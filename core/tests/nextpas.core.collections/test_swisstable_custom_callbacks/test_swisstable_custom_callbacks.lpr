program test_swisstable_custom_callbacks;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.collections.hashmap.swiss,
  nextpas.core.collections.hashmap.swiss.adapter;

type
  TRecordKey = record
    A: UInt32;
    B: UInt32;
  end;
  TIntSwiss = specialize TSwissTable<Integer, Integer>;
  TStringSwiss = specialize TSwissTable<string, Integer>;
  TRecordSwiss = specialize TSwissTable<TRecordKey, Integer>;
  TIntAdapter = specialize TSwissHashMap<Integer, Integer>;
  TRecordAdapter = specialize TSwissHashMap<TRecordKey, Integer>;

var
  T: TTestRunner;
  GFailHashEnabled: Boolean;
  GFailHashKey: Integer;

type
  EHashCallbackFault = class(Exception);

function HashModuloTen(const AKey: Integer): UInt32;
begin
  Result := UInt32(AKey mod 10);
end;

function EqualModuloTen(const L, R: Integer): Boolean;
begin
  Result := (L mod 10) = (R mod 10);
end;

function FailingIntHash(const AKey: Integer): UInt32;
begin
  if GFailHashEnabled and (AKey = GFailHashKey) then
    raise EHashCallbackFault.Create('intentional hash callback fault');
  Result := InlineHashMix32(UInt32(AKey));
end;

function EqualInt(const L, R: Integer): Boolean;
begin
  Result := L = R;
end;

function RecordHash(const AKey: TRecordKey): UInt32;
begin
  Result := AKey.A * UInt32($01000193);
end;

function RecordEqual(const L, R: TRecordKey): Boolean;
begin
  Result := L.A = R.A;
end;

procedure AddFive(var AValue: Integer);
begin
  Inc(AValue, 5);
end;

function CaseFoldHash(const AKey: string): UInt32;
var
  LKey: string;
  I: Integer;
begin
  LKey := LowerCase(AKey);
  Result := UInt32($811C9DC5);
  for I := 1 to Length(LKey) do
    Result := (Result xor Ord(LKey[I])) * UInt32($01000193);
end;

function CaseFoldEqual(const L, R: string): Boolean;
begin
  Result := SameText(L, R);
end;

procedure TestIntegerCallbacksOverrideFastPath;
var
  LMap: TIntSwiss;
  LValue: Integer;
begin
  LMap := TIntSwiss.Create(0, @HashModuloTen, @EqualModuloTen);
  try
    Check(LMap.AddOrAssign(1, 10), 'insert first key');
    Check(not LMap.AddOrAssign(11, 110), 'equal key updates existing slot');
    CheckEqual(Int64(1), Int64(LMap.Count), 'count after equal-key update');
    Check(LMap.TryGetValue(21, LValue), 'lookup with equivalent integer key');
    CheckEqual(Int64(110), Int64(LValue), 'updated equivalent value');
  finally
    LMap.Free;
  end;
end;

procedure TestStringHashCallbackOverridesFastPath;
var
  LMap: TStringSwiss;
  LValue: Integer;
begin
  LMap := TStringSwiss.Create(0, @CaseFoldHash, @CaseFoldEqual);
  try
    Check(LMap.AddOrAssign('Alpha', 1), 'insert mixed-case key');
    Check(not LMap.AddOrAssign('alpha', 2), 'case-fold equal key updates existing slot');
    CheckEqual(Int64(1), Int64(LMap.Count), 'count after case-fold update');
    Check(LMap.TryGetValue('ALPHA', LValue), 'lookup with case-fold key');
    CheckEqual(Int64(2), Int64(LValue), 'case-fold updated value');
  finally
    LMap.Free;
  end;
end;

procedure TestAdapterForwardsCallbacks;
var
  LMap: TIntAdapter;
  LValue: Integer;
