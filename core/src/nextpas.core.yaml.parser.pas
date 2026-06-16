unit nextpas.core.yaml.parser;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.number,
  nextpas.core.mem.intf,
  nextpas.core.yaml.types,
  nextpas.core.yaml.scanner;

type
  TYamlAnchorEntry = record
    Name: TStringView;
    NodeIdx: UInt32;
  end;
  PYamlAnchorEntry = ^TYamlAnchorEntry;

  TYamlDocument = record
  private
    FNodes: PYamlNode;
    FNodeCount: UInt32;
    FNodeCap: UInt32;
    FRootIdx: UInt32;
    FAnchors: PYamlAnchorEntry;
    FAnchorCount: UInt32;
    FAnchorCap: UInt32;
    FAllocator: IAllocator;
    FParseDepth: Int32;
    FError: TYamlError;
    FHasError: Boolean;
    FInitMagic: QWord;
    procedure RegisterAnchor(const AName: TStringView; ANodeIdx: UInt32);
  public
    procedure Init(const AAllocator: IAllocator);
    procedure Done;
    function AddNode: UInt32;
    function Node(AIdx: UInt32): PYamlNode; inline;
    function NodeCount: UInt32; inline;
    function Root: UInt32; inline;
    procedure SetRoot(AIdx: UInt32); inline;
    function AnchorEntry(AIdx: UInt32): PYamlAnchorEntry; inline;
    function AnchorCount: UInt32; inline;
    function HasError: Boolean; inline;
    function Error: TYamlError; inline;
    function ParseDepth: Int32; inline;
    function Allocator: IAllocator; inline;
    procedure SetError(const AMsg: string; const ALine, ACol: UInt32;
      const AOffset: SizeUInt);
  end;

procedure YamlDocInit(var ADoc: TYamlDocument);
procedure YamlDocInitWith(var ADoc: TYamlDocument; const AAllocator: IAllocator);
procedure YamlDocParse(var ADoc: TYamlDocument; const AInput: PAnsiChar; const ALen: SizeUInt);
procedure YamlDocParseWith(var ADoc: TYamlDocument; const AInput: PAnsiChar; const ALen: SizeUInt;
  const AAllocator: IAllocator);
procedure YamlDocParseView(var ADoc: TYamlDocument; const AView: TStringView);
procedure YamlDocParseViewWith(var ADoc: TYamlDocument; const AView: TStringView;
  const AAllocator: IAllocator);

implementation

uses
  nextpas.core.mem.default;

const
  INITIAL_CAPACITY = 64;
  YAML_DOCUMENT_INIT_MAGIC = QWord($59414D4C444F4331);

procedure TYamlDocument.Init(const AAllocator: IAllocator);
var
  LPtr: Pointer;
begin
  if AAllocator = nil then
    FAllocator := DefaultAllocator
  else
    FAllocator := AAllocator;
  FNodeCap := INITIAL_CAPACITY;
  FNodes := nil;
  FNodeCount := 0;
  FRootIdx := 0;
  FAnchorCap := 16;
  FAnchors := nil;
  FAnchorCount := 0;
  FParseDepth := 0;
  FError.Message := TStringView.Empty;
  FError.Line := 0;
  FError.Col := 0;
  FError.Offset := 0;
  FHasError := False;
  FInitMagic := YAML_DOCUMENT_INIT_MAGIC;
  LPtr := FAllocator.GetMem(FNodeCap * SizeOf(TYamlNode));
  if LPtr = nil then
  begin
    SetError('out of memory', 0, 0, 0);
    Exit;
  end;
  FNodes := PYamlNode(LPtr);

  LPtr := FAllocator.GetMem(FAnchorCap * SizeOf(TYamlAnchorEntry));
  if LPtr = nil then
  begin
    FAllocator.FreeMem(Pointer(FNodes));
    FNodes := nil;
    SetError('out of memory', 0, 0, 0);
    Exit;
  end;
  FAnchors := PYamlAnchorEntry(LPtr);
end;

procedure TYamlDocument.Done;
begin
  if FInitMagic <> YAML_DOCUMENT_INIT_MAGIC then
    Exit;
  if FNodes <> nil then
  begin
    FAllocator.FreeMem(Pointer(FNodes));
    FNodes := nil;
  end;
  FNodeCap := 0;
  FNodeCount := 0;
  if FAnchors <> nil then
  begin
    FAllocator.FreeMem(Pointer(FAnchors));
    FAnchors := nil;
  end;
  FAnchorCap := 0;
  FAnchorCount := 0;
  FParseDepth := 0;
  FRootIdx := 0;
  FError.Message := TStringView.Empty;
  FError.Line := 0;
  FError.Col := 0;
  FError.Offset := 0;
  FHasError := False;
  FAllocator := nil;
  FInitMagic := 0;
