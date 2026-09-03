unit nextpas.core.async.buffer;
{**
 * @desc 异步缓冲区池：高效的缓冲区分配和回收。
 *       支持固定大小缓冲区池和可变大小缓冲区，减少内存分配开销。
 *}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base;

type
  {** 缓冲区回调 *}
  TBufferCallback = procedure(AData: Pointer; ALen: UInt32; AContext: Pointer);

  {** 缓冲区选项 *}
  TBufferOption = (
    boZeroCopy,      { 零拷贝模式：直接传递指针，不复制数据 }
    boPooled         { 池化模式：从缓冲区池分配 }
  );
  TBufferOptions = set of TBufferOption;

  {** 异步缓冲区 *}
  TAsyncBuffer = record
    Data: Pointer;
    Len: UInt32;
    Cap: UInt32;
    Owner: Boolean;  { 是否拥有数据 }
  end;

  {** 缓冲区池接口 *}
  IAsyncBufferPool = interface
    ['{C8E5F6A7-3B9D-4E5C-8A2F-1D6E7B9C3A5F}']
    {** 分配缓冲区 *}
    function Alloc(ASize: UInt32): TAsyncBuffer;
    {** 释放缓冲区 *}
    procedure Free(var ABuffer: TAsyncBuffer);
    {** 获取池统计 *}
    function GetStats(out AAllocated, AFreed, AActive, APooled: UInt64): Boolean;
    {** 获取池容量 *}
    function Capacity: UInt32;
    {** 获取活跃缓冲区数 *}
    function ActiveCount: UInt32;
  end;

{** 创建缓冲区池 *}
function CreateAsyncBufferPool(AChunkSize: UInt32 = 4096; ACapacity: UInt32 = 1024): IAsyncBufferPool;

{** 创建缓冲区 *}
function AsyncBufferAlloc(ASize: UInt32): TAsyncBuffer;

{** 释放缓冲区 *}
procedure AsyncBufferFree(var ABuffer: TAsyncBuffer);

{** 复制缓冲区 *}
function AsyncBufferCopy(const ASource: TAsyncBuffer): TAsyncBuffer;

{** 从数据创建缓冲区 *}
function AsyncBufferFromData(AData: Pointer; ALen: UInt32): TAsyncBuffer;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.errors,
  nextpas.core.platform.sync;

const
  DEFAULT_CHUNK_SIZE = 4096;
  DEFAULT_CAPACITY = 1024;

type
  TBufferPoolStats = record
    Allocated: UInt64;
    Freed: UInt64;
    Active: UInt64;
    Pooled: UInt64;
  end;

  PPoolChunk = ^TPoolChunk;
  TPoolChunk = record
    Data: Pointer;
    Next: PPoolChunk;
  end;

  TAsyncBufferPool = class(TInterfacedObject, IAsyncBufferPool)
  private
    FChunkSize: UInt32;
    FCapacity: UInt32;
    FPoolHead: PPoolChunk;
    FPoolCount: UInt32;
    FStats: TBufferPoolStats;
    FLock: TPlatformMutex;
    function AllocChunk: PPoolChunk;
    procedure FreeChunk(AChunk: PPoolChunk);
  public
    constructor Create(AChunkSize: UInt32; ACapacity: UInt32);
    destructor Destroy; override;
    function Alloc(ASize: UInt32): TAsyncBuffer;
    procedure Free(var ABuffer: TAsyncBuffer);
    function GetStats(out AAllocated, AFreed, AActive, APooled: UInt64): Boolean;
    function Capacity: UInt32;
    function ActiveCount: UInt32;
  end;

function CreateAsyncBufferPool(AChunkSize: UInt32; ACapacity: UInt32): IAsyncBufferPool;
begin
  Result := TAsyncBufferPool.Create(AChunkSize, ACapacity);
end;

function AsyncBufferAlloc(ASize: UInt32): TAsyncBuffer;
begin
  Result.Data := GetMem(ASize);
  Result.Len := ASize;
  Result.Cap := ASize;
  Result.Owner := True;
end;

procedure AsyncBufferFree(var ABuffer: TAsyncBuffer);
begin
  if ABuffer.Owner and (ABuffer.Data <> nil) then
    FreeMem(ABuffer.Data, ABuffer.Cap);
  ABuffer.Data := nil;
  ABuffer.Len := 0;
  ABuffer.Cap := 0;
  ABuffer.Owner := False;
end;

function AsyncBufferCopy(const ASource: TAsyncBuffer): TAsyncBuffer;
begin
  if ASource.Data = nil then
  begin
    Result.Data := nil;
    Result.Len := 0;
    Result.Cap := 0;
    Result.Owner := False;
    Exit;
  end;

  Result.Data := GetMem(ASource.Len);
  BytesCopy(Result.Data, ASource.Data, ASource.Len); // perf: inline single Move via bytes.ops BytesCopy single source zero-copy
  Result.Len := ASource.Len;
  Result.Cap := ASource.Len;
  Result.Owner := True;
