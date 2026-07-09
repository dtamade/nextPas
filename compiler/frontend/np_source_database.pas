unit np_source_database;

{$mode objfpc}{$H+}
{$UNITPATH ../../rtl/core/base}
{$UNITPATH ../../rtl/core/text}

interface

uses
  nextpas.core.text.conv, nextpas.core.exception,
  np_base_types, np_text_primitives;

type
  TSourceFileId = TCoreId;

  TSourceFileEntry = record
    FileId: TSourceFileId;
    DisplayPath: string;
    CanonicalPath: string;
    SourceText: string;
    { Line offset table: LineOffsets[I] = byte offset of line I+1 start.
      Built lazily on first ByteOffsetToLineCol call. }
    LineOffsets: array of LongInt;
    LineIndexBuilt: Boolean;
  end;

  TLineCol = record
    Line: LongInt;
    Column: LongInt;
  end;

  TSourceDatabase = class
  private
    FFiles: array of TSourceFileEntry;
    FLineIndexState: string;
    function FindFileIndexByCanonicalPath(
      const ACanonicalPath: string
    ): LongInt;
    procedure BuildLineIndexForFile(AIndex: LongInt);
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
    { Convert byte offset to (Line, Column) for debug info.
      Line is 1-based, Column is 1-based (byte offset within line). }
    function ByteOffsetToLineCol(
      const AFileId: TSourceFileId;
      const AByteOffset: LongInt
    ): TLineCol;
    { Get display path for a file (for debug info filename). }
    function DisplayPathForFileId(const AFileId: TSourceFileId): string;
  end;

implementation

constructor TSourceDatabase.Create;
begin
  inherited Create;
  SetLength(FFiles, 0);
  FLineIndexState := 'available';
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
  FFiles[EntryIndex].LineIndexBuilt := False;
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

procedure TSourceDatabase.BuildLineIndexForFile(AIndex: LongInt);
var
  Src: string;
  I, Len, LineCount: LongInt;
begin
  if FFiles[AIndex].LineIndexBuilt then
    Exit;
  Src := FFiles[AIndex].SourceText;
  Len := Length(Src);
  { Worst case: every char is a newline → Len+1 entries }
  SetLength(FFiles[AIndex].LineOffsets, Len + 1);
  FFiles[AIndex].LineOffsets[0] := 0;  { Line 1 starts at offset 0 }
  LineCount := 1;
  I := 1;
  while I <= Len do
  begin
    if Src[I] = #10 then
    begin
      if LineCount >= Length(FFiles[AIndex].LineOffsets) then
        SetLength(FFiles[AIndex].LineOffsets, LineCount + 256);
      FFiles[AIndex].LineOffsets[LineCount] := I;  { next line starts after \n }
      Inc(LineCount);
      { Handle \r\n: skip the \r if it's before the \n }
    end
    else if (Src[I] = #13) and (I < Len) and (Src[I + 1] = #10) then
    begin
      { \r\n pair: line ends at \n, which is I+1 }
      if LineCount >= Length(FFiles[AIndex].LineOffsets) then
        SetLength(FFiles[AIndex].LineOffsets, LineCount + 256);
      FFiles[AIndex].LineOffsets[LineCount] := I + 1;
      Inc(LineCount);
      Inc(I);  { skip the \n }
    end
    else if (Src[I] = #13) then
    begin
      { Bare \r (old Mac style) }
      if LineCount >= Length(FFiles[AIndex].LineOffsets) then
        SetLength(FFiles[AIndex].LineOffsets, LineCount + 256);
      FFiles[AIndex].LineOffsets[LineCount] := I;
      Inc(LineCount);
    end;
    Inc(I);
  end;
  SetLength(FFiles[AIndex].LineOffsets, LineCount);
  FFiles[AIndex].LineIndexBuilt := True;
end;

function TSourceDatabase.ByteOffsetToLineCol(
  const AFileId: TSourceFileId;
  const AByteOffset: LongInt
): TLineCol;
var
  FileIdx, Lo, Hi, Mid: LongInt;
begin
  Result.Line := 1;
  Result.Column := 1;
  FileIdx := AFileId - 1;  { FileId is 1-based }
  if (FileIdx < 0) or (FileIdx >= Length(FFiles)) then
    Exit;
  BuildLineIndexForFile(FileIdx);
  { Binary search: find last line whose offset <= AByteOffset }
  Lo := 0;
  Hi := Length(FFiles[FileIdx].LineOffsets) - 1;
  Mid := 0;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if FFiles[FileIdx].LineOffsets[Mid] <= AByteOffset then
    begin
      Lo := Mid + 1;
    end
    else
      Hi := Mid - 1;
  end;
  { Hi is now the index of the line containing AByteOffset }
  if Hi < 0 then
    Hi := 0;
  Result.Line := Hi + 1;  { 1-based line number }
  Result.Column := AByteOffset - FFiles[FileIdx].LineOffsets[Hi] + 1;  { 1-based column }
end;

function TSourceDatabase.DisplayPathForFileId(
  const AFileId: TSourceFileId
): string;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FFiles) - 1 do
    if FFiles[Index].FileId = AFileId then
      Exit(FFiles[Index].DisplayPath);
  Result := '';
end;

end.
