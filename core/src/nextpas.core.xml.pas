unit nextpas.core.xml;
{**
 * @desc XML 模块 Facade：统一导出 reader/writer/dom 所有公共类型和函数。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.xml.base,
  nextpas.core.xml.reader,
  nextpas.core.xml.writer,
  nextpas.core.xml.dom;

type
  TXmlTokenKind = nextpas.core.xml.base.TXmlTokenKind;
  TXmlName = nextpas.core.xml.base.TXmlName;
  TXmlAttribute = nextpas.core.xml.base.TXmlAttribute;
  TXmlAttributeArray = nextpas.core.xml.base.TXmlAttributeArray;
  TXmlNamespace = nextpas.core.xml.base.TXmlNamespace;
  TXmlNamespaceArray = nextpas.core.xml.base.TXmlNamespaceArray;
  TXmlToken = nextpas.core.xml.base.TXmlToken;
  TXmlTokenArray = nextpas.core.xml.base.TXmlTokenArray;
  TXmlPosition = nextpas.core.xml.base.TXmlPosition;
  EXmlError = nextpas.core.xml.base.EXmlError;
  TXmlReader = nextpas.core.xml.reader.TXmlReader;
  TXmlWriter = nextpas.core.xml.writer.TXmlWriter;
  TXmlNode = nextpas.core.xml.dom.TXmlNode;
  TXmlNodeKind = nextpas.core.xml.dom.TXmlNodeKind;
  TXmlNodeArray = nextpas.core.xml.dom.TXmlNodeArray;
  TXmlDocument = nextpas.core.xml.dom.TXmlDocument;

const
  { Re-export TXmlTokenKind 枚举值，使 facade 完全自包含（无需 uses base 即可比较 token 类型） }
  xtkNone            = nextpas.core.xml.base.xtkNone;
  xtkStartElement    = nextpas.core.xml.base.xtkStartElement;
  xtkEndElement      = nextpas.core.xml.base.xtkEndElement;
  xtkEmptyElement    = nextpas.core.xml.base.xtkEmptyElement;
  xtkText            = nextpas.core.xml.base.xtkText;
  xtkCData           = nextpas.core.xml.base.xtkCData;
  xtkComment         = nextpas.core.xml.base.xtkComment;
  xtkProcessingInstr = nextpas.core.xml.base.xtkProcessingInstr;
  xtkXmlDecl         = nextpas.core.xml.base.xtkXmlDecl;
  xtkDoctype         = nextpas.core.xml.base.xtkDoctype;

  xnkElement  = nextpas.core.xml.dom.xnkElement;
  xnkText     = nextpas.core.xml.dom.xnkText;
  xnkCData    = nextpas.core.xml.dom.xnkCData;
  xnkComment  = nextpas.core.xml.dom.xnkComment;
  xnkPI       = nextpas.core.xml.dom.xnkPI;
  xnkDocument = nextpas.core.xml.dom.xnkDocument;

function XmlParse(const AInput: string): TXmlDocument; inline;
function XmlParseWith(const AInput: string; const AAllocator: IAllocator): TXmlDocument;
function TryXmlParse(const AInput: string; out ADoc: TXmlDocument): Boolean;
function TryXmlParseWith(const AInput: string; const AAllocator: IAllocator;
  out ADoc: TXmlDocument): Boolean;
function XmlTokenize(const AInput: string): TXmlTokenArray;
function XmlTokenizeWith(const AInput: string; const AAllocator: IAllocator): TXmlTokenArray;
function XmlDecodeEntities(const AStr: string): string; inline;
function XmlEncodeText(const AStr: string): string; inline;
function XmlEncodeAttr(const AStr: string): string; inline;

implementation

uses
  nextpas.core.errors,
  nextpas.core.mem.default;

type
  PXmlTokenSlot = ^TXmlToken;

function GrowTokenSlots(const AAllocator: IAllocator; var ASlots: PXmlTokenSlot;
  var ACap: Integer; ANeeded: Integer): Boolean;
var
  LNewCap: Integer;
  LNewPtr: Pointer;
  LOldCap: Integer;
begin
  if ANeeded <= ACap then
    Exit(True);
  LOldCap := ACap;
  if ACap = 0 then
    LNewCap := 16
  else
    LNewCap := ACap;
  while LNewCap < ANeeded do
    LNewCap := LNewCap * 2;
  LNewPtr := AAllocator.Reallocate(Pointer(ASlots),
    SizeUInt(LNewCap) * SizeOf(TXmlToken));
  if LNewPtr = nil then
    Exit(False);
  ASlots := PXmlTokenSlot(LNewPtr);
  if LNewCap > LOldCap then
    FillChar(ASlots[LOldCap], (LNewCap - LOldCap) * SizeOf(TXmlToken), 0);
  ACap := LNewCap;
  Result := True;
end;

procedure ReleaseTokenSlots(const AAllocator: IAllocator; var ASlots: PXmlTokenSlot;
  ACount: Integer);
var
  LI: Integer;
begin
  if ASlots = nil then
    Exit;
  for LI := 0 to ACount - 1 do
    Finalize(ASlots[LI]);
  AAllocator.Deallocate(Pointer(ASlots));
  ASlots := nil;
end;

function XmlParse(const AInput: string): TXmlDocument;
begin
  Result := XmlParseWith(AInput, DefaultAllocator);
end;

function XmlParseWith(const AInput: string; const AAllocator: IAllocator): TXmlDocument;
begin
  Result := TXmlDocument.ParseWith(AInput, AAllocator);
end;

function TryXmlParse(const AInput: string; out ADoc: TXmlDocument): Boolean;
begin
  Result := TryXmlParseWith(AInput, DefaultAllocator, ADoc);
end;

function TryXmlParseWith(const AInput: string; const AAllocator: IAllocator;
  out ADoc: TXmlDocument): Boolean;
begin
  ADoc := TXmlDocument.None;
  try
    ADoc := TXmlDocument.ParseWith(AInput, AAllocator);
    Result := True;
  except
    on EXmlError do
    begin
      if ADoc.IsAssigned then
        ADoc.Done;
      ADoc := TXmlDocument.None;
      Result := False;
    end;
  end;
end;

function XmlTokenize(const AInput: string): TXmlTokenArray;
begin
  Result := XmlTokenizeWith(AInput, DefaultAllocator);
end;

function XmlTokenizeWith(const AInput: string; const AAllocator: IAllocator): TXmlTokenArray;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
  LCount, LCap, LI: Integer;
  LAllocator: IAllocator;
  LToks: PXmlTokenSlot;
begin
  Result := nil;
  if AAllocator = nil then
    LAllocator := DefaultAllocator
  else
    LAllocator := AAllocator;
  LToks := nil;
  LReader := TXmlReader.Create(AInput);
  try
    LCount := 0;
    LCap := 0;
    while LReader.Next(LTok) do
    begin
      if not GrowTokenSlots(LAllocator, LToks, LCap, LCount + 1) then
        raise EResourceExhaustedError.Create('XmlTokenize: out of memory');
      LToks[LCount] := LTok;
      Inc(LCount);
    end;
    { 与 XmlParse 保持一致：非法 XML 必须抛错，不静默返回部分 token }
    if LReader.HasError then
      raise EXmlError.Create(LReader.GetError, LReader.Position);
    SetLength(Result, LCount);
    for LI := 0 to LCount - 1 do
      Result[LI] := LToks[LI];
  finally
    LReader.Free;
    ReleaseTokenSlots(LAllocator, LToks, LCount);
  end;
end;

function XmlDecodeEntities(const AStr: string): string;
begin
  Result := nextpas.core.xml.base.XmlDecodeEntities(AStr);
end;

function XmlEncodeText(const AStr: string): string;
begin
  Result := nextpas.core.xml.base.XmlEncodeText(AStr);
end;

function XmlEncodeAttr(const AStr: string): string;
begin
  Result := nextpas.core.xml.base.XmlEncodeAttr(AStr);
end;

end.
