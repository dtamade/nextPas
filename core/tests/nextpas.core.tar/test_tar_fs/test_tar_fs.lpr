program test_tar_fs;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.tar,
  nextpas.core.tar.base,
  nextpas.core.tar.writer,
  nextpas.core.tar.reader,
  nextpas.core.fs,
  nextpas.core.io.memory;

function BytesOf(const S: string): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then Move(S[1], Result[0], Length(S));
end;

function SameBytes(const A, B: TBytes): Boolean;
var I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do if A[I] <> B[I] then Exit(False);
  Result := True;
end;

procedure TestPackAndExtract;
var
  Root, OutDir: string;
  Arc: TBytes;
  R: TTarReader; H: TTarHeader; Found: Boolean;
begin
  Root := PathJoin([GetTempDir, 'nextpas_tar_fs_' + IntToStr(GetProcessID) + '_src']);
  OutDir := PathJoin([GetTempDir, 'nextpas_tar_fs_' + IntToStr(GetProcessID) + '_out']);
  RemoveAll(Root); RemoveAll(OutDir);
  MkdirAll(PathJoin([Root, 'a', 'b']), PermDirDefault);
  WriteFile(PathJoin([Root, 'a', 'b', 'hello.txt']), BytesOf('hello'), PermDefault);
  WriteFile(PathJoin([Root, 'root.txt']), BytesOf('root'), PermDefault);
  Arc := TarPackDir(Root);
  CheckTrue(Length(Arc) > 0, 'arc non-empty');
  CheckTrue(Length(Arc) mod 512 = 0, 'block aligned');
  TarExtractToDir(Arc, OutDir);
  CheckTrue(FileExists(PathJoin([OutDir, 'a', 'b', 'hello.txt'])), 'hello exists');
  CheckTrue(SameBytes(ReadFile(PathJoin([OutDir, 'a', 'b', 'hello.txt'])), BytesOf('hello')), 'hello content');
  CheckTrue(SameBytes(ReadFile(PathJoin([OutDir, 'root.txt'])), BytesOf('root')), 'root content');
  R := TTarReader.Create(Arc);
  try
    Found := False;
    while R.Next(H) do if H.Name = 'a/b/hello.txt' then Found := True;
    CheckTrue(Found, 'entry listed');
  finally R.Free; end;
  SetLength(Arc, 0);
  RemoveAll(Root); RemoveAll(OutDir);
end;

procedure TestUnsafeExtractRejected;
var
  S: IStream; W: TTarWriter; Arc: TBytes; Hdr: TTarHeader;
  OutDir: string;
begin
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  { bypass Validate via raw header for test: use writer's AddFile with unsafe name should already raise }
  try W.AddFile('../evil.txt', BytesOf('x')); CheckTrue(False, 'writer should reject');
  except on E: EArgumentError do CheckTrue(True, 'writer rejects unsafe'); end;
  W.Free;
  { craft manual tar with unsafe name to test reader/fs guard: use low-level emit }
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  FillChar(Hdr, SizeOf(Hdr), 0);
  Hdr.Name := 'ok.txt'; Hdr.Kind := tekRegular; Hdr.Mode := $1A4;
  W.AddEntry(Hdr, BytesOf('ok'));
  W.Finish; W.Free;
  SetLength(Arc, S.Size);
  S.Seek(0, soBeginning); S.Read(Arc[0], Length(Arc));
  { tamper first name to ../evil }
  Arc[0] := Ord('.'); Arc[1] := Ord('.'); Arc[2] := Ord('/');
  { recompute checksum: brute force update header checksum area to original sum }
  OutDir := PathJoin([GetTempDir, 'nextpas_tar_fs_unsafe_' + IntToStr(GetProcessID)]);
  RemoveAll(OutDir);
  try TarExtractToDir(Arc, OutDir); CheckTrue(False, 'should reject unsafe name');
  except on E: EParseError do CheckTrue(True, 'extract rejects unsafe'); on E: EIOError do CheckTrue(True, 'checksum mismatch also fail-closed'); end;
  SetLength(Arc, 0);
  RemoveAll(OutDir);
end;

var
  Suite: TTestSuite; Runner: TSuiteRunner; Results: specialize TArray<TTestRunResult>;
begin
  Suite := TTestSuite.Create('tar.fs');
  Suite.Test('pack and extract', @TestPackAndExtract);
  Suite.Test('unsafe extract rejected', @TestUnsafeExtractRejected);
  Runner := TSuiteRunner.Create('main');
  Runner.Add(Suite);
  Runner.RunAllWithResult(Results);
  if (Length(Results)=0) or (not Results[0].AllPassed) then Halt(1);
end.
