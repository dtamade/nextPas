program bench_fs_io;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.fs;

const
  WARMUP_ITERS = 50;
  DUR = 2000;

var
  GTmpDir: string;
  GWalkFileCount: Integer;

{$IFDEF LINUX}
function ClockGetTimeNs: Int64;
var
  LBuf: array[0..1] of Int64;
  LPtr: Pointer;
begin
  LBuf[0] := 0; LBuf[1] := 0;
  LPtr := @LBuf[0];
  asm
    movq $1, %rdi
    movq LPtr, %rsi
    movq $228, %rax
    syscall
  end ['rax', 'rdi', 'rsi', 'rdx', 'rcx', 'r11'];
  Result := LBuf[0] * 1000000000 + LBuf[1];
end;
{$ELSE}
function ClockGetTimeNs: Int64;
var
  LTs: TTimeStamp;
begin
  LTs := DateTimeToTimeStamp(Now);
  Result := (Int64(LTs.Date) * 86400000 + LTs.Time) * 1000000;
end;
{$ENDIF}

function FormatSize(ASize: SizeUInt): string;
begin
  if ASize >= 1048576 then
    Result := IntToStr(ASize div 1048576) + 'MB'
  else if ASize >= 1024 then
    Result := IntToStr(ASize div 1024) + 'KB'
  else
    Result := IntToStr(ASize) + 'B';
end;

procedure PrintResult(const AName: string; const AIterations: UInt64;
  const AElapsedNs: Int64; const ABytes: UInt64);
var
  LNsPerOp: Double;
  LMBps: Double;
begin
  if AIterations > 0 then
    LNsPerOp := AElapsedNs / AIterations
  else
    LNsPerOp := 0;
  if AElapsedNs > 0 then
    LMBps := (ABytes / 1048576.0) / (AElapsedNs / 1000000000.0)
  else
    LMBps := 0;
  WriteLn(Format('  %-30s %8d iters  %8.2f ms  %10.1f ns/op  %10.1f MB/s',
    [AName, AIterations, AElapsedNs / 1000000.0, LNsPerOp, LMBps]));
end;

procedure PrintOpsResult(const AName: string; const AIterations: UInt64;
  const AElapsedNs: Int64);
var
  LNsPerOp: Double;
begin
  if AIterations > 0 then
    LNsPerOp := AElapsedNs / AIterations
  else
    LNsPerOp := 0;
  WriteLn(Format('  %-30s %8d iters  %8.2f ms  %10.1f ns/op',
    [AName, AIterations, AElapsedNs / 1000000.0, LNsPerOp]));
end;

{ T10: BenchReadFile — 读不同大小文件 }
procedure BenchReadFile(ASize: SizeUInt; ADurationMs: Integer);
var
  LPath: string;
  LData: TBytes;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  LBytes: UInt64;
  I: Integer;
begin
  LPath := GTmpDir + '/bench_read_' + IntToStr(ASize) + '.bin';
  WriteFile(LPath, TBytes(nil));
  { 创建测试文件 }
  SetLength(LData, ASize);
  for I := 0 to ASize - 1 do
    LData[I] := Byte(I and $FF);
  WriteFile(LPath, LData);

  { 预热 }
  for I := 0 to WARMUP_ITERS - 1 do
    LData := ReadFile(LPath);

  LBytes := 0;
  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    LData := ReadFile(LPath);
    Inc(LBytes, ASize);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintResult('ReadFile ' + FormatSize(ASize), LIters, LElapsedNs, LBytes);

  { cleanup }
  Remove(LPath);
end;

{ T11: BenchWriteFile — 写不同大小文件 }
procedure BenchWriteFile(ASize: SizeUInt; ADurationMs: Integer);
var
  LPath: string;
  LData: TBytes;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  LBytes: UInt64;
  I: Integer;
begin
  LPath := GTmpDir + '/bench_write_' + IntToStr(ASize) + '.bin';
  SetLength(LData, ASize);
  for I := 0 to ASize - 1 do
    LData[I] := Byte(I and $FF);

  { 预热 }
  for I := 0 to WARMUP_ITERS - 1 do
    WriteFile(LPath, LData);

  LBytes := 0;
  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    WriteFile(LPath, LData);
    Inc(LBytes, ASize);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintResult('WriteFile ' + FormatSize(ASize), LIters, LElapsedNs, LBytes);

  { cleanup }
  Remove(LPath);
