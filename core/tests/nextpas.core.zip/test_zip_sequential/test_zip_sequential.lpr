program test_zip_sequential;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.io.memory,
  nextpas.core.io.intf,
  nextpas.core.zip,
  nextpas.core.zip.base,
  nextpas.core.checksum.crc32, nextpas.core.text.conv;

var
  T: TTestSuite;

function BytesOfStr(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(Pointer(S)^, Result[0], Length(S));
end;

function SameBytes(const A, B: TBytes): Boolean;
var
  LI: Integer;
begin
  Result := False;
  if Length(A) <> Length(B) then Exit;
  for LI := 0 to High(A) do
    if A[LI] <> B[LI] then Exit;
  Result := True;
end;

function PatternBytes(ALen, ASeed: Integer): TBytes;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, ALen);
  for LI := 0 to ALen - 1 do
    Result[LI] := Byte((LI * 3 + ASeed) mod 251);
end;

const
  C_PY_MAKE =
    'import zipfile, sys'#10 +
    'path = sys.argv[1]'#10 +
    'z = zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED)'#10 +
    'z.writestr("a.txt", b"hello world")'#10 +
    'z.writestr("dir/b.bin", bytes(range(256)) * 4)'#10 +
    'z.writestr("empty.bin", b"")'#10 +
    'z.writestr("docs/", b"")'#10 +
    'z.close()'#10;

  C_PY_STORE =
    'import zipfile, sys'#10 +
    'path = sys.argv[1]'#10 +
    'z = zipfile.ZipFile(path, "w", zipfile.ZIP_STORED)'#10 +
    'z.writestr("a.txt", b"hello world")'#10 +
    'z.writestr("dir/b.bin", bytes(range(256)) * 4)'#10 +
    'z.close()'#10;

function RunPy(const AScript, AZipPath: string): Boolean;
var
  LPy: string;
  LOut: TProcessOutput;
begin
  Result := False;
  if not TryLookPath('python3', LPy) then
  begin
    Check(False, 'python3 unavailable');
    Exit;
  end;
  LOut := Command(LPy).Arg('-c').Arg(AScript).Arg(AZipPath).Output;
  Check(ProcessSucceeded(LOut), 'python fixture: ' + Trim(LOut.StdErr));
  Result := True;
end;

procedure TestEmptyArchive;
var
  R: ISequentialZipReader;
  Info: TZipEntryInfo;
  Src: IReader;
begin
  Src := CreateBytesStreamFrom(NewZipWriter.Finish) as IReader;
  R := NewZipSequentialReader(Src);
  Check(not R.Next(Info), 'empty has no entries');
  Check(R.AtEnd, 'at end');
  Check(not R.Next(Info), 'second next still false');
end;

procedure TestStoreSequentialParity;
var
  W: IZipWriter;
  Archive: TBytes;
  RMem: IZipReader;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Buf: array[0..511] of Byte;
  N: SizeUInt;
  Got: TBytes;
  LI: Integer;
begin
  W := NewZipWriter;
  W.AddEntry('a.txt', BytesOfStr('hello'));
  W.AddEntry('b.bin', PatternBytes(1024, 7));
  W.AddEntryWithTime('c.txt', BytesOfStr('timed'), 1787574896);
  Archive := W.Finish;
  RMem := NewZipReader(Archive);
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  LI := 0;
  while RSeq.Next(Info) do
  begin
    Check(Info.Name = RMem.Entry(LI).Name, 'name parity ' + Info.Name);
    CheckEqual(Int64(Info.CompressedSize), Int64(RMem.Entry(LI).CompressedSize), 'csize parity');
    CheckEqual(Int64(Info.UncompressedSize), Int64(RMem.Entry(LI).UncompressedSize), 'usize parity');
    Stream := RSeq.Open;
    SetLength(Got, 0);
    repeat
      N := Stream.Read(Buf[0], SizeOf(Buf));
      if N > 0 then
      begin
        SetLength(Got, Length(Got) + Integer(N));
        Move(Buf[0], Got[Length(Got)-Integer(N)], N);
      end;
    until N = 0;
    Stream.Close;
    Check(SameBytes(Got, RMem.ExtractToBytes(LI)), 'content parity ' + Info.Name);
    Inc(LI);
  end;
  CheckEqual(Int64(LI), Int64(RMem.EntryCount), 'count parity');
