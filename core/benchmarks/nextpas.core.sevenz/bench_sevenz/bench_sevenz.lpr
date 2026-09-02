program bench_sevenz;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

{ nextpas.core.sevenz 吞吐基准：LZMA2 双后端编解码、BCJ/Delta 过滤器、
  容器端到端写读（含并行多 folder 对比）。语料确定性生成；每个用例先做往返正确性校验再计时 }

uses
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.time.base,
  nextpas.core.text.format,
  nextpas.core.sevenz,
  nextpas.core.sevenz.coders,
  nextpas.core.sevenz.filters,
  nextpas.core.sevenz.bcj.x86,
  nextpas.core.sevenz.lzma.ffi.decoder;

const
  DATA_SIZE = 1024 * 1024;
  CODEC_ITER = 3;        { LZMA2 编码较慢：少迭代 }
  DECODE_ITER = 10;
  FILTER_ITER = 50;
  CONTAINER_ITER = 3;
  ENTRY_COUNT = 8;

var
  GData: TBytes;
  GMix: TBytes;
  GExe: TBytes;

function BytesClone(const ASrc: TBytes): TBytes;
begin
  Result := SpanClone(TByteSpan.FromBytes(ASrc));
end;

procedure GenerateData;
var
  LI: Integer;
  LState: UInt32;
begin
  SetLength(GData, DATA_SIZE);
  for LI := 0 to DATA_SIZE - 1 do
    GData[LI] := Byte((LI * 7 + LI div 256) mod 251);
  { 分块混合语料：4KB 熵块与 4KB 可预测块交替——匹配功与字面量
    功负载并存，贴近真实混合数据 }
  SetLength(GMix, DATA_SIZE);
  LState := UInt32($20260826);
  for LI := 0 to DATA_SIZE - 1 do
  begin
    if Odd(LI shr 12) then
      GMix[LI] := Byte(LI)
    else
    begin
      {$PUSH}{$Q-}{$R-}
      LState := LState xor (LState shl 13);
      LState := LState xor (LState shr 17);
      LState := LState xor (LState shl 5);
      {$POP}
      GMix[LI] := Byte(LState shr 24);
    end;
  end;
  { 拟真可执行语料：中低熵指令流 + 聚集调用目标（BCJ 有效场景） }
  SetLength(GExe, DATA_SIZE);
  for LI := 0 to DATA_SIZE - 1 do
    GExe[LI] := Byte((LI * 13 + LI div 64) mod 251) and $3F;
  for LI := 0 to (DATA_SIZE div 16) - 1 do
    GExe[LI * 16] := $E8;
end;

function BytesEqual(const AA, AB: TBytes): Boolean;
var
  LI: Integer;
begin
  Result := Length(AA) = Length(AB);
  if Result and (Length(AA) > 0) then
  begin
    for LI := 0 to High(AA) do
      if AA[LI] <> AB[LI] then
        Exit(False);
  end;
end;

procedure CheckEqual(const AExpected, AActual: TBytes; const ALabel: string);
begin
  if not BytesEqual(AExpected, AActual) then
    raise EInvalidOperationError.Create(ALabel + ': byte mismatch');
end;

procedure BenchEncode(const ABackend: TSevenZLzmaBackend; const ATag: string);
var
  LI, LN: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LEnc: TSevenZLzmaEncoded;
  LRatio: Double;
begin
  SevenZSetLzmaBackend(ABackend);
  LEnc := SevenZAcquireEncoder.EncodeLzma2(GMix, szclDefault);
  LRatio := Length(LEnc.PackedData) / Double(DATA_SIZE) * 100;
  LN := CODEC_ITER;
  LStart := TInstant.Now;
  for LI := 1 to LN do
    LEnc := SevenZAcquireEncoder.EncodeLzma2(GMix, szclDefault);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('lzma2 encode  %-11s %6.1f MB/s  ratio=%.1f%%', [
    ATag, (DATA_SIZE * LN / 1048576.0) / LElapsed, LRatio]));
end;

procedure BenchDecode(const ABackend: TSevenZLzmaBackend; const ATag: string);
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LEnc: TSevenZLzmaEncoded;
  LOut: TBytes;
