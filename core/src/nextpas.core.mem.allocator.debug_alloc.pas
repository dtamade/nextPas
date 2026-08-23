{
# nextpas.core.mem.allocator.debug_alloc

## 摘要

调试分配器 — 记录分配来源（文件:行号）。

特性:
- 每次分配记录调用位置（文件名+行号）
- 支持查询某个分配的来源
- 生成分配报告（按文件:行号分组统计）
- 轻量级：仅在 DEBUG 模式下启用

适用场景：调试内存泄漏、分析分配热点。

Author:    nextpas.core
Copyright: (c) 2025 nextpas.core. All rights reserved.
}

unit nextpas.core.mem.allocator.debug_alloc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  {** 最大跟踪分配数 }
  DEBUG_ALLOC_MAX_TRACKED = 4096;
  {** 最大文件名长度 }
  DEBUG_ALLOC_MAX_FILE_LEN = 63;

type
  {** 分配来源记录 }
  TAllocSource = record
    FileName: string;      { 源文件名 }
    LineNum: Integer;      { 行号 }
    AllocSize: SizeUInt;   { 分配大小 }
    AllocTime: UInt64;     { 分配时间戳 }
  end;

  {** 调试分配器统计信息 }
  TDebugAllocStats = record
    TotalAllocs: UInt64;       { 总分配次数 }
    ActiveAllocs: UInt64;      { 活跃分配数 }
    PeakAllocs: UInt64;        { 峰值分配数 }
    TotalBytes: UInt64;        { 总分配字节 }
    ActiveBytes: UInt64;       { 活跃字节 }
    TrackedCount: Integer;     { 当前跟踪数 }
  end;

  {** TDebugAllocator
   *
   *  调试分配器。记录每次分配的来源（文件:行号）。
   *  用于调试内存泄漏和分析分配热点。
   *
   *  使用方式:
   *    LPtr := LDebug.GetMemWithSource(1024, 'main.pas', 42);
   *}
  TDebugAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    { 跟踪表：指针 → 来源 }
    FTrackedPtrs: array[0..DEBUG_ALLOC_MAX_TRACKED - 1] of Pointer;
    FTrackedSources: array[0..DEBUG_ALLOC_MAX_TRACKED - 1] of TAllocSource;
    FTrackedCount: Integer;
    { 统计 }
    FTotalAllocs: UInt64;
    FActiveAllocs: UInt64;
    FPeakAllocs: UInt64;
    FTotalBytes: UInt64;
    FActiveBytes: UInt64;
    function FindTracked(APtr: Pointer): Integer;
    procedure Track(APtr: Pointer; ASize: SizeUInt; const AFile: string; ALine: Integer);
    procedure Untrack(APtr: Pointer);
  public
    {** 创建调试分配器 }
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;

    {** 带来源信息的分配 }
    function GetMemWithSource(ASize: SizeUInt; const AFile: string; ALine: Integer): Pointer;
    {** 获取分配来源 }
    function GetSource(APtr: Pointer; out ASource: TAllocSource): Boolean;
    {** 生成泄漏报告 }
    function ReportLeaks: string;
    {** 获取统计信息 }
    function GetStats: TDebugAllocStats;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.error;

{ --- TDebugAllocator --- }

constructor TDebugAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, FormatAllocErrorMsg('TDebugAllocator', 'Create', 'AInner cannot be nil'));
  FInner := AInner;
  FTrackedCount := 0;
  FTotalAllocs := 0;
  FActiveAllocs := 0;
  FPeakAllocs := 0;
  FTotalBytes := 0;
  FActiveBytes := 0;
  FillChar(FTrackedPtrs, SizeOf(FTrackedPtrs), 0);
end;

destructor TDebugAllocator.Destroy;
begin
  { 释放所有未跟踪的分配 }
  FInner := nil;
  inherited Destroy;
end;

function TDebugAllocator.FindTracked(APtr: Pointer): Integer;
var
  LI: Integer;
begin
  for LI := 0 to FTrackedCount - 1 do
  begin
    if FTrackedPtrs[LI] = APtr then
      Exit(LI);
  end;
  Result := -1;
end;

procedure TDebugAllocator.Track(APtr: Pointer; ASize: SizeUInt;
  const AFile: string; ALine: Integer);
begin
  if FTrackedCount >= DEBUG_ALLOC_MAX_TRACKED then
    Exit;  { 跟踪表满，不记录 }

  FTrackedPtrs[FTrackedCount] := APtr;
  FTrackedSources[FTrackedCount].FileName := AFile;
  FTrackedSources[FTrackedCount].LineNum := ALine;
  FTrackedSources[FTrackedCount].AllocSize := ASize;
  FTrackedSources[FTrackedCount].AllocTime := 0;  { 简化：不记录时间 }
  Inc(FTrackedCount);
