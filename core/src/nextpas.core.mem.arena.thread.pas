{******************************************************************************
  nextpas.core.mem.arena.thread — Thread-Local Arena (TLA)

  核心设计:
    1. threadvar 存储 per-thread Arena 指针 — 零锁热路径
    2. 全局 Arena 池 (TMemMutex) 回收空闲 Arena
    3. Arena 是 TLocalArena (固定容量 bump pointer)
    4. 热路径 Alloc: TLS hit → ~2ns (与裸 TLocalArena 相同)
    5. 冷路径 Get miss → pool hit → ~100ns; miss → new Arena → ~1μs

  线程安全约束:
    - TLSCurrentArena 只由当前线程读写, 无竞争
    - FPoolLock 保护全局池的 Push/Pop
    - DrainTLS 将 Arena 从 TLS 移回全局池

  性能目标:
    - 热路径 Alloc: ~2ns (等同裸 TLocalArena.AllocFast)
    - Pool miss: ~100ns (一次 lock/unlock + pointer write)
    - Arena new: ~1μs (一次 GetMem)
******************************************************************************}
unit nextpas.core.mem.arena.thread;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.mutex;

type
  {** Thread-Local Arena 配置 }
  TThreadArenaConfig = record
    ArenaCapacity: SizeUInt;   { 每线程 Arena 容量, 0 = 默认 1MB }
    MaxPoolSize: Integer;      { 全局池最大 Arena 数, 0 = 默认 8 }
  end;

  {** Thread-Local Arena 管理器
   *
   *  管理线程 Arena 池。每线程通过 threadvar 持有独立 Arena，
   *  分配零锁；线程退出时 Arena 归还全局池供其他线程复用。
   *
   *  使用模式:
   *    var LMgr: TThreadArenaManager;
   *    LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
   *    try
   *      // 每线程:
   *      var LArena := LMgr.Get;
   *      LP := LArena.AllocFast(64);
   *      // ... 使用 LP ...
   *      LMgr.DrainTLS;  // 线程结束前归还
   *    finally
   *      LMgr.Free;
   *    end;
   *}
  {**
 * TThreadArenaManager - Thread-local arena manager with pool recycling
 *
 * @desc 管理线程本地 Arena 的创建和回收，使用池化减少分配开销。
 *
 * @warning 当前限制：每个线程只支持一个活跃的 TThreadArenaManager 实例。
 *          如果创建第二个 manager，GActiveManager 被覆盖，第一个 manager 的
 *          线程退出回调将无法正确归还 arena。
 *
 * @see TThreadArena
 *}
TThreadArenaManager = class
  private
    FConfig: TThreadArenaConfig;
    FPool: array of TLocalArena;
    FPoolCount: Integer;
    FPoolLock: TMemMutex;
    FTotalCreated: Integer;
    FTotalRecycled: Integer;
    FDead: LongBool;
    FTlsCleanupRegistered: Boolean;  { 是否已注册 pthread/Fls thread-exit cleanup }
    function PopFromPool: TLocalArena;
    procedure PushToPool(AArena: TLocalArena);
    {** 只归还 Arena 到池, 不清 TLS manager (供跨 manager 切换时调用) }
    procedure DrainArenaOnly;
  public
    constructor Create(const AConfig: TThreadArenaConfig);
    destructor Destroy; override;

    {** 获取当前线程的 Arena。首次调用从池或新建分配。 }
    function Get: TLocalArena;

    {** 将当前线程的 Arena 归还到全局池。线程退出前必须调用。 }
    procedure DrainTLS;

    {** 当前线程是否有 Arena (查询 TLS, 不创建) }
    function HasArena: Boolean;

    {** 全局池中空闲 Arena 数量 }
    function PoolSize: Integer;
    {** 已创建的 Arena 总数 }
    function TotalCreated: Integer;
    {** 已回收到池中的 Arena 总数 }
    function TotalRecycled: Integer;
  end;

  {** 轻量线程 Arena 句柄 (record, 1 pointer 大小)
   *
   *  TThreadArenaManager.Get 返回此 record。
   *  直接调用方法即可, 内部委托给 TLS Arena。
   *}
  TThreadArena = record
  private
    FArena: TLocalArena;
  public
    {** 从 TLocalArena 创建 TThreadArena 句柄 }
    class function Create(AArena: TLocalArena): TThreadArena; static;

    {** 从 Arena 分配 ASize 字节 }
    function Alloc(ASize: SizeUInt): Pointer; inline;
    {** 从 Arena 分配 ASize 字节并清零 }
    function AllocZeroed(ASize: SizeUInt): Pointer;
    {** 从 Arena 对齐分配 }
    function AllocAligned(ASize, AAlign: SizeUInt): Pointer;
    {** 快速分配 (DEBUG Assert 保护, Release 零分支) }
    function AllocFast(ASize: SizeUInt): Pointer; inline;
    {** 快速对齐分配 }
    function AllocAlignedFast(ASize, AAlign: SizeUInt): Pointer; inline;

    {** 保存当前位置标记 }
    function SaveMark: TArenaMark;
    {** 恢复到标记位置 }
    procedure RestoreToMark(AMark: TArenaMark);
    {** 重置 Arena (保留 buffer, 清零 offset) }
    procedure Reset;

    {** 已使用字节数 }
    function UsedSize: SizeUInt;
    {** 峰值使用量 }
    function PeakUsed: SizeUInt;

    {** 底层 TLocalArena 实例 (高级用法) }
    property Arena: TLocalArena read FArena;
  end;

