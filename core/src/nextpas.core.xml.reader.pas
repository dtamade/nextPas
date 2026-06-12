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
    FHasYieldedToken: Boolean;
    function Peek: AnsiChar; inline;
    function Advance: AnsiChar;
    function AtEnd: Boolean; inline;
    procedure SkipWhitespace;
    function ParseRawName: string;
    function ParseQName(
      const AExpectedMessage, AInvalidMessage: string;
      out AName: TXmlName): Boolean;
    function ParsePITarget(out AName: TXmlName; out AIsXmlDecl: Boolean): Boolean;
    function ParseQuotedValue: string;
    procedure ParseAttributes(
      out AAttrs: TXmlAttributeArray;
      out ASelfClose: Boolean;
      ARejectDuplicates: Boolean);
    function ValidateXmlDeclAttributes(
      const AAttrs: TXmlAttributeArray): Boolean;
    function ParseStartOrEmptyElement(out AToken: TXmlToken): Boolean;
    function ParseEndElement(out AToken: TXmlToken): Boolean;
    function ParseComment(out AToken: TXmlToken): Boolean;
    function ParseCData(out AToken: TXmlToken): Boolean;
    function ParsePI(out AToken: TXmlToken): Boolean;
    function ParseDoctype(out AToken: TXmlToken): Boolean;
    function ParseMarkup(out AToken: TXmlToken): Boolean;
    procedure PushTag(const AName: string);
    function PopTag(const AName: string): Boolean;
    function PushNamespaces(const AAttrs: TXmlAttributeArray): Boolean;
    procedure PopNamespaces;
    function NamespacePrefixIsBound(const APrefix: string): Boolean;
    function ValidateNamespacePrefixes(
      const AName: TXmlName;
      const AAttrs: TXmlAttributeArray): Boolean;
    function ValidateAttributeExpandedNames(
      const AAttrs: TXmlAttributeArray): Boolean;
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

const
  XmlNamespaceUri = 'http://www.w3.org/XML/1998/namespace';
  XmlnsNamespaceUri = 'http://www.w3.org/2000/xmlns/';

function IsXmlAsciiNameStartChar(ACh: AnsiChar): Boolean;
begin
  Result := ACh in ['A'..'Z', 'a'..'z', '_'];
end;

function IsXmlAsciiNameChar(ACh: AnsiChar): Boolean;
begin
  Result := ACh in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.'];
end;

function IsXmlAsciiQName(const AName: string): Boolean;
var
  LI: Integer;
  LAtPartStart: Boolean;
  LSeenColon: Boolean;
begin
  Result := False;
  if AName = '' then
    Exit;

  LAtPartStart := True;
  LSeenColon := False;
  for LI := 1 to Length(AName) do
  begin
    if AName[LI] = ':' then
    begin
      if LSeenColon or LAtPartStart or (LI = Length(AName)) then
        Exit;
      LSeenColon := True;
      LAtPartStart := True;
      Continue;
    end;

    if LAtPartStart then
    begin
      if not IsXmlAsciiNameStartChar(AName[LI]) then
        Exit;
      LAtPartStart := False;
    end
    else if not IsXmlAsciiNameChar(AName[LI]) then
      Exit;
  end;

  Result := not LAtPartStart;
end;

function IsXmlEncodingName(const AValue: string): Boolean;
var
  LI: Integer;
begin
  Result := False;
  if AValue = '' then
    Exit;
  if not (AValue[1] in ['A'..'Z', 'a'..'z']) then
    Exit;
  for LI := 2 to Length(AValue) do
  begin
    if not (AValue[LI] in ['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-']) then
      Exit;
  end;
  Result := True;
end;

function IsXmlVersionNumber(const AValue: string): Boolean;
var
  LI: Integer;
begin
  Result := False;
  if Length(AValue) < 3 then
    Exit;
  if (AValue[1] <> '1') or (AValue[2] <> '.') then
    Exit;
  for LI := 3 to Length(AValue) do
  begin
    if not (AValue[LI] in ['0'..'9']) then
      Exit;
  end;
  Result := True;
end;

function SplitXmlQName(const AName: string): TXmlName;
var
  LColonPos: Integer;