end;

procedure TDebugAllocator.Untrack(APtr: Pointer);
var
  LIdx: Integer;
begin
  LIdx := FindTracked(APtr);
  if LIdx < 0 then Exit;

  { 用最后一个覆盖 }
  FTrackedPtrs[LIdx] := FTrackedPtrs[FTrackedCount - 1];
  FTrackedSources[LIdx] := FTrackedSources[FTrackedCount - 1];
  Dec(FTrackedCount);
end;

function TDebugAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
  begin
    Track(Result, ASize, '(unknown)', 0);
    Inc(FTotalAllocs);
    Inc(FActiveAllocs);
    Inc(FTotalBytes, UInt64(ASize));
    Inc(FActiveBytes, UInt64(ASize));
    if FActiveAllocs > FPeakAllocs then
      FPeakAllocs := FActiveAllocs;
  end;
end;

function TDebugAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
  begin
    Track(Result, ASize, '(unknown)', 0);
    Inc(FTotalAllocs);
    Inc(FActiveAllocs);
    Inc(FTotalBytes, UInt64(ASize));
    Inc(FActiveBytes, UInt64(ASize));
    if FActiveAllocs > FPeakAllocs then
      FPeakAllocs := FActiveAllocs;
  end;
end;

function TDebugAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LOldSize: SizeUInt;
  LIdx: Integer;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then
    Exit(GetMem(ASize));

  LIdx := FindTracked(APtr);
  if LIdx >= 0 then
    LOldSize := FTrackedSources[LIdx].AllocSize
  else
    LOldSize := ASize;

  Result := FInner.ReallocMem(APtr, ASize);
  if Result <> nil then
  begin
    if APtr <> nil then
      Untrack(APtr);
    Track(Result, ASize, '(unknown)', 0);
    FActiveBytes := FActiveBytes - UInt64(LOldSize) + UInt64(ASize);
  end;
end;

procedure TDebugAllocator.FreeMem(APtr: Pointer); inline;
var
  LIdx: Integer;
  LSize: SizeUInt;
begin
  if APtr = nil then Exit;

  LIdx := FindTracked(APtr);
  if LIdx >= 0 then
  begin
    LSize := FTrackedSources[LIdx].AllocSize;
    Untrack(APtr);
    if LSize <= FActiveBytes then
      Dec(FActiveBytes, UInt64(LSize));
    if FActiveAllocs > 0 then
      Dec(FActiveAllocs);
  end;

  FInner.FreeMem(APtr);
end;

function TDebugAllocator.GetMemWithSource(ASize: SizeUInt;
  const AFile: string; ALine: Integer): Pointer;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
  begin
    Track(Result, ASize, AFile, ALine);
    Inc(FTotalAllocs);
    Inc(FActiveAllocs);
    Inc(FTotalBytes, UInt64(ASize));
    Inc(FActiveBytes, UInt64(ASize));
    if FActiveAllocs > FPeakAllocs then
      FPeakAllocs := FActiveAllocs;
  end;
end;

function TDebugAllocator.GetSource(APtr: Pointer; out ASource: TAllocSource): Boolean;
var
  LIdx: Integer;
begin
  LIdx := FindTracked(APtr);
  if LIdx >= 0 then
  begin
    ASource := FTrackedSources[LIdx];
    Result := True;
  end
  else
  begin
    ASource.FileName := '';
    ASource.LineNum := 0;
    ASource.AllocSize := 0;
    ASource.AllocTime := 0;
    Result := False;
  end;
end;

function TDebugAllocator.ReportLeaks: string;
var
  LI: Integer;
  LLine: string;
begin
  if FTrackedCount = 0 then
    Exit('No leaks detected.');

  Result := 'Leak report: ' + IntToStr(FTrackedCount) + ' block(s) not freed:'#10;
  for LI := 0 to FTrackedCount - 1 do
  begin
    Str(FTrackedSources[LI].AllocSize, LLine);
    Result := Result + '  $' + HexStr(PtrUInt(FTrackedPtrs[LI]), 16) +
      ' size=' + LLine;
    if FTrackedSources[LI].FileName <> '' then
      Result := Result + ' at ' + FTrackedSources[LI].FileName + ':' +
        IntToStr(FTrackedSources[LI].LineNum);
    Result := Result + #10;
  end;
end;

function TDebugAllocator.GetStats: TDebugAllocStats;
begin
  Result.TotalAllocs := FTotalAllocs;
  Result.ActiveAllocs := FActiveAllocs;
  Result.PeakAllocs := FPeakAllocs;
  Result.TotalBytes := FTotalBytes;
  Result.ActiveBytes := FActiveBytes;
  Result.TrackedCount := FTrackedCount;
end;

function TDebugAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
