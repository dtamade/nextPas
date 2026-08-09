{$mode objfpc}{$H+}
program test_interlocked_atomic_pass;

{ Interlocked* atomic intrinsics: statement form (walk_halt_calls) and value
  form (encode_runtime_expr 'ilk' blob op) across local / global / var-param
  targets. Return-value semantics: CAS/Exchange/ExchangeAdd return the OLD
  value; Increment/Decrement return the NEW value. }

var
  GCounter: LongInt;
  L32, Old32: LongInt;
  L64, Old64: Int64;

procedure BumpViaParam(var aTarget: LongInt);
begin
  InterlockedIncrement(aTarget);
end;

function SwapViaParam(var aTarget: Int64; aNew: Int64): Int64;
begin
  Result := InterlockedExchange64(aTarget, aNew);
end;

begin
  { statement form: local target }
  L32 := 5;
  InterlockedIncrement(L32);
  if L32 <> 6 then Halt(1);
  InterlockedDecrement(L32);
  if L32 <> 5 then Halt(2);

  { value form: CAS hit swaps and returns old }
  L32 := 10;
  Old32 := InterlockedCompareExchange(L32, 20, 10);
  if Old32 <> 10 then Halt(3);
  if L32 <> 20 then Halt(4);

  { value form: CAS miss leaves target untouched }
  Old32 := InterlockedCompareExchange(L32, 99, 10);
  if Old32 <> 20 then Halt(5);
  if L32 <> 20 then Halt(6);

  { value form: exchange returns old }
  Old32 := InterlockedExchange(L32, 7);
  if Old32 <> 20 then Halt(7);
  if L32 <> 7 then Halt(8);

  { value form: fetch-add returns old }
  Old32 := InterlockedExchangeAdd(L32, 3);
  if Old32 <> 7 then Halt(9);
  if L32 <> 10 then Halt(10);

  { 64-bit family }
  L64 := 100;
  Old64 := InterlockedCompareExchange64(L64, 200, 100);
  if Old64 <> 100 then Halt(11);
  if L64 <> 200 then Halt(12);
  Old64 := InterlockedExchangeAdd64(L64, 50);
  if Old64 <> 200 then Halt(13);
  if L64 <> 250 then Halt(14);

  { global target }
  GCounter := 1;
  Old32 := InterlockedCompareExchange(GCounter, 2, 1);
  if Old32 <> 1 then Halt(15);
  if GCounter <> 2 then Halt(16);

  { var-param target through helper routines }
  BumpViaParam(GCounter);
  if GCounter <> 3 then Halt(17);
  L64 := 300;
  Old64 := SwapViaParam(L64, 400);
  if Old64 <> 300 then Halt(18);
  if L64 <> 400 then Halt(19);
end.