end;

function TYamlDocument.AddNode: UInt32;
var
  LNewCap: UInt32;
  LNewPtr: Pointer;
begin
  Result := FNodeCount;
  if FNodeCount >= FNodeCap then
  begin
    LNewCap := FNodeCap * 2;
    LNewPtr := FAllocator.ReallocMem(Pointer(FNodes),
      LNewCap * SizeOf(TYamlNode));
    if LNewPtr = nil then
    begin
      SetError('out of memory', 0, 0, 0);
      Exit(YAML_NODE_NONE);
    end;
    FNodes := PYamlNode(LNewPtr);
    FNodeCap := LNewCap;
  end;
  FillChar(FNodes[Result], SizeOf(TYamlNode), 0);
  FNodes[Result].Next := YAML_NODE_NONE;
  Inc(FNodeCount);
end;

procedure TYamlDocument.RegisterAnchor(const AName: TStringView; ANodeIdx: UInt32);
var
  LNewCap: UInt32;
  LNewPtr: Pointer;
begin
  if FAnchorCount >= FAnchorCap then
  begin
    LNewCap := FAnchorCap * 2;
    LNewPtr := FAllocator.ReallocMem(Pointer(FAnchors),
      LNewCap * SizeOf(TYamlAnchorEntry));
    if LNewPtr = nil then
    begin
      SetError('out of memory', 0, 0, 0);
      Exit;
    end;
    FAnchors := PYamlAnchorEntry(LNewPtr);
    FAnchorCap := LNewCap;
  end;
  FAnchors[FAnchorCount].Name := AName;
  FAnchors[FAnchorCount].NodeIdx := ANodeIdx;
  Inc(FAnchorCount);
end;

function TYamlDocument.Node(AIdx: UInt32): PYamlNode;
begin
  Result := @FNodes[AIdx];
end;

function TYamlDocument.NodeCount: UInt32;
begin
  Result := FNodeCount;
end;

function TYamlDocument.Root: UInt32;
begin
  Result := FRootIdx;
end;

procedure TYamlDocument.SetRoot(AIdx: UInt32);
begin
  FRootIdx := AIdx;
end;

function TYamlDocument.AnchorEntry(AIdx: UInt32): PYamlAnchorEntry;
begin
  Result := @FAnchors[AIdx];
end;

function TYamlDocument.AnchorCount: UInt32;
begin
  Result := FAnchorCount;
end;

function TYamlDocument.HasError: Boolean;
begin
  Result := FHasError;
end;

function TYamlDocument.Error: TYamlError;
begin
  Result := FError;
end;

function TYamlDocument.ParseDepth: Int32;
begin
  Result := FParseDepth;
end;

function TYamlDocument.Allocator: IAllocator;
begin
  Result := FAllocator;
end;

procedure TYamlDocument.SetError(const AMsg: string; const ALine, ACol: UInt32;
  const AOffset: SizeUInt);
begin
  FHasError := True;
  FError.Message := TStringView.FromStr(AMsg);
  FError.Line := ALine;
  FError.Col := ACol;
  FError.Offset := AOffset;
end;

procedure YamlDocInit(var ADoc: TYamlDocument);
begin
  ADoc.Init(DefaultAllocator);
end;

procedure YamlDocInitWith(var ADoc: TYamlDocument; const AAllocator: IAllocator);
begin
  ADoc.Init(AAllocator);
end;

procedure PrepareYamlDocumentForParse(var ADoc: TYamlDocument);
begin
  if ADoc.FInitMagic = YAML_DOCUMENT_INIT_MAGIC then
  begin
    if ADoc.FNodes <> nil then
    begin
      ADoc.Done;
      Exit;
    end
    else
      FillChar(ADoc, SizeOf(ADoc), 0);
    Exit;
  end;
  FillChar(ADoc, SizeOf(ADoc), 0);
end;

function ResolveAlias(var ADoc: TYamlDocument; const AName: TStringView): UInt32;
var
  LI: UInt32;
begin
  for LI := 1 to ADoc.FAnchorCount do
    if ADoc.FAnchors[LI - 1].Name.Equals(AName) then
    begin
      Result := ADoc.FAnchors[LI - 1].NodeIdx;
      Exit;
    end;
  Result := YAML_NODE_NONE;
end;

function AliasResolutionDepthExceedsLimit(const ADoc: TYamlDocument;
  ANodeIdx: UInt32): Boolean;
var
  LIdx: UInt32;
  LDepth: UInt32;