end;

{ T12: BenchCopyFile — 复制不同大小文件 }
procedure BenchCopyFile(ASize: SizeUInt; ADurationMs: Integer);
var
  LSrc, LDst: string;
  LData: TBytes;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  LBytes: UInt64;
  I: Integer;
begin
  LSrc := GTmpDir + '/bench_copy_src_' + IntToStr(ASize) + '.bin';
  LDst := GTmpDir + '/bench_copy_dst_' + IntToStr(ASize) + '.bin';
  SetLength(LData, ASize);
  for I := 0 to ASize - 1 do
    LData[I] := Byte(I and $FF);
  WriteFile(LSrc, LData);

  { 预热 }
  for I := 0 to WARMUP_ITERS - 1 do
  begin
    CopyFile(LSrc, LDst);
    Remove(LDst);
  end;

  LBytes := 0;
  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    CopyFile(LSrc, LDst);
    Remove(LDst);
    Inc(LBytes, ASize);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintResult('CopyFile ' + FormatSize(ASize), LIters, LElapsedNs, LBytes);

  { cleanup }
  Remove(LSrc);
end;

{ T13: BenchReadDir — 读目录 }
procedure BenchReadDir(AFileCount: Integer; ADurationMs: Integer);
var
  LDir: string;
  LEntries: TDirEntryArray;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  I: Integer;
begin
  LDir := GTmpDir + '/bench_readdir_' + IntToStr(AFileCount);
  MkdirAll(LDir);
  for I := 0 to AFileCount - 1 do
    WriteFile(LDir + '/f' + IntToStr(I) + '.txt', TBytes.Create(0));

  { 预热 }
  for I := 0 to WARMUP_ITERS - 1 do
  begin
    LEntries := ReadDir(LDir);
    if Length(LEntries) < 0 then;
  end;

  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    LEntries := ReadDir(LDir);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintOpsResult('ReadDir ' + IntToStr(AFileCount) + ' files', LIters, LElapsedNs);

  { cleanup }
  RemoveAll(LDir);
end;

{ 全局回调函数，用于 Walk 基准测试 }
function WalkCounterCallback(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception): Boolean;
begin
  Inc(GWalkFileCount);
  Result := True;
end;

{ T14: BenchWalk — 遍历目录树 }
procedure CreateWalkTree(const ABase: string; AWidth, ADepth: Integer);
var
  I: Integer;
  LDir: string;
begin
  MkdirAll(ABase);
  for I := 0 to AWidth - 1 do
    WriteFile(ABase + '/f' + IntToStr(I) + '.txt', TBytes.Create(0));
  if ADepth > 1 then
    for I := 0 to AWidth - 1 do
    begin
      LDir := ABase + '/d' + IntToStr(I);
      CreateWalkTree(LDir, AWidth, ADepth - 1);
    end;
end;

procedure BenchWalk(AWidth, ADepth, ADurationMs: Integer);
var
  LWalkDir: string;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  I: Integer;
begin
  LWalkDir := GTmpDir + '/bench_walk_w' + IntToStr(AWidth) + '_d' + IntToStr(ADepth);
  CreateWalkTree(LWalkDir, AWidth, ADepth);

  { 预热 }
  for I := 0 to WARMUP_ITERS - 1 do
  begin
    GWalkFileCount := 0;
    Walk(LWalkDir, @WalkCounterCallback);
  end;

  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    GWalkFileCount := 0;
    Walk(LWalkDir, @WalkCounterCallback);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintOpsResult('Walk w=' + IntToStr(AWidth) + ' d=' + IntToStr(ADepth) +
    ' (' + IntToStr(GWalkFileCount) + ' entries)', LIters, LElapsedNs);

  { cleanup }
  RemoveAll(LWalkDir);
end;

{ T15: BenchPathJoin — 路径拼接 }
procedure BenchPathJoin(AComponents: Integer; ADurationMs: Integer);
var
  LParts: array of string;
  LResult: string;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  I: Integer;
begin
  SetLength(LParts, AComponents);
  for I := 0 to AComponents - 1 do
    LParts[I] := 'component' + IntToStr(I);

  { 预热 }
  for I := 0 to WARMUP_ITERS - 1 do
    LResult := PathJoin(LParts);

  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    LResult := PathJoin(LParts);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintOpsResult('PathJoin ' + IntToStr(AComponents) + ' parts', LIters, LElapsedNs);
  if Length(LResult) = 0 then;
