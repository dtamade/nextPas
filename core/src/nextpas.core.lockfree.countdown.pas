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
    LOld := atomic_load_64(FCount, mo_acquire);
    if LOld <= 0 then
      Exit;
  until atomic_compare_exchange_strong_64(FCount, LOld, LOld - 1, mo_release, mo_relaxed);
end;

procedure TCountDownLatch.DoneN(const AN: Int64);
var
  LOld: Int64;
  LNew: Int64;
begin
  if AN <= 0 then
    raise EArgumentError.Create('TCountDownLatch.DoneN: N must be > 0');
  repeat
    LOld := atomic_load_64(FCount, mo_acquire);
    if LOld <= 0 then
      Exit;
    if LOld > AN then
      LNew := LOld - AN
    else
      LNew := 0;
  until atomic_compare_exchange_strong_64(FCount, LOld, LNew, mo_release, mo_relaxed);
end;

procedure TCountDownLatch.Wait;
begin
  while atomic_load_64(FCount, mo_acquire) > 0 do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
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
  while atomic_load_64(FCount, mo_acquire) > 0 do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
      Exit(False);
    CpuPause;
  end;
  Result := True;
end;

function TCountDownLatch.GetCount: Int64; inline;
begin
  Result := atomic_load_64(FCount, mo_acquire);
end;

procedure TCountDownLatch.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TCountDownLatch.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TCountDownLatch.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
