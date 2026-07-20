unit nextpas.core.lockfree.exchanger;
{**
 * @desc Lock-free Exchanger for two-thread value exchange.
 *
 * @details Synchronization point for two threads to exchange values:
 *   - Exchange: offer value and wait for partner's value
 *   - Timeout variants for bounded waiting
 *   - Close semantics for graceful shutdown
 *
 * @concurrency Thread-safe for exactly two threads:
 *   - Exchange: threads block until both arrive
 *   - Close: safe to call from any thread
 *
 * @see Exchanger — two-thread synchronization primitive
 * @see Java Exchanger — similar exchange mechanism
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeExchangeResult = (exExchanged, exClosed, exTimeout);

const
  EXCHANGER_STATE_EMPTY = 0;
  EXCHANGER_STATE_RESERVED = 1;
  EXCHANGER_STATE_READY = 2;
  EXCHANGER_STATE_CLAIMED = 3;
  EXCHANGER_STATE_COMPLETED = 4;

type
  {** @desc 并发交换器（Exchanger）
    @details 两个线程交换值的同步点。
      线程 A 调用 Exchange(AValue) 阻塞等待，线程 B 调用 Exchange(BValue) 阻塞等待。
      当两方都到达时，交换值并返回对方的值。
      适用场景：双线程管道、生产者-消费者一对一通信。
  }
  generic TExchangerImpl<T> = class
  private
    FOfferValue: T;
    FReplyValue: T;
    FState: Int32;
    FClosed: Int32;
  public
    constructor Create;
    destructor Destroy; override;
    function Exchange(const AValue: T; out AOutValue: T): TLockFreeExchangeResult;
    function ExchangeTimeout(const AValue: T; out AOutValue: T; const ATimeoutNs: Int64): TLockFreeExchangeResult;
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

constructor TExchangerImpl.Create;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TExchanger: T must be unmanaged (no string/interface/dynarray)');
  inherited Create;
  FState := EXCHANGER_STATE_EMPTY;
  FClosed := 0;
end;

function TExchangerImpl.Exchange(const AValue: T; out AOutValue: T): TLockFreeExchangeResult;
var
  LCasExpected: Int32;
begin
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(exClosed);

    LCasExpected := EXCHANGER_STATE_EMPTY;
    if atomic_compare_exchange_strong(FState, LCasExpected, EXCHANGER_STATE_RESERVED, mo_acq_rel, mo_acquire) then
    begin
      FOfferValue := AValue;
      atomic_store(FState, EXCHANGER_STATE_READY, mo_release);

      while True do
      begin
        case atomic_load(FState, mo_acquire) of
          EXCHANGER_STATE_COMPLETED:
            begin
              AOutValue := FReplyValue;
              atomic_store(FState, EXCHANGER_STATE_EMPTY, mo_release);
              Exit(exExchanged);
            end;
          EXCHANGER_STATE_READY:
            ;
          EXCHANGER_STATE_CLAIMED:
            ;
        else
          raise EInvalidOperationError.Create('TExchanger.Exchange: invalid exchanger state');
        end;

        if atomic_load(FClosed, mo_acquire) <> 0 then
        begin
          LCasExpected := EXCHANGER_STATE_READY;
          if atomic_compare_exchange_strong(FState, LCasExpected, EXCHANGER_STATE_EMPTY, mo_acq_rel, mo_acquire) then
            Exit(exClosed);
        end;
        CpuPause;
      end;
    end;

    LCasExpected := EXCHANGER_STATE_READY;
    if atomic_compare_exchange_strong(FState, LCasExpected, EXCHANGER_STATE_CLAIMED, mo_acq_rel, mo_acquire) then
    begin
      AOutValue := FOfferValue;
      FReplyValue := AValue;
      atomic_store(FState, EXCHANGER_STATE_COMPLETED, mo_release);
      Exit(exExchanged);
    end;

    CpuPause;
  end;
end;

function TExchangerImpl.ExchangeTimeout(const AValue: T; out AOutValue: T; const ATimeoutNs: Int64): TLockFreeExchangeResult;
var
  LStart: TInstant;
  LState: Int32;
  LCasExpected: Int32;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TExchanger.ExchangeTimeout: timeout must be > 0');
  LStart := TInstant.Now;

  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(exClosed);
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
      Exit(exTimeout);

    LCasExpected := EXCHANGER_STATE_EMPTY;
    if atomic_compare_exchange_strong(FState, LCasExpected, EXCHANGER_STATE_RESERVED, mo_acq_rel, mo_acquire) then
    begin
      FOfferValue := AValue;
      atomic_store(FState, EXCHANGER_STATE_READY, mo_release);

      while True do
      begin
        LState := atomic_load(FState, mo_acquire);
        if LState = EXCHANGER_STATE_COMPLETED then
        begin
          AOutValue := FReplyValue;
          atomic_store(FState, EXCHANGER_STATE_EMPTY, mo_release);
          Exit(exExchanged);
        end;

        if atomic_load(FClosed, mo_acquire) <> 0 then
        begin
          LCasExpected := EXCHANGER_STATE_READY;
          if atomic_compare_exchange_strong(FState, LCasExpected, EXCHANGER_STATE_EMPTY, mo_acq_rel, mo_acquire) then
            Exit(exClosed);
        end;
        if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
        begin
          LCasExpected := EXCHANGER_STATE_READY;
          if atomic_compare_exchange_strong(FState, LCasExpected, EXCHANGER_STATE_EMPTY, mo_acq_rel, mo_acquire) then
            Exit(exTimeout);
        end;
        CpuPause;
      end;
    end;

    LCasExpected := EXCHANGER_STATE_READY;
    if atomic_compare_exchange_strong(FState, LCasExpected, EXCHANGER_STATE_CLAIMED, mo_acq_rel, mo_acquire) then
    begin
      AOutValue := FOfferValue;
      FReplyValue := AValue;
      atomic_store(FState, EXCHANGER_STATE_COMPLETED, mo_release);
      Exit(exExchanged);
    end;

    CpuPause;
  end;
end;

procedure TExchangerImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TExchangerImpl.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TExchangerImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
