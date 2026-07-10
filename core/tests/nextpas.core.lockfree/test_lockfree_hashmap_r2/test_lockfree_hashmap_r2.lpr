program test_lockfree_hashmap_r2;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.lockfree.hashmap,
  nextpas.core.test;

type
  TIntMap = specialize TShardedHashMap<Integer, Integer>;

procedure TestNonPowerOfTwoCapacityKeepsCompleteProbeSequence;
var
  LFirstKeyBySlot: array[0..15] of Integer;
  LSeenSlot: array[0..15] of Boolean;
  LFirstKey: Integer;
  LSecondKey: Integer;
  LKey: Integer;
  LSlot: Integer;
  LValue: Integer;
  LMap: TIntMap;
begin
  FillChar(LSeenSlot, SizeOf(LSeenSlot), 0);
  FillChar(LFirstKeyBySlot, SizeOf(LFirstKeyBySlot), 0);
  LFirstKey := 0;
  LSecondKey := 0;
  LMap := TIntMap.Create(5);
  try
    for LKey := 0 to 1024 do
    begin
      { Same low four hash bits guarantee the same shard and the same bucket
        before and after capacity 5 is normalized to 8. }
      LSlot := Integer(LMap.HashKey(LKey) and 15);
      if LSeenSlot[LSlot] then
      begin
        LFirstKey := LFirstKeyBySlot[LSlot];
        LSecondKey := LKey;
        Break;
      end;
      LSeenSlot[LSlot] := True;
      LFirstKeyBySlot[LSlot] := LKey;
    end;

    Check(LFirstKey <> LSecondKey, 'must find two keys with the same normalized bucket');
    LMap.Insert(LFirstKey, 101);
    LMap.Insert(LSecondKey, 202);
    Check(LMap.Find(LFirstKey, LValue), 'first colliding key remains findable');
    CheckEqual(101, LValue, 'first colliding value');
    Check(LMap.Find(LSecondKey, LValue), 'second colliding key is findable');
    CheckEqual(202, LValue, 'second colliding value');
  finally
    LMap.Free;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.lockfree.hashmap.r2');
  T.Test('non-power-of-two capacity keeps complete probe sequence',
    @TestNonPowerOfTwoCapacityKeepsCompleteProbeSequence);
  if not T.Run then
    Halt(1);
end.
