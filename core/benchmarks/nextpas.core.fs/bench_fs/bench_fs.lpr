program bench_fs;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.io.intf,
  nextpas.core.io.buffer,
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.fs.stream,
  nextpas.core.fs.util,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.fs;

var
  GTmpDir: string;

procedure Bench(const AName: string; const ABytes: Int64; const AElapsed: TDuration);
var
  LNs: Int64;
  LMBps: Double;
begin
  LNs := AElapsed.AsNanoseconds;
  if LNs > 0 then
    LMBps := (ABytes / (1024.0 * 1024.0)) / (LNs / 1000000000.0)
  else
    LMBps := 0;
  WriteLn(Format('  %-35s %10d bytes  %8.2f ms  %8.1f MB/s',
    [AName, ABytes, LNs / 1000000.0, LMBps]));
end;

procedure BenchSeqWrite(const ASize: SizeUInt);
var
  LF: IFile;
  LBuf: array[0..32767] of Byte;
  LRemaining, LChunk: SizeUInt;
  LStart: TInstant;
begin
  FillChar(LBuf[0], SizeOf(LBuf), $AA);
  LF := FsCreate(GTmpDir + '/bench_write.bin');
  LStart := TInstant.Now;
  LRemaining := ASize;
  while LRemaining > 0 do
  begin
    if LRemaining > SizeOf(LBuf) then
      LChunk := SizeOf(LBuf)
    else
      LChunk := LRemaining;
    LF.Write(LBuf[0], LChunk);
    Dec(LRemaining, LChunk);
  end;
  LF.Close;
  Bench('SeqWrite ' + IntToStr(ASize div 1024) + 'KB', Int64(ASize),
    LStart.Elapsed);
end;

procedure BenchSeqRead(const ASize: SizeUInt);
var
  LF: IFile;
  LBuf: array[0..32767] of Byte;
  LN: SizeUInt;
  LTotal: Int64;
  LStart: TInstant;
begin
  LF := FsOpen(GTmpDir + '/bench_write.bin', [fmRead]);
  LStart := TInstant.Now;
  LTotal := 0;
  repeat
    LN := LF.Read(LBuf[0], SizeOf(LBuf));
    Inc(LTotal, Int64(LN));
  until LN = 0;
  LF.Close;
  Bench('SeqRead ' + IntToStr(ASize div 1024) + 'KB', LTotal,
    LStart.Elapsed);
end;

procedure BenchReadFile(const ASize: SizeUInt);
var
  LData: TBytes;
  LStart: TInstant;
begin
  LStart := TInstant.Now;
  LData := FsReadFile(GTmpDir + '/bench_write.bin');
  Bench('ReadFile ' + IntToStr(ASize div 1024) + 'KB', Int64(Length(LData)),
    LStart.Elapsed);
end;

procedure BenchBufRead(const ASize: SizeUInt);
var
  LF: IFile;
  LBR: IReader;
  LBuf: array[0..32767] of Byte;
  LN: SizeUInt;
  LTotal: Int64;
  LStart: TInstant;
begin
  LF := FsOpen(GTmpDir + '/bench_write.bin', [fmRead]);
  LBR := CreateBufferedReader(LF as IReader, 4096);
  LStart := TInstant.Now;
  LTotal := 0;
  repeat
    LN := LBR.Read(LBuf[0], SizeOf(LBuf));
    Inc(LTotal, Int64(LN));
  until LN = 0;
  Bench('BufRead(4KB) ' + IntToStr(ASize div 1024) + 'KB', LTotal,
    LStart.Elapsed);
end;

procedure BenchCopyFile;
var
  LStart: TInstant;
  LCopied: Int64;
begin
  LStart := TInstant.Now;
  LCopied := FsCopyFile(GTmpDir + '/bench_write.bin', GTmpDir + '/bench_copy.bin');
  Bench('CopyFile 10240KB', LCopied, LStart.Elapsed);
end;

procedure CreateWalkTree(const ABase: string; ADepth, AFilesPerDir: Int32);
var
  I: Int32;
  H: TPlatformFileHandle;
  W: PtrUInt;
  LChild: string;