begin
  Result.Prefix := '';
  Result.Local := AName;
  LColonPos := Pos(':', AName);
  if LColonPos > 0 then
  begin
    Result.Prefix := Copy(AName, 1, LColonPos - 1);
    Result.Local := Copy(AName, LColonPos + 1, Length(AName) - LColonPos);
  end;
end;

function IsXmlReservedPITarget(const ATarget: string): Boolean;
begin
  Result := (Length(ATarget) = 3) and
    (((ATarget[1] = 'x') or (ATarget[1] = 'X')) and
     ((ATarget[2] = 'm') or (ATarget[2] = 'M')) and
     ((ATarget[3] = 'l') or (ATarget[3] = 'L')));
end;

function GetNamespaceDeclError(const APrefix, AURI: string): string;
begin
  Result := '';
  if APrefix = 'xmlns' then
    Result := 'prefix "xmlns" is reserved'
  else if (APrefix <> '') and (AURI = '') then
    Result := 'prefixed namespace declarations must not use an empty URI'
  else if APrefix = 'xml' then
  begin
    if AURI <> XmlNamespaceUri then
      Result := 'prefix "xml" must bind to the XML namespace URI';
  end
  else if AURI = XmlNamespaceUri then
    Result := 'the XML namespace URI must bind only to prefix "xml"'
  else if AURI = XmlnsNamespaceUri then
    Result := 'the XMLNS namespace URI must not be declared';