function DefaultThreadArenaConfig: TThreadArenaConfig;

implementation

const
  DEFAULT_ARENA_CAPACITY = 1024 * 1024;  { 1MB }
  DEFAULT_MAX_POOL_SIZE  = 8;

threadvar
  TLSCurrentArena: TLocalArena;
  TLSCurrentManager: Pointer;  { TThreadArenaManager 实例, 用于检测 manager 切换 }

{ --- Thread-exit cleanup ---
  UNIX: pthread TLS key destructor. Windows: FlsCallback.
  When a thread exits, the callback returns the arena to the manager's pool.
  Each TThreadArenaManager instance creates its own key/callback. }

type
  TThreadExitProc = procedure(AData: Pointer); cdecl;

{$IFDEF UNIX}
var
  GThreadArenaCleanupKey: QWord;  { pthread_key_t }

function pthread_key_create(var AKey: QWord;
  ADestructor: TThreadExitProc): Integer; cdecl; external 'c' name 'pthread_key_create';
function pthread_key_delete(AKey: QWord): Integer; cdecl; external 'c' name 'pthread_key_delete';
function pthread_setspecific(AKey: QWord; AValue: Pointer): Integer; cdecl; external 'c' name 'pthread_setspecific';
{$ENDIF}

{$IFDEF MSWINDOWS}
type
  TFlsCallback = procedure(lpFlsData: Pointer); stdcall;
  TFlsDWord = UInt32;
  TFlsBool = LongBool;
var
  GThreadArenaCleanupIndex: TFlsDWord;

function FlsAlloc(lpCallback: TFlsCallback): TFlsDWord; stdcall; external 'kernel32.dll' name 'FlsAlloc';
function FlsFree(dwFlsIndex: TFlsDWord): TFlsBool; stdcall; external 'kernel32.dll' name 'FlsFree';
function FlsSetValue(dwFlsIndex: TFlsDWord; lpFlsData: Pointer): TFlsBool; stdcall; external 'kernel32.dll' name 'FlsSetValue';
{$ENDIF}

{ Global manager pointer for the cleanup callback to find the owning manager.
  Only one active TThreadArenaManager per thread is supported (matching the
  TLSCurrentManager design). The cleanup callback reads TLSCurrentManager. }
var
  GActiveManager: Pointer;

procedure ThreadArenaCleanup(AData: Pointer); cdecl;
var
  LMgr: TThreadArenaManager;
begin
  { AData is non-nil sentinel; real manager is in TLSCurrentManager }
  LMgr := TThreadArenaManager(TLSCurrentManager);
  if (LMgr <> nil) and (LMgr = TThreadArenaManager(GActiveManager)) then
  begin
    if TLSCurrentArena <> nil then
    begin
      LMgr.PushToPool(TLSCurrentArena);
      TLSCurrentArena := nil;
      TLSCurrentManager := nil;
    end;
  end;
end;

