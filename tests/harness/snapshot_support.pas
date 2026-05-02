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
function SnapshotStatusForFixture(
  const AGroupName: string;
  const AGroupRoot: string;
  const AFixturePath: string
): string;
function ReadTextFile(const APath: string): string;
procedure WriteTextFile(const APath: string; const AText: string);
function NormalizeSnapshotText(const AText: string): string;

implementation

uses
  Classes, SysUtils;

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
    PathDelim,
    '-',
    [rfReplaceAll]
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

function SnapshotStatusForFixture(
  const AGroupName: string;
  const AGroupRoot: string;
  const AFixturePath: string
): string;
var
  SnapshotPathValue: string;
  RawSnapshotText: string;
  NormalizedSnapshotText: string;
begin
  SnapshotPathValue := SnapshotPathForFixture(
    AGroupName,
    AGroupRoot,
    AFixturePath
  );

  if not FileExists(SnapshotPathValue) then
    Exit('missing');

  RawSnapshotText := ReadTextFile(SnapshotPathValue);
  NormalizedSnapshotText := NormalizeSnapshotText(RawSnapshotText);
  if RawSnapshotText <> NormalizedSnapshotText then
    Exit('unstable');

  Result := 'ready';
end;

function ReadTextFile(const APath: string): string;
var
  Stream: TFileStream;
  Buffer: RawByteString;
begin
  Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Buffer, Stream.Size);
    if Stream.Size > 0 then
      Stream.ReadBuffer(Buffer[1], Stream.Size);
  finally
    Stream.Free;
  end;

  Result := string(Buffer);
end;

procedure WriteTextFile(const APath: string; const AText: string);
var
  Stream: TFileStream;
  Buffer: RawByteString;
begin
  ForceDirectories(ExtractFileDir(APath));
  Stream := TFileStream.Create(APath, fmCreate);
  try
    Buffer := RawByteString(AText);
    if Length(Buffer) > 0 then
      Stream.WriteBuffer(Buffer[1], Length(Buffer));
  finally
    Stream.Free;
  end;
end;

function NormalizeSnapshotText(const AText: string): string;
var
  Normalized: string;
begin
  Normalized := StringReplace(AText, #13#10, #10, [rfReplaceAll]);
  Normalized := StringReplace(Normalized, #13, #10, [rfReplaceAll]);

  Result := Normalized;
end;

end.