begin
  Result := False;
  LIdx := ANodeIdx;
  LDepth := 1;
  while (LIdx < ADoc.FNodeCount) and (ADoc.FNodes[LIdx].Kind = ynkAlias) do
  begin
    if LDepth >= YAML_ALIAS_RESOLUTION_DEPTH_LIMIT then
      Exit(True);
    LIdx := ADoc.FNodes[LIdx].AliasTarget;
    Inc(LDepth);
  end;
end;

function IsBareMergeKeyToken(const AToken: TYamlToken): Boolean;
begin
  Result :=
    (AToken.Kind = ytkScalar) and
    (AToken.Style = yssPlain) and
    (AToken.Value.Len = 2) and
    (AToken.Value.Data <> nil) and
    (AToken.Value.Data[0] = '<') and
    (AToken.Value.Data[1] = '<');
end;

procedure SetUnsupportedMergeKeyError(var ADoc: TYamlDocument;
  const AToken: TYamlToken);
begin
  ADoc.SetError('YAML merge keys are not supported',
    AToken.Line, AToken.Col, AToken.Offset);
end;

procedure SetUnsupportedExplicitMappingKeyError(var ADoc: TYamlDocument;
  const AToken: TYamlToken);
begin
  ADoc.SetError('YAML explicit mapping keys are not supported',
    AToken.Line, AToken.Col, AToken.Offset);
end;

function MappingContainsKey(const ADoc: TYamlDocument; AFirstKeyIdx: UInt32;
  const AKey: TStringView): Boolean;
var
  LCur: UInt32;
begin
  Result := False;
  LCur := AFirstKeyIdx;
  while LCur <> YAML_NODE_NONE do
  begin
    if (ADoc.FNodes[LCur].Kind = ynkString) and
       ADoc.FNodes[LCur].Str.Equals(AKey) then
    begin
      Result := True;
      Exit;
    end;
    if ADoc.FNodes[LCur].Next = YAML_NODE_NONE then
      Exit;
    LCur := ADoc.FNodes[ADoc.FNodes[LCur].Next].Next;
  end;
end;

procedure SetDuplicateMappingKeyError(var ADoc: TYamlDocument;
  const AToken: TYamlToken);
begin
  ADoc.SetError('duplicate mapping key',
    AToken.Line, AToken.Col, AToken.Offset);
end;

function TryParseHex(const AView: TStringView; out AValue: Int64): Boolean;
var
  LI: SizeUInt;
  LCh: Byte;
  LDigit: Int32;
begin
  Result := False;
  AValue := 0;
  if AView.Len <= 2 then Exit;
  for LI := 2 to AView.Len - 1 do
  begin
    LCh := Byte(AView.Data[LI]);
    if (LCh >= Byte('0')) and (LCh <= Byte('9')) then
      LDigit := LCh - Byte('0')
    else if (LCh >= Byte('a')) and (LCh <= Byte('f')) then
      LDigit := LCh - Byte('a') + 10
    else if (LCh >= Byte('A')) and (LCh <= Byte('F')) then
      LDigit := LCh - Byte('A') + 10
    else if LCh = Byte('_') then
      Continue
    else
      Exit;
    AValue := (AValue shl 4) or LDigit;
  end;
  Result := True;
end;

function TryParseOctal(const AView: TStringView; out AValue: Int64): Boolean;
var
  LI: SizeUInt;
  LCh: Byte;
begin
  Result := False;
  AValue := 0;
  if AView.Len <= 2 then Exit;
  for LI := 2 to AView.Len - 1 do
  begin
    LCh := Byte(AView.Data[LI]);
    if (LCh >= Byte('0')) and (LCh <= Byte('7')) then
      AValue := (AValue shl 3) or (LCh - Byte('0'))
    else if LCh = Byte('_') then
      Continue
    else
      Exit;
  end;
  Result := True;
end;

function ResolveScalar(const AValue: TStringView; const AStyle: TYamlScalarStyle;
  var ADoc: TYamlDocument): UInt32;
var
  LIdx: UInt32;
  LStr: string;
  LInt: Int64;
  LFloat: Double;
