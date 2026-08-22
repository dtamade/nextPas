unit nextpas.core.lockfree.rcu;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

const
  RCU_MAX_READERS = 64;
  RCU_GRACE_PERIOD_SPIN = 1000;

type
  {** @desc RCU 读侧保护 }
  TRcuGuard = record
    Domain: Pointer;
    ReaderIndex: Int32;
  end;

  {** @desc RCU 域
    @details 管理读侧临界区和宽限期。
      读操作: 无锁 (只读 + Acquire barrier)。
      写操作: Copy → Modify → Publish (atomic swap) → 等待宽限期 → Free old。
  }
  TRcuDomain = class
  private
    FReaderCounts: array[0..RCU_MAX_READERS - 1] of Int64;
    FNextReader: Int32;
    FClosed: Int32;
  public
    constructor Create;
    destructor Destroy; override;
    procedure EnterRead(out AGuard: TRcuGuard);
    procedure ExitRead(var AGuard: TRcuGuard);
    procedure Synchronize;
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

  { Internal heap-allocated node for COW }
  PRcuValueNode = ^TRcuValueNode;
  TRcuValueNode = record
    ValueSize: SizeInt;
  end;

function RcuAllocNode(ASize: SizeInt): PRcuValueNode;
procedure RcuFreeNode(ANode: PRcuValueNode);
procedure RcuCopyToNode(ANode: PRcuValueNode; const ASource; ASize: SizeInt);
procedure RcuCopyFromNode(ANode: PRcuValueNode; var ADest; ASize: SizeInt);

type
  {** @desc RCU 保护的泛型发布者
    @details 读操作无锁，写操作 Copy-on-Write。
      适用于读多写少的场景。
  }
  generic TRcuPublisherImpl<T> = class
  private
    FDomain: TRcuDomain;
    FCurrentNode: PRcuValueNode;
    FClosed: Int32;
    procedure AllocAndPublish(const AValue: T);
  public
    constructor Create(const AInitialValue: T);
    destructor Destroy; override;
    function Read(out AValue: T): Boolean;
    procedure Update(const AValue: T);
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

  generic TRcuPublisher<T> = class(specialize TRcuPublisherImpl<T>)
  end;

implementation

uses
  nextpas.core.mem,
  nextpas.core.errors,
  nextpas.core.atomic;

var
  GReaderCounter: Int32;

threadvar
  GMyReaderId: Int32;

function RcuAllocNode(ASize: SizeInt): PRcuValueNode;
begin
  Result := GetMem(SizeOf(TRcuValueNode) + ASize);
  Result^.ValueSize := ASize;
end;

procedure RcuFreeNode(ANode: PRcuValueNode);
begin
  if ANode <> nil then
    FreeMem(ANode, SizeOf(TRcuValueNode) + ANode^.ValueSize);
end;

procedure RcuCopyToNode(ANode: PRcuValueNode; const ASource; ASize: SizeInt);
begin
  Move(ASource, (PByte(ANode) + SizeOf(TRcuValueNode))^, ASize);
end;

procedure RcuCopyFromNode(ANode: PRcuValueNode; var ADest; ASize: SizeInt);
begin
  Move((PByte(ANode) + SizeOf(TRcuValueNode))^, ADest, ASize);
end;

{ TRcuDomain }

constructor TRcuDomain.Create;
var
  LI: Integer;
begin
  inherited Create;
  FNextReader := 0;
  FClosed := 0;
  for LI := 0 to RCU_MAX_READERS - 1 do
  begin
    FReaderCounts[LI] := 0;
  end;
end;

destructor TRcuDomain.Destroy;
begin
  inherited Destroy;
end;

procedure TRcuDomain.EnterRead(out AGuard: TRcuGuard);
var
  LIdx: Int32;
begin
  if GMyReaderId = 0 then
    GMyReaderId := atomic_fetch_add(GReaderCounter, 1, mo_relaxed) + 1;
  LIdx := (GMyReaderId - 1) mod RCU_MAX_READERS;
  AGuard.Domain := Self;
  AGuard.ReaderIndex := LIdx;
  atomic_fetch_add_64(FReaderCounts[LIdx], 1, mo_acquire);
end;

procedure TRcuDomain.ExitRead(var AGuard: TRcuGuard);
var
  LCount: Int64;
begin
  if (AGuard.Domain <> Pointer(Self)) or (AGuard.ReaderIndex < 0) or
     (AGuard.ReaderIndex >= RCU_MAX_READERS) then
    Exit;
  repeat
    LCount := atomic_load_64(FReaderCounts[AGuard.ReaderIndex], mo_acquire);
    if LCount <= 0 then
      Break;
  until atomic_compare_exchange_strong_64(FReaderCounts[AGuard.ReaderIndex], LCount, LCount - 1, mo_release, mo_relaxed);
  AGuard.Domain := nil;
  AGuard.ReaderIndex := -1;
end;

procedure TRcuDomain.Synchronize;
var
  LI: Integer;
  LSpin: Integer;
  LDone: Boolean;
begin
  LSpin := 0;
  while True do
  begin
    LDone := True;
    for LI := 0 to RCU_MAX_READERS - 1 do
    begin
      if atomic_load_64(FReaderCounts[LI], mo_acquire) > 0 then
      begin
        LDone := False;
        Break;
      end;
    end;
    if LDone then
      Exit;
    Inc(LSpin);
    if LSpin > RCU_GRACE_PERIOD_SPIN then
      ThreadSwitch
    else
      CpuPause;
  end;
end;

procedure TRcuDomain.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TRcuDomain.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

{ TRcuPublisherImpl }

procedure TRcuPublisherImpl.AllocAndPublish(const AValue: T);
var
  LNew, LOld: PRcuValueNode;
begin
  LNew := RcuAllocNode(SizeOf(T));
  RcuCopyToNode(LNew, AValue, SizeOf(T));
  LOld := PRcuValueNode(atomic_exchange(Pointer(FCurrentNode), Pointer(LNew), mo_acq_rel));
  FDomain.Synchronize;
  RcuFreeNode(LOld);
end;

constructor TRcuPublisherImpl.Create(const AInitialValue: T);
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TRcuPublisher: T must be unmanaged (no string/interface/dynarray)');
  inherited Create;
  FDomain := TRcuDomain.Create;
  FClosed := 0;
  FCurrentNode := RcuAllocNode(SizeOf(T));
  RcuCopyToNode(FCurrentNode, AInitialValue, SizeOf(T));
end;

destructor TRcuPublisherImpl.Destroy;
var
  LNode: PRcuValueNode;
begin
  LNode := PRcuValueNode(atomic_exchange(Pointer(FCurrentNode), nil, mo_acq_rel));
  RcuFreeNode(LNode);
  FDomain.Free;
  inherited Destroy;
end;

function TRcuPublisherImpl.Read(out AValue: T): Boolean;
var
  LGuard: TRcuGuard;
  LNode: PRcuValueNode;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
  begin
    AValue := Default(T);
    Exit(False);
  end;
  FDomain.EnterRead(LGuard);
  LNode := PRcuValueNode(atomic_load(Pointer(FCurrentNode), mo_acquire));
  if LNode <> nil then
    RcuCopyFromNode(LNode, AValue, SizeOf(T))
  else
    AValue := Default(T);
  FDomain.ExitRead(LGuard);
  Result := True;
end;

procedure TRcuPublisherImpl.Update(const AValue: T);
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit;
  AllocAndPublish(AValue);
end;

procedure TRcuPublisherImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
  FDomain.Close;
end;

function TRcuPublisherImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
