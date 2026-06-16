program test_fs_ifile;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.fs;

var
  T: TTestRunner;
  GTmpDir: string;

procedure SetupTmpDir;
begin
  GTmpDir := '/tmp/nextpas_ifile_test_' + IntToStr(GetProcessID);
  nextpas.core.fs.MkdirAll(GTmpDir);
end;

procedure CleanupTmpDir;
begin
  nextpas.core.fs.RemoveAll(GTmpDir);
end;

{ Helper: write raw bytes to a file via IFile }
procedure WriteRawFile(const APath: string; const AData: array of Byte);
var
  LF: IFile;
  LBuf: TBytes;
  I: SizeInt;
begin
  LF := nextpas.core.fs.Create(APath);
  SetLength(LBuf, Length(AData));
  for I := 0 to High(AData) do
    LBuf[I] := AData[I];
  if Length(LBuf) > 0 then
    LF.Write(LBuf[0], Length(LBuf));
  LF.Close;
end;

{ Helper: read all bytes from file into TBytes }
function ReadAllBytes(const APath: string): TBytes;
var
  LF: IFile;
  LSize: SizeUInt;
begin
  LF := nextpas.core.fs.Open(APath, [fmRead]);
  LSize := SizeUInt(LF.Size);
  SetLength(Result, LSize);
  if LSize > 0 then
    LF.Read(Result[0], LSize);
  LF.Close;
end;

{ T5.1: Create, write, close, verify file content }
procedure TestIFile_CreateWriteClose;
var
  LF: IFile;
  LData: TBytes;
  LWritten: SizeUInt;
begin
  LF := nextpas.core.fs.Create(GTmpDir + '/create_write.txt');
  LData := TBytes.Create(Ord('h'), Ord('e'), Ord('l'), Ord('l'), Ord('o'));
  LWritten := LF.Write(LData[0], Length(LData));
  CheckEqual(Int64(5), Int64(LWritten), 'Write returns 5');
  LF.Close;

  LData := ReadAllBytes(GTmpDir + '/create_write.txt');
  CheckEqual(Int64(5), Int64(Length(LData)), 'file size 5');
  CheckEqual(Byte(Ord('h')), LData[0], 'byte 0 = h');
  CheckEqual(Byte(Ord('o')), LData[4], 'byte 4 = o');
end;

{ T5.2: Open for read, read back, verify }
procedure TestIFile_OpenReadClose;
var
  LF: IFile;
  LBuf: array[0..4] of Byte;
  LRead: SizeUInt;
begin
  WriteRawFile(GTmpDir + '/open_read.txt',
    [Ord('a'), Ord('b'), Ord('c'), Ord('d'), Ord('e')]);

  LF := nextpas.core.fs.Open(GTmpDir + '/open_read.txt', [fmRead]);
  LRead := LF.Read(LBuf[0], 5);
  CheckEqual(Int64(5), Int64(LRead), 'Read returns 5');
  CheckEqual(Byte(Ord('a')), LBuf[0], 'byte 0 = a');
  CheckEqual(Byte(Ord('c')), LBuf[2], 'byte 2 = c');
  CheckEqual(Byte(Ord('e')), LBuf[4], 'byte 4 = e');
  LF.Close;
end;

{ T5.3: Seek from beginning, then read }
procedure TestIFile_SeekFromBeginning;
var
  LF: IFile;
  LPos: Int64;
  LBuf: Byte;
  LRead: SizeUInt;
begin
  WriteRawFile(GTmpDir + '/seek_begin.txt',
    [10, 20, 30, 40, 50]);

  LF := nextpas.core.fs.Open(GTmpDir + '/seek_begin.txt', [fmRead]);
  LPos := LF.Seek(3, soBeginning);
  CheckEqual(Int64(3), LPos, 'Seek from beginning returns 3');
  LRead := LF.Read(LBuf, 1);
  CheckEqual(Int64(1), Int64(LRead), 'read 1 byte');
  CheckEqual(Byte(40), LBuf, 'byte at offset 3 = 40');
  LF.Close;
end;

{ T5.4: Seek from end }
procedure TestIFile_SeekFromEnd;
var
  LF: IFile;
  LPos: Int64;
  LBuf: Byte;
  LRead: SizeUInt;
begin
  WriteRawFile(GTmpDir + '/seek_end.txt',
    [10, 20, 30, 40, 50]);

  LF := nextpas.core.fs.Open(GTmpDir + '/seek_end.txt', [fmRead]);
  LPos := LF.Seek(-2, soEnd);
  CheckEqual(Int64(3), LPos, 'Seek(-2, soEnd) returns 3');
  LRead := LF.Read(LBuf, 1);
  CheckEqual(Byte(40), LBuf, 'byte at -2 from end = 40');
  LF.Close;
end;

{ T5.5: Seek from current }
procedure TestIFile_SeekFromCurrent;
var
  LF: IFile;
  LPos: Int64;
  LBuf: Byte;
