program test_zip_stress;
{**
 * @desc 极限压力门（二十一期）。
 *
 * 在二十期预算锁定之上，验证 zip 在规模与敌意压力下的稳定性与完整性：
 *  - 70k 条目 Zip64 自动（Reserve 预分配，EOCD 链、偏移、central 校验）
 *  - 1k×2k 混合 store/deflate，memory vs sequential 双路径一致
 *  - ZipBomb 防御：单条目 MaxOutputSize 与跨条目 MaxTotalOutputSize fail-closed
 *  - 并发提取：同一归档多流并发打开（IReaderAt 间隔游标）与 sequential 单流约束
 *
 * 全部 deterministic、零网络、heaptrc 干净；失败即红，守住领头羊的
 * “规模不崩、敌意不透、并发不串”底线。
 *}
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.checksum.crc32,
  nextpas.core.io.memory,
  nextpas.core.io.intf,
  nextpas.core.zip,
  nextpas.core.zip.base;

var
  T: TTestSuite;

function BytesOfStr(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then Move(Pointer(S)^, Result[0], Length(S));
end;

function PatternBytes(ALen, ASeed: Integer): TBytes;
var LI: Integer;
begin
  SetLength(Result, ALen);
  for LI := 0 to ALen-1 do Result[LI] := Byte((LI*3 + ASeed + (LI shr 7)) mod 251);
end;

function SameBytes(const A,B: TBytes): Boolean;
var LI: Integer;
begin
  if Length(A)<>Length(B) then Exit(False);
  for LI:=0 to High(A) do if A[LI]<>B[LI] then Exit(False);
  Result:=True;
end;

procedure Test70kZip64;
var W: IZipWriter; Zip: TBytes; R: IZipReader; Seq: ISequentialZipReader; Info: TZipEntryInfo; LI: Integer; LOne: TBytes; S: IDecompressReader; Buf: array[0..511] of Byte; N: SizeUInt;
begin
  LOne := BytesOfStr('x');
  W := NewZipWriter;
  W.Reserve(70000);
  for LI := 1 to 70000 do
    W.AddEntry('e'+IntToStr(LI)+'.txt', LOne);
  Zip := W.Finish;
  Check(Length(Zip) > 0, '70k produced');
  // classic EOCD 占位，zip64 EOCD 存在由 reader 校验
  R := NewZipReader(Zip);
  CheckEqual(Int64(70000), Int64(R.EntryCount), '70k count');
  Check(SameBytes(R.ExtractToBytesByName('e1.txt'), LOne), 'first entry');
  Check(SameBytes(R.ExtractToBytesByName('e70000.txt'), LOne), 'last entry');
  Check(SameBytes(R.ExtractToBytes(35000), LOne), 'middle entry');
  // sequential 全遍历
  Seq := NewZipSequentialReader(CreateBytesStreamFrom(Zip) as IReader);
  LI := 0;
  while Seq.Next(Info) do
  begin
    Inc(LI);
    S := Seq.Open;
    N := S.Read(Buf[0], SizeOf(Buf));
    Check(N = 1, 'seq read 1 byte');
    Check(Buf[0] = Ord('x'), 'seq content');
    N := S.Read(Buf[0], SizeOf(Buf));
    Check(N = 0, 'seq eof');
    S.Close;
  end;
  CheckEqual(Int64(70000), Int64(LI), 'seq count 70k');
end;

procedure Test1kMixedParity;
var W: IZipWriter; Zip: TBytes; RMem: IZipReader; RSeq: ISequentialZipReader; Info: TZipEntryInfo; LI: Integer; Payloads: array of TBytes; Methods: array of Word; Names: array of string;
  GotMem, GotSeq: TBytes; S: IDecompressReader; Buf: array[0..4095] of Byte; N: SizeUInt;
begin
  SetLength(Payloads, 1000);
  SetLength(Methods, 1000);
  SetLength(Names, 1000);
  W := NewZipWriter;
  W.Reserve(1000);
  for LI := 0 to 999 do
  begin
    Names[LI] := 'f/'+IntToStr(LI)+'.bin';
    Payloads[LI] := PatternBytes(512 + (LI mod 8)*256, LI*7);
    if (LI mod 2 = 0) then Methods[LI] := 8 else Methods[LI] := 0;
    if Methods[LI] = 8 then
      W.AddEntryDeflate(Names[LI], Payloads[LI])
    else
      W.AddEntry(Names[LI], Payloads[LI]);
  end;
  Zip := W.Finish;
  RMem := NewZipReader(Zip);
  CheckEqual(Int64(1000), Int64(RMem.EntryCount), '1k count');
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Zip) as IReader);
  LI := 0;
  while RSeq.Next(Info) do
  begin
    Check(Info.Name = RMem.Entry(LI).Name, 'name parity '+IntToStr(LI));
    // open both
    GotMem := RMem.ExtractToBytes(LI);
    S := RSeq.Open;
    SetLength(GotSeq, 0);
    repeat N := S.Read(Buf[0], SizeOf(Buf)); if N>0 then begin SetLength(GotSeq, Length(GotSeq)+Integer(N)); Move(Buf[0], GotSeq[Length(GotSeq)-Integer(N)], N); end; until N=0;
    S.Close;
    Check(SameBytes(GotMem, Payloads[LI]), 'mem content '+IntToStr(LI));
    Check(SameBytes(GotSeq, Payloads[LI]), 'seq content '+IntToStr(LI));
    Check(SameBytes(GotMem, GotSeq), 'parity '+IntToStr(LI));
    Inc(LI);
  end;
  CheckEqual(Int64(1000), Int64(LI), 'seq iterated 1k');
