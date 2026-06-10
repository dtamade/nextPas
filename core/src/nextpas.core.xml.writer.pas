unit nextpas.core.xml.writer;
{**
 * @desc XML 输出器，支持 pretty print 和 compact 模式。
 *}

{$I nextpas.core.settings.inc}

interface

uses
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
    procedure FlushStartTag;
    procedure WriteIndent;
    procedure AppendStr(const AStr: string);
    procedure AppendChar(ACh: AnsiChar);
    procedure PushHasChild;
    procedure PopHasChild;
  public
    constructor Create(APretty: Boolean = False; const AIndent: string = '  ');
    destructor Destroy; override;
    procedure WriteXmlDecl(const AVersion: string = '1.0'; const AEncoding: string = 'UTF-8');
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

uses
  nextpas.core.errors;

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

procedure TXmlWriter.FlushStartTag;
begin
  if FInStartTag then
  begin
    AppendChar('>');
    FInStartTag := False;
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

procedure TXmlWriter.WriteXmlDecl(const AVersion: string; const AEncoding: string);
begin
  AppendStr('<?xml version="');
  AppendStr(AVersion);
  AppendStr('" encoding="');
  AppendStr(AEncoding);
  AppendStr('"?>');
  if FPretty then
    AppendChar(#10);
end;

procedure TXmlWriter.StartElement(const AName: string);
begin
  FlushStartTag;
  if FPretty and (FBufLen > 0) and (FBuf[FBufLen] <> #10) then
    AppendChar(#10);
  WriteIndent;
  AppendChar('<');
  AppendStr(AName);
  FInStartTag := True;
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
  AppendChar(' ');
  AppendStr(AName);
  AppendStr('="');
  AppendStr(XmlEncodeAttr(AValue));
  AppendChar('"');
end;

procedure TXmlWriter.NamespaceDecl(const APrefix, AURI: string);
begin
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
  FlushStartTag;
  AppendStr(XmlEncodeText(AValue));
end;

procedure TXmlWriter.CData(const AValue: string);
begin
  FlushStartTag;
  AppendStr('<![CDATA[');
  AppendStr(AValue);
  AppendStr(']]>');
end;

procedure TXmlWriter.Comment(const AValue: string);
begin
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
  FlushStartTag;
  if FPretty and (FBufLen > 0) then
    AppendChar(#10);
  WriteIndent;
  AppendStr('<?');
  AppendStr(ATarget);
  if AData <> '' then
  begin
    AppendChar(' ');
    AppendStr(AData);
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
  FHasChildren := False;
  FHasChildTop := -1;
  FElementStackTop := -1;
end;

end.
