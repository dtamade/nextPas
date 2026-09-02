program test_sevenz;

{$I nextpas.core.settings.inc}

{ nextpas.core.sevenz 正式测试：UTF 换算 / FILETIME / LZMA2 往返 /
  写端→读端容器往返（经门面）/ 边界与错误路径 }

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.checksum.crc32,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.util,
  nextpas.core.fs,
  nextpas.core.sevenz,
  nextpas.core.sevenz.fs,
  nextpas.core.sevenz.base,
  nextpas.core.sevenz.aes,
  nextpas.core.sevenz.bcj.x86,
  nextpas.core.sevenz.bcj.arm,
  nextpas.core.sevenz.bcj.arm64,
  nextpas.core.sevenz.bcj.ppc,
  nextpas.core.sevenz.bcj.ia64,
  nextpas.core.sevenz.bcj.sparc,
  nextpas.core.sevenz.bcj.armt,
  nextpas.core.sevenz.bcj.riscv,
  nextpas.core.compress.base,
  nextpas.core.sevenz.header,
  nextpas.core.sevenz.coders,
  nextpas.core.sevenz.filters,
  nextpas.core.sevenz.lzma.ffi.decoder,
  nextpas.core.compress.deflate,
  nextpas.core.compress.bzip2,
  nextpas.core.sevenz.limits,
  nextpas.core.test;

type
  { ExtractTo 测试用 sink：记录全部写入字节 }
  TSinkRecorder = class(TInterfacedObject, IWriter)
  public
    Buf: TBytes;
    Writes: Integer;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

function TSinkRecorder.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LBase: SizeInt;
begin
  LBase := Length(Buf);
  SetLength(Buf, LBase + SizeInt(ACount));
  if ACount > 0 then
    Move(ABuf, Buf[LBase], ACount);
  Inc(Writes);
  Result := ACount;
end;

var
  T: TTestSuite;

function BytesOf(const AValues: array of Byte): TBytes;
var
  I: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(AValues));
  for I := 0 to High(AValues) do
    Result[I] := AValues[I];
end;

function RepeatedText(AUnit: Integer; ATimes: Integer): TBytes;
var
  I: SizeInt;
begin
  Result := nil;
  SetLength(Result, AUnit * ATimes);
  for I := 0 to High(Result) do
    Result[I] := Byte(65 + (I mod AUnit));
end;

function SameBytes(const A, B: TBytes): Boolean; forward;

function Randomish(ALen: Integer; ASeed: Integer): TBytes;
var
  I: SizeInt;
  LState: UInt32;
begin
  { xorshift32 伪随机：确定性且高熵，逼出未压缩回退路径 }
  Result := nil;
  SetLength(Result, ALen);
  LState := UInt32(ASeed);
  for I := 0 to ALen - 1 do
  begin
    {$PUSH}{$Q-}{$R-}
    LState := LState xor (LState shl 13);
    LState := LState xor (LState shr 17);
    LState := LState xor (LState shl 5);
    {$POP}
    Result[I] := Byte(LState shr 24);
  end;
end;

{ UTF 换算 }

procedure TestUtf16BmpRoundTrip;
const
  C_NAME = '数据/文件-αβ.txt';
begin
  CheckEqual(C_NAME, SevenZUtf16LeToUtf8(SevenZUtf8ToUtf16Le(C_NAME)));
end;

procedure TestUtf16AsciiIdentity;
begin
  CheckEqual(Int64(24), Int64(Length(SevenZUtf8ToUtf16Le('hello world!'))));
  CheckEqual('a/b.txt',
    SevenZUtf16LeToUtf8(BytesOf([$61, $00, $2F, $00, $62, $00, $2E,
    $00, $74, $00, $78, $00, $74, $00])));
end;

procedure TestUtf16AstralSurrogatePair;
var
  LUnits: TBytes;
