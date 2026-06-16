unit nextpas.core.config.export;
{**
 * @desc Config export helpers for INI/JSON/YAML/TOML serialization.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.config,
  nextpas.core.ini,
  nextpas.core.json.writer,
  nextpas.core.yaml.builder,
  nextpas.core.toml.writer,
  nextpas.core.text.builder;

type
  TConfigExportNode = class;

  TConfigJsonChild = record
    Name: string;
    Node: TConfigExportNode;
  end;

  TConfigExportNode = class
  private
    FHasScalar: Boolean;
    FScalarValue: string;
    FChildren: array of TConfigJsonChild;
    FChildCount: Integer;
    function FindChildIndex(const AName: string): Integer;
    function RequireChild(const AName: string): TConfigExportNode;
    function IsDenseArray(out ACount: Integer): Boolean;
  public
    destructor Destroy; override;
    procedure SetScalar(const AValue: string);
    procedure AddPath(const AKey, AValue: string);
    procedure WriteJson(var AWriter: TJsonWriter; const APath: string);
    procedure BuildYaml(var ABuilder: TYamlBuilder; const APath: string);
  end;

function ConfigEntriesToJson(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
function ConfigEntriesToYaml(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
function ConfigEntriesToToml(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
function ConfigEntriesToIni(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
procedure ConfigWriteAtomicText(const APath, AText: string);

implementation

uses
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.platform.files.base,
  nextpas.core.text.conv,
  nextpas.core.text.number;

function JoinExportKey(const APrefix, AKey: string): string;
begin
  if APrefix = '' then
    Result := AKey
  else
    Result := APrefix + '.' + AKey;
end;

destructor TConfigExportNode.Destroy;
var
  LI: Integer;
begin
  for LI := 0 to FChildCount - 1 do
    FChildren[LI].Node.Free;
  FChildren := nil;
  inherited Destroy;
end;

function TConfigExportNode.FindChildIndex(const AName: string): Integer;
var
  LI: Integer;
  LLower: string;
begin
  LLower := LowerCase(AName);
  for LI := 0 to FChildCount - 1 do
    if LowerCase(FChildren[LI].Name) = LLower then
      Exit(LI);
  Result := -1;
end;

function TConfigExportNode.RequireChild(const AName: string): TConfigExportNode;
var
  LIdx: Integer;
begin
  LIdx := FindChildIndex(AName);
  if LIdx >= 0 then
    Exit(FChildren[LIdx].Node);

  if FChildCount >= Length(FChildren) then
    SetLength(FChildren, FChildCount + 8);

  FChildren[FChildCount].Name := AName;
  FChildren[FChildCount].Node := TConfigExportNode.Create;
  Result := FChildren[FChildCount].Node;
  Inc(FChildCount);
end;

function TConfigExportNode.IsDenseArray(out ACount: Integer): Boolean;
var
  LI: Integer;
  LIdx: Int64;
  LMax: Int64;
begin
  ACount := 0;
  if FChildCount = 0 then
    Exit(False);

  LMax := -1;
  for LI := 0 to FChildCount - 1 do
  begin
    if not TryParseArrayIndex(FChildren[LI].Name, LIdx) then
      Exit(False);
    if LIdx > LMax then
      LMax := LIdx;
  end;

  if LMax <> FChildCount - 1 then
    Exit(False);

  for LI := 0 to FChildCount - 1 do
    if FindChildIndex(IntToStr(LI)) < 0 then
      Exit(False);

  ACount := FChildCount;
  Result := True;
end;

procedure TConfigExportNode.SetScalar(const AValue: string);
begin
  FHasScalar := True;
  FScalarValue := AValue;
end;

procedure TConfigExportNode.AddPath(const AKey, AValue: string);
var
  LNode: TConfigExportNode;
  LPos: Integer;
  LSegment: string;
begin
  RequireHierarchicalConfigPath(AKey);

  LNode := Self;
  LPos := 1;
  while NextConfigPathSegment(AKey, LPos, LSegment) do
  begin
    if LPos > Length(AKey) then
    begin
      LNode.RequireChild(LSegment).SetScalar(AValue);
      Exit;
    end;
    LNode := LNode.RequireChild(LSegment);
  end;
end;

procedure TConfigExportNode.WriteJson(var AWriter: TJsonWriter; const APath: string);
var
  LI: Integer;
  LCount: Integer;
  LChildPath: string;
begin
  if FHasScalar then
  begin
    if FChildCount > 0 then
      raise EConfigError.Create('config export conflict at "' +
        DisplayConfigPath(APath) + '": scalar and subtree cannot both be represented as a hierarchical config');
    AWriter.Str(FScalarValue);
    Exit;
  end;

  if IsDenseArray(LCount) then
  begin
    AWriter.BeginArray;
    for LI := 0 to LCount - 1 do
      FChildren[FindChildIndex(IntToStr(LI))].Node.WriteJson(AWriter,
        JoinExportKey(APath, IntToStr(LI)));
    AWriter.EndArray;
    Exit;
  end;

  AWriter.BeginObject;
  for LI := 0 to FChildCount - 1 do
  begin
    AWriter.Key(FChildren[LI].Name);
    LChildPath := JoinExportKey(APath, FChildren[LI].Name);
    FChildren[LI].Node.WriteJson(AWriter, LChildPath);
  end;
  AWriter.EndObject;
end;

procedure TConfigExportNode.BuildYaml(var ABuilder: TYamlBuilder; const APath: string);
var
  LI: Integer;
  LCount: Integer;
begin
  if FHasScalar then
  begin
    if FChildCount > 0 then
      raise EConfigError.Create('config export conflict at "' +
        DisplayConfigPath(APath) + '": scalar and subtree cannot both be represented as a hierarchical config');
    ABuilder.PutStr(FScalarValue);
    Exit;
  end;

  if IsDenseArray(LCount) then
  begin
    ABuilder.BeginSeq;
    for LI := 0 to LCount - 1 do
      FChildren[FindChildIndex(IntToStr(LI))].Node.BuildYaml(ABuilder,
        JoinExportKey(APath, IntToStr(LI)));
    ABuilder.EndSeq;
    Exit;
  end;

  ABuilder.BeginMap;
  for LI := 0 to FChildCount - 1 do
  begin
    ABuilder.PutKey(FChildren[LI].Name);
    FChildren[LI].Node.BuildYaml(ABuilder, JoinExportKey(APath, FChildren[LI].Name));
  end;
  ABuilder.EndMap;
end;

function ConfigEntriesToJson(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
var
  LRoot: TConfigExportNode;
  LBuilder: TStringBuilder;
  LWriter: TJsonWriter;
  LI: Integer;
begin
  LRoot := TConfigExportNode.Create;
  try
    for LI := 0 to ACount - 1 do
      LRoot.AddPath(AEntries[LI].Key, AEntries[LI].Value);

    LBuilder.Init(ACount * 32 + 2);
    try
      LWriter.Init(LBuilder);
      LRoot.WriteJson(LWriter, '');
      Result := LBuilder.ToString;
    finally
      LBuilder.Done;
    end;
  finally
    LRoot.Free;
  end;
end;

function ConfigEntriesToYaml(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
var
  LRoot: TConfigExportNode;
  LBuilder: TYamlBuilder;
  LI: Integer;
begin
  LRoot := TConfigExportNode.Create;
  try
    for LI := 0 to ACount - 1 do
      LRoot.AddPath(AEntries[LI].Key, AEntries[LI].Value);

    LBuilder.Init;
    try
      LRoot.BuildYaml(LBuilder, '');
      Result := LBuilder.Stringify;
    finally
      LBuilder.Done;
    end;
  finally
    LRoot.Free;
  end;
end;

function ConfigEntriesToToml(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
var
  LBuilder: TStringBuilder;
  LWriter: TTomlWriter;
  LI: Integer;
begin
  LBuilder.Init(256);
  try
    LWriter.Init(LBuilder);
    for LI := 0 to ACount - 1 do
    begin
      LWriter.Key(AEntries[LI].Key);
      LWriter.Str(AEntries[LI].Value);
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function ContainsIniLineBreak(const AValue: string): Boolean;
var
  LI: Integer;
begin
  for LI := 1 to Length(AValue) do
    if (AValue[LI] = #10) or (AValue[LI] = #13) then
      Exit(True);
  Result := False;
end;

function HasIniTrimmedEdgeWhitespace(const AValue: string): Boolean;
begin
  Result := (AValue <> '') and
    (((AValue[1] = ' ') or (AValue[1] = #9)) or
     ((AValue[Length(AValue)] = ' ') or (AValue[Length(AValue)] = #9)));
end;

function IsIniSectionNameRepresentable(const ASection: string): Boolean;
begin
  Result := (ASection <> '') and
    (not ContainsIniLineBreak(ASection)) and
    (not HasIniTrimmedEdgeWhitespace(ASection)) and
    (Pos(']', ASection) = 0);
end;

function IsIniKeyNameRepresentable(const AKey: string): Boolean;
begin
  Result := (AKey <> '') and
    (not ContainsIniLineBreak(AKey)) and
    (not HasIniTrimmedEdgeWhitespace(AKey)) and
    (Pos('=', AKey) = 0) and
    (AKey[1] <> '[') and
    (AKey[1] <> ';') and
    (AKey[1] <> '#');
end;

function TryMapConfigKeyToIniPath(const AConfigKey: string; out ASection,
  AKey: string): Boolean;
var
  LDotPos: Integer;
  LSection: string;
  LKey: string;
begin
  for LDotPos := Length(AConfigKey) downto 1 do
    if AConfigKey[LDotPos] = '.' then
    begin
      LSection := Copy(AConfigKey, 1, LDotPos - 1);
      LKey := Copy(AConfigKey, LDotPos + 1,
        Length(AConfigKey) - LDotPos);
      if IsIniSectionNameRepresentable(LSection) and
         IsIniKeyNameRepresentable(LKey) then
      begin
        ASection := LSection;
        AKey := LKey;
        Exit(True);
      end;
    end;

  if IsIniKeyNameRepresentable(AConfigKey) then
  begin
    ASection := '';
    AKey := AConfigKey;
    Exit(True);
  end;

  ASection := '';
  AKey := '';
  Result := False;
end;

function ConfigEntriesToIni(const AEntries: TConfigEntryArray;
  const ACount: Integer): string;
var
  LIni: TIniFile;
  LI: Integer;
  LSection: string;
  LKey: string;
begin
  LIni := TIniFile.Create;
  try
    for LI := 0 to ACount - 1 do
    begin
      if ContainsIniLineBreak(AEntries[LI].Value) then
        raise EConfigError.Create('config key "' + AEntries[LI].Key +
          '" cannot be exported to ini: value contains line breaks');
      if (AEntries[LI].Value <> '') and
         ((AEntries[LI].Value[1] = ' ') or (AEntries[LI].Value[1] = #9)) then
        raise EConfigError.Create('config key "' + AEntries[LI].Key +
          '" cannot be exported to ini: value has leading whitespace');
      if not TryMapConfigKeyToIniPath(AEntries[LI].Key, LSection, LKey) then
        raise EConfigError.Create('config key "' + AEntries[LI].Key +
          '" cannot be exported to ini: key is not representable');
      LIni.WriteString(LSection, LKey, AEntries[LI].Value);
    end;
    Result := LIni.ToString;
  finally
    LIni.Free;
  end;
end;

procedure ConfigWriteAtomicText(const APath, AText: string);
var
  LData: TBytes;
begin
  if Length(AText) > 0 then
  begin
    SetLength(LData, Length(AText));
    Move(PAnsiChar(AText)^, LData[0], Length(AText));
    WriteAtomic(APath, LData);
  end
  else
    WriteAtomic(APath, nil);
end;

end.
