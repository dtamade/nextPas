unit nextpas.compiler.frontend.source_database;

{$mode objfpc}{$H+}
{$UNITPATH ../../rtl/core/base}
{$UNITPATH ../../rtl/core/text}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.text.conv, nextpas.core.exception,
  nextpas.core.collections.vec,
  np_base_types, np_text_primitives;

type
  TSourceFileId = TCoreId;

  TSourceLineOffsetVec = specialize TVec<LongInt>;

  TSourceFileEntry = record
    FileId: TSourceFileId;
    DisplayPath: string;
    CanonicalPath: string;
    SourceText: string;
    { Line offset table: LineOffsets[I] = byte offset of line I+1 start.
      Built lazily on first ByteOffsetToLineCol call.
      Session-long entry ownership on the default heap. }
    LineOffsets: TSourceLineOffsetVec;
    LineIndexBuilt: Boolean;
  end;
  PSourceFileEntry = ^TSourceFileEntry;

  TSourceFileEntryVec = specialize TVec<TSourceFileEntry>;

  TLineCol = record
    Line: LongInt;
    Column: LongInt;
  end;

  TSourceDatabase = class
  private
    FFiles: TSourceFileEntryVec;
    FLineIndexState: string;
    function FindFileIndexByCanonicalPath(
      const ACanonicalPath: string
    ): LongInt;
    procedure BuildLineIndexForFile(AIndex: LongInt);
  public
    constructor Create;
    destructor Destroy; override;
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
  FFiles := TSourceFileEntryVec.Create;
  FLineIndexState := 'available';
end;

destructor TSourceDatabase.Destroy;
var
  Index: LongInt;
  Entry: PSourceFileEntry;
begin
  if FFiles <> nil then
  begin
    for Index := 0 to LongInt(FFiles.Count) - 1 do
    begin
      Entry := FFiles.GetPtr(SizeUInt(Index));
      Entry^.LineOffsets.Free;
      Entry^.LineOffsets := nil;
    end;
  end;
  FFiles.Free;
  FFiles := nil;
  inherited Destroy;
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
  if FFiles = nil then
    Exit(-1);
  for Index := 0 to LongInt(FFiles.Count) - 1 do
    if FFiles[SizeUInt(Index)].CanonicalPath = ACanonicalPath then
      Exit(Index);

  Result := -1;
end;

function TSourceDatabase.RegisterSource(const SourcePath: string): TSourceFileId;
var
  CanonicalPath: string;
  LoadedCanonicalPath: string;
  SourceText: string;
  Entry: TSourceFileEntry;
  ExistingIndex: LongInt;
  ReadResult: TCoreResult;
begin
  if FFiles = nil then
    FFiles := TSourceFileEntryVec.Create;
  CanonicalPath := NormalizeCorePath(SourcePath);
  ExistingIndex := FindFileIndexByCanonicalPath(CanonicalPath);
  if ExistingIndex >= 0 then
    Exit(FFiles[SizeUInt(ExistingIndex)].FileId);

  ReadResult := TryReadCoreTextFile(CanonicalPath, LoadedCanonicalPath, SourceText);
  if not CoreResultIsOk(ReadResult) then
    raise Exception.Create(
      'source-database.read-failed: ' + CoreResultCodeName(ReadResult.Code) +
      ': ' + ReadResult.Detail
    );
  CanonicalPath := LoadedCanonicalPath;

  Entry := Default(TSourceFileEntry);
  Entry.FileId := TSourceFileId(LongInt(FFiles.Count) + 1);
  Entry.DisplayPath := SourcePath;
  Entry.CanonicalPath := CanonicalPath;
  Entry.SourceText := SourceText;
  Entry.LineIndexBuilt := False;
  FFiles.Push(Entry);
  Result := Entry.FileId;
end;

function TSourceDatabase.FileCount: LongInt;
begin
  if FFiles = nil then
    Exit(0);
  Result := LongInt(FFiles.Count);
end;

function TSourceDatabase.LineIndexState: string;
begin
  Result := FLineIndexState;
end;

function TSourceDatabase.RootFileId: TSourceFileId;
begin
  if (FFiles = nil) or (FFiles.Count = 0) then
    Exit(0);

  Result := FFiles[0].FileId;
end;

function TSourceDatabase.RootSourceText: string;
begin
  if (FFiles = nil) or (FFiles.Count = 0) then
    Exit('');

  Result := FFiles[0].SourceText;