begin
  WriteRawFile(GTmpDir + '/seek_cur.txt',
    [10, 20, 30, 40, 50]);

  LF := nextpas.core.fs.Open(GTmpDir + '/seek_cur.txt', [fmRead]);
  LF.Seek(1, soBeginning);
  LPos := LF.Seek(2, soCurrent);
  CheckEqual(Int64(3), LPos, 'Seek(1,beg) + Seek(2,cur) = 3');
  LF.Read(LBuf, 1);
  CheckEqual(Byte(40), LBuf, 'byte at 3 = 40');
  LF.Close;
end;

{ T5.6: Position and Size properties }
procedure TestIFile_PositionSize;
var
  LF: IFile;
  LData: TBytes;
begin
  LF := nextpas.core.fs.Create(GTmpDir + '/pos_size.txt');
  LData := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
  LF.Write(LData[0], Length(LData));
  CheckEqual(Int64(10), LF.Position, 'Position after write = 10');
  CheckEqual(Int64(10), LF.Size, 'Size = 10 after write');

  LF.Seek(0, soBeginning);
  CheckEqual(Int64(0), LF.Position, 'Position after Seek(0) = 0');
  LF.Close;
end;

{ T5.7: Name property returns file path }
procedure TestIFile_Name;
var
  LF: IFile;
  LPath: string;
begin
  LPath := GTmpDir + '/name_test.txt';
  LF := nextpas.core.fs.Create(LPath);
  CheckEqual(LPath, LF.Name, 'Name returns file path');
  LF.Close;
end;

{ T5.8: Sync then verify data persisted }
procedure TestIFile_Sync;
var
  LF: IFile;
  LData: TBytes;
  LRead: TBytes;
begin
  LF := nextpas.core.fs.Create(GTmpDir + '/sync_test.txt');
  LData := TBytes.Create(Ord('s'), Ord('y'), Ord('n'), Ord('c'));
  LF.Write(LData[0], Length(LData));
  LF.Sync;
  LF.Close;

  LRead := ReadAllBytes(GTmpDir + '/sync_test.txt');
  CheckEqual(Int64(4), Int64(Length(LRead)), 'sync file size 4');
  CheckEqual(Byte(Ord('s')), LRead[0], 'sync byte 0');
  CheckEqual(Byte(Ord('c')), LRead[3], 'sync byte 3');
end;

{ T5.9: Truncate after writing }
procedure TestIFile_Truncate;
var
  LF: IFile;
  LData: TBytes;
begin
  LF := nextpas.core.fs.Create(GTmpDir + '/truncate.txt');
  SetLength(LData, 100);
  FillChar(LData[0], 100, Ord('X'));
  LF.Write(LData[0], 100);
  CheckEqual(Int64(100), LF.Size, 'size before truncate = 100');

  LF.Truncate(50);
  CheckEqual(Int64(50), LF.Size, 'size after truncate(50) = 50');
  LF.Close;

  LData := ReadAllBytes(GTmpDir + '/truncate.txt');
  CheckEqual(Int64(50), Int64(Length(LData)), 'file on disk is 50 bytes');
end;

{ T5.10: Truncate to zero }
procedure TestIFile_TruncateToZero;
var
  LF: IFile;
  LData: TBytes;
begin
  LF := nextpas.core.fs.Create(GTmpDir + '/trunc_zero.txt');
  LData := TBytes.Create(1, 2, 3, 4, 5);
  LF.Write(LData[0], 5);
  LF.Truncate(0);
  CheckEqual(Int64(0), LF.Size, 'truncated to 0');
  LF.Close;

  LData := ReadAllBytes(GTmpDir + '/trunc_zero.txt');
  CheckEqual(Int64(0), Int64(Length(LData)), 'file on disk is 0 bytes');
end;

{ T5.11: Large I/O — write and read 128KB }
procedure TestIFile_LargeIO;
var
  LF: IFile;
  LWrite, LRead: TBytes;
  LI: SizeInt;
  LTotalRead: SizeUInt;
begin
  SetLength(LWrite, 128 * 1024);
  for LI := 0 to High(LWrite) do
    LWrite[LI] := Byte(LI and $FF);

  LF := nextpas.core.fs.Create(GTmpDir + '/large_io.bin');
  LF.Write(LWrite[0], Length(LWrite));
  CheckEqual(Int64(128 * 1024), LF.Size, 'size after 128KB write');
  LF.Close;

  LF := nextpas.core.fs.Open(GTmpDir + '/large_io.bin', [fmRead]);
  SetLength(LRead, 128 * 1024);
  LTotalRead := LF.Read(LRead[0], Length(LRead));
  CheckEqual(Int64(128 * 1024), Int64(LTotalRead), 'read 128KB');
  for LI := 0 to High(LWrite) do
    if LWrite[LI] <> LRead[LI] then
    begin
      Check(False, 'data mismatch at offset ' + IntToStr(LI));
      Break;
    end;
  LF.Close;
