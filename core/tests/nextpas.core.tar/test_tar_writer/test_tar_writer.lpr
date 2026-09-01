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
  nextpas.core.tar.reader,
  nextpas.core.tar.writer,
  nextpas.core.io.memory;

function BytesOf(const S: string): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then Move(S[1], Result[0], Length(S));
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
  W.AddFile('a.txt', BytesOf('hi'));
  W.Finish; W.Free;
  B := Snapshot(S);
  CheckTrue(Length(B) mod 512 = 0, 'block aligned');
  CheckTrue(Length(B) >= 1536, 'at least header+data+2zero');
  CheckTrue((B[Length(B)-512]=0) and (B[Length(B)-1024]=0), 'two zero blocks');
end;

procedure TestPrefixSplitAndReject;
var
  S: IStream; W: TTarWriter;
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
    try W.AddFile(LongFail, BytesOf('x')); CheckTrue(False, 'should raise');
    except on E: EIOError do CheckTrue(True, 'too long raises'); end;
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
  W.AddFile('m.txt', BytesOf('data'), $1ED, 1234567890);
  W.AddDir('d', $1ED, 1234567890);
  W.Finish; W.Free;
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
  W.AddFile('a.txt', BytesOf('hi'));
  W.Finish; W.Finish; CheckTrue(True, 'finish idempotent');
  W.Free;
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
  Runner := TSuiteRunner.Create('main');
  Runner.Add(Suite);
  Runner.RunAllWithResult(Results);
  if (Length(Results)=0) or (not Results[0].AllPassed) then Halt(1);
end.