begin
  LIdx := ADoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    Exit(YAML_NODE_NONE);

  if AStyle <> yssPlain then
  begin
    ADoc.FNodes[LIdx].Kind := ynkString;
    ADoc.FNodes[LIdx].Str := AValue;
    Result := LIdx;
    Exit;
  end;

  if AValue.IsEmpty then
  begin
    ADoc.FNodes[LIdx].Kind := ynkNull;
    Result := LIdx;
    Exit;
  end;

  LStr := AValue.ToString;

  // Null
  if (LStr = 'null') or (LStr = 'Null') or (LStr = 'NULL') or (LStr = '~') then
  begin
    ADoc.FNodes[LIdx].Kind := ynkNull;
    Result := LIdx;
    Exit;
  end;

  // Bool
  if (LStr = 'true') or (LStr = 'True') or (LStr = 'TRUE') then
  begin
    ADoc.FNodes[LIdx].Kind := ynkBool;
    ADoc.FNodes[LIdx].BoolVal := True;
    Result := LIdx;
    Exit;
  end;
  if (LStr = 'false') or (LStr = 'False') or (LStr = 'FALSE') then
  begin
    ADoc.FNodes[LIdx].Kind := ynkBool;
    ADoc.FNodes[LIdx].BoolVal := False;
    Result := LIdx;
    Exit;
  end;

  // Int
  if ViewToInt64(AValue, LInt) then
  begin
    ADoc.FNodes[LIdx].Kind := ynkInt;
    ADoc.FNodes[LIdx].IntVal := LInt;
    Result := LIdx;
    Exit;
  end;

  // Hex int (0x...)
  if (AValue.Len > 2) and (AValue.Data[0] = '0') and
     ((AValue.Data[1] = 'x') or (AValue.Data[1] = 'X')) then
  begin
    LInt := 0;
    if TryParseHex(AValue, LInt) then
    begin
      ADoc.FNodes[LIdx].Kind := ynkInt;
      ADoc.FNodes[LIdx].IntVal := LInt;
      Result := LIdx;
      Exit;
    end;
  end;

  // Octal int (0o...)
  if (AValue.Len > 2) and (AValue.Data[0] = '0') and
     ((AValue.Data[1] = 'o') or (AValue.Data[1] = 'O')) then
  begin
    LInt := 0;
    if TryParseOctal(AValue, LInt) then
    begin
      ADoc.FNodes[LIdx].Kind := ynkInt;
      ADoc.FNodes[LIdx].IntVal := LInt;
      Result := LIdx;
      Exit;
    end;
  end;

  // Float
  if (LStr = '.inf') or (LStr = '.Inf') or (LStr = '.INF') or
     (LStr = '+.inf') or (LStr = '+.Inf') or (LStr = '+.INF') then
  begin
    ADoc.FNodes[LIdx].Kind := ynkFloat;
    ADoc.FNodes[LIdx].RealVal := 1.0 / 0.0;
    Result := LIdx;
    Exit;
  end;
  if (LStr = '-.inf') or (LStr = '-.Inf') or (LStr = '-.INF') then
  begin
    ADoc.FNodes[LIdx].Kind := ynkFloat;
    ADoc.FNodes[LIdx].RealVal := -1.0 / 0.0;
    Result := LIdx;
    Exit;
  end;
  if (LStr = '.nan') or (LStr = '.NaN') or (LStr = '.NAN') then
  begin
    ADoc.FNodes[LIdx].Kind := ynkFloat;
    ADoc.FNodes[LIdx].RealVal := 0.0 / 0.0;
    Result := LIdx;
    Exit;
  end;

  if ViewToDouble(AValue, LFloat) then
  begin
    ADoc.FNodes[LIdx].Kind := ynkFloat;
    ADoc.FNodes[LIdx].RealVal := LFloat;
    Result := LIdx;
    Exit;
  end;

  // Default: string
  ADoc.FNodes[LIdx].Kind := ynkString;
  ADoc.FNodes[LIdx].Str := AValue;
  Result := LIdx;
end;

{ Forward declarations }
function ParseNode(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken): UInt32; forward;

function ParseBlockSequence(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken): UInt32;
var
  LIdx, LFirst, LPrev, LChild: UInt32;
  LCount: UInt32;
begin
  LIdx := ADoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    Exit(YAML_NODE_NONE);
  ADoc.FNodes[LIdx].Kind := ynkSequence;

  LFirst := YAML_NODE_NONE;
  LPrev := YAML_NODE_NONE;
  LCount := 0;

  while ACurToken.Kind = ytkBlockSeqStart do
  begin
    ACurToken := AScanner.NextToken; // consume - indicator
    LChild := ParseNode(ADoc, AScanner, ACurToken);
    if ADoc.FHasError then begin Result := LIdx; Exit; end;

    if LFirst = YAML_NODE_NONE then
      LFirst := LChild
    else
      ADoc.FNodes[LPrev].Next := LChild;
    LPrev := LChild;
    Inc(LCount);
  end;

  if ACurToken.Kind = ytkBlockEnd then
    ACurToken := AScanner.NextToken;

  ADoc.FNodes[LIdx].Container.FirstChild := LFirst;
  ADoc.FNodes[LIdx].Container.Count := LCount;
  Result := LIdx;
end;

function ParseBlockMapping(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken): UInt32;
var
  LIdx, LFirst, LPrev, LKeyNode, LValNode: UInt32;
  LCount: UInt32;
