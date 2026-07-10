program test_lockfree_crdt;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.crdt;

var
  GPassed, GFailed: Int32;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure TestGCounter;
var
  LC1, LC2: TGCounter;
begin
  WriteLn('--- TestGCounter ---');
  LC1 := TGCounter.Create(3);
  LC2 := TGCounter.Create(3);
  try
    LC1.Increment(0, 5);
    LC1.Increment(1, 3);
    LC2.Increment(1, 7);
    LC2.Increment(2, 2);
    Check(LC1.Value = 8, 'Counter1 value = 8');
    Check(LC2.Value = 9, 'Counter2 value = 9');
    LC1.Merge(LC2);
    Check(LC1.Value = 14, 'After merge value = 14');
    Check(LC1.NodeValue(0) = 5, 'Node 0 = 5');
    Check(LC1.NodeValue(1) = 7, 'Node 1 merged to 7');
    Check(LC1.NodeValue(2) = 2, 'Node 2 merged to 2');
    LC1.Close;
    Check(LC1.Increment(0, 1) = crClosed, 'Increment after close fails');
  finally
    LC1.Free;
    LC2.Free;
  end;
end;

procedure TestGCounterMergeLaws;
var
  LC1, LC2: TGCounter;
begin
  WriteLn('--- TestGCounterMergeLaws ---');
  LC1 := TGCounter.Create(2);
  LC2 := TGCounter.Create(3);
  try
    Check(LC1.Increment(0, -1) = crInvalid,
      'G-Counter rejects negative increments');
    Check(LC1.Value = 0, 'Rejected increment preserves value');

    LC1.Increment(0, 5);
    LC2.Increment(1, 7);
    LC2.Increment(2, 11);
    LC1.Merge(LC2);
    LC2.Merge(LC1);
    Check(LC1.Value = 23, 'Smaller replica learns every component');
    Check(LC2.Value = 23, 'Merge is commutative across replica sizes');

    LC1.Merge(LC1);
    Check(LC1.Value = 23, 'Self-merge is an idempotent no-op');
  finally
    LC1.Free;
    LC2.Free;
  end;
end;

procedure TestGCounterTotalOverflowIsAtomic;
var
  LC1, LC2: TGCounter;
  LRaised: Boolean;
begin
  WriteLn('--- TestGCounterTotalOverflowIsAtomic ---');
  LC1 := TGCounter.Create(2);
  LC2 := TGCounter.Create(2);
  try
    Check(LC1.Increment(0, High(Int64)) = crOk,
      'Maximum representable total is accepted');
    Check(LC1.Increment(1, 1) = crInvalid,
      'Increment rejects total-value overflow');
    Check(LC1.NodeValue(1) = 0,
      'Rejected total overflow preserves the component');

    LC2.Increment(1, 1);
    LRaised := False;
    try
      LC1.Merge(LC2);
    except
      on Exception do
        LRaised := True;
    end;
    Check(LRaised, 'Merge reports an unrepresentable joined total');
    Check(LC1.NodeValue(1) = 0,
      'Rejected merge does not partially publish components');
  finally
    LC1.Free;
    LC2.Free;
  end;
end;

procedure TestPNCounter;
var
  LC1, LC2: TPNCounter;
begin
  WriteLn('--- TestPNCounter ---');
  LC1 := TPNCounter.Create(2);
  LC2 := TPNCounter.Create(2);
  try
    LC1.Increment(0, 10);
    LC1.Decrement(0, 3);
    Check(LC1.Value = 7, 'PN value = 7');
    LC2.Increment(1, 5);
    LC2.Decrement(0, 8);
    Check(LC2.Value = -3, 'PN value = -3');
    LC1.Merge(LC2);
    Check(LC1.Value = 7, 'After merge value = 7');
    LC1.Close;
    Check(LC1.Increment(0, 1) = crClosed, 'Increment after close fails');
  finally
    LC1.Free;
    LC2.Free;
  end;
end;

procedure TestPNCounterRejectsNegativeAmounts;
var
  LC: TPNCounter;
begin
  WriteLn('--- TestPNCounterRejectsNegativeAmounts ---');
  LC := TPNCounter.Create(1);
  try
    Check(LC.Increment(0, -1) = crInvalid,
      'PN increment rejects negative amount');
    Check(LC.Decrement(0, -1) = crInvalid,
      'PN decrement rejects negative amount');
    Check(LC.Value = 0, 'Rejected PN operations preserve value');
  finally
    LC.Free;
  end;
