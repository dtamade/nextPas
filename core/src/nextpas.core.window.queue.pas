unit nextpas.core.window.queue;

{** @desc 窗口家族共享的环形工作队列（M-band 复用提纯）。

       目的：消除 sdl2/win32/cocoa/wasm/android/uikit 6 后端
       对“互斥环形 FIFO + 32 cap 起步 + 2× 增长”样板代码的重复拷贝，
       统一并发、零分配与亲和语义，保持单点修复能力。

       设计：
       - 本单元为家族内特权共享（不经门面 re-export），仅被 `window.*` 后端 uses
       - 队列本身不感知唤醒原语（`SDL_PushEvent / PostMessage / SetEvent` 等归后端）
       - 线程安全：单锁保护头/尾/计数与环，`Drain` 逐条在锁外执行，避免持有锁回调
       - 性能：32 起步容，`Grow` 时 `Move` 环绕切片至新数组头，O(n) 仅在扩容时触发  *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf,
  nextpas.core.window.intf;

type
  TWindowQueue = class
  private
    FRing: array of TWindowProcRef;
    FHead: Integer;
    FCount: Integer;
    FLock: ILock;
    procedure Grow;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Push(AProc: TWindowProcRef); inline;
    function TryPop(out AProc: TWindowProcRef): Boolean; inline;
    procedure Drain; inline;
    function IsEmpty: Boolean; inline;
    function Count: Integer; inline;
    procedure Clear; inline;
  end;

implementation

uses
  nextpas.core.sync.mutex;

constructor TWindowQueue.Create;
begin
  inherited Create;
  FLock := TMutex.Create as ILock;
end;

destructor TWindowQueue.Destroy;
begin
  Clear;
  FLock := nil;
  inherited;
end;

procedure TWindowQueue.Grow;
var
  LNewCap, I: Integer;
  LNew: array of TWindowProcRef;
begin
  LNewCap := Length(FRing) * 2;
  if LNewCap = 0 then
    LNewCap := 32;
  SetLength(LNew, LNewCap);
  for I := 0 to FCount - 1 do
    LNew[I] := FRing[(FHead + I) mod Length(FRing)];
  FRing := LNew;
  FHead := 0;
end;

procedure TWindowQueue.Push(AProc: TWindowProcRef);
begin
  if FLock = nil then
    FLock := TMutex.Create as ILock;
  FLock.Acquire;
  try
    if FCount = Length(FRing) then
      Grow;
    FRing[(FHead + FCount) mod Length(FRing)] := AProc;
    Inc(FCount);
  finally
    FLock.Release;
  end;
end;

function TWindowQueue.TryPop(out AProc: TWindowProcRef): Boolean;
begin
  Result := False;
  AProc := nil;
  if FLock = nil then
    Exit;
  FLock.Acquire;
  try
    if FCount = 0 then
      Exit;
    AProc := FRing[FHead];
    FRing[FHead] := nil;
    FHead := (FHead + 1) mod Length(FRing);
    Dec(FCount);
    Result := True;
  finally
    FLock.Release;
  end;
end;

procedure TWindowQueue.Drain;
var
  LProc: TWindowProcRef;
begin
  while TryPop(LProc) do
  begin
    try
      if Assigned(LProc) then
        LProc();
    except
      raise;
    end;
    LProc := nil;
  end;
end;

function TWindowQueue.IsEmpty: Boolean;
begin
  if FLock = nil then
    Exit(True);
  FLock.Acquire;
  try
    Result := FCount = 0;
  finally
    FLock.Release;
  end;
end;

function TWindowQueue.Count: Integer;
begin
  if FLock = nil then
    Exit(0);
  FLock.Acquire;
  try
    Result := FCount;
  finally
    FLock.Release;
  end;
end;

procedure TWindowQueue.Clear;
var
  I: Integer;
begin
  if FLock = nil then
    Exit;
  FLock.Acquire;
  try
    for I := 0 to FCount - 1 do
      FRing[(FHead + I) mod Length(FRing)] := nil;
    FCount := 0;
    FHead := 0;
  finally
    FLock.Release;
  end;
end;

end.
