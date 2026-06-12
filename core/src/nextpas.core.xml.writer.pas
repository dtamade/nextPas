unit nextpas.core.xml.writer;
{**
 * @desc XML 输出器，支持 pretty print 和 compact 模式。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.xml.base;

type
  TXmlWriter = class
  private
    FBuf: string;
    FBufLen: Integer;
    FIndent: string;
    FDepth: Integer;
    FInStartTag: Boolean;
    FPretty: Boolean;
    FHasChildren: Boolean;
    FHasChildStack: array of Boolean;
    FHasChildTop: Integer;
    { HIGH 6 fix: element name stack to track open elements }
    FElementStack: array of string;
    FElementStackTop: Integer;
    FAttributeNames: array of string;
    FAttributeNameCount: Integer;
    procedure FlushStartTag;
    procedure WriteIndent;
    procedure AppendStr(const AStr: string);
    procedure AppendChar(ACh: AnsiChar);
    procedure AppendCDataValue(const AValue: string);
    procedure AppendPIData(const ATarget, AData: string);
    procedure ResetAttributeNames;
    procedure RequireUniqueAttributeName(const AName: string);
    procedure PushHasChild;
    procedure PopHasChild;
  public
    constructor Create(APretty: Boolean = False; const AIndent: string = '  ');
    destructor Destroy; override;
    procedure WriteXmlDecl(
      const AVersion: string = '1.0';
      const AEncoding: string = 'UTF-8';
      const AStandalone: string = '');
    procedure StartElement(const AName: string); overload;
    procedure StartElement(const APrefix, ALocal: string); overload;
    procedure Attribute(const AName, AValue: string);
    procedure NamespaceDecl(const APrefix, AURI: string);
    procedure EndElement(const AName: string);
    procedure EmptyElement(const AName: string);
    procedure Text(const AValue: string);
    procedure CData(const AValue: string);
    procedure Comment(const AValue: string);
    procedure PI(const ATarget, AData: string);
    procedure Raw(const AStr: string);
    function ToString: string; override;
    procedure Clear;
  end;

implementation

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

function IsXmlAllowedChar(ACh: Char): Boolean;
begin
  case Ord(ACh) of
    9, 10, 13:
      Result := True;
  else
    Result := Ord(ACh) >= 32;
  end;
end;

function FindInvalidXmlControlChar(const AValue: string): Integer;
var
  LI: Integer;
begin
  Result := 0;
  for LI := 1 to Length(AValue) do
  begin
    if not IsXmlAllowedChar(AValue[LI]) then
      Exit(LI);
  end;
end;

procedure RequireXmlQName(const AMethod, AName: string);
begin
  if AName = '' then
    raise EArgumentError.Create(
      'TXmlWriter.' + AMethod + ': name must not be empty');
  if not IsXmlAsciiQName(AName) then
    raise EArgumentError.Create(
      'TXmlWriter.' + AMethod + ': name must be a valid XML QName');
end;

procedure RequireXmlPITarget(const ATarget: string);
begin
  if ATarget = '' then
    raise EArgumentError.Create(
      'TXmlWriter.PI: target must not be empty');
  if not IsXmlAsciiQName(ATarget) then
    raise EArgumentError.Create(
      'TXmlWriter.PI: target must be a valid XML processing-instruction target');
end;

procedure RequireXmlValueChars(const AMethod, AValueName, AValue: string);
begin
  if FindInvalidXmlControlChar(AValue) <> 0 then
    raise EArgumentError.Create(
      'TXmlWriter.' + AMethod + ': ' + AValueName +
      ' must not contain XML 1.0 forbidden control characters');
end;

const
  XmlNamespaceUri = 'http://www.w3.org/XML/1998/namespace';
  XmlnsNamespaceUri = 'http://www.w3.org/2000/xmlns/';

procedure RequireXmlNamespaceDecl(const APrefix, AURI: string);
begin
  if APrefix = 'xmlns' then
    raise EArgumentError.Create(
      'TXmlWriter.NamespaceDecl: prefix "xmlns" is reserved');
  if (APrefix <> '') and (AURI = '') then
    raise EArgumentError.Create(
      'TXmlWriter.NamespaceDecl: prefixed namespace declarations must not use an empty URI');
  if APrefix = 'xml' then
  begin
    if AURI <> XmlNamespaceUri then
      raise EArgumentError.Create(
        'TXmlWriter.NamespaceDecl: prefix "xml" must bind to the XML namespace URI');
    Exit;
  end;
  if AURI = XmlNamespaceUri then
    raise EArgumentError.Create(
      'TXmlWriter.NamespaceDecl: the XML namespace URI must bind only to prefix "xml"');
  if AURI = XmlnsNamespaceUri then
    raise EArgumentError.Create(
      'TXmlWriter.NamespaceDecl: the XMLNS namespace URI must not be declared');
end;

{ TXmlWriter }

constructor TXmlWriter.Create(APretty: Boolean; const AIndent: string);
begin
  inherited Create;
  FPretty := APretty;
  FIndent := AIndent;
  FDepth := 0;
  FInStartTag := False;
  FHasChildren := False;
  FBuf := '';
  FBufLen := 0;
  SetLength(FHasChildStack, 32);
  FHasChildTop := -1;
  { HIGH 6 fix: initialize element stack }
  SetLength(FElementStack, 32);
  FElementStackTop := -1;
  SetLength(FAttributeNames, 8);
  FAttributeNameCount := 0;
end;

destructor TXmlWriter.Destroy;
begin
  inherited;
end;

procedure TXmlWriter.AppendStr(const AStr: string);
var
  LLen: Integer;
begin
  LLen := Length(AStr);
  if LLen = 0 then Exit;
  while FBufLen + LLen > Length(FBuf) do
  begin
    if Length(FBuf) = 0 then
      SetLength(FBuf, 256)
    else
      SetLength(FBuf, Length(FBuf) * 2);
  end;
  Move(AStr[1], FBuf[FBufLen + 1], LLen);
  Inc(FBufLen, LLen);
end;

procedure TXmlWriter.AppendChar(ACh: AnsiChar);
begin
  if FBufLen + 1 > Length(FBuf) then
  begin
    if Length(FBuf) = 0 then
      SetLength(FBuf, 256)
    else
      SetLength(FBuf, Length(FBuf) * 2);
  end;
  Inc(FBufLen);
  FBuf[FBufLen] := ACh;
end;

procedure TXmlWriter.AppendCDataValue(const AValue: string);
var
  LStart, LPos, LLen: Integer;
begin
  LLen := Length(AValue);
  LStart := 1;
  LPos := 1;
  while LPos <= LLen - 2 do
  begin
    if (AValue[LPos] = ']') and (AValue[LPos + 1] = ']') and
      (AValue[LPos + 2] = '>') then
    begin
      if LPos > LStart then
        AppendStr(Copy(AValue, LStart, LPos - LStart));
      AppendStr(']]]]><![CDATA[>');
      Inc(LPos, 3);
      LStart := LPos;
    end
    else
      Inc(LPos);
  end;
  if LStart <= LLen then
    AppendStr(Copy(AValue, LStart, LLen - LStart + 1));
end;

procedure TXmlWriter.AppendPIData(const ATarget, AData: string);
var
  LStart, LPos, LLen: Integer;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit;
  LStart := 1;
  LPos := 1;
  while LPos <= LLen - 1 do
  begin
    if (AData[LPos] = '?') and (AData[LPos + 1] = '>') then
    begin
      AppendStr(Copy(AData, LStart, LPos - LStart + 1));
      AppendStr('?><?');
      AppendStr(ATarget);
      AppendChar(' ');
      AppendChar('>');
      Inc(LPos, 2);
      LStart := LPos;
    end
    else
      Inc(LPos);
  end;
  if LStart <= LLen then
    AppendStr(Copy(AData, LStart, LLen - LStart + 1));
end;

procedure TXmlWriter.PushHasChild;
begin
  Inc(FHasChildTop);
  if FHasChildTop >= Length(FHasChildStack) then
    SetLength(FHasChildStack, Length(FHasChildStack) * 2);
  FHasChildStack[FHasChildTop] := FHasChildren;
  FHasChildren := False;
end;

procedure TXmlWriter.PopHasChild;
begin
  if FHasChildTop >= 0 then
  begin
    FHasChildren := FHasChildStack[FHasChildTop];
    Dec(FHasChildTop);
  end;
end;

procedure TXmlWriter.ResetAttributeNames;
begin
  FAttributeNameCount := 0;
end;

procedure TXmlWriter.RequireUniqueAttributeName(const AName: string);
var
  LI: Integer;
begin
  for LI := 0 to FAttributeNameCount - 1 do
  begin
    if FAttributeNames[LI] = AName then
      raise EArgumentError.Create(
        'TXmlWriter.Attribute: duplicate attribute QName "' + AName + '"');
  end;

  if FAttributeNameCount >= Length(FAttributeNames) then
    SetLength(FAttributeNames, Length(FAttributeNames) * 2);
  FAttributeNames[FAttributeNameCount] := AName;
  Inc(FAttributeNameCount);
end;

procedure TXmlWriter.FlushStartTag;
begin
  if FInStartTag then
  begin
    AppendChar('>');
    FInStartTag := False;
    ResetAttributeNames;
  end;
end;

procedure TXmlWriter.WriteIndent;
var
  LI: Integer;
begin
  if not FPretty then Exit;
  for LI := 1 to FDepth do
    AppendStr(FIndent);
end;

procedure TXmlWriter.WriteXmlDecl(
  const AVersion: string;
  const AEncoding: string;
  const AStandalone: string);
begin
  if FBufLen <> 0 then
    raise EArgumentError.Create(
      'TXmlWriter.WriteXmlDecl: XML declaration must be the first output');
  if AVersion = '' then
    raise EArgumentError.Create(
      'TXmlWriter.WriteXmlDecl: version must not be empty');
  if not IsXmlVersionNumber(AVersion) then
    raise EArgumentError.Create(
      'TXmlWriter.WriteXmlDecl: version must be a valid XML version number');
  if (AEncoding <> '') and (not IsXmlEncodingName(AEncoding)) then
    raise EArgumentError.Create(
      'TXmlWriter.WriteXmlDecl: encoding must be a valid XML encoding name');
  if (AStandalone <> '') and (AStandalone <> 'yes') and (AStandalone <> 'no') then
    raise EArgumentError.Create(
      'TXmlWriter.WriteXmlDecl: standalone must be "yes" or "no"');
  AppendStr('<?xml version="');
  AppendStr(AVersion);
  if AEncoding <> '' then
  begin
    AppendStr('" encoding="');
    AppendStr(AEncoding);
  end;
  if AStandalone <> '' then
  begin
    AppendStr('" standalone="');
    AppendStr(AStandalone);
  end;
  AppendStr('"?>');
  if FPretty then
    AppendChar(#10);
end;

procedure TXmlWriter.StartElement(const AName: string);
begin
  RequireXmlQName('StartElement', AName);
  FlushStartTag;
  if FPretty and (FBufLen > 0) and (FBuf[FBufLen] <> #10) then
    AppendChar(#10);
  WriteIndent;
  AppendChar('<');
  AppendStr(AName);
  FInStartTag := True;
  ResetAttributeNames;
  if FHasChildTop >= 0 then
    FHasChildren := True;
  PushHasChild;
  Inc(FDepth);
  { HIGH 6 fix: push element name onto stack }
  Inc(FElementStackTop);
  if FElementStackTop >= Length(FElementStack) then
    SetLength(FElementStack, Length(FElementStack) * 2);
  FElementStack[FElementStackTop] := AName;
end;

procedure TXmlWriter.StartElement(const APrefix, ALocal: string);
begin
  if APrefix = '' then
    StartElement(ALocal)
  else
    StartElement(APrefix + ':' + ALocal);
end;

procedure TXmlWriter.Attribute(const AName, AValue: string);
begin
  if not FInStartTag then Exit;
  RequireXmlQName('Attribute', AName);
  RequireXmlValueChars('Attribute', 'value', AValue);
  RequireUniqueAttributeName(AName);
  AppendChar(' ');
  AppendStr(AName);
  AppendStr('="');
  AppendStr(XmlEncodeAttr(AValue));
  AppendChar('"');
end;

procedure TXmlWriter.NamespaceDecl(const APrefix, AURI: string);
begin
  if not FInStartTag then Exit;
  RequireXmlNamespaceDecl(APrefix, AURI);
  if APrefix = '' then
    Attribute('xmlns', AURI)
  else
    Attribute('xmlns:' + APrefix, AURI);
end;

procedure TXmlWriter.EndElement(const AName: string);
begin
  if FElementStackTop < 0 then
    raise EArgumentError.CreateFmt(
      'TXmlWriter.EndElement: unexpected close "%s" with no open element',
      [AName]);
  if (FElementStackTop >= 0) and (FElementStack[FElementStackTop] <> AName) then
    raise EArgumentError.CreateFmt(
      'TXmlWriter.EndElement: expected "%s" but got "%s"',
      [FElementStack[FElementStackTop], AName]);
  Dec(FDepth);
  if FInStartTag then
  begin
    AppendStr('/>');
    FInStartTag := False;
    ResetAttributeNames;
    PopHasChild;
    if FHasChildTop >= 0 then
      FHasChildren := True;
    { HIGH 6 fix: pop element stack }
    if FElementStackTop >= 0 then
      Dec(FElementStackTop);
    Exit;
  end;
  if FPretty and FHasChildren then
  begin
    AppendChar(#10);
    WriteIndent;
  end;
  PopHasChild;
  AppendStr('</');
  AppendStr(AName);
  AppendChar('>');
  if FHasChildTop >= 0 then
    FHasChildren := True;
  { HIGH 6 fix: pop element stack }
  if FElementStackTop >= 0 then
    Dec(FElementStackTop);
end;

procedure TXmlWriter.EmptyElement(const AName: string);
begin
  RequireXmlQName('EmptyElement', AName);
  FlushStartTag;
  if FPretty and (FBufLen > 0) then
    AppendChar(#10);
  WriteIndent;
  AppendChar('<');
  AppendStr(AName);
  AppendStr('/>');
  if FHasChildTop >= 0 then
    FHasChildren := True;
end;

procedure TXmlWriter.Text(const AValue: string);
begin
  RequireXmlValueChars('Text', 'value', AValue);
  FlushStartTag;
  AppendStr(XmlEncodeText(AValue));
end;

procedure TXmlWriter.CData(const AValue: string);
begin
  RequireXmlValueChars('CData', 'value', AValue);
  FlushStartTag;
  AppendStr('<![CDATA[');
  AppendCDataValue(AValue);
  AppendStr(']]>');
end;

procedure TXmlWriter.Comment(const AValue: string);
begin
  RequireXmlValueChars('Comment', 'value', AValue);
  if Pos('--', AValue) > 0 then
    raise EArgumentError.Create(
      'TXmlWriter.Comment: comment text must not contain "--"');
  if (AValue <> '') and (AValue[Length(AValue)] = '-') then
    raise EArgumentError.Create(
      'TXmlWriter.Comment: comment text must not end with "-"');
  FlushStartTag;
  if FPretty and (FBufLen > 0) then
    AppendChar(#10);
  WriteIndent;
  AppendStr('<!--');
  AppendStr(AValue);
  AppendStr('-->');
  if FHasChildTop >= 0 then
    FHasChildren := True;
end;

procedure TXmlWriter.PI(const ATarget, AData: string);
begin
  RequireXmlPITarget(ATarget);
  RequireXmlValueChars('PI', 'data', AData);
  if (Length(ATarget) = 3) and
     (((ATarget[1] = 'x') or (ATarget[1] = 'X')) and
      ((ATarget[2] = 'm') or (ATarget[2] = 'M')) and
      ((ATarget[3] = 'l') or (ATarget[3] = 'L'))) then
    raise EArgumentError.Create(
      'TXmlWriter.PI: target "xml" is reserved for XML declarations');
  FlushStartTag;
  if FPretty and (FBufLen > 0) then
    AppendChar(#10);
  WriteIndent;
  AppendStr('<?');
  AppendStr(ATarget);
  if AData <> '' then
  begin
    AppendChar(' ');
    AppendPIData(ATarget, AData);
  end;
  AppendStr('?>');
  if FHasChildTop >= 0 then
    FHasChildren := True;
end;

procedure TXmlWriter.Raw(const AStr: string);
begin
  FlushStartTag;
  AppendStr(AStr);
end;

function TXmlWriter.ToString: string;
begin
  Result := Copy(FBuf, 1, FBufLen);
end;

procedure TXmlWriter.Clear;
begin
  FBufLen := 0;
  FDepth := 0;
  FInStartTag := False;
  ResetAttributeNames;
  FHasChildren := False;
  FHasChildTop := -1;
  FElementStackTop := -1;
end;

end.
