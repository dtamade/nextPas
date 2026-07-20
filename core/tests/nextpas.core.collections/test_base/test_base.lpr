program test_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.collections.base;

var
  T: TTestSuite;

procedure TestBaseExportsCollectionSkeleton;
var
  LClass: TCollectionClass;
begin
  LClass := TCollection;
  Check(LClass <> nil, 'TCollectionClass should accept TCollection');
end;

procedure TestBaseExportsGrowthStrategies;
var
  LStrategy: IGrowthStrategy;
begin
  LStrategy := FactorGrow(1.5);
  Check(LStrategy <> nil, 'FactorGrow should return a strategy');
  Check(LStrategy.GetGrowSize(0, 10) >= 10, 'growth strategy should satisfy required size');

  LStrategy := DoublingGrow;
  CheckEqual(Int64(8), Int64(LStrategy.GetGrowSize(4, 5)), 'doubling strategy should double capacity');

  CheckEqual(
    Int64(64),
    Int64(TAlignedWrapperStrategy.DEFAULT_ALIGN_SIZE),
    'aligned wrapper default alignment');
end;

function FileReadable(const APath: string): Boolean;
var
  LFile: Text;
begin
  {$I-}
  Assign(LFile, APath);
  Reset(LFile);
  Result := IOResult = 0;
  if Result then
    Close(LFile);
  {$I+}
end;

function ExtractBaseName(const APath: string): string;
var
  I: Integer;
begin
  Result := APath;
  for I := Length(APath) downto 1 do
    if (APath[I] = '/') or (APath[I] = '\') then
      Exit(Copy(APath, I + 1, MaxInt));
end;

function ReadSourceFile(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  if not FileReadable(APath) then
    Exit;
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LLine + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolveSourcePath(const APathFromTest: string; const APathFromRoot: string): string;
var
  LBase: string;
begin
  if FileReadable(APathFromTest) then
    Exit(APathFromTest);
  if FileReadable(APathFromRoot) then
    Exit(APathFromRoot);
  LBase := ExtractBaseName(APathFromRoot);
  if FileReadable('src/' + LBase) then
    Exit('src/' + LBase);
  Result := APathFromTest;
end;

procedure TestGrowthStrategyInterfaceLivesInBase;
var
  LBaseSource: string;
  LIntfSource: string;
begin
  LBaseSource := ReadSourceFile(ResolveSourcePath(
    '../../../src/nextpas.core.collections.base.pas',
    'core/src/nextpas.core.collections.base.pas'));
  LIntfSource := ReadSourceFile(ResolveSourcePath(
    '../../../src/nextpas.core.collections.intf.pas',
    'core/src/nextpas.core.collections.intf.pas'));

  if (LBaseSource = '') or (LIntfSource = '') then
  begin Check(True, 'skipped - source not accessible'); Exit; end;

  Check(Pos('IGrowthStrategy = interface', LBaseSource) > 0,
    'IGrowthStrategy interface definition should live in collections.base');
  Check(Pos('IGrowthStrategy = interface', LIntfSource) = 0,
    'collections.intf should no longer own IGrowthStrategy interface definition');
end;

procedure TestCollectionInterfacesLiveInIntf;
var
  LBaseSource: string;
  LIntfSource: string;
begin
  LBaseSource := ReadSourceFile(ResolveSourcePath(
    '../../../src/nextpas.core.collections.base.pas',
    'core/src/nextpas.core.collections.base.pas'));
  LIntfSource := ReadSourceFile(ResolveSourcePath(
    '../../../src/nextpas.core.collections.intf.pas',
    'core/src/nextpas.core.collections.intf.pas'));

  if (LBaseSource = '') or (LIntfSource = '') then
  begin Check(True, 'skipped - source not accessible'); Exit; end;

  Check(Pos('ICollection = interface', LIntfSource) > 0,
    'ICollection interface definition should live in collections.intf');
  Check(Pos('ICollection = interface', LBaseSource) = 0,
    'collections.base should not own ICollection interface definition');
  Check(Pos('generic IGenericCollection<T> = interface', LIntfSource) > 0,
    'IGenericCollection<T> interface definition should live in collections.intf');
  Check(Pos('generic IGenericCollection<T> = interface', LBaseSource) = 0,
    'collections.base should not own IGenericCollection<T> interface definition');
end;

begin
  T := TTestSuite.Create('nextpas.core.collections.base');
  T.Test('exports collection skeleton', @TestBaseExportsCollectionSkeleton);
  T.Test('exports growth strategies', @TestBaseExportsGrowthStrategies);
  T.Test('growth strategy interface lives in base', @TestGrowthStrategyInterfaceLivesInBase);
  T.Test('collection interfaces live in intf', @TestCollectionInterfacesLiveInIntf);
  if not T.Run then Halt(1);
end.
