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
  Result := nil;
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

procedure TestTokenPositions;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<root><child/></root>');
  CheckEqual(Int64(3), Int64(Length(LToks)), 'token count');
  CheckEqual(Int64(0), Int64(LToks[0].Position.ByteOffset), 'root start offset');
  CheckEqual(Int64(1), Int64(LToks[0].Position.Line), 'root start line');
  CheckEqual(Int64(1), Int64(LToks[0].Position.Column), 'root start column');
  CheckEqual(Int64(6), Int64(LToks[1].Position.ByteOffset), 'child offset');
  CheckEqual(Int64(1), Int64(LToks[1].Position.Line), 'child line');
  CheckEqual(Int64(7), Int64(LToks[1].Position.Column), 'child column');
  CheckEqual(Int64(14), Int64(LToks[2].Position.ByteOffset), 'root end offset');
  CheckEqual(Int64(1), Int64(LToks[2].Position.Line), 'root end line');
  CheckEqual(Int64(15), Int64(LToks[2].Position.Column), 'root end column');
end;

procedure TestTokenPositionsCROnlyLineEnding;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<root>' + #13 + '<child/></root>');
  CheckEqual(Int64(4), Int64(Length(LToks)), 'token count');
  Check(LToks[1].Kind = xtkText, 'CR whitespace text token');
  Check(LToks[2].Kind = xtkEmptyElement, 'CR child token');
  CheckEqual(Int64(7), Int64(LToks[2].Position.ByteOffset),
    'child offset after CR');
  CheckEqual(Int64(2), Int64(LToks[2].Position.Line),
    'child line after CR');
  CheckEqual(Int64(1), Int64(LToks[2].Position.Column),
    'child column after CR');
end;

procedure TestTokenPositionsCRLFLineEndingCountsOnce;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<root>' + #13#10 + '<child/></root>');
  CheckEqual(Int64(4), Int64(Length(LToks)), 'token count');
  Check(LToks[1].Kind = xtkText, 'CRLF whitespace text token');
  Check(LToks[2].Kind = xtkEmptyElement, 'CRLF child token');
  CheckEqual(Int64(8), Int64(LToks[2].Position.ByteOffset),
    'child offset after CRLF');
  CheckEqual(Int64(2), Int64(LToks[2].Position.Line),
    'child line after CRLF');
  CheckEqual(Int64(1), Int64(LToks[2].Position.Column),
    'child column after CRLF');
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

procedure TestDuplicateAttributesAreRejected;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
begin
  LReader := TXmlReader.Create('<r a="1" a="2"/>');
  try
    Check(not LReader.Next(LTok), 'duplicate attribute rejects before token');
    Check(LReader.HasError, 'duplicate attribute sets reader error');
    Check(Pos('attribute "a" must not appear more than once',
      LReader.GetError) > 0, 'duplicate attribute error text');
    CheckEqual(Int64(0), Int64(LReader.Depth),
      'duplicate attribute leaves depth unchanged');
  finally
    LReader.Free;
  end;
end;

procedure TestAttributeEntityValue;
var LToks: TXmlTokenArray;
begin
  LToks := ReadAll('<a v="a&amp;b&lt;c">x</a>');
  CheckEqual('a&b<c', LToks[0].Attributes[0].Value, 'decoded attr');
end;

procedure TestAttributeRawLessThanIsRejected;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
  LToks: TXmlTokenArray;
begin
  LReader := TXmlReader.Create('<a v="raw<bad">x</a>');
  try
    Check(not LReader.Next(LTok),
      'raw less-than in attribute rejects before yielding token');
    Check(LReader.HasError,
      'raw less-than in attribute sets reader error');
    Check(Pos('attribute value must not contain raw <', LReader.GetError) > 0,
      'raw less-than in attribute reports expected error text');
    CheckEqual(Int64(0), Int64(LReader.Depth),
      'raw less-than in attribute leaves depth unchanged');
  finally
    LReader.Free;
  end;

  LToks := ReadAll('<a v="safe&lt;value">x</a>');
  CheckEqual('safe<value', LToks[0].Attributes[0].Value,
    'escaped less-than remains valid in attribute');
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