end;

{ T16: BenchScanFileLines — 逐行扫描 }
procedure BenchScanFileLines(ALineCount: Integer; ADurationMs: Integer);
var
  LPath: string;
  LLines: TStringArray;
  LScanner: IScanner;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  LBytes: UInt64;
  I: Integer;
begin
  LPath := GTmpDir + '/bench_scan_' + IntToStr(ALineCount) + '.txt';
  SetLength(LLines, ALineCount);
  for I := 0 to ALineCount - 1 do
    LLines[I] := 'line ' + IntToStr(I) + ' some padding text to make lines longer for realistic testing';
  WriteFileLines(LPath, LLines);

  { 预热 }
  for I := 0 to WARMUP_ITERS - 1 do
  begin
    LScanner := ScanFileLines(LPath);
    while LScanner.Scan do;
  end;

  LBytes := 0;
  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    LScanner := ScanFileLines(LPath);
    while LScanner.Scan do
      Inc(LBytes, Length(LScanner.Text));
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintResult('ScanFileLines ' + IntToStr(ALineCount) + ' lines', LIters,
    LElapsedNs, LBytes);

  { cleanup }
  Remove(LPath);
end;

{ T17: BenchMapFileLines — 映射读行 }
procedure BenchMapFileLines(ALineCount: Integer; ADurationMs: Integer);
var
  LPath: string;
  LLines: TStringArray;
  LMapped: IMappedLines;
  LStart, LEnd, LElapsedNs: Int64;
  LIters: UInt64;
  LLineCount: Int32;
  I: Integer;
begin
  LPath := GTmpDir + '/bench_mmap_' + IntToStr(ALineCount) + '.txt';
  SetLength(LLines, ALineCount);
  for I := 0 to ALineCount - 1 do
    LLines[I] := 'line ' + IntToStr(I) + ' some padding text to make lines longer for realistic testing';
  WriteFileLines(LPath, LLines);

  { 预热 }
  for I := 0 to WARMUP_ITERS - 1 do
  begin
    LMapped := MapFileLines(LPath);
    LLineCount := LMapped.Count;
  end;

  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    LMapped := MapFileLines(LPath);
    LLineCount := LMapped.Count;
    for I := 0 to LLineCount - 1 do
      LMapped.Line(I);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  PrintOpsResult('MapFileLines ' + IntToStr(ALineCount) + ' lines', LIters, LElapsedNs);

  { cleanup }
  Remove(LPath);
end;

begin
  GTmpDir := '/tmp/nextpas_fs_bench_io_' + IntToStr(GetProcessID);
  MkdirAll(GTmpDir);
  try
    WriteLn('=== nextpas.core.fs IO Benchmarks ===');
    WriteLn;

    WriteLn('--- ReadFile ---');
    BenchReadFile(1024, DUR);
    BenchReadFile(65536, DUR);
    BenchReadFile(1048576, DUR);
    BenchReadFile(16777216, DUR);

    WriteLn;
    WriteLn('--- WriteFile ---');
    BenchWriteFile(1024, DUR);
    BenchWriteFile(65536, DUR);
    BenchWriteFile(1048576, DUR);
    BenchWriteFile(16777216, DUR);

    WriteLn;
    WriteLn('--- CopyFile ---');
    BenchCopyFile(1024, DUR);
    BenchCopyFile(65536, DUR);
    BenchCopyFile(1048576, DUR);
    BenchCopyFile(16777216, DUR);

    WriteLn;
    WriteLn('--- ReadDir ---');
    BenchReadDir(10, DUR);
    BenchReadDir(100, DUR);
    BenchReadDir(1000, DUR);

    WriteLn;
    WriteLn('--- Walk ---');
    BenchWalk(3, 3, DUR);
    BenchWalk(3, 10, DUR);

    WriteLn;
    WriteLn('--- PathJoin ---');
    BenchPathJoin(2, DUR);
    BenchPathJoin(5, DUR);

    WriteLn;
    WriteLn('--- ScanFileLines ---');
    BenchScanFileLines(100, DUR);
    BenchScanFileLines(10000, DUR);

    WriteLn;
    WriteLn('--- MapFileLines ---');
    BenchMapFileLines(100, DUR);
    BenchMapFileLines(10000, DUR);

    WriteLn;
    WriteLn('Done.');
  finally
    RemoveAll(GTmpDir);
  end;
end.