end;

procedure TestDeflateSequentialParity;
var
  W: IZipWriter;
  Archive: TBytes;
  RMem: IZipReader;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Buf: array[0..1023] of Byte;
  N: SizeUInt;
  Got: TBytes;
  LI: Integer;
  Data: TBytes;
begin
  SetLength(Data, 50000);
  for LI := 0 to High(Data) do Data[LI] := Byte((LI*11) mod 251);
  W := NewZipWriter;
  W.AddEntryDeflate('big.bin', Data);
  W.AddEntryDeflateWithTime('small.txt', BytesOfStr('hello deflate'), 1787574896);
  Archive := W.Finish;
  RMem := NewZipReader(Archive);
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  LI := 0;
  while RSeq.Next(Info) do
  begin
    Stream := RSeq.Open;
    SetLength(Got,0);
    repeat N:= Stream.Read(Buf[0], SizeOf(Buf)); if N>0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N=0;
    Stream.Close;
    Check(SameBytes(Got, RMem.ExtractToBytes(LI)), 'deflate parity ' + Info.Name);
    Inc(LI);
  end;
  CheckEqual(Int64(LI), Int64(2), 'deflate count');
end;

procedure TestDescriptorStoreParity;
var
  W: IZipWriter;
  Opt: TZipAddOptions;
  S: ICompressWriter;
  Archive: TBytes;
  RMem: IZipReader;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Buf: array[0..1023] of Byte;
  N: SizeUInt;
  Got: TBytes;
  Data: TBytes;
begin
  Data := BytesOfStr('descriptor store payload');
  W := NewZipWriter;
  Opt := DefaultZipAddOptions;
  Opt.DataDescriptor := True;
  S := W.AddEntryStream('a.txt', Opt);
  S.Write(Data[0], Length(Data));
  S.Close;
  Archive := W.Finish;
  RMem := NewZipReader(Archive);
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  Check(RSeq.Next(Info), 'has entry');
  Check(Info.Name = 'a.txt', 'name');
  CheckEqual(Int64(Info.CompressedSize), Int64(Length(Data)), 'csize after next');
  Stream := RSeq.Open;
  SetLength(Got,0);
  repeat N:= Stream.Read(Buf[0], SizeOf(Buf)); if N>0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N=0;
  Stream.Close;
  Check(SameBytes(Got, Data), 'store desc content');
  Check(SameBytes(Got, RMem.ExtractToBytesByName('a.txt')), 'store desc vs mem');
  Check(not RSeq.Next(Info), 'no more');
end;

procedure TestDescriptorDeflateParity;
var
  W: IZipWriter;
  Opt: TZipAddOptions;
  S: ICompressWriter;
  Archive: TBytes;
  RMem: IZipReader;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Buf: array[0..4095] of Byte;
  N: SizeUInt;
  Got: TBytes;
  Data: TBytes;
  LI: Integer;
begin
  SetLength(Data, 50000);
  for LI := 0 to High(Data) do Data[LI] := Byte((LI*13) mod 251);
  W := NewZipWriter;
  Opt := DefaultZipAddOptions;
  Opt.Method := zmDeflate;
  Opt.DataDescriptor := True;
  S := W.AddEntryStream('b.bin', Opt);
  S.Write(Data[0], 20000);
  S.Write(Data[20000], Length(Data)-20000);
  S.Close;
  Archive := W.Finish;
  RMem := NewZipReader(Archive);
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  Check(RSeq.Next(Info), 'has entry');
  CheckEqual(Int64(Info.UncompressedSize), Int64(Length(Data)), 'usize');
  Stream := RSeq.Open;
  SetLength(Got,0);
  repeat N:= Stream.Read(Buf[0], SizeOf(Buf)); if N>0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N=0;
  Stream.Close;
  Check(SameBytes(Got, Data), 'deflate desc content');
  Check(SameBytes(Got, RMem.ExtractToBytesByName('b.bin')), 'vs mem');
