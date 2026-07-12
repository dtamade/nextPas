unit nextpas.core.lockfree.countdown;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  {** @desc 并发倒计时闩（CountDownLatch）
    @details 类似 Go sync.WaitGroup，等待 N 个事件完成。
      初始计数为 N，每个 Done 将计数减 1。
      Wait 阻塞直到计数归零。
      适用于：等待一组 goroutine 完成、扇出-汇聚模式。
  }
  TCountDownLatch = class
  private
    FCount: Int64;
    FClosed: Int32;
  public
    constructor Create(const AInitialCount: Int64);
    destructor Destroy; override;
    procedure Done;
    procedure DoneN(const AN: Int64);
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function GetCount: Int64; inline;
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

constructor TCountDownLatch.Create(const AInitialCount: Int64);
begin
  if AInitialCount < 0 then
    raise EArgumentError.Create('TCountDownLatch: initial count must be >= 0');
  inherited Create;
  FCount := AInitialCount;
  FClosed := 0;
end;

procedure TCountDownLatch.Done;
var
  LOld: Int64;
begin
  repeat
    LOld := AtomicLoad64(FCount, moAcquire);
    if LOld <= 0 then
      Exit;
  until AtomicCompareExchange64(FCount, LOld, LOld - 1, moRelease) = LOld;
end;

procedure TCountDownLatch.DoneN(const AN: Int64);
var
  LOld: Int64;
  LNew: Int64;
begin
  if AN <= 0 then
    raise EArgumentError.Create('TCountDownLatch.DoneN: N must be > 0');
  repeat
    LOld := AtomicLoad64(FCount, moAcquire);
    if LOld <= 0 then
      Exit;
    if LOld > AN then
      LNew := LOld - AN
    else
      LNew := 0;
  until AtomicCompareExchange64(FCount, LOld, LNew, moRelease) = LOld;
end;

procedure TCountDownLatch.Wait;
begin
  while AtomicLoad64(FCount, moAcquire) > 0 do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit;
    CpuPause;
  end;
end;

function TCountDownLatch.WaitTimeout(const ATimeoutNs: Int64): Boolean;
var
  LStart: TInstant;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TCountDownLatch.WaitTimeout: timeout must be > 0');
  LStart := TInstant.Now;
  while AtomicLoad64(FCount, moAcquire) > 0 do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
      Exit(False);
    CpuPause;
  end;
  Result := True;
end;

function TCountDownLatch.GetCount: Int64; inline;
begin
  Result := AtomicLoad64(FCount, moAcquire);
end;

procedure TCountDownLatch.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

destructor TCountDownLatch.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TCountDownLatch.IsClosed: Boolean; inline;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
