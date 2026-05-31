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

function XmlParse(const AInput: string): TXmlDocument; inline;
function XmlTokenize(const AInput: string): TXmlTokenArray;
function XmlDecodeEntities(const AStr: string): string; inline;
function XmlEncodeText(const AStr: string): string; inline;
function XmlEncodeAttr(const AStr: string): string; inline;

implementation

function XmlParse(const AInput: string): TXmlDocument;
begin
  Result := TXmlDocument.Parse(AInput);
end;

function XmlTokenize(const AInput: string): TXmlTokenArray;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
  LCount, LCap: Integer;
begin
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