end;

procedure TestMixedWithDescriptor;
var
  W: IZipWriter;
  Opt: TZipAddOptions;
  S: ICompressWriter;
  Archive: TBytes;
  RMem: IZipReader;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Buf: array[0..4095] of Byte;
  N: SizeUInt;
  Got: TBytes;
  Count: Integer;
begin
  W := NewZipWriter;
  W.AddEntry('first.txt', BytesOfStr('first'));
  Opt := DefaultZipAddOptions;
  Opt.Method := zmDeflate;
  Opt.DataDescriptor := True;
  S := W.AddEntryStream('mid.bin', Opt);
  S.Write(PatternBytes(50000, 7)[0], 50000);
  S.Close;
  W.AddEntry('last.txt', BytesOfStr('last'));
  Opt.Method := zmStore;
  Opt.DataDescriptor := True;
  S := W.AddEntryStream('tail.txt', Opt);
  S.Write(BytesOfStr('tail store')[0], Length(BytesOfStr('tail store')));
  S.Close;
  Archive := W.Finish;
  RMem := NewZipReader(Archive);
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  Count := 0;
  while RSeq.Next(Info) do
  begin
    Stream := RSeq.Open;
    SetLength(Got,0);
    repeat N:= Stream.Read(Buf[0], SizeOf(Buf)); if N>0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N=0;
    Stream.Close;
    Check(SameBytes(Got, RMem.ExtractToBytesByName(Info.Name)), 'mixed ' + Info.Name);
    Inc(Count);
  end;
  CheckEqual(Int64(Count), Int64(4), 'mixed count');
end;

procedure TestPythonInteropSequential;
var
  LDir, LZipPath: string;
  LData: TBytes;
  RMem: IZipReader;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Buf: array[0..1023] of Byte;
  N: SizeUInt;
  Got: TBytes;
  Count: Integer;
begin
  LDir := TempDir(GetTempDir, 'seqpy');
  try
    LZipPath := LDir + '/py.zip';
    RunPy(C_PY_MAKE, LZipPath);
    LData := ReadFile(LZipPath);
    RMem := NewZipReader(LData);
    RSeq := NewZipSequentialReader(CreateBytesStreamFrom(LData) as IReader);
    Count := 0;
    while RSeq.Next(Info) do
    begin
      Stream := RSeq.Open;
      SetLength(Got,0);
      repeat N:= Stream.Read(Buf[0], SizeOf(Buf)); if N>0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N=0;
      Stream.Close;
      Check(SameBytes(Got, RMem.ExtractToBytesByName(Info.Name)), 'py ' + Info.Name);
      Inc(Count);
    end;
    CheckEqual(Int64(Count), Int64(RMem.EntryCount), 'py count');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestPythonStoreInterop;
var
  LDir, LZipPath: string;
  LData: TBytes;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Buf: array[0..1023] of Byte;
  N: SizeUInt;
  Got: TBytes;
begin
  LDir := TempDir(GetTempDir, 'seqpy2');
  try
    LZipPath := LDir + '/py_store.zip';
    RunPy(C_PY_STORE, LZipPath);
    LData := ReadFile(LZipPath);
    RSeq := NewZipSequentialReader(CreateBytesStreamFrom(LData) as IReader);
    Check(RSeq.Next(Info), 'has entry');
    Stream := RSeq.Open;
    SetLength(Got,0);
    repeat N:= Stream.Read(Buf[0], SizeOf(Buf)); if N>0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N=0;
    Stream.Close;
    Check(SameBytes(Got, BytesOfStr('hello world')), 'store hello');
  finally
    RemoveAll(LDir);
  end;
end;

procedure TestSkip;
var
  W: IZipWriter;
  Opt: TZipAddOptions;
  S: ICompressWriter;
  Archive: TBytes;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Buf: array[0..1023] of Byte;
  N: SizeUInt;
  Got: TBytes;
