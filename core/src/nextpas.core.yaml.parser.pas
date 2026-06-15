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
    FAllocator: IAllocator;
    Nodes: PYamlNode;
    NodeCount: UInt32;
    NodeCap: UInt32;
    RootIdx: UInt32;
    Anchors: PYamlAnchorEntry;
    AnchorCount: UInt32;
    AnchorCap: UInt32;
    ParseDepth: Int32;
    Error: TYamlError;
    HasError: Boolean;
    procedure Init(const AAllocator: IAllocator);
    procedure Done;
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

procedure TYamlDocument.Init(const AAllocator: IAllocator);
begin
  if AAllocator = nil then
    FAllocator := DefaultAllocator
  else
    FAllocator := AAllocator;
  NodeCap := INITIAL_CAPACITY;
  Nodes := PYamlNode(FAllocator.Allocate(NodeCap * SizeOf(TYamlNode)));
  NodeCount := 0;
  RootIdx := 0;
  AnchorCap := 16;
  Anchors := PYamlAnchorEntry(FAllocator.Allocate(AnchorCap * SizeOf(TYamlAnchorEntry)));
  AnchorCount := 0;
  ParseDepth := 0;
  Error.Message := TStringView.Empty;
  Error.Line := 0;
  Error.Col := 0;
  Error.Offset := 0;
  HasError := False;
end;

procedure TYamlDocument.Done;
begin
  if Nodes <> nil then
  begin
    FAllocator.Deallocate(Pointer(Nodes));
    Nodes := nil;
  end;
  NodeCap := 0;
  NodeCount := 0;
  if Anchors <> nil then
  begin
    FAllocator.Deallocate(Pointer(Anchors));
    Anchors := nil;
  end;
  AnchorCap := 0;
  AnchorCount := 0;
  ParseDepth := 0;
  RootIdx := 0;
  Error.Message := TStringView.Empty;
  Error.Line := 0;
  Error.Col := 0;
  Error.Offset := 0;
  HasError := False;
end;

procedure YamlDocInit(var ADoc: TYamlDocument);
begin
  ADoc.Init(DefaultAllocator);
end;

procedure YamlDocInitWith(var ADoc: TYamlDocument; const AAllocator: IAllocator);
begin
  ADoc.Init(AAllocator);
end;

function AddNode(var ADoc: TYamlDocument): UInt32;
begin
  Result := ADoc.NodeCount;
  if ADoc.NodeCount >= ADoc.NodeCap then
  begin
    ADoc.NodeCap := ADoc.NodeCap * 2;
    ADoc.Nodes := PYamlNode(ADoc.FAllocator.Reallocate(Pointer(ADoc.Nodes),
      ADoc.NodeCap * SizeOf(TYamlNode)));
  end;
  FillChar(ADoc.Nodes[Result], SizeOf(TYamlNode), 0);
  ADoc.Nodes[Result].Next := YAML_NODE_NONE;
  Inc(ADoc.NodeCount);
end;

procedure RegisterAnchor(var ADoc: TYamlDocument; const AName: TStringView; ANodeIdx: UInt32);
begin
  if ADoc.AnchorCount >= ADoc.AnchorCap then
  begin
    ADoc.AnchorCap := ADoc.AnchorCap * 2;
    ADoc.Anchors := PYamlAnchorEntry(ADoc.FAllocator.Reallocate(Pointer(ADoc.Anchors),
      ADoc.AnchorCap * SizeOf(TYamlAnchorEntry)));
  end;
  ADoc.Anchors[ADoc.AnchorCount].Name := AName;
  ADoc.Anchors[ADoc.AnchorCount].NodeIdx := ANodeIdx;
  Inc(ADoc.AnchorCount);
end;

function ResolveAlias(var ADoc: TYamlDocument; const AName: TStringView): UInt32;
var
  LI: UInt32;
begin
  for LI := 1 to ADoc.AnchorCount do
    if ADoc.Anchors[LI - 1].Name.Equals(AName) then
    begin
      Result := ADoc.Anchors[LI - 1].NodeIdx;
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
  while (LIdx < ADoc.NodeCount) and (ADoc.Nodes[LIdx].Kind = ynkAlias) do
  begin
    if LDepth >= YAML_ALIAS_RESOLUTION_DEPTH_LIMIT then
      Exit(True);
    LIdx := ADoc.Nodes[LIdx].AliasTarget;
    Inc(LDepth);
  end;
end;

procedure SetError(var ADoc: TYamlDocument; const AMsg: string;
  const ALine, ACol: UInt32; const AOffset: SizeUInt);