{$IFDEF MSWINDOWS}
procedure ThreadArenaFlsCallback(lpFlsData: Pointer); stdcall;
begin
  ThreadArenaCleanup(lpFlsData);
end;
{$ENDIF}

function DefaultThreadArenaConfig: TThreadArenaConfig;
begin
  Result.ArenaCapacity := DEFAULT_ARENA_CAPACITY;
  Result.MaxPoolSize := DEFAULT_MAX_POOL_SIZE;
end;

{ ---------------------------------------------------------------------------
  TThreadArenaManager
  --------------------------------------------------------------------------- }

constructor TThreadArenaManager.Create(const AConfig: TThreadArenaConfig);
begin
  inherited Create;
  FConfig := AConfig;
  if FConfig.ArenaCapacity = 0 then
    FConfig.ArenaCapacity := DEFAULT_ARENA_CAPACITY;
  if FConfig.MaxPoolSize <= 0 then
    FConfig.MaxPoolSize := DEFAULT_MAX_POOL_SIZE;
  FPool := nil;
  FPoolCount := 0;
  FPoolLock.Init;
  FTotalCreated := 0;
  FTotalRecycled := 0;
  FDead := False;
  FTlsCleanupRegistered := True;
  GActiveManager := Pointer(Self);
end;

destructor TThreadArenaManager.Destroy;
var
  I: Integer;
begin
  { 先回收当前线程 Arena }
  DrainTLS;
  { 标记即将销毁 — 冷路径 DrainArenaOnly 检查此标志避免 push 到死亡 manager }
  FDead := True;
  { 释放池中所有 Arena }
  FPoolLock.Acquire;
  try
    for I := 0 to FPoolCount - 1 do
      FPool[I].Free;
    FPoolCount := 0;
    FPool := nil;
  finally
    FPoolLock.Release;
  end;
  FPoolLock.Done;
  if FTlsCleanupRegistered and (GActiveManager = Pointer(Self)) then
    GActiveManager := nil;
  inherited Destroy;
end;

function TThreadArenaManager.PopFromPool: TLocalArena;
begin
  Result := nil;
  FPoolLock.Acquire;
  try
    if FPoolCount > 0 then begin
      Dec(FPoolCount);
      Result := FPool[FPoolCount];
      FPool[FPoolCount] := nil;
    end;
  finally
    FPoolLock.Release;
  end;
end;

procedure TThreadArenaManager.PushToPool(AArena: TLocalArena);
begin
  FPoolLock.Acquire;
  try
    if FPoolCount < Length(FPool) then begin
      FPool[FPoolCount] := AArena;
      Inc(FPoolCount);
      Inc(FTotalRecycled);
    end
    else if FPoolCount < FConfig.MaxPoolSize then begin
      SetLength(FPool, FPoolCount + 1);
      FPool[FPoolCount] := AArena;
      Inc(FPoolCount);
      Inc(FTotalRecycled);
    end
    else begin
      { 池已满, 直接释放 }
      AArena.Free;
    end;
  finally
    FPoolLock.Release;
  end;
end;

function TThreadArenaManager.Get: TLocalArena;
begin
  { 热路径: TLS 命中 且 manager 匹配 }
  if TLSCurrentManager = Pointer(Self) then begin
    Result := TLSCurrentArena;
    if Result <> nil then
      Exit;
  end;

  { 冷路径: manager 不匹配或无 Arena → 归还旧 Arena 给原 manager }
  if TLSCurrentArena <> nil then begin
    if (TLSCurrentManager <> nil) and
       (not TThreadArenaManager(TLSCurrentManager).FDead) then
      TThreadArenaManager(TLSCurrentManager).DrainArenaOnly
    else
      TLSCurrentArena.Free;
    TLSCurrentArena := nil;
    TLSCurrentManager := nil;
  end;

  { 从池中取 }
  Result := PopFromPool;
  if Result <> nil then begin
    Result.Reset;
    TLSCurrentArena := Result;
    TLSCurrentManager := Pointer(Self);
    {$IFDEF UNIX}
    if FTlsCleanupRegistered then
      pthread_setspecific(GThreadArenaCleanupKey, Pointer(1));
    {$ENDIF}
    {$IFDEF MSWINDOWS}
    if FTlsCleanupRegistered then
      FlsSetValue(GThreadArenaCleanupIndex, Pointer(1));
    {$ENDIF}
    Exit;
  end;

  { 最冷路径: 新建 }
  Result := TLocalArena.Create(FConfig.ArenaCapacity);
  InterLockedIncrement(FTotalCreated);
  TLSCurrentArena := Result;
  TLSCurrentManager := Pointer(Self);
  {$IFDEF UNIX}
  if FTlsCleanupRegistered then
    pthread_setspecific(GThreadArenaCleanupKey, Pointer(1));
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  if FTlsCleanupRegistered then
    FlsSetValue(GThreadArenaCleanupIndex, Pointer(1));
  {$ENDIF}
