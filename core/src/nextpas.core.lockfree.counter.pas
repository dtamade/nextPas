unit nextpas.core.lockfree.counter;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  {** @desc 并发计数器
    @details 基于原子操作的高性能计数器。
      支持 Increment/Decrement/Add/Sub/Load/Store/Reset。
      适用于统计、计数等场景。
  }
  TConcurrentCounter = class
  private
    FValue: Int64;
    FClosed: Int32;
  public
    constructor Create(const AInitialValue: Int64 = 0);
    function Increment: Int64; inline;
    function Decrement: Int64; inline;
    function Add(const AValue: Int64): Int64; inline;
    function Sub(const AValue: Int64): Int64; inline;
    function Load: Int64; inline;
    procedure Store(const AValue: Int64);
    procedure Reset;
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

implementation

uses
  nextpas.core.atomic;

constructor TConcurrentCounter.Create(const AInitialValue: Int64);
begin
  inherited Create;
  FValue := AInitialValue;
  FClosed := 0;
end;

function TConcurrentCounter.Increment: Int64; inline;
begin
  Result := AtomicFetchAdd64(FValue, 1, moRelaxed) + 1;
end;

function TConcurrentCounter.Decrement: Int64; inline;
begin
  Result := AtomicFetchSub64(FValue, 1, moRelaxed) - 1;
end;

function TConcurrentCounter.Add(const AValue: Int64): Int64; inline;
begin
  Result := AtomicFetchAdd64(FValue, AValue, moRelaxed) + AValue;
end;

function TConcurrentCounter.Sub(const AValue: Int64): Int64; inline;
begin
  Result := AtomicFetchSub64(FValue, AValue, moRelaxed) - AValue;
end;

function TConcurrentCounter.Load: Int64; inline;
begin
  Result := AtomicLoad64(FValue, moRelaxed);
end;

procedure TConcurrentCounter.Store(const AValue: Int64);
begin
  AtomicStore64(FValue, AValue, moRelaxed);
end;

procedure TConcurrentCounter.Reset;
begin
  AtomicStore64(FValue, 0, moRelaxed);
end;

procedure TConcurrentCounter.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentCounter.IsClosed: Boolean; inline;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