begin
  SevenZSetLzmaBackend(ABackend);
  LEnc := SevenZAcquireEncoder.EncodeLzma2(GMix, szclDefault);
  LOut := SevenZAcquireDecoder.DecodeLzma2(LEnc.Props, LEnc.PackedData,
    UInt64(DATA_SIZE));
  CheckEqual(GMix, LOut, 'decode ' + ATag);
  LStart := TInstant.Now;
  for LI := 1 to DECODE_ITER do
    LOut := SevenZAcquireDecoder.DecodeLzma2(LEnc.Props, LEnc.PackedData,
      UInt64(DATA_SIZE));
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('lzma2 decode  %-11s %6.1f MB/s', [
    ATag, (DATA_SIZE * DECODE_ITER / 1048576.0) / LElapsed]));
end;

procedure BenchBcjX86;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LBuf: TBytes;
begin
  LBuf := BytesClone(GExe);
  SevenZBcjX86Convert(LBuf, 0, True);
  SevenZBcjX86Convert(LBuf, 0, False);
  CheckEqual(GExe, LBuf, 'bcj roundtrip');
  LStart := TInstant.Now;
  for LI := 1 to FILTER_ITER do
  begin
    LBuf := BytesClone(GExe);
    SevenZBcjX86Convert(LBuf, 0, True);
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('bcj x86 encode          %6.1f MB/s',
    [(DATA_SIZE * FILTER_ITER / 1048576.0) / LElapsed]));
end;

procedure BenchDelta;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LBuf: TBytes;
begin
  LBuf := SevenZDeltaEncode(TBytes.Create(Byte(0)), GData);
  CheckEqual(GData, SevenZDeltaDecode(TBytes.Create(Byte(0)), LBuf,
    UInt64(DATA_SIZE)), 'delta roundtrip');
  LStart := TInstant.Now;
  for LI := 1 to FILTER_ITER do
    LBuf := SevenZDeltaEncode(TBytes.Create(Byte(0)), GData);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('delta encode            %6.1f MB/s',
    [(DATA_SIZE * FILTER_ITER / 1048576.0) / LElapsed]));
end;

procedure BenchContainerRoundtrip;
var
  LI, LJ: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArchive, LGot: TBytes;
  LTotal: Int64;
begin
  LW := TSevenZWriterImpl.Create;
  for LJ := 0 to ENTRY_COUNT - 1 do
    LW.AddFile(TextFormat('e%d.bin', [LJ]),
      Copy(GData, LJ * (DATA_SIZE div ENTRY_COUNT),
        DATA_SIZE div ENTRY_COUNT));
  LArchive := LW.Finish;
  LR := TSevenZReaderImpl.Create(LArchive);
  LTotal := 0;
  for LJ := 0 to LR.EntryCount - 1 do
  begin
    LGot := LR.Extract(LJ);
    Inc(LTotal, Length(LGot));
  end;
  if LTotal <> DATA_SIZE then
    raise EInvalidOperationError.Create('container roundtrip size mismatch');
  LStart := TInstant.Now;
  for LI := 1 to CONTAINER_ITER do
    for LJ := 0 to LR.EntryCount - 1 do
      LGot := LR.Extract(LJ);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat(
    'container extract (%d entries, warm cache) %6.1f MB/s  archive=%d bytes',
    [ENTRY_COUNT, (DATA_SIZE * CONTAINER_ITER / 1048576.0) / LElapsed,
     Length(LArchive)]));
end;

procedure BenchContainerParallel;
var
  LI, LJ: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArchive: TBytes;
  LIsMT: string;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetFolderLimits(0, 1); // 8 folders → parallel path when cthreads
  for LJ := 0 to ENTRY_COUNT - 1 do
    LW.AddFile(TextFormat('e%d.bin', [LJ]),
      Copy(GData, LJ * (DATA_SIZE div ENTRY_COUNT), DATA_SIZE div ENTRY_COUNT));
  LStart := TInstant.Now;
  LArchive := LW.Finish;
  LElapsed := LStart.Elapsed.AsSecondsF;
  if System.IsMultiThread then LIsMT := 'mt' else LIsMT := 'st';
  WriteLn(TextFormat('container create  multi(%s) %6.1f MB/s  archive=%d bytes',
    [LIsMT, (DATA_SIZE / 1048576.0) / LElapsed, Length(LArchive)]));
  LR := TSevenZReaderImpl.Create(LArchive);
  LStart := TInstant.Now;
  for LI := 1 to CONTAINER_ITER do
    for LJ := 0 to LR.EntryCount - 1 do
      LR.Extract(LJ);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('container extract multi     %6.1f MB/s', [(DATA_SIZE*CONTAINER_ITER/1048576.0)/LElapsed]));