begin
  LIdx := ADoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    Exit(YAML_NODE_NONE);
  ADoc.FNodes[LIdx].Kind := ynkMapping;
  ACurToken := AScanner.NextToken; // consume BlockMapStart

  LFirst := YAML_NODE_NONE;
  LPrev := YAML_NODE_NONE;
  LCount := 0;

  while (ACurToken.Kind <> ytkBlockEnd) and (ACurToken.Kind <> ytkStreamEnd) and
        (ACurToken.Kind <> ytkDocEnd) and (ACurToken.Kind <> ytkError) do
  begin
    // Key
    if ACurToken.Kind = ytkKey then
      ACurToken := AScanner.NextToken;

    if ACurToken.Kind = ytkScalar then
    begin
      if IsBareMergeKeyToken(ACurToken) then
      begin
        SetUnsupportedMergeKeyError(ADoc, ACurToken);
        Result := LIdx;
        Exit;
      end;
      if MappingContainsKey(ADoc, LFirst, ACurToken.Value) then
      begin
        SetDuplicateMappingKeyError(ADoc, ACurToken);
        Result := LIdx;
        Exit;
      end;
      LKeyNode := ADoc.AddNode;
      if LKeyNode = YAML_NODE_NONE then
      begin
        Result := LIdx;
        Exit;
      end;
      ADoc.FNodes[LKeyNode].Kind := ynkString;
      ADoc.FNodes[LKeyNode].Str := ACurToken.Value;
      ADoc.FNodes[LKeyNode].Next := YAML_NODE_NONE;
      ACurToken := AScanner.NextToken;
    end
    else
    begin
      ADoc.SetError('expected mapping key', ACurToken.Line, ACurToken.Col,
        ACurToken.Offset);
      Result := LIdx;
      Exit;
    end;

    // Value
    if ACurToken.Kind = ytkValue then
    begin
      ACurToken := AScanner.NextToken;
      LValNode := ParseNode(ADoc, AScanner, ACurToken);
      if ADoc.FHasError then begin Result := LIdx; Exit; end;
    end
    else
    begin
      LValNode := ADoc.AddNode;
      if LValNode = YAML_NODE_NONE then
      begin
        Result := LIdx;
        Exit;
      end;
      ADoc.FNodes[LValNode].Kind := ynkNull;
    end;

    ADoc.FNodes[LKeyNode].Next := LValNode;

    if LFirst = YAML_NODE_NONE then
      LFirst := LKeyNode
    else
      ADoc.FNodes[LPrev].Next := LKeyNode;
    LPrev := LValNode;
    Inc(LCount);
  end;

  if ACurToken.Kind = ytkBlockEnd then
    ACurToken := AScanner.NextToken;

  ADoc.FNodes[LIdx].Container.FirstChild := LFirst;
  ADoc.FNodes[LIdx].Container.Count := LCount;
  Result := LIdx;
end;

function ParseFlowSequence(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken): UInt32;
var
  LIdx, LFirst, LPrev, LChild: UInt32;
  LCount: UInt32;
begin
  LIdx := ADoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    Exit(YAML_NODE_NONE);
  ADoc.FNodes[LIdx].Kind := ynkSequence;
  ACurToken := AScanner.NextToken; // consume [

  LFirst := YAML_NODE_NONE;
  LPrev := YAML_NODE_NONE;
  LCount := 0;

  while (ACurToken.Kind <> ytkFlowSeqEnd) and (ACurToken.Kind <> ytkStreamEnd) and
        (ACurToken.Kind <> ytkError) do
  begin
    if (LCount > 0) then
    begin
      if ACurToken.Kind <> ytkFlowEntry then
      begin
        ADoc.SetError('expected "," or "]"', ACurToken.Line, ACurToken.Col,
          ACurToken.Offset);
        Result := LIdx;
        Exit;
      end;
      ACurToken := AScanner.NextToken; // consume ,
      if ACurToken.Kind = ytkFlowSeqEnd then
        Break; // trailing comma
    end;

    LChild := ParseNode(ADoc, AScanner, ACurToken);
    if ADoc.FHasError then begin Result := LIdx; Exit; end;

    if LFirst = YAML_NODE_NONE then
      LFirst := LChild
    else
      ADoc.FNodes[LPrev].Next := LChild;
    LPrev := LChild;
    Inc(LCount);
  end;

  if ACurToken.Kind = ytkFlowSeqEnd then
  begin
    ACurToken := AScanner.NextToken; // consume ]
  end
  else if (ACurToken.Kind = ytkStreamEnd) and (not ADoc.FHasError) then
  begin
    ADoc.SetError('expected "]"', ACurToken.Line, ACurToken.Col,
      ACurToken.Offset);
    Result := LIdx;
    Exit;
  end;

  ADoc.FNodes[LIdx].Container.FirstChild := LFirst;
  ADoc.FNodes[LIdx].Container.Count := LCount;
  Result := LIdx;
