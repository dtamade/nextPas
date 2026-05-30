unit nextpas.core.yaml.parser;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.text.number,
  nextpas.core.yaml.types,
  nextpas.core.yaml.scanner;

type
  TYamlDocument = record
    Nodes: array of TYamlNode;
    NodeCount: UInt32;
    Error: TYamlError;
    HasError: Boolean;
  end;

procedure YamlDocInit(var ADoc: TYamlDocument);
procedure YamlDocParse(var ADoc: TYamlDocument; const AInput: PAnsiChar; const ALen: SizeUInt);
procedure YamlDocParseView(var ADoc: TYamlDocument; const AView: TStringView);

implementation

const
  INITIAL_CAPACITY = 64;

procedure YamlDocInit(var ADoc: TYamlDocument);
begin
  SetLength(ADoc.Nodes, INITIAL_CAPACITY);
  ADoc.NodeCount := 0;
  ADoc.HasError := False;
end;

function AddNode(var ADoc: TYamlDocument): UInt32;
begin
  Result := ADoc.NodeCount;
  if ADoc.NodeCount >= UInt32(Length(ADoc.Nodes)) then
    SetLength(ADoc.Nodes, Length(ADoc.Nodes) * 2);
  FillChar(ADoc.Nodes[Result], SizeOf(TYamlNode), 0);
  ADoc.Nodes[Result].Next := YAML_NODE_NONE;
  Inc(ADoc.NodeCount);
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
        SetError(ADoc, 'expected "," or "]"', ACurToken.Line, ACurToken.Col, 0);
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
    ACurToken := AScanner.NextToken; // consume ]

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
    if (LCount > 0) then
    begin
      if ACurToken.Kind <> ytkFlowEntry then
      begin
        SetError(ADoc, 'expected "," or "}"', ACurToken.Line, ACurToken.Col, 0);
        Result := LIdx;
        Exit;
      end;
      ACurToken := AScanner.NextToken; // consume ,
      if ACurToken.Kind = ytkFlowMapEnd then
        Break; // trailing comma
    end;

    // Key
    if ACurToken.Kind = ytkKey then
      ACurToken := AScanner.NextToken; // explicit ? key

    if ACurToken.Kind = ytkScalar then
    begin
      LKeyNode := ResolveScalar(ACurToken.Value, ACurToken.Style, ADoc);
      ACurToken := AScanner.NextToken;
    end
    else
    begin
      SetError(ADoc, 'expected mapping key', ACurToken.Line, ACurToken.Col, 0);
      Result := LIdx;
      Exit;
    end;

    // Value
    if ACurToken.Kind = ytkValue then
      ACurToken := AScanner.NextToken // consume :
    else
    begin
      SetError(ADoc, 'expected ":"', ACurToken.Line, ACurToken.Col, 0);
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
    ACurToken := AScanner.NextToken; // consume }

  ADoc.Nodes[LIdx].Container.FirstChild := LFirst;
  ADoc.Nodes[LIdx].Container.Count := LCount;
  Result := LIdx;
end;

function ParseNode(var ADoc: TYamlDocument; var AScanner: TYamlScanner;
  var ACurToken: TYamlToken): UInt32;
var
  LAnchorName: TStringView;
begin
  case ACurToken.Kind of
    ytkFlowSeqStart:
      Result := ParseFlowSequence(ADoc, AScanner, ACurToken);
    ytkFlowMapStart:
      Result := ParseFlowMapping(ADoc, AScanner, ACurToken);
    ytkScalar:
    begin
      Result := ResolveScalar(ACurToken.Value, ACurToken.Style, ADoc);
      ACurToken := AScanner.NextToken;
    end;
    ytkAlias:
    begin
      Result := AddNode(ADoc);
      ADoc.Nodes[Result].Kind := ynkAlias;
      ADoc.Nodes[Result].Str := ACurToken.Value;
      ACurToken := AScanner.NextToken;
    end;
    ytkAnchor:
    begin
      LAnchorName := ACurToken.Value;
      ACurToken := AScanner.NextToken;
      Result := ParseNode(ADoc, AScanner, ACurToken);
      if not ADoc.HasError then
        ADoc.Nodes[Result].Anchor := LAnchorName;
    end;
  else
    Result := AddNode(ADoc);
    ADoc.Nodes[Result].Kind := ynkNull;
  end;
end;

procedure YamlDocParse(var ADoc: TYamlDocument; const AInput: PAnsiChar; const ALen: SizeUInt);
var
  LScanner: TYamlScanner;
  LTok: TYamlToken;
begin
  YamlDocInit(ADoc);
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

  ParseNode(ADoc, LScanner, LTok);

  if LScanner.HasError then
  begin
    ADoc.HasError := True;
    ADoc.Error := LScanner.Error;
  end;
end;

procedure YamlDocParseView(var ADoc: TYamlDocument; const AView: TStringView);
begin
  YamlDocParse(ADoc, AView.Data, AView.Len);
end;

end.
