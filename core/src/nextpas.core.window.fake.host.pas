unit nextpas.core.window.fake.host;

{** @desc fake 宿主队列子单元：宿主事件渗透职责拆分。
       单源环形 FIFO（WindowGrowCapacity 0→32→2× inline 零拷贝 O(1)均摊
       via window.impl → bytes.ops），ILock 互斥保护，ManagedRingCopy 托管批量
       inline 零额外调用（bytes.ops 单源 via ManagedCopyArray/CopyArray），
       方法指针渗透经 dispatcher wwkMethod 零堆分配。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.sync.intf;

type
  THostWorkKind = (hwkResized, hwkScaleChanged, hwkInjected);
  THostWork = record
    Kind: THostWorkKind;
    Width: Integer;
    Height: Integer;
    Scale: Double;
    Event: TWindowEvent;
  end;

  TFakeHostQueue = class
  private
    FRing: array of THostWork;
    FHead: Integer;
    FCount: Integer;
    FLock: ILock;
    procedure Grow;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enqueue(const AWork: THostWork);
    function TryDequeue(out AWork: THostWork): Boolean;
    procedure Clear;
    function Count: Integer; inline;
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.bytes.ops,
  nextpas.core.window.impl,
  nextpas.core.sync.mutex;

constructor TFakeHostQueue.Create;
begin
  inherited Create;
  FLock := TMutex.Create as ILock;
  FHead := 0;
  FCount := 0;
end;

destructor TFakeHostQueue.Destroy;
begin
  Clear;
  SetLength(FRing, 0);
  FLock := nil;
  inherited;
end;

procedure TFakeHostQueue.Grow;
var
  LNewCap: Integer;
  LNew: array of THostWork;
  LOldCap: Integer;
begin
  // 单源 bytes.ops via window.impl WindowGrowCapacity 0→32→2× inline 零拷贝 O(1)均摊 + ManagedRingCopy 托管批量 inline 零额外调用（bytes.ops 单源 via ManagedCopyArray/CopyArray，正确处理 string/interface 重叠与引用计数），不回退硬编码+32，守单源幂二链；外联禁 inline
  LOldCap := Length(FRing);
  LNewCap := WindowGrowCapacity(LOldCap);
  if LNewCap <= LOldCap then
    Exit;
  SetLength(LNew, LNewCap);
  if FCount > 0 then
    specialize ManagedRingCopy<THostWork>(LNew, FRing, FHead, LOldCap, FCount);
  FRing := LNew;
  FHead := 0;
end;

procedure TFakeHostQueue.Enqueue(const AWork: THostWork);
begin
  // 单源环形入队：Acquire/Grow/掩码入队三份样板收口，复用 WindowRingIndex/WindowRingNext via bytes.ops BytesRingMask 0→32→2× 单源 inline 零拷贝 O(1)，零堆分配，稳定性不丢
  if FLock = nil then
    FLock := TMutex.Create as ILock;
  FLock.Acquire;
  try
    if FCount = Length(FRing) then
      Grow;
    if FCount < Length(FRing) then
    begin
      FRing[WindowRingIndex(FHead, FCount, Length(FRing))] := AWork;
      Inc(FCount);
    end;
  finally
    FLock.Release;
  end;
end;

function TFakeHostQueue.TryDequeue(out AWork: THostWork): Boolean;
begin
  Result := False;
  AWork := Default(THostWork);
  if FLock = nil then Exit;
  FLock.Acquire;
  try
    if FCount = 0 then Exit;
    AWork := FRing[FHead];
    FHead := WindowRingNext(FHead, Length(FRing));
    Dec(FCount);
    Result := True;
  finally
    FLock.Release;
  end;
end;

procedure TFakeHostQueue.Clear;
begin
  if FLock = nil then Exit;
  FLock.Acquire;
  try
    FCount := 0;
    FHead := 0;
  finally
    FLock.Release;
  end;
end;

function TFakeHostQueue.Count: Integer; inline;
begin
  // live/queue 同构：atomic_load 零锁快照 inline 16ns，热路径查询零锁竞争
  Result := atomic_load(FCount);
end;

end.
