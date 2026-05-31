program test_xml;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.xml;

var
  T: TTestRunner;

{ Test 1: Simple element with text }
procedure TestSimpleElement;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<tag>text</tag>');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(3), Int64(Length(LEvents)), 'event count');
  Check(LEvents[0].Kind = xekStartElement, 'start');
  CheckEqual('tag', LEvents[0].Name, 'start name');
  Check(LEvents[1].Kind = xekText, 'text');
  CheckEqual('text', LEvents[1].Value, 'text value');
  Check(LEvents[2].Kind = xekEndElement, 'end');
  CheckEqual('tag', LEvents[2].Name, 'end name');
end;

{ Test 2: Attributes }
procedure TestAttributes;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<tag attr="value" num="42"/>');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(2), Int64(Length(LEvents)), 'event count');
  Check(LEvents[0].Kind = xekStartElement, 'start');
  CheckEqual('tag', LEvents[0].Name, 'name');
  CheckEqual(Int64(2), Int64(Length(LEvents[0].Attributes)), 'attr count');
  CheckEqual('attr', LEvents[0].Attributes[0].Name, 'attr0 name');
  CheckEqual('value', LEvents[0].Attributes[0].Value, 'attr0 value');
  CheckEqual('num', LEvents[0].Attributes[1].Name, 'attr1 name');
  CheckEqual('42', LEvents[0].Attributes[1].Value, 'attr1 value');
  Check(LEvents[1].Kind = xekEndElement, 'end');
end;

{ Test 3: Self-closing tag }
procedure TestSelfClosing;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<br/>');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(2), Int64(Length(LEvents)), 'event count');
  Check(LEvents[0].Kind = xekStartElement, 'start');
  CheckEqual('br', LEvents[0].Name, 'name');
  Check(LEvents[1].Kind = xekEndElement, 'end');
  CheckEqual('br', LEvents[1].Name, 'end name');
end;

{ Test 4: Nested elements }
procedure TestNestedElements;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<root><child>hello</child></root>');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(5), Int64(Length(LEvents)), 'event count');
  Check(LEvents[0].Kind = xekStartElement, 'root start');
  CheckEqual('root', LEvents[0].Name, 'root name');
  Check(LEvents[1].Kind = xekStartElement, 'child start');
  CheckEqual('child', LEvents[1].Name, 'child name');
  Check(LEvents[2].Kind = xekText, 'text');
  CheckEqual('hello', LEvents[2].Value, 'text value');
  Check(LEvents[3].Kind = xekEndElement, 'child end');
  CheckEqual('child', LEvents[3].Name, 'child end name');
  Check(LEvents[4].Kind = xekEndElement, 'root end');
  CheckEqual('root', LEvents[4].Name, 'root end name');
end;

{ Test 5: CDATA }
procedure TestCData;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<data><![CDATA[<not>&xml;]]></data>');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(3), Int64(Length(LEvents)), 'event count');
  Check(LEvents[1].Kind = xekCData, 'cdata');
  CheckEqual('<not>&xml;', LEvents[1].Value, 'cdata value');
end;

{ Test 6: Comment }
procedure TestComment;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<!-- this is a comment --><root/>');
  LEvents := LReader.ReadAll;
  Check(LEvents[0].Kind = xekComment, 'comment');
  CheckEqual(' this is a comment ', LEvents[0].Value, 'comment value');
end;

{ Test 7: Processing instruction }
procedure TestProcessingInstruction;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<?xml version="1.0" encoding="UTF-8"?>');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(1), Int64(Length(LEvents)), 'event count');
  Check(LEvents[0].Kind = xekProcessingInstruction, 'PI');
  CheckEqual('xml', LEvents[0].Name, 'PI name');
  CheckEqual('version="1.0" encoding="UTF-8"', LEvents[0].Value, 'PI value');
end;