begin
  ADoc.HasError := True;
  ADoc.Error.Message := TStringView.FromStr(AMsg);
  ADoc.Error.Line := ALine;
  ADoc.Error.Col := ACol;
  ADoc.Error.Offset := AOffset;
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
  SetError(ADoc, 'YAML merge keys are not supported',
    AToken.Line, AToken.Col, AToken.Offset);
end;

procedure SetUnsupportedExplicitMappingKeyError(var ADoc: TYamlDocument;
  const AToken: TYamlToken);
begin
  SetError(ADoc, 'YAML explicit mapping keys are not supported',
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
    if (ADoc.Nodes[LCur].Kind = ynkString) and
       ADoc.Nodes[LCur].Str.Equals(AKey) then
    begin
      Result := True;
      Exit;
    end;
    if ADoc.Nodes[LCur].Next = YAML_NODE_NONE then
      Exit;
    LCur := ADoc.Nodes[ADoc.Nodes[LCur].Next].Next;
  end;
end;

procedure SetDuplicateMappingKeyError(var ADoc: TYamlDocument;
  const AToken: TYamlToken);
begin
  SetError(ADoc, 'duplicate mapping key',
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
  LIdx := AddNode(ADoc);

  if AStyle <> yssPlain then
  begin
    ADoc.Nodes[LIdx].Kind := ynkString;
    ADoc.Nodes[LIdx].Str := AValue;
    Result := LIdx;
    Exit;
  end;

  if AValue.IsEmpty then
  begin
    ADoc.Nodes[LIdx].Kind := ynkNull;
    Result := LIdx;
    Exit;
  end;

  LStr := AValue.ToString;

  // Null
  if (LStr = 'null') or (LStr = 'Null') or (LStr = 'NULL') or (LStr = '~') then
  begin
    ADoc.Nodes[LIdx].Kind := ynkNull;
    Result := LIdx;
    Exit;
  end;

  // Bool
  if (LStr = 'true') or (LStr = 'True') or (LStr = 'TRUE') then
  begin
    ADoc.Nodes[LIdx].Kind := ynkBool;
    ADoc.Nodes[LIdx].BoolVal := True;
    Result := LIdx;
    Exit;
  end;
  if (LStr = 'false') or (LStr = 'False') or (LStr = 'FALSE') then
  begin
    ADoc.Nodes[LIdx].Kind := ynkBool;
    ADoc.Nodes[LIdx].BoolVal := False;
    Result := LIdx;
    Exit;
  end;

  // Int
  if ViewToInt64(AValue, LInt) then
  begin
    ADoc.Nodes[LIdx].Kind := ynkInt;
    ADoc.Nodes[LIdx].IntVal := LInt;
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
      ADoc.Nodes[LIdx].Kind := ynkInt;
      ADoc.Nodes[LIdx].IntVal := LInt;
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
      ADoc.Nodes[LIdx].Kind := ynkInt;
      ADoc.Nodes[LIdx].IntVal := LInt;
      Result := LIdx;
      Exit;
    end;
  end;

  // Float
  if (LStr = '.inf') or (LStr = '.Inf') or (LStr = '.INF') or
     (LStr = '+.inf') or (LStr = '+.Inf') or (LStr = '+.INF') then
  begin
    ADoc.Nodes[LIdx].Kind := ynkFloat;
    ADoc.Nodes[LIdx].RealVal := 1.0 / 0.0;
    Result := LIdx;
    Exit;
  end;
  if (LStr = '-.inf') or (LStr = '-.Inf') or (LStr = '-.INF') then
  begin
    ADoc.Nodes[LIdx].Kind := ynkFloat;
    ADoc.Nodes[LIdx].RealVal := -1.0 / 0.0;
    Result := LIdx;
    Exit;
  end;
  if (LStr = '.nan') or (LStr = '.NaN') or (LStr = '.NAN') then
  begin
    ADoc.Nodes[LIdx].Kind := ynkFloat;
    ADoc.Nodes[LIdx].RealVal := 0.0 / 0.0;
    Result := LIdx;
    Exit;
  end;

  if ViewToDouble(AValue, LFloat) then
  begin
    ADoc.Nodes[LIdx].Kind := ynkFloat;
    ADoc.Nodes[LIdx].RealVal := LFloat;
    Result := LIdx;
    Exit;
  end;

  // Default: string
  ADoc.Nodes[LIdx].Kind := ynkString;
  ADoc.Nodes[LIdx].Str := AValue;
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
  LIdx := AddNode(ADoc);
  ADoc.Nodes[LIdx].Kind := ynkSequence;

  LFirst := YAML_NODE_NONE;
  LPrev := YAML_NODE_NONE;
  LCount := 0;

  while ACurToken.Kind = ytkBlockSeqStart do
  begin
    ACurToken := AScanner.NextToken; // consume - indicator
    LChild := ParseNode(ADoc, AScanner, ACurToken);
    if ADoc.HasError then begin Result := LIdx; Exit; end;

    if LFirst = YAML_NODE_NONE then
      LFirst := LChild
    else
      ADoc.Nodes[LPrev].Next := LChild;
    LPrev := LChild;
    Inc(LCount);
  end;

  if ACurToken.Kind = ytkBlockEnd then
    ACurToken := AScanner.NextToken;

  ADoc.Nodes[LIdx].Container.FirstChild := LFirst;
  ADoc.Nodes[LIdx].Container.Count := LCount;
  Result := LIdx;
end;

function ParseBlockMapping(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken): UInt32;
var
  LIdx, LFirst, LPrev, LKeyNode, LValNode: UInt32;
  LCount: UInt32;
begin
  LIdx := AddNode(ADoc);
  ADoc.Nodes[LIdx].Kind := ynkMapping;
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
      LKeyNode := AddNode(ADoc);
      ADoc.Nodes[LKeyNode].Kind := ynkString;
      ADoc.Nodes[LKeyNode].Str := ACurToken.Value;
      ADoc.Nodes[LKeyNode].Next := YAML_NODE_NONE;
      ACurToken := AScanner.NextToken;
    end
    else
    begin
      SetError(ADoc, 'expected mapping key', ACurToken.Line, ACurToken.Col,
        ACurToken.Offset);
      Result := LIdx;
      Exit;
    end;

    // Value
    if ACurToken.Kind = ytkValue then
    begin
      ACurToken := AScanner.NextToken;
      LValNode := ParseNode(ADoc, AScanner, ACurToken);
      if ADoc.HasError then begin Result := LIdx; Exit; end;
    end
    else
    begin
      LValNode := AddNode(ADoc);
      ADoc.Nodes[LValNode].Kind := ynkNull;
    end;

    ADoc.Nodes[LKeyNode].Next := LValNode;

    if LFirst = YAML_NODE_NONE then
      LFirst := LKeyNode
    else
      ADoc.Nodes[LPrev].Next := LKeyNode;
    LPrev := LValNode;
    Inc(LCount);
  end;

  if ACurToken.Kind = ytkBlockEnd then
    ACurToken := AScanner.NextToken;

  ADoc.Nodes[LIdx].Container.FirstChild := LFirst;
  ADoc.Nodes[LIdx].Container.Count := LCount;
  Result := LIdx;
end;

function ParseFlowSequence(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken): UInt32;
var
  LIdx, LFirst, LPrev, LChild: UInt32;
  LCount: UInt32;
begin
  LIdx := AddNode(ADoc);
  ADoc.Nodes[LIdx].Kind := ynkSequence;
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
        SetError(ADoc, 'expected "," or "]"', ACurToken.Line, ACurToken.Col,
          ACurToken.Offset);
        Result := LIdx;
        Exit;
      end;
      ACurToken := AScanner.NextToken; // consume ,
      if ACurToken.Kind = ytkFlowSeqEnd then
        Break; // trailing comma
    end;

    LChild := ParseNode(ADoc, AScanner, ACurToken);
    if ADoc.HasError then begin Result := LIdx; Exit; end;

    if LFirst = YAML_NODE_NONE then
      LFirst := LChild
    else
      ADoc.Nodes[LPrev].Next := LChild;
    LPrev := LChild;
    Inc(LCount);
  end;

  if ACurToken.Kind = ytkFlowSeqEnd then
  begin
    ACurToken := AScanner.NextToken; // consume ]
  end
  else if (ACurToken.Kind = ytkStreamEnd) and (not ADoc.HasError) then
  begin
    SetError(ADoc, 'expected "]"', ACurToken.Line, ACurToken.Col,
      ACurToken.Offset);
    Result := LIdx;
    Exit;
  end;

  ADoc.Nodes[LIdx].Container.FirstChild := LFirst;
  ADoc.Nodes[LIdx].Container.Count := LCount;
  Result := LIdx;
end;

function ParseFlowMapping(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken): UInt32;
var
  LIdx, LFirst, LPrev, LKeyNode, LValNode: UInt32;
  LCount: UInt32;
begin
  LIdx := AddNode(ADoc);
  ADoc.Nodes[LIdx].Kind := ynkMapping;
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
        SetError(ADoc, 'expected "," or "}"', ACurToken.Line, ACurToken.Col,
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
      LKeyNode := AddNode(ADoc);
      ADoc.Nodes[LKeyNode].Kind := ynkString;
      ADoc.Nodes[LKeyNode].Str := ACurToken.Value;
      ADoc.Nodes[LKeyNode].Next := YAML_NODE_NONE;
      ACurToken := AScanner.NextToken;
    end
    else
    begin
      SetError(ADoc, 'expected mapping key', ACurToken.Line, ACurToken.Col,
        ACurToken.Offset);
      Result := LIdx;
      Exit;
    end;

    // Value
    if ACurToken.Kind = ytkValue then
      ACurToken := AScanner.NextToken // consume :
    else
    begin
      SetError(ADoc, 'expected ":"', ACurToken.Line, ACurToken.Col,
        ACurToken.Offset);
      Result := LIdx;
      Exit;
    end;

    LValNode := ParseNode(ADoc, AScanner, ACurToken);
    if ADoc.HasError then begin Result := LIdx; Exit; end;

    // Link key → value as siblings
    ADoc.Nodes[LKeyNode].Next := LValNode;

    if LFirst = YAML_NODE_NONE then
      LFirst := LKeyNode
    else
      ADoc.Nodes[LPrev].Next := LKeyNode;
    LPrev := LValNode;
    Inc(LCount);
  end;

  if ACurToken.Kind = ytkFlowMapEnd then
  begin
    ACurToken := AScanner.NextToken; // consume }
  end
  else if (ACurToken.Kind = ytkStreamEnd) and (not ADoc.HasError) then
  begin
    SetError(ADoc, 'expected "}"', ACurToken.Line, ACurToken.Col,
      ACurToken.Offset);
    Result := LIdx;
    Exit;
  end;

  ADoc.Nodes[LIdx].Container.FirstChild := LFirst;
  ADoc.Nodes[LIdx].Container.Count := LCount;
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
  Inc(ADoc.ParseDepth);
  if ADoc.ParseDepth > 256 then
  begin
    SetError(ADoc, 'nesting too deep', ACurToken.Line, ACurToken.Col,
      ACurToken.Offset);
    Result := AddNode(ADoc);
    ADoc.Nodes[Result].Kind := ynkNull;
    Dec(ADoc.ParseDepth);
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
      ACurToken := AScanner.NextToken;
      if ACurToken.Kind = ytkValue then
      begin
        if ACurToken.Line <> LKeyToken.Line then
        begin
          SetError(ADoc, 'expected mapping key', ACurToken.Line, ACurToken.Col,
            ACurToken.Offset);
          Dec(ADoc.ParseDepth);
          Exit;
        end;
        if IsBareMergeKeyToken(LKeyToken) then
        begin
          SetUnsupportedMergeKeyError(ADoc, LKeyToken);
          Dec(ADoc.ParseDepth);
          Exit;
        end;
        LKeyNode := Result;
        ADoc.Nodes[LKeyNode].Kind := ynkString;
        ADoc.Nodes[LKeyNode].Str := LKeyView;
        LIdx := AddNode(ADoc);
        ADoc.Nodes[LIdx].Kind := ynkMapping;
        LFirst := LKeyNode;
        LPrev := YAML_NODE_NONE;
        LCount := 0;
        while ACurToken.Kind = ytkValue do
        begin
          ACurToken := AScanner.NextToken;
          LValNode := ParseNode(ADoc, AScanner, ACurToken);
          if ADoc.HasError then begin Result := LIdx; Exit; end;
          ADoc.Nodes[LKeyNode].Next := LValNode;
          if LCount = 0 then
            LFirst := LKeyNode
          else
            ADoc.Nodes[LPrev].Next := LKeyNode;
          LPrev := LValNode;
          Inc(LCount);
          if (ACurToken.Kind = ytkScalar) and (ACurToken.Col = LMapCol) then
          begin
            if IsBareMergeKeyToken(ACurToken) then
            begin
              SetUnsupportedMergeKeyError(ADoc, ACurToken);
              Result := LIdx;
              Dec(ADoc.ParseDepth);
              Exit;
            end;
            if MappingContainsKey(ADoc, LFirst, ACurToken.Value) then
            begin
              SetDuplicateMappingKeyError(ADoc, ACurToken);
              Result := LIdx;
              Dec(ADoc.ParseDepth);
              Exit;
            end;
            LKeyView := ACurToken.Value;
            LKeyNode := AddNode(ADoc);
            ADoc.Nodes[LKeyNode].Kind := ynkString;
            ADoc.Nodes[LKeyNode].Str := LKeyView;
            ADoc.Nodes[LKeyNode].Next := YAML_NODE_NONE;
            ACurToken := AScanner.NextToken;
          end
          else
            Break;
        end;
        if ACurToken.Kind = ytkValue then
        begin
          SetError(ADoc, 'expected mapping key', ACurToken.Line, ACurToken.Col,
            ACurToken.Offset);
          Result := LIdx;
          Dec(ADoc.ParseDepth);
          Exit;
        end;
        if ACurToken.Kind = ytkBlockEnd then
          ACurToken := AScanner.NextToken;
        ADoc.Nodes[LIdx].Container.FirstChild := LFirst;
        ADoc.Nodes[LIdx].Container.Count := LCount;
        Result := LIdx;
      end;
    end;
    ytkAlias:
    begin
      LIdx := ResolveAlias(ADoc, ACurToken.Value);
      if LIdx = YAML_NODE_NONE then
      begin
        SetError(ADoc, 'undefined alias', ACurToken.Line, ACurToken.Col,
          ACurToken.Offset);
        Result := AddNode(ADoc);
        ADoc.Nodes[Result].Kind := ynkNull;
      end
      else if AliasResolutionDepthExceedsLimit(ADoc, LIdx) then
      begin
        SetError(ADoc, 'alias resolution depth exceeds limit',
          ACurToken.Line, ACurToken.Col, ACurToken.Offset);
        Result := AddNode(ADoc);
        ADoc.Nodes[Result].Kind := ynkNull;
      end
      else
      begin
        Result := AddNode(ADoc);
        ADoc.Nodes[Result].Kind := ynkAlias;
        ADoc.Nodes[Result].AliasTarget := LIdx;
      end;
      ACurToken := AScanner.NextToken;
    end;
    ytkAnchor:
    begin
      LAnchorName := ACurToken.Value;
      ACurToken := AScanner.NextToken;
      Result := ParseNode(ADoc, AScanner, ACurToken);
      if not ADoc.HasError then
      begin
        ADoc.Nodes[Result].Anchor := LAnchorName;
        RegisterAnchor(ADoc, LAnchorName, Result);
      end;
    end;
    ytkKey:
    begin
      SetUnsupportedExplicitMappingKeyError(ADoc, ACurToken);
      Result := AddNode(ADoc);
      ADoc.Nodes[Result].Kind := ynkNull;
    end;
    ytkValue:
    begin
      SetError(ADoc, 'expected mapping key', ACurToken.Line, ACurToken.Col,
        ACurToken.Offset);
      Result := AddNode(ADoc);
      ADoc.Nodes[Result].Kind := ynkNull;
    end;
  else
    Result := AddNode(ADoc);
    ADoc.Nodes[Result].Kind := ynkNull;
  end;
  Dec(ADoc.ParseDepth);
end;

procedure ValidateDocumentTail(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken);
begin
  if ACurToken.Kind = ytkDocEnd then
    ACurToken := AScanner.NextToken;

  if ACurToken.Kind = ytkStreamEnd then
    Exit;

  if ACurToken.Kind = ytkDocStart then
    SetError(ADoc, 'multiple YAML documents are not supported',
      ACurToken.Line, ACurToken.Col, ACurToken.Offset)
  else
    SetError(ADoc, 'unexpected content after YAML document',
      ACurToken.Line, ACurToken.Col, ACurToken.Offset);
end;

procedure YamlDocParseWith(var ADoc: TYamlDocument; const AInput: PAnsiChar; const ALen: SizeUInt;
  const AAllocator: IAllocator);
var
  LScanner: TYamlScanner;
  LTok: TYamlToken;
begin
  ADoc.Init(AAllocator);
  if (AInput = nil) or (ALen = 0) then
  begin
    AddNode(ADoc);
    ADoc.Nodes[0].Kind := ynkNull;
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
    AddNode(ADoc);
    ADoc.Nodes[0].Kind := ynkNull;
    Exit;
  end;

  ADoc.RootIdx := ParseNode(ADoc, LScanner, LTok);

  if (not ADoc.HasError) and (not LScanner.HasError) then
    ValidateDocumentTail(ADoc, LScanner, LTok);

  if LScanner.HasError then
  begin
    ADoc.HasError := True;
    ADoc.Error := LScanner.Error;
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