procedure TestNamespaceDeclAllowsXmlPrefixBinding;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
begin
  LReader := TXmlReader.Create(
    '<root xmlns:xml="http://www.w3.org/XML/1998/namespace"><child/></root>');
  try
    Check(LReader.Next(LTok), 'root token');
    Check(LTok.Kind = xtkStartElement, 'start element token');
    CheckEqual('http://www.w3.org/XML/1998/namespace',
      LTok.Attributes[0].Value, 'xml namespace attr value');
    CheckEqual('http://www.w3.org/XML/1998/namespace',
      LReader.ResolveNamespace('xml'), 'xml prefix remains resolvable');
    Check(not LReader.HasError, 'xml reserved binding stays valid');
  finally
    LReader.Free;
  end;
end;

procedure TestNamespaceDeclRejectsInvalidReservedBindings;
var
  LReader: TXmlReader;
  LTok: TXmlToken;

  procedure ExpectInvalidNamespaceDecl(
    const AXml, AExpectedFragment, ALabel: string);
  begin
    LReader.Free;
    LReader := TXmlReader.Create(AXml);
    Check(not LReader.Next(LTok), ALabel + ' fails before yielding a token');
    Check(LReader.HasError, ALabel + ' sets reader error');
    Check(Pos(AExpectedFragment, LReader.GetError) > 0,
      ALabel + ' reports the expected error text');
    CheckEqual('', LReader.ResolveNamespace('ns'),
      ALabel + ' leaves custom prefixes unresolved');
    CheckEqual(Int64(0), Int64(LReader.Depth),
      ALabel + ' does not push tag depth');
  end;

begin
  LReader := nil;
  try
    ExpectInvalidNamespaceDecl('<root xmlns:xmlns="urn:x"/>',
      'prefix "xmlns" is reserved',
      'reserved xmlns prefix declaration');
    ExpectInvalidNamespaceDecl(
      '<root xmlns:xml="urn:x"/>',
      'prefix "xml" must bind to the XML namespace URI',
      'xml prefix bound to a non-standard namespace');
    ExpectInvalidNamespaceDecl(
      '<root xmlns:ns=""/>',
      'prefixed namespace declarations must not use an empty URI',
      'prefixed namespace undeclaration');
    ExpectInvalidNamespaceDecl(
      '<root xmlns:ns="http://www.w3.org/XML/1998/namespace"/>',
      'the XML namespace URI must bind only to prefix "xml"',
      'non-xml prefix bound to the xml namespace');
    ExpectInvalidNamespaceDecl(
      '<root xmlns="http://www.w3.org/XML/1998/namespace"/>',
      'the XML namespace URI must bind only to prefix "xml"',
      'xml namespace declared as the default namespace');
    ExpectInvalidNamespaceDecl(
      '<root xmlns:ns="http://www.w3.org/2000/xmlns/"/>',
      'the XMLNS namespace URI must not be declared',
      'non-xmlns prefix bound to the xmlns namespace');
    ExpectInvalidNamespaceDecl(
      '<root xmlns="http://www.w3.org/2000/xmlns/"/>',
      'the XMLNS namespace URI must not be declared',
      'xmlns namespace declared as the default namespace');
  finally
    LReader.Free;
  end;
end;

procedure TestUnboundNamespacePrefixesAreRejected;
var
  LReader: TXmlReader;
  LTok: TXmlToken;

  procedure ExpectUnboundPrefix(
    const AXml, APrefix, ALabel: string);
  begin
    LReader.Free;
    LReader := TXmlReader.Create(AXml);
    Check(not LReader.Next(LTok), ALabel + ' fails before yielding a token');
    Check(LReader.HasError, ALabel + ' sets reader error');
    Check(Pos('namespace prefix "' + APrefix + '" is not bound',
      LReader.GetError) > 0, ALabel + ' reports the expected error text');
    CheckEqual('', LReader.ResolveNamespace(APrefix),
      ALabel + ' leaves the failed prefix unresolved');
    CheckEqual('', LReader.ResolveNamespace('ok'),
      ALabel + ' rolls back same-tag namespace bindings');
    CheckEqual(Int64(0), Int64(LReader.Depth),
      ALabel + ' does not push tag depth');
  end;

