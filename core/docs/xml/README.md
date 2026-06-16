# nextpas.core.xml

XML tokenizer, reader, writer, and DOM for the nextPas core framework.

## Architecture

XML module is organized into four sub-units:

| Unit | Type | Description |
|------|------|-------------|
| `xml.base` | Types | TXmlTokenKind, TXmlName, TXmlPosition, EXmlError |
| `xml.reader` | TXmlReader | Tokenizing XML reader |
| `xml.writer` | TXmlWriter | XML serializer |
| `xml.dom` | TXmlDocument/TXmlNode | In-memory DOM tree |

## Failure and ownership contract

`XmlParse` and `XmlTokenize` raise `EXmlError` on parse or tokenization failures.

`TryXmlParse` returns `False` on failure and keeps `ADoc = nil`.

`EXmlError.Pos` exposes `ByteOffset`, `Line`, and `Column`.

Callers own `TXmlDocument`, `TXmlReader`, and `TXmlWriter` instances and must free them.

## Quick Start

```pascal
uses nextpas.core.xml;

// Parse with TXmlReader
var Reader: TXmlReader;
Reader := TXmlReader.Create;
try
  Reader.Parse('<root><item id="1">Hello</item></root>');
  while Reader.Read do
    WriteLn(Reader.Token.Kind, ' ', Reader.Token.Name.ToString);
finally
  Reader.Free;
end;

// Parse with DOM
var Doc: TXmlDocument;
Doc := TXmlDocument.Create;
try
  Doc.LoadFromString('<config><name>app</name></config>');
  WriteLn(Doc.Root.FindChild('name').Text);
finally
  Doc.Free;
end;

// Write XML
var Writer: TXmlWriter;
Writer := TXmlWriter.Create;
try
  Writer.StartDocument;
  Writer.StartElement('config');
  Writer.Attribute('version', '1.0');
  Writer.TextElement('name', 'my-app');
  Writer.EndElement;
  Writer.FinishDocument;
  WriteLn(Writer.ToString);
finally
  Writer.Free;
end;
```

## File Structure

```
src/nextpas.core.xml.base.pas   — TXmlTokenKind, TXmlName, TXmlPosition, EXmlError
src/nextpas.core.xml.reader.pas — TXmlReader (tokenizing reader)
src/nextpas.core.xml.writer.pas — TXmlWriter (serializer)
src/nextpas.core.xml.dom.pas    — TXmlDocument, TXmlNode (DOM tree)
src/nextpas.core.xml.pas        — Facade exporting all types and constants
```

## Feature Coverage

- XML 1.0 well-formedness checking
- Namespace support
- Attribute parsing
- CDATA sections
- Comments
- Processing instructions
- XML declarations
- DOCTYPE declarations
- DOM tree building
- Pretty-print serialization

## Dependencies

- `nextpas.core.text.view` — TStringView
- `nextpas.core.text.scan` — SIMD byte scanning
- `nextpas.core.errors` — Error handling