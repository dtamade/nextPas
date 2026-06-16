program test_concurrent_hashmap_managed_returns;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}cthreads,{$endif}
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.concurrent.hashmap;

type
  TStringConcurrentMap = specialize TConcurrentHashMap<string, Integer>;

var
  T: TTestRunner;

function HashString(const A: string): UInt32;
var
  I: Integer;
begin
  Result := 2166136261;
  for I := 1 to Length(A) do
    Result := (Result xor UInt32(Ord(A[I]))) * 16777619;
end;

function EqualString(const A, B: string): Boolean;
begin
  Result := A = B;
end;

procedure TestManagedKeysOutliveMap;
var
  LMap: TStringConcurrentMap;
  LKeys: TStringConcurrentMap.TKeyArray;
  I: Integer;
  LSeenAlpha: Boolean;
  LSeenBeta: Boolean;
  LSeenGamma: Boolean;
begin
  LMap := TStringConcurrentMap.Create(@HashString, @EqualString);
  try
    LMap.Put('alpha', 1);
    LMap.Put('beta', 2);
    LMap.Put('gamma', 3);
    LKeys := LMap.Keys;
  finally
    LMap.Free;
  end;

  CheckEqual(Int64(3), Int64(Length(LKeys)), 'keys length');
  LSeenAlpha := False;
  LSeenBeta := False;
  LSeenGamma := False;
  for I := 0 to High(LKeys) do
  begin
    if LKeys[I] = 'alpha' then
      LSeenAlpha := True;
    if LKeys[I] = 'beta' then
      LSeenBeta := True;
    if LKeys[I] = 'gamma' then
      LSeenGamma := True;
  end;
  Check(LSeenAlpha and LSeenBeta and LSeenGamma, 'all keys retained after map free');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.concurrent_hashmap_managed_returns');
  T.Run('managed keys outlive map', @TestManagedKeysOutliveMap);
  T.Summary;
end.
