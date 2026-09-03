program test_async_cancellation;
{$mode ObjFPC}{$H+}{$J-}

uses
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

{ Test: RemoveOnCancel（V3-B7 反哺新增的幂等注销面） }
procedure TestRemoveOnCancel;
var
  LToken: IAsyncCancellationToken;
begin
  WriteLn('TestRemoveOnCancel:');
  { 摘除 A 后取消：只有 B 触发 }
  LToken := CreateCancellationToken;
  GCancelCallbackFired := 0;
  LToken.OnCancel(@TestCancelCallback, Pointer(1));
  LToken.OnCancel(@TestCancelCallback, Pointer(2));
  LToken.RemoveOnCancel(@TestCancelCallback, Pointer(1));
  LToken.Cancel;
  Check(GCancelCallbackFired = 1, 'removed callback not fired, other fired');

  { 无匹配注销 = 无害 no-op；重复注销幂等 }
  LToken := CreateCancellationToken;
  GCancelCallbackFired := 0;
  LToken.RemoveOnCancel(@TestCancelCallback);       { 从未注册 }
  LToken.OnCancel(@TestCancelCallback);
  LToken.RemoveOnCancel(@TestCancelCallback);
  LToken.RemoveOnCancel(@TestCancelCallback);       { 重复摘除 }
  LToken.Cancel;
  Check(GCancelCallbackFired = 0, 'cancel after removal fires nothing');

  { 连续同名多注册一次清空 }
  LToken := CreateCancellationToken;
  GCancelCallbackFired := 0;
  LToken.OnCancel(@TestCancelCallback);
  LToken.OnCancel(@TestCancelCallback);
  LToken.RemoveOnCancel(@TestCancelCallback);
  LToken.Cancel;
  Check(GCancelCallbackFired = 0, 'duplicate registrations all removed');
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

{ V3-B6 回归（UAF 窗口修复钉子）：子 Detach 后父取消必须安全——
  修复前父列表残留裸指针，此处为悬垂解引用 }
procedure TestChildDetachCallback(AContext: Pointer);
begin
  Inc(GCancelCallbackFired);
end;

procedure TestChildDetachThenParentCancel;
var
  LParent, LChild: IAsyncCancellationToken;
begin
  WriteLn('TestChildDetachThenParentCancel:');
  GCancelCallbackFired := 0;
  LParent := CreateCancellationToken;
  LChild := LParent.CreateChildToken;
  LChild.OnCancel(@TestChildDetachCallback);
  LChild.DetachFromParent;              { 子任务收尾标准动作 }
  LChild := nil;                        { 摘链后即可释放 }
  LParent.Cancel;                       { 修复前：遍历悬挂指针 UAF }
  Check(GCancelCallbackFired = 0,
    'detached child callback NOT fired by parent cancel');
  Check(LParent.IsCancelled, 'parent cancelled normally');
end;

{ V3-B6 回归（保活钉子）：未 Detach 的子由父持引用保活——父取消时
  回调仍触发一次；已取消后 Detach 幂等无害 }
procedure TestChildKeptAliveUntilCancel;
var
  LParent, LChild: IAsyncCancellationToken;
begin
  WriteLn('TestChildKeptAliveUntilCancel:');
  GCancelCallbackFired := 0;
  LParent := CreateCancellationToken;
  LChild := LParent.CreateChildToken;
  LChild.OnCancel(@TestChildDetachCallback);
  LParent.Cancel;
  Check(LChild.IsCancelled, 'listed child cancelled via parent');
  Check(GCancelCallbackFired = 1, 'listed child callback fired once');
  LChild.DetachFromParent;              { 已取消后摘链：幂等 }
  LChild := nil;
end;

{ V3-B6 回归（父亡重入钉子）：父先亡须安全释放仍挂列的子令牌，
  heaptrc 零泄漏兜底 }
procedure TestParentDiesWithListedChild;
var
  LParent, LChild: IAsyncCancellationToken;
begin
  WriteLn('TestParentDiesWithListedChild:');
  LParent := CreateCancellationToken;
  LChild := LParent.CreateChildToken;
  LChild.OnCancel(@TestChildDetachCallback);
  LParent := nil;                       { 父亡：条目释放，子被保活不析构 }
  Check(not LChild.IsCancelled, 'child survives parent death (kept alive)');
  LChild.DetachFromParent;              { 父引用已随父亡释放：幂等摘链 }
  LChild := nil;                        { 此时才真正析构 }
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

  TestRemoveOnCancel;
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

  TestChildDetachThenParentCancel;
  WriteLn;

  TestChildKeptAliveUntilCancel;
  WriteLn;

  TestParentDiesWithListedChild;
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
