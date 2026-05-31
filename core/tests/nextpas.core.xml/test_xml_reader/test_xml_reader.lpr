program test_xml_reader;
{**
 * @desc XML SAX Reader 测试套件：40+ 测试覆盖所有解析场景。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.xml.base,
  nextpas.core.xml.reader;

var
  T: TTestRunner;

{ === Helper === }

function ReadAll(const AXml: string): TXmlTokenArray;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
  LCount, LCap: Integer;
begin
  LReader := TXmlReader.Create(AXml);
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
    if LReader.HasError then
      Fail('Parse error: ' + LReader.GetError);
    SetLength(Result, LCount);
  finally
    LReader.Free;
  end;
end;

{ === Tests === }

procedure TestSimpleElement;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<a>text</a>');
  CheckEqual(Int64(3), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkStartElement, 'start');
  CheckEqual('a', LToks[0].Name.Local, 'start name');
  Check(LToks[1].Kind = xtkText, 'text');
  CheckEqual('text', LToks[1].Value, 'text value');
  Check(LToks[2].Kind = xtkEndElement, 'end');
  CheckEqual('a', LToks[2].Name.Local, 'end name');
end;

procedure TestNestedElements;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<a><b>inner</b></a>');
  CheckEqual(Int64(5), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkStartElement, 'a start');
  Check(LToks[1].Kind = xtkStartElement, 'b start');
  CheckEqual('b', LToks[1].Name.Local, 'b name');
  Check(LToks[2].Kind = xtkText, 'text');
  CheckEqual('inner', LToks[2].Value, 'text value');
  Check(LToks[3].Kind = xtkEndElement, 'b end');
  Check(LToks[4].Kind = xtkEndElement, 'a end');
end;

procedure TestSelfClosing;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<br/>');
  CheckEqual(Int64(1), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkEmptyElement, 'empty element');
  CheckEqual('br', LToks[0].Name.Local, 'name');
  Check(LToks[0].IsSelfClosing, 'self closing');
end;

procedure TestSelfClosingWithSpace;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<br />');
  CheckEqual(Int64(1), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkEmptyElement, 'empty element');
  CheckEqual('br', LToks[0].Name.Local, 'name');
end;

procedure TestAttributeDouble;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<a href="http://x.com">link</a>');
  CheckEqual(Int64(3), Int64(Length(LToks)), 'token count');
  CheckEqual(Int64(1), Int64(Length(LToks[0].Attributes)), 'attr count');
  CheckEqual('href', LToks[0].Attributes[0].Name.Local, 'attr name');
  CheckEqual('http://x.com', LToks[0].Attributes[0].Value, 'attr value');
end;

procedure TestAttributeSingle;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<a title=''hello''>x</a>');
  CheckEqual(Int64(1), Int64(Length(LToks[0].Attributes)), 'attr count');
  CheckEqual('hello', LToks[0].Attributes[0].Value, 'attr value');
end;

procedure TestMultipleAttributes;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<div id="main" class="big" data-x="1">x</div>');
  CheckEqual(Int64(3), Int64(Length(LToks[0].Attributes)), 'attr count');
  CheckEqual('id', LToks[0].Attributes[0].Name.Local, 'attr0');
  CheckEqual('main', LToks[0].Attributes[0].Value, 'val0');
  CheckEqual('class', LToks[0].Attributes[1].Name.Local, 'attr1');
  CheckEqual('big', LToks[0].Attributes[1].Value, 'val1');
  CheckEqual('data-x', LToks[0].Attributes[2].Name.Local, 'attr2');
  CheckEqual('1', LToks[0].Attributes[2].Value, 'val2');
end;

procedure TestAttributeEntityValue;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<a v="a&amp;b&lt;c">x</a>');
  CheckEqual('a&b<c', LToks[0].Attributes[0].Value, 'decoded attr');
end;

procedure TestNamespaceDecl;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
  LUri: string;
begin
  LReader := TXmlReader.Create('<root xmlns:ns="http://example.com"><ns:child/></root>');
  try
    Check(LReader.Next(LTok), 'root start');
    LUri := LReader.ResolveNamespace('ns');
    CheckEqual('http://example.com', LUri, 'ns uri');
    Check(LReader.Next(LTok), 'child');
    CheckEqual('ns', LTok.Name.Prefix, 'child prefix');
    CheckEqual('child', LTok.Name.Local, 'child local');
  finally
    LReader.Free;
  end;
end;

procedure TestDefaultNamespace;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
  LUri: string;
begin
  LReader := TXmlReader.Create('<root xmlns="http://default.ns"><child/></root>');
  try
    Check(LReader.Next(LTok), 'root start');
    LUri := LReader.ResolveNamespace('');
    CheckEqual('http://default.ns', LUri, 'default ns');
  finally
    LReader.Free;
  end;
end;

procedure TestTextEntityDecode;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<r>a&amp;b&lt;c&gt;d</r>');
  CheckEqual('a&b<c>d', LToks[1].Value, 'decoded text');
end;

procedure TestNumericEntity;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<r>&#65;&#x42;</r>');
  CheckEqual('AB', LToks[1].Value, 'numeric entities');
end;

procedure TestCData;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<r><![CDATA[<not>&markup]]></r>');
  CheckEqual(Int64(3), Int64(Length(LToks)), 'token count');
  Check(LToks[1].Kind = xtkCData, 'cdata kind');
  CheckEqual('<not>&markup', LToks[1].Value, 'cdata value');
end;

procedure TestComment;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<!-- hello --><r/>');
  CheckEqual(Int64(2), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkComment, 'comment kind');
  CheckEqual(' hello ', LToks[0].Value, 'comment value');
end;

procedure TestPI;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<?target data here?><r/>');
  CheckEqual(Int64(2), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkProcessingInstr, 'pi kind');
  CheckEqual('target', LToks[0].Name.Local, 'pi target');
  CheckEqual('data here', LToks[0].Value, 'pi data');
end;

procedure TestXmlDecl;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<?xml version="1.0" encoding="UTF-8"?><r/>');
  CheckEqual(Int64(2), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkXmlDecl, 'xml decl');
  CheckEqual(Int64(2), Int64(Length(LToks[0].Attributes)), 'decl attrs');
  CheckEqual('version', LToks[0].Attributes[0].Name.Local, 'version attr');
  CheckEqual('1.0', LToks[0].Attributes[0].Value, 'version val');
end;

procedure TestDoctype;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<!DOCTYPE html><r/>');
  CheckEqual(Int64(2), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkDoctype, 'doctype kind');
end;

procedure TestMismatchedTag;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
begin
  LReader := TXmlReader.Create('<a></b>');
  try
    LReader.Next(LTok); { <a> }
    LReader.Next(LTok); { </b> - should fail }
    Check(LReader.HasError, 'should have error');
    Check(Pos('Mismatched', LReader.GetError) > 0, 'error msg');
  finally
    LReader.Free;
  end;
end;

procedure TestUnexpectedEndTag;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
begin
  LReader := TXmlReader.Create('</a>');
  try
    LReader.Next(LTok);
    Check(LReader.HasError, 'should have error');
    Check(Pos('Unexpected end tag', LReader.GetError) > 0, 'error msg');
  finally
    LReader.Free;
  end;
end;

procedure TestPositionTracking;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
  LPos: TXmlPosition;
begin
  LReader := TXmlReader.Create('<a>' + #10 + '<b/>');
  try
    LReader.Next(LTok); { <a> }
    LReader.Next(LTok); { newline text }
    LReader.Next(LTok); { <b/> }
    LPos := LReader.Position;
    CheckEqual(Int64(2), Int64(LPos.Line), 'line');
  finally
    LReader.Free;
  end;
end;

procedure TestDepth;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
begin
  LReader := TXmlReader.Create('<a><b><c/></b></a>');
  try
    LReader.Next(LTok); { <a> }
    CheckEqual(Int64(1), Int64(LReader.Depth), 'depth after a');
    LReader.Next(LTok); { <b> }
    CheckEqual(Int64(2), Int64(LReader.Depth), 'depth after b');
    LReader.Next(LTok); { <c/> }
    CheckEqual(Int64(2), Int64(LReader.Depth), 'depth after c empty');
    LReader.Next(LTok); { </b> }
    CheckEqual(Int64(1), Int64(LReader.Depth), 'depth after /b');
    LReader.Next(LTok); { </a> }
    CheckEqual(Int64(0), Int64(LReader.Depth), 'depth after /a');
  finally
    LReader.Free;
  end;
end;

procedure TestMixedContent;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<p>Hello <b>world</b>!</p>');
  CheckEqual(Int64(7), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkStartElement, 'p start');
  Check(LToks[1].Kind = xtkText, 'text1');
  CheckEqual('Hello ', LToks[1].Value, 'text1 val');
  Check(LToks[2].Kind = xtkStartElement, 'b start');
  Check(LToks[3].Kind = xtkText, 'text2');
  CheckEqual('world', LToks[3].Value, 'text2 val');
  Check(LToks[4].Kind = xtkEndElement, 'b end');
  Check(LToks[5].Kind = xtkText, 'text3');
  CheckEqual('!', LToks[5].Value, 'text3 val');
  Check(LToks[6].Kind = xtkEndElement, 'p end');
end;

procedure TestLargeInput;
var
  LXml: string;
  LI: Integer;
  LReader: TXmlReader;
  LTok: TXmlToken;
  LCount: Integer;
begin
  LXml := '<root>';
  for LI := 1 to 500 do
    LXml := LXml + '<item id="' + IntToStr(LI) + '">value' + IntToStr(LI) + '</item>';
  LXml := LXml + '</root>';
  { Should be > 10KB }
  Check(Length(LXml) > 10000, 'input > 10KB');
  LReader := TXmlReader.Create(LXml);
  try
    LCount := 0;
    while LReader.Next(LTok) do
      Inc(LCount);
    Check(not LReader.HasError, 'no error on large input');
    { root start + 500*(item start + text + item end) + root end = 1502 }
    CheckEqual(Int64(1502), Int64(LCount), 'large token count');
  finally
    LReader.Free;
  end;
end;

procedure TestEmptyDocument;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
begin
  LReader := TXmlReader.Create('');
  try
    Check(not LReader.Next(LTok), 'empty doc returns false');
    Check(not LReader.HasError, 'no error');
  finally
    LReader.Free;
  end;
end;

procedure TestOnlyDecl;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<?xml version="1.0"?>');
  CheckEqual(Int64(1), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkXmlDecl, 'xml decl');
end;

procedure TestBOM;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll(#$EF#$BB#$BF'<r/>');
  CheckEqual(Int64(1), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkEmptyElement, 'element after BOM');
  CheckEqual('r', LToks[0].Name.Local, 'name');
end;

procedure TestXmlDecodeEntitiesUnit;
begin
  CheckEqual('&', XmlDecodeEntities('&amp;'), 'amp');
  CheckEqual('<', XmlDecodeEntities('&lt;'), 'lt');
  CheckEqual('>', XmlDecodeEntities('&gt;'), 'gt');
  CheckEqual('"', XmlDecodeEntities('&quot;'), 'quot');
  CheckEqual('''', XmlDecodeEntities('&apos;'), 'apos');
  CheckEqual('A', XmlDecodeEntities('&#65;'), 'dec');
  CheckEqual('B', XmlDecodeEntities('&#x42;'), 'hex');
  CheckEqual('no entities here', XmlDecodeEntities('no entities here'), 'passthrough');
  CheckEqual('a&b', XmlDecodeEntities('a&amp;b'), 'mixed');
end;

procedure TestXmlEncodeTextUnit;
begin
  CheckEqual('hello', XmlEncodeText('hello'), 'passthrough');
  CheckEqual('&lt;a&gt;', XmlEncodeText('<a>'), 'lt gt');
  CheckEqual('a&amp;b', XmlEncodeText('a&b'), 'amp');
end;

procedure TestXmlEncodeAttrUnit;
begin
  CheckEqual('hello', XmlEncodeAttr('hello'), 'passthrough');
  CheckEqual('&lt;&gt;&amp;&quot;&apos;', XmlEncodeAttr('<>&"'''), 'all special');
end;

procedure TestRoundTrip;
var LOriginal, LEncoded, LDecoded: string;
begin
  LOriginal := 'x < y & "z" > ''w''';
  LEncoded := XmlEncodeAttr(LOriginal);
  LDecoded := XmlDecodeEntities(LEncoded);
  CheckEqual(LOriginal, LDecoded, 'roundtrip');
end;

procedure TestNameFull;
var LName: TXmlName;
begin
  LName.Prefix := '';
  LName.Local := 'tag';
  CheckEqual('tag', LName.Full, 'no prefix');
  LName.Prefix := 'ns';
  LName.Local := 'elem';
  CheckEqual('ns:elem', LName.Full, 'with prefix');
end;

procedure TestWhitespaceText;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<r>  ' + #10 + '  </r>');
  CheckEqual(Int64(3), Int64(Length(LToks)), 'token count');
  Check(LToks[1].Kind = xtkText, 'whitespace text');
end;

procedure TestEmptyElement;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<r></r>');
  CheckEqual(Int64(2), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkStartElement, 'start');
  Check(LToks[1].Kind = xtkEndElement, 'end');
end;

procedure TestMultipleRoots;
var LToks: TXmlTokenArray;
begin
  { XML technically allows only one root, but parser should handle multiple }
  LToks := ReadAll('<a/><b/>');
  CheckEqual(Int64(2), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkEmptyElement, 'first');
  Check(LToks[1].Kind = xtkEmptyElement, 'second');
end;

procedure TestDeeplyNested;
var
  LXml: string;
  LI: Integer;
  LReader: TXmlReader;
  LTok: TXmlToken;
begin
  LXml := '';
  for LI := 1 to 50 do
    LXml := LXml + '<d>';
  LXml := LXml + 'deep';
  for LI := 1 to 50 do
    LXml := LXml + '</d>';
  LReader := TXmlReader.Create(LXml);
  try
    while LReader.Next(LTok) do ;
    Check(not LReader.HasError, 'no error on deep nesting');
  finally
    LReader.Free;
  end;
end;

procedure TestCommentInElement;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<r><!-- comment --></r>');
  CheckEqual(Int64(3), Int64(Length(LToks)), 'token count');
  Check(LToks[1].Kind = xtkComment, 'comment');
  CheckEqual(' comment ', LToks[1].Value, 'comment value');
end;

procedure TestCDataInElement;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<r><![CDATA[hello]]></r>');
  CheckEqual(Int64(3), Int64(Length(LToks)), 'token count');
  Check(LToks[1].Kind = xtkCData, 'cdata');
  CheckEqual('hello', LToks[1].Value, 'cdata value');
end;

procedure TestPrefixedElement;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<ns:root xmlns:ns="urn:x"><ns:child/></ns:root>');
  CheckEqual('ns', LToks[0].Name.Prefix, 'root prefix');
  CheckEqual('root', LToks[0].Name.Local, 'root local');
  CheckEqual('ns', LToks[1].Name.Prefix, 'child prefix');
  CheckEqual('child', LToks[1].Name.Local, 'child local');
end;

procedure TestDoctypeWithInternalSubset;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<!DOCTYPE root [<!ELEMENT root (#PCDATA)>]><root/>');
  CheckEqual(Int64(2), Int64(Length(LToks)), 'token count');
  Check(LToks[0].Kind = xtkDoctype, 'doctype');
  Check(LToks[1].Kind = xtkEmptyElement, 'root');
end;

procedure TestEntityApos;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<r>&apos;hi&apos;</r>');
  CheckEqual('''hi''', LToks[1].Value, 'apos decoded');
end;

procedure TestMultiLineElement;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<r' + #10 + '  id="x"' + #10 + '>text</r>');
  CheckEqual(Int64(3), Int64(Length(LToks)), 'token count');
  CheckEqual('x', LToks[0].Attributes[0].Value, 'attr');
  CheckEqual('text', LToks[1].Value, 'text');
end;

procedure TestEmptyAttrValue;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<r a="">x</r>');
  CheckEqual('', LToks[0].Attributes[0].Value, 'empty attr');
end;

{ === Main === }

begin
  T := TTestRunner.Create('XML Reader');
  T.Run('SimpleElement', @TestSimpleElement);
  T.Run('NestedElements', @TestNestedElements);
  T.Run('SelfClosing', @TestSelfClosing);
  T.Run('SelfClosingWithSpace', @TestSelfClosingWithSpace);
  T.Run('AttributeDouble', @TestAttributeDouble);
  T.Run('AttributeSingle', @TestAttributeSingle);
  T.Run('MultipleAttributes', @TestMultipleAttributes);
  T.Run('AttributeEntityValue', @TestAttributeEntityValue);
  T.Run('NamespaceDecl', @TestNamespaceDecl);
  T.Run('DefaultNamespace', @TestDefaultNamespace);
  T.Run('TextEntityDecode', @TestTextEntityDecode);
  T.Run('NumericEntity', @TestNumericEntity);
  T.Run('CData', @TestCData);
  T.Run('Comment', @TestComment);
  T.Run('PI', @TestPI);
  T.Run('XmlDecl', @TestXmlDecl);
  T.Run('Doctype', @TestDoctype);
  T.Run('MismatchedTag', @TestMismatchedTag);
  T.Run('UnexpectedEndTag', @TestUnexpectedEndTag);
  T.Run('PositionTracking', @TestPositionTracking);
  T.Run('Depth', @TestDepth);
  T.Run('MixedContent', @TestMixedContent);
  T.Run('LargeInput', @TestLargeInput);
  T.Run('EmptyDocument', @TestEmptyDocument);
  T.Run('OnlyDecl', @TestOnlyDecl);
  T.Run('BOM', @TestBOM);
  T.Run('XmlDecodeEntitiesUnit', @TestXmlDecodeEntitiesUnit);
  T.Run('XmlEncodeTextUnit', @TestXmlEncodeTextUnit);
  T.Run('XmlEncodeAttrUnit', @TestXmlEncodeAttrUnit);
  T.Run('RoundTrip', @TestRoundTrip);
  T.Run('NameFull', @TestNameFull);
  T.Run('WhitespaceText', @TestWhitespaceText);
  T.Run('EmptyElement', @TestEmptyElement);
  T.Run('MultipleRoots', @TestMultipleRoots);
  T.Run('DeeplyNested', @TestDeeplyNested);
  T.Run('CommentInElement', @TestCommentInElement);
  T.Run('CDataInElement', @TestCDataInElement);
  T.Run('PrefixedElement', @TestPrefixedElement);
  T.Run('DoctypeWithInternalSubset', @TestDoctypeWithInternalSubset);
  T.Run('EntityApos', @TestEntityApos);
  T.Run('MultiLineElement', @TestMultiLineElement);
  T.Run('EmptyAttrValue', @TestEmptyAttrValue);
  T.Summary;
end.