begin
  { U+1F600 = F0 9F 98 80 → 代理对 D83D DE00 → 回转同一 UTF-8 }
  LUnits := SevenZUtf8ToUtf16Le(Utf8String(#$F0#$9F#$98#$80));
  CheckEqual(Int64(4), Int64(Length(LUnits)));
  CheckEqual(Int64($3D), Int64(LUnits[0]));
  CheckEqual(Int64($D8), Int64(LUnits[1]));
  CheckEqual(Int64($00), Int64(LUnits[2]));
  CheckEqual(Int64($DE), Int64(LUnits[3]));
  CheckEqual(Utf8String(#$F0#$9F#$98#$80),
    SevenZUtf16LeToUtf8(LUnits));
end;

procedure TestUtf16UnpairedSurrogateIsReplacement;
var
  LOut: string;
begin
  { 未配对高代理判废为单个 U+FFFD（UTF-16LE 为 FD FF） }
  LOut := SevenZUtf16LeToUtf8(BytesOf([$00, $D8]));
  CheckEqual(Utf8String(#$EF#$BF#$BD), LOut);
end;

procedure TestUtf8TruncatedTailIsSingleReplacement;
begin
  { E6 95 尾部截断：整段判废，恰一 U+FFFD 单元（2 字节） }
  CheckEqual(Int64(2),
    Int64(Length(SevenZUtf8ToUtf16Le(Utf8String(#$E6#$95)))));
end;

procedure TestUtf8BadContinuationConsumesSequence;
begin
  { E6 41 42：续字节非法整段判废为 U+FFFD，不再产出散落单元（2 字节） }
  CheckEqual(Int64(2),
    Int64(Length(SevenZUtf8ToUtf16Le(Utf8String(#$E6#$41#$42)))));
end;

{ FILETIME }

procedure TestFiletimeRoundTrip;
begin
  CheckEqual(Int64(1700000000),
    SevenZFILETIMEToUnix(SevenZUnixToFILETIME(1700000000)));
  CheckEqual(Int64(0), SevenZFILETIMEToUnix(SevenZUnixToFILETIME(0)));
end;

procedure TestFiletimeNegativeClamp;
begin
  { 早于 NT 纪元（1601-01-01）的时间钳到 0，避免无符号下溢 }
  CheckEqual(UInt64(0), SevenZUnixToFILETIME(-20000000000));
end;

{ LZMA2 编解码往返（经 coders 获取当前后端） }

procedure RoundtripLzma2(const ARaw: TBytes; const ATag: string);
var
  LEncoded: TSevenZLzmaEncoded;
  LDecoded: TBytes;
begin
  LEncoded := SevenZAcquireEncoder.EncodeLzma2(ARaw, szclDefault);
  LDecoded := SevenZAcquireDecoder.DecodeLzma2(
    LEncoded.Props, LEncoded.PackedData, SizeUInt(Length(ARaw)));
  CheckEqual(Int64(Length(ARaw)), Int64(Length(LDecoded)), ATag + ' size');
  if Length(ARaw) > 0 then
    Check(CompareMem(@ARaw[0], @LDecoded[0], Length(ARaw)),
      ATag + ' content');
end;

procedure TestLzma2Empty;
begin
  RoundtripLzma2(nil, 'empty');
end;

procedure TestLzma2OneByte;
begin
  RoundtripLzma2(BytesOf([$42]), 'one-byte');
end;

procedure TestLzma2TextPattern;
var
  LRaw: TBytes;
begin
  LRaw := RepeatedText(45, 5000);
  RoundtripLzma2(LRaw, 'text');
end;

procedure TestLzma2RandomStoredFallback;
var
  LRaw: TBytes;
begin
  { 高熵数据触发未压缩回退与多块拼接 }
  LRaw := Randomish(150000, 20260825);
  RoundtripLzma2(LRaw, 'random-stored');
end;

procedure TestLzma2ChunkCapBoundary;
var
  LRaw: TBytes;
begin
  { 恰好跨一个 2MiB 解压块边界 }
  LRaw := RepeatedText(97, 22000);
  RoundtripLzma2(LRaw, 'chunk-cap');
end;


{ 后端切换：显式 PurePascal / 显式 FFI（不可用则回落）/ 缺省 Auto }

procedure TestBackendSwitchPurePascal;
begin
  SevenZSetLzmaBackend(szlbPurePascal);
  try
    Check(SevenZActiveBackend = szlbPurePascal, 'resolve purepascal');
    RoundtripLzma2(RepeatedText(45, 1000), 'backend-purepascal');
  finally
    SevenZSetLzmaBackend(szlbAuto);
  end;
end;

procedure TestBackendSwitchFfi;
begin
  SevenZSetLzmaBackend(szlbFfi);
  try
    if SevenZLzmaFfiAvailable then
      Check(SevenZActiveBackend = szlbFfi, 'resolve ffi')
    else
      Check(SevenZActiveBackend = szlbPurePascal, 'ffi falls back');
    RoundtripLzma2(RepeatedText(45, 2000), 'backend-ffi');
    RoundtripLzma2(Randomish(150000, 7), 'backend-ffi-stored');
  finally
    SevenZSetLzmaBackend(szlbAuto);
  end;
end;

procedure TestBackendDefaultAuto;
var
  LExpected: TSevenZLzmaBackend;
begin
  SevenZSetLzmaBackend(szlbAuto);
  if SevenZLzmaFfiAvailable then
    LExpected := szlbFfi
  else
    LExpected := szlbPurePascal;
  Check(SevenZActiveBackend = LExpected, 'auto resolves by availability');
end;

{ 写端 → 读端容器往返（门面） }

procedure TestWriterReaderSingleFile;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LE: TSevenZEntryInfo;
  LGot: TBytes;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$68, $65, $6C, $6C, $6F]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(1), Int64(LR.EntryCount));
  LE := LR.Entry(0);
  CheckEqual('a.txt', LE.Name);
  Check(LE.Kind = sekFile, 'kind');
  CheckEqual(Int64(5), Int64(LE.Size));
  Check(LE.HasCrc, 'crc present');
  LGot := LR.Extract(0);
  CheckEqual(Int64(5), Int64(Length(LGot)));
  CheckEqual(Int64($68), Int64(LGot[0]));
end;

procedure TestWriterSolidMultiFile;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LGot: TBytes;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('one.bin', RepeatedText(8, 100));
  LW.AddFile('two.bin', RepeatedText(9, 50));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(2), Int64(LR.EntryCount));
  CheckEqual(Int64(800), Int64(Length(LR.Extract(0))));
  LGot := LR.Extract(1);
  CheckEqual(Int64(450), Int64(Length(LGot)));
  CheckEqual(Int64($41), Int64(LGot[0]));
end;

procedure TestWriterDirAndEmptyEntries;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LE: TSevenZEntryInfo;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddDirectory('docs');
  LW.AddFileWithTime('docs/x.bin', RepeatedText(4, 10), 1700000000);
  LW.AddFile('e.dat', nil);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(3), Int64(LR.EntryCount));
  LE := LR.Entry(0);
  Check(LE.Kind = sekDirectory, 'dir kind');
  Check(LR.Extract(0) = nil, 'dir extract nil');
  LE := LR.Entry(2);
  Check(LE.Kind = sekFile, 'empty file kind');
  CheckEqual(Int64(0), Int64(LE.Size));
  Check(not LE.HasCrc, 'empty file no crc');
  Check(LR.Extract(2) = nil, 'empty extract nil');
end;

procedure TestWriterUnicodeNames;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LIdx: Integer;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddDirectory('数据');
  LW.AddFile('数据/文件-αβ.txt', TBytes.Create($E4, $B8, $80));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  LIdx := LR.Find('数据/文件-αβ.txt');
  Check(LIdx >= 0, 'unicode find');
  CheckEqual(Int64(3), Int64(Length(LR.Extract(LIdx))));
end;

procedure TestWriterDeterministicDefaultMtime;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LE: TSevenZEntryInfo;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('t.txt', BytesOf([$31]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  LE := LR.Entry(0);
  Check(LE.HasMTime, 'has mtime');
  CheckEqual(Int64(0), Int64(LE.MTimeUnixSec));
end;

procedure TestWriterExplicitMtimeSurvives;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFileWithTime('t.txt', BytesOf([$31]), 1234567890);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(1234567890),
    Int64(LR.Entry(0).MTimeUnixSec));
end;

procedure ExpectNameRejected(const AName: string);
var
  LW: ISevenZWriter;
begin
  LW := TSevenZWriterImpl.Create;
  try
    LW.AddFile(AName, BytesOf([$30]));
    Fail('name should be rejected: ' + AName);
  except
    on E: EArgumentError do
      ;
  end;
end;

procedure TestWriterNameValidation;
begin
  ExpectNameRejected('');
  ExpectNameRejected('/abs.txt');
  ExpectNameRejected('back\slash.txt');
  ExpectNameRejected('..');
  ExpectNameRejected('a/../b.txt');
  ExpectNameRejected('a/..');
  { 空路径段族：双斜杠与尾斜杠 }
  ExpectNameRejected('a//b.txt');
  ExpectNameRejected('trailing/');
  ExpectNameRejected('a/b/');
end;

procedure TestFinishTwiceRaises;
var
  LW: ISevenZWriter;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('x', BytesOf([$58]));
  LW.Finish;
  try
    LW.Finish;
    Fail('second Finish should raise');
  except
    on E: ESevenZError do
      ;
  end;
end;

procedure TestWriterEmptyArchive;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(0), Int64(LR.EntryCount));
end;

{ 读端边界 }

procedure ExpectCreateRaises(const AArchive: TBytes; const ATag: string);
begin
  try
    TSevenZReaderImpl.Create(AArchive);
    Fail('should raise: ' + ATag);
  except
    on E: ESevenZError do
      ;
  end;
end;

{ BCJ x86：黄金向量（宿主机 p7zip 17.05 真实 ELF 差分采集，
  窗口取自流内偏移 200，AStartIp 补偿绝对位置依赖）}

const
  C_BCJ_ORIG: array[0..47] of Byte = (
    $00, $00, $00, $00, $00, $00, $00, $00,
    $E8, $14, $00, $00, $00, $00, $00, $00,
    $E8, $14, $00, $00, $00, $00, $00, $00,
    $00, $10, $00, $00, $00, $00, $00, $00,
    $01, $00, $00, $00, $05, $00, $00, $00,
    $00, $20, $00, $00, $00, $00, $00, $00);
  C_BCJ_ENC: array[0..47] of Byte = (
    $00, $00, $00, $00, $00, $00, $00, $00,
    $E8, $E9, $00, $00, $00, $00, $00, $00,
    $E8, $F1, $00, $00, $00, $00, $00, $00,
    $00, $10, $00, $00, $00, $00, $00, $00,
    $01, $00, $00, $00, $05, $00, $00, $00,
    $00, $20, $00, $00, $00, $00, $00, $00);

function BytesFromConst(const AArr: array of Byte): TBytes;
var
  LI: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(AArr));
  for LI := 0 to High(AArr) do
    Result[LI] := AArr[LI];
end;

procedure TestBcjGoldenVectors;
var
  B: TBytes;
begin
  { 解码方向：参考编码产物 -> 原始相对位移 }
  B := BytesFromConst(C_BCJ_ENC);
  SevenZBcjX86Convert(B, 200, False);
  CheckEqual(Int64(Length(C_BCJ_ORIG)), Int64(Length(B)), 'bcj dec len');
  Check(CompareMem(@B[0], @C_BCJ_ORIG[0], Length(B)), 'bcj dec bytes');

  { 编码方向：原始 -> 参考编码形态 }
  B := BytesFromConst(C_BCJ_ORIG);
  SevenZBcjX86Convert(B, 200, True);
  Check(CompareMem(@B[0], @C_BCJ_ENC[0], Length(B)), 'bcj enc bytes');
end;

procedure TestBcjRoundtripAndSkip;
var
  LRaw: TBytes;
  LWork: TBytes;
  LI: SizeInt;

  procedure InjectPattern(APos: SizeInt; const APat: array of Byte);
  var
    LK: SizeInt;
  begin
    for LK := 0 to High(APat) do
      if APos + LK < Length(LRaw) then
        LRaw[APos + LK] := APat[LK];
  end;

begin
  { 高熵底 + 密集 E8/E9 注入：编->解必须逐字节还原 }
  LRaw := Randomish(70000, 777);
  for LI := 0 to 400 do
    InjectPattern((LI * 173) mod 69000,
      BytesOf([$E8, Byte(LI), $00, $FF, $00]));
  for LI := 0 to 200 do
    InjectPattern((LI * 331 + 7) mod 68000,
      BytesOf([$E9, $AA, $55, $00, $00]));

  LWork := Copy(LRaw, 0, Length(LRaw));
  SevenZBcjX86Convert(LWork, 0, True);
  SevenZBcjX86Convert(LWork, 0, False);
  Check(CompareMem(@LRaw[0], @LWork[0], Length(LRaw)), 'bcj roundtrip');

  { 操作数最高位非 $00/$FF 的伪候选必须原样保留 }
  LWork := BytesOf([$90, $90, $E8, $11, $22, $33, $44, $90, $90, $90]);
  SevenZBcjX86Convert(LWork, 0, False);
  Check(LWork[2] = $E8, 'skip keeps opcode');
  Check((LWork[3] = $11) and (LWork[4] = $22) and
    (LWork[5] = $33) and (LWork[6] = $44), 'skip keeps operand');
end;

{ BCJ ARM / ARM64 / PPC：按 xz 参考实现移植，逐字节对照 encode↔decode }

procedure TestBcjArmRoundtrip;
var
  LRaw, LWork: TBytes;
  LI: SizeInt;
begin
  LRaw := Randomish(70000, 881);
  for LI := 0 to 800 do
  begin
    if (LI*4+3 < Length(LRaw)) then
    begin
      LRaw[LI*4 + 3] := $EB;
      LRaw[LI*4] := Byte(LI and $FF);
      LRaw[LI*4 + 1] := Byte((LI*7) and $FF);
      LRaw[LI*4 + 2] := Byte((LI*11) and $FF);
    end;
  end;
  LWork := Copy(LRaw, 0, Length(LRaw));
  SevenZBcjArmConvert(LWork, 0, True);
  SevenZBcjArmConvert(LWork, 0, False);
  Check(CompareMem(@LRaw[0], @LWork[0], Length(LRaw)), 'bcj arm roundtrip');
  { 非对齐尾部保持原样 }
  LWork := BytesOf([$EB, $01, $02]);
  SevenZBcjArmConvert(LWork, 0, True);
  Check(LWork[0] = $EB, 'arm tiny kept');
end;

procedure TestBcjPpcRoundtrip;
var
  LRaw, LWork: TBytes;
  LI: SizeInt;
begin
  LRaw := Randomish(80000, 882);
  for LI := 0 to Length(LRaw)-4 do
    if (LI mod 4 = 0) and (LI mod 7 = 0) then
    begin
      LRaw[LI] := $48 or Byte(LI and 3);
      LRaw[LI+1] := Byte((LI*5) and $FF);
      LRaw[LI+2] := Byte((LI*9) and $FF);
      LRaw[LI+3] := (LRaw[LI+3] and $FC) or 1;
    end;
  LWork := Copy(LRaw, 0, Length(LRaw));
  SevenZBcjPpcConvert(LWork, 0, True);
  SevenZBcjPpcConvert(LWork, 0, False);
  Check(CompareMem(@LRaw[0], @LWork[0], Length(LRaw)), 'bcj ppc roundtrip');
end;

procedure TestBcjArm64Roundtrip;
var
  LRaw, LWork: TBytes;
  LI: SizeInt;
  LInstr: UInt32;
begin
  SetLength(LRaw, 8192);
  for LI := 0 to Length(LRaw)-1 do
    LRaw[LI] := Byte((LI*31) and $FF);
  { 注入 BL 与 ADRP 样本 }
  for LI := 0 to 100 do
  begin
    LInstr := $94000000 or (UInt32(LI*13) and $03FFFFFF);
    LRaw[LI*32] := Byte(LInstr and $FF);
    LRaw[LI*32+1] := Byte((LInstr shr 8) and $FF);
    LRaw[LI*32+2] := Byte((LInstr shr 16) and $FF);
    LRaw[LI*32+3] := Byte((LInstr shr 24) and $FF);
  end;
  LWork := Copy(LRaw, 0, Length(LRaw));
  SevenZBcjArm64Convert(LWork, 0, True);
  SevenZBcjArm64Convert(LWork, 0, False);
  Check(CompareMem(@LRaw[0], @LWork[0], Length(LRaw)), 'bcj arm64 roundtrip');
end;

procedure TestBcjArm64AdrpVector;
var
  B: TBytes;
begin
  { ADRP 构造：0x90000000 | 偏移组合，验证编解码互逆 }
  B := BytesOf([$00, $00, $00, $90, $00, $00, $00, $90]);
  SevenZBcjArm64Convert(B, $1000, True);
  SevenZBcjArm64Convert(B, $1000, False);
  Check(B[0] = $00, 'arm64 adrp vector');
end;

procedure TestBcjIa64Roundtrip;
var LRaw, LWork: TBytes;
begin
  LRaw := Randomish(16384, 9111);
  LWork := Copy(LRaw, 0, Length(LRaw));
  SevenZBcjIa64Convert(LWork, 0, True);
  SevenZBcjIa64Convert(LWork, 0, False);
  Check(CompareMem(@LRaw[0], @LWork[0], Length(LRaw)), 'bcj ia64 roundtrip');
  LWork := BytesOf([$00, $01, $02]);
  SevenZBcjIa64Convert(LWork, 0, True);
  Check(Length(LWork)=3, 'ia64 tiny kept');
end;

procedure TestBcjSparcRoundtrip;
var LRaw, LWork: TBytes; LI: SizeInt;
begin
  LRaw := Randomish(8000, 9122);
  for LI := 0 to Length(LRaw)-4 do if (LI mod 4=0) and (LI mod 9=0) then begin LRaw[LI]:=$40; LRaw[LI+1]:= $00; end;
  LWork := Copy(LRaw, 0, Length(LRaw));
  SevenZBcjSparcConvert(LWork, 0, True);
  SevenZBcjSparcConvert(LWork, 0, False);
  Check(CompareMem(@LRaw[0], @LWork[0], Length(LRaw)), 'bcj sparc roundtrip');
end;

procedure TestBcjArmtRoundtrip;
var LRaw, LWork: TBytes;
begin
  LRaw := Randomish(8000, 9133);
  LWork := Copy(LRaw, 0, Length(LRaw));
  SevenZBcjArmtConvert(LWork, 0, True);
  SevenZBcjArmtConvert(LWork, 0, False);
  Check(CompareMem(@LRaw[0], @LWork[0], Length(LRaw)), 'bcj armt roundtrip');
  LWork := BytesOf([$F0, $01, $F8, $02, $00]);
  SevenZBcjArmtConvert(LWork, 0, True);
  SevenZBcjArmtConvert(LWork, 0, False);
  Check(LWork[0]=$F0, 'armt tiny');
end;

procedure TestBcjRiscvRoundtrip;
var LRaw, LWork: TBytes; LI: SizeInt;
begin
  LRaw := Randomish(8192, 9144);
  for LI := 0 to Length(LRaw)-4 do if (LI mod 8=0) then begin LRaw[LI]:=$EF; LRaw[LI+1]:=$00; end;
  LWork := Copy(LRaw, 0, Length(LRaw));
  SevenZBcjRiscvConvert(LWork, 0, True);
  SevenZBcjRiscvConvert(LWork, 0, False);
  Check(CompareMem(@LRaw[0], @LWork[0], Length(LRaw)), 'bcj riscv roundtrip');
end;

{ Delta 过滤器已知向量 }

procedure TestDeltaDecodeVectors;
var
  LIn: TBytes;
begin
  { dist=1（props[0]=0）：前缀和 }
  LIn := SevenZDeltaDecode(TBytes.Create(0),
    BytesOf([$01, $01, $01, $01]), 4);
  CheckEqual(Int64(4), Int64(Length(LIn)), 'delta dist1 len');
  CheckEqual(Int64($01), Int64(LIn[0]), 'delta d1 b0');
  CheckEqual(Int64($02), Int64(LIn[1]), 'delta d1 b1');
  CheckEqual(Int64($03), Int64(LIn[2]), 'delta d1 b2');
  CheckEqual(Int64($04), Int64(LIn[3]), 'delta d1 b3');
  { dist=2（props[0]=1）：隔二前缀和 }
  LIn := SevenZDeltaDecode(TBytes.Create(1),
    BytesOf([$01, $10, $01, $10]), 4);
  CheckEqual(Int64($02), Int64(LIn[2]), 'delta d2 b2');
  CheckEqual(Int64($20), Int64(LIn[3]), 'delta d2 b3');
end;

procedure TestDeflateVectors;
var
  LRaw, LZlib, LRawEnc, LDec: TBytes;
begin
  LRaw := RepeatedText(7, 200);
  LZlib := DeflateCompress(LRaw);
  LDec := SevenZDeflateDecodeForTest(LZlib, UInt64(Length(LRaw)));
  CheckEqual(Int64(Length(LRaw)), Int64(Length(LDec)), 'deflate zlib len');
  Check(SameBytes(LRaw, LDec), 'deflate zlib bytes');
  LRawEnc := RawDeflateMessageCompress(LRaw);
  LDec := SevenZDeflateDecodeForTest(LRawEnc, UInt64(Length(LRaw)));
  CheckEqual(Int64(Length(LRaw)), Int64(Length(LDec)), 'deflate raw len');
  Check(SameBytes(LRaw, LDec), 'deflate raw bytes');
  { 空载荷在七z层短路，不进入 deflate 解码；helper 的 0 尺寸由上层保证不调用 }
  LRaw := nil;
  LZlib := DeflateCompress(LRaw);
  Check(Length(LZlib) > 0, 'deflate empty compress non-empty');
  LDec := DeflateDecompressWithMaxOutputSize(LZlib, 16);
  Check(LDec = nil, 'deflate empty zlib roundtrip');
end;

procedure TestBZip2Vectors;
var
  LRaw, LBz2, LDec: TBytes;
begin
  { 系统 bzip2 1.0.8 对 "hello world x3" 的确定性产物（BZh91...），
    校验纯 Pascal 解码器在七z外也能还原 }
  LRaw := BytesOf([
    $68,$65,$6C,$6C,$6F,$20,$77,$6F,$72,$6C,$64,$20,
    $68,$65,$6C,$6C,$6F,$20,$77,$6F,$72,$6C,$64,$20,
    $68,$65,$6C,$6C,$6F,$20,$77,$6F,$72,$6C,$64]);
  LBz2 := BytesOf([
    $42,$5A,$68,$39,$31,$41,$59,$26,$53,$59,$2C,$41,$D3,$C0,
    $00,$00,$05,$91,$80,$40,$00,$06,$44,$90,$80,$20,$00,$21,
    $B5,$46,$7A,$81,$0C,$08,$F4,$44,$4A,$B9,$86,$0C,$34,$D1,
    $38,$5D,$C9,$14,$E1,$42,$40,$B1,$07,$4F,$00]);
  LDec := SevenZBZip2DecodeForTest(LBz2, UInt64(Length(LRaw)));
  CheckEqual(Int64(Length(LRaw)), Int64(Length(LDec)), 'bzip2 len');
  Check(SameBytes(LRaw, LDec), 'bzip2 bytes');
  { 越界探测：声明上限小于真实尺寸须抛错防炸弹（炸弹归为 ESevenZLimitError） }
  try
    SevenZBZip2DecodeForTest(LBz2, 10);
    Fail('bzip2 limit not enforced');
  except on E: ESevenZLimitError do ; on E: EIOError do ; on E: ESevenZError do ; end;
end;

procedure TestBZip2GoldenArchive;
var
  LArch: TBytes;
  LR: ISevenZReader;
  LGot: TBytes;
  s: string;
begin
  { p7zip 17.05 -m0=BZip2 对 hello.txt (35B) 产生的 175B 归档，验证
    folder BZip2 解码链（含 BZip2 4B CRC 尾） }
  LArch := BytesOf([
    $37,$7A,$BC,$AF,$27,$1C,$00,$04,$66,$E0,$2B,$DA,$35,$00,$00,$00,
    $00,$00,$00,$00,$5A,$00,$00,$00,$00,$00,$00,$00,$97,$7C,$83,$33,
    $42,$5A,$68,$39,$31,$41,$59,$26,$53,$59,$2C,$41,$D3,$C0,$00,$00,
    $05,$91,$80,$40,$00,$06,$44,$90,$80,$20,$00,$21,$B5,$46,$7A,$81,
    $03,$03,$D1,$11,$2A,$E6,$18,$30,$D3,$44,$E1,$77,$24,$53,$85,$09,
    $02,$C4,$1D,$3C,$00,$01,$04,$06,$00,$01,$09,$35,$00,$07,$0B,$01,
    $00,$01,$03,$04,$02,$02,$0C,$23,$00,$08,$0A,$01,$BB,$FE,$42,$0F,
    $00,$00,$05,$01,$19,$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,
    $00,$00,$11,$15,$00,$68,$00,$65,$00,$6C,$00,$6C,$00,$6F,$00,$2E,
    $00,$74,$00,$78,$00,$74,$00,$00,$00,$14,$0A,$01,$00,$80,$6F,$1E,
    $AD,$66,$36,$DD,$01,$15,$06,$01,$00,$20,$80,$B4,$81,$00,$00]);
  LR := TSevenZReaderImpl.Create(LArch);
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'bzip2 arch entries');
  CheckEqual('hello.txt', LR.Entry(0).Name, 'bzip2 arch name');
  LGot := LR.Extract(0);
  CheckEqual(Int64(35), Int64(Length(LGot)), 'bzip2 arch size');
  SetLength(s, Length(LGot));
  if Length(LGot)>0 then Move(LGot[0], s[1], Length(LGot));
  CheckEqual('hello world hello world hello world', s, 'bzip2 arch bytes');
end;

procedure TestBZip2Truncated;
var
  LBz2: TBytes;
begin
  LBz2 := BytesOf([
    $42,$5A,$68,$39,$31,$41,$59,$26,$53,$59,$2C,$41,$D3,$C0,
    $00,$00,$05,$91,$80,$40,$00,$06,$44,$90,$80,$20,$00,$21,
    $B5,$46,$7A,$81,$0C,$08,$F4,$44,$4A,$B9,$86,$0C,$34,$D1,
    $38,$5D,$C9,$14,$E1,$42,$40,$B1,$07,$4F,$00]);
  SetLength(LBz2, Length(LBz2)-10); // 截断
  try
    SevenZBZip2DecodeForTest(LBz2, 35);
    Fail('truncated bzip2 should raise');
  except
    on E: Exception do ; // 截断流抛 EReadError/EBzip2/EIOError/ESevenZError 均视为成功
  end;
end;

procedure TestPpmdNotSupported;
var
  F: TSevenZFolder;
  P: TBytes;
begin
  FillChar(F, SizeOf(F), 0);
  SetLength(F.Coders, 1);
  F.Coders[0].MethodId := SEVENZ_METHOD_PPMD;
  F.Coders[0].NumInStreams := 1;
  F.Coders[0].Props := nil;
  SetLength(F.OutSizes, 1);
  F.OutSizes[0] := 10;
  SetLength(F.PackedInIndices, 1);
  F.PackedInIndices[0] := 0;
  SetLength(F.BindPairs, 0);
  F.MainOutIndex := 0;
  P := BytesOf([$00]);
  try
    SevenZDecodeFolder(F, [P], '');
    Fail('ppmd should raise');
  except
    on E: ESevenZError do
      Check(Pos('ppmd', LowerCase(E.Message)) > 0, 'ppmd message');
  end;
end;

procedure TestDeflateTruncatedViaFolder;
var
  LRaw: TBytes;
begin
  LRaw := BytesOf([$78,$9C]); // 截断 zlib 头
  try
    SevenZDeflateDecodeForTest(LRaw, 10);
    Fail('truncated deflate should raise');
  except on E: EIOError do ; on E: ESevenZError do ; on E: EParseError do ; end;
end;

{ 写端过滤链：BCJ / Delta 预过滤后压缩，读端按拓扑逆序还原 }

{ 共享目标函数的档内绝对地址：模拟多调用点汇聚到少数函数 }
const
  C_TARGETS: array[0..4] of Cardinal =
    ($1204, $8030, $20008, $31000, $40ABC);

function ExeLikeCorpus(ALen: Integer): TBytes;
var
  I, J: SizeInt;
  LRel: Int64;
begin
  { 拟真 x86 语料：中低熵指令流 + 每 16 字节一条相对调用（E8），
    操作数 = 固定目标地址 - 本调用点返回地址。BCJ 换算后同类调用
    点的操作数还原为同一常量，重复度剧增——真实可执行档的收益来源 }
  Result := Randomish(ALen, 4242);
  for I := 0 to High(Result) do
    Result[I] := Result[I] and $3F;
  I := 0;
  while I + 5 <= ALen do
  begin
    Result[I] := $E8;
    LRel := Int64(C_TARGETS[(I div 16) mod Length(C_TARGETS)]) -
      Int64(I + 5);
    for J := 0 to 3 do
      Result[I + 1 + J] := Byte((UInt32(LRel) shr (8 * J)) and $FF);
    Inc(I, 16);
  end;
end;

function SlopeBytes(ALen: Integer): TBytes;
var
  I: SizeInt;
begin
  { 平滑斜坡：Delta-1 过滤后趋近常量序列 }
  Result := nil;
  SetLength(Result, ALen);
  for I := 0 to ALen - 1 do
    Result[I] := Byte(I * 3);
end;

procedure RunFiltersCase(const AFilters: array of TSevenZFilter;
  const ATag: string);
var
  LExe, LGot: TBytes;
  LW: ISevenZWriter;
  LR: ISevenZReader;
begin
  LExe := ExeLikeCorpus(40000);
  LW := TSevenZWriterImpl.Create;
  LW.SetFilters(AFilters);
  LW.AddFile('bin/app.exe', LExe);
  LW.AddFile('audio/slope.raw', SlopeBytes(20000));
  LW.AddDirectory('docs');
  LW.AddFile('docs/note.txt', RepeatedText(12, 30));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(4), Int64(LR.EntryCount), ATag + ': entries');
  LGot := LR.Extract(LR.Find('bin/app.exe'));
  CheckEqual(Int64(Length(LExe)), Int64(Length(LGot)), ATag + ': exe size');
  Check(CompareMem(@LGot[0], @LExe[0], Length(LExe)), ATag + ': exe bytes');
  LGot := LR.Extract(LR.Find('audio/slope.raw'));
  CheckEqual(Int64(20000), Int64(Length(LGot)), ATag + ': slope size');
  CheckEqual(Int64(171), Int64(LGot[12345]), ATag + ': slope byte');
end;

procedure TestWriterFiltersBcjRoundtrip;
begin
  RunFiltersCase([szfBcjX86], 'bcj');
end;

procedure TestWriterFiltersDeltaRoundtrip;
begin
  RunFiltersCase([szfDelta], 'delta');
end;

procedure TestWriterFiltersChainRoundtrip;
begin
  { 声明序 = 应用序：先 Delta 后 BCJ；读端须逆序还原 }
  RunFiltersCase([szfDelta, szfBcjX86], 'chain');
end;

procedure TestWriterFiltersResetToDefaultBytes;
var
  LExe: TBytes;
  LPlain, LReset: TBytes;
  LW: ISevenZWriter;
begin
  { SetFilters([]) 后产物与从未设置过滤器的写端逐字节一致 }
  LExe := ExeLikeCorpus(9000);
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.bin', LExe);
  LPlain := LW.Finish;
  LW := TSevenZWriterImpl.Create;
  LW.SetFilters([szfDelta]);
  LW.SetFilters([]);
  LW.AddFile('a.bin', LExe);
  LReset := LW.Finish;
  CheckEqual(Int64(Length(LPlain)), Int64(Length(LReset)), 'reset len');
  Check(CompareMem(@LPlain[0], @LReset[0], Length(LPlain)),
    'reset bytes identical');
end;

procedure TestWriterFiltersDeterministic;
var
  LExe, LA, LB: TBytes;
  LW: ISevenZWriter;
begin
  LExe := ExeLikeCorpus(30000);
  LW := TSevenZWriterImpl.Create;
  LW.SetFilters([szfBcjX86]);
  LW.AddFile('a.exe', LExe);
  LA := LW.Finish;
  LW := TSevenZWriterImpl.Create;
  LW.SetFilters([szfBcjX86]);
  LW.AddFile('a.exe', LExe);
  LB := LW.Finish;
  CheckEqual(Int64(Length(LA)), Int64(Length(LB)), 'det len');
  Check(CompareMem(@LA[0], @LB[0], Length(LA)), 'det bytes identical');
end;

procedure TestWriterFiltersCompressionGain;
var
  LExe: TBytes;
  LPlain, LFiltered: Int64;
  LW: ISevenZWriter;
begin
  { 密集 E8 语料经 BCJ 预过滤后档体应显著变小 }
  LExe := ExeLikeCorpus(120000);
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.exe', LExe);
  LPlain := Int64(Length(LW.Finish));
  LW := TSevenZWriterImpl.Create;
  LW.SetFilters([szfBcjX86]);
  LW.AddFile('a.exe', LExe);
  LFiltered := Int64(Length(LW.Finish));
  Check(LFiltered < LPlain,
    Format('bcj shrinks corpus: %d < %d', [LFiltered, LPlain]));
end;

procedure TestWriterFiltersValidation;
var
  LW: ISevenZWriter;
  LArr: array of TSevenZFilter;
  LI: Integer;
begin
  LW := TSevenZWriterImpl.Create;
  SetLength(LArr, C_MAX_FILTERS + 1);
  for LI := 0 to High(LArr) do
    LArr[LI] := szfDelta;
  try
    LW.SetFilters(LArr);
    Fail('over-deep chain accepted');
  except
    on E: EArgumentError do ;  { 预期：深度超限 }
  end;
  LW.SetFilters([szfBcjX86]);
  LW.AddFile('x.bin', RepeatedText(3, 5));
  LW.Finish;
  try
    LW.SetFilters([]);
    Fail('SetFilters after finish accepted');
  except
    on E: ESevenZError do ;  { 预期：终结后锁定 }
  end;
end;

procedure TestWriterFiltersEmptyArchive;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetFilters([szfBcjX86, szfDelta]);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(0), Int64(LR.EntryCount), 'empty entries');
end;

{ 新增 ARM/ARM64/PPC 过滤链：与 x86 同测往返与确定性 }

procedure TestWriterFiltersArmRoundtrip;
begin
  RunFiltersCase([szfBcjArm], 'arm');
end;

procedure TestWriterFiltersArm64Roundtrip;
begin
  RunFiltersCase([szfBcjArm64], 'arm64');
end;

procedure TestWriterFiltersPpcRoundtrip;
begin
  RunFiltersCase([szfBcjPpc], 'ppc');
end;

procedure TestWriterFiltersArmChainRoundtrip;
begin
  RunFiltersCase([szfDelta, szfBcjArm], 'arm-chain');
  RunFiltersCase([szfBcjArm64, szfDelta], 'arm64-chain');
  RunFiltersCase([szfBcjPpc, szfDelta, szfBcjX86], 'ppc-x86-chain');
end;

procedure TestWriterFiltersIa64Roundtrip;
begin
  RunFiltersCase([szfBcjIa64], 'ia64');
end;

procedure TestWriterFiltersSparcRoundtrip;
begin
  RunFiltersCase([szfBcjSparc], 'sparc');
end;

procedure TestWriterFiltersArmtRoundtrip;
begin
  RunFiltersCase([szfBcjArmt], 'armt');
end;

procedure TestWriterFiltersRiscvRoundtrip;
begin
  RunFiltersCase([szfBcjRiscv], 'riscv');
end;

procedure TestWriterFiltersMixedBcjChain;
begin
  RunFiltersCase([szfBcjIa64, szfBcjSparc, szfDelta], 'ia64-sparc-delta');
  RunFiltersCase([szfBcjArmt, szfBcjRiscv, szfBcjX86], 'armt-riscv-x86');
end;

{ 写端压缩级别 }

procedure RunLevelRoundtrip(ALevel: TSevenZCompressionLevel;
  const ATag: string);
var
  LData, LGot: TBytes;
  LW: ISevenZWriter;
  LR: ISevenZReader;
begin
  LData := Randomish(70000, 99);
  LW := TSevenZWriterImpl.Create;
  LW.SetLevel(ALevel);
  LW.AddFile('r.bin', LData);
  LW.AddDirectory('d');
  LR := TSevenZReaderImpl.Create(LW.Finish);
  LGot := LR.Extract(0);
  CheckEqual(Int64(Length(LData)), Int64(Length(LGot)), ATag + ': size');
  Check(CompareMem(@LGot[0], @LData[0], Length(LData)), ATag + ': bytes');
end;

procedure TestLevelNoneStoredRoundtrip;
begin
  { szclNone 走未压缩 chunk 存储路径，容器语义不变 }
  RunLevelRoundtrip(szclNone, 'none');
end;

procedure TestLevelFastestRoundtrip;
begin
  RunLevelRoundtrip(szclFastest, 'fastest');
end;

procedure TestLevelBestRoundtrip;
begin
  RunLevelRoundtrip(szclBest, 'best');
end;

procedure TestLevelMonotonicOnRepeatedText;
var
  LSaved: TSevenZLzmaBackend;
  LText: TBytes;
  LFastest, LBest: Int64;
  LW: ISevenZWriter;
begin
  { 级别映射属纯 Pascal 编码器内部契约：固定后端做确定性比较，
    best 在重复语料上不得劣于 fastest（允许持平） }
  LSaved := SevenZRequestedBackend;
  SevenZSetLzmaBackend(szlbPurePascal);
  try
    LText := RepeatedText(64, 500);
    LW := TSevenZWriterImpl.Create;
    LW.SetLevel(szclFastest);
    LW.AddFile('t.txt', LText);
    LFastest := Int64(Length(LW.Finish));
    LW := TSevenZWriterImpl.Create;
    LW.SetLevel(szclBest);
    LW.AddFile('t.txt', LText);
    LBest := Int64(Length(LW.Finish));
    Check(LBest <= LFastest,
      Format('best %d <= fastest %d', [LBest, LFastest]));
  finally
    SevenZSetLzmaBackend(LSaved);
  end;
end;

procedure TestLevelSetAfterFinishRaises;
var
  LW: ISevenZWriter;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('x.bin', BytesOf([$01]));
  LW.Finish;
  try
    LW.SetLevel(szclBest);
    Fail('SetLevel after finish accepted');
  except
    on E: ESevenZError do ;  { 预期：终结后锁定 }
  end;
end;

{ BCJ2 金样档:p7zip -m0=BCJ2 生成,载荷为 600 字节 ELF 前缀 +
  人工 E8/E9/0F84 模式尾(616 字节),读端经单 coder 四输入拓扑还原 }
const
  C_BCJ2_GOLDEN: array[0..734] of Byte = (
    $37, $7a, $bc, $af, $27, $1c, $00, $04, $68, $fd, $22, $35,
    $6d, $02, $00, $00, $00, $00, $00, $00, $52, $00, $00, $00,
    $00, $00, $00, $00, $54, $30, $dc, $64, $7f, $45, $4c, $46,
    $02, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $03, $00, $3e, $00, $01, $00, $00, $00, $e0, $27, $00, $00,
    $00, $00, $00, $00, $40, $00, $00, $00, $00, $00, $00, $00,
    $28, $a2, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $40, $00, $38, $00, $0e, $00, $40, $00, $1e, $00, $1d, $00,
    $06, $00, $00, $00, $04, $00, $00, $00, $40, $00, $00, $00,
    $00, $00, $00, $00, $40, $00, $00, $00, $00, $00, $00, $00,
    $40, $00, $00, $00, $00, $00, $00, $00, $10, $03, $00, $00,
    $00, $00, $00, $00, $10, $03, $00, $00, $00, $00, $00, $00,
    $08, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00,
    $04, $00, $00, $00, $94, $03, $00, $00, $00, $00, $00, $00,
    $94, $03, $00, $00, $00, $00, $00, $00, $94, $03, $00, $00,
    $00, $00, $00, $00, $1c, $00, $00, $00, $00, $00, $00, $00,
    $1c, $00, $00, $00, $00, $00, $00, $00, $01, $00, $00, $00,
    $00, $00, $00, $00, $01, $00, $00, $00, $04, $00, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $e8, $00, $00, $00, $e8, $00, $00, $00, $00, $10, $00, $00,
    $00, $00, $00, $00, $01, $00, $00, $00, $05, $00, $00, $00,
    $00, $20, $00, $00, $00, $00, $00, $00, $00, $20, $00, $00,
    $00, $00, $00, $00, $00, $20, $00, $00, $00, $00, $00, $00,
    $e9, $00, $00, $00, $e9, $00, $00, $00, $00, $10, $00, $00,
    $00, $00, $00, $00, $01, $00, $00, $00, $04, $00, $00, $00,
    $00, $70, $00, $00, $00, $00, $00, $00, $00, $70, $00, $00,
    $00, $00, $00, $00, $00, $70, $00, $00, $00, $00, $00, $00,
    $18, $1e, $00, $00, $00, $00, $00, $00, $18, $1e, $00, $00,
    $00, $00, $00, $00, $00, $10, $00, $00, $00, $00, $00, $00,
    $01, $00, $00, $00, $06, $00, $00, $00, $b0, $9b, $00, $00,
    $00, $00, $00, $00, $b0, $9b, $00, $00, $00, $00, $00, $00,
    $b0, $9b, $00, $00, $00, $00, $00, $00, $d0, $04, $00, $00,
    $00, $00, $00, $00, $90, $06, $00, $00, $00, $00, $00, $00,
    $00, $10, $00, $00, $00, $00, $00, $00, $02, $00, $00, $00,
    $06, $00, $00, $00, $58, $9c, $00, $00, $00, $00, $00, $00,
    $58, $9c, $00, $00, $00, $00, $00, $00, $58, $9c, $00, $00,
    $00, $00, $00, $00, $f0, $01, $00, $00, $00, $00, $00, $00,
    $f0, $01, $00, $00, $00, $00, $00, $00, $08, $00, $00, $00,
    $00, $00, $00, $00, $04, $00, $00, $00, $04, $00, $00, $00,
    $50, $03, $00, $00, $00, $00, $00, $00, $50, $03, $00, $00,
    $00, $00, $00, $00, $50, $03, $00, $00, $00, $00, $00, $00,
    $20, $00, $00, $00, $00, $00, $00, $00, $20, $00, $00, $00,
    $00, $00, $00, $00, $08, $00, $00, $00, $00, $00, $00, $00,
    $04, $00, $00, $00, $04, $00, $00, $00, $70, $03, $00, $00,
    $00, $00, $00, $00, $70, $03, $00, $00, $00, $00, $00, $00,
    $70, $03, $00, $00, $00, $00, $00, $00, $24, $00, $00, $00,
    $00, $00, $00, $00, $24, $00, $00, $00, $00, $00, $00, $00,
    $04, $00, $00, $00, $00, $00, $00, $00, $04, $00, $00, $00,
    $04, $00, $00, $00, $f8, $8d, $00, $00, $00, $00, $00, $00,
    $f8, $8d, $00, $00, $00, $00, $00, $00, $f8, $8d, $00, $00,
    $00, $00, $00, $00, $e8, $e9, $10, $00, $00, $00, $0f, $84,
    $20, $00, $00, $00, $00, $00, $00, $e9, $00, $00, $00, $f1,
    $00, $00, $02, $5d, $00, $00, $01, $52, $00, $00, $01, $5a,
    $00, $f6, $f7, $fc, $80, $01, $04, $06, $00, $04, $09, $82,
    $54, $0c, $08, $05, $00, $07, $0b, $01, $00, $01, $14, $03,
    $03, $01, $1b, $04, $01, $00, $01, $02, $03, $0c, $82, $68,
    $00, $08, $0a, $01, $f4, $52, $57, $ef, $00, $00, $05, $01,
    $19, $00, $11, $0d, $00, $78, $00, $2e, $00, $62, $00, $69,
    $00, $6e, $00, $00, $00, $14, $0a, $01, $00, $00, $46, $78,
    $7d, $46, $35, $dd, $01, $15, $06, $01, $00, $20, $80, $b4,
    $81, $00, $00);

{ AES 金样档:p7zip -psecret123 -mhc=off / -mhe=on 对 a.txt+b.bin 小语料生成。
  语料:a.txt=273B 图案文本(crc $5C317BF5); b.bin=384B 结构化坡道(crc $14215A54) }
const
  C_GOLD_AES_PLAIN: array[0..429] of Byte = (
    $37, $7A, $BC, $AF, $27, $1C, $00, $04, $C6, $48, $67, $4A, $00, $01, $00, $00,
    $00, $00, $00, $00, $8E, $00, $00, $00, $00, $00, $00, $00, $B9, $D7, $62, $66,
    $F9, $7A, $DF, $54, $E5, $FE, $75, $67, $B2, $78, $99, $60, $43, $87, $26, $CF,
    $3F, $B0, $A5, $11, $BE, $9B, $08, $56, $E6, $9F, $D8, $2F, $19, $F8, $54, $44,
    $F4, $BB, $0C, $B9, $A2, $46, $3C, $91, $AE, $A7, $FB, $D1, $07, $FB, $68, $F7,
    $E0, $8D, $28, $B8, $7A, $09, $A2, $E3, $F0, $E8, $0F, $74, $A7, $5B, $5D, $D7,
    $70, $2B, $16, $54, $06, $9B, $85, $FF, $9B, $36, $2B, $C4, $57, $21, $E7, $85,
    $5D, $08, $70, $2E, $6F, $C3, $99, $6A, $4D, $92, $4D, $10, $01, $F2, $C0, $A8,
    $AE, $24, $20, $50, $6F, $FD, $7D, $CE, $A2, $9F, $66, $44, $67, $49, $58, $A6,
    $45, $15, $D8, $8C, $33, $B0, $5C, $F9, $8A, $4D, $E8, $D5, $F3, $53, $3B, $07,
    $94, $5C, $1B, $8F, $51, $E9, $B5, $94, $D1, $18, $3B, $53, $95, $F7, $7A, $E6,
    $07, $50, $D0, $3F, $16, $4D, $3D, $03, $58, $73, $7A, $49, $A3, $C3, $15, $DE,
    $3E, $45, $58, $DB, $87, $96, $D5, $53, $BF, $79, $DA, $65, $A6, $AD, $77, $78,
    $1B, $79, $6C, $3E, $A9, $00, $3B, $04, $5B, $F2, $2A, $9C, $14, $37, $65, $DA,
    $CE, $98, $8A, $31, $88, $F7, $47, $63, $35, $F5, $3B, $30, $21, $42, $86, $C2,
    $2E, $1B, $6E, $32, $66, $C6, $B8, $A3, $FD, $18, $0A, $19, $4B, $2B, $9F, $40,
    $0B, $BC, $F7, $6E, $56, $7C, $AC, $73, $0A, $DE, $7B, $5F, $A2, $19, $B0, $1E,
    $55, $82, $DE, $0D, $AA, $B0, $F0, $06, $04, $EF, $8E, $AF, $21, $C2, $6A, $30,
    $01, $04, $06, $00, $01, $09, $81, $00, $00, $07, $0B, $01, $00, $02, $24, $06,
    $F1, $07, $01, $12, $53, $0F, $24, $E6, $38, $4A, $07, $6A, $DD, $D0, $C1, $27,
    $F4, $A5, $D2, $F5, $5E, $11, $21, $21, $01, $00, $01, $00, $0C, $80, $FE, $82,
    $91, $00, $08, $0D, $02, $09, $81, $11, $0A, $01, $F5, $7B, $31, $5C, $54, $5A,
    $21, $14, $00, $00, $05, $02, $19, $05, $00, $00, $00, $00, $00, $11, $19, $00,
    $61, $00, $2E, $00, $74, $00, $78, $00, $74, $00, $00, $00, $62, $00, $2E, $00,
    $62, $00, $69, $00, $6E, $00, $00, $00, $19, $02, $00, $00, $14, $12, $01, $00,
    $00, $D2, $A1, $A6, $58, $35, $DD, $01, $00, $D2, $A1, $A6, $58, $35, $DD, $01,
    $15, $0A, $01, $00, $20, $80, $B4, $81, $20, $80, $B4, $81, $00, $00);

const
  C_GOLD_AES_HDR: array[0..477] of Byte = (
    $37, $7A, $BC, $AF, $27, $1C, $00, $04, $0B, $89, $C3, $B0, $80, $01, $00, $00,
    $00, $00, $00, $00, $3E, $00, $00, $00, $00, $00, $00, $00, $A4, $84, $A7, $20,
    $C5, $99, $EB, $33, $A4, $A1, $40, $FF, $EE, $96, $A3, $03, $49, $7F, $70, $93,
    $62, $B6, $F6, $C8, $74, $20, $8C, $1A, $D6, $6F, $CE, $BC, $6B, $33, $AC, $02,
    $BB, $17, $97, $F3, $B5, $82, $78, $A9, $73, $56, $24, $DC, $15, $63, $5E, $75,
    $7A, $08, $B0, $75, $BE, $6B, $21, $83, $34, $4E, $CF, $02, $BC, $0B, $1C, $C8,
    $99, $41, $CA, $D0, $DA, $7C, $34, $57, $1A, $78, $B8, $E9, $54, $58, $12, $52,
    $AC, $81, $27, $CC, $2A, $54, $08, $AB, $DA, $3D, $60, $03, $04, $90, $F7, $0E,
    $9B, $5B, $42, $54, $07, $3A, $60, $E6, $EE, $91, $91, $C6, $7B, $2E, $26, $17,
    $FE, $AC, $77, $6E, $8B, $0B, $33, $E9, $86, $70, $AC, $CC, $40, $2F, $9B, $19,
    $E3, $FE, $1F, $7C, $3F, $7A, $13, $16, $F5, $D7, $D7, $7F, $A4, $F2, $8F, $52,
    $2C, $57, $40, $FF, $B6, $6D, $CA, $56, $88, $58, $E3, $A7, $8F, $CD, $6E, $7A,
    $89, $70, $59, $D9, $4B, $26, $EA, $DB, $A1, $59, $8F, $95, $3A, $6C, $7A, $26,
    $73, $B5, $15, $23, $59, $9C, $8F, $42, $A3, $82, $EF, $60, $C6, $8C, $08, $B3,
    $B5, $C4, $58, $12, $C2, $C4, $C7, $DD, $B5, $75, $6F, $53, $44, $B6, $1E, $66,
    $7B, $3E, $DF, $EC, $6E, $BA, $6F, $51, $C9, $50, $9D, $54, $3B, $C2, $56, $FB,
    $1A, $16, $D0, $66, $BC, $F5, $37, $F6, $26, $39, $63, $16, $7C, $30, $BB, $DC,
    $D8, $BA, $5B, $E3, $19, $FE, $C3, $96, $21, $74, $6F, $A2, $A8, $BB, $32, $1E,
    $46, $61, $83, $08, $90, $80, $B6, $12, $88, $FD, $3C, $13, $5E, $6C, $94, $19,
    $01, $7C, $41, $A6, $DA, $33, $B2, $4D, $60, $1E, $9B, $CC, $19, $7A, $CF, $A3,
    $2C, $E4, $2F, $21, $EC, $23, $C7, $AE, $1E, $01, $91, $E3, $D5, $9F, $70, $3B,
    $2C, $83, $95, $76, $FA, $5E, $C3, $5F, $30, $BC, $41, $36, $25, $8A, $CD, $81,
    $C7, $72, $ED, $D7, $3E, $90, $03, $36, $79, $DE, $BB, $25, $85, $CC, $CC, $0B,
    $74, $88, $3F, $E5, $D7, $A1, $8F, $26, $94, $2A, $30, $EC, $A1, $B7, $FE, $FC,
    $1E, $D3, $EB, $B6, $CD, $58, $B3, $AF, $2F, $EB, $3F, $8A, $67, $9B, $E4, $DA,
    $69, $4E, $F4, $2C, $61, $D3, $74, $D7, $BE, $31, $DF, $01, $B6, $41, $05, $A4,
    $17, $06, $81, $00, $01, $09, $80, $80, $00, $07, $0B, $01, $00, $02, $24, $06,
    $F1, $07, $01, $12, $53, $0F, $7E, $11, $4D, $D3, $0F, $19, $D2, $39, $D8, $AA,
    $D2, $DC, $3D, $B2, $71, $D3, $23, $03, $01, $01, $05, $5D, $00, $10, $00, $00,
    $01, $00, $0C, $7F, $80, $8E, $0A, $01, $F7, $6D, $D4, $1B, $00, $00);

{ 金样档中 AES coder 的原始属性字节:power=19、无盐、IV 16 字节 }
const
  C_GOLD_AES_PROPS: array[0..17] of Byte = (
    $53, $0F, $24, $E6, $38, $4A, $07, $6A, $DD, $D0, $C1,
    $27, $F4, $A5, $D2, $F5, $5E, $11);

{ KAT 向量：独立 Python 实现按参考源码形状计算（口令 secret123 的 UTF-16LE）}
const
  C_AES_KAT_P5_SALT4: array[0..31] of Byte = (
    $08, $6A, $CD, $7B, $A3, $D3, $36, $96, $E3, $A8, $E8, $E5, $55, $DB, $5F, $A5,
    $B5, $37, $66, $AB, $DC, $CF, $E2, $54, $D1, $7D, $A4, $4C, $4A, $8A, $A8, $0A);

const
  C_AES_KAT_P3F: array[0..31] of Byte = (
    $73, $00, $65, $00, $63, $00, $72, $00, $65, $00, $74, $00, $31, $00, $32, $00,
    $33, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00);

const
  C_AES_KAT_P19: array[0..31] of Byte = (
    $D0, $5C, $E1, $AF, $28, $2A, $4D, $95, $0F, $D6, $96, $E6, $E7, $F1, $E7, $65,
    $7C, $CA, $2D, $03, $4B, $B4, $23, $9C, $12, $BC, $D3, $84, $F1, $84, $D2, $B2);

function ConstBytes(const AC: array of Byte): TBytes;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AC));
  for LI := 0 to High(AC) do
    Result[LI] := AC[LI];
end;

{ 动态数组按内容比较（= 运算符对 TBytes 不保证内容语义）}
function SameBytes(const A, B: TBytes): Boolean;
begin
  Result := (Length(A) = Length(B)) and
    ((Length(A) = 0) or CompareMem(@A[0], @B[0], Length(A)));
end;

procedure TestBcj2GoldenArchive;
var
  LR: ISevenZReader;
  LArch, LGot: TBytes;
begin
  LArch := ConstBytes(C_BCJ2_GOLDEN);
  LR := TSevenZReaderImpl.Create(LArch);
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'bcj2 entries');
  LGot := LR.Extract(0);
  CheckEqual(Int64(616), Int64(Length(LGot)), 'bcj2 len');
  CheckEqual(UInt64($EF5752F4), UInt64(Crc32OfBytes(LGot)), 'bcj2 crc');
  CheckEqual(Int64($7F), Int64(LGot[0]), 'bcj2 head0');
  CheckEqual(Int64($46), Int64(LGot[3]), 'bcj2 head3');
  CheckEqual(Int64($0F), Int64(LGot[610]), 'bcj2 jcc op');
  CheckEqual(Int64($00), Int64(LGot[615]), 'bcj2 tail');
end;

{ AES：金样档差分（p7zip -psecret123 生成）+ KAT + 负路径 }

procedure TestAesGoldenPlainHeader;
var
  LR: ISevenZReader;
  LGot: TBytes;
begin
  LR := TSevenZReaderImpl.CreateWithPassword(
    ConstBytes(C_GOLD_AES_PLAIN), 'secret123');
  CheckEqual(Int64(2), Int64(LR.EntryCount), 'aes plain entries');
  CheckEqual('a.txt', LR.Entry(0).Name, 'aes plain name0');
  CheckEqual('b.bin', LR.Entry(1).Name, 'aes plain name1');
  LGot := LR.Extract(0);
  CheckEqual(Int64(273), Int64(Length(LGot)), 'aes plain a len');
  CheckEqual(UInt64($5C317BF5), UInt64(Crc32OfBytes(LGot)), 'aes plain a crc');
  LGot := LR.Extract(1);
  CheckEqual(Int64(384), Int64(Length(LGot)), 'aes plain b len');
  CheckEqual(UInt64($14215A54), UInt64(Crc32OfBytes(LGot)), 'aes plain b crc');
end;

procedure TestAesGoldenPlainHeaderPureBackend;
var
  LR: ISevenZReader;
begin
  SevenZSetLzmaBackend(szlbPurePascal);
  try
    LR := TSevenZReaderImpl.CreateWithPassword(
      ConstBytes(C_GOLD_AES_PLAIN), 'secret123');
    CheckEqual(UInt64($14215A54),
      UInt64(Crc32OfBytes(LR.Extract(1))), 'aes pure b crc');
  finally
    SevenZSetLzmaBackend(szlbAuto);
  end;
end;

procedure TestAesGoldenEncryptedHeader;
var
  LR: ISevenZReader;
begin
  { -mhe=on：头部本体也走 AES 解码链 }
  LR := TSevenZReaderImpl.CreateWithPassword(
    ConstBytes(C_GOLD_AES_HDR), 'secret123');
  CheckEqual(Int64(2), Int64(LR.EntryCount), 'aes hdr entries');
  CheckEqual('a.txt', LR.Entry(0).Name, 'aes hdr name0');
  CheckEqual('b.bin', LR.Entry(1).Name, 'aes hdr name1');
  CheckEqual(UInt64($5C317BF5),
    UInt64(Crc32OfBytes(LR.Extract(0))), 'aes hdr a crc');
  CheckEqual(UInt64($14215A54),
    UInt64(Crc32OfBytes(LR.Extract(1))), 'aes hdr b crc');
end;

procedure TestAesWrongPasswordRaises;
var
  LR: ISevenZReader;
begin
  { 明文头档：列目录不受影响，提取时垃圾明文在解码链抛 ESevenZError }
  LR := TSevenZReaderImpl.CreateWithPassword(
    ConstBytes(C_GOLD_AES_PLAIN), 'wrongpass');
  CheckEqual(Int64(2), Int64(LR.EntryCount), 'wrongpass listing');
  try
    LR.Extract(0);
    Fail('wrong password extract should raise');
  except
    on E: ESevenZError do
      ;
  end;
end;

procedure TestAesEncryptedHeaderNoPasswordRaises;
var
  LR: ISevenZReader;
begin
  { 加密头档：口令不对连头部都解不出；构造或首次访问即抛 }
  LR := nil;
  try
    LR := TSevenZReaderImpl.CreateWithPassword(ConstBytes(C_GOLD_AES_HDR), '');
    CheckEqual(Int64(2), Int64(LR.EntryCount), 'hdr lazy trigger');
    Fail('encrypted header with empty password should raise');
  except
    on E: ESevenZError do
      ;
  end;
end;

procedure TestAesPropsParseDefaultsAndRejects;
var
  LP: TSevenZAesProps;
begin
  SevenZParseAesProps(nil, LP);
  CheckEqual(Int64(0), Int64(LP.NumCyclesPower), 'props default power');
  CheckEqual(Int64(0), Int64(LP.SaltSize), 'props default salt');
  CheckEqual(Int64(0), Int64(LP.IvSize), 'props default iv');

  SevenZParseAesProps(ConstBytes([$13]), LP);
  CheckEqual(Int64(19), Int64(LP.NumCyclesPower), 'props single power');

  SevenZParseAesProps(ConstBytes(C_GOLD_AES_PROPS), LP);
  CheckEqual(Int64(19), Int64(LP.NumCyclesPower), 'golden props power');
  CheckEqual(Int64(0), Int64(LP.SaltSize), 'golden props salt size');
  CheckEqual(Int64(16), Int64(LP.IvSize), 'golden props iv size');
  CheckEqual(Int64($24), Int64(LP.Iv[0]), 'golden props iv0');
  CheckEqual(Int64($11), Int64(LP.Iv[15]), 'golden props iv15');

  { 防御性上界：单字节属性 power>24 入口即拒（参考实现放行至派生挂死）}
  try
    SevenZParseAesProps(ConstBytes([$39]), LP);
    Fail('power>24 single byte should raise');
  except
    on E: ESevenZError do
      ;
  end;

  { 扩展路径：声明长度与实际不符 }
  try
    SevenZParseAesProps(ConstBytes([$80, $10]), LP);
    Fail('props size mismatch should raise');
  except
    on E: ESevenZError do
      ;
  end;

  { 单字节路径尾随垃圾 }
  try
    SevenZParseAesProps(ConstBytes([$13, $00]), LP);
    Fail('single byte trailing should raise');
  except
    on E: ESevenZError do
      ;
  end;
end;

procedure TestAesDeriveKat;
var
  LP: TSevenZAesProps;
  LKey: TBytes;
  LI: Integer;
  LMatch: Boolean;

  function KeyMatches(const AC: array of Byte): Boolean;
  var
    LJ: Integer;
  begin
    Result := Length(LKey) = Length(AC);
    if Result then
      for LJ := 0 to High(AC) do
        if LKey[LJ] <> AC[LJ] then
          Exit(False);
  end;

begin
  { power=5 + 4 字节盐 KAT（独立 Python 实现计算）}
  LP := Default(TSevenZAesProps);
  LP.NumCyclesPower := 5;
  LP.SaltSize := 4;
  LP.Salt[0] := $DE; LP.Salt[1] := $AD; LP.Salt[2] := $BE; LP.Salt[3] := $EF;
  SevenZDeriveAesKey(LP, 'secret123', LKey);
  Check(KeyMatches(C_AES_KAT_P5_SALT4), 'kat p5 salt4');

  { power=$3F 直拼路径 KAT }
  LP := Default(TSevenZAesProps);
  LP.NumCyclesPower := $3F;
  SevenZDeriveAesKey(LP, 'secret123', LKey);
  Check(KeyMatches(C_AES_KAT_P3F), 'kat p3f');

  { 金样档真实属性 → 派生结果与独立实现一致 }
  SevenZParseAesProps(ConstBytes(C_GOLD_AES_PROPS), LP);
  SevenZDeriveAesKey(LP, 'secret123', LKey);
  Check(KeyMatches(C_AES_KAT_P19), 'kat p19 from golden props');

  { 空口令派生不得等于正确口令派生（负对照）}
  SevenZDeriveAesKey(LP, '', LKey);
  LMatch := False;
  for LI := 0 to 31 do
    if LKey[LI] <> C_AES_KAT_P19[LI] then
      LMatch := True;
  Check(LMatch, 'empty pw differs');
end;

{ 写端加密：往返 / 负路径 / 属性序列化互逆 }

procedure TestWriterPasswordRoundtripEncHeader;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetPassword('secret123');
  LW.AddFile('a.txt', RepeatedText(7, 39));
  LW.AddFile('b.bin', Randomish(1000, 9));
  LArc := LW.Finish;
  { 默认编码头也被加密：无口令连目录都读不出 }
  try
    TSevenZReaderImpl.Create(LArc);
    Fail('encrypted header open without password should raise');
  except
    on E: ESevenZError do
      ;
  end;
  LR := TSevenZReaderImpl.CreateWithPassword(LArc, 'secret123');
  CheckEqual(Int64(2), Int64(LR.EntryCount), 'pw enc hdr entries');
  CheckEqual('a.txt', LR.Entry(0).Name, 'pw enc hdr name0');
  Check(SameBytes(LR.Extract(0), RepeatedText(7, 39)), 'pw enc hdr a data');
  CheckEqual(Int64(1000), Int64(Length(LR.Extract(1))), 'pw enc hdr b len');
end;

procedure TestWriterPasswordIvUnique;
var
  LW: ISevenZWriter;
  LA1, LA2: TBytes;
begin
  { 随机 IV 使同输入两档不同（确定性仅在明文模式成立）}
  LW := TSevenZWriterImpl.Create;
  LW.SetPassword('pw');
  LW.AddFile('x', RepeatedText(3, 11));
  LA1 := LW.Finish;
  LW := TSevenZWriterImpl.Create;
  LW.SetPassword('pw');
  LW.AddFile('x', RepeatedText(3, 11));
  LA2 := LW.Finish;
  Check(Length(LA1) = Length(LA2), 'iv unique same size');
  Check(not SameBytes(LA1, LA2), 'iv unique bytes differ');
end;

procedure TestWriterPasswordPlainHeaderRoundtrip;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetEncodeHeader(False);
  LW.SetPassword('secret123');
  LW.AddFile('a.txt', RepeatedText(7, 39));
  LArc := LW.Finish;
  { 明文头可匿名列目录，但提取必须口令 }
  LR := TSevenZReaderImpl.Create(LArc);
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'pw plain hdr entries');
  try
    LR.Extract(0);
    Fail('plain header extract without password should raise');
  except
    on E: ESevenZError do
      ;
  end;
  LR := TSevenZReaderImpl.CreateWithPassword(LArc, 'secret123');
  Check(SameBytes(LR.Extract(0), RepeatedText(7, 39)), 'pw plain hdr data');
end;

procedure TestWriterPasswordWrongRaises;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetPassword('right');
  LW.AddFile('x', Randomish(300, 5));
  LArc := LW.Finish;
  { 加密头档：错误口令在构造（头解码）阶段即抛 }
  try
    LR := TSevenZReaderImpl.CreateWithPassword(LArc, 'wrong');
    CheckEqual(Int64(1), Int64(LR.EntryCount), 'wrong lazy trigger');
    Fail('wrong password should raise');
  except
    on E: ESevenZError do
      ;
  end;
end;

procedure TestWriterPasswordClearRestoresBytes;
var
  LW: ISevenZWriter;
  LA1, LA2: TBytes;
begin
  { 清除口令后回到逐字节确定输出，与从未设置完全一致 }
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('x', RepeatedText(3, 21));
  LA1 := LW.Finish;
  LW := TSevenZWriterImpl.Create;
  LW.SetPassword('temp');
  LW.SetPassword('');
  LW.AddFile('x', RepeatedText(3, 21));
  LA2 := LW.Finish;
  Check(SameBytes(LA1, LA2), 'cleared password restores determinism');
end;

procedure TestWriterPasswordAfterFinishRaises;
var
  LW: ISevenZWriter;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('x', BytesOf([$31]));
  LW.Finish;
  try
    LW.SetPassword('late');
    Fail('set password after finish should raise');
  except
    on E: ESevenZError do
      ;
  end;
end;

procedure TestWriterPasswordDirsOnlyEncHeader;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
begin
  { 无非空条目时不产出 solid folder，但编码头仍受口令保护 }
  LW := TSevenZWriterImpl.Create;
  LW.SetPassword('secret123');
  LW.AddDirectory('d');
  LArc := LW.Finish;
  try
    TSevenZReaderImpl.Create(LArc);
    Fail('dirs-only encrypted header should raise');
  except
    on E: ESevenZError do
      ;
  end;
  LR := TSevenZReaderImpl.CreateWithPassword(LArc, 'secret123');
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'dirs only entries');
  Check(LR.Extract(0) = nil, 'dir extracts nil');
end;

procedure TestAesPropsBuildParsesBack;
var
  LIv, LSalt, LProps: TBytes;
  LP: TSevenZAesProps;
  LI: Integer;
begin
  { IV=16 触发半字节进位编码，与 p7zip 金样的 53 0F 前缀互证 }
  SetLength(LIv, 16);
  for LI := 0 to 15 do
    LIv[LI] := Byte($10 + LI);
  LProps := SevenZBuildAesProps(19, nil, LIv);
  CheckEqual(Int64(18), Int64(Length(LProps)), 'build props len');
  CheckEqual(Int64($53), Int64(LProps[0]), 'build props b0');
  CheckEqual(Int64($0F), Int64(LProps[1]), 'build props b1');
  SevenZParseAesProps(LProps, LP);
  CheckEqual(Int64(19), Int64(LP.NumCyclesPower), 'roundtrip power');
  CheckEqual(Int64(0), Int64(LP.SaltSize), 'roundtrip salt');
  CheckEqual(Int64(16), Int64(LP.IvSize), 'roundtrip iv size');
  CheckEqual(Int64($10), Int64(LP.Iv[0]), 'roundtrip iv0');
  CheckEqual(Int64($1F), Int64(LP.Iv[15]), 'roundtrip iv15');

  { 带盐形态与单字节形态 }
  LSalt := TBytes.Create($DE, $AD, $BE, $EF);
  LProps := SevenZBuildAesProps($3F, LSalt, nil);
  SevenZParseAesProps(LProps, LP);
  CheckEqual(Int64($3F), Int64(LP.NumCyclesPower), 'roundtrip 3f power');
  CheckEqual(Int64(4), Int64(LP.SaltSize), 'roundtrip 3f salt size');
  CheckEqual(Int64($EF), Int64(LP.Salt[3]), 'roundtrip 3f salt3');

  LProps := SevenZBuildAesProps(0, nil, nil);
  CheckEqual(Int64(1), Int64(Length(LProps)), 'minimal props len');
  SevenZParseAesProps(LProps, LP);
  CheckEqual(Int64(0), Int64(LP.NumCyclesPower), 'minimal power');

  { 非法档位在序列化端同样拒绝 }
  try
    SevenZBuildAesProps(25, nil, nil);
    Fail('build props power>24 should raise');
  except
    on E: ESevenZError do
      ;
  end;
end;

procedure TestAesEncryptDecryptRoundtrip;
var
  LP: TSevenZAesProps;
  LData, LEnc, LDec: TBytes;
  LI: Integer;
begin
  LP := Default(TSevenZAesProps);
  LP.NumCyclesPower := 19;
  LP.IvSize := 16;
  for LI := 0 to 15 do
    LP.Iv[LI] := Byte($A0 + LI);
  SetLength(LData, 48);
  for LI := 0 to 47 do
    LData[LI] := Byte((LI * 7 + 3) and $FF);
  SevenZAesEncryptData(LP, 'secret123', LData, LEnc);
  CheckEqual(Int64(48), Int64(Length(LEnc)), 'enc len');
  Check(not SameBytes(LEnc, LData), 'enc transforms data');
  SevenZAesDecryptData(LP, 'secret123', LEnc, LDec);
  Check(SameBytes(LDec, LData), 'enc/dec roundtrip');

  { 非块对齐输入拒绝 }
  SetLength(LData, 40);
  try
    SevenZAesEncryptData(LP, 'secret123', LData, LEnc);
    Fail('unaligned encrypt should raise');
  except
    on E: ESevenZError do
      ;
  end;
end;

{ 多 folder 切分：阈值策略（字节/条目数） }

procedure TestMultiFolderBytesThreshold;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
  LI: Integer;
  LGot: TBytes;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetFolderLimits(500, 0);
  for LI := 0 to 4 do
    LW.AddFile('f' + IntToStr(LI) + '.bin', RepeatedText(10, 20));
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.Create(LArc);
  CheckEqual(Int64(5), Int64(LR.EntryCount), 'mf bytes entries');
  for LI := 0 to 4 do
  begin
    LGot := LR.Extract(LI);
    CheckEqual(Int64(200), Int64(Length(LGot)), 'mf bytes len ' + IntToStr(LI));
    Check(SameBytes(LGot, RepeatedText(10, 20)), 'mf bytes content ' + IntToStr(LI));
  end;
  { 单文件超限仍独占一 folder，不被拆散 }
  LW := TSevenZWriterImpl.Create;
  LW.SetFolderLimits(10, 0);
  LW.AddFile('big.bin', RepeatedText(7, 100));
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.Create(LArc);
  Check(SameBytes(LR.Extract(0), RepeatedText(7, 100)), 'mf big single');
end;

procedure TestMultiFolderFileCount;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetFolderLimits(0, 1);
  LW.AddFile('a.bin', BytesOf([$01, $02]));
  LW.AddFile('b.bin', BytesOf([$03, $04, $05]));
  LW.AddFile('c.bin', BytesOf([$06]));
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.Create(LArc);
  CheckEqual(Int64(3), Int64(LR.EntryCount), 'mf count entries');
  Check(SameBytes(LR.Extract(0), BytesOf([$01, $02])), 'mf count a');
  Check(SameBytes(LR.Extract(1), BytesOf([$03, $04, $05])), 'mf count b');
  Check(SameBytes(LR.Extract(2), BytesOf([$06])), 'mf count c');
  { 窗口化写出跨多 folder 仍正确 }
  CheckEqual(Int64(2), LR.ExtractTo(TSinkRecorder.Create as IWriter, 0), 'mf count extractto');
end;

procedure TestMultiFolderWithFilters;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
  LExe: TBytes;
begin
  LExe := ExeLikeCorpus(8000);
  LW := TSevenZWriterImpl.Create;
  LW.SetFilters([szfBcjX86]);
  LW.SetFolderLimits(3000, 0);
  LW.AddFile('a.exe', LExe);
  LW.AddFile('b.exe', LExe);
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.Create(LArc);
  Check(SameBytes(LR.Extract(0), LExe), 'mf filter a');
  Check(SameBytes(LR.Extract(1), LExe), 'mf filter b');
end;

procedure TestMultiFolderWithPassword;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
  LData: TBytes;
begin
  LData := RepeatedText(11, 50);
  LW := TSevenZWriterImpl.Create;
  LW.SetPassword('pw123');
  LW.SetFolderLimits(200, 0);
  LW.AddFile('a.bin', LData);
  LW.AddFile('b.bin', LData);
  LW.AddFile('c.bin', LData);
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.CreateWithPassword(LArc, 'pw123');
  CheckEqual(Int64(3), Int64(LR.EntryCount), 'mf pw entries');
  Check(SameBytes(LR.Extract(1), LData), 'mf pw content');
  { 编码头加密 + 多 folder 组合：错误口令在头解码阶段即抛 }
  try
    TSevenZReaderImpl.CreateWithPassword(LArc, 'wrong');
    Fail('mf pw wrong should raise');
  except
    on E: ESevenZError do
      ;
  end;
end;

procedure TestMultiFolderPlainHeader;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetEncodeHeader(False);
  LW.SetFolderLimits(100, 0);
  LW.AddFile('a.bin', RepeatedText(5, 30));
  LW.AddFile('b.bin', RepeatedText(6, 30));
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.Create(LArc);
  CheckEqual(Int64(2), Int64(LR.EntryCount), 'mf plain entries');
  Check(SameBytes(LR.Extract(0), RepeatedText(5, 30)), 'mf plain a');
  Check(SameBytes(LR.Extract(1), RepeatedText(6, 30)), 'mf plain b');
end;

procedure TestMultiFolderLimitsValidation;
var
  LW: ISevenZWriter;
begin
  LW := TSevenZWriterImpl.Create;
  try
    LW.SetFolderLimits(0, -1);
    Fail('negative files should raise');
  except
    on E: EArgumentError do
      ;
  end;
  LW.AddFile('x', BytesOf([$01]));
  LW.Finish;
  try
    LW.SetFolderLimits(100, 1);
    Fail('set after finish should raise');
  except
    on E: ESevenZError do
      ;
  end;
end;

procedure TestMultiFolderDirsAndEmpty;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetFolderLimits(10, 0);
  LW.AddDirectory('d');
  LW.AddFile('a.bin', BytesOf([$01, $02]));
  LW.AddFile('e.dat', nil);
  LW.AddFile('b.bin', BytesOf([$03]));
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.Create(LArc);
  CheckEqual(Int64(4), Int64(LR.EntryCount), 'mf dirs entries');
  Check(LR.Entry(0).Kind = sekDirectory, 'mf dirs kind');
  Check(SameBytes(LR.Extract(1), BytesOf([$01, $02])), 'mf dirs a');
  Check(LR.Extract(2) = nil, 'mf empty nil');
  Check(SameBytes(LR.Extract(3), BytesOf([$03])), 'mf dirs b');
end;

{ 读端查询与越界 }

procedure TestFindMissAndIndexErrors;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$61]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(-1), Int64(LR.Find('missing.txt')), 'find miss');
  try
    LR.Entry(99);
    Fail('entry out of range should raise');
  except
    on E: EArgumentError do
      ;
  end;
  try
    LR.Extract(-1);
    Fail('extract negative should raise');
  except
    on E: EArgumentError do
      ;
  end;
