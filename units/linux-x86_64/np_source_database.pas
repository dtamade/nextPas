unit np_source_database;

{$mode objfpc}{$H+}
{$UNITPATH ../../rtl/core/base}
{$UNITPATH ../../rtl/core/text}

interface

uses
  SysUtils, np_base_types, np_text_primitives;

type
  TSourceFileId = TCoreId;

  TSourceFileEntry = record
    FileId: TSourceFileId;
    DisplayPath: string;
    CanonicalPath: string;
    SourceText: string;
  end;

  TSourceDatabase = class
  private
    FFiles: array of TSourceFileEntry;
    FLineIndexState: string;
    function FindFileIndexByCanonicalPath(
      const ACanonicalPath: string
    ): LongInt;
  public
    constructor Create;
    function RegisterRootSource(const SourcePath: string): TSourceFileId;
    function RegisterSource(const SourcePath: string): TSourceFileId;
    function FileCount: LongInt;
    function LineIndexState: string;
    function RootFileId: TSourceFileId;
    function RootSourceText: string;
    function RootSourceCanonicalPath: string;
    function CanonicalPathForFileId(const AFileId: TSourceFileId): string;
    function SourceTextForFileId(const AFileId: TSourceFileId): string;
  end;

implementation

constructor TSourceDatabase.Create;
begin
  inherited Create;
  SetLength(FFiles, 0);
  FLineIndexState := 'deferred';
end;

function TSourceDatabase.RegisterRootSource(const SourcePath: string): TSourceFileId;
begin
  Result := RegisterSource(SourcePath);
end;

function TSourceDatabase.FindFileIndexByCanonicalPath(
  const ACanonicalPath: string
): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FFiles) - 1 do
    if FFiles[Index].CanonicalPath = ACanonicalPath then
      Exit(Index);

  Result := -1;
end;

function TSourceDatabase.RegisterSource(const SourcePath: string): TSourceFileId;
var
  CanonicalPath: string;
  LoadedCanonicalPath: string;
  SourceText: string;
  EntryIndex: SizeInt;
  ExistingIndex: LongInt;
  ReadResult: TCoreResult;
begin
  CanonicalPath := NormalizeCorePath(SourcePath);
  ExistingIndex := FindFileIndexByCanonicalPath(CanonicalPath);
  if ExistingIndex >= 0 then
    Exit(FFiles[ExistingIndex].FileId);

  ReadResult := TryReadCoreTextFile(CanonicalPath, LoadedCanonicalPath, SourceText);
  if not CoreResultIsOk(ReadResult) then
    raise Exception.Create(
      'source-database.read-failed: ' + CoreResultCodeName(ReadResult.Code) +
      ': ' + ReadResult.Detail
    );
  CanonicalPath := LoadedCanonicalPath;

  EntryIndex := Length(FFiles);
  SetLength(FFiles, EntryIndex + 1);
  FFiles[EntryIndex].FileId := EntryIndex + 1;
  FFiles[EntryIndex].DisplayPath := SourcePath;
  FFiles[EntryIndex].CanonicalPath := CanonicalPath;
  FFiles[EntryIndex].SourceText := SourceText;
  Result := FFiles[EntryIndex].FileId;
end;

function TSourceDatabase.FileCount: LongInt;
begin
  Result := Length(FFiles);
end;

function TSourceDatabase.LineIndexState: string;
begin
  Result := FLineIndexState;
end;

function TSourceDatabase.RootFileId: TSourceFileId;
begin
  if Length(FFiles) = 0 then
    Exit(0);

  Result := FFiles[0].FileId;
end;

function TSourceDatabase.RootSourceText: string;
begin
  if Length(FFiles) = 0 then
    Exit('');

  Result := FFiles[0].SourceText;
end;

function TSourceDatabase.RootSourceCanonicalPath: string;
begin
  if Length(FFiles) = 0 then
    Exit('');

  Result := FFiles[0].CanonicalPath;
end;

function TSourceDatabase.CanonicalPathForFileId(
  const AFileId: TSourceFileId
): string;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FFiles) - 1 do
    if FFiles[Index].FileId = AFileId then
      Exit(FFiles[Index].CanonicalPath);

  Result := '';
end;

function TSourceDatabase.SourceTextForFileId(
  const AFileId: TSourceFileId
): string;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FFiles) - 1 do
    if FFiles[Index].FileId = AFileId then
      Exit(FFiles[Index].SourceText);

  Result := '';
end;

end.
