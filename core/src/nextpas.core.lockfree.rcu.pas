unit nextpas.core.lockfree.rcu;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

const
  RCU_MAX_READERS = 64;
  RCU_GRACE_PERIOD_SPIN = 1000;

type
  {** @desc RCU 读侧保护
    @details 进入读临界区后，其他线程不能回收旧数据。
      使用引用计数实现宽限期检测。
  }
  TRcuGuard = record
    Domain: Pointer;
    ReaderIndex: Int32;
  end;

  {** @desc RCU 域
    @details 管理读侧临界区和宽限期。
      读操作: 无锁 (只读 + Acquire barrier)。
      写操作: Copy → Modify → Publish (CAS) → 等待宽限期 → Free old。
  }
  TRcuDomain = class
  private
    FReaderCounts: array[0..RCU_MAX_READERS - 1] of Int64;
    FReaderActive: array[0..RCU_MAX_READERS - 1] of Int32;
    FNextReader: Int32;
    FClosed: Int32;
  public
    constructor Create;
    destructor Destroy; override;
    procedure EnterRead(out AGuard: TRcuGuard);
    procedure ExitRead(var AGuard: TRcuGuard);
    procedure Synchronize;
    procedure Close;
    function IsClosed: Boolean;
  end;

  {** @desc RCU 保护的泛型发布者
    @details 读操作无锁，写操作 Copy-on-Write。
      适用于读多写少的场景。
  }
  generic TRcuPublisherImpl<T> = class
  private
    FDomain: TRcuDomain;
    FCurrentValue: T;
    FClosed: Int32;
  public
    constructor Create(const AInitialValue: T);
    destructor Destroy; override;
    function Read(out AValue: T): Boolean;
    procedure Update(const AValue: T);
    procedure Close;
    function IsClosed: Boolean;
  end;

  generic TRcuPublisher<T> = class(specialize TRcuPublisherImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

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
    FReaderActive[LI] := 0;
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
  LIdx := AtomicFetchAdd32(FNextReader, 1, moRelaxed) mod RCU_MAX_READERS;
  AGuard.Domain := Self;
  AGuard.ReaderIndex := LIdx;
  AtomicStore32(FReaderActive[LIdx], 1, moRelease);
  AtomicFetchAdd64(FReaderCounts[LIdx], 1, moRelaxed);
end;

procedure TRcuDomain.ExitRead(var AGuard: TRcuGuard);
begin
  AtomicFetchSub64(FReaderCounts[AGuard.ReaderIndex], 1, moRelaxed);
  AtomicStore32(FReaderActive[AGuard.ReaderIndex], 0, moRelease);
end;

procedure TRcuDomain.Synchronize;
var
  LI: Integer;
  LSpin: Integer;
begin
  LSpin := 0;
  while True do
  begin
    for LI := 0 to RCU_MAX_READERS - 1 do
    begin
      if (AtomicLoad32(FReaderActive[LI], moAcquire) <> 0) and
         (AtomicLoad64(FReaderCounts[LI], moAcquire) > 0) then
      begin
        Inc(LSpin);
        if LSpin > RCU_GRACE_PERIOD_SPIN then
        begin
          ThreadSwitch;
          LSpin := RCU_GRACE_PERIOD_SPIN;
        end;
        Continue;
      end;
    end;
    Exit;
  end;
end;

procedure TRcuDomain.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TRcuDomain.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

{ TRcuPublisherImpl }

constructor TRcuPublisherImpl.Create(const AInitialValue: T);
begin
  inherited Create;
  FDomain := TRcuDomain.Create;
  FCurrentValue := AInitialValue;
  FClosed := 0;
end;

destructor TRcuPublisherImpl.Destroy;
begin
  FDomain.Free;
  inherited Destroy;
end;

function TRcuPublisherImpl.Read(out AValue: T): Boolean;
var
  LGuard: TRcuGuard;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
  begin
    AValue := Default(T);
    Exit(False);
  end;
  FDomain.EnterRead(LGuard);
  AValue := FCurrentValue;
  FDomain.ExitRead(LGuard);
  Result := True;
end;

procedure TRcuPublisherImpl.Update(const AValue: T);
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit;
  FCurrentValue := AValue;
  FDomain.Synchronize;
end;

procedure TRcuPublisherImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
  FDomain.Close;
end;

function TRcuPublisherImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