end;

function ParseFlowMapping(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken): UInt32;
var
  LIdx, LFirst, LPrev, LKeyNode, LValNode: UInt32;
  LCount: UInt32;
begin
  LIdx := ADoc.AddNode;
  if LIdx = YAML_NODE_NONE then
    Exit(YAML_NODE_NONE);
  ADoc.FNodes[LIdx].Kind := ynkMapping;
  ACurToken := AScanner.NextToken; // consume {

  LFirst := YAML_NODE_NONE;
  LPrev := YAML_NODE_NONE;
  LCount := 0;

  while (ACurToken.Kind <> ytkFlowMapEnd) and (ACurToken.Kind <> ytkStreamEnd) and
        (ACurToken.Kind <> ytkError) do
  begin
    if ACurToken.Kind = ytkKey then
    begin
      SetUnsupportedExplicitMappingKeyError(ADoc, ACurToken);
      Result := LIdx;
      Exit;
    end;

    if (LCount > 0) then
    begin
      if ACurToken.Kind <> ytkFlowEntry then
      begin
        ADoc.SetError('expected "," or "}"', ACurToken.Line, ACurToken.Col,
          ACurToken.Offset);
        Result := LIdx;
        Exit;
      end;
      ACurToken := AScanner.NextToken; // consume ,
      if ACurToken.Kind = ytkFlowMapEnd then
        Break; // trailing comma
    end;

    // Key
    if ACurToken.Kind = ytkScalar then
    begin
      if IsBareMergeKeyToken(ACurToken) then
      begin
        SetUnsupportedMergeKeyError(ADoc, ACurToken);
        Result := LIdx;
        Exit;
      end;
      if MappingContainsKey(ADoc, LFirst, ACurToken.Value) then
      begin
        SetDuplicateMappingKeyError(ADoc, ACurToken);
        Result := LIdx;
        Exit;
      end;
      LKeyNode := ADoc.AddNode;
      if LKeyNode = YAML_NODE_NONE then
      begin
        Result := LIdx;
        Exit;
      end;
      ADoc.FNodes[LKeyNode].Kind := ynkString;
      ADoc.FNodes[LKeyNode].Str := ACurToken.Value;
      ADoc.FNodes[LKeyNode].Next := YAML_NODE_NONE;
      ACurToken := AScanner.NextToken;
    end
    else
    begin
      ADoc.SetError('expected mapping key', ACurToken.Line, ACurToken.Col,
        ACurToken.Offset);
      Result := LIdx;
      Exit;
    end;

    // Value
    if ACurToken.Kind = ytkValue then
      ACurToken := AScanner.NextToken // consume :
    else
    begin
      ADoc.SetError('expected ":"', ACurToken.Line, ACurToken.Col,
        ACurToken.Offset);
      Result := LIdx;
      Exit;
    end;

    LValNode := ParseNode(ADoc, AScanner, ACurToken);
    if ADoc.FHasError then begin Result := LIdx; Exit; end;

    // Link key → value as siblings
    ADoc.FNodes[LKeyNode].Next := LValNode;

    if LFirst = YAML_NODE_NONE then
      LFirst := LKeyNode
    else
      ADoc.FNodes[LPrev].Next := LKeyNode;
    LPrev := LValNode;
    Inc(LCount);
  end;

  if ACurToken.Kind = ytkFlowMapEnd then
  begin
    ACurToken := AScanner.NextToken; // consume }
  end
  else if (ACurToken.Kind = ytkStreamEnd) and (not ADoc.FHasError) then
  begin
    ADoc.SetError('expected "}"', ACurToken.Line, ACurToken.Col,
      ACurToken.Offset);
    Result := LIdx;
    Exit;
  end;

  ADoc.FNodes[LIdx].Container.FirstChild := LFirst;
  ADoc.FNodes[LIdx].Container.Count := LCount;
  Result := LIdx;
end;

function ParseNode(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken): UInt32;
var
  LAnchorName, LKeyView: TStringView;
  LKeyToken: TYamlToken;
  LKeyNode, LValNode, LFirst, LPrev, LIdx: UInt32;
  LCount, LMapCol: UInt32;