end;

function TSourceDatabase.RootSourceCanonicalPath: string;
begin
  if (FFiles = nil) or (FFiles.Count = 0) then
    Exit('');

  Result := FFiles[0].CanonicalPath;
end;

function TSourceDatabase.CanonicalPathForFileId(
  const AFileId: TSourceFileId
): string;
var
  Index: LongInt;
begin
  if FFiles = nil then
    Exit('');
  for Index := 0 to LongInt(FFiles.Count) - 1 do
    if FFiles[SizeUInt(Index)].FileId = AFileId then
      Exit(FFiles[SizeUInt(Index)].CanonicalPath);

  Result := '';
end;

function TSourceDatabase.SourceTextForFileId(
  const AFileId: TSourceFileId
): string;
var
  Index: LongInt;
begin
  if FFiles = nil then
    Exit('');
  for Index := 0 to LongInt(FFiles.Count) - 1 do
    if FFiles[SizeUInt(Index)].FileId = AFileId then
      Exit(FFiles[SizeUInt(Index)].SourceText);

  Result := '';
end;

procedure TSourceDatabase.BuildLineIndexForFile(AIndex: LongInt);
var
  Entry: PSourceFileEntry;
  Src: string;
  I, Len: LongInt;
begin
  Entry := FFiles.GetPtr(SizeUInt(AIndex));
  if Entry^.LineIndexBuilt then
    Exit;
  Src := Entry^.SourceText;
  Len := Length(Src);
  { Worst case: every char is a newline → Len+1 entries }
  if Entry^.LineOffsets = nil then
    Entry^.LineOffsets := TSourceLineOffsetVec.Create(SizeUInt(Len + 1))
  else
  begin
    Entry^.LineOffsets.Clear;
    Entry^.LineOffsets.EnsureCapacity(SizeUInt(Len + 1));
  end;
  Entry^.LineOffsets.Push(0);  { Line 1 starts at offset 0 }
  I := 1;
  while I <= Len do
  begin
    if Src[I] = #10 then
    begin
      Entry^.LineOffsets.Push(I);  { next line starts after \n }
      { Handle \r\n: skip the \r if it's before the \n }
    end
    else if (Src[I] = #13) and (I < Len) and (Src[I + 1] = #10) then
    begin
      { \r\n pair: line ends at \n, which is I+1 }
      Entry^.LineOffsets.Push(I + 1);
      Inc(I);  { skip the \n }
    end
    else if (Src[I] = #13) then
    begin
      { Bare \r (old Mac style) }
      Entry^.LineOffsets.Push(I);
    end;
    Inc(I);
  end;
  Entry^.LineIndexBuilt := True;
end;

function TSourceDatabase.ByteOffsetToLineCol(
  const AFileId: TSourceFileId;
  const AByteOffset: LongInt
): TLineCol;
var
  FileIdx, Lo, Hi, Mid: LongInt;
  Entry: PSourceFileEntry;
begin
  Result.Line := 1;
  Result.Column := 1;
  FileIdx := AFileId - 1;  { FileId is 1-based }
  if (FFiles = nil) or (FileIdx < 0) or (FileIdx >= LongInt(FFiles.Count)) then
    Exit;
  BuildLineIndexForFile(FileIdx);
  Entry := FFiles.GetPtr(SizeUInt(FileIdx));
  if (Entry^.LineOffsets = nil) or (Entry^.LineOffsets.Count = 0) then
    Exit;
  { Binary search: find last line whose offset <= AByteOffset }
  Lo := 0;
  Hi := LongInt(Entry^.LineOffsets.Count) - 1;
  Mid := 0;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if Entry^.LineOffsets[SizeUInt(Mid)] <= AByteOffset then
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
  Result.Column := AByteOffset - Entry^.LineOffsets[SizeUInt(Hi)] + 1;  { 1-based column }
end;

function TSourceDatabase.DisplayPathForFileId(
  const AFileId: TSourceFileId
): string;
var
  Index: LongInt;
begin
  if FFiles = nil then
    Exit('');
  for Index := 0 to LongInt(FFiles.Count) - 1 do
    if FFiles[SizeUInt(Index)].FileId = AFileId then
      Exit(FFiles[SizeUInt(Index)].DisplayPath);
  Result := '';
end;

end.
