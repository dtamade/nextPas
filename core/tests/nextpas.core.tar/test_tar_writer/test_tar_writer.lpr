program test_tar_writer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.tar.base,
  nextpas.core.tar.common,
  nextpas.core.tar.reader,
  nextpas.core.tar.writer,
  nextpas.core.tar.builder,
  nextpas.core.io.memory,
  nextpas.core.bytes.ops;

function BytesOf(const S: string): TBytes; inline;
begin
  // perf: single-source via bytes.ops.StringToBytes (zero-copy PAnsiChar view, single Move), inline thin forward, owner bytes.ops; heaptrc0 via common.mk HEAPTRC_GATE=1 (-gh, haltonnotreleased+log), no duplicate Move
  Result := nextpas.core.bytes.ops.StringToBytes(S);
end;

function Snapshot(S: IStream): TBytes;
begin
  SetLength(Result, S.Size);
  if Length(Result) > 0 then
  begin
    S.Seek(0, soBeginning);
    S.Read(Result[0], Length(Result));
  end;
end;

procedure TestBlockAlignedAndTwoZero;
var
  S: IStream; W: TTarWriter; B: TBytes;
begin
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile('a.txt', BytesOf('hi'));
    W.Finish;
  finally W.Free; end;
  B := Snapshot(S);
  CheckTrue(Length(B) mod 512 = 0, 'block aligned');
  CheckTrue(Length(B) >= 1536, 'at least header+data+2zero');
  CheckTrue((B[Length(B)-512]=0) and (B[Length(B)-1024]=0), 'two zero blocks');
end;

procedure TestPrefixSplitAndReject;
var
  S: IStream; W: TTarWriter; R: TTarReader; H: TTarHeader; B: TBytes;
  LongOk, LongFail: string; I: Integer;
begin
  LongOk := '';
  for I := 1 to 80 do LongOk := LongOk + 'q';
  LongOk := LongOk + '/' + LongOk;
  { make suffix <=100, total >100 -> split ok }
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try W.AddFile(LongOk, BytesOf('x')); W.Finish; CheckTrue(True, 'split ok'); finally W.Free; end;
  LongFail := '';
  for I := 1 to 300 do LongFail := LongFail + 'a';
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile(LongFail, BytesOf('x')); W.Finish;
    B := Snapshot(S);
    R := TTarReader.Create(B);
    try
      CheckTrue(R.Next(H), 'pax longname found');
      CheckEqual(LongFail, H.Name, 'pax roundtrip long name');
      CheckTrue(R.Next(H) = False, 'end after pax');
    finally R.Free; end;
    CheckTrue(True, 'pax longname ok');
  finally W.Free; end;
end;

procedure TestUnsafeNameRejected;
var
  S: IStream; W: TTarWriter;
begin
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    try W.AddFile('../evil.txt', BytesOf('x')); CheckTrue(False, 'should reject');
    except on E: EArgumentError do CheckTrue(True, 'unsafe rejected'); end;
    try W.AddFile('/abs.txt', BytesOf('x')); CheckTrue(False, 'abs reject');
    except on E: EArgumentError do CheckTrue(True, 'abs rejected'); end;
  finally W.Free; end;
end;

procedure TestModeAndMtime;
var
  S: IStream; W: TTarWriter; R: TTarReader; H: TTarHeader; B: TBytes;
begin
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile('m.txt', BytesOf('data'), $1ED, 1234567890);
    W.AddDir('d', $1ED, 1234567890);
    W.Finish;
  finally W.Free; end;
  B := Snapshot(S);
  R := TTarReader.Create(B);
  try
    CheckTrue(R.Next(H), 'file'); CheckEqual('m.txt', H.Name, 'name');
    CheckEqual(Int64(1234567890), H.MTimeUnix, 'mtime');
    CheckEqual(Int64($1ED and $FFFF), Int64(H.Mode and $FFFF), 'mode');
    CheckTrue(R.Next(H), 'dir'); CheckEqual('d/', H.Name, 'dir name slash');
  finally R.Free; end;
end;

procedure TestFinishTwiceAndShortWrite;
var
  S: IStream; W: TTarWriter;
begin
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    W.AddFile('a.txt', BytesOf('hi'));
    W.Finish; W.Finish; CheckTrue(True, 'finish idempotent');
  finally W.Free; end;