end;

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
  FHasYieldedToken := False;
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
  case Result of
    #13:
      begin
        if (FPos < FLen) and (FData[FPos] = #10) then
          Inc(FPos);
        Inc(FLine);
        FCol := 1;
      end;
    #10:
      begin
        Inc(FLine);
        FCol := 1;
      end;
  else
    Inc(FCol);
  end;
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

function TXmlReader.ParseRawName: string;
var
  LStart: SizeUInt;
begin
  Result := '';
  LStart := FPos;
  if AtEnd then
    Exit;
  if not (FData[FPos] in ['A'..'Z', 'a'..'z', '_', ':']) then Exit;
  Advance;
  while (FPos < FLen) and (FData[FPos] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.', ':']) do
    Advance;
  SetString(Result, @FData[LStart], FPos - LStart);
end;

function TXmlReader.ParseQName(
  const AExpectedMessage, AInvalidMessage: string;
  out AName: TXmlName): Boolean;
var
  LRawName: string;
begin
  Result := False;
  AName.Prefix := '';
  AName.Local := '';

  LRawName := ParseRawName;
  if LRawName = '' then
  begin
    SetError(AExpectedMessage);
    Exit;
  end;
  if not IsXmlAsciiQName(LRawName) then
  begin
    SetError(AInvalidMessage);
    Exit;
  end;

  AName := SplitXmlQName(LRawName);
  Result := True;
end;

function TXmlReader.ParsePITarget(out AName: TXmlName; out AIsXmlDecl: Boolean): Boolean;
var
  LRawTarget: string;
begin
  Result := False;
  AIsXmlDecl := False;
  AName.Prefix := '';
  AName.Local := '';

  LRawTarget := ParseRawName;
  if LRawTarget = '' then
  begin
    SetError('Expected processing-instruction target');
    Exit;
  end;
  if IsXmlReservedPITarget(LRawTarget) then
  begin
    if LRawTarget = 'xml' then
    begin
      AName := SplitXmlQName(LRawTarget);
      AIsXmlDecl := True;
      Result := True;
      Exit;
    end;
    SetError(
      'processing-instruction target "xml" is reserved for XML declarations');
    Exit;
  end;
  if not IsXmlAsciiQName(LRawTarget) then
  begin
    SetError('processing-instruction target must be a valid XML QName');
    Exit;
  end;

  AName := SplitXmlQName(LRawTarget);
  Result := True;
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
  LFound := ScanFindByte2(@FData[FPos], FLen - FPos, Byte(LQuote), Byte('<'));
  if LFound < 0 then
  begin
    SetError('Unterminated attribute value');
    while FPos < FLen do Advance;
    SetString(Result, @FData[LStart], FPos - LStart);
    Exit;
  end;
  while FPos < LStart + SizeUInt(LFound) do
    Advance;
  if FData[FPos] = '<' then
  begin
    SetError('attribute value must not contain raw <');
    Exit;
  end;
  SetString(Result, @FData[LStart], FPos - LStart);
  Advance;
  Result := XmlDecodeEntities(Result);
end;

procedure TXmlReader.ParseAttributes(
  out AAttrs: TXmlAttributeArray;
  out ASelfClose: Boolean;
  ARejectDuplicates: Boolean);
var
  LCount, LCap, LI: Integer;
  LName: TXmlName;
  LNameFull: string;
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
    if not ParseQName(
      'Expected attribute name',
      'attribute name must be a valid XML QName',
      LName) then
    begin
      SetLength(AAttrs, LCount);
      Exit;
    end;
    if ARejectDuplicates then
    begin
      LNameFull := LName.Full;
      for LI := 0 to LCount - 1 do
      begin
        if AAttrs[LI].Name.Full = LNameFull then
        begin
          SetError('attribute "' + LNameFull + '" must not appear more than once');
          SetLength(AAttrs, LCount);
          Exit;
        end;
      end;
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

function TXmlReader.ValidateXmlDeclAttributes(
  const AAttrs: TXmlAttributeArray): Boolean;
var
  LI: Integer;
  LAttr: TXmlAttribute;
  LAttrName: string;
  LSeenVersion: Boolean;
  LSeenEncoding: Boolean;
  LSeenStandalone: Boolean;
begin
  Result := False;
  if Length(AAttrs) = 0 then
  begin
    SetError('XML declaration must include a version attribute first');
    Exit;
  end;

  LSeenVersion := False;
  LSeenEncoding := False;
  LSeenStandalone := False;
  for LI := 0 to High(AAttrs) do
  begin
    LAttr := AAttrs[LI];
    if LAttr.Name.Prefix <> '' then
    begin
      SetError(
        'XML declaration attribute "' + LAttr.Name.Full + '" is not supported');
      Exit;
    end;

    LAttrName := LAttr.Name.Local;
    if LAttrName = 'version' then
    begin
      if LSeenVersion then
      begin
        SetError(
          'XML declaration attribute "version" must not appear more than once');
        Exit;
      end;
      if LI <> 0 then
      begin
        SetError('XML declaration must include a version attribute first');
        Exit;
      end;
      if not IsXmlVersionNumber(LAttr.Value) then
      begin
        SetError('XML declaration version must be a valid XML version number');
        Exit;
      end;
      LSeenVersion := True;
      Continue;
    end;

    if not LSeenVersion then
    begin
      SetError('XML declaration must include a version attribute first');
      Exit;
    end;

    if LAttrName = 'encoding' then
    begin
      if LSeenEncoding then
      begin
        SetError(
          'XML declaration attribute "encoding" must not appear more than once');
        Exit;
      end;
      if LSeenStandalone then
      begin
        SetError(
          'XML declaration attribute "encoding" must appear before "standalone"');
        Exit;
      end;
      if not IsXmlEncodingName(LAttr.Value) then
      begin
        SetError('XML declaration encoding must be a valid XML encoding name');
        Exit;
      end;
      LSeenEncoding := True;
      Continue;
    end;

    if LAttrName = 'standalone' then
    begin
      if LSeenStandalone then
      begin
        SetError(
          'XML declaration attribute "standalone" must not appear more than once');
        Exit;
      end;
      if (LAttr.Value <> 'yes') and (LAttr.Value <> 'no') then
      begin
        SetError('XML declaration standalone value must be "yes" or "no"');
        Exit;
      end;
      LSeenStandalone := True;
      Continue;
    end;

    SetError(
      'XML declaration attribute "' + LAttr.Name.Full + '" is not supported');
      Exit;
  end;

  if not LSeenVersion then
  begin
    SetError('XML declaration must include a version attribute first');
    Exit;
  end;

  Result := True;
end;

function TXmlReader.ParseStartOrEmptyElement(out AToken: TXmlToken): Boolean;
var
  LAttrs: TXmlAttributeArray;
  LSelfClose: Boolean;
begin
  Result := True;
  if not ParseQName(
    'Expected element name',
    'element name must be a valid XML QName',
    AToken.Name) then
  begin
    Result := False;
    Exit;
  end;
  ParseAttributes(LAttrs, LSelfClose, True);
  if FHasError then begin Result := False; Exit; end;
  AToken.Attributes := LAttrs;
  AToken.Value := '';
  if LSelfClose then
  begin
    AToken.Kind := xtkEmptyElement;
    AToken.IsSelfClosing := True;
    if not PushNamespaces(LAttrs) then
    begin
      Result := False;
      Exit;
    end;
    if not ValidateNamespacePrefixes(AToken.Name, LAttrs) then
    begin
      PopNamespaces;
      Result := False;
      Exit;
    end;
    if not ValidateAttributeExpandedNames(LAttrs) then
    begin
      PopNamespaces;
      Result := False;
      Exit;
    end;
    PopNamespaces;
  end
  else
  begin
    AToken.Kind := xtkStartElement;
    AToken.IsSelfClosing := False;
    if not PushNamespaces(LAttrs) then
    begin
      Result := False;
      Exit;
    end;
    if not ValidateNamespacePrefixes(AToken.Name, LAttrs) then
    begin
      PopNamespaces;
      Result := False;
      Exit;
    end;
    if not ValidateAttributeExpandedNames(LAttrs) then
    begin
      PopNamespaces;
      Result := False;
      Exit;
    end;
    PushTag(AToken.Name.Full);
  end;
end;

function TXmlReader.ParseEndElement(out AToken: TXmlToken): Boolean;
begin
  Result := True;
  AToken.Kind := xtkEndElement;
  if not ParseQName(
    'Expected end element name',
    'end element name must be a valid XML QName',
    AToken.Name) then
  begin
    Result := False;
    Exit;
  end;
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
  if not NamespacePrefixIsBound(AToken.Name.Prefix) then
  begin
    SetError('namespace prefix "' + AToken.Name.Prefix + '" is not bound');
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
      if Pos('--', AToken.Value) > 0 then
      begin
        SetError('comment text must not contain "--"');
        Result := False;
        Exit;
      end;
      if (Length(AToken.Value) > 0) and
        (AToken.Value[Length(AToken.Value)] = '-') then
      begin
        SetError('comment text must not end with "-"');
        Result := False;
        Exit;
      end;
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
  LIsXmlDecl: Boolean;
  LSelfClose: Boolean;
begin
  Result := True;
  if not ParsePITarget(LTarget, LIsXmlDecl) then
  begin
    Result := False;
    Exit;
  end;
  AToken.Name := LTarget;
  AToken.IsSelfClosing := False;
  SetLength(AToken.Attributes, 0);
  if LIsXmlDecl then
  begin
    if FHasYieldedToken then
    begin
      SetError('XML declaration must be the first token in the document');
      Result := False;
      Exit;
    end;
    AToken.Kind := xtkXmlDecl
  end
  else
    AToken.Kind := xtkProcessingInstr;
  if AToken.Kind = xtkXmlDecl then
  begin
    ParseAttributes(AToken.Attributes, LSelfClose, False);
    AToken.Value := '';
    if FHasError then
    begin
      Result := False;
      Exit;
    end;
    if not ValidateXmlDeclAttributes(AToken.Attributes) then
    begin
      Result := False;
      Exit;
    end;
    if (FPos < 2) or (FData[FPos - 2] <> '?') then
    begin
      SetError('XML declaration must end with ?>');
      Result := False;
      Exit;
    end;
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

function TXmlReader.PushNamespaces(const AAttrs: TXmlAttributeArray): Boolean;
var
  LI, LCount: Integer;
  LNs: TXmlNamespaceArray;
  LPrefix, LError: string;
begin
  Result := False;
  LCount := 0;
  SetLength(LNs, Length(AAttrs));
  for LI := 0 to High(AAttrs) do
  begin
    if (AAttrs[LI].Name.Prefix = '') and (AAttrs[LI].Name.Local = 'xmlns') then
    begin
      LPrefix := '';
      LError := GetNamespaceDeclError(LPrefix, AAttrs[LI].Value);
      if LError <> '' then
      begin
        SetError('Invalid namespace declaration: ' + LError);
        Exit;
      end;
      LNs[LCount].Prefix := '';
      LNs[LCount].URI := AAttrs[LI].Value;
      Inc(LCount);
    end
    else if AAttrs[LI].Name.Prefix = 'xmlns' then
    begin
      LPrefix := AAttrs[LI].Name.Local;
      LError := GetNamespaceDeclError(LPrefix, AAttrs[LI].Value);
      if LError <> '' then
      begin
        SetError('Invalid namespace declaration: ' + LError);
        Exit;
      end;
      LNs[LCount].Prefix := AAttrs[LI].Name.Local;
      LNs[LCount].URI := AAttrs[LI].Value;
      Inc(LCount);
    end;
  end;
  SetLength(LNs, LCount);
  Inc(FNsStackTop);
  if FNsStackTop >= Length(FNsStack) then
    SetLength(FNsStack, Length(FNsStack) * 2);
  FNsStack[FNsStackTop] := LNs;
  Result := True;
end;

procedure TXmlReader.PopNamespaces;
begin
  if FNsStackTop >= 0 then
    Dec(FNsStackTop);
end;

function TXmlReader.NamespacePrefixIsBound(const APrefix: string): Boolean;
begin
  if (APrefix = '') or (APrefix = 'xml') then
    Exit(True);
  Result := ResolveNamespace(APrefix) <> '';
end;

function TXmlReader.ValidateNamespacePrefixes(
  const AName: TXmlName;
  const AAttrs: TXmlAttributeArray): Boolean;
var
  LI: Integer;
begin
  Result := False;
  if not NamespacePrefixIsBound(AName.Prefix) then
  begin
    SetError('namespace prefix "' + AName.Prefix + '" is not bound');
    Exit;
  end;

  for LI := 0 to High(AAttrs) do
  begin
    if (AAttrs[LI].Name.Prefix = '') and (AAttrs[LI].Name.Local = 'xmlns') then
      Continue;
    if AAttrs[LI].Name.Prefix = 'xmlns' then
      Continue;
    if not NamespacePrefixIsBound(AAttrs[LI].Name.Prefix) then
    begin
      SetError('namespace prefix "' + AAttrs[LI].Name.Prefix + '" is not bound');
      Exit;
    end;
  end;

  Result := True;
end;

function TXmlReader.ValidateAttributeExpandedNames(
  const AAttrs: TXmlAttributeArray): Boolean;
var
  LI, LJ: Integer;
  LUriI, LUriJ: string;
begin
  Result := False;
  for LI := 0 to High(AAttrs) do
  begin
    if ((AAttrs[LI].Name.Prefix = '') and (AAttrs[LI].Name.Local = 'xmlns')) or
      (AAttrs[LI].Name.Prefix = 'xmlns') then
      Continue;

    if AAttrs[LI].Name.Prefix = '' then
      LUriI := ''
    else
      LUriI := ResolveNamespace(AAttrs[LI].Name.Prefix);

    for LJ := LI + 1 to High(AAttrs) do
    begin
      if ((AAttrs[LJ].Name.Prefix = '') and (AAttrs[LJ].Name.Local = 'xmlns')) or
        (AAttrs[LJ].Name.Prefix = 'xmlns') then
        Continue;
      if AAttrs[LI].Name.Local <> AAttrs[LJ].Name.Local then
        Continue;

      if AAttrs[LJ].Name.Prefix = '' then
        LUriJ := ''
      else
        LUriJ := ResolveNamespace(AAttrs[LJ].Name.Prefix);

      if LUriI = LUriJ then
      begin
        SetError('attribute "' + AAttrs[LI].Name.Full + '" and "' +
          AAttrs[LJ].Name.Full + '" must not appear more than once');
        Exit;
      end;
    end;
  end;
  Result := True;
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

  AToken.Position := Position;

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
    if Result then
      FHasYieldedToken := True;
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
    FHasYieldedToken := True;
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
  if APrefix = 'xml' then
  begin
    Result := XmlNamespaceUri;
    Exit;
  end;

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