begin
  W := NewZipWriter;
  W.AddEntry('a.txt', BytesOfStr('first'));
  Opt := DefaultZipAddOptions;
  Opt.DataDescriptor := True;
  S := W.AddEntryStream('b.txt', Opt);
  S.Write(BytesOfStr('to skip')[0], Length(BytesOfStr('to skip')));
  S.Close;
  W.AddEntry('c.txt', BytesOfStr('last'));
  Archive := W.Finish;
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  Check(RSeq.Next(Info), 'first');
  Check(Info.Name='a.txt', 'first name');
  RSeq.Skip;
  Check(RSeq.Next(Info), 'second');
  Check(Info.Name='b.txt', 'second name');
  RSeq.Skip;
  Check(RSeq.Next(Info), 'third');
  Check(Info.Name='c.txt', 'third name');
  Stream := RSeq.Open;
  SetLength(Got,0);
  repeat N:= Stream.Read(Buf[0], SizeOf(Buf)); if N>0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N=0;
  Stream.Close;
  Check(SameBytes(Got, BytesOfStr('last')), 'skip->last');
end;

procedure TestCopyTo;
var
  W: IZipWriter;
  Archive: TBytes;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  Dst: IStream;
  Got: TBytes;
  LRead: SizeUInt;
begin
  W := NewZipWriter;
  W.AddEntryDeflate('x.bin', PatternBytes(10000, 5));
  Archive := W.Finish;
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  Check(RSeq.Next(Info), 'has');
  Dst := CreateBytesStream(1024);
  CheckEqual(Int64(10000), Int64(RSeq.CopyTo(Dst as IWriter)), 'copy count');
  SetLength(Got, Integer(Dst.Size));
  Dst.Position := 0;
  LRead := Dst.Read(Got[0], Length(Got));
  CheckEqual(Int64(LRead), Int64(10000), 'read back');
  Check(SameBytes(Got, PatternBytes(10000,5)), 'copy content');
end;

function TrySkipAll(const AData: TBytes): Boolean;
var
  R: ISequentialZipReader;
  Info: TZipEntryInfo;
begin
  R := NewZipSequentialReader(CreateBytesStreamFrom(AData) as IReader);
  try
    while R.Next(Info) do
      R.Skip;
    Result := False;
  except
    on E: EParseError do Result := True;
  end;
end;

procedure TestTruncated;
var
  W: IZipWriter;
  Archive, Cut: TBytes;
  LGot: Boolean;
  LCutLen: SizeInt;
begin
  W := NewZipWriter;
  W.AddEntry('a.txt', BytesOfStr('hello'));
  Archive := W.Finish;
  LCutLen := 30 + Length('a.txt') + 2;
  if LCutLen > Length(Archive) then
    LCutLen := Length(Archive) - 5;
  SetLength(Cut, LCutLen);
  Move(Archive[0], Cut[0], LCutLen);
  LGot := TrySkipAll(Cut);
  Check(LGot, 'truncated raises parse');
end;

function TryOpenUnsafe(const AData: TBytes): Boolean;
var
  R: ISequentialZipReader;
  Info: TZipEntryInfo;
begin
  R := NewZipSequentialReader(CreateBytesStreamFrom(AData) as IReader);
  if not R.Next(Info) then Exit(False);
  try
    R.Open;
    Result := False;
  except
    on E: EParseError do Result := True;
    on E: ENotSupportedError do Result := True;
  end;
end;

procedure TestUnsafeName;
var
  LDir, LZipPath: string;
  LData: TBytes;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  LGot: Boolean;
const
  C_PY_UNSAFE = 'import zipfile, sys'#10 + 'z = zipfile.ZipFile(sys.argv[1], "w")'#10 + 'z.writestr("../evil.txt", b"x")'#10 + 'z.close()'#10;
begin
  LDir := TempDir(GetTempDir, 'sequnsafe');
  try
    LZipPath := LDir + '/evil.zip';
    RunPy(C_PY_UNSAFE, LZipPath);
    LData := ReadFile(LZipPath);
    RSeq := NewZipSequentialReader(CreateBytesStreamFrom(LData) as IReader);
    Check(RSeq.Next(Info), 'evil entry listed');
    LGot := TryOpenUnsafe(LData);
    Check(LGot, 'unsafe refused at open');
  finally
    RemoveAll(LDir);
  end;