end;

function AsyncBufferFromData(AData: Pointer; ALen: UInt32): TAsyncBuffer;
begin
  Result.Data := AData;
  Result.Len := ALen;
  Result.Cap := ALen;
  Result.Owner := False;
end;

constructor TAsyncBufferPool.Create(AChunkSize: UInt32; ACapacity: UInt32);
begin
  inherited Create;
  if AChunkSize = 0 then
    FChunkSize := DEFAULT_CHUNK_SIZE
  else
    FChunkSize := AChunkSize;
  if ACapacity = 0 then
    FCapacity := DEFAULT_CAPACITY
  else
    FCapacity := ACapacity;
  FPoolHead := nil;
  FPoolCount := 0;
  BytesZero(@FStats, SizeOf(FStats)); // perf: inline single FillChar via bytes.ops BytesZero single source zero-copy
  if platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL) <> 0 then
    raise EInvalidOperationError.Create('buffer pool: mutex init failed');
end;

destructor TAsyncBufferPool.Destroy;
var
  LChunk: PPoolChunk;
begin
  { Free all pooled chunks }
  while FPoolHead <> nil do
  begin
    LChunk := FPoolHead;
    FPoolHead := FPoolHead^.Next;
    FreeChunk(LChunk);
  end;
  platform_mutex_destroy(FLock);
  inherited Destroy;
end;

function TAsyncBufferPool.AllocChunk: PPoolChunk;
begin
  New(Result);
  Result^.Data := GetMem(FChunkSize);
  Result^.Next := nil;
end;

procedure TAsyncBufferPool.FreeChunk(AChunk: PPoolChunk);
begin
  if AChunk^.Data <> nil then
    FreeMem(AChunk^.Data, FChunkSize);
  Dispose(AChunk);
end;

function TAsyncBufferPool.Alloc(ASize: UInt32): TAsyncBuffer;
var
  LChunk: PPoolChunk;
begin
  platform_mutex_lock(FLock);
  try
    { Try to reuse from pool }
    if (FPoolHead <> nil) and (ASize <= FChunkSize) then
    begin
      LChunk := FPoolHead;
      FPoolHead := FPoolHead^.Next;
      Dec(FPoolCount);

      Result.Data := LChunk^.Data;
      Result.Len := ASize;
      Result.Cap := FChunkSize;
      Result.Owner := True;
      Dispose(LChunk);

      Inc(FStats.Allocated);
      Inc(FStats.Active);
      Exit;
    end;

    { Allocate new }
    if ASize <= FChunkSize then
    begin
      LChunk := AllocChunk;
      Result.Data := LChunk^.Data;
      Result.Len := ASize;
      Result.Cap := FChunkSize;
      Result.Owner := True;
      Dispose(LChunk);
    end
    else
    begin
      Result.Data := GetMem(ASize);
      Result.Len := ASize;
      Result.Cap := ASize;
      Result.Owner := True;
    end;

    Inc(FStats.Allocated);
    Inc(FStats.Active);
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncBufferPool.Free(var ABuffer: TAsyncBuffer);
var
  LChunk: PPoolChunk;
begin
  if not ABuffer.Owner or (ABuffer.Data = nil) then
  begin
    ABuffer.Data := nil;
    ABuffer.Len := 0;
    ABuffer.Cap := 0;
    Exit;
  end;

  platform_mutex_lock(FLock);
  try
    { Return to pool if capacity allows }
    if (ABuffer.Cap = FChunkSize) and (FPoolCount < FCapacity) then
    begin
      New(LChunk);
      LChunk^.Data := ABuffer.Data;
      LChunk^.Next := FPoolHead;
      FPoolHead := LChunk;
      Inc(FPoolCount);
      Inc(FStats.Pooled);
    end
    else
    begin
      FreeMem(ABuffer.Data, ABuffer.Cap);
    end;

    ABuffer.Data := nil;
    ABuffer.Len := 0;
    ABuffer.Cap := 0;
    ABuffer.Owner := False;

    Inc(FStats.Freed);
    if FStats.Active > 0 then
      Dec(FStats.Active);
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncBufferPool.GetStats(out AAllocated, AFreed, AActive, APooled: UInt64): Boolean;
begin
  AAllocated := FStats.Allocated;
  AFreed := FStats.Freed;
  AActive := FStats.Active;
  APooled := FStats.Pooled;
  Result := True;
end;

function TAsyncBufferPool.Capacity: UInt32;
begin
  Result := FCapacity;
end;

function TAsyncBufferPool.ActiveCount: UInt32;
begin
  Result := FStats.Active;
end;

end.
