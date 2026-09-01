program test_tar_reader;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.tar.base,
  nextpas.core.tar.reader,
  nextpas.core.tar.writer,
  nextpas.core.io.memory,
  nextpas.core.fs;

function BytesOf(const S: string): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then Move(S[1], Result[0], Length(S));
end;

function SameBytes(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do if A[I] <> B[I] then Exit(False);
  Result := True;
end;

function Patterned(ASize: Integer; ASeed: Cardinal): TBytes;
var
  I: Integer;
  S: Cardinal;
begin
  SetLength(Result, ASize);
  S := ASeed;
  for I := 0 to ASize - 1 do
  begin
    S := S * 1664525 + 1013904223;
    Result[I] := Byte((S shr 16) and $FF);
  end;
end;

procedure TestRoundTripRegular;
var
  S: IStream;
  W: TTarWriter;
  R: TTarReader;
  H: TTarHeader;
  Data, Out: TBytes;
begin
  Data := BytesOf('hello tar');
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  W.AddFile('a.txt', Data, $1A4, 1700000000);
  W.AddDir('dir');
  W.AddFile('dir/b.bin', Patterned(600, 1), $1A4, 1700000001);
  W.Finish; W.Free;
  SetLength(Data, S.Size);
  S.Seek(0, soBeginning);
  S.Read(Data[0], Length(Data));
  R := TTarReader.Create(Data);
  try
    CheckTrue(R.Next(H), 'first');
    CheckEqual('a.txt', H.Name, 'name');
    CheckEqual(9, H.Size, 'size');
    Out := R.EntryData;
    CheckTrue(SameBytes(Out, BytesOf('hello tar')), 'payload');
    CheckTrue(R.Next(H), 'second');
    CheckEqual('dir/', H.Name, 'dir name');
    CheckEqual(Ord(tekDirectory), Ord(H.Kind), 'dir kind');
    CheckTrue(R.Next(H), 'third');
    CheckEqual('dir/b.bin', H.Name, 'nested');
    CheckTrue(R.Next(H) = False, 'end');
  finally R.Free; end;
end;

procedure TestGNUAndPaxLongNames;
var
  S: IStream;
  W: TTarWriter;
  R: TTarReader;
  H: TTarHeader;
  LongName: string;
  Payload: TBytes;
  I: Integer;
begin
  LongName := '';
  for I := 1 to 40 do LongName := LongName + 'l';
  LongName := LongName + '/' + LongName + '/' + LongName + 'n';
  Payload := BytesOf('payload');
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  { writer uses ustar prefix split for long names }
  W.AddFile(LongName, Payload);
  W.Finish; W.Free;
  SetLength(Payload, S.Size);
  S.Seek(0, soBeginning);
  S.Read(Payload[0], Length(Payload));
  R := TTarReader.Create(Payload);
  try
    CheckTrue(R.Next(H), 'found');
    CheckEqual(LongName, H.Name, 'roundtrip long name');
    CheckTrue(R.Next(H) = False, 'end');
  finally R.Free; end;
end;

procedure TestBase256AndChecksum;
var
  B: TBytes;
  R: TTarReader;
  H: TTarHeader;
  Hello: TBytes;
  Sum, I: Integer;
  procedure PutTextAt(AOfs: Integer; const V: string);
  begin Move(V[1], B[AOfs], Length(V)); end;
begin
  SetLength(B, 2048);
  FillChar(B[0], 2048, 0);
  PutTextAt(0, 'b256.txt');
  PutTextAt(100, '0000644'#0);
  B[124] := $80; B[135] := 5;
  PutTextAt(136, '00000000000'#0);
  FillChar(B[148], 8, Ord(' '));
  B[156] := Ord('0');
  PutTextAt(257, 'ustar');
  PutTextAt(263, '00');
  Sum := 0;
  for I := 0 to 511 do Sum := Sum + B[I];
  for I := 0 to 5 do B[148 + I] := Byte(Ord('0') + ((Sum shr ((5 - I) * 3)) and 7));
  B[154] := 0; B[155] := Ord(' ');
  Hello := BytesOf('hello');
  Move(Hello[0], B[512], 5);
  R := TTarReader.Create(B);
  try
    CheckTrue(R.Next(H), 'entry');
    CheckEqual(5, H.Size, 'base256 size');
    CheckTrue(SameBytes(R.EntryData, Hello), 'payload');
  finally R.Free; end;
  B[3] := B[3] xor $20;
  try
    R := TTarReader.Create(B);
    try R.Next(H); CheckTrue(False, 'should raise'); finally R.Free; end;
  except on E: EIOError do CheckTrue(True, 'corrupt checksum raises EIOError'); end;
end;

procedure TestZeroCopySliceAndStream;
var
  S: IStream;
  W: TTarWriter;
  R: TTarReader;
  H: TTarHeader;
  D: TBytes;
  P: PByte;
  C: SizeUInt;
  RS: IReader;
  Buf: array[0..31] of Byte;
  N: SizeUInt;
begin
  D := Patterned(100, 42);
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  W.AddFile('x.bin', D);
  W.Finish; W.Free;
  SetLength(D, S.Size);
  S.Seek(0, soBeginning);
  S.Read(D[0], Length(D));
  R := TTarReader.Create(D);
  try
    CheckTrue(R.Next(H), 'next');
    CheckTrue(R.EntryDataSlice(P, C), 'slice');
    CheckEqual(100, Int64(C), 'slice size');
    CheckTrue(P <> nil, 'slice ptr');
    RS := R.OpenEntryStream;
    N := RS.Read(Buf[0], 10);
    CheckEqual(10, Int64(N), 'stream read');
  finally R.Free; end;
end;

var
  Suite: TTestSuite;
  Runner: TSuiteRunner;
  Results: specialize TArray<TTestRunResult>;
begin
  Suite := TTestSuite.Create('tar.reader');
  Suite.Test('roundtrip regular', @TestRoundTripRegular);
  Suite.Test('long names prefix split', @TestGNUAndPaxLongNames);
  Suite.Test('base256 and checksum', @TestBase256AndChecksum);
  Suite.Test('zero-copy slice and stream', @TestZeroCopySliceAndStream);
  Runner := TSuiteRunner.Create('main');
  Runner.Add(Suite);
  Runner.RunAllWithResult(Results);
  if (Length(Results) = 0) or (not Results[0].AllPassed) then Halt(1);
end.
