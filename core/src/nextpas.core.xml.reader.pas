unit nextpas.core.xml.reader;
{**
 * @desc XML SAX 流式解析器。基于 PAnsiChar 直接扫描，SIMD 加速文本跳过。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.xml.base;

type
  TXmlReader = class
  private
    FData: PAnsiChar;
    FLen: SizeUInt;
    FPos: SizeUInt;
    FLine: UInt32;
    FCol: UInt32;
    FTagStack: array of string;
    FTagStackTop: Integer;
    FNsStack: array of TXmlNamespaceArray;
    FNsStackTop: Integer;
    FError: string;
    FHasError: Boolean;
    function Peek: AnsiChar; inline;
    function Advance: AnsiChar;
    function AtEnd: Boolean; inline;
    procedure SkipWhitespace;
    function ParseName: TXmlName;
    function ParseQuotedValue: string;
    procedure ParseAttributes(out AAttrs: TXmlAttributeArray; out ASelfClose: Boolean);
    function ParseStartOrEmptyElement(out AToken: TXmlToken): Boolean;
    function ParseEndElement(out AToken: TXmlToken): Boolean;
    function ParseComment(out AToken: TXmlToken): Boolean;
    function ParseCData(out AToken: TXmlToken): Boolean;
    function ParsePI(out AToken: TXmlToken): Boolean;
    function ParseDoctype(out AToken: TXmlToken): Boolean;
    function ParseMarkup(out AToken: TXmlToken): Boolean;
    procedure PushTag(const AName: string);
    function PopTag(const AName: string): Boolean;
    procedure PushNamespaces(const AAttrs: TXmlAttributeArray);
    procedure PopNamespaces;
    procedure SetError(const AMsg: string);
  public
    constructor Create(const AInput: string);
    destructor Destroy; override;
    function Next(out AToken: TXmlToken): Boolean;
    function Position: TXmlPosition;
    function GetError: string;
    function HasError: Boolean;
    function ResolveNamespace(const APrefix: string): string;
    function Depth: Integer;
  end;

implementation

uses
  nextpas.core.text.scan,
  nextpas.core.text.conv;

{ TXmlReader }

constructor TXmlReader.Create(const AInput: string);
begin
  inherited Create;
  FLen := Length(AInput);
  if FLen > 0 then
  begin
    GetMem(FData, FLen);
    Move(AInput[1], FData^, FLen);
  end
  else
    FData := nil;
  FPos := 0;
  FLine := 1;
  FCol := 1;
  FTagStackTop := -1;
  FNsStackTop := -1;
  FHasError := False;
  FError := '';
  SetLength(FTagStack, 32);
  SetLength(FNsStack, 32);
end;

destructor TXmlReader.Destroy;
begin
  if FData <> nil then
    FreeMem(FData);
  inherited;
end;

function TXmlReader.Peek: AnsiChar;
begin
  if FPos < FLen then
    Result := FData[FPos]
  else
    Result := #0;
end;

function TXmlReader.Advance: AnsiChar;
begin
  Result := FData[FPos];
  Inc(FPos);
  if Result = #10 then
  begin
    Inc(FLine);
    FCol := 1;
  end
  else
    Inc(FCol);
end;

function TXmlReader.AtEnd: Boolean;
begin
  Result := FPos >= FLen;
end;

procedure TXmlReader.SkipWhitespace;
begin
  while (FPos < FLen) and (FData[FPos] in [#9, #10, #13, ' ']) do
    Advance;
end;

{ PLACEHOLDER_PARSENAME }

function TXmlReader.ParseName: TXmlName;
var
  LStart: SizeUInt;
  LFull: string;
  LColonPos, LI: Integer;
begin
  Result.Prefix := '';
  Result.Local := '';
  LStart := FPos;
  if AtEnd then Exit;
  if not (FData[FPos] in ['A'..'Z', 'a'..'z', '_', ':']) then Exit;
  Advance;
  while (FPos < FLen) and (FData[FPos] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.', ':']) do
    Advance;
  SetString(LFull, @FData[LStart], FPos - LStart);
  LColonPos := 0;
  for LI := 1 to Length(LFull) do
    if LFull[LI] = ':' then
    begin
      LColonPos := LI;
      Break;
    end;
  if LColonPos > 0 then
  begin
    Result.Prefix := Copy(LFull, 1, LColonPos - 1);
    Result.Local := Copy(LFull, LColonPos + 1, Length(LFull) - LColonPos);
  end
  else
    Result.Local := LFull;
end;

function TXmlReader.ParseQuotedValue: string;
var
  LQuote: AnsiChar;
  LStart: SizeUInt;
  LFound: PtrInt;
begin
  Result := '';
  if AtEnd then Exit;
  LQuote := FData[FPos];
  if not (LQuote in ['"', '''']) then
  begin
    SetError('Expected quote character');
    Exit;
  end;
  Advance;
  LStart := FPos;
  LFound := ScanFindByte(@FData[FPos], FLen - FPos, Byte(LQuote));
  if LFound < 0 then
  begin
    SetError('Unterminated attribute value');
    while FPos < FLen do Advance;
    SetString(Result, @FData[LStart], FPos - LStart);
    Exit;
  end;
  while FPos < LStart + SizeUInt(LFound) do
    Advance;
  SetString(Result, @FData[LStart], FPos - LStart);
  Advance;
  Result := XmlDecodeEntities(Result);
end;

procedure TXmlReader.ParseAttributes(out AAttrs: TXmlAttributeArray; out ASelfClose: Boolean);
var
  LCount, LCap: Integer;
  LName: TXmlName;
begin
  LCount := 0;
  LCap := 8;
  SetLength(AAttrs, LCap);
  ASelfClose := False;
  while True do
  begin
    SkipWhitespace;
    if AtEnd then Break;
    if FData[FPos] = '/' then
    begin
      Advance;
      if (not AtEnd) and (FData[FPos] = '>') then
      begin
        Advance;
        ASelfClose := True;
        SetLength(AAttrs, LCount);
        Exit;
      end;
      SetError('Expected > after /');
      SetLength(AAttrs, LCount);
      Exit;
    end;
    if FData[FPos] = '>' then
    begin
      Advance;
      SetLength(AAttrs, LCount);
      Exit;
    end;
    if FData[FPos] = '?' then
    begin
      Advance;
      if (not AtEnd) and (FData[FPos] = '>') then
      begin
        Advance;
        ASelfClose := True;
        SetLength(AAttrs, LCount);
        Exit;
      end;
      SetError('Expected > after ?');
      SetLength(AAttrs, LCount);
      Exit;
    end;
    LName := ParseName;
    if (LName.Local = '') and (LName.Prefix = '') then
    begin
      SetError('Expected attribute name');
      SetLength(AAttrs, LCount);
      Exit;
    end;
    SkipWhitespace;
    if AtEnd or (FData[FPos] <> '=') then
    begin
      SetError('Expected = after attribute name');
      SetLength(AAttrs, LCount);
      Exit;
    end;
    Advance;
    SkipWhitespace;
    if LCount >= LCap then
    begin
      LCap := LCap * 2;
      SetLength(AAttrs, LCap);
    end;
    AAttrs[LCount].Name := LName;
    AAttrs[LCount].Value := ParseQuotedValue;
    if FHasError then begin SetLength(AAttrs, LCount); Exit; end;
    Inc(LCount);
  end;
  SetLength(AAttrs, LCount);
end;

function TXmlReader.ParseStartOrEmptyElement(out AToken: TXmlToken): Boolean;
var
  LAttrs: TXmlAttributeArray;
  LSelfClose: Boolean;
begin
  Result := True;
  AToken.Name := ParseName;
  if (AToken.Name.Local = '') and (AToken.Name.Prefix = '') then
  begin
    SetError('Expected element name');
    Result := False;
    Exit;
  end;
  ParseAttributes(LAttrs, LSelfClose);
  if FHasError then begin Result := False; Exit; end;
  AToken.Attributes := LAttrs;
  AToken.Value := '';
  if LSelfClose then
  begin
    AToken.Kind := xtkEmptyElement;
    AToken.IsSelfClosing := True;
    PushNamespaces(LAttrs);
    PopNamespaces;
  end
  else
  begin
    AToken.Kind := xtkStartElement;
    AToken.IsSelfClosing := False;
    PushNamespaces(LAttrs);
    PushTag(AToken.Name.Full);
  end;
end;

function TXmlReader.ParseEndElement(out AToken: TXmlToken): Boolean;
begin
  Result := True;
  AToken.Kind := xtkEndElement;
  AToken.Name := ParseName;
  AToken.Value := '';
  AToken.IsSelfClosing := False;
  SetLength(AToken.Attributes, 0);
  SkipWhitespace;
  if (not AtEnd) and (FData[FPos] = '>') then
    Advance
  else
  begin
    SetError('Expected > in end tag');
    Result := False;
    Exit;
  end;
  if not PopTag(AToken.Name.Full) then
  begin
    Result := False;
    Exit;
  end;
  PopNamespaces;
end;

function TXmlReader.ParseComment(out AToken: TXmlToken): Boolean;
var
  LStart, LCheckPos: SizeUInt;
  LFound: PtrInt;
begin
  Result := True;
  AToken.Kind := xtkComment;
  AToken.Name.Prefix := '';
  AToken.Name.Local := '';
  AToken.IsSelfClosing := False;
  SetLength(AToken.Attributes, 0);
  LStart := FPos;
  while FPos < FLen do
  begin
    LFound := ScanFindByte(@FData[FPos], FLen - FPos, Byte('-'));
    if LFound < 0 then
    begin
      while FPos < FLen do Advance;
      Break;
    end;
    LCheckPos := FPos + SizeUInt(LFound);
    while FPos < LCheckPos do
      Advance;
    if (FPos + 2 < FLen) and (FData[FPos] = '-') and (FData[FPos + 1] = '-') and (FData[FPos + 2] = '>') then
    begin
      SetString(AToken.Value, @FData[LStart], FPos - LStart);
      Advance; Advance; Advance;
      Exit;
    end;
    Advance;
  end;
  SetString(AToken.Value, @FData[LStart], FPos - LStart);
  SetError('Unterminated comment');
  Result := False;
end;

function TXmlReader.ParseCData(out AToken: TXmlToken): Boolean;
var
  LStart, LCheckPos: SizeUInt;
  LFound: PtrInt;
begin
  Result := True;
  AToken.Kind := xtkCData;
  AToken.Name.Prefix := '';
  AToken.Name.Local := '';
  AToken.IsSelfClosing := False;
  SetLength(AToken.Attributes, 0);
  LStart := FPos;
  while FPos < FLen do
  begin
    LFound := ScanFindByte(@FData[FPos], FLen - FPos, Byte(']'));
    if LFound < 0 then
    begin
      while FPos < FLen do Advance;
      Break;
    end;
    LCheckPos := FPos + SizeUInt(LFound);
    while FPos < LCheckPos do
      Advance;
    if (FPos + 2 < FLen) and (FData[FPos] = ']') and (FData[FPos + 1] = ']') and (FData[FPos + 2] = '>') then
    begin
      SetString(AToken.Value, @FData[LStart], FPos - LStart);
      Advance; Advance; Advance;
      Exit;
    end;
    Advance;
  end;
  SetString(AToken.Value, @FData[LStart], FPos - LStart);
  SetError('Unterminated CDATA section');
  Result := False;
end;

function TXmlReader.ParsePI(out AToken: TXmlToken): Boolean;
var
  LStart, LCheckPos: SizeUInt;
  LTarget: TXmlName;
  LFound: PtrInt;
  LSelfClose: Boolean;
begin
  Result := True;
  LTarget := ParseName;
  AToken.Name := LTarget;
  AToken.IsSelfClosing := False;
  SetLength(AToken.Attributes, 0);
  if (LTarget.Prefix = '') and (LTarget.Local = 'xml') then
    AToken.Kind := xtkXmlDecl
  else
    AToken.Kind := xtkProcessingInstr;
  if AToken.Kind = xtkXmlDecl then
  begin
    ParseAttributes(AToken.Attributes, LSelfClose);
    AToken.Value := '';
    Exit;
  end;
  SkipWhitespace;
  LStart := FPos;
  while FPos < FLen do
  begin
    LFound := ScanFindByte(@FData[FPos], FLen - FPos, Byte('?'));
    if LFound < 0 then
    begin
      while FPos < FLen do Advance;
      Break;
    end;
    LCheckPos := FPos + SizeUInt(LFound);
    while FPos < LCheckPos do
      Advance;
    if (FPos + 1 < FLen) and (FData[FPos] = '?') and (FData[FPos + 1] = '>') then
    begin
      SetString(AToken.Value, @FData[LStart], FPos - LStart);
      Advance; Advance;
      Exit;
    end;
    Advance;
  end;
  SetString(AToken.Value, @FData[LStart], FPos - LStart);
  SetError('Unterminated processing instruction');
  Result := False;
end;

function TXmlReader.ParseDoctype(out AToken: TXmlToken): Boolean;
var
  LStart: SizeUInt;
  LDepth: Integer;
begin
  Result := True;
  AToken.Kind := xtkDoctype;
  AToken.Name.Prefix := '';
  AToken.Name.Local := '';
  AToken.IsSelfClosing := False;
  SetLength(AToken.Attributes, 0);
  LStart := FPos;
  LDepth := 0;
  while FPos < FLen do
  begin
    case FData[FPos] of
      '[': begin Inc(LDepth); Advance; end;
      ']': begin Dec(LDepth); Advance; end;
      '>': begin
        if LDepth <= 0 then
        begin
          SetString(AToken.Value, @FData[LStart], FPos - LStart);
          Advance;
          Exit;
        end;
        Advance;
      end;
    else
      Advance;
    end;
  end;
  SetString(AToken.Value, @FData[LStart], FPos - LStart);
  SetError('Unterminated DOCTYPE');
  Result := False;
end;

function TXmlReader.ParseMarkup(out AToken: TXmlToken): Boolean;
begin
  Result := True;
  if AtEnd then
  begin
    SetError('Unexpected end after <');
    Result := False;
    Exit;
  end;
  case FData[FPos] of
    '/': begin
      Advance;
      Result := ParseEndElement(AToken);
    end;
    '!': begin
      Advance;
      if (FPos + 1 < FLen) and (FData[FPos] = '-') and (FData[FPos + 1] = '-') then
      begin
        Advance; Advance;
        Result := ParseComment(AToken);
      end
      else if (FPos + 6 < FLen) and (FData[FPos] = '[') and (FData[FPos+1] = 'C') and
              (FData[FPos+2] = 'D') and (FData[FPos+3] = 'A') and (FData[FPos+4] = 'T') and
              (FData[FPos+5] = 'A') and (FData[FPos+6] = '[') then
      begin
        Advance; Advance; Advance; Advance; Advance; Advance; Advance;
        Result := ParseCData(AToken);
      end
      else if (FPos + 6 < FLen) and (FData[FPos] = 'D') and (FData[FPos+1] = 'O') and
              (FData[FPos+2] = 'C') and (FData[FPos+3] = 'T') and (FData[FPos+4] = 'Y') and
              (FData[FPos+5] = 'P') and (FData[FPos+6] = 'E') then
      begin
        Advance; Advance; Advance; Advance; Advance; Advance; Advance;
        SkipWhitespace;
        Result := ParseDoctype(AToken);
      end
      else
      begin
        SetError('Unknown markup declaration');
        Result := False;
      end;
    end;
    '?': begin
      Advance;
      Result := ParsePI(AToken);
    end;
  else
    Result := ParseStartOrEmptyElement(AToken);
  end;
end;

procedure TXmlReader.PushTag(const AName: string);
begin
  Inc(FTagStackTop);
  if FTagStackTop >= Length(FTagStack) then
    SetLength(FTagStack, Length(FTagStack) * 2);
  FTagStack[FTagStackTop] := AName;
end;

function TXmlReader.PopTag(const AName: string): Boolean;
begin
  if FTagStackTop < 0 then
  begin
    SetError('Unexpected end tag: ' + AName);
    Result := False;
    Exit;
  end;
  if FTagStack[FTagStackTop] <> AName then
  begin
    SetError('Mismatched end tag: expected ' + FTagStack[FTagStackTop] + ', got ' + AName);
    Result := False;
    Exit;
  end;
  Dec(FTagStackTop);
  Result := True;
end;

procedure TXmlReader.PushNamespaces(const AAttrs: TXmlAttributeArray);
var
  LI, LCount: Integer;
  LNs: TXmlNamespaceArray;
begin
  Inc(FNsStackTop);
  if FNsStackTop >= Length(FNsStack) then
    SetLength(FNsStack, Length(FNsStack) * 2);
  LCount := 0;
  SetLength(LNs, Length(AAttrs));
  for LI := 0 to High(AAttrs) do
  begin
    if (AAttrs[LI].Name.Prefix = '') and (AAttrs[LI].Name.Local = 'xmlns') then
    begin
      LNs[LCount].Prefix := '';
      LNs[LCount].URI := AAttrs[LI].Value;
      Inc(LCount);
    end
    else if AAttrs[LI].Name.Prefix = 'xmlns' then
    begin
      LNs[LCount].Prefix := AAttrs[LI].Name.Local;
      LNs[LCount].URI := AAttrs[LI].Value;
      Inc(LCount);
    end;
  end;
  SetLength(LNs, LCount);
  FNsStack[FNsStackTop] := LNs;
end;

procedure TXmlReader.PopNamespaces;
begin
  if FNsStackTop >= 0 then
    Dec(FNsStackTop);
end;

procedure TXmlReader.SetError(const AMsg: string);
begin
  if not FHasError then
  begin
    FHasError := True;
    FError := Format('[%d:%d] %s', [FLine, FCol, AMsg]);
  end;
end;

function TXmlReader.Next(out AToken: TXmlToken): Boolean;
var
  LTextStart, LEntStart, LTarget: SizeUInt;
  LText, LPart, LEntStr: string;
  LFound: PtrInt;
begin
  Result := False;
  if FHasError then Exit;
  AToken.Kind := xtkNone;
  AToken.Name.Prefix := '';
  AToken.Name.Local := '';
  AToken.Value := '';
  AToken.IsSelfClosing := False;
  SetLength(AToken.Attributes, 0);

  { Skip BOM at start }
  if (FPos = 0) and (FLen >= 3) and
     (Byte(FData[0]) = $EF) and (Byte(FData[1]) = $BB) and (Byte(FData[2]) = $BF) then
  begin
    Inc(FPos, 3);
    Inc(FCol, 3);
  end;

  if AtEnd then
  begin
    { HIGH 4 fix: check for unclosed tags at EOF }
    if FTagStackTop >= 0 then
      SetError('Unclosed element: ' + FTagStack[FTagStackTop]);
    Exit;
  end;

  if FData[FPos] = '<' then
  begin
    Advance;
    Result := ParseMarkup(AToken);
    Exit;
  end;

  { Text content }
  LTextStart := FPos;
  LText := '';
  while (FPos < FLen) and (FData[FPos] <> '<') do
  begin
    if FData[FPos] = '&' then
    begin
      if FPos > LTextStart then
      begin
        SetString(LPart, @FData[LTextStart], FPos - LTextStart);
        LText := LText + LPart;
      end;
      LEntStart := FPos;
      Advance;
      while (FPos < FLen) and (FData[FPos] <> ';') and (FPos - LEntStart < 12) do
        Advance;
      if (FPos < FLen) and (FData[FPos] = ';') then
        Advance;
      SetString(LEntStr, @FData[LEntStart], FPos - LEntStart);
      LText := LText + XmlDecodeEntities(LEntStr);
      LTextStart := FPos;
    end
    else
    begin
      LFound := ScanFindByte2(@FData[FPos], FLen - FPos, Byte('<'), Byte('&'));
      if LFound < 0 then
      begin
        while FPos < FLen do Advance;
      end
      else
      begin
        LTarget := FPos + SizeUInt(LFound);
        while FPos < LTarget do
          Advance;
      end;
    end;
  end;
  if FPos > LTextStart then
  begin
    SetString(LPart, @FData[LTextStart], FPos - LTextStart);
    LText := LText + LPart;
  end;
  if LText <> '' then
  begin
    AToken.Kind := xtkText;
    AToken.Value := LText;
    Result := True;
  end;
end;

function TXmlReader.Position: TXmlPosition;
begin
  Result.ByteOffset := FPos;
  Result.Line := FLine;
  Result.Column := FCol;
end;

function TXmlReader.GetError: string;
begin
  Result := FError;
end;

function TXmlReader.HasError: Boolean;
begin
  Result := FHasError;
end;

function TXmlReader.ResolveNamespace(const APrefix: string): string;
var
  LI, LJ: Integer;
begin
  Result := '';
  for LI := FNsStackTop downto 0 do
    for LJ := 0 to High(FNsStack[LI]) do
      if FNsStack[LI][LJ].Prefix = APrefix then
      begin
        Result := FNsStack[LI][LJ].URI;
        Exit;
      end;
end;

function TXmlReader.Depth: Integer;
begin
  Result := FTagStackTop + 1;
end;

end.