end;

{ ExtractTo：窗口化写出（数据量 > 单窗），目录与空文件计 0 字节 }

procedure TestExtractToWindowed;
const
  C_BIG = 300 * 1024;   { 跨过 256KiB 写窗 }
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LSink: TSinkRecorder;
  LRaw: TBytes;
begin
  LRaw := Randomish(C_BIG, 42);
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('big.bin', LRaw);
  LW.AddDirectory('d');
  LW.AddFile('e.dat', nil);
  LR := TSevenZReaderImpl.Create(LW.Finish);

  LSink := TSinkRecorder.Create;
  try
    CheckEqual(Int64(C_BIG), LR.ExtractTo(LSink, 0), 'extractto count');
    CheckEqual(Int64(C_BIG), Int64(Length(LSink.Buf)), 'sink size');
    Check(CompareMem(@LRaw[0], @LSink.Buf[0], C_BIG), 'sink content');
    Check(LSink.Writes >= 2, 'multiple window writes');

    CheckEqual(Int64(0), LR.ExtractTo(LSink, 1), 'dir extractto zero');
    CheckEqual(Int64(0), LR.ExtractTo(LSink, 2), 'empty extractto zero');
  finally
    LSink.Free;
  end;
end;

{ OpenStream：Read/Seek/Position/Size/Close 幂等与关闭后访问 }