{ Test 8: Entity decode - named }
procedure TestEntityDecodeNamed;
begin
  CheckEqual('&', XmlDecodeEntities('&amp;'), 'amp');
  CheckEqual('<', XmlDecodeEntities('&lt;'), 'lt');
  CheckEqual('>', XmlDecodeEntities('&gt;'), 'gt');
  CheckEqual('"', XmlDecodeEntities('&quot;'), 'quot');
  CheckEqual('''', XmlDecodeEntities('&apos;'), 'apos');
end;

{ Test 9: Entity decode - numeric decimal }
procedure TestEntityDecodeNumeric;
begin
  CheckEqual('A', XmlDecodeEntities('&#65;'), 'dec 65');
  CheckEqual('Z', XmlDecodeEntities('&#90;'), 'dec 90');
  CheckEqual(' ', XmlDecodeEntities('&#32;'), 'dec 32');
end;

{ Test 10: Entity decode - numeric hex }
procedure TestEntityDecodeHex;
begin
  CheckEqual('A', XmlDecodeEntities('&#x41;'), 'hex 41');
  CheckEqual('Z', XmlDecodeEntities('&#x5A;'), 'hex 5A');
  CheckEqual('a', XmlDecodeEntities('&#x61;'), 'hex 61');
end;

{ Test 11: Entity encode }
procedure TestEntityEncode;
begin
  CheckEqual('&amp;&lt;&gt;&quot;&apos;', XmlEncodeEntities('&<>"'''), 'encode');
end;

{ Test 12: Roundtrip encode/decode }
procedure TestEntityRoundtrip;
var
  LOriginal, LEncoded, LDecoded: string;
begin
  LOriginal := 'Hello <world> & "friends" it''s nice';
  LEncoded := XmlEncodeEntities(LOriginal);
  LDecoded := XmlDecodeEntities(LEncoded);
  CheckEqual(LOriginal, LDecoded, 'roundtrip');
end;

{ Test 13: Empty element }
procedure TestEmptyElement;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<empty></empty>');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(2), Int64(Length(LEvents)), 'event count');
  Check(LEvents[0].Kind = xekStartElement, 'start');
  CheckEqual('empty', LEvents[0].Name, 'name');
  Check(LEvents[1].Kind = xekEndElement, 'end');
  CheckEqual('empty', LEvents[1].Name, 'end name');
end;

{ Test 14: Empty attribute value }
procedure TestEmptyAttributeValue;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<tag attr=""/>');
  LEvents := LReader.ReadAll;
  Check(LEvents[0].Kind = xekStartElement, 'start');
  CheckEqual(Int64(1), Int64(Length(LEvents[0].Attributes)), 'attr count');
  CheckEqual('attr', LEvents[0].Attributes[0].Name, 'attr name');
  CheckEqual('', LEvents[0].Attributes[0].Value, 'attr value empty');
end;

{ Test 15: Multiple attributes }
procedure TestMultipleAttributes;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<div id="main" class="container" style="color:red"/>');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(3), Int64(Length(LEvents[0].Attributes)), 'attr count');
  CheckEqual('id', LEvents[0].Attributes[0].Name, 'attr0');
  CheckEqual('main', LEvents[0].Attributes[0].Value, 'val0');
  CheckEqual('class', LEvents[0].Attributes[1].Name, 'attr1');
  CheckEqual('container', LEvents[0].Attributes[1].Value, 'val1');
  CheckEqual('style', LEvents[0].Attributes[2].Name, 'attr2');
  CheckEqual('color:red', LEvents[0].Attributes[2].Value, 'val2');
end;

{ Test 16: Whitespace in text }
procedure TestWhitespaceText;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<p>  hello  world  </p>');
  LEvents := LReader.ReadAll;
  Check(LEvents[1].Kind = xekText, 'text');
  CheckEqual('  hello  world  ', LEvents[1].Value, 'preserves whitespace');
end;

{ Test 17: Entities in text content }
procedure TestEntitiesInText;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<p>a &amp; b &lt; c</p>');
  LEvents := LReader.ReadAll;
  Check(LEvents[1].Kind = xekText, 'text');
  CheckEqual('a & b < c', LEvents[1].Value, 'decoded text');
end;