begin
  LReader := nil;
  try
    ExpectUnboundPrefix(
      '<ns:root/>',
      'ns',
      'unbound empty-element prefix');
    ExpectUnboundPrefix(
      '<root xmlns:ok="urn:ok" bad:attr="x"/>',
      'bad',
      'unbound attribute prefix');

    LReader.Free;
    LReader := TXmlReader.Create('<root><ns:child/></root>');
    Check(LReader.Next(LTok), 'root start token before unbound child');
    Check(not LReader.Next(LTok), 'unbound child element prefix rejects');
    Check(LReader.HasError, 'unbound child element prefix sets reader error');
    Check(Pos('namespace prefix "ns" is not bound', LReader.GetError) > 0,
      'unbound child element prefix reports expected error');
    CheckEqual(Int64(1), Int64(LReader.Depth),
      'unbound child element prefix keeps parent depth');

    LReader.Free;
    LReader := TXmlReader.Create('<root xml:lang="en"/>');
    Check(LReader.Next(LTok), 'built-in xml prefix remains accepted');
    Check(not LReader.HasError, 'built-in xml prefix does not require declaration');
    CheckEqual('xml', LTok.Attributes[0].Name.Prefix, 'xml attribute prefix');
    CheckEqual('lang', LTok.Attributes[0].Name.Local, 'xml attribute local');
    CheckEqual('http://www.w3.org/XML/1998/namespace',
      LReader.ResolveNamespace('xml'), 'built-in xml prefix resolves');

    LReader.Free;
    LReader := TXmlReader.Create('<root></ns:root>');
    Check(LReader.Next(LTok), 'root start token');
    Check(not LReader.Next(LTok), 'unbound end-tag prefix rejects');
    Check(LReader.HasError, 'unbound end-tag prefix sets reader error');
    Check(Pos('namespace prefix "ns" is not bound', LReader.GetError) > 0,
      'unbound end-tag prefix reports expected error');
    CheckEqual(Int64(1), Int64(LReader.Depth),
      'unbound end-tag prefix does not pop existing depth');
  finally
    LReader.Free;
  end;
end;

procedure TestNamespaceAttributeDeclarationsAreVisibleBeforeUse;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
begin
  LReader := TXmlReader.Create('<root p:attr="x" xmlns:p="urn:p"></root>');
  try
    Check(LReader.Next(LTok),
      'same-tag namespace declaration validates earlier attribute prefix');
    Check(not LReader.HasError, 'attribute prefix declaration does not error');
    CheckEqual('p', LTok.Attributes[0].Name.Prefix, 'attribute prefix');
    CheckEqual('attr', LTok.Attributes[0].Name.Local, 'attribute local');
    CheckEqual('urn:p', LReader.ResolveNamespace('p'),
      'same-tag namespace declaration remains in scope');
  finally
    LReader.Free;
  end;
end;

procedure TestDuplicateExpandedAttributeNamesAreRejected;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
begin
  LReader := TXmlReader.Create(
    '<root xmlns:p="urn:x" xmlns:q="urn:x" p:a="1" q:a="2"/>');
  try
    Check(not LReader.Next(LTok),
      'duplicate expanded attribute names reject before token');
    Check(LReader.HasError, 'duplicate expanded attribute names set error');
    Check(Pos('must not appear more than once', LReader.GetError) > 0,
      'duplicate expanded attribute error text');
    CheckEqual('', LReader.ResolveNamespace('p'),
      'duplicate expanded attribute rolls back namespace p');
    CheckEqual('', LReader.ResolveNamespace('q'),
      'duplicate expanded attribute rolls back namespace q');
    CheckEqual(Int64(0), Int64(LReader.Depth),
      'duplicate expanded attribute leaves depth unchanged');
  finally
    LReader.Free;
  end;
end;

