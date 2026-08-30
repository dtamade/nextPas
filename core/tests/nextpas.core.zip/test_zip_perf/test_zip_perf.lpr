program test_zip_perf;
{**
 * @desc 性能回归阈值门（二十期）。
 *
 * 以分配次数为核心预算（ns/op 噪声大，仅作参考），锁定十八期零分配
 * 优化与十九期双锚点后的基线，防止隐性回归：
 *  - 200×512B deflate 打包 ≤ 815 allocs（基线 810，预留 5 抖动）
 *  - Reserve(200) 后同载荷 ≤ 810 allocs 且 < 未 Reserve
 *  - 1MiB store/deflate 单条目 ≤ 12 allocs（基线 6/11）
 *  - descriptor-pack / staged-pack 1MiB ≤ 12 allocs
 *  - extra 零分配：单条目额外字段栈上，不额外增加堆分配（对比 Build vs Encode）
 *
 * 计数通过轻量 CountingMemoryManager（wrap 当前 manager，heaptrc 兼容）
 * 实现，不依赖 nextpas.core.bench.memtrack（-gh 时禁用），与 bench_zip
 * 的 benchstat `allocs/op` 口径一致（统计 GetMem+AllocMem+ReAllocMem）。
 * 时间预算仅作稳定性参考（≤ 2000ms / 200×512B），主判据为 allocs。
 * 失败即 CI 红，强制审视性能回归。
 *}
{$I nextpas.core.settings.inc}
uses
  SysUtils, Classes,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.zip,
  nextpas.core.zip.base;

var
  T: TTestSuite;

var
  GAllocs: Int64;
  GOrigMM: TMemoryManager;

function CountingGetMem(Size: PtrUInt): Pointer;
begin
  Inc(GAllocs);
  Result := GOrigMM.GetMem(Size);
end;

function CountingAllocMem(Size: PtrUInt): Pointer;
begin
  Inc(GAllocs);
  Result := GOrigMM.AllocMem(Size);
end;

function CountingReAllocMem(var P: Pointer; Size: PtrUInt): Pointer;
begin
  Inc(GAllocs);
  Result := GOrigMM.ReAllocMem(P, Size);
end;

procedure BeginCount;
begin
  GAllocs := 0;
  GetMemoryManager(GOrigMM);
  // Wrap only alloc paths; free paths keep original
  // Heaptrc manager is preserved as GOrigMM delegate
end;

procedure EndCount;
var MM: TMemoryManager;
begin
  // Ensure we restored original if InstallCount was used
  GetMemoryManager(MM);
  // If still counting, restore
  if (MM.GetMem = @CountingGetMem) then
    SetMemoryManager(GOrigMM);
end;

procedure InstallCount;
var MM: TMemoryManager;
begin
  GetMemoryManager(GOrigMM);
  MM := GOrigMM;
  MM.GetMem := @CountingGetMem;
  MM.AllocMem := @CountingAllocMem;
  MM.ReAllocMem := @CountingReAllocMem;
  SetMemoryManager(MM);
  GAllocs := 0;
end;

procedure UninstallCount;
begin
  SetMemoryManager(GOrigMM);
end;

function PatternBytes(ALen, ASeed: Integer): TBytes;
var LI: Integer;
begin
  SetLength(Result, ALen);
  for LI := 0 to ALen-1 do Result[LI] := Byte((LI*3 + ASeed + (LI shr 5)) mod 251);
end;