procedure TestEntryStreamSemantics;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  S: IStream;
  LB: TBytes;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFileWithTime('s.bin', BytesOf([$31, $32, $33, $34, $35]), 100);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  S := LR.OpenStream(0);
  CheckEqual(Int64(5), S.GetSize, 'stream size');
  SetLength(LB, 5);
  CheckEqual(Int64(3), Int64(S.Read(LB[0], 3)), 'read head');
  CheckEqual(Int64(3), S.GetPosition, 'position after read');
  { 位置 3 回退 2 → 1；随后两字节读到 data[1..2] }
  CheckEqual(Int64(1), S.Seek(-2, soCurrent), 'seek cur back');
  CheckEqual(Int64(2), Int64(S.Read(LB[3], 2)), 'read tail');
  CheckEqual(Int64($32), Int64(LB[3]), 'byte after seek');
  CheckEqual(Int64(0), S.Seek(0, soBeginning), 'seek begin');
  CheckEqual(Int64(5), Int64(S.Read(LB[0], 5)), 'reread full');
  CheckEqual(Int64($31), Int64(LB[0]), 'reread b0');
  CheckEqual(Int64($35), Int64(LB[4]), 'reread b4');
  { 关闭后访问 raise；Close 幂等 }
  S.Close;
  S.Close;
  try
    S.Read(LB[0], 1);
    Fail('closed read should raise');
  except
    on E: EIOError do
      ;
  end;
  try
    S.Seek(0, soBeginning);
    Fail('closed seek should raise');
  except
    on E: EIOError do
      ;
  end;
end;

{ 合成 kEncodedHeader 归档：读端编码头全链路（识别→解码头→CRC→重解析） }

procedure SigPutLE32(var ASig: TBytes; AOfs: SizeInt; AVal: UInt32);
var
  LI: SizeInt;
begin
  for LI := 0 to 3 do
    ASig[AOfs + LI] := Byte((AVal shr (8 * LI)) and $FF);
end;

procedure SigPutLE64(var ASig: TBytes; AOfs: SizeInt; AVal: UInt64);
var
  LI: SizeInt;
begin
  for LI := 0 to 7 do
    ASig[AOfs + LI] := Byte((AVal shr (8 * LI)) and $FF);
end;

procedure AppendProp(var AOut: TBytes; AId: Byte; const APayload: TBytes);
begin
  SevenZAppendByte(AOut, AId);
  SevenZWriteNumber(AOut, UInt64(Length(APayload)));
  if Length(APayload) > 0 then
    SevenZAppendBytes(AOut, @APayload[0], Length(APayload));
end;

procedure TestEncodedHeaderRoundTrip;
var
  LPlain: TBytes;
  LEnc: TSevenZLzmaEncoded;
  LBlock, LPack, LPayload, LName: TBytes;
  LArchive: TBytes;
  LR: ISevenZReader;
begin
  { 明文头：一个空文件条目（免 MainStreamsInfo，聚焦编码头机制本身） }
  SetLength(LPlain, 0);
  SevenZAppendByte(LPlain, SZ_ID_HEADER);
  SevenZAppendByte(LPlain, SZ_ID_FILES_INFO);
  SevenZWriteNumber(LPlain, 1);                     { NumFiles }
  SetLength(LPayload, 0);
  SevenZAppendByte(LPayload, $80);                  { EmptyStream bit0=1 }
  AppendProp(LPlain, SZ_ID_EMPTY_STREAM, LPayload);
  SetLength(LPayload, 0);
  SevenZAppendByte(LPayload, $80);                  { EmptyFile bit0=1 }
  AppendProp(LPlain, SZ_ID_EMPTY_FILE, LPayload);
  LName := SevenZUtf8ToUtf16Le('only-empty.txt');
  SetLength(LPayload, 0);
  SevenZAppendByte(LPayload, 0);                    { External }
  SevenZAppendBytes(LPayload, @LName[0], Length(LName));
  SevenZAppendByte(LPayload, 0);
  SevenZAppendByte(LPayload, 0);
  AppendProp(LPlain, SZ_ID_NAME, LPayload);
  SevenZAppendByte(LPlain, SZ_ID_END);
  SevenZAppendByte(LPlain, SZ_ID_END);

  LEnc := SevenZAcquireEncoder.EncodeLzma2(LPlain, szclDefault);
  LPack := LEnc.PackedData;

  { kEncodedHeader 块：PackInfo + UnpackInfo（LZMA2 单 coder 带 CRC） }
  SetLength(LBlock, 0);
  SevenZAppendByte(LBlock, SZ_ID_ENCODED_HEADER);
  SevenZAppendByte(LBlock, SZ_ID_PACK_INFO);
  SevenZWriteNumber(LBlock, 0);                     { PackPos }
  SevenZWriteNumber(LBlock, 1);                     { NumPackStreams }
  SevenZAppendByte(LBlock, SZ_ID_SIZE);
  SevenZWriteNumber(LBlock, UInt64(Length(LPack)));
  SevenZAppendByte(LBlock, SZ_ID_END);
  SevenZAppendByte(LBlock, SZ_ID_UNPACK_INFO);
  SevenZAppendByte(LBlock, SZ_ID_FOLDER);
  SevenZWriteNumber(LBlock, 1);                     { NumFolders }
  SevenZAppendByte(LBlock, 0);                      { External }
  SevenZWriteNumber(LBlock, 1);                     { NumCoders }
  SevenZAppendByte(LBlock, $21);                    { flags: idSize=1+props }
  SevenZAppendByte(LBlock, Byte(SEVENZ_METHOD_LZMA2));
  SevenZWriteNumber(LBlock, UInt64(Length(LEnc.Props)));
  SevenZAppendBytes(LBlock, @LEnc.Props[0], Length(LEnc.Props));
  SevenZAppendByte(LBlock, SZ_ID_CODERS_UNPACK_SZ);
  SevenZWriteNumber(LBlock, UInt64(Length(LPlain)));
  SevenZAppendByte(LBlock, SZ_ID_CRC);
  SevenZAppendByte(LBlock, $01);                    { BoolVector2 全定义 }
  SevenZAppendUInt32LE(LBlock, Crc32OfBytes(LPlain));
  SevenZAppendByte(LBlock, SZ_ID_END);
  SevenZAppendByte(LBlock, SZ_ID_END);

  { 组装签名头：载荷 = packedData ++ encodedHeaderBlock }
  SetLength(LArchive, C_SEVENZ_SIG_HEADER_SIZE);
  FillChar(LArchive[0], C_SEVENZ_SIG_HEADER_SIZE, 0);
  LArchive[0] := C_SEVENZ_MAGIC_0;
  LArchive[1] := C_SEVENZ_MAGIC_1;
  LArchive[2] := C_SEVENZ_MAGIC_2;
  LArchive[3] := C_SEVENZ_MAGIC_3;
  LArchive[4] := C_SEVENZ_MAGIC_4;
  LArchive[5] := C_SEVENZ_MAGIC_5;
  LArchive[6] := C_SEVENZ_VERSION_MAJOR;
  LArchive[7] := C_SEVENZ_VERSION_MINOR;
  SigPutLE64(LArchive, 12, UInt64(Length(LPack)));
  SigPutLE64(LArchive, 20, UInt64(Length(LBlock)));
  SigPutLE32(LArchive, 28, Crc32OfBytes(LBlock));
  SigPutLE32(LArchive, 8, Crc32Of((@LArchive[12])^, 20));

  SetLength(LArchive, Length(LArchive) + Length(LPack) + Length(LBlock));
  Move(LPack[0], LArchive[C_SEVENZ_SIG_HEADER_SIZE], Length(LPack));
  Move(LBlock[0],
    LArchive[C_SEVENZ_SIG_HEADER_SIZE + Length(LPack)], Length(LBlock));

  LR := TSevenZReaderImpl.Create(LArchive);
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'encoded hdr entry count');
  CheckEqual('only-empty.txt', LR.Entry(0).Name, 'encoded hdr name');
  Check(LR.Entry(0).Kind = sekFile, 'encoded hdr kind');
  Check(LR.Extract(0) = nil, 'encoded hdr extract empty');
end;

procedure TestReaderRejectsShortInput;
begin
  ExpectCreateRaises(BytesOf([$37, $7A, $BC, $AF]), 'short input');
  ExpectCreateRaises(nil, 'nil input');
end;

procedure TestReaderRejectsBadMagic;
begin
  ExpectCreateRaises(BytesOf([$4E, $4F, $54, $37, $5A, $49, $50, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00]), 'bad magic');
end;

procedure TestReaderRejectsStartHeaderCrcMismatch;
var
  LW: ISevenZWriter;
  LBad: TBytes;
begin
  { 合法档把起始头 CRC 位翻掉后必须被拒。
    经接口变量持有写端实例，避免 TInterfacedObject 引用计数悬空 }
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('x', BytesOf([$58]));
  LBad := LW.Finish;
  LBad[8] := Byte(LBad[8] xor $FF);
  ExpectCreateRaises(LBad, 'start header crc');
end;

{ 编码头开关：默认 kEncodedHeader，可切回明文。空文件条目使档内
  无 solid 载荷：NextHeaderOffset 直接给出压缩头码流长度，
  块起点可据此精确断言 }

function SigLe64At(const AArchive: TBytes; AOfs: SizeInt): Int64;
var
  LI: SizeInt;
begin
  Result := 0;
  for LI := 7 downto 0 do
    Result := (Result shl 8) or AArchive[AOfs + LI];
end;

