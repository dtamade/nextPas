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

procedure TestAppendFileLine;
var
  LPath: string;
  LLines: TStringArray;
begin
  LPath := TmpPath + '.txt';
  WriteFileText(LPath, '');
  AppendFileLine(LPath, 'first');
  AppendFileLine(LPath, 'second');
  AppendFileLine(LPath, 'third');
  LLines := ReadFileLines(LPath);
  Check(Length(LLines) >= 3, 'append 3 lines');
  Check(LLines[0] = 'first', 'line 1');
  Check(LLines[2] = 'third', 'line 3');
  DeleteFile(LPath);
end;

procedure TestReadFileTextStripsUtf8Bom;
var
  LPath, LText: string;
begin
  LPath := TmpPath + '.txt';
  WriteFile(LPath, TBytes.Create($EF, $BB, $BF, Ord('o'), Ord('k')));
  LText := ReadFileText(LPath);
  Check(LText = 'ok', 'UTF-8 BOM stripped');
  DeleteFile(LPath);
end;

procedure TestReadFileTextRejectsInvalidUtf8;
var
  LPath: string;
  LGot: Boolean;
begin
  LPath := TmpPath + '.txt';
  WriteFile(LPath, TBytes.Create($C3, $28));
  LGot := False;
  try
    ReadFileText(LPath);
  except
    on E: EConvertError do
      LGot := True;
  end;
  Check(LGot, 'invalid UTF-8 rejected');
  DeleteFile(LPath);
end;

{ --- BOM encoding detection --- }

procedure TestReadFileText_UTF16LE_BOM;
var
  LPath, LText: string;
begin
  LPath := TmpPath + '.txt';
  { UTF-16LE BOM FF FE + "hi" as UTF-16LE: h=68 00, i=69 00 }
  WriteFile(LPath, TBytes.Create($FF, $FE, $68, $00, $69, $00));
  LText := ReadFileText(LPath);
  Check(LText = 'hi', 'UTF-16LE BOM decoded to UTF-8');
  DeleteFile(LPath);
end;

procedure TestReadFileText_UTF16BE_BOM;
var
  LPath, LText: string;
begin
  LPath := TmpPath + '.txt';
  { UTF-16BE BOM FE FF + "hi" as UTF-16BE: h=00 68, i=00 69 }
  WriteFile(LPath, TBytes.Create($FE, $FF, $00, $68, $00, $69));
  LText := ReadFileText(LPath);
  Check(LText = 'hi', 'UTF-16BE BOM decoded to UTF-8');
  DeleteFile(LPath);
end;

procedure TestReadFileText_EmptyFile;
var
  LPath, LText: string;
begin
  LPath := TmpPath + '.txt';
  WriteFile(LPath, nil);
  LText := ReadFileText(LPath);
  Check(LText = '', 'empty file returns empty string');
  DeleteFile(LPath);
end;

procedure TestReadFileText_ASCII_NoBOM;
var
  LPath, LText: string;
begin
  LPath := TmpPath + '.txt';
  WriteFile(LPath, TBytes.Create(Ord('p'), Ord('l'), Ord('a'), Ord('i'), Ord('n')));
  LText := ReadFileText(LPath);
  Check(LText = 'plain', 'ASCII no BOM');
  DeleteFile(LPath);
end;

procedure TestReadFileText_UTF8_MultiByte;
var
  LPath, LText: string;
begin
  LPath := TmpPath + '.txt';
  { UTF-8 encoded "日本語" (3 CJK chars, each 3 bytes = 9 bytes) }
  WriteFile(LPath, TBytes.Create(
    $E6, $97, $A5,  // 日
    $E6, $9C, $AC,  // 本
    $E8, $AA, $9E   // 語
  ));
  LText := ReadFileText(LPath);
  Check(LText = '日本語', 'UTF-8 multi-byte preserved');
  DeleteFile(LPath);
end;

procedure TestScanFileLines;
var
  LPath: string;
  LScanner: IScanner;
  LCount: Int32;
begin
  LPath := TmpPath + '.txt';
  WriteFileLines(LPath, TStringArray.Create('alpha', 'beta', 'gamma'));
  LScanner := ScanFileLines(LPath);
  LCount := 0;
  while LScanner.Scan do Inc(LCount);
  CheckEqual(Int64(3), Int64(LCount), 'scan 3 lines');
  DeleteFile(LPath);
end;

procedure TestMapFileLines;
var
  LPath: string;
  LMap: IMappedLines;
begin
  LPath := TmpPath + '.txt';
  WriteFileText(LPath, 'one' + #10 + 'two' + #10 + 'three');
  LMap := MapFileLines(LPath);
  CheckEqual(Int64(3), Int64(LMap.Count), 'map 3 lines');
  Check(LMap.Line(0).ToString = 'one', 'map line 0');
  Check(LMap.Line(2).ToString = 'three', 'map line 2');
  Check(LMap.Contains('two'), 'map contains');
  LMap := nil;
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
  T.Run('AppendFileLine', @TestAppendFileLine);
  T.Run('ReadFileText strips UTF-8 BOM', @TestReadFileTextStripsUtf8Bom);
  T.Run('ReadFileText rejects invalid UTF-8', @TestReadFileTextRejectsInvalidUtf8);
  T.Run('ReadFileText UTF-16LE BOM', @TestReadFileText_UTF16LE_BOM);
  T.Run('ReadFileText UTF-16BE BOM', @TestReadFileText_UTF16BE_BOM);
  T.Run('ReadFileText empty file', @TestReadFileText_EmptyFile);
  T.Run('ReadFileText ASCII no BOM', @TestReadFileText_ASCII_NoBOM);
  T.Run('ReadFileText UTF-8 multi-byte', @TestReadFileText_UTF8_MultiByte);
  T.Run('ScanFileLines', @TestScanFileLines);
  T.Run('MapFileLines', @TestMapFileLines);
  T.Summary;
end.