end;

procedure TestLWWRegister;
var
  LR1, LR2: TLWWRegister;
  LVal: AnsiString;
  LTs: Int64;
begin
  WriteLn('--- TestLWWRegister ---');
  LR1 := TLWWRegister.Create;
  LR2 := TLWWRegister.Create;
  try
    LR1.Assign('hello', 100);
    LTs := LR1.Read(LVal);
    Check(LVal = 'hello', 'Read hello');
    Check(LTs = 100, 'Timestamp 100');
    LR2.Assign('world', 200);
    LR1.Merge(LR2);
    LR1.Read(LVal);
    Check(LVal = 'world', 'After merge world wins');
    LR1.Assign('old', 50);
    LR1.Read(LVal);
    Check(LVal = 'world', 'Old timestamp rejected');
    LR1.Close;
    Check(LR1.Assign('x', 999) = crClosed, 'Assign after close fails');
  finally
    LR1.Free;
    LR2.Free;
  end;
end;

procedure TestLWWRegisterEqualTimestampConverges;
var
  LR1, LR2: TLWWRegister;
  LValue1, LValue2: AnsiString;
begin
  WriteLn('--- TestLWWRegisterEqualTimestampConverges ---');
  LR1 := TLWWRegister.Create;
  LR2 := TLWWRegister.Create;
  try
    LR1.Assign('alpha', 100);
    LR2.Assign('omega', 100);
    LR1.Merge(LR2);
    LR2.Merge(LR1);
    LR1.Read(LValue1);
    LR2.Read(LValue2);
    Check(LValue1 = LValue2,
      'Equal-timestamp merge order converges to one value');
    Check(LValue1 = 'omega',
      'Equal timestamps use deterministic value tie-break');

    LR1.Merge(LR1);
    LR1.Read(LValue1);
    Check(LValue1 = 'omega', 'LWW self-merge is idempotent');
  finally
    LR1.Free;
    LR2.Free;
  end;
end;

procedure TestORSet;
var
  LS1, LS2: TORSet;
begin
  WriteLn('--- TestORSet ---');
  LS1 := TORSet.Create;
  LS2 := TORSet.Create;
  try
    LS1.Add('a');
    LS1.Add('b');
    LS1.Add('c');
    Check(LS1.Count = 3, 'Count = 3');
    Check(LS1.Contains('a'), 'Contains a');
    LS1.Remove('b');
    Check(LS1.Count = 2, 'After remove count = 2');
    Check(not LS1.Contains('b'), 'b removed');
    LS2.Add('d');
    LS2.Add('b');
    LS1.Merge(LS2);
    Check(LS1.Contains('d'), 'Has d after merge');
    Check(LS1.Contains('b'), 'b re-added from other');
    LS1.Close;
    Check(LS1.Add('x') = crClosed, 'Add after close fails');
  finally
    LS1.Free;
    LS2.Free;
  end;
end;

procedure TestORSetMergePropagatesRemoval;
var
  LS1, LS2: TORSet;
begin
  WriteLn('--- TestORSetMergePropagatesRemoval ---');
  LS1 := TORSet.Create;
  LS2 := TORSet.Create;
  try
    LS1.Add('x');
    LS2.Merge(LS1);
    Check(LS2.Contains('x'), 'Peer sees replicated add');
    LS2.Remove('x');
    LS1.Merge(LS2);
    Check(not LS1.Contains('x'), 'Observed removal should propagate across merge');
  finally
    LS1.Free;
    LS2.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_crdt ===');
  GPassed := 0;
  GFailed := 0;
  TestGCounter;
  TestGCounterMergeLaws;
  TestGCounterTotalOverflowIsAtomic;
  TestPNCounter;
  TestPNCounterRejectsNegativeAmounts;
  TestLWWRegister;
  TestLWWRegisterEqualTimestampConverges;
  TestORSet;
  TestORSetMergePropagatesRemoval;
  WriteLn;
  WriteLn('Results: ', GPassed, ' passed, ', GFailed, ' failed');
  if GFailed > 0 then
    Halt(1);
end.