end;

procedure BenchContainerFilteredCrypto;
var
  LStart: TInstant;
  LElapsed: Double;
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArchive, LGot: TBytes;
  LTotal: Int64;
  procedure BenchOne(const ATag: string; AUsePass, AMulti: Boolean);
  var LIsMT: string; LL, LM: Integer;
  begin
    LW := TSevenZWriterImpl.Create;
    LW.SetLevel(szclNone);
    LW.SetFilters([szfBcjX86]);
    if AUsePass then LW.SetPassword('bench-pw');
    if AMulti then LW.SetFolderLimits(0, 1);
    for LM := 0 to ENTRY_COUNT - 1 do
      LW.AddFile(TextFormat('e%d.bin', [LM]),
        Copy(GExe, LM * (DATA_SIZE div ENTRY_COUNT), DATA_SIZE div ENTRY_COUNT));
    LStart := TInstant.Now;
    LArchive := LW.Finish;
    LElapsed := LStart.Elapsed.AsSecondsF;
    if AUsePass and AMulti then
      if System.IsMultiThread then LIsMT := 'mt' else LIsMT := 'st'
    else LIsMT := '--';
    WriteLn(TextFormat('container %s %s %6.1f MB/s  archive=%d bytes',
      [ATag, LIsMT, (DATA_SIZE / 1048576.0) / LElapsed, Length(LArchive)]));
    if AUsePass then
      LR := TSevenZReaderImpl.CreateWithPassword(LArchive, 'bench-pw')
    else LR := TSevenZReaderImpl.Create(LArchive);
    LTotal := 0;
    for LM := 0 to LR.EntryCount - 1 do
    begin
      LGot := LR.Extract(LM);
      Inc(LTotal, Length(LGot));
    end;
    if LTotal <> DATA_SIZE then
      raise EInvalidOperationError.Create(ATag + ': size mismatch');
    LStart := TInstant.Now;
    for LL := 1 to CONTAINER_ITER do
      for LM := 0 to LR.EntryCount - 1 do
        LR.Extract(LM);
    LElapsed := LStart.Elapsed.AsSecondsF;
    WriteLn(TextFormat('  extract %-16s %6.1f MB/s', [ATag, (DATA_SIZE*CONTAINER_ITER/1048576.0)/LElapsed]));
  end;
begin
  BenchOne('copy+bcj', False, False);
  BenchOne('copy+bcj+pw', True, False);
  BenchOne('copy+bcj+pw multi', True, True);
end;

procedure BenchGlobIgnoreCase;
const N = 2000; ITER = 5000;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArchive: TBytes;
  LJ: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LRes: TSevenZEntryInfoArray;
  LName: string;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetLevel(szclNone);
  for LJ := 0 to N - 1 do
  begin
    LName := TextFormat('pref_%04d_suf.TXT', [LJ]);
    if (LJ mod 500) = 0 then LW.AddDirectory(TextFormat('pref_%04d', [LJ]));
    LW.AddFile(LName, TBytes.Create(Byte(LJ and $FF)));
  end;
  LArchive := LW.Finish;
  LR := TSevenZReaderImpl.Create(LArchive);
  LRes := LR.EntriesByGlobIgnoreCase('pref_00*');
  if Length(LRes) = 0 then raise EInvalidOperationError.Create('bench glob warm failed');
  LStart := TInstant.Now;
  for LJ := 1 to ITER do LRes := LR.EntriesByGlobIgnoreCase('pref_00*');
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('glob IgnoreCase prefix*   %6.0f ops/s  hits=%d', [ITER/LElapsed, Length(LRes)]));
  LStart := TInstant.Now;
  for LJ := 1 to ITER do LRes := LR.EntriesByGlobIgnoreCase('*_suf.txt');
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('glob IgnoreCase *suffix   %6.0f ops/s  hits=%d', [ITER/LElapsed, Length(LRes)]));
  LStart := TInstant.Now;
  for LJ := 1 to ITER do LRes := LR.EntriesByGlobIgnoreCase('pref_*_suf.txt');
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('glob IgnoreCase p*s      %6.0f ops/s  hits=%d', [ITER/LElapsed, Length(LRes)]));
  LStart := TInstant.Now;
  for LJ := 1 to ITER do LRes := LR.EntriesByGlobIgnoreCase('PREF_0100_SUF.txt');
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('glob IgnoreCase exact     %6.0f ops/s  hits=%d', [ITER/LElapsed, Length(LRes)]));
end;