end;

function TryMaxOutput(const AData: TBytes): Boolean;
var
  R: ISequentialZipReader;
  Opts: TZipReadOptions;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Buf: array[0..1023] of Byte;
begin
  Opts := DefaultZipReadOptions;
  Opts.MaxOutputSize := 100;
  R := NewZipSequentialReaderWithOptions(CreateBytesStreamFrom(AData) as IReader, Opts);
  if not R.Next(Info) then Exit(False);
  try
    Stream := R.Open;
    while Stream.Read(Buf[0], SizeOf(Buf)) > 0 do ;
    Stream.Close;
    Result := False;
  except
    on E: EIOError do Result := True;
  end;
end;

procedure TestMaxOutput;
var
  W: IZipWriter;
  Archive: TBytes;
  LGot: Boolean;
begin
  W := NewZipWriter;
  W.AddEntryDeflate('big.bin', PatternBytes(10000, 9));
  Archive := W.Finish;
  LGot := TryMaxOutput(Archive);
  Check(LGot, 'max output enforced');
end;

function TryOpenBeforeNext(const AData: TBytes): Boolean;
var
  R: ISequentialZipReader;
begin
  R := NewZipSequentialReader(CreateBytesStreamFrom(AData) as IReader);
  try
    R.Open;
    Result := False;
  except
    on E: EInvalidOperationError do Result := True;
  end;
end;

function TryDoubleOpen(const AData: TBytes): Boolean;
var
  R: ISequentialZipReader;
  Info: TZipEntryInfo;
  S1: IDecompressReader;
begin
  R := NewZipSequentialReader(CreateBytesStreamFrom(AData) as IReader);
  if not R.Next(Info) then Exit(False);
  S1 := R.Open;
  try
    R.Open;
    Result := False;
  except
    on E: EInvalidOperationError do Result := True;
  end;
  S1.Close;
end;

procedure TestOpenGuards;
var
  W: IZipWriter;
  Archive: TBytes;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  S1: IDecompressReader;
begin
  W := NewZipWriter;
  W.AddEntry('a.txt', BytesOfStr('x'));
  W.AddEntry('b.txt', BytesOfStr('y'));
  Archive := W.Finish;
  Check(TryOpenBeforeNext(Archive), 'open before next raises');
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  Check(RSeq.Next(Info), 'first');
  Check(TryDoubleOpen(Archive), 'double open raises');
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  Check(RSeq.Next(Info), 'first');
  S1 := RSeq.Open;
  S1.Close;
  Check(RSeq.Next(Info), 'second');
  S1 := RSeq.Open;
  S1.Close;
  Check(not RSeq.Next(Info), 'end');
end;

procedure TestAesNonDescriptor;
var
  W: IZipWriter;
  Opt: TZipAddOptions;
  Archive: TBytes;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  ROpts: TZipReadOptions;
  Stream: IDecompressReader;
  Buf: array[0..1023] of Byte;
  N: SizeUInt;
  Got: TBytes;
  Data: TBytes;
begin
  Data:= BytesOfStr('secret payload for seq');
  W:= NewZipWriter;
  Opt:= DefaultZipAddOptions;
  Opt.Password:= BytesOfStr('pw123');
  Opt.AesStrength:= 3;
  W.AddEntryWithOptions('enc.txt', Data, Opt);
  Archive:= W.Finish;
  ROpts:= DefaultZipReadOptions;
  ROpts.Password:= BytesOfStr('pw123');
  RSeq:= NewZipSequentialReaderWithOptions(CreateBytesStreamFrom(Archive) as IReader, ROpts);
  Check(RSeq.Next(Info), 'has enc');
  Check(Info.IsEncrypted, 'is encrypted');
  Stream:= RSeq.Open;
  SetLength(Got,0);
  repeat N:= Stream.Read(Buf[0], SizeOf(Buf)); if N>0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N=0;
  Stream.Close;
  Check(SameBytes(Got, Data), 'aes seq content');
