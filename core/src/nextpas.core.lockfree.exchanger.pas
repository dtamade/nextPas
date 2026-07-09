unit nextpas.core.lockfree.exchanger;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeExchangeResult = (exExchanged, exClosed, exTimeout);

  {** @desc 并发交换器（Exchanger）
    @details 两个线程交换值的同步点。
      线程 A 调用 Exchange(AValue) 阻塞等待，线程 B 调用 Exchange(BValue) 阻塞等待。
      当两方都到达时，交换值并返回对方的值。
      适用场景：双线程管道、生产者-消费者一对一通信。
  }
  generic TExchangerImpl<T> = class
  private
    FSlot0Value: T;
    FSlot0State: Int32;  // 0=empty, 1=waiting, 2=ready
    FSlot1Value: T;
    FSlot1State: Int32;
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
  FSlot0State := 0;
  FSlot1State := 0;
  FClosed := 0;
end;

function TExchangerImpl.Exchange(const AValue: T; out AOutValue: T): TLockFreeExchangeResult;
var
  LOldState: Int32;
begin
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(exClosed);

    // Try to be the first thread: offer in slot 0, take from slot 1
    if AtomicCompareExchange32(FSlot0State, 0, 1) = 0 then
    begin
      FSlot0Value := AValue;
      AtomicStore32(FSlot0State, 2, moRelease);

      // Wait for slot 1 to become ready
      while AtomicLoad32(FSlot1State, moAcquire) <> 2 do
      begin
        if AtomicLoad32(FClosed, moAcquire) <> 0 then
        begin
          AtomicStore32(FSlot0State, 0, moRelease);
          Exit(exClosed);
        end;
        CpuPause;
      end;

      AOutValue := FSlot1Value;
      AtomicStore32(FSlot1State, 0, moRelease);
      Exit(exExchanged);
    end;

    // Try to be the second thread: take from slot 0, offer in slot 1
    if AtomicCompareExchange32(FSlot0State, 2, 0) = 2 then
    begin
      AOutValue := FSlot0Value;

      // Store our value in slot 1
      while True do
      begin
        if AtomicLoad32(FClosed, moAcquire) <> 0 then
          Exit(exClosed);
        if AtomicCompareExchange32(FSlot1State, 0, 1) = 0 then
          Break;
        CpuPause;
      end;

      FSlot1Value := AValue;
      AtomicStore32(FSlot1State, 2, moRelease);
      Exit(exExchanged);
    end;

    CpuPause;
  end;
end;

function TExchangerImpl.ExchangeTimeout(const AValue: T; out AOutValue: T; const ATimeoutNs: Int64): TLockFreeExchangeResult;
var
  LStart: TInstant;
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

    // Try to be the first thread
    if AtomicCompareExchange32(FSlot0State, 0, 1) = 0 then
    begin
      FSlot0Value := AValue;
      AtomicStore32(FSlot0State, 2, moRelease);

      while AtomicLoad32(FSlot1State, moAcquire) <> 2 do
      begin
        if AtomicLoad32(FClosed, moAcquire) <> 0 then
        begin
          AtomicStore32(FSlot0State, 0, moRelease);
          Exit(exClosed);
        end;
        if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
        begin
          AtomicStore32(FSlot0State, 0, moRelease);
          Exit(exTimeout);
        end;
        CpuPause;
      end;

      AOutValue := FSlot1Value;
      AtomicStore32(FSlot1State, 0, moRelease);
      Exit(exExchanged);
    end;

    // Try to be the second thread
    if AtomicCompareExchange32(FSlot0State, 2, 0) = 2 then
    begin
      AOutValue := FSlot0Value;

      while True do
      begin
        if AtomicLoad32(FClosed, moAcquire) <> 0 then
          Exit(exClosed);
        if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
          Exit(exTimeout);
        if AtomicCompareExchange32(FSlot1State, 0, 1) = 0 then
          Break;
        CpuPause;
      end;

      FSlot1Value := AValue;
      AtomicStore32(FSlot1State, 2, moRelease);
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