procedure BenchGlobIgnoreCase10k;
const N = 10000; ITER = 1000;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArchive: TBytes;
  LJ: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LRes: TSevenZEntryInfoArray;
  LName: string;
  Ops: Double;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetLevel(szclNone);
  for LJ := 0 to N - 1 do
  begin
    LName := TextFormat('pref_%05d_suf.TXT', [LJ]);
    if (LJ mod 1000) = 0 then LW.AddDirectory(TextFormat('pref_%05d', [LJ]));
    LW.AddFile(LName, TBytes.Create(Byte(LJ and $FF)));
  end;
  LArchive := LW.Finish;
  LR := TSevenZReaderImpl.Create(LArchive);
  // warm + redline: O(log N) paths must stay >1k ops/s at 10k scale
  LRes := LR.EntriesByGlobIgnoreCase('pref_000*');
  if Length(LRes) = 0 then raise EInvalidOperationError.Create('bench 10k warm failed');
  LStart := TInstant.Now;
  for LJ := 1 to ITER do LRes := LR.EntriesByGlobIgnoreCase('pref_000*');
  LElapsed := LStart.Elapsed.AsSecondsF;
  Ops := ITER / LElapsed;
  WriteLn(TextFormat('glob IgnoreCase10k prefix* %6.0f ops/s  hits=%d', [Ops, Length(LRes)]));
  if Ops < 1000 then
    WriteLn('WARN: prefix* 10k redline <1000 ops/s');
  LStart := TInstant.Now;
  for LJ := 1 to ITER do LRes := LR.EntriesByGlobIgnoreCase('*_suf.txt');
  LElapsed := LStart.Elapsed.AsSecondsF;
  Ops := ITER / LElapsed;
  WriteLn(TextFormat('glob IgnoreCase10k *suffix %6.0f ops/s  hits=%d', [Ops, Length(LRes)]));
  if Ops < 500 then
    WriteLn('WARN: *suffix 10k redline <500 ops/s');
  LStart := TInstant.Now;
  for LJ := 1 to ITER do LRes := LR.EntriesByGlobIgnoreCase('pref_*_suf.txt');
  LElapsed := LStart.Elapsed.AsSecondsF;
  Ops := ITER / LElapsed;
  WriteLn(TextFormat('glob IgnoreCase10k p*s    %6.0f ops/s  hits=%d', [Ops, Length(LRes)]));
  if Ops < 300 then
    WriteLn('WARN: p*s 10k redline <300 ops/s');
  LStart := TInstant.Now;
  for LJ := 1 to ITER do LRes := LR.EntriesByGlobIgnoreCase('PREF_00500_SUF.txt');
  LElapsed := LStart.Elapsed.AsSecondsF;
  Ops := ITER / LElapsed;
  WriteLn(TextFormat('glob IgnoreCase10k exact  %6.0f ops/s  hits=%d', [Ops, Length(LRes)]));
  if Ops < 100000 then
    WriteLn('WARN: exact 10k redline <100k ops/s');
end;

var
  LSaved: TSevenZLzmaBackend;
  LFfiOk: Boolean;
  LFfiTag: string;
begin
  GenerateData;
  LFfiOk := SevenZLzmaFfiAvailable;
  if LFfiOk then
    LFfiTag := 'yes'
  else
    LFfiTag := 'no';
  LSaved := SevenZRequestedBackend;
  WriteLn(TextFormat(
    '=== nextpas.core.sevenz benchmark (1MB corpus, ffi=%s) ===',
    [LFfiTag]));
  WriteLn;
  BenchEncode(szlbPurePascal, 'pure');
  { 写端编码器当前仅纯 Pascal 实现（见 README），故无 ffi 编码行 }
  WriteLn;
  BenchDecode(szlbPurePascal, 'pure');
  if LFfiOk then
    BenchDecode(szlbFfi, 'ffi');
  WriteLn;
  BenchBcjX86;
  BenchDelta;
  WriteLn;
  SevenZSetLzmaBackend(LSaved);
  BenchContainerRoundtrip;
  BenchContainerParallel;
  BenchContainerFilteredCrypto;
  WriteLn;
  BenchGlobIgnoreCase;
  BenchGlobIgnoreCase10k;
  WriteLn;
  WriteLn('done.');
end.
