program test_async_cancellation;
{$mode ObjFPC}{$H+}{$J-}

uses
  SysUtils, Classes,
  nextpas.core.base, nextpas.core.errors,
  nextpas.core.async.base,
  nextpas.core.async.cancellation;

const
  HEAPTRC_ACTIVE =
    {$IFDEF HEAPTRC_ACTIVE} True {$ELSE} False {$ENDIF};

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;
  GCancelCallbackFired: Integer = 0;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', ATestName);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAIL: ', ATestName);
  end;
end;

procedure TestCancelCallback(AContext: Pointer);
begin
  Inc(GCancelCallbackFired);
end;

{ Test 1: Create token }
procedure TestCreateToken;
var
  LToken: IAsyncCancellationToken;
begin
  WriteLn('TestCreateToken:');
  LToken := CreateCancellationToken;
  Check(LToken <> nil, 'token created');
  Check(not LToken.IsCancelled, 'not cancelled initially');
end;

{ Test 2: Cancel token }
procedure TestCancelToken;
var
  LToken: IAsyncCancellationToken;
begin
  WriteLn('TestCancelToken:');
  LToken := CreateCancellationToken;
  Check(not LToken.IsCancelled, 'not cancelled initially');
  LToken.Cancel;
  Check(LToken.IsCancelled, 'cancelled after Cancel');
end;

{ Test 3: Double cancel is safe }
procedure TestDoubleCancel;
var
  LToken: IAsyncCancellationToken;
begin
  WriteLn('TestDoubleCancel:');
  LToken := CreateCancellationToken;
  LToken.Cancel;
  LToken.Cancel;  { should not crash }
  Check(LToken.IsCancelled, 'still cancelled');
end;

{ Test 4: OnCancel callback }
procedure TestOnCancelCallback;
var
  LToken: IAsyncCancellationToken;
begin
  WriteLn('TestOnCancelCallback:');
  LToken := CreateCancellationToken;
  GCancelCallbackFired := 0;
  LToken.OnCancel(@TestCancelCallback);
  Check(GCancelCallbackFired = 0, 'callback not fired before cancel');
  LToken.Cancel;
  Check(GCancelCallbackFired = 1, 'callback fired after cancel');
end;

{ Test 5: OnCancel on already cancelled token }
procedure TestOnCancelAlreadyCancelled;
var
  LToken: IAsyncCancellationToken;
begin
  WriteLn('TestOnCancelAlreadyCancelled:');
  LToken := CreateCancellationToken;
  LToken.Cancel;
  GCancelCallbackFired := 0;
  LToken.OnCancel(@TestCancelCallback);
  Check(GCancelCallbackFired = 1, 'callback fired immediately for cancelled token');
end;

{ Test 6: Multiple callbacks }
procedure TestMultipleCallbacks;
var
  LToken: IAsyncCancellationToken;
begin
  WriteLn('TestMultipleCallbacks:');
  LToken := CreateCancellationToken;
  GCancelCallbackFired := 0;
  LToken.OnCancel(@TestCancelCallback);
  LToken.OnCancel(@TestCancelCallback);
  LToken.OnCancel(@TestCancelCallback);
  LToken.Cancel;
  Check(GCancelCallbackFired = 3, 'all 3 callbacks fired');
end;

{ Test 7: Child token }
procedure TestChildToken;
var
  LParent, LChild: IAsyncCancellationToken;
begin
  WriteLn('TestChildToken:');
  LParent := CreateCancellationToken;
  LChild := LParent.CreateChildToken;
  Check(not LChild.IsCancelled, 'child not cancelled initially');
  LParent.Cancel;
  Check(LChild.IsCancelled, 'child cancelled when parent cancelled');
end;

{ Test 8: Child token independent cancel }
procedure TestChildIndependentCancel;
var
  LParent, LChild: IAsyncCancellationToken;
begin
  WriteLn('TestChildIndependentCancel:');
  LParent := CreateCancellationToken;
  LChild := LParent.CreateChildToken;
  LChild.Cancel;
  Check(LChild.IsCancelled, 'child cancelled');
  Check(not LParent.IsCancelled, 'parent not cancelled');
end;

{ Test 9: Grandchild propagation }
procedure TestGrandchildPropagation;
var
  LGrandparent, LParent, LChild: IAsyncCancellationToken;
begin
  WriteLn('TestGrandchildPropagation:');
  LGrandparent := CreateCancellationToken;
  LParent := LGrandparent.CreateChildToken;
  LChild := LParent.CreateChildToken;
  Check(not LChild.IsCancelled, 'grandchild not cancelled initially');
  LGrandparent.Cancel;
  Check(LChild.IsCancelled, 'grandchild cancelled when grandparent cancelled');
  Check(LParent.IsCancelled, 'parent cancelled when grandparent cancelled');
end;

{ Test 10: WaitForCancel with timeout }
procedure TestWaitForCancelTimeout;
var
  LToken: IAsyncCancellationToken;
  LCancelled: Boolean;
begin
  WriteLn('TestWaitForCancelTimeout:');
  LToken := CreateCancellationToken;
  LCancelled := LToken.WaitForCancel(10);  { 10ms timeout }
  Check(not LCancelled, 'not cancelled after timeout');
end;

{ Test 11: WaitForCancel immediate }
procedure TestWaitForCancelImmediate;
var
  LToken: IAsyncCancellationToken;
begin
  WriteLn('TestWaitForCancelImmediate:');
  LToken := CreateCancellationToken;
  LToken.Cancel;
  Check(LToken.WaitForCancel(0), 'immediate wait returns true');
end;

{ Test 12: Child callback on parent cancel }
procedure TestChildCallbackOnParentCancel;
var
  LParent, LChild: IAsyncCancellationToken;
begin
  WriteLn('TestChildCallbackOnParentCancel:');
  LParent := CreateCancellationToken;
  LChild := LParent.CreateChildToken;
  GCancelCallbackFired := 0;
  LChild.OnCancel(@TestCancelCallback);
  LParent.Cancel;
  Check(GCancelCallbackFired = 1, 'child callback fired when parent cancelled');
end;

{ Main }
begin
  WriteLn('=== test_async_cancellation ===');
  WriteLn;

  TestCreateToken;
  WriteLn;

  TestCancelToken;
  WriteLn;

  TestDoubleCancel;
  WriteLn;

  TestOnCancelCallback;
  WriteLn;

  TestOnCancelAlreadyCancelled;
  WriteLn;

  TestMultipleCallbacks;
  WriteLn;

  TestChildToken;
  WriteLn;

  TestChildIndependentCancel;
  WriteLn;

  TestGrandchildPropagation;
  WriteLn;

  TestWaitForCancelTimeout;
  WriteLn;

  TestWaitForCancelImmediate;
  WriteLn;

  TestChildCallbackOnParentCancel;
  WriteLn;

  WriteLn('=== Results ===');
  WriteLn('Passed: ', GTestsPassed);
  WriteLn('Failed: ', GTestsFailed);
  WriteLn('Total:  ', GTestsPassed + GTestsFailed);
  WriteLn;

  if GTestsFailed > 0 then
  begin
    WriteLn('FAILED');
    Halt(1);
  end
  else
    WriteLn('OK');
end.