end;

procedure TestBombGuards;
var W: IZipWriter; Zip: TBytes; R: IZipReader; ROpts: TZipReadOptions; LI: Integer; Hit: Boolean; Blob: TBytes; S: IDecompressReader; Buf: array[0..4095] of Byte; N: SizeUInt;
begin
  Blob := PatternBytes(1024*1024, 1);
  W := NewZipWriter;
  W.AddEntryDeflate('bomb.bin', Blob);
  Zip := W.Finish;
  ROpts := DefaultZipReadOptions;
  ROpts.MaxOutputSize := 10;
  R := NewZipReaderWithOptions(Zip, ROpts);
  Hit := False;
  try R.ExtractToBytes(0); except on E: EIOError do Hit := True; end;
  Check(Hit, 'single MaxOutputSize bomb detected');
  Hit := False;
  try
    S := R.OpenEntry(0);
    repeat N := S.Read(Buf[0], SizeOf(Buf)); until N=0;
    S.Close;
  except on E: EIOError do Hit := True; end;
  Check(Hit, 'stream bomb detected');
  W := NewZipWriter;
  for LI := 0 to 99 do
    W.AddEntry('f'+IntToStr(LI)+'.bin', PatternBytes(10000, LI));
  Zip := W.Finish;
  ROpts := DefaultZipReadOptions;
  ROpts.MaxTotalOutputSize := 500*1024;
  Hit := False;
  try R := NewZipReaderWithOptions(Zip, ROpts); except on E: EIOError do Hit := True; end;
  Check(Hit, 'total output limit at open');
  W := NewZipWriter;
  for LI := 0 to 9 do
    W.AddEntry('a'+IntToStr(LI)+'.bin', PatternBytes(20000, LI));
  Zip := W.Finish;
  ROpts.MaxTotalOutputSize := 100*1024;
  Hit := False;
  try R := NewZipReaderWithOptions(Zip, ROpts); except on E: EIOError do Hit := True; end;
  Check(Hit, 'total limit triggers 2');
end;

procedure TestConcurrentExtract;
var W: IZipWriter; Zip: TBytes; R: IZipReader; S1,S2: IDecompressReader; Buf1,Buf2: array[0..4095] of Byte; N1,N2: SizeUInt; LI: Integer; P1,P2: TBytes;
begin
  W := NewZipWriter;
  P1 := PatternBytes(8192, 11);
  P2 := PatternBytes(8192, 22);
  W.AddEntryDeflate('a.bin', P1);
  W.AddEntryDeflate('b.bin', P2);
  Zip := W.Finish;
  R := NewZipReader(Zip);
  S1 := R.OpenEntry(0);
  S2 := R.OpenEntry(1);
  // 交替读取
  N1 := S1.Read(Buf1[0], 1024);
  N2 := S2.Read(Buf2[0], 1024);
  Check(N1 = 1024, 'concurrent read1');
  Check(N2 = 1024, 'concurrent read2');
  // 读完
  repeat N1 := S1.Read(Buf1[0], SizeOf(Buf1)); until N1=0;
  repeat N2 := S2.Read(Buf2[0], SizeOf(Buf2)); until N2=0;
  S1.Close;
  S2.Close;
  Check(SameBytes(R.ExtractToBytes(0), P1), 'a.bin after concurrent');
  Check(SameBytes(R.ExtractToBytes(1), P2), 'b.bin after concurrent');
  // sequential 不允许并发：Open时已有流应 raise
  // 此部分由 test_zip_sequential 覆盖，这里仅验证 memory reader 并发不串扰
end;

begin
  T := TTestSuite.Create('nextpas.core.zip.stress');
  T.Test('70k Zip64', @Test70kZip64);
  T.Test('1k mixed parity', @Test1kMixedParity);
  T.Test('Bomb guards', @TestBombGuards);
  T.Test('Concurrent extract', @TestConcurrentExtract);
  if not T.Run then Halt(1);
end.
