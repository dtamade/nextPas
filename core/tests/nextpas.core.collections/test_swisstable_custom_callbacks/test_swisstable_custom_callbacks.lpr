program test_swisstable_custom_callbacks;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.hashmap.swiss,
  nextpas.core.collections.hashmap.swiss.adapter;

type
  TIntSwiss = specialize TSwissTable<Integer, Integer>;
  TStringSwiss = specialize TSwissTable<string, Integer>;
  TIntAdapter = specialize TSwissHashMap<Integer, Integer>;

var
  T: TTestRunner;

function HashModuloTen(const AKey: Integer): UInt32;
begin
  Result := UInt32(AKey mod 10);
end;

function EqualModuloTen(const L, R: Integer): Boolean;
begin
  Result := (L mod 10) = (R mod 10);
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

begin
  T := TTestRunner.Create('nextpas.core.collections.swisstable_custom_callbacks');
  T.Run('integer callbacks override fast path', @TestIntegerCallbacksOverrideFastPath);
  T.Run('string hash callback overrides fast path', @TestStringHashCallbackOverridesFastPath);
  T.Run('adapter forwards callbacks', @TestAdapterForwardsCallbacks);
  T.Summary;
end.