{ Test 18: Entities in attribute values }
procedure TestEntitiesInAttributes;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<a href="a&amp;b&lt;c"/>');
  LEvents := LReader.ReadAll;
  CheckEqual('a&b<c', LEvents[0].Attributes[0].Value, 'decoded attr');
end;

{ Test 19: DOCTYPE }
procedure TestDoctype;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<!DOCTYPE html><html/>');
  LEvents := LReader.ReadAll;
  Check(LEvents[0].Kind = xekDoctype, 'doctype');
  CheckEqual('html', LEvents[0].Value, 'doctype value');
end;

{ Test 20: Mixed content }
procedure TestMixedContent;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<p>Hello <b>world</b>!</p>');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(7), Int64(Length(LEvents)), 'event count');
  Check(LEvents[0].Kind = xekStartElement, 'p start');
  Check(LEvents[1].Kind = xekText, 'text1');
  CheckEqual('Hello ', LEvents[1].Value, 'text1 val');
  Check(LEvents[2].Kind = xekStartElement, 'b start');
  Check(LEvents[3].Kind = xekText, 'text2');
  CheckEqual('world', LEvents[3].Value, 'text2 val');
  Check(LEvents[4].Kind = xekEndElement, 'b end');
  Check(LEvents[5].Kind = xekText, 'text3');
  CheckEqual('!', LEvents[5].Value, 'text3 val');
  Check(LEvents[6].Kind = xekEndElement, 'p end');
end;

{ Test 21: Self-closing with space before slash }
procedure TestSelfClosingSpace;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<br />');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(2), Int64(Length(LEvents)), 'event count');
  Check(LEvents[0].Kind = xekStartElement, 'start');
  CheckEqual('br', LEvents[0].Name, 'name');
  Check(LEvents[1].Kind = xekEndElement, 'end');
end;

{ Test 22: Single-quoted attributes }
procedure TestSingleQuotedAttributes;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<tag attr=''value''/>');
  LEvents := LReader.ReadAll;
  CheckEqual('value', LEvents[0].Attributes[0].Value, 'single quoted');
end;

{ Test 23: Next() iteration }
procedure TestNextIteration;
var
  LReader: TXmlReader;
  LEvent: TXmlEvent;
  LCount: Integer;
begin
  LReader := TXmlReader.Create('<a><b/></a>');
  LCount := 0;
  while LReader.Next(LEvent) do
    Inc(LCount);
  CheckEqual(Int64(4), Int64(LCount), 'next count');
end;

{ Test 24: Empty input }
procedure TestEmptyInput;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(0), Int64(Length(LEvents)), 'empty');
end;

{ Test 25: Unclosed tag (best-effort) }
procedure TestUnclosedTag;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<root><child>text');
  LEvents := LReader.ReadAll;
  Check(Length(LEvents) >= 3, 'at least 3 events');
  Check(LEvents[0].Kind = xekStartElement, 'root start');
  Check(LEvents[1].Kind = xekStartElement, 'child start');
  Check(LEvents[2].Kind = xekText, 'text');
  CheckEqual('text', LEvents[2].Value, 'text value');
end;

{ Test 26: Large XML (10KB+) }
procedure TestLargeXml;
var
  LXml: string;
  LI: Integer;
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LXml := '<root>';
  for LI := 1 to 500 do
    LXml := LXml + '<item id="' + IntToStr(LI) + '">value' + IntToStr(LI) + '</item>';
  LXml := LXml + '</root>';
  Check(Length(LXml) > 10000, 'xml > 10KB');
  LReader := TXmlReader.Create(LXml);
  LEvents := LReader.ReadAll;
  // root start + 500*(item start + text + item end) + root end = 1502
  CheckEqual(Int64(1502), Int64(Length(LEvents)), 'large event count');
  Check(LEvents[0].Kind = xekStartElement, 'root start');
  CheckEqual('root', LEvents[0].Name, 'root name');
  Check(LEvents[Length(LEvents)-1].Kind = xekEndElement, 'root end');
end;

{ Test 27: Comment with dashes inside }
procedure TestCommentDashes;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<!-- a - b --><x/>');
  LEvents := LReader.ReadAll;
  Check(LEvents[0].Kind = xekComment, 'comment');
  CheckEqual(' a - b ', LEvents[0].Value, 'comment value');
