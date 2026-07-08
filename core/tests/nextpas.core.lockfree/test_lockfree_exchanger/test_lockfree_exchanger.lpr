program test_lockfree_exchanger;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.lockfree.exchanger,
  nextpas.core.lockfree,
  nextpas.core.platform.thread,
  nextpas.core.test;

type
  TIntExchanger = specialize TExchangerImpl<Integer>;

  TExchangeArgs = record
    Exchanger: TIntExchanger;
    ValueToSend: Integer;
    ReceivedValue: Integer;
    ExchangeResult: TLockFreeExchangeResult;
  end;
  PExchangeArgs = ^TExchangeArgs;

function ExchangeThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LArgs: PExchangeArgs;
begin
  LArgs := PExchangeArgs(AArg);
  LArgs^.ExchangeResult := LArgs^.Exchanger.Exchange(LArgs^.ValueToSend, LArgs^.ReceivedValue);
  Result := nil;
end;

procedure TestExchangerBasic;
var
  LExchanger: TIntExchanger;
  LOut: Integer;
  LResult: TLockFreeExchangeResult;
begin
  LExchanger := TIntExchanger.Create;
  try
    Check(not LExchanger.IsClosed, 'Should not be closed');

    // Close without exchange
    LExchanger.Close;
    Check(LExchanger.IsClosed, 'Should be closed');

    LResult := LExchanger.Exchange(42, LOut);
    Check(exClosed = LResult, 'Should return closed');
  finally
    LExchanger.Free;
  end;
end;

procedure TestExchangerTwoThreads;
var
  LExchanger: TIntExchanger;
  LArgs: TExchangeArgs;
  LHandle: TPlatformThreadHandle;
  LOut: Integer;
  LResult: TLockFreeExchangeResult;
  LRetVal: Pointer;
begin
  LExchanger := TIntExchanger.Create;
  try
    LArgs.Exchanger := LExchanger;
    LArgs.ValueToSend := 100;
    LArgs.ReceivedValue := 0;
    LArgs.ExchangeResult := exClosed;

    CheckEqual(Int64(0), Int64(platform_thread_create(LHandle, @ExchangeThreadProc, @LArgs)),
      'thread create must succeed');

    // Small delay to let thread start and offer value
    Sleep(10);

    // Our exchange
    LResult := LExchanger.Exchange(200, LOut);
    Check(exExchanged = LResult, 'Should exchange');
    CheckEqual(100, LOut, 'Should receive thread value');

    CheckEqual(Int64(0), Int64(platform_thread_join(LHandle, LRetVal)),
      'thread join must succeed');

    Check(exExchanged = LArgs.ExchangeResult, 'Thread should exchange');
    CheckEqual(200, LArgs.ReceivedValue, 'Thread should receive our value');
  finally
    LExchanger.Free;
  end;
end;

procedure TestExchangerTimeout;
var
  LExchanger: TIntExchanger;
  LOut: Integer;
  LResult: TLockFreeExchangeResult;
begin
  LExchanger := TIntExchanger.Create;
  try
    // Timeout with no partner
    LResult := LExchanger.ExchangeTimeout(42, LOut, 1000000); // 1ms
    Check(exTimeout = LResult, 'Should timeout');
  finally
    LExchanger.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_exchanger ===');
  WriteLn;

  TestExchangerBasic;
  WriteLn('  + Basic close');

  TestExchangerTwoThreads;
  WriteLn('  + Two thread exchange');

  TestExchangerTimeout;
  WriteLn('  + Timeout');

  WriteLn;
  WriteLn('All exchanger tests passed!');
end.