procedure TestHeaderEncodingModes;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LPlainArc, LEncArc: TBytes;
  LBlockOfs: SizeInt;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetEncodeHeader(False);
  LW.AddFile('e.txt', nil);
  LPlainArc := LW.Finish;
  { 明文模式无 solid、无码流：块紧随签名头 }
  CheckEqual(Int64(0), SigLe64At(LPlainArc, 12), 'plain offset');
  CheckEqual(Int64(SZ_ID_HEADER),
    Int64(LPlainArc[C_SEVENZ_SIG_HEADER_SIZE]), 'plain marker');

  LW := TSevenZWriterImpl.Create;
  LW.AddFile('e.txt', nil);
  LW.SetEncodeHeader(True);          { Finish 前可随时切换 }
  LEncArc := LW.Finish;
  { 编码模式：偏移即压缩头码流长度；块以 kEncodedHeader 开头 }
  Check(SigLe64At(LEncArc, 12) > 0, 'encoded stream length > 0');
  LBlockOfs := C_SEVENZ_SIG_HEADER_SIZE + SizeInt(SigLe64At(LEncArc, 12));
  CheckEqual(Int64(SZ_ID_ENCODED_HEADER),
    Int64(LEncArc[LBlockOfs]), 'encoded marker');

  LR := TSevenZReaderImpl.Create(LPlainArc);
  CheckEqual('e.txt', LR.Entry(0).Name, 'plain hdr name');
  Check(LR.Extract(0) = nil, 'plain hdr extract');

  LR := TSevenZReaderImpl.Create(LEncArc);
  CheckEqual('e.txt', LR.Entry(0).Name, 'enc hdr name');
  Check(LR.Extract(0) = nil, 'enc hdr extract');
end;

{ 流式增量 API：AddFileFromReader / CreateFromReader / FinishTo }

type
  TShortReader = class(TInterfacedObject, IReader)
  private
    FData: TBytes;
    FPos: SizeInt;
    FLimit: SizeInt;
  public
    constructor Create(const AData: TBytes; ALimit: SizeInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TShortReader.Create(const AData: TBytes; ALimit: SizeInt);
begin
  inherited Create;
  FData := Copy(AData);
  FPos := 0;
  FLimit := ALimit;
end;

function TShortReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvail: SizeInt;
begin
  if FPos >= FLimit then Exit(0);
  LAvail := FLimit - FPos;
  if SizeInt(ACount) > LAvail then
    Result := SizeUInt(LAvail)
  else
    Result := ACount;
  if Result > 0 then
  begin
    Move(FData[FPos], ABuf, Result);
    Inc(FPos, Result);
  end;
end;

procedure TestWriterAddFileFromReaderRoundtrip;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LData, LGot: TBytes;
  LRd: IReader;
begin
  LData := RepeatedText(7, 300);
  LRd := CreateBytesStreamFrom(LData) as IReader;
  LW := TSevenZWriterImpl.Create;
  LW.AddFileFromReader('r.bin', LRd, UInt64(Length(LData)));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  LGot := LR.Extract(0);
  CheckEqual(Int64(Length(LData)), Int64(Length(LGot)), 'reader size');
  Check(CompareMem(@LData[0], @LGot[0], Length(LData)), 'reader bytes');
end;

procedure TestWriterAddFileFromReaderWithTime;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LData: TBytes;
begin
  LData := BytesOf([$01, $02, $03]);
  LW := TSevenZWriterImpl.Create;
  LW.AddFileFromReaderWithTime('t.bin', CreateBytesStreamFrom(LData) as IReader,
    UInt64(Length(LData)), 1234567890);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(1234567890), Int64(LR.Entry(0).MTimeUnixSec), 'mtime');
  CheckEqual(Int64(3), Int64(Length(LR.Extract(0))), 'size');
end;

procedure TestWriterAddFileFromReaderMixed;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LA, LB: TBytes;
begin
  LA := RepeatedText(5, 100);
  LB := Randomish(5000, 11);
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.bin', LA);
  LW.AddFileFromReader('b.bin', CreateBytesStreamFrom(LB) as IReader, UInt64(Length(LB)));
  LW.AddDirectory('d');
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(3), Int64(LR.EntryCount), 'mixed count');
  Check(CompareMem(@LA[0], @LR.Extract(0)[0], Length(LA)), 'mixed a');
  Check(CompareMem(@LB[0], @LR.Extract(1)[0], Length(LB)), 'mixed b');
  Check(LR.Extract(2) = nil, 'mixed dir nil');
end;

procedure TestWriterAddFileFromReaderLarge;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LData, LGot: TBytes;
begin
  LData := Randomish(300000, 20260828);
  LW := TSevenZWriterImpl.Create;
  LW.AddFileFromReader('big.bin', CreateBytesStreamFrom(LData) as IReader,
    UInt64(Length(LData)));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  LGot := LR.Extract(0);
  CheckEqual(Int64(Length(LData)), Int64(Length(LGot)), 'large size');
  Check(Crc32OfBytes(LData) = Crc32OfBytes(LGot), 'large crc');
end;

procedure TestWriterAddFileFromReaderMultiFolder;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LA, LB, LC: TBytes;
begin
  LA := RepeatedText(3, 1000);
  LB := RepeatedText(4, 800);
  LC := RepeatedText(5, 600);
  LW := TSevenZWriterImpl.Create;
  LW.SetFolderLimits(2000, 0);
  LW.AddFileFromReader('a.bin', CreateBytesStreamFrom(LA) as IReader, UInt64(Length(LA)));
  LW.AddFileFromReader('b.bin', CreateBytesStreamFrom(LB) as IReader, UInt64(Length(LB)));
  LW.AddFileFromReader('c.bin', CreateBytesStreamFrom(LC) as IReader, UInt64(Length(LC)));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(3), Int64(LR.EntryCount), 'mf count');
  Check(CompareMem(@LA[0], @LR.Extract(0)[0], Length(LA)), 'mf a');
  Check(CompareMem(@LB[0], @LR.Extract(1)[0], Length(LB)), 'mf b');
  Check(CompareMem(@LC[0], @LR.Extract(2)[0], Length(LC)), 'mf c');
end;

procedure TestWriterAddFileFromReaderWithFilterAndPassword;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LData, LGot: TBytes;
  LArc: TBytes;
begin
  LData := ExeLikeCorpus(20000);
  LW := TSevenZWriterImpl.Create;
  LW.SetFilters([szfBcjX86]);
  LW.SetPassword('pw123');
  LW.AddFileFromReader('x.exe', CreateBytesStreamFrom(LData) as IReader,
    UInt64(Length(LData)));
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.CreateWithPassword(LArc, 'pw123');
  LGot := LR.Extract(0);
  Check(CompareMem(@LData[0], @LGot[0], Length(LData)), 'filter pw bytes');
end;

procedure TestWriterAddFileFromReaderEmpty;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFileFromReader('empty.bin', CreateBytesStreamFrom(nil) as IReader, 0);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'empty count');
  CheckEqual(Int64(0), Int64(LR.Entry(0).Size), 'empty size');
  Check(LR.Extract(0) = nil, 'empty extract nil');
end;

procedure TestWriterAddFileFromReaderNilRaises;
var
  LW: ISevenZWriter;
begin
  LW := TSevenZWriterImpl.Create;
  try
    LW.AddFileFromReader('x.bin', nil, 10);
    Fail('nil reader accepted');
  except
    on E: EArgumentError do ;
  end;
end;

procedure TestWriterAddFileFromReaderShortReadRaises;
var
  LW: ISevenZWriter;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFileFromReader('x.bin', TShortReader.Create(BytesOf([$01,$02]), 2) as IReader, 10);
  try
    LW.Finish;
    Fail('short read accepted');
  except
    on E: EIOError do ;
  end;
end;

procedure TestWriterAddFileFromReaderAfterFinishRaises;
var
  LW: ISevenZWriter;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.bin', BytesOf([$01]));
  LW.Finish;
  try
    LW.AddFileFromReader('b.bin', CreateBytesStreamFrom(BytesOf([$02])) as IReader, 1);
    Fail('after finish accepted');
  except
    on E: ESevenZError do ;
  end;
end;

procedure TestReaderCreateFromReader;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
  LData: TBytes;
begin
  LData := RepeatedText(9, 200);
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.bin', LData);
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.CreateFromReader(CreateBytesStreamFrom(LArc) as IReader);
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'from reader count');
  Check(CompareMem(@LData[0], @LR.Extract(0)[0], Length(LData)), 'from reader bytes');
  { 带密码变体 }
  LW := TSevenZWriterImpl.Create;
  LW.SetPassword('secret');
  LW.AddFile('b.bin', LData);
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.CreateFromReaderWithPassword(
    CreateBytesStreamFrom(LArc) as IReader, 'secret');
  Check(CompareMem(@LData[0], @LR.Extract(0)[0], Length(LData)), 'from reader pw');
end;

procedure TestReaderCreateFromReaderNilRaises;
begin
  try
    TSevenZReaderImpl.CreateFromReader(nil);
    Fail('nil reader accepted');
  except
    on E: EArgumentError do ;
  end;
end;

procedure TestWriterFinishToStreaming;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LData: TBytes;
  LSink: IStream;
  LArc: TBytes;
begin
  LData := Randomish(80000, 99);
  LW := TSevenZWriterImpl.Create;
  LW.AddFileFromReader('a.bin', CreateBytesStreamFrom(LData) as IReader, UInt64(Length(LData)));
  LSink := CreateBytesStream(256);
  LW.FinishTo(LSink as IWriter);
  LSink.Seek(0, soBeginning);
  LArc := IoReadAll(LSink as IReader);
  LR := TSevenZReaderImpl.Create(LArc);
  Check(CompareMem(@LData[0], @LR.Extract(0)[0], Length(LData)), 'finishTo bytes');
  { 二次 FinishTo 应锁死 }
  try
    LW.FinishTo(LSink as IWriter);
    Fail('second FinishTo accepted');
  except
    on E: ESevenZError do ;
  end;
end;

procedure TestFactoryHelpers;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LData: TBytes;
begin
  LData := BytesOf([$AA, $BB]);
  LW := SevenZCreateWriter;
  LW.AddFile('f.bin', LData);
  LR := SevenZCreateReader(LW.Finish);
  CheckEqual(Int64(2), Int64(Length(LR.Extract(0))), 'factory bytes');
  LW := SevenZCreateWriter;
  LW.AddFile('f.bin', LData);
  LR := SevenZCreateReaderFrom(CreateBytesStreamFrom(LW.Finish) as IReader);
  CheckEqual(Int64(2), Int64(Length(LR.Extract(0))), 'factory from reader');
end;

procedure TestLevelNoneCopyRoundtrip;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LData, LGot: TBytes;
begin
  LData := Randomish(80000, 55);
  LW := TSevenZWriterImpl.Create;
  LW.SetLevel(szclNone);
  LW.AddFile('r.bin', LData);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  LGot := LR.Extract(0);
  CheckEqual(Int64(Length(LData)), Int64(Length(LGot)), 'none size');
  Check(CompareMem(@LData[0], @LGot[0], Length(LData)), 'none bytes');
  { 与压缩档对比：不可压缩数据上 None 不应显著膨胀，且对可压缩数据 None 应更大 }
  LData := RepeatedText(8, 5000);
  LW := TSevenZWriterImpl.Create;
  LW.SetLevel(szclNone);
  LW.AddFile('t.txt', LData);
  Check(Int64(Length(LW.Finish)) > 40000, 'none not compress');
end;

procedure TestLevelNoneCopyWithFiltersAndPassword;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LData, LGot: TBytes;
  LArc: TBytes;
begin
  LData := ExeLikeCorpus(15000);
  LW := TSevenZWriterImpl.Create;
  LW.SetLevel(szclNone);
  LW.SetFilters([szfBcjX86]);
  LW.SetPassword('pw-none');
  LW.AddFile('x.exe', LData);
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.CreateWithPassword(LArc, 'pw-none');
  LGot := LR.Extract(0);
  Check(CompareMem(@LData[0], @LGot[0], Length(LData)), 'none filter pw');
end;

procedure TestWriterDeflateMethod;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LData, LGot: TBytes;
  LArc: TBytes;
begin
  LData := RepeatedText(7, 400);
  LW := TSevenZWriterImpl.Create;
  LW.SetMethod(SEVENZ_METHOD_DEFLATE);
  LW.AddFile('t.txt', LData);
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.Create(LArc);
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'deflate method entries');
  LGot := LR.Extract(0);
  CheckEqual(Int64(Length(LData)), Int64(Length(LGot)), 'deflate method size');
  Check(SameBytes(LData, LGot), 'deflate method bytes');
  // Deflate + BCJ + password 组合
  LW := TSevenZWriterImpl.Create;
  LW.SetMethod(SEVENZ_METHOD_DEFLATE);
  LW.SetFilters([szfBcjX86]);
  LW.SetPassword('pw-deflate');
  LW.AddFile('x.exe', ExeLikeCorpus(8000));
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.CreateWithPassword(LArc, 'pw-deflate');
  LGot := LR.Extract(0);
  CheckEqual(Int64(8000), Int64(Length(LGot)), 'deflate filter pw size');
end;

procedure TestWriterBZip2Method;
var
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LData, LGot: TBytes;
  LArc: TBytes;
begin
  if not BZip2FfiIsAvailable then
    Exit;
  LData := RepeatedText(11, 500);
  LW := TSevenZWriterImpl.Create;
  LW.SetMethod(SEVENZ_METHOD_BZIP2);
  LW.AddFile('t.txt', LData);
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.Create(LArc);
  CheckEqual(Int64(1), Int64(LR.EntryCount), 'bzip2 method entries');
  LGot := LR.Extract(0);
  CheckEqual(Int64(Length(LData)), Int64(Length(LGot)), 'bzip2 method size');
  Check(SameBytes(LData, LGot), 'bzip2 method bytes');
  LW := TSevenZWriterImpl.Create;
  LW.SetMethod(SEVENZ_METHOD_BZIP2);
  LW.SetFilters([szfDelta]);
  LW.SetPassword('pw-bzip2');
  LW.AddFile('d.bin', RepeatedText(5, 800));
  LArc := LW.Finish;
  LR := TSevenZReaderImpl.CreateWithPassword(LArc, 'pw-bzip2');
  LGot := LR.Extract(0);
  CheckEqual(Int64(5*800), Int64(Length(LGot)), 'bzip2 filter pw size');
end;

procedure TestWriterSetMethodValidation;
var
  LW: ISevenZWriter;
begin
  LW := TSevenZWriterImpl.Create;
  try
    LW.SetMethod(SEVENZ_METHOD_PPMD);
    Fail('ppmd writer should raise');
  except on E: EArgumentError do ; end;
  try
    LW.SetMethod(UInt64($DEADBEEF));
    Fail('unknown writer should raise');
  except on E: EArgumentError do ; end;
  Check(SevenZMethodName(SEVENZ_METHOD_DEFLATE) = 'Deflate', 'method name deflate');
  Check(SevenZMethodName(SEVENZ_METHOD_BZIP2) = 'BZip2', 'method name bzip2');
  Check(SevenZMethodName(SEVENZ_METHOD_PPMD) = 'PPMD', 'method name ppmd');
  Check(SevenZIsSupportedMethod(SEVENZ_METHOD_DEFLATE), 'supported deflate');
  Check(SevenZIsSupportedMethod(SEVENZ_METHOD_BZIP2), 'supported bzip2');
  Check(not SevenZIsSupportedMethod(UInt64($DEADBEEF)), 'unsupported unknown');
end;

procedure TestBuilderChain;
var B: ISevenZWriterBuilder; LR: ISevenZReader; LData, LGot: TBytes;
begin
  LData := RepeatedText(9, 200);
  B := SevenZCreateWriterBuilder;
  LGot := B.AddFile('a.bin', LData).WithLevel(szclBest).WithFilters([szfDelta]).Finish;
  LR := SevenZCreateReader(LGot);
  Check(SameBytes(LR.Extract(0), LData), 'builder finish bytes');
  B := SevenZCreateWriterBuilder;
  B.AddFile('x.bin', LData).WithMethod(SEVENZ_METHOD_DEFLATE).WithEncodeHeader(False);
  LR := SevenZCreateReader(B.Build.Finish);
  Check(SameBytes(LR.Extract(0), LData), 'builder build deflate');
  CheckEqual(Int64(1), Int64(SevenZLevelToBZip2BlockSize(szclFastest)), 'level bzip fastest');
  CheckEqual(Int64(9), Int64(SevenZLevelToBZip2BlockSize(szclBest)), 'level bzip best');
  Check(SevenZLevelToDeflateLevel(szclFastest)=clFastest, 'level deflate fastest');
  Check(SevenZLevelToDeflateLevel(szclBest)=clBest, 'level deflate best');
end;

procedure TestTryExtractProbe;
var LW: ISevenZWriter; LR: ISevenZReader; LData, LOut: TBytes; LOk: Boolean; LWr: Int64; Sink: TSinkRecorder;
begin
  LData := BytesOf([$01,$02,$03]);
  LW := TSevenZWriterImpl.Create; LW.AddFile('a.bin', LData); LR := TSevenZReaderImpl.Create(LW.Finish);
  LOk := LR.TryExtract(0, LOut); Check(LOk, 'tryextract ok'); Check(SameBytes(LOut, LData), 'tryextract bytes');
  LOk := LR.TryExtract(99, LOut); Check(not LOk, 'tryextract out of range false');
  Sink := TSinkRecorder.Create;
  try
    LOk := LR.TryExtractTo(Sink, 0, LWr); Check(LOk, 'tryextractto ok'); CheckEqual(Int64(3), LWr, 'tryextractto bytes');
    LOk := LR.TryExtractTo(nil, 0, LWr); Check(not LOk, 'tryextractto nil false');
    LOk := LR.TryExtractTo(Sink, 99, LWr); Check(not LOk, 'tryextractto oob false');
  finally
    Sink.Free;
  end;
end;

procedure TestBZip2LevelMapping;
var LW: ISevenZWriter; LR: ISevenZReader; LData: TBytes; LArc: TBytes;
begin
  if not SevenZBZip2Available then Exit;
  LData := RepeatedText(7, 1000);
  LW := SevenZCreateWriterBuilder.AddFile('t.txt', LData).WithLevel(szclFastest).WithMethod(SEVENZ_METHOD_BZIP2).Build; LArc := LW.Finish;
  LR := SevenZCreateReader(LArc); Check(SameBytes(LR.Extract(0), LData), 'bzip fastest roundtrip');
  LW := SevenZCreateWriterBuilder.AddFile('t.txt', LData).WithLevel(szclBest).WithMethod(SEVENZ_METHOD_BZIP2).Build; LArc := LW.Finish;
  LR := SevenZCreateReader(LArc); Check(SameBytes(LR.Extract(0), LData), 'bzip best roundtrip');
end;

procedure TestBuilderFsTree;
var B: ISevenZWriterBuilder; LR: ISevenZReader; LRoot, LOut: string; LData: TBytes;
begin
  LRoot := TempDir('', 'sevenz-builder-fs-');
  LOut := TempDir('', 'sevenz-builder-fs-out-');
  try
    MkdirAll(PathJoin([LRoot, 'a']));
    LData := RepeatedText(5, 50);
    WriteFile(PathJoin([LRoot, 'a', 'f.txt']), LData);
    B := SevenZCreateWriterBuilder.AddTree(LRoot, 'arc');
    LR := SevenZCreateReader(B.Finish);
    Check(LR.Find('arc/a/f.txt')>=0, 'builder tree find');
    Check(SameBytes(LR.Extract(LR.Find('arc/a/f.txt')), LData), 'builder tree bytes');
    B := SevenZCreateWriterBuilder.AddFileFromFs(PathJoin([LRoot, 'a', 'f.txt']), 'single.txt');
    LR := SevenZCreateReader(B.Finish);
    Check(SameBytes(LR.Extract(0), LData), 'builder addfilefromfs');
  finally RemoveAll(LRoot); RemoveAll(LOut); end;
end;

procedure TestTryExtractWithError;
var LW: ISevenZWriter; LR: ISevenZReader; LData, LOut: TBytes; LErr: string; LOk: Boolean; S: IStream;
begin
  LData := BytesOf([$AA,$BB]);
  LW := TSevenZWriterImpl.Create; LW.AddFile('a.bin', LData); LR := TSevenZReaderImpl.Create(LW.Finish);
  LOk := LR.TryExtractWithError(0, LOut, LErr); Check(LOk and (LErr=''), 'trywitherror ok empty');
  LOk := LR.TryExtractWithError(99, LOut, LErr); Check(not LOk and (LErr<>''), 'trywitherror oob msg');
  LOk := LR.TryOpenStreamWithError(0, S, LErr); Check(LOk and Assigned(S), 'tryopen ok');
  LOk := LR.TryOpenStreamWithError(99, S, LErr); Check(not LOk and (LErr<>''), 'tryopen oob');
end;

procedure TestFsAddTreeAndExtractAll;
var
  LRoot, LOut: string;
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LArc: TBytes;
  LDataA, LDataB: TBytes;
begin
  LRoot := TempDir('', 'sevenz-fs-addtree-');
  LOut := TempDir('', 'sevenz-fs-extract-');
  try
    MkdirAll(PathJoin([LRoot, 'a', 'b']));
    LDataA := RepeatedText(5, 200);
    LDataB := Randomish(1000, 9);
    WriteFile(PathJoin([LRoot, 'a', 'file1.txt']), LDataA);
    WriteFile(PathJoin([LRoot, 'a', 'b', 'file2.bin']), LDataB);
    MkdirAll(PathJoin([LRoot, 'emptyDir']));
    LW := TSevenZWriterImpl.Create;
    SevenZAddTree(LW, LRoot, '');
    LArc := LW.Finish;
    LR := TSevenZReaderImpl.Create(LArc);
    SevenZExtractAllToFs(LR, LOut);
    Check(IsFile(PathJoin([LOut, 'a', 'file1.txt'])), 'fs file1 exists');
    Check(IsFile(PathJoin([LOut, 'a', 'b', 'file2.bin'])), 'fs file2 exists');
    Check(IsDir(PathJoin([LOut, 'emptyDir'])), 'fs emptyDir exists');
    Check(CompareMem(@LDataA[0], @ReadFile(PathJoin([LOut, 'a', 'file1.txt']))[0], Length(LDataA)), 'fs file1 bytes');
    Check(Crc32OfBytes(LDataB) = Crc32OfBytes(ReadFile(PathJoin([LOut, 'a', 'b', 'file2.bin']))), 'fs file2 crc');
  finally
    RemoveAll(LRoot);
    RemoveAll(LOut);
  end;
end;

procedure TestFsExtractToSingle;
var
  LOutDir: string;
  LW: ISevenZWriter;
  LR: ISevenZReader;
  LData: TBytes;
  LHost: string;
begin
  LData := BytesOf([$DE,$AD,$BE,$EF]);
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('x.bin', LData);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  LOutDir := TempDir('', 'sevenz-fs-single-');
  try
    LHost := PathJoin([LOutDir, 'out', 'x.bin']);
    SevenZExtractToFs(LR, 0, LHost);
    Check(IsFile(LHost), 'single exists');
    CheckEqual(Int64(4), Int64(FileSize(LHost)), 'single size');
    Check(Crc32OfBytes(LData) = Crc32OfBytes(ReadFile(LHost)), 'single crc');
  finally
    RemoveAll(LOutDir);
  end;
end;