end;

{ T5.12: Interface release — heaptrc verifies 0 leaks }
procedure TestIFile_InterfaceRelease;
var
  LF: IFile;
begin
  LF := nextpas.core.fs.Create(GTmpDir + '/release.txt');
  LF.Write(PAnsiChar('x')^, 1);
  LF.Close;
  LF := nil;
  { heaptrc -gh will report leaks; 0 leaks means interface was released }
  Check(True, 'interface released without leak');
end;

{ T5.13: Open nonexistent file raises ENotFoundError }
procedure TestIFile_OpenNonexistent;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    nextpas.core.fs.Open(GTmpDir + '/nonexistent_xyz_abc', [fmRead]);
  except
    on E: ENotFoundError do
      LGot := True;
  end;
  Check(LGot, 'Open nonexistent raises ENotFoundError');
end;

{ T5.14: SetPosition property }
procedure TestIFile_SetPosition;
var
  LF: IFile;
  LBuf: Byte;
begin
  WriteRawFile(GTmpDir + '/set_pos.txt',
    [10, 20, 30, 40, 50]);

  LF := nextpas.core.fs.Open(GTmpDir + '/set_pos.txt', [fmRead]);
  LF.Position := 2;
  CheckEqual(Int64(2), LF.Position, 'Position after set = 2');
  LF.Read(LBuf, 1);
  CheckEqual(Byte(30), LBuf, 'byte at position 2 = 30');
  LF.Close;
end;

{ T5.15: Stat returns valid TFileInfo }
procedure TestIFile_Stat;
var
  LF: IFile;
  LInfo: TFileInfo;
begin
  WriteRawFile(GTmpDir + '/stat.txt',
    [1, 2, 3, 4, 5]);

  LF := nextpas.core.fs.Open(GTmpDir + '/stat.txt', [fmRead]);
  LInfo := LF.Stat;
  CheckEqual(Int64(5), LInfo.Size, 'Stat.Size = 5');
  Check(LInfo.FileType = ftRegular, 'Stat.FileType = ftRegular');
  Check(not LInfo.IsDir, 'Stat.IsDir = false');
  LF.Close;
end;

{ T5.16: Partial read — read less than available }
procedure TestIFile_PartialRead;
var
  LF: IFile;
  LBuf: array[0..1] of Byte;
  LRead: SizeUInt;
begin
  WriteRawFile(GTmpDir + '/partial_read.txt',
    [10, 20, 30, 40, 50]);

  LF := nextpas.core.fs.Open(GTmpDir + '/partial_read.txt', [fmRead]);
  LRead := LF.Read(LBuf[0], 2);
  CheckEqual(Int64(2), Int64(LRead), 'partial read returns 2');
  CheckEqual(Byte(10), LBuf[0], 'partial byte 0');
  CheckEqual(Byte(20), LBuf[1], 'partial byte 1');
  CheckEqual(Int64(2), LF.Position, 'Position advances by read count');
  LF.Close;
end;

{ T5.17: Read at EOF returns 0 }
procedure TestIFile_ReadAtEOF;
var
  LF: IFile;
  LBuf: Byte;
  LRead: SizeUInt;
begin
  WriteRawFile(GTmpDir + '/read_eof.txt', [42]);

  LF := nextpas.core.fs.Open(GTmpDir + '/read_eof.txt', [fmRead]);
  LF.Seek(0, soEnd);
  LRead := LF.Read(LBuf, 1);
  CheckEqual(Int64(0), Int64(LRead), 'Read at EOF returns 0');
  LF.Close;
end;

begin
  SetupTmpDir;
  try
    T := TTestRunner.Create('nextpas.core.fs.ifile');

    T.Run('Create write close', @TestIFile_CreateWriteClose);
    T.Run('Open read close', @TestIFile_OpenReadClose);
    T.Run('Seek from beginning', @TestIFile_SeekFromBeginning);
    T.Run('Seek from end', @TestIFile_SeekFromEnd);
    T.Run('Seek from current', @TestIFile_SeekFromCurrent);
    T.Run('Position and Size', @TestIFile_PositionSize);
    T.Run('Name property', @TestIFile_Name);
    T.Run('Sync', @TestIFile_Sync);
    T.Run('Truncate', @TestIFile_Truncate);
    T.Run('Truncate to zero', @TestIFile_TruncateToZero);
    T.Run('Large I/O 128KB', @TestIFile_LargeIO);
    T.Run('Interface release', @TestIFile_InterfaceRelease);
    T.Run('Open nonexistent raises', @TestIFile_OpenNonexistent);
    T.Run('SetPosition property', @TestIFile_SetPosition);
    T.Run('Stat', @TestIFile_Stat);
    T.Run('Partial read', @TestIFile_PartialRead);
    T.Run('Read at EOF', @TestIFile_ReadAtEOF);

    T.Summary;
  finally
    CleanupTmpDir;
  end;
end.
