unit nextpas.core.xml;
{**
 * @desc XML 模块 Facade：统一导出 reader/writer/dom 所有公共类型和函数。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.xml.base,
  nextpas.core.xml.reader,
  nextpas.core.xml.writer,
  nextpas.core.xml.dom;

type
  TXmlTokenKind = nextpas.core.xml.base.TXmlTokenKind;
  TXmlName = nextpas.core.xml.base.TXmlName;
  TXmlAttribute = nextpas.core.xml.base.TXmlAttribute;
  TXmlAttributeArray = nextpas.core.xml.base.TXmlAttributeArray;
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

function XmlParse(const AInput: string): TXmlDocument; inline;
function TryXmlParse(const AInput: string; out ADoc: TXmlDocument): Boolean;
function XmlTokenize(const AInput: string): TXmlTokenArray;
function XmlDecodeEntities(const AStr: string): string; inline;
function XmlEncodeText(const AStr: string): string; inline;
function XmlEncodeAttr(const AStr: string): string; inline;

implementation

function XmlParse(const AInput: string): TXmlDocument;
begin
  Result := TXmlDocument.Parse(AInput);
end;

function TryXmlParse(const AInput: string; out ADoc: TXmlDocument): Boolean;
begin
  ADoc := nil;
  try
    ADoc := XmlParse(AInput);
    Result := True;
  except
    on EXmlError do
    begin
      ADoc.Free;
      ADoc := nil;
      Result := False;
    end;
  end;
end;

function XmlTokenize(const AInput: string): TXmlTokenArray;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
  LCount, LCap: Integer;
begin
  Result := nil;
  LReader := TXmlReader.Create(AInput);
  try
    LCount := 0;
    LCap := 16;
    SetLength(Result, LCap);
    while LReader.Next(LTok) do
    begin
      if LCount >= LCap then
      begin
        LCap := LCap * 2;
        SetLength(Result, LCap);
      end;
      Result[LCount] := LTok;
      Inc(LCount);
    end;
    SetLength(Result, LCount);
    { 与 XmlParse 保持一致：非法 XML 必须抛错，不静默返回部分 token }
    if LReader.HasError then
      raise EXmlError.Create(LReader.GetError, LReader.Position);
  finally
    LReader.Free;
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
