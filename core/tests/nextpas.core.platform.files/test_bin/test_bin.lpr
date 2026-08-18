program test_bin;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.platform.files.bin,
  nextpas.core.test;

const
  F = '/tmp/td888_core_file_bin.dat';

function BytesEqual(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  if Result then
    for I := 0 to Length(A) - 1 do
      if A[I] <> B[I] then
        Exit(False);
end;

procedure TestRoundtrip;
var
  B, R: TBytes;
begin
  { 写→读往返, 内容精确(含 0x00/0xFF 全字节域) }
  B := TBytes.Create($00, $01, $7F, $80, $FE, $FF);
  Check(FileWriteAllBytes(F, B), 'write ok');
  Check(FileReadAllBytes(F, R), 'read ok');
  Check(BytesEqual(R, B), 'roundtrip exact');
end;

procedure TestOverwrite;
var
  B, R: TBytes;
begin
  { 覆盖写 = 截断旧内容换新 }
  Check(FileWriteAllBytes(F, TBytes.Create(1, 2, 3, 4, 5)), 'write old');
  Check(FileWriteAllBytes(F, TBytes.Create($AA, $BB)), 'write new');
  Check(FileReadAllBytes(F, R), 'read after overwrite');
  Check(BytesEqual(R, TBytes.Create($AA, $BB)), 'overwrite truncated');
end;

procedure TestEmpty;
var
  R: TBytes;
begin
  { 空数组写 → 空文件; 读回空数组 }
  Check(FileWriteAllBytes(F, nil), 'write empty');
  Check(FileReadAllBytes(F, R), 'read empty');
  CheckEqual(Length(R), 0, 'empty content');
end;

procedure TestLargeContent;
var
  I: Integer;
  B, R: TBytes;
begin
  { 1MB 内容(跨多次 write 循环)往返 }
  SetLength(B, 1024 * 1024);
  for I := 0 to Length(B) - 1 do
    B[I] := Byte(I * 31 + 7);
  Check(FileWriteAllBytes(F, B), 'write large');
  Check(FileReadAllBytes(F, R), 'read large');
  Check(Length(R) = Length(B), 'large size');
  Check(BytesEqual(R, B), 'large content');
end;

procedure TestFailPaths;
var
  R: TBytes;
begin
  Check(not FileWriteAllBytes('/nonexistent_dir/xx', TBytes.Create(1)),
    'write missing dir false');
  Check(not FileReadAllBytes('/nonexistent_dir/xx', R),
    'read missing path false');
  Check(not FileReadAllBytes('', R), 'read empty path false');
  Check(not FileWriteAllBytes('', TBytes.Create(1)), 'write empty path false');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.platform.files.bin');
  T.Test('roundtrip exact', @TestRoundtrip);
  T.Test('overwrite truncates', @TestOverwrite);
  T.Test('empty content', @TestEmpty);
  T.Test('large content', @TestLargeContent);
  T.Test('fail paths', @TestFailPaths);
  if not T.Run then Halt(1);
end.