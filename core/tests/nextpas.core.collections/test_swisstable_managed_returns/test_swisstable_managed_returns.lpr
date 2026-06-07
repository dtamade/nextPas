program test_swisstable_managed_returns;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.hashmap.swiss;

type
  TStringSwiss = specialize TSwissTable<string, Integer>;

var
  T: TTestRunner;

procedure TestManagedKeysOutliveTable;
var
  LMap: TStringSwiss;
  LKeys: TStringSwiss.TKeyArray;
  I: Integer;
  LSeenAlpha: Boolean;
  LSeenBeta: Boolean;
  LSeenGamma: Boolean;
begin
  LMap := TStringSwiss.Create;
  try
    LMap.Put('alpha', 1);
    LMap.Put('beta', 2);
    LMap.Put('gamma', 3);
    LKeys := LMap.GetKeys;
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
  Check(LSeenAlpha and LSeenBeta and LSeenGamma, 'all keys retained after table free');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.swisstable_managed_returns');
  T.Run('managed keys outlive table', @TestManagedKeysOutliveTable);
  T.Summary;
end.