begin
  LMap := TIntAdapter.Create(0, @HashModuloTen, @EqualModuloTen);
  try
    Check(LMap.AddOrAssign(2, 20), 'adapter insert first key');
    Check(not LMap.AddOrAssign(12, 120), 'adapter equal key updates existing slot');
    CheckEqual(Int64(1), Int64(LMap.GetCount), 'adapter count after update');
    Check(LMap.TryGetValue(22, LValue), 'adapter lookup with equivalent key');
    CheckEqual(Int64(120), Int64(LValue), 'adapter updated equivalent value');
  finally
    LMap.Free;
  end;
end;

procedure TestRecordCallbacksSupportDirectTable;
var
  LMap: TRecordSwiss;
  LKey, LEqualKey: TRecordKey;
  LValue: Integer;
begin
  LMap := TRecordSwiss.Create(0, @RecordHash, @RecordEqual);
  try
    LKey.A := 7;
    LKey.B := 1;
    LEqualKey.A := 7;
    LEqualKey.B := 2;

    Check(LMap.AddOrAssign(LKey, 70), 'record callback inserts key');
    Check(not LMap.AddOrAssign(LEqualKey, 700), 'record callback equality updates existing key');
    CheckEqual(Int64(1), Int64(LMap.Count), 'record callback table count');
    Check(LMap.TryGetValue(LEqualKey, LValue), 'record callback lookup uses equality');
    CheckEqual(Int64(700), Int64(LValue), 'record callback updated value');
    Check(LMap.Remove(LEqualKey), 'record callback remove uses equality');
    CheckEqual(Int64(0), Int64(LMap.Count), 'record callback remove count');
  finally
    LMap.Free;
  end;
end;

procedure TestRecordCallbacksSupportAdapterSurface;
var
  LMap: TRecordAdapter;
  LKey, LEqualKey: TRecordKey;
  LValue: Integer;
begin
  LMap := TRecordAdapter.Create(0, @RecordHash, @RecordEqual);
  try
    LKey.A := 9;
    LKey.B := 1;
    LEqualKey.A := 9;
    LEqualKey.B := 2;

    Check(LMap.Add(LKey, 90), 'adapter record callback add inserts');
    Check(not LMap.Add(LEqualKey, 900), 'adapter record callback add rejects equal key');
    Check(LMap.ContainsKey(LEqualKey), 'adapter record callback contains uses equality');
    CheckEqual(Int64(90), Int64(LMap.GetOrInsert(LEqualKey, 1)), 'adapter record callback get-or-insert');
    LMap.ModifyOrInsert(LEqualKey, @AddFive, 1);
    Check(LMap.TryGetValue(LKey, LValue), 'adapter record callback lookup original key');
    CheckEqual(Int64(95), Int64(LValue), 'adapter record callback modify existing');
    Check(LMap.Remove(LEqualKey), 'adapter record callback remove uses equality');
    CheckEqual(Int64(0), Int64(LMap.GetCount), 'adapter record callback remove count');
  finally
    LMap.Free;
  end;
end;

procedure TestPartialCallbacksFailClosed;
var
  LMap: TIntSwiss;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    LMap := TIntSwiss.Create(0, @HashModuloTen, nil);
    try
      LMap.Free;
    finally
    end;
  except
    on E: EArgumentError do
      LRaised := Pos('hash/equality callbacks', E.Message) > 0;
  end;
  Check(LRaised, 'hash callback without equality should fail closed');

  LRaised := False;
  try
    LMap := TIntSwiss.Create(0, nil, @EqualModuloTen);
    try
      LMap.Free;
    finally
    end;
  except
    on E: EArgumentError do
      LRaised := Pos('hash/equality callbacks', E.Message) > 0;
  end;
  Check(LRaised, 'equality callback without hash should fail closed');
end;

procedure TestUnsupportedRecordDefaultHashFailsClosed;
var
  LMap: TRecordSwiss;
  LKey: TRecordKey;
begin
  LMap := TRecordSwiss.Create;
  try
    LKey.A := 1;
    LKey.B := 2;
    try
      LMap.Put(LKey, 10);
      Fail('record key without custom hash/equality should fail closed');
    except
      on E: ENotSupportedError do
        Check(Pos('custom hash/equality', E.Message) > 0, 'unsupported key error explains custom callbacks');
    end;
  finally
    LMap.Free;
  end;