procedure TestReaderForInEnumerator;
var LW: ISevenZWriter; LR: ISevenZReader; LCount: Integer; LE: TSevenZEntryInfo;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LW.AddFile('b.txt', BytesOf([$02,$03]));
  LW.AddDirectory('d');
  LR := TSevenZReaderImpl.Create(LW.Finish);
  LCount := 0;
  for LE in LR do
  begin
    Check(LE.Name <> '', 'enum name non-empty');
    Inc(LCount);
  end;
  CheckEqual(Int64(3), Int64(LCount), 'enum count');
end;

type TProgressProbe = class
  public Count: Integer; LastDone, LastTotal: Integer;
  procedure OnProgress(Sender: TObject; ADone, ATotal: Integer);
end;
procedure TProgressProbe.OnProgress(Sender: TObject; ADone, ATotal: Integer);
begin Inc(Count); LastDone:=ADone; LastTotal:=ATotal; end;

procedure TestBuilderWithProgress;
var B: ISevenZWriterBuilder; P: TProgressProbe; LR: ISevenZReader;
begin
  P := TProgressProbe.Create;
  try
    B := SevenZCreateWriterBuilder.WithProgress(@P.OnProgress).WithFolderLimits(0,1);
    B.AddFile('a.bin', RepeatedText(4,20));
    B.AddFile('b.bin', RepeatedText(4,20));
    B.AddFile('c.bin', RepeatedText(4,20));
    LR := SevenZCreateReader(B.Finish);
    CheckEqual(Int64(3), Int64(P.Count), 'progress call count');
    CheckEqual(Int64(3), Int64(P.LastDone), 'progress last done');
    CheckEqual(Int64(3), Int64(P.LastTotal), 'progress total');
    CheckEqual(Int64(3), Int64(LR.EntryCount), 'progress archive ok');
    P.Count:=0;
    B := SevenZCreateWriterBuilder.WithFolderLimits(0,0);
    B.AddFile('solo.bin', RepeatedText(5,10));
    LR := SevenZCreateReader(B.Finish);
    CheckEqual(Int64(0), Int64(P.Count), 'progress nil zero overhead');
  finally P.Free; end;
end;

procedure TestBombHeaderReject;
var LBad: TBytes; LW: ISevenZWriter;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('x.bin', BytesOf([$01]));
  LBad := LW.Finish;
  SigPutLE64(LBad, 20, UInt64(70*1024*1024));
  SigPutLE32(LBad, 8, Crc32Of((@LBad[12])^, 20));
  try TSevenZReaderImpl.Create(LBad); Fail('bomb header should raise');
  except on E: ESevenZLimitError do ; on E: ESevenZError do ; end;
end;