end;

function TryAesDescriptorNoPassword(const AData: TBytes): Boolean;
var
  R: ISequentialZipReader;
  Info: TZipEntryInfo;
begin
  R := NewZipSequentialReader(CreateBytesStreamFrom(AData) as IReader);
  try
    if R.Next(Info) then
      R.Open;
    Result := False;
  except
    on E: EInvalidOperationError do Result := True;
  end;
end;

procedure TestAesDescriptorNotSupported;
var
  W: IZipWriter;
  Opt: TZipAddOptions;
  S: ICompressWriter;
  Archive: TBytes;
  LGot: Boolean;
begin
  W:= NewZipWriter;
  Opt:= DefaultZipAddOptions;
  Opt.DataDescriptor:= True;
  Opt.Password:= BytesOfStr('pw');
  Opt.AesStrength:= 3;
  S:= W.AddEntryStream('encd.txt', Opt);
  S.Write(BytesOfStr('secret')[0], 6);
  S.Close;
  Archive:= W.Finish;
  LGot := TryAesDescriptorNoPassword(Archive);
  Check(LGot, 'aes descriptor without password raises invalid operation');
end;

procedure TestAesDescriptorParity;
var
  W: IZipWriter;
  Opt: TZipAddOptions;
  S: ICompressWriter;
  Archive: TBytes;
  RMem: IZipReader;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  ROpts: TZipReadOptions;
  Stream: IDecompressReader;
  Buf: array[0..4095] of Byte;
  N: SizeUInt;
  Got, Data: TBytes;
  LI: Integer;
begin
  for LI := 0 to 1 do
  begin
    if LI = 0 then Data := BytesOfStr('descriptor store aes')
    else begin SetLength(Data, 50000); for N:=0 to High(Data) do Data[N]:= Byte((N*13) mod 251); end;
    W:= NewZipWriter;
    Opt:= DefaultZipAddOptions;
    Opt.DataDescriptor:= True;
    Opt.Password:= BytesOfStr('pw123');
    Opt.AesStrength:= 3;
    if LI=1 then Opt.Method:= zmDeflate else Opt.Method:= zmStore;
    S:= W.AddEntryStream('encd'+IntToStr(LI)+'.bin', Opt);
    if Length(Data)>0 then S.Write(Data[0], Length(Data));
    S.Close;
    Archive:= W.Finish;
    ROpts:= DefaultZipReadOptions; ROpts.Password:= BytesOfStr('pw123');
    RMem:= NewZipReaderWithOptions(Archive, ROpts);
    RSeq:= NewZipSequentialReaderWithOptions(CreateBytesStreamFrom(Archive) as IReader, ROpts);
    Check(RSeq.Next(Info), 'aes desc next '+IntToStr(LI));
    Check(Info.IsEncrypted, 'is encrypted');
    Stream:= RSeq.Open;
    SetLength(Got,0);
    repeat N:= Stream.Read(Buf[0], SizeOf(Buf)); if N>0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N=0;
    Stream.Close;
    Check(SameBytes(Got, Data), 'aes desc content '+IntToStr(LI));
    Check(SameBytes(Got, RMem.ExtractToBytesByName('encd'+IntToStr(LI)+'.bin')), 'vs mem aes desc '+IntToStr(LI));
  end;
end;

procedure TestEmptyDescriptorStore;
var
  W: IZipWriter;
  Opt: TZipAddOptions;
  S: ICompressWriter;
  Archive: TBytes;
  RSeq: ISequentialZipReader;
  RMem: IZipReader;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Got: TBytes;
  N: SizeUInt;
  Buf: array[0..255] of Byte;