begin
  Inc(ADoc.FParseDepth);
  if ADoc.FParseDepth > 256 then
  begin
    ADoc.SetError('nesting too deep', ACurToken.Line, ACurToken.Col,
      ACurToken.Offset);
    Result := ADoc.AddNode;
    if Result <> YAML_NODE_NONE then
      ADoc.FNodes[Result].Kind := ynkNull;
    Dec(ADoc.FParseDepth);
    Exit;
  end;
  case ACurToken.Kind of
    ytkFlowSeqStart:
      Result := ParseFlowSequence(ADoc, AScanner, ACurToken);
    ytkFlowMapStart:
      Result := ParseFlowMapping(ADoc, AScanner, ACurToken);
    ytkBlockMapStart:
      Result := ParseBlockMapping(ADoc, AScanner, ACurToken);
    ytkBlockSeqStart:
      Result := ParseBlockSequence(ADoc, AScanner, ACurToken);
    ytkScalar:
    begin
      LKeyToken := ACurToken;
      LKeyView := ACurToken.Value;
      LMapCol := ACurToken.Col;
      Result := ResolveScalar(ACurToken.Value, ACurToken.Style, ADoc);
      if Result = YAML_NODE_NONE then
      begin
        Dec(ADoc.FParseDepth);
        Exit;
      end;
      ACurToken := AScanner.NextToken;
      if ACurToken.Kind = ytkValue then
      begin
        if ACurToken.Line <> LKeyToken.Line then
        begin
          ADoc.SetError('expected mapping key', ACurToken.Line, ACurToken.Col,
            ACurToken.Offset);
          Dec(ADoc.FParseDepth);
          Exit;
        end;
        if IsBareMergeKeyToken(LKeyToken) then
        begin
          SetUnsupportedMergeKeyError(ADoc, LKeyToken);
          Dec(ADoc.FParseDepth);
          Exit;
        end;
        LKeyNode := Result;
        ADoc.FNodes[LKeyNode].Kind := ynkString;
        ADoc.FNodes[LKeyNode].Str := LKeyView;
        LIdx := ADoc.AddNode;
        if LIdx = YAML_NODE_NONE then
        begin
          Dec(ADoc.FParseDepth);
          Exit;
        end;
        ADoc.FNodes[LIdx].Kind := ynkMapping;
        LFirst := LKeyNode;
        LPrev := YAML_NODE_NONE;
        LCount := 0;
        while ACurToken.Kind = ytkValue do
        begin
          ACurToken := AScanner.NextToken;
          LValNode := ParseNode(ADoc, AScanner, ACurToken);
          if ADoc.FHasError then begin Result := LIdx; Exit; end;
          ADoc.FNodes[LKeyNode].Next := LValNode;
          if LCount = 0 then
            LFirst := LKeyNode
          else
            ADoc.FNodes[LPrev].Next := LKeyNode;
          LPrev := LValNode;
          Inc(LCount);
          if (ACurToken.Kind = ytkScalar) and (ACurToken.Col = LMapCol) then
          begin
            if IsBareMergeKeyToken(ACurToken) then
            begin
              SetUnsupportedMergeKeyError(ADoc, ACurToken);
              Result := LIdx;
              Dec(ADoc.FParseDepth);
              Exit;
            end;
            if MappingContainsKey(ADoc, LFirst, ACurToken.Value) then
            begin
              SetDuplicateMappingKeyError(ADoc, ACurToken);
              Result := LIdx;
              Dec(ADoc.FParseDepth);
              Exit;
            end;
            LKeyView := ACurToken.Value;
            LKeyNode := ADoc.AddNode;
            if LKeyNode = YAML_NODE_NONE then
            begin
              Result := LIdx;
              Dec(ADoc.FParseDepth);
              Exit;
            end;
            ADoc.FNodes[LKeyNode].Kind := ynkString;
            ADoc.FNodes[LKeyNode].Str := LKeyView;
            ADoc.FNodes[LKeyNode].Next := YAML_NODE_NONE;
            ACurToken := AScanner.NextToken;
          end
          else
            Break;
        end;
        if ACurToken.Kind = ytkValue then
        begin
          ADoc.SetError('expected mapping key', ACurToken.Line, ACurToken.Col,
            ACurToken.Offset);
          Result := LIdx;
          Dec(ADoc.FParseDepth);
          Exit;
        end;
        if ACurToken.Kind = ytkBlockEnd then
          ACurToken := AScanner.NextToken;
        ADoc.FNodes[LIdx].Container.FirstChild := LFirst;
        ADoc.FNodes[LIdx].Container.Count := LCount;
        Result := LIdx;
      end;
    end;
    ytkAlias:
    begin
      LIdx := ResolveAlias(ADoc, ACurToken.Value);
      if LIdx = YAML_NODE_NONE then
      begin
        ADoc.SetError('undefined alias', ACurToken.Line, ACurToken.Col,
          ACurToken.Offset);
        Result := ADoc.AddNode;
        if Result <> YAML_NODE_NONE then
          ADoc.FNodes[Result].Kind := ynkNull;
      end
      else if AliasResolutionDepthExceedsLimit(ADoc, LIdx) then
      begin
        ADoc.SetError('alias resolution depth exceeds limit',
          ACurToken.Line, ACurToken.Col, ACurToken.Offset);
        Result := ADoc.AddNode;
        if Result <> YAML_NODE_NONE then
          ADoc.FNodes[Result].Kind := ynkNull;
      end
      else
      begin
        Result := ADoc.AddNode;
        if Result = YAML_NODE_NONE then
        begin
          Dec(ADoc.FParseDepth);
          Exit;
        end;
        ADoc.FNodes[Result].Kind := ynkAlias;
        ADoc.FNodes[Result].AliasTarget := LIdx;
      end;
      ACurToken := AScanner.NextToken;
    end;
    ytkAnchor:
    begin
      LAnchorName := ACurToken.Value;
      ACurToken := AScanner.NextToken;
      Result := ParseNode(ADoc, AScanner, ACurToken);
      if not ADoc.FHasError then
      begin
        ADoc.FNodes[Result].Anchor := LAnchorName;
        ADoc.RegisterAnchor(LAnchorName, Result);
      end;
    end;
    ytkKey:
    begin
      SetUnsupportedExplicitMappingKeyError(ADoc, ACurToken);
      Result := ADoc.AddNode;
      if Result <> YAML_NODE_NONE then
        ADoc.FNodes[Result].Kind := ynkNull;
    end;
    ytkValue:
    begin
      ADoc.SetError('expected mapping key', ACurToken.Line, ACurToken.Col,
        ACurToken.Offset);
      Result := ADoc.AddNode;
      if Result <> YAML_NODE_NONE then
        ADoc.FNodes[Result].Kind := ynkNull;
    end;
  else
    Result := ADoc.AddNode;
    if Result <> YAML_NODE_NONE then
      ADoc.FNodes[Result].Kind := ynkNull;
  end;
  Dec(ADoc.FParseDepth);