procedure TestExpandedAttributeNamesAllowDistinctNamespaces;
var
  LReader: TXmlReader;
  LTok: TXmlToken;
begin
  LReader := TXmlReader.Create(
    '<root p:a="1" q:a="2" xmlns:p="urn:p" xmlns:q="urn:q"/>');
  try
    Check(LReader.Next(LTok),
      'same local attributes with distinct namespace URIs are allowed');
    Check(not LReader.HasError,
      'same local attributes with distinct namespaces do not set error');
    CheckEqual(Int64(4), Int64(Length(LTok.Attributes)),
      'distinct namespace attribute count includes namespace declarations');
    CheckEqual('p', LTok.Attributes[0].Name.Prefix,
      'first distinct namespace attribute prefix');
    CheckEqual('q', LTok.Attributes[1].Name.Prefix,
      'second distinct namespace attribute prefix');
  finally
    LReader.Free;
  end;

  LReader := TXmlReader.Create(
    '<root a="1" p:a="2" xmlns="urn:x" xmlns:p="urn:x"/>');
  try
    Check(LReader.Next(LTok),
      'default namespace does not apply to unprefixed attributes');
    Check(not LReader.HasError,
      'default namespace plus prefixed same local does not set error');
    CheckEqual(Int64(4), Int64(Length(LTok.Attributes)),
      'default namespace attribute count includes namespace declarations');
    CheckEqual('', LTok.Attributes[0].Name.Prefix,
      'unprefixed attribute keeps empty prefix');
    CheckEqual('p', LTok.Attributes[1].Name.Prefix,
      'prefixed attribute keeps explicit prefix');
  finally
    LReader.Free;
  end;
end;

procedure TestInvalidQNamesAreRejected;
var
  LReader: TXmlReader;
  LTok: TXmlToken;

  procedure ExpectInvalidQName(
    const AXml, AExpectedFragment, ALabel: string);
  begin
    LReader.Free;
    LReader := TXmlReader.Create(AXml);
    Check(not LReader.Next(LTok), ALabel + ' fails before yielding a token');
    Check(LReader.HasError, ALabel + ' sets reader error');
    Check(Pos(AExpectedFragment, LReader.GetError) > 0,
      ALabel + ' reports the expected error text');
    CheckEqual('', LReader.ResolveNamespace('ns'),
      ALabel + ' leaves namespace bindings untouched');
    CheckEqual(Int64(0), Int64(LReader.Depth),
      ALabel + ' does not push tag depth');
  end;

begin
  LReader := nil;
  try
    ExpectInvalidQName(
      '<ns:bad:name/>',
      'element name must be a valid XML QName',
      'element QName with multiple colons');
    ExpectInvalidQName(
      '<root xmlns:ns="urn:x" ns:bad:name="x"/>',
      'attribute name must be a valid XML QName',
      'attribute QName with multiple colons');
    ExpectInvalidQName(
      '<root :attr="x"/>',
      'attribute name must be a valid XML QName',
      'attribute QName with an empty prefix part');
  finally
    LReader.Free;
  end;
end;

procedure TestInvalidPITargetsAreRejected;
var
  LReader: TXmlReader;
  LTok: TXmlToken;

  procedure ExpectInvalidPITarget(
    const AXml, AExpectedFragment, ALabel: string);
  begin
    LReader.Free;
    LReader := TXmlReader.Create(AXml);
    Check(not LReader.Next(LTok), ALabel + ' fails before yielding a token');
    Check(LReader.HasError, ALabel + ' sets reader error');
    Check(Pos(AExpectedFragment, LReader.GetError) > 0,
      ALabel + ' reports the expected error text');
    CheckEqual(Int64(0), Int64(LReader.Depth),
      ALabel + ' keeps reader depth unchanged');
  end;

begin
  LReader := nil;
  try
    ExpectInvalidPITarget(
      '<?bad:target:name payload?>',
      'processing-instruction target must be a valid XML QName',
      'processing-instruction target with multiple colons');
    ExpectInvalidPITarget(
      '<?XML version="1.0"?>',
      'processing-instruction target "xml" is reserved for XML declarations',
      'reserved XML processing-instruction target');
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