begin
  platform_file_mkdir(PAnsiChar(ABase), 493);
  for I := 0 to AFilesPerDir - 1 do
  begin
    platform_file_open(PAnsiChar(ABase + '/f' + IntToStr(I) + '.txt'),
      fomWriteOnly, fcmCreateAlways, H);
    platform_file_write(H, PAnsiChar('x'), 1, W);
    platform_file_close(H);
  end;
  if ADepth > 0 then
    for I := 0 to 2 do
    begin
      LChild := ABase + '/d' + IntToStr(I);
      CreateWalkTree(LChild, ADepth - 1, AFilesPerDir);
    end;
end;

procedure RemoveWalkTree(const ABase: string);
var
  LHandle: TPlatformDirHandle;
  LEntry: TPlatformDirEntry;
  LChild: string;
begin
  if platform_dir_open(PAnsiChar(ABase), LHandle) <> 0 then
  begin
    platform_file_unlink(PAnsiChar(ABase));
    Exit;
  end;
  while platform_dir_read(LHandle, LEntry) = 0 do
  begin
    LChild := ABase + '/' + StrPas(@LEntry.Name[0]);
    if LEntry.FileType = ftDirectory then
      RemoveWalkTree(LChild)
    else
      platform_file_unlink(PAnsiChar(LChild));
  end;
  platform_dir_close(LHandle);
  platform_file_rmdir(PAnsiChar(ABase));
end;

var
  GWalkCount: Int32;

function WalkCounter(const AEntry: TPlatformWalkEntry;
  AUserData: Pointer): TPlatformWalkAction;
begin
  Inc(GWalkCount);
  Result := pwaContinue;
end;

procedure FpcWalkRecurse(const APath: string; var ACount: Int32);
var
  SR: TSearchRec;
begin
  Inc(ACount);
  if FindFirst(APath + '/*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      if (SR.Attr and faDirectory) <> 0 then
        FpcWalkRecurse(APath + '/' + SR.Name, ACount)
      else
        Inc(ACount);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

procedure BenchWalk;
var
  LWalkDir: string;
  LStart: TInstant;
  LElapsed: TDuration;
  LFpcCount: Int32;
begin
  LWalkDir := GTmpDir + '/walk_tree';
  CreateWalkTree(LWalkDir, 3, 5);

  GWalkCount := 0;
  LStart := TInstant.Now;
  platform_fs_walk(PAnsiChar(LWalkDir), @WalkCounter, nil, False);
  LElapsed := LStart.Elapsed;
  WriteLn(Format('  %-35s %6d entries  %8.2f ms',
    ['platform_fs_walk (depth=3,5f/dir)', GWalkCount, LElapsed.AsNanoseconds / 1000000.0]));

  LFpcCount := 0;
  LStart := TInstant.Now;
  FpcWalkRecurse(LWalkDir, LFpcCount);
  LElapsed := LStart.Elapsed;
  WriteLn(Format('  %-35s %6d entries  %8.2f ms',
    ['FPC FindFirst/Next recursive', LFpcCount, LElapsed.AsNanoseconds / 1000000.0]));

  RemoveWalkTree(LWalkDir);
end;

begin
  GTmpDir := '/tmp/nextpas_fs_bench_' + IntToStr(GetProcessID);
  ForceDirectories(GTmpDir);
  try
    WriteLn('=== nextpas.core.fs benchmarks ===');
    WriteLn;

    BenchSeqWrite(1024 * 1024);
    BenchSeqRead(1024 * 1024);
    BenchReadFile(1024 * 1024);
    BenchBufRead(1024 * 1024);

    BenchSeqWrite(10 * 1024 * 1024);
    BenchSeqRead(10 * 1024 * 1024);
    BenchReadFile(10 * 1024 * 1024);
    BenchBufRead(10 * 1024 * 1024);

    BenchCopyFile;

    WriteLn;
    BenchWalk;

    WriteLn;
    WriteLn('Done.');
  finally
    // cleanup
    DeleteFile(GTmpDir + '/bench_write.bin');
    DeleteFile(GTmpDir + '/bench_copy.bin');
    RemoveWalkTree(GTmpDir + '/walk_tree');
    RmDir(PAnsiChar(GTmpDir));
  end;
end.