end;

procedure ValidateDocumentTail(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken);
begin
  if ACurToken.Kind = ytkDocEnd then
    ACurToken := AScanner.NextToken;

  if ACurToken.Kind = ytkStreamEnd then
    Exit;

  if ACurToken.Kind = ytkDocStart then
    ADoc.SetError('multiple YAML documents are not supported',
      ACurToken.Line, ACurToken.Col, ACurToken.Offset)
  else
    ADoc.SetError('unexpected content after YAML document',
      ACurToken.Line, ACurToken.Col, ACurToken.Offset);
end;

procedure YamlDocParseWith(var ADoc: TYamlDocument; const AInput: PAnsiChar; const ALen: SizeUInt;
  const AAllocator: IAllocator);
var
  LScanner: TYamlScanner;
  LTok: TYamlToken;
begin
  PrepareYamlDocumentForParse(ADoc);
  ADoc.Init(AAllocator);
  if ADoc.FHasError then
    Exit;
  if (AInput = nil) or (ALen = 0) then
  begin
    ADoc.FRootIdx := ADoc.AddNode;
    if ADoc.FRootIdx <> YAML_NODE_NONE then
      ADoc.FNodes[ADoc.FRootIdx].Kind := ynkNull;
    Exit;
  end;

  LScanner.Init(AInput, ALen);
  LTok := LScanner.NextToken; // StreamStart
  LTok := LScanner.NextToken; // first real token

  // Skip document start marker
  if LTok.Kind = ytkDocStart then
    LTok := LScanner.NextToken;

  if (LTok.Kind = ytkStreamEnd) then
  begin
    ADoc.FRootIdx := ADoc.AddNode;
    if ADoc.FRootIdx <> YAML_NODE_NONE then
      ADoc.FNodes[ADoc.FRootIdx].Kind := ynkNull;
    Exit;
  end;

  ADoc.FRootIdx := ParseNode(ADoc, LScanner, LTok);

  if (not ADoc.FHasError) and (not LScanner.HasError) then
    ValidateDocumentTail(ADoc, LScanner, LTok);

  if LScanner.HasError then
  begin
    ADoc.FHasError := True;
    ADoc.FError := LScanner.Error;
  end;
end;

procedure YamlDocParse(var ADoc: TYamlDocument; const AInput: PAnsiChar; const ALen: SizeUInt);
begin
  YamlDocParseWith(ADoc, AInput, ALen, DefaultAllocator);
end;

procedure YamlDocParseView(var ADoc: TYamlDocument; const AView: TStringView);
begin
  YamlDocParse(ADoc, AView.Data, AView.Len);
end;

procedure YamlDocParseViewWith(var ADoc: TYamlDocument; const AView: TStringView;
  const AAllocator: IAllocator);
begin
  YamlDocParseWith(ADoc, AView.Data, AView.Len, AAllocator);
end;

end.
