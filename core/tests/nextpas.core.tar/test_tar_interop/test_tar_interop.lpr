program test_tar_interop;

{**
 * @desc tar 系统互操作固件门：只读提交在 fixtures/ 的 GNU tar 1.35 产出，
 *  零外部进程依赖。覆盖 ustar 长名拆分、pax 长名回退、UTF-8 名、
 *  pax 远期 mtime、symlink、oldgnu 稀疏、pax 1.0 稀疏（含扩展链）。
 *  固件生成配方见 fixtures/README.md。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.tar.base,
  nextpas.core.tar.reader,
  nextpas.core.fs;

const
  C_MTIME_2020 = 1577836800;
  C_MTIME_2500 = 16725225600;

function Fixture(const AName: string): TBytes;
begin
  Result := ReadFile(PathJoin([GetCurrentDir, 'fixtures', AName]));
end;

function ExpectSparse2: TBytes;
begin
  SetLength(Result, 8 * 1024 * 1024);
  FillChar(Result[0], Length(Result), 0);
  Result[0] := Ord('H');
  Result[1] := Ord('E');
  Result[2] := Ord('A');
  Result[3] := Ord('D');
  Result[4 * 1024 * 1024] := Ord('M');
  Result[4 * 1024 * 1024 + 1] := Ord('I');
  Result[4 * 1024 * 1024 + 2] := Ord('D');
end;

function ExpectSparse8: TBytes;
var
  I, J: Integer;
begin
  SetLength(Result, 8 * 1024 * 1024);
  FillChar(Result[0], Length(Result), 0);
  for I := 0 to 7 do
    for J := 0 to 99 do
      Result[I * 1024 * 1024 + J] := Ord('A') + I;
end;

procedure CheckPayload(const R: TTarReader; const AExpect: TBytes; const AMsg: string);
var
  LSlice: TByteSpan;
begin
  if Length(AExpect) = 0 then
  begin
    CheckTrue(R.TrySlice(LSlice) = False, AMsg + ' empty');
    Exit;
  end;
  CheckTrue(R.TrySlice(LSlice), AMsg + ' slice');
  CheckTrue(BytesEqual(AExpect, SpanClone(LSlice)), AMsg + ' content');
end;

procedure TestSparseGnu;
var
  R: TTarReader;
  H: TTarHeader;
begin
  R := TTarReader.Create(Fixture('sparse-gnu.tar'));
  try
    CheckTrue(R.Next(H), 'sparse entry');
    CheckEqual('sparse2.bin', H.Name, 'sparse name');
    CheckEqual(Int64(8 * 1024 * 1024), H.Size, 'sparse real size');
    CheckEqual(Int64(Ord(tekRegular)), Int64(Ord(H.Kind)), 'sparse kind');
    CheckPayload(R, ExpectSparse2, 'sparse2 reconstructed');
    CheckTrue(R.Next(H) = False, 'sparse end');
  finally
    R.Free;
  end;
end;

procedure TestSparseGnuExt;
var
  R: TTarReader;
  H: TTarHeader;
begin
  R := TTarReader.Create(Fixture('sparse-gnu-ext.tar'));
  try
    CheckTrue(R.Next(H), 'ext entry');
    CheckEqual('sparse8.bin', H.Name, 'ext name');
    CheckEqual(Int64(8 * 1024 * 1024), H.Size, 'ext real size');
    CheckPayload(R, ExpectSparse8, 'ext chain reconstructed');
    CheckTrue(R.Next(H) = False, 'ext end');
  finally
    R.Free;
  end;
end;

procedure TestSparsePax10;
var
  R: TTarReader;
  H: TTarHeader;
begin
  R := TTarReader.Create(Fixture('sparse-pax10.tar'));
  try
    CheckTrue(R.Next(H), 'pax10 entry');
    CheckEqual('sparse2.bin', H.Name, 'pax10 real name from GNU.sparse.name');
    CheckEqual(Int64(8 * 1024 * 1024), H.Size, 'pax10 real size');
    CheckPayload(R, ExpectSparse2, 'pax10 reconstructed');
    CheckTrue(R.Next(H) = False, 'pax10 end');
  finally
    R.Free;
  end;
end;

procedure TestUstarLong;
var
  R: TTarReader;
  H: TTarHeader;
  LongName: string;
  I: Integer;
begin
  LongName := '';
  for I := 1 to 60 do
    LongName := LongName + 'a';
  LongName := LongName + '/';
  for I := 1 to 80 do
    LongName := LongName + 'b';
  LongName := LongName + '.txt';
  R := TTarReader.Create(Fixture('ustar-long.tar'));
  try
    CheckTrue(R.Next(H), 'hello');
    CheckEqual('hello.txt', H.Name, 'hello name');
    CheckEqual(Int64(C_MTIME_2020), H.MTimeUnix, 'hello mtime');
    CheckEqual(Int64(0), Int64(H.UID), 'hello uid');
    CheckPayload(R, StringToBytes('plain content'), 'hello payload');
    CheckTrue(R.Next(H), 'sub dir');
    CheckEqual('sub/', H.Name, 'sub name');
    CheckEqual(Int64(Ord(tekDirectory)), Int64(Ord(H.Kind)), 'sub kind');
    CheckTrue(R.Next(H), 'deep');
    CheckEqual('sub/deep.txt', H.Name, 'deep name');
    CheckPayload(R, StringToBytes('nested content'), 'deep payload');
    CheckTrue(R.Next(H), 'link');
    CheckEqual('alink', H.Name, 'link name');
    CheckEqual(Int64(Ord(tekSymlink)), Int64(Ord(H.Kind)), 'link kind');
    CheckEqual('hello.txt', H.LinkName, 'link target');
    CheckTrue(R.Next(H), 'long');
    CheckEqual(LongName, H.Name, 'prefix-split reassembled');
    CheckPayload(R, StringToBytes('split-name payload'), 'long payload');
    CheckTrue(R.Next(H) = False, 'ustar end');
  finally
    R.Free;
  end;
end;

procedure TestPaxLong;
var
  R: TTarReader;
  H: TTarHeader;
  LongName: string;
  I: Integer;
  FoundMTime: Boolean;
begin
  LongName := '';
  for I := 1 to 150 do
    LongName := LongName + 'c';
  R := TTarReader.Create(Fixture('pax-long.tar'));
  try
    CheckTrue(R.Next(H), 'hello');
    CheckEqual('hello.txt', H.Name, 'hello name');
    CheckPayload(R, StringToBytes('plain content'), 'hello payload');
    CheckTrue(R.Next(H), 'sub dir');
    CheckEqual('sub/', H.Name, 'sub name');
    CheckTrue(R.Next(H), 'deep');
    CheckEqual('sub/deep.txt', H.Name, 'deep name');
    CheckTrue(R.Next(H), 'link');
    CheckEqual(Int64(Ord(tekSymlink)), Int64(Ord(H.Kind)), 'link kind');
    CheckEqual('hello.txt', H.LinkName, 'link target');
    CheckTrue(R.Next(H), 'pax long');
    CheckEqual(LongName, H.Name, 'pax fallback name');
    CheckPayload(R, StringToBytes('pax-fallback payload'), 'pax long payload');
    CheckTrue(R.Next(H), 'utf8');
    CheckEqual('héllo-世界.txt', H.Name, 'utf8 name bytes preserved');
    CheckPayload(R, StringToBytes('utf8 payload'), 'utf8 payload');
    CheckTrue(R.Next(H), 'future');
    CheckEqual('future.txt', H.Name, 'future name');
    CheckEqual(Int64(C_MTIME_2500), H.MTimeUnix, 'pax-only far-future mtime');
    CheckPayload(R, StringToBytes('future payload'), 'future payload');
    FoundMTime := False;
    for I := 0 to High(H.PaxRecords) do
      if H.PaxRecords[I].Key = 'mtime' then
        FoundMTime := True;
    CheckTrue(FoundMTime, 'future mtime record visible');
    CheckTrue(R.Next(H) = False, 'pax end');
  finally
    R.Free;
  end;
end;

var
  Suite: TTestSuite;
  Runner: TSuiteRunner;
  Results: specialize TArray<TTestRunResult>;
begin
  Suite := TTestSuite.Create('tar.interop');
  Suite.Test('gnu sparse fixture', @TestSparseGnu);
  Suite.Test('gnu sparse ext fixture', @TestSparseGnuExt);
  Suite.Test('pax 1.0 sparse fixture', @TestSparsePax10);
  Suite.Test('ustar long fixture', @TestUstarLong);
  Suite.Test('pax long fixture', @TestPaxLong);
  Runner := TSuiteRunner.Create('main');
  Runner.Add(Suite);
  Runner.RunAllWithResult(Results);
  if (Length(Results) = 0) or (not Results[0].AllPassed) then
    Halt(1);
end.