procedure TestCommentRejectsInvalidPayload;
var
  LReader: TXmlReader;
  LTok: TXmlToken;

  procedure ExpectInvalidComment(const AXml, AExpectedFragment,
    ALabel: string);
  begin
    LReader.Free;
    LReader := TXmlReader.Create(AXml);
    Check(not LReader.Next(LTok), ALabel + ' rejects comment');
    Check(LReader.HasError, ALabel + ' sets reader error');
    Check(Pos(AExpectedFragment, LReader.GetError) > 0,
      ALabel + ' reports comment payload error');
    CheckEqual(Int64(0), Int64(LReader.Depth),
      ALabel + ' leaves reader depth unchanged');
  end;

begin
  LReader := nil;
  try
    ExpectInvalidComment('<!--alpha--omega--><root/>',
      'comment text must not contain "--"',
      'comment with double hyphen payload');
    ExpectInvalidComment('<!--alpha---><root/>',
      'comment text must not end with "-"',
      'comment with trailing hyphen payload');
  finally
    LReader.Free;
  end;
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

procedure TestXmlDeclAttributeContract;
var
  LToks: TXmlTokenArray;
  LReader: TXmlReader;
  LTok: TXmlToken;

  procedure ExpectInvalidXmlDecl(
    const AXml, AExpectedFragment, ALabel: string);
  begin
    LReader.Free;
    LReader := TXmlReader.Create(AXml);
    Check(not LReader.Next(LTok), ALabel + ' rejects the xml declaration');
    Check(LReader.HasError, ALabel + ' sets reader error');
    Check(Pos(AExpectedFragment, LReader.GetError) > 0,
      ALabel + ' reports the expected error');
    CheckEqual(Int64(0), Int64(LReader.Depth),
      ALabel + ' leaves depth unchanged after failure');
  end;

