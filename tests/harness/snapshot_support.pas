unit snapshot_support;

{$mode objfpc}{$H+}

interface

function GroupUsesSnapshot(const AGroupName: string): Boolean;
function SnapshotRoot: string;
function SnapshotPath(const AName: string): string;
function SnapshotDiffPath(const AName: string): string;
function SnapshotKeyForFixture(
  const AGroupName: string;
  const AGroupRoot: string;
  const AFixturePath: string
): string;
function SnapshotPathForFixture(
  const AGroupName: string;
  const AGroupRoot: string;
  const AFixturePath: string
): string;
function SnapshotDiffPathForFixture(
  const AGroupName: string;
  const AGroupRoot: string;
  const AFixturePath: string
): string;
function ReadTextFile(const APath: string): string;
procedure WriteTextFile(const APath: string; const AText: string);
function NormalizeSnapshotText(const AText: string): string;
function RelativeFixtureName(
  const AGroupRoot: string;
  const AFixturePath: string
): string;

implementation

uses
  nextpas.core.base, nextpas.core.text.conv, nextpas.core.fs,
  nextpas.core.path;

function GroupUsesSnapshot(const AGroupName: string): Boolean;
begin
  Result := (AGroupName = 'compiler-fail') or (AGroupName = 'diagnostics');
end;

function SnapshotRoot: string;
begin
  Result := 'tests/snapshots';
end;

function SnapshotPath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(SnapshotRoot) + AName + '.txt';
end;

function SnapshotDiffPath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(SnapshotRoot) + AName + '.diff.txt';
end;

function StripKnownFixtureSuffix(const AName: string): string;
begin
  Result := AName;
  if (Length(Result) > 5) and (Copy(Result, Length(Result) - 4, 5) = '_fail') then
    Delete(Result, Length(Result) - 4, 5);
end;

function RelativeFixtureName(
  const AGroupRoot: string;
  const AFixturePath: string
): string;
var
  ExpandedGroupRoot: string;
  ExpandedFixturePath: string;
begin
  ExpandedGroupRoot := IncludeTrailingPathDelimiter(ExpandFileName(AGroupRoot));
  ExpandedFixturePath := ExpandFileName(AFixturePath);
  if Pos(ExpandedGroupRoot, ExpandedFixturePath) = 1 then
    Result := Copy(
      ExpandedFixturePath,
      Length(ExpandedGroupRoot) + 1,
      Length(ExpandedFixturePath) - Length(ExpandedGroupRoot)
    )
  else
    Result := ExtractFileName(AFixturePath);
end;

function SnapshotKeyForFixture(
  const AGroupName: string;
  const AGroupRoot: string;
  const AFixturePath: string
): string;
var
  RelativeName: string;
begin
  RelativeName := ChangeFileExt(RelativeFixtureName(AGroupRoot, AFixturePath), '');
  RelativeName := StringReplace(
    RelativeName,
    DirectorySeparator,
    '-',
    True
  );

  if AGroupName = 'compiler-fail' then
    RelativeName := StripKnownFixtureSuffix(RelativeName);

  Result := AGroupName + '-' + RelativeName + '.stderr';
end;

function SnapshotPathForFixture(
  const AGroupName: string;
  const AGroupRoot: string;
  const AFixturePath: string
): string;
begin
  Result := SnapshotPath(SnapshotKeyForFixture(AGroupName, AGroupRoot, AFixturePath));
end;

function SnapshotDiffPathForFixture(
  const AGroupName: string;
  const AGroupRoot: string;
  const AFixturePath: string
): string;
begin
  Result := SnapshotDiffPath(
    SnapshotKeyForFixture(AGroupName, AGroupRoot, AFixturePath)
  );
end;

function ReadTextFile(const APath: string): string;
var
  Data: TBytes;
begin
  Data := ReadFile(APath);
  SetLength(Result, Length(Data));
  if Length(Data) > 0 then
    Move(Data[0], Result[1], Length(Data));
end;

procedure WriteTextFile(const APath: string; const AText: string);
begin
  ForceDirectories(ExtractFileDir(APath));
  WriteFileText(APath, AText);
end;

function NormalizeSnapshotText(const AText: string): string;
var
  Normalized: string;
begin
  Normalized := StringReplace(AText, #13#10, #10, True);
  Normalized := StringReplace(Normalized, #13, #10, True);

  Result := Normalized;
end;

end.