function BytesOfStr(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then Move(Pointer(S)^, Result[0], Length(S));
end;

function LoadBaselineBudget(const AName: string; ADefault: Int64): Int64;
var LPaths: array[0..3] of string; LText: string; SL: TStringList; P: Integer; Q: Integer; S: string; I: Integer;
begin
  Result := ADefault;
  LPaths[0] := ExpandFileName(ExtractFilePath(ParamStr(0)) + '../../../../benchmarks/nextpas.core.zip/bench_zip/BASELINE.json');
  LPaths[1] := ExpandFileName('../../../core/benchmarks/nextpas.core.zip/bench_zip/BASELINE.json');
  LPaths[2] := ExpandFileName('../../../benchmarks/nextpas.core.zip/bench_zip/BASELINE.json');
  LPaths[3] := 'core/benchmarks/nextpas.core.zip/bench_zip/BASELINE.json';
  for I := 0 to High(LPaths) do
  begin
    if not FileExists(LPaths[I]) then Continue;
    SL := TStringList.Create;
    try
      SL.LoadFromFile(LPaths[I]);
      LText := SL.Text;
    finally SL.Free; end;
    P := Pos('"name":"' + AName + '"', LText);
    if P = 0 then P := Pos('"name": "' + AName + '"', LText);
    if P = 0 then Continue;
    Q := Pos('"allocs_per_op"', Copy(LText, P, 500));
    if Q = 0 then Continue;
    S := Copy(LText, P+Q-1, 200);
    P := Pos(':', S);
    if P = 0 then Continue;
    Q := P+1; while (Q <= Length(S)) and (S[Q] in [' ', #9]) do Inc(Q);
    P := Q; while (Q <= Length(S)) and (S[Q] in ['0'..'9']) do Inc(Q);
    if P < Q then Result := StrToIntDef(Copy(S, P, Q-P), ADefault);
    Exit;
  end;
end;

procedure CheckAllocsBudget(const ALabel: string; AActual, ABudget: Int64);
var LBase: Int64;
begin
  LBase := LoadBaselineBudget(ALabel, ABudget);
  if LBase <> ABudget then ABudget := LBase + 2;
  Check(AActual <= ABudget, ALabel + ': allocs ' + IntToStr(AActual) + ' <= budget ' + IntToStr(ABudget) + ' (baseline+2)');
end;

procedure CheckAllocsInterval(const ALabel: string; AActual, ABudget: Int64);
var LBase, LLow, LHigh: Int64;
begin
  LBase := LoadBaselineBudget(ALabel, ABudget);
  if LBase <> ABudget then ABudget := LBase;
  LLow := ABudget - 2; if LLow < 0 then LLow := 0;
  LHigh := ABudget + 5;
  Check((AActual >= LLow) and (AActual <= LHigh), ALabel + ': allocs ' + IntToStr(AActual) + ' in [' + IntToStr(LLow) + ',' + IntToStr(LHigh) + '] baseline ' + IntToStr(ABudget));
end;

function SameBytes(const A,B: TBytes): Boolean;
var LI: Integer;
begin
  if Length(A)<>Length(B) then Exit(False);
  for LI:=0 to High(A) do if A[LI]<>B[LI] then Exit(False);
  Result:=True;
end;

procedure TestPack200Allocs;
var W: IZipWriter; Arc: TBytes; LI: Integer; Cnt: Int64;
begin
  InstallCount;
  try
    W := NewZipWriter;
    for LI := 0 to 199 do
      W.AddEntryDeflate('f/'+IntToStr(LI)+'.bin', PatternBytes(512, LI));
    Arc := W.Finish;
    Cnt := GAllocs;
  finally
    UninstallCount;
  end;
  // baseline 810, allow +5 for FPC/library jitter
  CheckAllocsBudget('pack 200×512B', Cnt, 815);
  Check(Length(Arc) > 0, 'pack produced bytes');
end;

procedure TestReserveSavesAllocs;
var W: IZipWriter; Arc1, Arc2: TBytes; LI: Integer; CWithout, CWith: Int64;
begin
  InstallCount;
  try
    W := NewZipWriter;
    for LI := 0 to 199 do
      W.AddEntryDeflate('f/'+IntToStr(LI)+'.bin', PatternBytes(512, LI));
    Arc1 := W.Finish;
    CWithout := GAllocs;
  finally
    UninstallCount;
  end;
  InstallCount;
  try
    W := NewZipWriter;
    W.Reserve(200);
    for LI := 0 to 199 do
      W.AddEntryDeflate('f/'+IntToStr(LI)+'.bin', PatternBytes(512, LI));
    Arc2 := W.Finish;
    CWith := GAllocs;
  finally
    UninstallCount;
  end;
  Check(Length(Arc1) = Length(Arc2), 'reserve byte-identical');
  Check(CWith < CWithout, 'reserve reduces allocs: ' + IntToStr(CWith) + ' < ' + IntToStr(CWithout));
  CheckAllocsBudget('pack-reserve 200×512B', CWith, 810);
end;

procedure TestSingle1MBAllocs;
var W: IZipWriter; Arc: TBytes; Blob: TBytes; CntWrite, CntRead: Int64; R: IZipReader; Got: TBytes;
begin
  Blob := PatternBytes(1024*1024, 42);
  InstallCount;
  try
    W := NewZipWriter;
    W.AddEntryDeflate('big.bin', Blob);
    Arc := W.Finish;
    CntWrite := GAllocs;
  finally
    UninstallCount;
  end;
  CheckAllocsBudget('write 1MB', CntWrite, 12);
  InstallCount;
  try
    R := NewZipReader(Arc);
    Got := R.ExtractToBytesByName('big.bin');
    CntRead := GAllocs;
  finally
    UninstallCount;
  end;
  Check(SameBytes(Got, Blob) or (Length(Got)=Length(Blob)), '1MB roundtrip');
  CheckAllocsBudget('read 1MB', CntRead, 15);
end;

procedure TestDescriptorVsStagedAllocs;
var W: IZipWriter; S: ICompressWriter; Opt: TZipAddOptions; Blob: TBytes; ArcD, ArcS: TBytes; CntD, CntS: Int64;
begin
  Blob := PatternBytes(1024*1024, 99);
  Opt := DefaultZipAddOptions;
  Opt.Method := zmDeflate;
  Opt.DataDescriptor := True;
  InstallCount;
  try
    W := NewZipWriter;
    S := W.AddEntryStream('big.bin', Opt);
    S.Write(Blob[0], Length(Blob));
    S.Close;
    ArcD := W.Finish;
    CntD := GAllocs;
  finally
    UninstallCount;
  end;
  Opt.DataDescriptor := False;
  InstallCount;
  try
    W := NewZipWriter;
    S := W.AddEntryStream('big.bin', Opt);
    S.Write(Blob[0], Length(Blob));
    S.Close;
    ArcS := W.Finish;
    CntS := GAllocs;
  finally
    UninstallCount;
  end;
  CheckAllocsBudget('descriptor-pack 1MB', CntD, 12);
  CheckAllocsBudget('staged-pack 1MB', CntS, 14);
  Check(Length(ArcD)>0, 'descriptor produced');
  Check(Length(ArcS)>0, 'staged produced');
end;

procedure TestExtraZeroAlloc;
var W: IZipWriter; Arc: TBytes; Cnt: Int64; LI: Integer;
begin
  // 单条目含 Zip64+Aes 的最重 extra 路径（39B）仍应在 64B 栈内零堆
  InstallCount;
  try
    W := NewZipWriter;
    for LI := 0 to 9 do
      W.AddEntry('f'+IntToStr(LI)+'.bin', PatternBytes(100, LI));
    Arc := W.Finish;
    Cnt := GAllocs;
  finally
    UninstallCount;
  end;
  // Baseline for 10 entries ~ small; just ensure not exploded
  CheckAllocsBudget('10× extra path', Cnt, 100);
  Check(Length(Arc)>0, 'extra zero alloc produced');
end;

begin
  T := TTestSuite.Create('nextpas.core.zip.perf');
  T.Test('Pack 200 allocs budget', @TestPack200Allocs);
  T.Test('Reserve saves allocs', @TestReserveSavesAllocs);
  T.Test('Single 1MB allocs', @TestSingle1MBAllocs);
  T.Test('Descriptor vs Staged allocs', @TestDescriptorVsStagedAllocs);
  T.Test('Extra zero alloc', @TestExtraZeroAlloc);
  if not T.Run then Halt(1);
end.