end;

function HoleyData: TBytes;
var
  I: Integer;
begin
  SetLength(Result, 8008);
  for I := 0 to 8007 do Result[I] := 0;
  Result[0] := Ord('H'); Result[1] := Ord('E');
  Result[2] := Ord('A'); Result[3] := Ord('D');
  Result[8004] := Ord('T'); Result[8005] := Ord('A');
  Result[8006] := Ord('I'); Result[8007] := Ord('L');
end;

function DenseData: TBytes;
var
  I: Integer;
begin
  SetLength(Result, 3000);
  for I := 0 to 2999 do Result[I] := Byte((I mod 250) + 1);
end;

function WriteSingleFile(const AName: string; const AData: TBytes): TBytes;
var
  S: IStream; W: TTarWriter;
begin
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try W.AddFile(AName, AData); W.Finish; finally W.Free; end;
  Result := Snapshot(S);
end;

function WriteSingleSparse(const AName: string; const AData: TBytes): TBytes;
var
  S: IStream; W: TTarWriter;
begin
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try W.AddSparseFile(AName, AData); W.Finish; finally W.Free; end;
  Result := Snapshot(S);
end;

function FindPaxValue(const H: TTarHeader; const AKey: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(H.PaxRecords) do
    if H.PaxRecords[I].Key = AKey then Result := H.PaxRecords[I].Value;
end;

function RawNameAt(const B: TBytes; ABlock: Integer): string;
var
  I, O: Integer;
begin
  Result := '';
  O := ABlock * C_TAR_BLOCK_SIZE;
  for I := 0 to C_TAR_LAYOUT.Name.Len - 1 do
  begin
    if B[O + I] = 0 then Exit;
    Result := Result + Chr(B[O + I]);
  end;
end;

function FindSparsePlaceholder(const B: TBytes): string;
var
  BI: Integer;
  N: string;
begin
  Result := '';
  BI := 1;
  while (BI + 1) * C_TAR_BLOCK_SIZE <= Length(B) do
  begin
    N := RawNameAt(B, BI);
    if (Length(N) > 16) and (Copy(N, 1, 16) = './GNUSparseFile.') then Exit(N);
    Inc(BI);
  end;
end;

procedure CheckSingleRoundtrip(const B, ExpectData: TBytes; const ExpectName: string; ExpectSize: Int64);
var
  R: TTarReader; H: TTarHeader; LSlice: TByteSpan;
begin
  R := TTarReader.Create(B);
  try
    CheckTrue(R.Next(H), 'entry present');
    CheckEqual(ExpectName, H.Name, 'entry name');
    CheckEqual(ExpectSize, H.Size, 'entry size');
    if Length(ExpectData) > 0 then
    begin
      CheckTrue(R.TrySlice(LSlice), 'entry slice');
      CheckTrue(nextpas.core.bytes.ops.BytesEqual(ExpectData, SpanClone(LSlice)), 'entry content');
    end;
    CheckTrue(R.Next(H) = False, 'end of archive');
  finally R.Free; end;
end;

procedure TestSparseRoundtrip;
var
  Data, B: TBytes;
begin
  Data := HoleyData;
  B := WriteSingleSparse('sparse.bin', Data);
  CheckSingleRoundtrip(B, Data, 'sparse.bin', Int64(Length(Data)));
end;

procedure TestSparseSmallerThanDense;
var
  Data, BDense, BSparse: TBytes;
begin
  Data := HoleyData;
  BDense := WriteSingleFile('sparse.bin', Data);
  BSparse := WriteSingleSparse('sparse.bin', Data);
  CheckTrue(Length(BSparse) < Length(BDense), 'sparse stored smaller');
end;

procedure TestSparseFallbackIdentical;
var
  Data, B1, B2: TBytes;
begin
  Data := DenseData;
  B1 := WriteSingleFile('dense.bin', Data);
  B2 := WriteSingleSparse('dense.bin', Data);
  CheckTrue(nextpas.core.bytes.ops.BytesEqual(B1, B2), 'no-benefit falls back to dense bytes');
  CheckSingleRoundtrip(B2, Data, 'dense.bin', Int64(Length(Data)));
end;

procedure TestSparseEmptyDense;
var
  B1, B2: TBytes;
begin
  B1 := WriteSingleFile('e.bin', nil);
  B2 := WriteSingleSparse('e.bin', nil);
  CheckTrue(nextpas.core.bytes.ops.BytesEqual(B1, B2), 'empty falls back to dense bytes');
  CheckSingleRoundtrip(B2, nil, 'e.bin', 0);
end;

procedure TestSparseStructure;
var
  Data, B: TBytes;
  R: TTarReader; H: TTarHeader;
begin
  Data := HoleyData;
  B := WriteSingleSparse('sparse.bin', Data);
  CheckTrue(B[C_TAR_LAYOUT.TypeFlag.Off] = Ord('x'), 'first header is pax');
  CheckEqual('./GNUSparseFile.0/sparse.bin', FindSparsePlaceholder(B), 'deterministic placeholder');
  R := TTarReader.Create(B);
  try
    CheckTrue(R.Next(H), 'sparse present');
    CheckEqual('1', FindPaxValue(H, 'GNU.sparse.major'), 'sparse major');
    CheckEqual('0', FindPaxValue(H, 'GNU.sparse.minor'), 'sparse minor');
    CheckEqual('sparse.bin', FindPaxValue(H, 'GNU.sparse.name'), 'sparse name key');
    CheckEqual('8008', FindPaxValue(H, 'GNU.sparse.realsize'), 'sparse realsize key');
  finally R.Free; end;
end;

procedure TestSparseViaOptionsAndBuilder;
var
  S: IStream; W: TTarWriter; Opts: TTarAddOptions;
  Data, B, BBuilder: TBytes;
  R: TTarReader; H: TTarHeader; LSlice: TByteSpan;
begin
  Data := HoleyData;
  Opts := DefaultTarAddOptions;
  Opts.Sparse := True;
  Opts.Mode := $1A4;
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try W.AddEntryWithOptions('opt.bin', Data, Opts); W.Finish; finally W.Free; end;
  B := Snapshot(S);
  R := TTarReader.Create(B);
  try
    CheckTrue(R.Next(H), 'options sparse present');
    CheckEqual('opt.bin', H.Name, 'options sparse name');
    CheckEqual(Int64(Length(Data)), H.Size, 'options sparse size');
    CheckEqual(Int64($1A4), Int64(H.Mode and $FFFF), 'options mode kept');
    CheckTrue(R.TrySlice(LSlice), 'options sparse slice');
    CheckTrue(nextpas.core.bytes.ops.BytesEqual(Data, SpanClone(LSlice)), 'options sparse content');
  finally R.Free; end;
  BBuilder := TarBuilder.AddSparse('b.bin', Data).Finish;
  CheckSingleRoundtrip(BBuilder, Data, 'b.bin', Int64(Length(Data)));
  BBuilder := TarBuilder.AddSparseWithOptions('c.bin', Data, DefaultTarAddOptions).Finish;
  CheckSingleRoundtrip(BBuilder, Data, 'c.bin', Int64(Length(Data)));
end;

var
  Suite: TTestSuite; Runner: TSuiteRunner; Results: specialize TArray<TTestRunResult>;
begin
  Suite := TTestSuite.Create('tar.writer');
  Suite.Test('block aligned', @TestBlockAlignedAndTwoZero);
  Suite.Test('prefix split', @TestPrefixSplitAndReject);
  Suite.Test('unsafe rejected', @TestUnsafeNameRejected);
  Suite.Test('mode and mtime', @TestModeAndMtime);
  Suite.Test('finish idempotent', @TestFinishTwiceAndShortWrite);
  Suite.Test('sparse roundtrip', @TestSparseRoundtrip);
  Suite.Test('sparse smaller', @TestSparseSmallerThanDense);
  Suite.Test('sparse fallback', @TestSparseFallbackIdentical);
  Suite.Test('sparse empty', @TestSparseEmptyDense);
  Suite.Test('sparse structure', @TestSparseStructure);
  Suite.Test('sparse options', @TestSparseViaOptionsAndBuilder);
  Runner := TSuiteRunner.Create('main');
  Runner.Add(Suite);
  Runner.RunAllWithResult(Results);
  if (Length(Results)=0) or (not Results[0].AllPassed) then Halt(1);
end.
