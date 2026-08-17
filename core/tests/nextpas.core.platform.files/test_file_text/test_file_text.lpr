program test_file_text;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.files.text,
  nextpas.core.test;

const
  F = '/tmp/td888_core_file_text.bin';

procedure TestRoundtrip;
var
  S, R: AnsiString;
begin
  { 写→读往返, 内容精确(含 UTF-8 中文与二进制字节) }
  S := '你好, tuiDesign888!' + #10 + 'line2 ' + #0 + #255 + #10;
  Check(FileWriteAllText(F, S), 'write ok');
  Check(FileReadAllText(F, R), 'read ok');
  CheckEqual(R, S, 'roundtrip exact');
end;

procedure TestOverwrite;
var
  S, R: AnsiString;
begin
  { 覆盖写 = 截断旧内容换新 }
  Check(FileWriteAllText(F, 'AAAAAAA'), 'write old');
  Check(FileWriteAllText(F, 'BB'), 'write new');
  Check(FileReadAllText(F, R), 'read after overwrite');
  CheckEqual(R, 'BB', 'overwrite truncated');
end;

procedure TestEmpty;
var
  R: AnsiString;
begin
  { 空内容写 → 空文件; 读回空串 }
  Check(FileWriteAllText(F, ''), 'write empty');
  Check(FileReadAllText(F, R), 'read empty');
  CheckEqual(R, '', 'empty content');
end;

procedure TestLargeContent;
var
  I: Integer;
  S, R: AnsiString;
begin
  { 1MB 内容(跨多次 write 循环)往返 }
  S := '';
  for I := 1 to 131072 do
    S := S + '01234567';
  Check(FileWriteAllText(F, S), 'write large');
  Check(FileReadAllText(F, R), 'read large');
  CheckEqual(R, S, 'large roundtrip exact');
  CheckEqual(Int64(1024 * 1024), Int64(Length(R)), 'large size');
end;

procedure TestFailPaths;
var
  R: AnsiString;
begin
  Check(not FileWriteAllText('/nonexistent_dir/xx', 'x'),
    'write missing dir false');
  Check(not FileReadAllText('/nonexistent_dir/xx', R),
    'read missing path false');
  Check(not FileReadAllText('', R), 'read empty path false');
  Check(not FileWriteAllText('', 'x'), 'write empty path false');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.platform.files.text');
  T.Test('roundtrip exact', @TestRoundtrip);
  T.Test('overwrite truncates', @TestOverwrite);
  T.Test('empty content', @TestEmpty);
  T.Test('large content', @TestLargeContent);
  T.Test('fail paths', @TestFailPaths);
  if not T.Run then Halt(1);
end.