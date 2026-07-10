unit nextpas.core.lockfree.exchanger;

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
    function Exchange(const AValue: T; out AOutValue: T): TLockFreeExchangeResult;
    function ExchangeTimeout(const AValue: T; out AOutValue: T; const ATimeoutNs: Int64): TLockFreeExchangeResult;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

constructor TExchangerImpl.Create;
begin
  inherited Create;
  FState := EXCHANGER_STATE_EMPTY;
  FClosed := 0;
end;

function TExchangerImpl.Exchange(const AValue: T; out AOutValue: T): TLockFreeExchangeResult;
begin
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(exClosed);

    if AtomicCompareExchange32(FState, EXCHANGER_STATE_EMPTY, EXCHANGER_STATE_RESERVED, moAcqRel) = EXCHANGER_STATE_EMPTY then
    begin
      FOfferValue := AValue;
      AtomicStore32(FState, EXCHANGER_STATE_READY, moRelease);

      while True do
      begin
        case AtomicLoad32(FState, moAcquire) of
          EXCHANGER_STATE_COMPLETED:
            begin
              AOutValue := FReplyValue;
              AtomicStore32(FState, EXCHANGER_STATE_EMPTY, moRelease);
              Exit(exExchanged);
            end;
          EXCHANGER_STATE_READY:
            ;
        else
          raise EInvalidOperationError.Create('TExchanger.Exchange: invalid exchanger state');
        end;

        if AtomicLoad32(FClosed, moAcquire) <> 0 then
        begin
          if AtomicCompareExchange32(FState, EXCHANGER_STATE_READY, EXCHANGER_STATE_EMPTY, moAcqRel) = EXCHANGER_STATE_READY then
            Exit(exClosed);
        end;
        CpuPause;
      end;
    end;

    if AtomicCompareExchange32(FState, EXCHANGER_STATE_READY, EXCHANGER_STATE_CLAIMED, moAcqRel) = EXCHANGER_STATE_READY then
    begin
      AOutValue := FOfferValue;
      FReplyValue := AValue;
      AtomicStore32(FState, EXCHANGER_STATE_COMPLETED, moRelease);
      Exit(exExchanged);
    end;

    CpuPause;
  end;
end;

function TExchangerImpl.ExchangeTimeout(const AValue: T; out AOutValue: T; const ATimeoutNs: Int64): TLockFreeExchangeResult;
var
  LStart: TInstant;
  LState: Int32;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TExchanger.ExchangeTimeout: timeout must be > 0');
  LStart := TInstant.Now;

  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(exClosed);
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
      Exit(exTimeout);

    if AtomicCompareExchange32(FState, EXCHANGER_STATE_EMPTY, EXCHANGER_STATE_RESERVED, moAcqRel) = EXCHANGER_STATE_EMPTY then
    begin
      FOfferValue := AValue;
      AtomicStore32(FState, EXCHANGER_STATE_READY, moRelease);

      while True do
      begin
        LState := AtomicLoad32(FState, moAcquire);
        if LState = EXCHANGER_STATE_COMPLETED then
        begin
          AOutValue := FReplyValue;
          AtomicStore32(FState, EXCHANGER_STATE_EMPTY, moRelease);
          Exit(exExchanged);
        end;

        if AtomicLoad32(FClosed, moAcquire) <> 0 then
        begin
          if AtomicCompareExchange32(FState, EXCHANGER_STATE_READY, EXCHANGER_STATE_EMPTY, moAcqRel) = EXCHANGER_STATE_READY then
            Exit(exClosed);
        end;
        if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
        begin
          if AtomicCompareExchange32(FState, EXCHANGER_STATE_READY, EXCHANGER_STATE_EMPTY, moAcqRel) = EXCHANGER_STATE_READY then
            Exit(exTimeout);
        end;
        CpuPause;
      end;
    end;

    if AtomicCompareExchange32(FState, EXCHANGER_STATE_READY, EXCHANGER_STATE_CLAIMED, moAcqRel) = EXCHANGER_STATE_READY then
    begin
      AOutValue := FOfferValue;
      FReplyValue := AValue;
      AtomicStore32(FState, EXCHANGER_STATE_COMPLETED, moRelease);
      Exit(exExchanged);
    end;

    CpuPause;
  end;
end;

procedure TExchangerImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TExchangerImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