end;

{ Test 28: Multiple PIs }
procedure TestMultiplePIs;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<?xml version="1.0"?><?style type="text/xsl"?><root/>');
  LEvents := LReader.ReadAll;
  CheckEqual(Int64(4), Int64(Length(LEvents)), 'event count');
  Check(LEvents[0].Kind = xekProcessingInstruction, 'PI1');
  CheckEqual('xml', LEvents[0].Name, 'PI1 name');
  Check(LEvents[1].Kind = xekProcessingInstruction, 'PI2');
  CheckEqual('style', LEvents[1].Name, 'PI2 name');
end;

{ Test 29: Deeply nested }
procedure TestDeeplyNested;
var
  LXml: string;
  LI: Integer;
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LXml := '';
  for LI := 1 to 50 do
    LXml := LXml + '<n' + IntToStr(LI) + '>';
  LXml := LXml + 'deep';
  for LI := 50 downto 1 do
    LXml := LXml + '</n' + IntToStr(LI) + '>';
  LReader := TXmlReader.Create(LXml);
  LEvents := LReader.ReadAll;
  // 50 start + 1 text + 50 end = 101
  CheckEqual(Int64(101), Int64(Length(LEvents)), 'deep event count');
  Check(LEvents[50].Kind = xekText, 'deep text');
  CheckEqual('deep', LEvents[50].Value, 'deep text value');
end;

{ Test 30: CDATA with special chars }
procedure TestCDataSpecialChars;
var
  LReader: TXmlReader;
  LEvents: TXmlEventArray;
begin
  LReader := TXmlReader.Create('<code><![CDATA[if (a < b && c > d) { x = "y"; }]]></code>');
  LEvents := LReader.ReadAll;
  Check(LEvents[1].Kind = xekCData, 'cdata');
  CheckEqual('if (a < b && c > d) { x = "y"; }', LEvents[1].Value, 'cdata value');
end;

begin
  T := TTestRunner.Create('nextpas.core.xml');
  T.Run('SimpleElement', @TestSimpleElement);
  T.Run('Attributes', @TestAttributes);
  T.Run('SelfClosing', @TestSelfClosing);
  T.Run('NestedElements', @TestNestedElements);
  T.Run('CData', @TestCData);
  T.Run('Comment', @TestComment);
  T.Run('ProcessingInstruction', @TestProcessingInstruction);
  T.Run('EntityDecodeNamed', @TestEntityDecodeNamed);
  T.Run('EntityDecodeNumeric', @TestEntityDecodeNumeric);
  T.Run('EntityDecodeHex', @TestEntityDecodeHex);
  T.Run('EntityEncode', @TestEntityEncode);
  T.Run('EntityRoundtrip', @TestEntityRoundtrip);
  T.Run('EmptyElement', @TestEmptyElement);
  T.Run('EmptyAttributeValue', @TestEmptyAttributeValue);
  T.Run('MultipleAttributes', @TestMultipleAttributes);
  T.Run('WhitespaceText', @TestWhitespaceText);
  T.Run('EntitiesInText', @TestEntitiesInText);
  T.Run('EntitiesInAttributes', @TestEntitiesInAttributes);
  T.Run('Doctype', @TestDoctype);
  T.Run('MixedContent', @TestMixedContent);
  T.Run('SelfClosingSpace', @TestSelfClosingSpace);
  T.Run('SingleQuotedAttributes', @TestSingleQuotedAttributes);
  T.Run('NextIteration', @TestNextIteration);
  T.Run('EmptyInput', @TestEmptyInput);
  T.Run('UnclosedTag', @TestUnclosedTag);
  T.Run('LargeXml', @TestLargeXml);
  T.Run('CommentDashes', @TestCommentDashes);
  T.Run('MultiplePIs', @TestMultiplePIs);
  T.Run('DeeplyNested', @TestDeeplyNested);
  T.Run('CDataSpecialChars', @TestCDataSpecialChars);
  T.Summary;
end.
