program test_fs_text;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.fs;

var
  T: TTestRunner;

function TmpPath: string;
begin
  Result := '/tmp/test_fs_text_' + IntToStr(Random(99999));
end;

procedure TestWriteFileText;
var
  LPath, LRead: string;
begin
  LPath := TmpPath + '.txt';
  WriteFileText(LPath, 'hello world');
  LRead := ReadFileText(LPath);
  Check(LRead = 'hello world', 'write+read text');
  DeleteFile(LPath);
end;

procedure TestWriteFileTextEmpty;
var
  LPath, LRead: string;
begin
  LPath := TmpPath + '.txt';
  WriteFileText(LPath, '');
  LRead := ReadFileText(LPath);
  Check(LRead = '', 'empty text');
  DeleteFile(LPath);
end;

procedure TestWriteFileLines;
var
  LPath: string;
  LLines: TStringArray;
begin
  LPath := TmpPath + '.txt';
  WriteFileLines(LPath, TStringArray.Create('line1', 'line2', 'line3'));
  LLines := ReadFileLines(LPath);
  Check(Length(LLines) >= 3, 'at least 3 lines');
  Check(LLines[0] = 'line1', 'line 1');
  Check(LLines[1] = 'line2', 'line 2');
  Check(LLines[2] = 'line3', 'line 3');
  DeleteFile(LPath);
end;

procedure TestWriteFileLinesEmpty;
var
  LPath, LText: string;
begin
  LPath := TmpPath + '.txt';
  WriteFileLines(LPath, nil);
  LText := ReadFileText(LPath);
  Check(LText = '', 'empty lines');
  DeleteFile(LPath);
end;

procedure TestAppendFile;
var
  LPath: string;
  LData: TBytes;
begin
  LPath := TmpPath + '.bin';
  WriteFile(LPath, TBytes.Create(1, 2, 3));
  AppendFile(LPath, TBytes.Create(4, 5));
  LData := ReadFile(LPath);
  CheckEqual(Int64(5), Int64(Length(LData)), 'append length');
  Check((LData[0] = 1) and (LData[4] = 5), 'append content');
  DeleteFile(LPath);
end;

procedure TestAppendFileText;
var
  LPath, LText: string;
begin
  LPath := TmpPath + '.txt';
  WriteFileText(LPath, 'hello');
  AppendFileText(LPath, ' world');
  LText := ReadFileText(LPath);
  Check(LText = 'hello world', 'append text');
  DeleteFile(LPath);
end;

procedure TestAppendToNonExistent;
var
  LPath: string;
  LData: TBytes;
begin
  LPath := TmpPath + '.bin';
  // AppendFile on non-existent should create
  AppendFile(LPath, TBytes.Create(42));
  LData := ReadFile(LPath);
  CheckEqual(Int64(1), Int64(Length(LData)), 'append creates file');
  Check(LData[0] = 42, 'append content');
  DeleteFile(LPath);
end;

procedure TestWriteReadLargeText;
var
  LPath, LText, LRead: string;
  LI: Int32;
begin
  LPath := TmpPath + '.txt';
  SetLength(LText, 100000);
  for LI := 1 to 100000 do LText[LI] := Chr(Ord('A') + (LI mod 26));
  WriteFileText(LPath, LText);
  LRead := ReadFileText(LPath);
  CheckEqual(Int64(100000), Int64(Length(LRead)), 'large text length');
  Check(LRead[1] = Chr(Ord('A') + (1 mod 26)), 'large text first char');
  Check(LRead[100000] = Chr(Ord('A') + (100000 mod 26)), 'large text last char');
  DeleteFile(LPath);
end;

procedure TestWriteFileLinesUnicode;
var
  LPath: string;
  LLines: TStringArray;
begin
  LPath := TmpPath + '.txt';
  WriteFileLines(LPath, TStringArray.Create('日本語', 'Ελληνικά', '中文'));
  LLines := ReadFileLines(LPath);
  Check(Length(LLines) >= 3, 'unicode lines count');
  Check(LLines[0] = '日本語', 'unicode line 1');
  Check(LLines[2] = '中文', 'unicode line 3');
  DeleteFile(LPath);
end;

begin
  T := TTestRunner.Create('nextpas.core.fs.text');
  T.Run('WriteFileText', @TestWriteFileText);
  T.Run('WriteFileText empty', @TestWriteFileTextEmpty);
  T.Run('WriteFileLines', @TestWriteFileLines);
  T.Run('WriteFileLines empty', @TestWriteFileLinesEmpty);
  T.Run('AppendFile', @TestAppendFile);
  T.Run('AppendFileText', @TestAppendFileText);
  T.Run('Append non-existent', @TestAppendToNonExistent);
  T.Run('Large text 100KB', @TestWriteReadLargeText);
  T.Run('Unicode lines', @TestWriteFileLinesUnicode);
  T.Summary;
end.