end;

procedure TThreadArenaManager.DrainTLS;
var
  LArena: TLocalArena;
begin
  if TLSCurrentManager <> Pointer(Self) then
    Exit;
  LArena := TLSCurrentArena;
  TLSCurrentArena := nil;
  TLSCurrentManager := nil;
  if LArena = nil then
    Exit;
  PushToPool(LArena);
end;

procedure TThreadArenaManager.DrainArenaOnly;
var
  LArena: TLocalArena;
begin
  LArena := TLSCurrentArena;
  TLSCurrentArena := nil;
  TLSCurrentManager := nil;
  if LArena = nil then
    Exit;
  PushToPool(LArena);
end;

function TThreadArenaManager.HasArena: Boolean;
begin
  Result := (TLSCurrentManager = Pointer(Self)) and (TLSCurrentArena <> nil);
end;

function TThreadArenaManager.PoolSize: Integer;
begin
  FPoolLock.Acquire;
  try
    Result := FPoolCount;
  finally
    FPoolLock.Release;
  end;
end;

function TThreadArenaManager.TotalCreated: Integer;
begin
  Result := FTotalCreated;
end;

function TThreadArenaManager.TotalRecycled: Integer;
begin
  Result := FTotalRecycled;
end;

{ ---------------------------------------------------------------------------
  TThreadArena
  --------------------------------------------------------------------------- }

class function TThreadArena.Create(AArena: TLocalArena): TThreadArena;
begin
  Result.FArena := AArena;
end;

function TThreadArena.Alloc(ASize: SizeUInt): Pointer;
begin
  Result := FArena.Alloc(ASize);
end;

function TThreadArena.AllocZeroed(ASize: SizeUInt): Pointer;
begin
  Result := FArena.AllocZeroed(ASize);
end;

function TThreadArena.AllocAligned(ASize, AAlign: SizeUInt): Pointer;
begin
  Result := FArena.AllocAligned(ASize, AAlign);
end;

function TThreadArena.AllocFast(ASize: SizeUInt): Pointer;
begin
  Result := FArena.AllocFast(ASize);
end;

function TThreadArena.AllocAlignedFast(ASize, AAlign: SizeUInt): Pointer;
begin
  Result := FArena.AllocAlignedFast(ASize, AAlign);
end;

function TThreadArena.SaveMark: TArenaMark;
begin
  Result := FArena.SaveMark;
end;

procedure TThreadArena.RestoreToMark(AMark: TArenaMark);
begin
  FArena.RestoreToMark(AMark);
end;

procedure TThreadArena.Reset;
begin
  FArena.Reset;
end;

function TThreadArena.UsedSize: SizeUInt;
begin
  Result := FArena.UsedSize;
end;

function TThreadArena.PeakUsed: SizeUInt;
begin
  Result := FArena.PeakUsed;
end;

initialization
  GActiveManager := nil;
  {$IFDEF UNIX}
  GThreadArenaCleanupKey := 0;
  pthread_key_create(GThreadArenaCleanupKey, @ThreadArenaCleanup);
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  GThreadArenaCleanupIndex := FlsAlloc(@ThreadArenaFlsCallback);
  {$ENDIF}

finalization
  GActiveManager := nil;
  {$IFDEF UNIX}
  if GThreadArenaCleanupKey <> 0 then
    pthread_key_delete(GThreadArenaCleanupKey);
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  if GThreadArenaCleanupIndex <> 0 then
    FlsFree(GThreadArenaCleanupIndex);
  {$ENDIF}

end.