end;

procedure CheckIntSwissContents(LMap: TIntSwiss; AFirstKey, ALastKey: Integer);
var
  I, LValue: Integer;
begin
  for I := AFirstKey to ALastKey do
  begin
    Check(LMap.TryGetValue(I, LValue), 'old key remains readable');
    CheckEqual(Int64(I * 10), Int64(LValue), 'old value remains readable');
  end;
end;

procedure TestHashExceptionDuringGrowKeepsOldTable;
var
  LMap: TIntSwiss;
  I, LValue: Integer;
  LOldCount, LOldCapacity: SizeUInt;
  LRaised: Boolean;
begin
  GFailHashEnabled := False;
  GFailHashKey := 7;
  LMap := TIntSwiss.Create(0, @FailingIntHash, @EqualInt);
  try
    for I := 0 to 13 do
      LMap.Put(I, I * 10);
    LOldCount := LMap.Count;
    LOldCapacity := LMap.Capacity;

    LRaised := False;
    GFailHashEnabled := True;
    try
      LMap.Put(100, 1000);
    except
      on EHashCallbackFault do
        LRaised := True;
    end;
    GFailHashEnabled := False;

    Check(LRaised, 'grow rehash propagates hash callback fault');
    CheckEqual(Int64(LOldCount), Int64(LMap.Count), 'failed grow keeps old count');
    CheckEqual(Int64(LOldCapacity), Int64(LMap.Capacity), 'failed grow keeps old capacity');
    CheckIntSwissContents(LMap, 0, 13);
    Check(not LMap.TryGetValue(100, LValue), 'failed grow does not insert new key');
  finally
    GFailHashEnabled := False;
    LMap.Free;
  end;
end;

procedure TestHashExceptionDuringShrinkKeepsOldTable;
var
  LMap: TIntSwiss;
  I: Integer;
  LOldCount, LOldCapacity: SizeUInt;
  LRaised: Boolean;
begin
  GFailHashEnabled := False;
  GFailHashKey := 7;
  LMap := TIntSwiss.Create(0, @FailingIntHash, @EqualInt);
  try
    LMap.Reserve(128);
    for I := 0 to 13 do
      LMap.Put(I, I * 10);
    LOldCount := LMap.Count;
    LOldCapacity := LMap.Capacity;

    LRaised := False;
    GFailHashEnabled := True;
    try
      LMap.ShrinkToFit;
    except
      on EHashCallbackFault do
        LRaised := True;
    end;
    GFailHashEnabled := False;

    Check(LRaised, 'shrink rehash propagates hash callback fault');
    CheckEqual(Int64(LOldCount), Int64(LMap.Count), 'failed shrink keeps old count');
    CheckEqual(Int64(LOldCapacity), Int64(LMap.Capacity), 'failed shrink keeps old capacity');
    CheckIntSwissContents(LMap, 0, 13);
  finally
    GFailHashEnabled := False;
    LMap.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.swisstable_custom_callbacks');
  T.Run('integer callbacks override fast path', @TestIntegerCallbacksOverrideFastPath);
  T.Run('string hash callback overrides fast path', @TestStringHashCallbackOverridesFastPath);
  T.Run('adapter forwards callbacks', @TestAdapterForwardsCallbacks);
  T.Run('record callbacks support direct table', @TestRecordCallbacksSupportDirectTable);
  T.Run('record callbacks support adapter surface', @TestRecordCallbacksSupportAdapterSurface);
  T.Run('partial callbacks fail closed', @TestPartialCallbacksFailClosed);
  T.Run('unsupported record default hash fails closed', @TestUnsupportedRecordDefaultHashFailsClosed);
  T.Run('hash exception during grow keeps old table', @TestHashExceptionDuringGrowKeepsOldTable);
  T.Run('hash exception during shrink keeps old table', @TestHashExceptionDuringShrinkKeepsOldTable);
  T.Summary;
end.