begin
  W := NewZipWriter;
  Opt := DefaultZipAddOptions;
  Opt.DataDescriptor := True;
  S := W.AddEntryStream('empty.txt', Opt);
  S.Close;
  Archive := W.Finish;
  RMem := NewZipReader(Archive);
  CheckEqual(Int64(0), Int64(Length(RMem.ExtractToBytesByName('empty.txt'))), 'mem empty');
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  Check(RSeq.Next(Info), 'empty has entry');
  Check(Info.Name = 'empty.txt', 'name');
  CheckEqual(Int64(0), Int64(Info.CompressedSize), 'csize 0');
  CheckEqual(Int64(0), Int64(Info.UncompressedSize), 'usize 0');
  Stream := RSeq.Open;
  SetLength(Got, 0);
  repeat N := Stream.Read(Buf[0], SizeOf(Buf)); if N > 0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N = 0;
  Stream.Close;
  CheckEqual(Int64(0), Int64(Length(Got)), 'seq empty');
  Check(not RSeq.Next(Info), 'no more');
end;

procedure TestSequentialWithForceZip64;
var
  Opts: TZipWriteOptions;
  W: IZipWriter;
  Archive: TBytes;
  RMem: IZipReader;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Buf: array[0..1023] of Byte;
  N: SizeUInt;
  Got: TBytes;
  Data: TBytes;
begin
  Data := PatternBytes(4096, 11);
  Opts.ForceZip64 := True;
  W := NewZipWriterWithOptions(Opts);
  W.AddEntry('z64.bin', Data);
  Archive := W.Finish;
  RMem := NewZipReader(Archive);
  Check(SameBytes(RMem.ExtractToBytesByName('z64.bin'), Data), 'mem forced zip64');
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  Check(RSeq.Next(Info), 'has entry');
  Check(Info.Name = 'z64.bin', 'name');
  CheckEqual(Int64(Length(Data)), Int64(Info.UncompressedSize), 'usize');
  Stream := RSeq.Open;
  SetLength(Got, 0);
  repeat N := Stream.Read(Buf[0], SizeOf(Buf)); if N > 0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N = 0;
  Stream.Close;
  Check(SameBytes(Got, Data), 'seq forced zip64');
end;

procedure TestSkipBufferedDescriptor;
var
  W: IZipWriter;
  Opt: TZipAddOptions;
  S: ICompressWriter;
  Archive: TBytes;
  RSeq: ISequentialZipReader;
  Info: TZipEntryInfo;
  Stream: IDecompressReader;
  Buf: array[0..255] of Byte;
  N: SizeUInt;
  Got: TBytes;
begin
  W := NewZipWriter;
  W.AddEntry('a.txt', BytesOfStr('keep'));
  Opt := DefaultZipAddOptions;
  Opt.DataDescriptor := True;
  S := W.AddEntryStream('b.txt', Opt);
  S.Write(BytesOfStr('skip me')[0], Length(BytesOfStr('skip me')));
  S.Close;
  W.AddEntry('c.txt', BytesOfStr('after'));
  Archive := W.Finish;
  RSeq := NewZipSequentialReader(CreateBytesStreamFrom(Archive) as IReader);
  Check(RSeq.Next(Info), 'first');
  RSeq.Skip;
  Check(RSeq.Next(Info), 'second is buffered descriptor');
  RSeq.Skip;
  Check(RSeq.Next(Info), 'third');
  Stream := RSeq.Open;
  SetLength(Got, 0);
  repeat N := Stream.Read(Buf[0], SizeOf(Buf)); if N > 0 then begin SetLength(Got, Length(Got)+Integer(N)); Move(Buf[0], Got[Length(Got)-Integer(N)], N); end; until N = 0;
  Stream.Close;
  Check(SameBytes(Got, BytesOfStr('after')), 'skip->after');
end;

function TryTotalLimitSequential(const AData: TBytes; ALimit: UInt64): Boolean;
var
  R: ISequentialZipReader;
  Opts: TZipReadOptions;
  Info: TZipEntryInfo;
begin
  Opts := DefaultZipReadOptions;
  Opts.MaxTotalOutputSize := ALimit;
  R := NewZipSequentialReaderWithOptions(CreateBytesStreamFrom(AData) as IReader, Opts);
  try
    while R.Next(Info) do
      R.Skip;
    Result := False;
  except
    on E: EIOError do Result := True;
  end;