begin
  LToks := ReadAll(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><r/>');
  CheckEqual(Int64(2), Int64(Length(LToks)), 'standalone decl token count');
  Check(LToks[0].Kind = xtkXmlDecl, 'standalone decl kind');
  CheckEqual(Int64(3), Int64(Length(LToks[0].Attributes)),
    'standalone decl attrs');
  CheckEqual('standalone', LToks[0].Attributes[2].Name.Local,
    'standalone attr');
  CheckEqual('yes', LToks[0].Attributes[2].Value, 'standalone val');

  LReader := nil;
  try
    ExpectInvalidXmlDecl(
      '<?xml encoding="UTF-8"?><root/>',
      'XML declaration must include a version attribute first',
      'missing version declaration');
    ExpectInvalidXmlDecl(
      '<?xml version="1.0" version="1.1"?><root/>',
      'XML declaration attribute "version" must not appear more than once',
      'duplicate version declaration');
    ExpectInvalidXmlDecl(
      '<?xml version="1.0" foo="bar"?><root/>',
      'XML declaration attribute "foo" is not supported',
      'unsupported declaration attribute');
    ExpectInvalidXmlDecl(
      '<?xml version="1.0" standalone="yes" encoding="UTF-8"?><root/>',
      'XML declaration attribute "encoding" must appear before "standalone"',
      'encoding after standalone declaration');
    ExpectInvalidXmlDecl(
      '<?xml version="1 x"?><root/>',
      'XML declaration version must be a valid XML version number',
      'invalid declaration version');
    ExpectInvalidXmlDecl(
      '<?xml version="1.0" encoding="UTF 8"?><root/>',
      'XML declaration encoding must be a valid XML encoding name',
      'invalid declaration encoding');
    ExpectInvalidXmlDecl(
      '<?xml version="1.0" standalone="maybe"?><root/>',
      'XML declaration standalone value must be "yes" or "no"',
      'invalid declaration standalone');
    ExpectInvalidXmlDecl(
      '<?xml version="1.0"><root/>',
      'XML declaration must end with ?>',
      'declaration without pi terminator');
  finally
    LReader.Free;
  end;
end;

procedure TestXmlDeclMustBeFirstToken;
var
  LReader: TXmlReader;
  LTok: TXmlToken;

  procedure ExpectMisplacedXmlDecl(
    const AXml, ALabel: string; const AExpectedFirstKind: TXmlTokenKind);
  begin
    LReader.Free;
    LReader := TXmlReader.Create(AXml);
    Check(LReader.Next(LTok), ALabel + ' yields the first token');
    Check(LTok.Kind = AExpectedFirstKind, ALabel + ' first token kind');
    Check(not LReader.Next(LTok), ALabel + ' rejects the misplaced declaration');
    Check(LReader.HasError, ALabel + ' sets reader error');
    Check(Pos('XML declaration must be the first token in the document',
      LReader.GetError) > 0, ALabel + ' reports placement error');
    CheckEqual(Int64(0), Int64(LReader.Depth),
      ALabel + ' leaves depth unchanged after failure');
  end;

begin
  LReader := nil;
  try
    ExpectMisplacedXmlDecl(
      '<?xml version="1.0"?><?xml version="1.0"?><root/>',
      'duplicate xml declaration',
      xtkXmlDecl);
    ExpectMisplacedXmlDecl(
      '<root/><?xml version="1.0"?>',
      'late xml declaration after root',
      xtkEmptyElement);
  finally
    LReader.Free;
  end;
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
  T.Run('TokenPositions', @TestTokenPositions);
  T.Run('TokenPositions.CROnlyLineEnding',
    @TestTokenPositionsCROnlyLineEnding);
  T.Run('TokenPositions.CRLFLineEndingCountsOnce',
    @TestTokenPositionsCRLFLineEndingCountsOnce);
  T.Run('SelfClosing', @TestSelfClosing);
  T.Run('SelfClosingWithSpace', @TestSelfClosingWithSpace);
  T.Run('AttributeDouble', @TestAttributeDouble);
  T.Run('AttributeSingle', @TestAttributeSingle);
  T.Run('MultipleAttributes', @TestMultipleAttributes);
  T.Run('DuplicateAttributesAreRejected', @TestDuplicateAttributesAreRejected);
  T.Run('AttributeEntityValue', @TestAttributeEntityValue);
  T.Run('AttributeRawLessThanIsRejected',
    @TestAttributeRawLessThanIsRejected);
  T.Run('NamespaceDecl', @TestNamespaceDecl);
  T.Run('DefaultNamespace', @TestDefaultNamespace);
  T.Run('NamespaceDeclAllowsXmlPrefixBinding',
    @TestNamespaceDeclAllowsXmlPrefixBinding);
  T.Run('NamespaceDeclRejectsInvalidReservedBindings',
    @TestNamespaceDeclRejectsInvalidReservedBindings);
  T.Run('UnboundNamespacePrefixesAreRejected',
    @TestUnboundNamespacePrefixesAreRejected);
  T.Run('NamespaceAttributeDeclarationsAreVisibleBeforeUse',
    @TestNamespaceAttributeDeclarationsAreVisibleBeforeUse);
  T.Run('DuplicateExpandedAttributeNamesAreRejected',
    @TestDuplicateExpandedAttributeNamesAreRejected);
  T.Run('ExpandedAttributeNamesAllowDistinctNamespaces',
    @TestExpandedAttributeNamesAllowDistinctNamespaces);
  T.Run('InvalidQNamesAreRejected', @TestInvalidQNamesAreRejected);
  T.Run('InvalidPITargetsAreRejected', @TestInvalidPITargetsAreRejected);
  T.Run('TextEntityDecode', @TestTextEntityDecode);
  T.Run('NumericEntity', @TestNumericEntity);
  T.Run('CData', @TestCData);
  T.Run('Comment', @TestComment);
  T.Run('CommentRejectsInvalidPayload', @TestCommentRejectsInvalidPayload);
  T.Run('PI', @TestPI);
  T.Run('XmlDecl', @TestXmlDecl);
  T.Run('XmlDeclAttributeContract', @TestXmlDeclAttributeContract);
  T.Run('XmlDeclMustBeFirstToken', @TestXmlDeclMustBeFirstToken);
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