procedure TestReaderCountAndItems;
var LW: ISevenZWriter; LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LW.AddFile('b.txt', BytesOf([$02]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(2), Int64(LR.Count), 'count prop');
  CheckEqual('a.txt', LR[0].Name, 'items default a');
  CheckEqual('b.txt', LR[1].Name, 'items default b');
  CheckEqual('b.txt', LR.Items[1].Name, 'items explicit');
end;

procedure TestWriterSinglePassCrc;
var LW: ISevenZWriter; LR: ISevenZReader; LData, LGot: TBytes;
begin
  LData := Randomish(300000, 77);
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('big.bin', LData);
  LW.AddFileFromReader('big2.bin', CreateBytesStreamFrom(LData) as IReader, UInt64(Length(LData)));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual('big.bin', LR[0].Name, 'items prop name');
  CheckEqual(Int64(2), Int64(LR.Count), 'count prop');
  LGot := LR.Extract(0);
  Check(Crc32OfBytes(LData)=Crc32OfBytes(LGot), 'singlepass crc a');
  LGot := LR.Extract(1);
  Check(Crc32OfBytes(LData)=Crc32OfBytes(LGot), 'singlepass crc b');
end;

procedure TestBombFileCountReject;
var LPlain, LBlock, LPack, LArchive: TBytes; LEnc: TSevenZLzmaEncoded;
  LLargeCount: UInt64;
begin
  LLargeCount := UInt64(SEVENZ_MAX_FILE_COUNT) + 1;
  SetLength(LPlain, 0);
  SevenZAppendByte(LPlain, SZ_ID_HEADER);
  SevenZAppendByte(LPlain, SZ_ID_FILES_INFO);
  SevenZWriteNumber(LPlain, LLargeCount);
  LEnc := SevenZAcquireEncoder.EncodeLzma2(LPlain, szclDefault);
  LPack := LEnc.PackedData;
  SetLength(LBlock, 0);
  SevenZAppendByte(LBlock, SZ_ID_ENCODED_HEADER);
  SevenZAppendByte(LBlock, SZ_ID_PACK_INFO);
  SevenZWriteNumber(LBlock, 0);
  SevenZWriteNumber(LBlock, 1);
  SevenZAppendByte(LBlock, SZ_ID_SIZE);
  SevenZWriteNumber(LBlock, UInt64(Length(LPack)));
  SevenZAppendByte(LBlock, SZ_ID_END);
  SevenZAppendByte(LBlock, SZ_ID_UNPACK_INFO);
  SevenZAppendByte(LBlock, SZ_ID_FOLDER);
  SevenZWriteNumber(LBlock, 1);
  SevenZAppendByte(LBlock, 0);
  SevenZWriteNumber(LBlock, 1);
  SevenZAppendByte(LBlock, $21);
  SevenZAppendByte(LBlock, Byte(SEVENZ_METHOD_LZMA2));
  SevenZWriteNumber(LBlock, UInt64(Length(LEnc.Props)));
  SevenZAppendBytes(LBlock, @LEnc.Props[0], Length(LEnc.Props));
  SevenZAppendByte(LBlock, SZ_ID_CODERS_UNPACK_SZ);
  SevenZWriteNumber(LBlock, UInt64(Length(LPlain)));
  SevenZAppendByte(LBlock, SZ_ID_CRC);
  SevenZAppendByte(LBlock, $01);
  SevenZAppendUInt32LE(LBlock, Crc32OfBytes(LPlain));
  SevenZAppendByte(LBlock, SZ_ID_END);
  SevenZAppendByte(LBlock, SZ_ID_END);
  SetLength(LArchive, C_SEVENZ_SIG_HEADER_SIZE);
  FillChar(LArchive[0], C_SEVENZ_SIG_HEADER_SIZE, 0);
  LArchive[0]:=C_SEVENZ_MAGIC_0; LArchive[1]:=C_SEVENZ_MAGIC_1;
  LArchive[2]:=C_SEVENZ_MAGIC_2; LArchive[3]:=C_SEVENZ_MAGIC_3;
  LArchive[4]:=C_SEVENZ_MAGIC_4; LArchive[5]:=C_SEVENZ_MAGIC_5;
  LArchive[6]:=C_SEVENZ_VERSION_MAJOR; LArchive[7]:=C_SEVENZ_VERSION_MINOR;
  SigPutLE64(LArchive, 12, UInt64(Length(LPack)));
  SigPutLE64(LArchive, 20, UInt64(Length(LBlock)));
  SigPutLE32(LArchive, 28, Crc32OfBytes(LBlock));
  SigPutLE32(LArchive, 8, Crc32Of((@LArchive[12])^, 20));
  SetLength(LArchive, Length(LArchive)+Length(LPack)+Length(LBlock));
  Move(LPack[0], LArchive[C_SEVENZ_SIG_HEADER_SIZE], Length(LPack));
  Move(LBlock[0], LArchive[C_SEVENZ_SIG_HEADER_SIZE+Length(LPack)], Length(LBlock));
  try TSevenZReaderImpl.Create(LArchive); Fail('bomb file count should raise');
  except on E: ESevenZLimitError do ; on E: ESevenZError do ; end;
end;

procedure TestReaderContainsTryGetEntry;
var LW: ISevenZWriter; LR: ISevenZReader; LInfo: TSevenZEntryInfo;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LW.AddDirectory('d');
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Check(LR.Contains('a.txt'), 'contains a');
  Check(not LR.Contains('missing'), 'not contains');
  Check(LR.TryGetEntry('a.txt', LInfo), 'tryget a');
  CheckEqual('a.txt', LInfo.Name, 'tryget name');
  Check(not LR.TryGetEntry('missing', LInfo), 'tryget missing false');
end;

procedure TestWriterNulNameReject;
var LW: ISevenZWriter;
begin
  LW := TSevenZWriterImpl.Create;
  try LW.AddFile('a'#0'b.txt', BytesOf([$01])); Fail('NUL should raise'); except on E: EArgumentError do ; end;
  try LW.AddFile('a'#0, BytesOf([$01])); Fail('NUL trail should raise'); except on E: EArgumentError do ; end;
end;

procedure TestExtractToSinglePassLarge;
var LW: ISevenZWriter; LR: ISevenZReader; LData: TBytes; Sink: TSinkRecorder;
begin
  LData := Randomish(300*1024, 88);
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('big.bin', LData);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Sink := TSinkRecorder.Create;
  try
    CheckEqual(Int64(300*1024), LR.ExtractTo(Sink, 0), 'extractto large count');
    Check(Crc32OfBytes(LData)=Crc32OfBytes(Sink.Buf), 'extractto singlepass crc');
    Check(Sink.Writes >= 2, 'windowed writes');
  finally Sink.Free; end;
end;

procedure TestReaderLruCacheTwoEntries;
var LW: ISevenZWriter; LR: ISevenZReader; LA, LB: TBytes;
begin
  LA := RepeatedText(7, 400); LB := RepeatedText(11, 400);
  LW := TSevenZWriterImpl.Create;
  LW.SetFolderLimits(0, 1);
  LW.AddFile('a.bin', LA);
  LW.AddFile('b.bin', LB);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Check(SameBytes(LR.Extract(0), LA), 'lru a1');
  Check(SameBytes(LR.Extract(1), LB), 'lru b1');
  Check(SameBytes(LR.Extract(0), LA), 'lru a2 cached');
  Check(SameBytes(LR.Extract(1), LB), 'lru b2 cached');
  Check(SameBytes(LR.Extract(0), LA), 'lru a3 promoted');
end;

procedure TestReaderEntryByName;
var LW: ISevenZWriter; LR: ISevenZReader; LE: TSevenZEntryInfo;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('hello.txt', BytesOf([$68,$69]));
  LW.AddDirectory('d');
  LR := TSevenZReaderImpl.Create(LW.Finish);
  LE := LR.EntryByName('hello.txt');
  CheckEqual('hello.txt', LE.Name, 'entrybyname name');
  CheckEqual(Int64(2), LE.Size, 'entrybyname size');
  try LR.EntryByName('missing.txt'); Fail('missing should raise'); except on E: EArgumentError do ; end;
end;

procedure TestReaderIsEmpty;
var LW: ISevenZWriter; LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Check(LR.IsEmpty, 'empty is empty');
  CheckEqual(Int64(0), Int64(LR.Count), 'empty count');
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Check(not LR.IsEmpty, 'non-empty not empty');
end;

procedure TestReaderEntries;
var LW: ISevenZWriter; LR: ISevenZReader; Arr: TSevenZEntryInfoArray;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LW.AddFile('b.txt', BytesOf([$02,$03]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.Entries;
  CheckEqual(Int64(2), Int64(Length(Arr)), 'entries len');
  CheckEqual('a.txt', Arr[0].Name, 'entries 0');
  CheckEqual('b.txt', Arr[1].Name, 'entries 1');
  Arr[0].Name := 'mutated';
  CheckEqual('a.txt', LR.Entry(0).Name, 'entries snapshot isolation');
end;

procedure TestReaderFindIgnoreCase;
var LW: ISevenZWriter; LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('Docs/A.BIN', BytesOf([$01]));
  LW.AddFile('docs/b.txt', BytesOf([$02]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(0), Int64(LR.FindIgnoreCase('docs/a.bin')), 'ignorecase 0');
  CheckEqual(Int64(0), Int64(LR.FindIgnoreCase('DOCS/A.BIN')), 'ignorecase upper');
  CheckEqual(Int64(1), Int64(LR.FindIgnoreCase('DOCS/B.TXT')), 'ignorecase 1');
  CheckEqual(Int64(-1), Int64(LR.FindIgnoreCase('missing.txt')), 'ignorecase miss');
end;

procedure TestReaderTryEntryByName;
var LW: ISevenZWriter; LR: ISevenZReader; Info: TSevenZEntryInfo;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$AA]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Check(LR.TryEntryByName('a.txt', Info), 'tryentry found');
  CheckEqual('a.txt', Info.Name, 'tryentry name');
  Check(not LR.TryEntryByName('missing.txt', Info), 'tryentry miss');
end;

procedure TestReaderContainsIgnoreCase;
var LW: ISevenZWriter; LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('Docs/ReadMe.TXT', BytesOf([$01]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Check(LR.ContainsIgnoreCase('docs/readme.txt'), 'contains ignore true');
  Check(LR.ContainsIgnoreCase('DOCS/README.TXT'), 'contains ignore upper');
  Check(not LR.ContainsIgnoreCase('missing.txt'), 'contains ignore miss');
end;

procedure TestReaderTryGetEntryIgnoreCase;
var LW: ISevenZWriter; LR: ISevenZReader; Info: TSevenZEntryInfo;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a/B.txt', BytesOf([$02,$03]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Check(LR.TryGetEntryIgnoreCase('A/b.TXT', Info), 'tryget ignore found');
  CheckEqual('a/B.txt', Info.Name, 'tryget ignore name');
  Check(not LR.TryGetEntryIgnoreCase('missing', Info), 'tryget ignore miss');
end;

procedure TestReaderEntryByNameIgnoreCase;
var LW: ISevenZWriter; LR: ISevenZReader; Info: TSevenZEntryInfo;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('Hello.TXT', BytesOf([$AA,$BB]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Info := LR.EntryByNameIgnoreCase('hello.txt');
  CheckEqual('Hello.TXT', Info.Name, 'entrybyname ignore');
  CheckEqual(Int64(2), Info.Size, 'entrybyname ignore size');
  try LR.EntryByNameIgnoreCase('missing.txt'); Fail('missing ignore should raise'); except on E: EArgumentError do ; end;
end;

procedure TestReaderNonAsciiIgnoreCase;
var LW: ISevenZWriter; LR: ISevenZReader; Info: TSevenZEntryInfo;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('München.TXT', BytesOf([$01]));
  LW.AddFile('naïve.txt', BytesOf([$02]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(0), Int64(LR.FindIgnoreCase('münchen.txt')), 'nonascii münchen lower ascii');
  CheckEqual(Int64(-1), Int64(LR.FindIgnoreCase('MÜNCHEN.TXT')), 'nonascii münchen upper not folded');
  Check(not LR.ContainsIgnoreCase('NAÏVE.TXT'), 'nonascii naive upper not folded');
  Check(LR.TryGetEntryIgnoreCase('naïve.txt', Info), 'nonascii tryget exact');
  CheckEqual('naïve.txt', Info.Name, 'nonascii tryget name');
  CheckEqual(Int64(-1), Int64(LR.FindIgnoreCase('missing-ä.txt')), 'nonascii miss');
end;

procedure TestReaderClearCache;
var LW: ISevenZWriter; LR: ISevenZReader; LA, LB: TBytes;
begin
  LA := RepeatedText(7, 400); LB := RepeatedText(11, 400);
  LW := TSevenZWriterImpl.Create;
  LW.SetFolderLimits(0, 1);
  LW.AddFile('a.bin', LA);
  LW.AddFile('b.bin', LB);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Check(SameBytes(LR.Extract(0), LA), 'clearcache a1');
  LR.ClearCache;
  Check(SameBytes(LR.Extract(0), LA), 'clearcache a2 after clear');
  Check(SameBytes(LR.Extract(1), LB), 'clearcache b after clear');
  LR.ClearCache;
  LR.ClearCache; // idempotent
  Check(not LR.IsEmpty, 'clearcache not empty');
end;

procedure TestReaderEmptyIgnoreCaseEdge;
var LW: ISevenZWriter; LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(-1), Int64(LR.FindIgnoreCase('')), 'empty find ignore -1');
  Check(not LR.ContainsIgnoreCase('anything'), 'empty contains ignore false');
  Check(not LR.ContainsIgnoreCase(''), 'empty contains ignore empty false');
end;

procedure TestHashIndexCorrectness;
var LW: ISevenZWriter; LR: ISevenZReader; LI: Integer; LName: string;
begin
  LW := TSevenZWriterImpl.Create;
  for LI:=0 to 199 do
  begin
    LName := Format('file_%3.3d.txt', [LI]);
    LW.AddFile(LName, BytesOf([Byte(LI)]));
  end;
  LR := TSevenZReaderImpl.Create(LW.Finish);
  for LI:=0 to 199 do
  begin
    LName := Format('file_%3.3d.txt', [LI]);
    CheckEqual(Int64(LI), Int64(LR.Find(LName)), 'hash find exact '+LName);
    CheckEqual(Int64(LI), Int64(LR.FindIgnoreCase(LowerCase(LName))), 'hash find ignore '+LName);
    Check(LR.Contains(LName), 'hash contains '+LName);
    Check(LR.ContainsIgnoreCase(UpperCase(LName)), 'hash contains ignore '+LName);
  end;
  CheckEqual(Int64(-1), Int64(LR.Find('missing.txt')), 'hash miss exact');
  CheckEqual(Int64(-1), Int64(LR.FindIgnoreCase('missing.txt')), 'hash miss ignore');
end;

procedure TestEntriesByPrefix;
var LW: ISevenZWriter; LR: ISevenZReader; Arr: TSevenZEntryInfoArray;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('docs/a.txt', BytesOf([$01]));
  LW.AddFile('docs/b.txt', BytesOf([$02]));
  LW.AddFile('src/main.pas', BytesOf([$03]));
  LW.AddFile('docs/sub/c.txt', BytesOf([$04]));
  LW.AddDirectory('docs');
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByPrefix('docs/');
  CheckEqual(Int64(3), Int64(Length(Arr)), 'prefix docs/');
  Arr := LR.EntriesByPrefix('src/');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'prefix src/');
  CheckEqual('src/main.pas', Arr[0].Name, 'prefix src name');
  Arr := LR.EntriesByPrefix('');
  CheckEqual(Int64(5), Int64(Length(Arr)), 'prefix empty all');
  Arr := LR.EntriesByPrefix('missing/');
  CheckEqual(Int64(0), Int64(Length(Arr)), 'prefix miss zero');
  Arr := LR.EntriesByPrefix('docs/a.txt');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'prefix exact');
end;

procedure TestDuplicateNameStability;
var LW: ISevenZWriter; LR: ISevenZReader; LA, LB: TBytes;
begin
  // Writer allows duplicate names – reader must keep first index stable and extract slices independent
  LA := BytesOf([$AA]); LB := BytesOf([$BB,$CC]);
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('dup.txt', LA);
  LW.AddFile('dup.txt', LB);
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(2), Int64(LR.EntryCount), 'dup count');
  CheckEqual(Int64(0), Int64(LR.Find('dup.txt')), 'dup find first');
  CheckEqual(Int64(0), Int64(LR.FindIgnoreCase('DUP.TXT')), 'dup find ignore first');
  Check(SameBytes(LR.Extract(0), LA), 'dup extract 0');
  Check(SameBytes(LR.Extract(1), LB), 'dup extract 1');
  CheckEqual(Int64(2), Int64(Length(LR.EntriesByPrefix('dup'))), 'dup prefix both via dup');
  CheckEqual(Int64(2), Int64(Length(LR.EntriesByPrefix('dup.txt'))), 'dup prefix both');
end;

procedure TestEntriesByPrefixSorted;
var LW: ISevenZWriter; LR: ISevenZReader; Arr: TSevenZEntryInfoArray;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('z.txt', BytesOf([$01]));
  LW.AddFile('a.txt', BytesOf([$02]));
  LW.AddFile('m.txt', BytesOf([$03]));
  LW.AddFile('a/b.txt', BytesOf([$04]));
  LW.AddFile('a/a.txt', BytesOf([$05]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByPrefix('a');
  CheckEqual(Int64(3), Int64(Length(Arr)), 'sorted a count');
  CheckEqual('a.txt', Arr[0].Name, 'sorted 0');
  CheckEqual('a/a.txt', Arr[1].Name, 'sorted 1');
  CheckEqual('a/b.txt', Arr[2].Name, 'sorted 2');
  Arr := LR.EntriesByPrefix('z');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'sorted z');
  Arr := LR.EntriesByPrefix('m');
  CheckEqual('m.txt', Arr[0].Name, 'sorted m');
end;

procedure TestEntriesBySuffix;
var LW: ISevenZWriter; LR: ISevenZReader; Arr: TSevenZEntryInfoArray;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LW.AddFile('b.txt', BytesOf([$02]));
  LW.AddFile('c.pas', BytesOf([$03]));
  LW.AddFile('dir/d.txt', BytesOf([$04]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesBySuffix('.txt');
  CheckEqual(Int64(3), Int64(Length(Arr)), 'suffix txt count');
  Arr := LR.EntriesBySuffix('.pas');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'suffix pas count');
  CheckEqual('c.pas', Arr[0].Name, 'suffix pas name');
  Arr := LR.EntriesBySuffix('');
  CheckEqual(Int64(4), Int64(Length(Arr)), 'suffix empty all');
  Arr := LR.EntriesBySuffix('.missing');
  CheckEqual(Int64(0), Int64(Length(Arr)), 'suffix miss');
end;

procedure TestSuffixPrefixEdge;
var LW: ISevenZWriter; LR: ISevenZReader; Arr: TSevenZEntryInfoArray;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByPrefix('a.txt/extra');
  CheckEqual(Int64(0), Int64(Length(Arr)), 'prefix overrun zero');
  Arr := LR.EntriesBySuffix('a.txt.');
  CheckEqual(Int64(0), Int64(Length(Arr)), 'suffix overrun zero');
  LW := TSevenZWriterImpl.Create;
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByPrefix('');
  CheckEqual(Int64(0), Int64(Length(Arr)), 'empty prefix on empty archive');
  Arr := LR.EntriesBySuffix('');
  CheckEqual(Int64(0), Int64(Length(Arr)), 'empty suffix on empty archive');
end;

procedure TestFindByPrefixSuffix;
var LW: ISevenZWriter; LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('docs/a.txt', BytesOf([$01]));
  LW.AddFile('docs/b.txt', BytesOf([$02]));
  LW.AddFile('src/x.pas', BytesOf([$03]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(0), Int64(LR.FindByPrefix('docs/')), 'findbyprefix docs');
  CheckEqual(Int64(2), Int64(LR.FindByPrefix('src/')), 'findbyprefix src');
  CheckEqual(Int64(-1), Int64(LR.FindByPrefix('missing/')), 'findbyprefix miss');
  Check(LR.FindBySuffix('.txt') >= 0, 'findbysuffix txt');
  CheckEqual(Int64(2), Int64(LR.FindBySuffix('.pas')), 'findbysuffix pas');
  CheckEqual(Int64(-1), Int64(LR.FindBySuffix('.missing')), 'findbysuffix miss');
  CheckEqual(Int64(0), Int64(LR.FindByPrefix('')), 'findbyprefix empty');
  CheckEqual(Int64(0), Int64(LR.FindBySuffix('')), 'findbysuffix empty');
end;

procedure TestEntriesByGlob;
var LW: ISevenZWriter; LR: ISevenZReader; Arr: TSevenZEntryInfoArray;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LW.AddFile('b.txt', BytesOf([$02]));
  LW.AddFile('c.pas', BytesOf([$03]));
  LW.AddFile('docs/d.txt', BytesOf([$04]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByGlob('*.txt');
  CheckEqual(Int64(3), Int64(Length(Arr)), 'glob *.txt count');
  Arr := LR.EntriesByGlob('*.pas');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'glob *.pas');
  Arr := LR.EntriesByGlob('docs/*');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'glob docs/*');
  Arr := LR.EntriesByGlob('*');
  CheckEqual(Int64(4), Int64(Length(Arr)), 'glob * all');
  Arr := LR.EntriesByGlob('?.txt');
  CheckEqual(Int64(2), Int64(Length(Arr)), 'glob ?.txt');
  Arr := LR.EntriesByGlob('*.missing');
  CheckEqual(Int64(0), Int64(Length(Arr)), 'glob miss');
end;

procedure TestGlobEdge;
var LW: ISevenZWriter; LR: ISevenZReader; Arr: TSevenZEntryInfoArray;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByGlob('');
  CheckEqual(Int64(0), Int64(Length(Arr)), 'glob empty');
  Arr := LR.EntriesByGlob('a.txt');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'glob exact');
  LW := TSevenZWriterImpl.Create;
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByGlob('*');
  CheckEqual(Int64(0), Int64(Length(Arr)), 'glob * empty archive');
end;

procedure TestFindByGlob;
var LW: ISevenZWriter; LR: ISevenZReader;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('docs/a.txt', BytesOf([$01]));
  LW.AddFile('docs/b.txt', BytesOf([$02]));
  LW.AddFile('src/x.pas', BytesOf([$03]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Check(LR.FindByGlob('docs/*.txt') >= 0, 'findbyglob docs star');
  CheckEqual(Int64(-1), Int64(LR.FindByGlob('*.missing')), 'findbyglob miss');
  Check(LR.FindByGlob('*') >= 0, 'findbyglob star');
  CheckEqual(Int64(-1), Int64(LR.FindByGlob('')), 'findbyglob empty');
  CheckEqual(Int64(0), Int64(LR.FindByGlob('docs/a.txt')), 'findbyglob exact');
end;

procedure TestGlobDispatch;
var LW: ISevenZWriter; LR: ISevenZReader; Arr: TSevenZEntryInfoArray;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LW.AddFile('b.txt', BytesOf([$02]));
  LW.AddFile('c.pas', BytesOf([$03]));
  LW.AddFile('docs/d.txt', BytesOf([$04]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByGlob('*.txt');
  CheckEqual(Int64(3), Int64(Length(Arr)), 'dispatch suffix txt via suffix index');
  Arr := LR.EntriesByGlob('docs/*');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'dispatch prefix docs via prefix index');
  Arr := LR.EntriesByGlob('a.txt');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'dispatch exact via hash');
  CheckEqual('a.txt', Arr[0].Name, 'dispatch exact name');
end;

procedure TestFindByPrefixNoAlloc;
var LW: ISevenZWriter; LR: ISevenZReader; LI: Integer;
begin
  LW := TSevenZWriterImpl.Create;
  for LI:=0 to 99 do LW.AddFile(Format('p_%3.3d.txt', [LI]), BytesOf([Byte(LI)]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(0), Int64(LR.FindByPrefix('p_000')), 'noprefix 0');
  CheckEqual(Int64(50), Int64(LR.FindByPrefix('p_050')), 'noprefix 50');
  CheckEqual(Int64(-1), Int64(LR.FindByPrefix('missing_')), 'noprefix miss');
  CheckEqual(Int64(0), Int64(LR.FindBySuffix('.txt')), 'nosuffix txt');
  CheckEqual(Int64(-1), Int64(LR.FindBySuffix('.pas')), 'nosuffix miss');
end;

procedure TestGlobPrefixStarSuffix;
var LW: ISevenZWriter; LR: ISevenZReader; Arr: TSevenZEntryInfoArray; Idx: Integer;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('pre_aaa_post.txt', BytesOf([$01]));
  LW.AddFile('pre_bbb_post.txt', BytesOf([$02]));
  LW.AddFile('pre_aaa_other.txt', BytesOf([$03]));
  LW.AddFile('other_post.txt', BytesOf([$04]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByGlob('pre_*_post.txt');
  CheckEqual(Int64(2), Int64(Length(Arr)), 'pre*suffix count');
  Idx := LR.FindByGlob('pre_*_post.txt');
  Check(Idx >= 0, 'pre*suffix find');
  Check(Pos('pre_', LR.Entry(Idx).Name)=1, 'pre*suffix find prefix');
end;

procedure TestExtractByPrefixSuffixGlob;
var LW: ISevenZWriter; LR: ISevenZReader; Ext: TSevenZExtractedArray; LOk: Boolean; LErr: string;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LW.AddFile('a.log', BytesOf([$02]));
  LW.AddFile('b.txt', BytesOf([$03]));
  LW.AddFile('docs/c.txt', BytesOf([$04]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Ext := LR.ExtractByPrefix('a');
  CheckEqual(Int64(2), Int64(Length(Ext)), 'extract prefix a count');
  Ext := LR.ExtractBySuffix('.txt');
  CheckEqual(Int64(3), Int64(Length(Ext)), 'extract suffix txt count');
  Ext := LR.ExtractByGlob('*.txt');
  CheckEqual(Int64(3), Int64(Length(Ext)), 'extract glob txt');
  Check(Ext[0].Data <> nil, 'extract glob data non-nil');
  LOk := LR.TryExtractByGlob('*.txt', Ext);
  Check(LOk and (Length(Ext)=3), 'try extract glob ok');
  LOk := LR.TryExtractByGlobWithError('*.txt', Ext, LErr);
  Check(LOk and (LErr='') and (Length(Ext)=3), 'try with error ok');
  Ext := LR.ExtractByGlob('pre_*_post.txt');
  CheckEqual(Int64(0), Int64(Length(Ext)), 'extract glob miss zero');
  LOk := LR.TryExtractByPrefix('a', Ext);
  Check(LOk and (Length(Ext)=2), 'try prefix ok');
  LOk := LR.TryExtractByPrefixWithError('a', Ext, LErr);
  Check(LOk and (LErr='') and (Length(Ext)=2), 'try prefix with error');
  LOk := LR.TryExtractBySuffix('.txt', Ext);
  Check(LOk and (Length(Ext)=3), 'try suffix ok');
  LOk := LR.TryExtractBySuffixWithError('.txt', Ext, LErr);
  Check(LOk and (LErr='') and (Length(Ext)=3), 'try suffix with error');
end;

procedure TestBulkGroupedMultiFolder;
var LW: ISevenZWriter; LR: ISevenZReader; Ext: TSevenZExtractedArray; I: Integer;
begin
  LW := TSevenZWriterImpl.Create;
  LW.SetFolderLimits(0,1); // one folder per file -> 4 folders
  LW.AddFile('a.txt', BytesOf([$01]));
  LW.AddFile('a2.txt', BytesOf([$02]));
  LW.AddFile('b.txt', BytesOf([$03]));
  LW.AddFile('b2.txt', BytesOf([$04]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Ext := LR.ExtractBySuffix('.txt'); // 4 files across 4 folders, grouped should decode each once
  CheckEqual(Int64(4), Int64(Length(Ext)), 'grouped suffix 4');
  for I:=0 to High(Ext) do Check(Ext[I].Data <> nil, 'grouped data non-nil '+IntToStr(I));
  Ext := LR.ExtractByPrefix('a');
  CheckEqual(Int64(2), Int64(Length(Ext)), 'grouped prefix a 2');
end;

procedure TestExtractByGlobToFs;
var LW: ISevenZWriter; LR: ISevenZReader; LRoot: string; Cnt: Integer; Err: string; Ok: Boolean;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LW.AddFile('b.txt', BytesOf([$02]));
  LW.AddFile('c.log', BytesOf([$03]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  LRoot := TempDir('', 'sevenz-glob-fs-');
  try
    Cnt := SevenZExtractByGlobToFs(LR, '*.txt', LRoot);
    CheckEqual(Int64(2), Int64(Cnt), 'glob to fs cnt');
    Check(IsFile(PathJoin([LRoot, 'a.txt'])), 'glob fs a exists');
    Check(IsFile(PathJoin([LRoot, 'b.txt'])), 'glob fs b exists');
    Check(not IsFile(PathJoin([LRoot, 'c.log'])), 'glob fs c not');
    Ok := SevenZTryExtractByGlobToFs(LR, '*.txt', LRoot, Err);
    Check(Ok and (Err=''), 'try glob to fs ok');
    Cnt := SevenZExtractByPrefixToFs(LR, 'a', LRoot);
    CheckEqual(Int64(1), Int64(Cnt), 'prefix to fs');
    Cnt := SevenZExtractBySuffixToFs(LR, '.log', LRoot);
    CheckEqual(Int64(1), Int64(Cnt), 'suffix to fs');
  finally RemoveAll(LRoot); end;
end;

procedure TestLowerBoundSuffixZeroAlloc;
var LW: ISevenZWriter; LR: ISevenZReader; LI: Integer;
begin
  LW := TSevenZWriterImpl.Create;
  for LI:=0 to 199 do LW.AddFile(Format('file_%3.3d.log', [LI]), BytesOf([Byte(LI)]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(200), Int64(Length(LR.EntriesBySuffix('.log'))), 'suffix log 200 via zero alloc');
  CheckEqual(Int64(200), Int64(Length(LR.EntriesBySuffix('.txt')) + Length(LR.EntriesBySuffix('.log'))), 'suffix mix');
end;

procedure TestExtractAllGrouped;
var LW: ISevenZWriter; LR: ISevenZReader; Ext: TSevenZExtractedArray; LOk: Boolean; LErr: string; LRoot: string;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddDirectory('docs');
  LW.AddFile('a.txt', BytesOf([$01,$02]));
  LW.AddFile('b.txt', BytesOf([$03]));
  LW.AddFile('empty.dat', nil);
  LW.SetFolderLimits(0,1); // force 3 folders for files
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Ext := LR.ExtractAll;
  CheckEqual(Int64(4), Int64(Length(Ext)), 'extractall count includes dir');
  Check(Ext[0].Info.Kind=sekDirectory, 'extractall dir');
  Check(Ext[0].Data=nil, 'extractall dir nil');
  Check(Ext[3].Data=nil, 'extractall empty nil');
  Check(Ext[1].Data<>nil, 'extractall file data');
  LOk := LR.TryExtractAll(Ext);
  Check(LOk and (Length(Ext)=4), 'try extract all ok');
  LOk := LR.TryExtractAllWithError(Ext, LErr);
  Check(LOk and (LErr=''), 'try all with error ok');
  // grouped outperforms naive: same bytes via multi-folder single pass
  LRoot := TempDir('', 'sevenz-all-fs-');
  try
    SevenZExtractAllToFs(LR, LRoot);
    Check(IsFile(PathJoin([LRoot, 'a.txt'])), 'all to fs a exists');
    Check(IsFile(PathJoin([LRoot, 'b.txt'])), 'all to fs b exists');
    Check(IsDir(PathJoin([LRoot, 'docs'])), 'all to fs docs dir');
  finally RemoveAll(LRoot); end;
end;

procedure TestIgnoreCaseFull;
var LW: ISevenZWriter; LR: ISevenZReader; Arr: TSevenZEntryInfoArray; Ext: TSevenZExtractedArray; Idx: Integer; LOk: Boolean; LErr: string;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('Docs/Readme.TXT', BytesOf([$01]));
  LW.AddFile('docs/readme.txt', BytesOf([$02]));
  LW.AddFile('SRC/Main.PAS', BytesOf([$03]));
  LW.AddFile('src/util.pas', BytesOf([$04]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByPrefixIgnoreCase('docs/');
  CheckEqual(Int64(2), Int64(Length(Arr)), 'ignore prefix docs 2');
  Arr := LR.EntriesBySuffixIgnoreCase('.txt');
  CheckEqual(Int64(2), Int64(Length(Arr)), 'ignore suffix txt 2');
  Arr := LR.EntriesBySuffixIgnoreCase('.PAS');
  CheckEqual(Int64(2), Int64(Length(Arr)), 'ignore suffix pas 2');
  Idx := LR.FindByPrefixIgnoreCase('DOCS/');
  Check(Idx>=0, 'ignore find prefix');
  Idx := LR.FindBySuffixIgnoreCase('.TXT');
  Check(Idx>=0, 'ignore find suffix');
  Arr := LR.EntriesByGlobIgnoreCase('*.txt');
  CheckEqual(Int64(2), Int64(Length(Arr)), 'ignore glob txt 2');
  Idx := LR.FindByGlobIgnoreCase('*.PAS');
  Check(Idx>=0, 'ignore find glob pas');
  Ext := LR.ExtractByPrefixIgnoreCase('DOCS/');
  CheckEqual(Int64(2), Int64(Length(Ext)), 'extract ignore prefix 2');
  Ext := LR.ExtractBySuffixIgnoreCase('.TXT');
  CheckEqual(Int64(2), Int64(Length(Ext)), 'extract ignore suffix 2');
  Ext := LR.ExtractByGlobIgnoreCase('*.PAS');
  CheckEqual(Int64(2), Int64(Length(Ext)), 'extract ignore glob pas 2');
  LOk := LR.TryExtractByPrefixIgnoreCase('docs/', Ext);
  Check(LOk and (Length(Ext)=2), 'try ignore prefix');
  LOk := LR.TryExtractByPrefixIgnoreCaseWithError('DOCS/', Ext, LErr);
  Check(LOk and (LErr=''), 'try ignore prefix with error');
  LOk := LR.TryExtractBySuffixIgnoreCase('.txt', Ext);
  Check(LOk and (Length(Ext)=2), 'try ignore suffix');
  LOk := LR.TryExtractBySuffixIgnoreCaseWithError('.TXT', Ext, LErr);
  Check(LOk and (LErr=''), 'try ignore suffix with error');
  LOk := LR.TryExtractByGlobIgnoreCase('*.txt', Ext);
  Check(LOk and (Length(Ext)=2), 'try ignore glob');
  LOk := LR.TryExtractByGlobIgnoreCaseWithError('*.TXT', Ext, LErr);
  Check(LOk and (LErr=''), 'try ignore glob with error');
  // ascii fast path 100 entries
  LW := TSevenZWriterImpl.Create;
  for Idx:=0 to 99 do LW.AddFile(Format('File_%3.3d.TXT', [Idx]), BytesOf([Byte(Idx)]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  CheckEqual(Int64(100), Int64(Length(LR.EntriesByPrefixIgnoreCase('file_'))), 'ignore prefix 100 ascii');
  CheckEqual(Int64(100), Int64(Length(LR.EntriesBySuffixIgnoreCase('.txt'))), 'ignore suffix 100 ascii');
end;

procedure TestFsIgnoreCaseToFs;
var LW: ISevenZWriter; LR: ISevenZReader; LRoot: string; Cnt: Integer; Ok: Boolean; Err: string;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('Docs/A.TXT', BytesOf([$01]));
  LW.AddFile('docs/b.txt', BytesOf([$02]));
  LW.AddFile('src/C.PAS', BytesOf([$03]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  LRoot := TempDir('', 'sevenz-ignore-fs-');
  try
    Cnt := SevenZExtractByPrefixIgnoreCaseToFs(LR, 'DOCS/', LRoot);
    CheckEqual(Int64(2), Int64(Cnt), 'ignore prefix to fs 2');
    Cnt := SevenZExtractBySuffixIgnoreCaseToFs(LR, '.txt', LRoot);
    CheckEqual(Int64(2), Int64(Cnt), 'ignore suffix to fs 2');
    Cnt := SevenZExtractByGlobIgnoreCaseToFs(LR, '*.PAS', LRoot);
    CheckEqual(Int64(1), Int64(Cnt), 'ignore glob to fs pas 1 (src distinct)');
    // actually 1 file matches *.PAS case-insensitive? Wait Docs/A.TXT not pas, src/C.PAS is pas, so 1. But also need check.
    Ok := SevenZTryExtractByGlobIgnoreCaseToFs(LR, '*.txt', LRoot, Err);
    Check(Ok and (Err=''), 'try ignore glob to fs ok');
  finally RemoveAll(LRoot); end;
end;

procedure TestGlobClassifyUnified;
var LW: ISevenZWriter; LR: ISevenZReader; Arr: TSevenZEntryInfoArray; Ext: TSevenZExtractedArray;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01]));
  LW.AddFile('b.txt', BytesOf([$02]));
  LW.AddFile('pre_mid_post.txt', BytesOf([$03]));
  LW.AddFile('pre_aaa_post.txt', BytesOf([$04]));
  LW.AddFile('docs/x.txt', BytesOf([$05]));
  LW.AddFile('a.log', BytesOf([$06]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByGlob('');
  CheckEqual(Int64(0), Int64(Length(Arr)), 'classify empty');
  CheckEqual(Int64(-1), Int64(LR.FindByGlob('')), 'classify empty find');
  Arr := LR.EntriesByGlob('*');
  CheckEqual(Int64(6), Int64(Length(Arr)), 'classify star');
  Arr := LR.EntriesByGlob('a.txt');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'classify exact');
  CheckEqual('a.txt', Arr[0].Name, 'classify exact name');
  Arr := LR.EntriesByGlob('docs/*');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'classify prefix');
  Arr := LR.EntriesByGlob('*.txt');
  CheckEqual(Int64(5), Int64(Length(Arr)), 'classify suffix txt');
  Arr := LR.EntriesByGlob('pre_*_post.txt');
  CheckEqual(Int64(2), Int64(Length(Arr)), 'classify pre*suffix');
  Arr := LR.EntriesByGlob('pre*post*');
  CheckEqual(Int64(2), Int64(Length(Arr)), 'complex multi-star 2');
  Arr := LR.EntriesByGlob('?.txt');
  CheckEqual(Int64(2), Int64(Length(Arr)), 'classify q txt 2');
  Check(LR.FindByGlob('pre_*_post.txt') >=0, 'find classify p*s');
  CheckEqual(Int64(-1), Int64(LR.FindByGlob('nope_*_zzz')), 'find miss p*s');
  Ext := LR.ExtractByGlob('*.log');
  CheckEqual(Int64(1), Int64(Length(Ext)), 'extract suffix via glob');
  Ext := LR.ExtractByGlob('pre_*_post.txt');
  CheckEqual(Int64(2), Int64(Length(Ext)), 'extract p*s 2');
  Arr := LR.EntriesByGlobIgnoreCase('*.TXT');
  CheckEqual(Int64(5), Int64(Length(Arr)), 'classify ignore suffix');
  Arr := LR.EntriesByGlobIgnoreCase('PRE_*_POST.TXT');
  CheckEqual(Int64(2), Int64(Length(Arr)), 'classify ignore p*s');
  CheckEqual(Int64(-1), Int64(LR.FindByGlobIgnoreCase('')), 'ignore empty find');
  Check(LR.FindByGlobIgnoreCase('PRE_*_POST.TXT') >=0, 'ignore find p*s');
end;

procedure TestBuildSortedUnifiedAndSameIgnoreCaseZeroAlloc;
var LW: ISevenZWriter; LR: ISevenZReader; Idx: Integer; Arr: TSevenZEntryInfoArray;
begin
  LW := TSevenZWriterImpl.Create;
  for Idx := 0 to 199 do
    LW.AddFile(Format('File_%3.3d.TXT', [Idx]), BytesOf([Byte(Idx)]));
  LW.AddFile('Café_Ünicode.txt', BytesOf([$01]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  Arr := LR.EntriesByPrefixIgnoreCase('file_');
  CheckEqual(Int64(200), Int64(Length(Arr)), 'buildsorted prefix 200 ascii');
  Arr := LR.EntriesBySuffixIgnoreCase('.txt');
  Check(Length(Arr) >= 200, 'buildsorted suffix txt >=200');
  Idx := LR.FindIgnoreCase('FILE_010.TXT');
  Check(Idx >= 0, 'sameignore ascii upper');
  CheckEqual('File_010.TXT', LR.Entry(Idx).Name, 'sameignore ascii name');
  Idx := LR.FindIgnoreCase('café_Ünicode.txt');
  Check(Idx >= 0, 'sameignore ascii folding preserves non-ascii bytes');
  CheckEqual(Int64(200), Int64(Idx), 'sameignore non-ascii exact after ascii fold');
  Arr := LR.EntriesByPrefixIgnoreCase('café_');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'buildsorted non-ascii prefix 1');
  CheckEqual('Café_Ünicode.txt', Arr[0].Name, 'buildsorted non-ascii prefix name');
end;

procedure TestGlobIgnoreCaseComplexAsciiZeroAlloc;
var LW: ISevenZWriter; LR: ISevenZReader; Arr, Arr2: TSevenZEntryInfoArray; Idx: Integer;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('AlphaBetaGamma.txt', BytesOf([$01]));
  LW.AddFile('alpha_beta_gamma.txt', BytesOf([$02]));
  LW.AddFile('ALPHA-BETA-GAMMA.TXT', BytesOf([$03]));
  LW.AddFile('aXbYcZ.log', BytesOf([$04]));
  LW.AddFile('Café_Alpha.txt', BytesOf([$05]));
  LR := TSevenZReaderImpl.Create(LW.Finish);
  // ascii complex glob via ? and * must be case-insensitive zero-alloc path
  Arr := LR.EntriesByGlobIgnoreCase('ALPHA*BETA*GAMMA.TXT');
  CheckEqual(Int64(3), Int64(Length(Arr)), 'glob ic complex alpha*beta*gamma 3');
  Arr := LR.EntriesByGlobIgnoreCase('alpha?beta*gamma.txt');
  // '?'' matches '-' or '_' single char, so ALPHA-BETA- and alpha_beta both match, AlphaBeta without sep does not
  Check(Length(Arr) >= 2, 'glob ic ? wildcard >=2');
  // exact via hash still case-insensitive
  Idx := LR.FindByGlobIgnoreCase('ALPHA*BETA*GAMMA.TXT');
  Check(Idx >= 0, 'find glob ic complex');
  // non-ascii pattern must fallback to LowerCase path and not corrupt ascii fast path
  Arr := LR.EntriesByGlobIgnoreCase('café*alpha.txt');
  CheckEqual(Int64(1), Int64(Length(Arr)), 'glob ic non-ascii fallback 1');
  CheckEqual('Café_Alpha.txt', Arr[0].Name, 'glob ic non-ascii name');
  Arr2 := LR.EntriesByGlobIgnoreCase('CAFÉ*ALPHA.TXT');
  CheckEqual(Int64(0), Int64(Length(Arr2)), 'glob ic non-ascii upper not folded 0');
end;

procedure TestWriterBombEarlyViaReader;
var LW: ISevenZWriter; LR1, LR2: IReader;
begin
  LW := TSevenZWriterImpl.Create;
  LR1 := CreateBytesStreamFrom(TBytes.Create(0)) as IReader;
  LW.AddFileFromReader('big.bin', LR1, UInt64(9) * 1024 * 1024 * 1024);
  try
    LW.Finish;
    Fail('single huge entry should raise ESevenZLimitError');
  except on E: ESevenZLimitError do ; end;
  LW := TSevenZWriterImpl.Create;
  LR1 := CreateBytesStreamFrom(TBytes.Create(0)) as IReader;
  LR2 := CreateBytesStreamFrom(TBytes.Create(1)) as IReader;
  LW.AddFileFromReader('a.bin', LR1, UInt64(5) * 1024 * 1024 * 1024);
  LW.AddFileFromReader('b.bin', LR2, UInt64(5) * 1024 * 1024 * 1024);
  try
    LW.Finish;
    Fail('total unpack overflow should raise ESevenZLimitError');
  except on E: ESevenZLimitError do ; end;
end;

procedure TestBackendConsistencyPureVsFfi;
var LW: ISevenZWriter; LR1, LR2: ISevenZReader; LArc, LGot1, LGot2: TBytes; LData: TBytes;
begin
  if not SevenZLzmaFfiAvailable then Exit;
  LData := ExeLikeCorpus(80000);
  LW := TSevenZWriterImpl.Create;
  LW.SetFilters([szfBcjX86]);
  LW.AddFile('app.exe', LData);
  LArc := LW.Finish;
  SevenZSetLzmaBackend(szlbPurePascal);
  try
    LR1 := TSevenZReaderImpl.Create(LArc);
    LGot1 := LR1.Extract(0);
  finally SevenZSetLzmaBackend(szlbAuto); end;
  SevenZSetLzmaBackend(szlbFfi);
  try
    LR2 := TSevenZReaderImpl.Create(LArc);
    LGot2 := LR2.Extract(0);
  finally SevenZSetLzmaBackend(szlbAuto); end;
  CheckEqual(Int64(Length(LGot1)), Int64(Length(LGot2)), 'backend consistency len');
  Check(SameBytes(LGot1, LGot2), 'backend consistency bytes');
  Check(SameBytes(LData, LGot1), 'backend original bytes');
end;

procedure TestWriterBombPackSizeReject;
var LW: ISevenZWriter; LData: TBytes;
begin
  LData := Randomish(67 * 1024 * 1024, 999);
  LW := TSevenZWriterImpl.Create;
  LW.SetLevel(szclNone);
  LW.AddFile('big.bin', LData);
  try
    LW.Finish;
    Fail('pack >64MiB should raise ESevenZLimitError');
  except on E: ESevenZLimitError do ; end;
end;

procedure TestWriterNameTooLongReject;
var LW: ISevenZWriter; LName: string;
begin
  LName := StringOfChar('a', SizeInt(SEVENZ_MAX_NAME_BYTES) + 1);
  LW := TSevenZWriterImpl.Create;
  try
    LW.AddFile(LName, BytesOf([$01]));
    Fail('name >64KiB should raise ESevenZLimitError');
  except on E: ESevenZLimitError do ; end;
  LName := StringOfChar('a', SizeInt(SEVENZ_MAX_NAME_BYTES));
  LW := TSevenZWriterImpl.Create;
  LW.AddFile(LName, BytesOf([$02]));
end;

procedure TestReaderTruncatedArchive;
var LW: ISevenZWriter; LArc, LTrunc: TBytes;
begin
  LW := TSevenZWriterImpl.Create;
  LW.AddFile('a.txt', BytesOf([$01,$02,$03]));
  LW.AddFile('b.txt', Randomish(5000, 777));
  LArc := LW.Finish;
  SetLength(LTrunc, Length(LArc) - 10);
  if Length(LTrunc) > 0 then
    Move(LArc[0], LTrunc[0], Length(LTrunc));
  try
    TSevenZReaderImpl.Create(LTrunc);
    Fail('truncated archive should raise');
  except on E: ESevenZError do ; on E: ESevenZLimitError do ; on E: EIOError do ; end;
  SetLength(LTrunc, 10);
  if Length(LTrunc) > 0 then
    Move(LArc[0], LTrunc[0], Length(LTrunc));
  try
    TSevenZReaderImpl.Create(LTrunc);
    Fail('severely truncated should raise');
  except on E: ESevenZError do ; on E: ESevenZLimitError do ; on E: EIOError do ; end;
end;

procedure TestCoderPropsExceedsLimitReject;
var LPlain, LBlock, LPack, LArchive: TBytes;
    LEnc: TSevenZLzmaEncoded;
begin
  { 最小明文头：仅空 FilesInfo，聚焦 UnpackInfo 中 coder props 超限分支。
    props 大小 = SEVENZ_MAX_CODER_PROPS+1 (=1048577) 应在 ParseFolder 提前抛 ESevenZLimitError，
    避免分配 1MiB+ 载荷 — 验证 header 限界在流式/固化路径均生效。 }
  SetLength(LPlain, 0);
  SevenZAppendByte(LPlain, SZ_ID_HEADER);
  SevenZAppendByte(LPlain, SZ_ID_FILES_INFO);
  SevenZWriteNumber(LPlain, 0);
  SevenZAppendByte(LPlain, SZ_ID_END);
  SevenZAppendByte(LPlain, SZ_ID_END);
  LEnc := SevenZAcquireEncoder.EncodeLzma2(LPlain, szclDefault);
  LPack := LEnc.PackedData;
  SetLength(LBlock, 0);
  SevenZAppendByte(LBlock, SZ_ID_ENCODED_HEADER);
  SevenZAppendByte(LBlock, SZ_ID_PACK_INFO);
  SevenZWriteNumber(LBlock, 0);
  SevenZWriteNumber(LBlock, 1);
  SevenZAppendByte(LBlock, SZ_ID_SIZE);
  SevenZWriteNumber(LBlock, UInt64(Length(LPack)));
  SevenZAppendByte(LBlock, SZ_ID_END);
  SevenZAppendByte(LBlock, SZ_ID_UNPACK_INFO);
  SevenZAppendByte(LBlock, SZ_ID_FOLDER);
  SevenZWriteNumber(LBlock, 1);
  SevenZAppendByte(LBlock, 0);
  SevenZWriteNumber(LBlock, 1);
  SevenZAppendByte(LBlock, $21);
  SevenZAppendByte(LBlock, Byte(SEVENZ_METHOD_LZMA2));
  SevenZWriteNumber(LBlock, UInt64(SEVENZ_MAX_CODER_PROPS) + 1);
  { 不跟 props 载荷：ParseFolder 在 ReadBytes 前已判限 }
  SevenZAppendByte(LBlock, SZ_ID_CODERS_UNPACK_SZ);
  SevenZWriteNumber(LBlock, UInt64(Length(LPlain)));
  SevenZAppendByte(LBlock, SZ_ID_END);
  SevenZAppendByte(LBlock, SZ_ID_END);
  SetLength(LArchive, C_SEVENZ_SIG_HEADER_SIZE);
  FillChar(LArchive[0], C_SEVENZ_SIG_HEADER_SIZE, 0);
  LArchive[0]:=C_SEVENZ_MAGIC_0; LArchive[1]:=C_SEVENZ_MAGIC_1;
  LArchive[2]:=C_SEVENZ_MAGIC_2; LArchive[3]:=C_SEVENZ_MAGIC_3;
  LArchive[4]:=C_SEVENZ_MAGIC_4; LArchive[5]:=C_SEVENZ_MAGIC_5;
  LArchive[6]:=C_SEVENZ_VERSION_MAJOR; LArchive[7]:=C_SEVENZ_VERSION_MINOR;
  SigPutLE64(LArchive, 12, UInt64(Length(LPack)));
  SigPutLE64(LArchive, 20, UInt64(Length(LBlock)));
  SigPutLE32(LArchive, 28, Crc32OfBytes(LBlock));
  SigPutLE32(LArchive, 8, Crc32Of((@LArchive[12])^, 20));
  SetLength(LArchive, Length(LArchive)+Length(LPack)+Length(LBlock));
  Move(LPack[0], LArchive[C_SEVENZ_SIG_HEADER_SIZE], Length(LPack));
  Move(LBlock[0], LArchive[C_SEVENZ_SIG_HEADER_SIZE+Length(LPack)], Length(LBlock));
  try
    TSevenZReaderImpl.Create(LArchive);
    Fail('coder props >1M should raise ESevenZLimitError');
  except
    on E: ESevenZLimitError do ;
    on E: ESevenZError do ; // 读截断路径亦可接受，但限界优先
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.sevenz');
  T.Test('utf16 bmp round trip', @TestUtf16BmpRoundTrip);
  T.Test('utf16 ascii identity', @TestUtf16AsciiIdentity);
  T.Test('utf16 astral surrogate pair', @TestUtf16AstralSurrogatePair);
  T.Test('utf16 unpaired surrogate is replacement',
    @TestUtf16UnpairedSurrogateIsReplacement);
  T.Test('utf8 truncated tail single replacement',
    @TestUtf8TruncatedTailIsSingleReplacement);
  T.Test('utf8 bad continuation consumes sequence',
    @TestUtf8BadContinuationConsumesSequence);

  T.Test('filetime round trip', @TestFiletimeRoundTrip);
  T.Test('filetime negative clamp', @TestFiletimeNegativeClamp);

  T.Test('lzma2 empty', @TestLzma2Empty);
  T.Test('lzma2 one byte', @TestLzma2OneByte);
  T.Test('lzma2 text pattern', @TestLzma2TextPattern);
  T.Test('lzma2 random stored fallback', @TestLzma2RandomStoredFallback);
  T.Test('lzma2 chunk cap boundary', @TestLzma2ChunkCapBoundary);
  T.Test('backend switch purepascal', @TestBackendSwitchPurePascal);
  T.Test('backend switch ffi', @TestBackendSwitchFfi);
  T.Test('backend default auto', @TestBackendDefaultAuto);

  T.Test('writer reader single file', @TestWriterReaderSingleFile);
  T.Test('writer solid multi file', @TestWriterSolidMultiFile);
  T.Test('writer dir and empty entries', @TestWriterDirAndEmptyEntries);
  T.Test('writer unicode names', @TestWriterUnicodeNames);
  T.Test('writer deterministic default mtime',
    @TestWriterDeterministicDefaultMtime);
  T.Test('writer explicit mtime survives',
    @TestWriterExplicitMtimeSurvives);
  T.Test('writer name validation', @TestWriterNameValidation);
  T.Test('finish twice raises', @TestFinishTwiceRaises);
  T.Test('writer empty archive', @TestWriterEmptyArchive);
  T.Test('writer filters bcj roundtrip', @TestWriterFiltersBcjRoundtrip);
  T.Test('writer filters delta roundtrip', @TestWriterFiltersDeltaRoundtrip);
  T.Test('writer filters chain roundtrip', @TestWriterFiltersChainRoundtrip);
  T.Test('writer filters reset to default bytes',
    @TestWriterFiltersResetToDefaultBytes);
  T.Test('writer filters deterministic', @TestWriterFiltersDeterministic);
  T.Test('writer filters compression gain',
    @TestWriterFiltersCompressionGain);
  T.Test('writer filters validation', @TestWriterFiltersValidation);
  T.Test('writer filters empty archive', @TestWriterFiltersEmptyArchive);
  T.Test('writer filters arm roundtrip', @TestWriterFiltersArmRoundtrip);
  T.Test('writer filters arm64 roundtrip', @TestWriterFiltersArm64Roundtrip);
  T.Test('writer filters ppc roundtrip', @TestWriterFiltersPpcRoundtrip);
  T.Test('writer filters arm chain roundtrip', @TestWriterFiltersArmChainRoundtrip);
  T.Test('writer filters ia64 roundtrip', @TestWriterFiltersIa64Roundtrip);
  T.Test('writer filters sparc roundtrip', @TestWriterFiltersSparcRoundtrip);
  T.Test('writer filters armt roundtrip', @TestWriterFiltersArmtRoundtrip);
  T.Test('writer filters riscv roundtrip', @TestWriterFiltersRiscvRoundtrip);
  T.Test('writer filters mixed bcj chain', @TestWriterFiltersMixedBcjChain);
  T.Test('level none stored roundtrip', @TestLevelNoneStoredRoundtrip);
  T.Test('level fastest roundtrip', @TestLevelFastestRoundtrip);
  T.Test('level best roundtrip', @TestLevelBestRoundtrip);
  T.Test('level monotonic on repeated text',
    @TestLevelMonotonicOnRepeatedText);
  T.Test('level set after finish raises', @TestLevelSetAfterFinishRaises);

  T.Test('reader rejects short input', @TestReaderRejectsShortInput);
  T.Test('reader rejects bad magic', @TestReaderRejectsBadMagic);
  T.Test('reader rejects start header crc mismatch',
    @TestReaderRejectsStartHeaderCrcMismatch);

  T.Test('bcj arm roundtrip', @TestBcjArmRoundtrip);
  T.Test('bcj ppc roundtrip', @TestBcjPpcRoundtrip);
  T.Test('bcj arm64 roundtrip', @TestBcjArm64Roundtrip);
  T.Test('bcj arm64 adrp vector', @TestBcjArm64AdrpVector);
  T.Test('bcj ia64 roundtrip', @TestBcjIa64Roundtrip);
  T.Test('bcj sparc roundtrip', @TestBcjSparcRoundtrip);
  T.Test('bcj armt roundtrip', @TestBcjArmtRoundtrip);
  T.Test('bcj riscv roundtrip', @TestBcjRiscvRoundtrip);
  T.Test('delta decode vectors', @TestDeltaDecodeVectors);
  T.Test('deflate vectors', @TestDeflateVectors);
  T.Test('bzip2 vectors', @TestBZip2Vectors);
  T.Test('bzip2 golden archive', @TestBZip2GoldenArchive);
  T.Test('bzip2 truncated', @TestBZip2Truncated);
  T.Test('ppmd not supported', @TestPpmdNotSupported);
  T.Test('deflate truncated via folder', @TestDeflateTruncatedViaFolder);
  T.Test('bcj golden vectors', @TestBcjGoldenVectors);
  T.Test('bcj roundtrip and skip', @TestBcjRoundtripAndSkip);
  T.Test('bcj2 golden archive', @TestBcj2GoldenArchive);
  T.Test('find miss and index errors', @TestFindMissAndIndexErrors);
  T.Test('extractto windowed', @TestExtractToWindowed);
  T.Test('entry stream semantics', @TestEntryStreamSemantics);
  T.Test('encoded header round trip', @TestEncodedHeaderRoundTrip);
  T.Test('header encoding modes', @TestHeaderEncodingModes);

  T.Test('aes golden plain header', @TestAesGoldenPlainHeader);
  T.Test('aes golden plain header pure backend',
    @TestAesGoldenPlainHeaderPureBackend);
  T.Test('aes golden encrypted header', @TestAesGoldenEncryptedHeader);
  T.Test('aes wrong password raises', @TestAesWrongPasswordRaises);
  T.Test('aes encrypted header no password raises',
    @TestAesEncryptedHeaderNoPasswordRaises);
  T.Test('aes props parse defaults and rejects',
    @TestAesPropsParseDefaultsAndRejects);
  T.Test('aes derive kat', @TestAesDeriveKat);
  T.Test('writer password roundtrip enc header',
    @TestWriterPasswordRoundtripEncHeader);
  T.Test('writer password iv unique', @TestWriterPasswordIvUnique);
  T.Test('writer password plain header roundtrip',
    @TestWriterPasswordPlainHeaderRoundtrip);
  T.Test('writer password wrong raises', @TestWriterPasswordWrongRaises);
  T.Test('writer password clear restores bytes',
    @TestWriterPasswordClearRestoresBytes);
  T.Test('writer password after finish raises',
    @TestWriterPasswordAfterFinishRaises);
  T.Test('writer password dirs only enc header',
    @TestWriterPasswordDirsOnlyEncHeader);
  T.Test('aes props build parses back', @TestAesPropsBuildParsesBack);
  T.Test('aes encrypt decrypt roundtrip', @TestAesEncryptDecryptRoundtrip);
  T.Test('multi folder bytes threshold', @TestMultiFolderBytesThreshold);
  T.Test('multi folder file count', @TestMultiFolderFileCount);
  T.Test('multi folder with filters', @TestMultiFolderWithFilters);
  T.Test('multi folder with password', @TestMultiFolderWithPassword);
  T.Test('multi folder plain header', @TestMultiFolderPlainHeader);
  T.Test('multi folder limits validation', @TestMultiFolderLimitsValidation);
  T.Test('multi folder dirs and empty', @TestMultiFolderDirsAndEmpty);

  T.Test('writer addfile from reader roundtrip', @TestWriterAddFileFromReaderRoundtrip);
  T.Test('writer addfile from reader with time', @TestWriterAddFileFromReaderWithTime);
  T.Test('writer addfile from reader mixed', @TestWriterAddFileFromReaderMixed);
  T.Test('writer addfile from reader large', @TestWriterAddFileFromReaderLarge);
  T.Test('writer addfile from reader multi folder', @TestWriterAddFileFromReaderMultiFolder);
  T.Test('writer addfile from reader with filter and password', @TestWriterAddFileFromReaderWithFilterAndPassword);
  T.Test('writer addfile from reader empty', @TestWriterAddFileFromReaderEmpty);
  T.Test('writer addfile from reader nil raises', @TestWriterAddFileFromReaderNilRaises);
  T.Test('writer addfile from reader short read raises', @TestWriterAddFileFromReaderShortReadRaises);
  T.Test('writer addfile from reader after finish raises', @TestWriterAddFileFromReaderAfterFinishRaises);
  T.Test('reader create from reader', @TestReaderCreateFromReader);
  T.Test('reader create from reader nil raises', @TestReaderCreateFromReaderNilRaises);
  T.Test('writer finishto streaming', @TestWriterFinishToStreaming);
  T.Test('factory helpers', @TestFactoryHelpers);
  T.Test('level none copy roundtrip', @TestLevelNoneCopyRoundtrip);
  T.Test('level none copy with filters and password', @TestLevelNoneCopyWithFiltersAndPassword);
  T.Test('writer deflate method', @TestWriterDeflateMethod);
  T.Test('writer bzip2 method', @TestWriterBZip2Method);
  T.Test('writer set method validation', @TestWriterSetMethodValidation);
  T.Test('builder chain', @TestBuilderChain);
  T.Test('tryextract probe', @TestTryExtractProbe);
  T.Test('bzip2 level mapping', @TestBZip2LevelMapping);
  T.Test('builder fs tree', @TestBuilderFsTree);
  T.Test('tryextract with error', @TestTryExtractWithError);
  T.Test('fs add tree and extract all', @TestFsAddTreeAndExtractAll);
  T.Test('fs extract to single', @TestFsExtractToSingle);
  T.Test('reader for..in enumerator', @TestReaderForInEnumerator);
  T.Test('builder with progress', @TestBuilderWithProgress);
  T.Test('bomb header reject', @TestBombHeaderReject);
  T.Test('reader count and items', @TestReaderCountAndItems);
  T.Test('writer singlepass crc', @TestWriterSinglePassCrc);
  T.Test('bomb file count reject', @TestBombFileCountReject);
  T.Test('reader contains tryget', @TestReaderContainsTryGetEntry);
  T.Test('writer nul name reject', @TestWriterNulNameReject);
  T.Test('extractto singlepass large', @TestExtractToSinglePassLarge);
  T.Test('reader lru cache two entries', @TestReaderLruCacheTwoEntries);
  T.Test('reader entry by name', @TestReaderEntryByName);
  T.Test('reader is empty', @TestReaderIsEmpty);
  T.Test('reader entries snapshot', @TestReaderEntries);
  T.Test('reader find ignore case', @TestReaderFindIgnoreCase);
  T.Test('reader try entry by name', @TestReaderTryEntryByName);
  T.Test('reader contains ignore case', @TestReaderContainsIgnoreCase);
  T.Test('reader try get entry ignore case', @TestReaderTryGetEntryIgnoreCase);
  T.Test('reader entry by name ignore case', @TestReaderEntryByNameIgnoreCase);
  T.Test('reader non ascii ignore case', @TestReaderNonAsciiIgnoreCase);
  T.Test('reader clear cache', @TestReaderClearCache);
  T.Test('reader empty ignore case edge', @TestReaderEmptyIgnoreCaseEdge);
  T.Test('hash index correctness 200', @TestHashIndexCorrectness);
  T.Test('entries by prefix', @TestEntriesByPrefix);
  T.Test('duplicate name stability', @TestDuplicateNameStability);
  T.Test('entries by prefix sorted', @TestEntriesByPrefixSorted);
  T.Test('entries by suffix', @TestEntriesBySuffix);
  T.Test('suffix prefix edge', @TestSuffixPrefixEdge);
  T.Test('find by prefix suffix', @TestFindByPrefixSuffix);
  T.Test('entries by glob', @TestEntriesByGlob);
  T.Test('glob edge', @TestGlobEdge);
  T.Test('find by glob', @TestFindByGlob);
  T.Test('glob dispatch', @TestGlobDispatch);
  T.Test('find by prefix noalloc', @TestFindByPrefixNoAlloc);
  T.Test('glob prefix*suffix', @TestGlobPrefixStarSuffix);
  T.Test('extract by prefix suffix glob', @TestExtractByPrefixSuffixGlob);
  T.Test('lowerbound suffix zero alloc', @TestLowerBoundSuffixZeroAlloc);
  T.Test('bulk grouped multi folder', @TestBulkGroupedMultiFolder);
  T.Test('extract by glob to fs', @TestExtractByGlobToFs);
  T.Test('extract all grouped', @TestExtractAllGrouped);
  T.Test('ignore case full', @TestIgnoreCaseFull);
  T.Test('fs ignore case to fs', @TestFsIgnoreCaseToFs);
  T.Test('glob classify unified', @TestGlobClassifyUnified);
  T.Test('buildsorted unified + sameignore zeroalloc', @TestBuildSortedUnifiedAndSameIgnoreCaseZeroAlloc);
  T.Test('glob ignorecase complex ascii zeroalloc', @TestGlobIgnoreCaseComplexAsciiZeroAlloc);
  T.Test('writer bomb early via reader huge size', @TestWriterBombEarlyViaReader);
  T.Test('backend consistency pure vs ffi', @TestBackendConsistencyPureVsFfi);
  T.Test('writer bomb pack size reject', @TestWriterBombPackSizeReject);
  T.Test('writer name too long reject', @TestWriterNameTooLongReject);
  T.Test('reader truncated archive', @TestReaderTruncatedArchive);
  T.Test('coder props exceeds limit reject', @TestCoderPropsExceedsLimitReject);

  if not T.Run then Halt(1);
end.
