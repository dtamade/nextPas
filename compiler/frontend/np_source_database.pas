unit np_source_database;

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
    function ResolveDiagnosticByteCount(
      const AFileId: TCoreId;
      const AByteOffset: LongInt
    ): LongInt;
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

function TSourceDatabase.ResolveDiagnosticByteCount(
  const AFileId: TCoreId;
  const AByteOffset: LongInt
): LongInt;
var
  Src: string;
  Len, StartIdx, Idx: LongInt;
  Ch, NextCh: Char;
  LineCol: TLineCol;
  Entry: PSourceFileEntry;
  NextLineStart: LongInt;
  FileIdx: LongInt;
  function IsIdentStart(const C: Char): Boolean; inline;
  begin Result := (C in ['A'..'Z', 'a'..'z', '_']); end;
  function IsIdentCont(const C: Char): Boolean; inline;
  begin Result := (C in ['A'..'Z', 'a'..'z', '0'..'9', '_']); end;
begin
  Result := 1;
  if (AFileId <= 0) or (AByteOffset < 0) then Exit(0);
  Src := SourceTextForFileId(AFileId);
  Len := Length(Src);
  if Len = 0 then Exit(1);
  StartIdx := AByteOffset + 1;
  if (StartIdx < 1) or (StartIdx > Len) then Exit(1);
  Ch := Src[StartIdx];
  if StartIdx < Len then
  begin
    NextCh := Src[StartIdx + 1];
    if ((Ch = ':') and (NextCh = '=')) or ((Ch = '<') and (NextCh = '>')) or ((Ch = '<') and (NextCh = '=')) or ((Ch = '>') and (NextCh = '=')) or ((Ch = '.') and (NextCh = '.')) or ((Ch = '+') and (NextCh = '=')) or ((Ch = '-') and (NextCh = '=')) or ((Ch = '*') and (NextCh = '=')) or ((Ch = '/') and (NextCh = '=')) then Exit(2);
  end;
  if IsIdentStart(Ch) then
  begin
    Idx := StartIdx + 1;
    while (Idx <= Len) and IsIdentCont(Src[Idx]) do Inc(Idx);
    Result := Idx - StartIdx;
    if Result < 1 then Result := 1;
    Exit;
  end;
  if (Ch in ['0'..'9']) then
  begin
    Idx := StartIdx + 1;
    while (Idx <= Len) and (Src[Idx] in ['0'..'9', 'A'..'F', 'a'..'f', '_']) do Inc(Idx);
    if (Idx <= Len) and (Src[Idx] = '.') and (Idx < Len) and (Src[Idx+1] in ['0'..'9']) then
    begin
      Inc(Idx);
      while (Idx <= Len) and (Src[Idx] in ['0'..'9']) do Inc(Idx);
      if (Idx <= Len) and (Src[Idx] in ['e','E']) then
      begin
        Inc(Idx);
        if (Idx <= Len) and (Src[Idx] in ['+','-']) then Inc(Idx);
        while (Idx <= Len) and (Src[Idx] in ['0'..'9']) do Inc(Idx);
      end;
    end else if (Idx <= Len) and (Src[Idx] in ['e','E']) then
    begin
      Inc(Idx);
      if (Idx <= Len) and (Src[Idx] in ['+','-']) then Inc(Idx);
      while (Idx <= Len) and (Src[Idx] in ['0'..'9']) do Inc(Idx);
    end;
    Result := Idx - StartIdx;
    if Result < 1 then Result := 1;
    Exit;
  end;
  if (Ch = '$') and (StartIdx < Len) and (Src[StartIdx+1] in ['0'..'9','A'..'F','a'..'f']) then
  begin
    Idx := StartIdx + 2;
    while (Idx <= Len) and (Src[Idx] in ['0'..'9','A'..'F','a'..'f']) do Inc(Idx);
    Exit(Idx - StartIdx);
  end;
  if (Ch = '&') and (StartIdx < Len) and (Src[StartIdx+1] in ['0'..'7']) then
  begin
    Idx := StartIdx + 2;
    while (Idx <= Len) and (Src[Idx] in ['0'..'7']) do Inc(Idx);
    Exit(Idx - StartIdx);
  end;
  if (Ch = '%') and (StartIdx < Len) and (Src[StartIdx+1] in ['0','1']) then
  begin
    Idx := StartIdx + 2;
    while (Idx <= Len) and (Src[Idx] in ['0','1']) do Inc(Idx);
    Exit(Idx - StartIdx);
  end;
  if Ch = '''' then
  begin
    Idx := StartIdx + 1;
    while Idx <= Len do
    begin
      if Src[Idx] = '''' then
      begin
        Inc(Idx);
        if (Idx <= Len) and (Src[Idx] = '''') then Inc(Idx) else Break;
      end else if Src[Idx] in [#10,#13] then Break else Inc(Idx);
    end;
    Result := Idx - StartIdx;
    if Result < 1 then Result := 1;
    Exit;
  end;
  if Ch = '#' then
  begin
    Idx := StartIdx + 1;
    if (Idx <= Len) and (Src[Idx] = '$') then
    begin
      Inc(Idx);
      while (Idx <= Len) and (Src[Idx] in ['0'..'9','A'..'F','a'..'f']) do Inc(Idx);
    end else while (Idx <= Len) and (Src[Idx] in ['0'..'9']) do Inc(Idx);
    while (Idx <= Len) and (Src[Idx] = '''') do
    begin
      Inc(Idx);
      while (Idx <= Len) and (Src[Idx] <> '''') and not (Src[Idx] in [#10,#13]) do Inc(Idx);
      if (Idx <= Len) and (Src[Idx] = '''') then
      begin Inc(Idx); if (Idx <= Len) and (Src[Idx] = '''') then Inc(Idx) else Break; end else Break;
    end;
    Result := Idx - StartIdx;
    if Result < 1 then Result := 1;
    Exit;
  end;
  if Ch in [';',',',':','=','<','>','+','-','*','/','(',')','[',']','@','^','.', '#','$'] then Exit(1);
  if Ch in [#9,#10,#13,' '] then
  begin
    FileIdx := AFileId - 1;
    if (FFiles <> nil) and (FileIdx >=0) and (FileIdx < LongInt(FFiles.Count)) then
    begin
      BuildLineIndexForFile(FileIdx);
      Entry := FFiles.GetPtr(SizeUInt(FileIdx));
      LineCol := ByteOffsetToLineCol(AFileId, AByteOffset);
      if LineCol.Line < LongInt(Entry^.LineOffsets.Count) then
        NextLineStart := Entry^.LineOffsets[SizeUInt(LineCol.Line)]
      else NextLineStart := Len;
      Result := NextLineStart - AByteOffset;
      while (Result > 1) and (StartIdx + Result -1 <= Len) and (Src[StartIdx+Result-1] in [#10,#13]) do Dec(Result);
      if Result < 1 then Result := 1;
      if Result > 80 then Result := 1;
      Exit;
    end;
    Exit(1);
  end;
  Result := 1;
end;

end.