end;

procedure TestTotalLimitSequential;
var
  W: IZipWriter;
  Archive: TBytes;
  LI: Integer;
begin
  W := NewZipWriter;
  for LI := 0 to 4 do
    W.AddEntry('f' + IntToStr(LI) + '.bin', PatternBytes(100, LI));
  Archive := W.Finish;
  Check(TryTotalLimitSequential(Archive, 250), 'total limit enforced sequential');
  Check(not TryTotalLimitSequential(Archive, 500), 'total exact boundary sequential');
  Check(not TryTotalLimitSequential(Archive, 0), 'total unlimited sequential');
end;

function TryDescriptorLimit(const AData: TBytes; ALimit: SizeUInt): Boolean;
var
  R: ISequentialZipReader;
  Opts: TZipReadOptions;
  Info: TZipEntryInfo;
begin
  Opts := DefaultZipReadOptions;
  Opts.MaxDescriptorBuffer := ALimit;
  R := NewZipSequentialReaderWithOptions(CreateBytesStreamFrom(AData) as IReader, Opts);
  try
    R.Next(Info);
    Result := False;
  except
    on E: EParseError do Result := True;
    else Result := False;
  end;
end;

procedure TestDescriptorBufferLimit;
var
  W: IZipWriter;
  Opt: TZipAddOptions;
  S: ICompressWriter;
  Archive, Trunc: TBytes;
begin
  W := NewZipWriter;
  Opt := DefaultZipAddOptions;
  Opt.DataDescriptor := True;
  S := W.AddEntryStream('a.bin', Opt);
  S.Write(PatternBytes(1024, 1)[0], 1024);
  S.Close;
  Archive := W.Finish;
  Check(not TryDescriptorLimit(Archive, 10), 'valid descriptor passes even tiny limit (found before limit)');
  Check(not TryDescriptorLimit(Archive, 0), 'default limit passes (0->512MiB)');
  Check(not TryDescriptorLimit(Archive, 512*1024*1024), 'explicit default passes');
  SetLength(Trunc, 30+5+1024);
  Move(Archive[0], Trunc[0], Length(Trunc));
  Check(TryDescriptorLimit(Trunc, 2048), 'truncated descriptor not found');
  SetLength(Trunc, 30+5+512);
  Move(Archive[0], Trunc[0], Length(Trunc));
  Check(TryDescriptorLimit(Trunc, 512), 'tiny limit truncated still not found');
end;

begin
  T := TTestSuite.Create('nextpas.core.zip.sequential');
  T.Test('Empty archive', @TestEmptyArchive);
  T.Test('Store parity', @TestStoreSequentialParity);
  T.Test('Deflate parity', @TestDeflateSequentialParity);
  T.Test('Descriptor store parity', @TestDescriptorStoreParity);
  T.Test('Descriptor deflate parity', @TestDescriptorDeflateParity);
  T.Test('Mixed with descriptor', @TestMixedWithDescriptor);
  T.Test('Python interop', @TestPythonInteropSequential);
  T.Test('Python store interop', @TestPythonStoreInterop);
  T.Test('Skip', @TestSkip);
  T.Test('CopyTo', @TestCopyTo);
  T.Test('Truncated', @TestTruncated);
  T.Test('Unsafe name', @TestUnsafeName);
  T.Test('Max output', @TestMaxOutput);
  T.Test('Open guards', @TestOpenGuards);
  T.Test('AES non-descriptor', @TestAesNonDescriptor);
  T.Test('AES descriptor not supported', @TestAesDescriptorNotSupported);
  T.Test('AES descriptor parity', @TestAesDescriptorParity);
  T.Test('Empty descriptor store', @TestEmptyDescriptorStore);
  T.Test('Force Zip64 sequential', @TestSequentialWithForceZip64);
  T.Test('Skip buffered descriptor', @TestSkipBufferedDescriptor);
  T.Test('Total limit sequential', @TestTotalLimitSequential);
  T.Test('Descriptor buffer limit', @TestDescriptorBufferLimit);
  if not T.Run then Halt(1);
end.
