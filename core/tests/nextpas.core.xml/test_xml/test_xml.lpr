program test_xml;
{**
 * @desc XML Facade 测试套件：覆盖 nextpas.core.xml 统一导出的
 *       XmlParse / XmlTokenize / XmlDecodeEntities / XmlEncodeText /
 *       XmlEncodeAttr 五个门面函数，确保 facade 转发正确。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.default,
  nextpas.core.testing,
  nextpas.core.xml;

var
  T: TTestRunner;

{ === XmlParse（转发 TXmlDocument.Parse） === }

procedure TestXmlParseSimple;
var
  LDoc: TXmlDocument;
begin
  LDoc := XmlParse('<root>hello</root>');
  try
    Check(LDoc.Root.IsAssigned, 'root not nil');
    CheckEqual('root', LDoc.Root.Name.Local, 'root name');
    CheckEqual('hello', LDoc.Root.Text, 'root text');
  finally
    LDoc.Free;
  end;
end;

procedure TestXmlParseNested;
var
  LDoc: TXmlDocument;
  LChild: TXmlNode;
begin
  LDoc := XmlParse('<a attr="v"><b>inner</b></a>');
  try
    CheckEqual('a', LDoc.Root.Name.Local, 'root name');
    CheckEqual('v', LDoc.Root.GetAttr('attr'), 'root attr');
    CheckEqual(Int64(1), Int64(LDoc.Root.ChildCount), 'child count');
    LChild := LDoc.Root.FindChild('b');
    Check(LChild.IsAssigned, 'child found');
    CheckEqual('inner', LChild.Text, 'child text');
  finally
    LDoc.Free;
  end;
end;

procedure TestTryXmlParseSuccess;
var
  LDoc: TXmlDocument;
begin
  Check(TryXmlParse('<root><item>ok</item></root>', LDoc), 'try parse success');
  try
    Check(LDoc.IsAssigned, 'doc assigned');
    CheckEqual('root', LDoc.Root.Name.Local, 'root name');
    CheckEqual('ok', LDoc.Root.FindChild('item').Text, 'item text');
  finally
    LDoc.Free;
  end;
end;

procedure TestTryXmlParseFailureReturnsNil;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.None;
  Check(not TryXmlParse('<root><unclosed>', LDoc), 'try parse failure');
  Check(not LDoc.IsAssigned, 'doc remains nil on failure');
end;

procedure TestTryXmlParseWithSuccess;
var
  LDoc: TXmlDocument;
begin
  Check(TryXmlParseWith('<root><item>ok</item></root>', DefaultAllocator, LDoc),
    'try parse with allocator success');
  try
    Check(LDoc.IsAssigned, 'doc assigned');
    CheckEqual('ok', LDoc.Root.FindChild('item').Text, 'item text');
  finally
    LDoc.Free;
  end;
end;

procedure TestTryXmlParseWithFailureReturnsNil;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.None;
  Check(not TryXmlParseWith('<root><unclosed>', DefaultAllocator, LDoc),
    'try parse with allocator failure');
  Check(not LDoc.IsAssigned, 'doc remains nil on allocator parse failure');
end;

{ === XmlTokenize（转发 TXmlReader 流式 token） === }

procedure TestXmlTokenizeBasic;
var
  LToks: TXmlTokenArray;
begin
  LToks := XmlTokenize('<root>hi</root>');
  Check(Length(LToks) >= 3, 'at least start/text/end tokens');
  CheckEqual(Int64(Ord(xtkStartElement)), Int64(Ord(LToks[0].Kind)), 'first is start element');
  CheckEqual('root', LToks[0].Name.Local, 'start element name');
end;

procedure TestXmlTokenizeEmpty;
var
  LToks: TXmlTokenArray;
begin
  LToks := XmlTokenize('<br/>');
  Check(Length(LToks) >= 1, 'one token for empty element');
  CheckEqual(Int64(Ord(xtkEmptyElement)), Int64(Ord(LToks[0].Kind)), 'empty element kind');
  CheckEqual('br', LToks[0].Name.Local, 'empty element name');
end;

procedure TestXmlTokenizeText;
var
  LToks: TXmlTokenArray;
  I: Integer;
  LFound: Boolean;
begin
  LToks := XmlTokenize('<p>hello world</p>');
  LFound := False;
  for I := 0 to High(LToks) do
    if LToks[I].Kind = xtkText then
    begin
      CheckEqual('hello world', LToks[I].Value, 'text token value');
      LFound := True;
    end;
  Check(LFound, 'text token present');
end;

procedure TestXmlAllocatorSurface;
var
  LDoc: TXmlDocument;
  LToks: TXmlTokenArray;
begin
  LDoc := XmlParseWith('<root><item>ok</item></root>', DefaultAllocator);
  try
    Check(LDoc.Allocator <> nil, 'allocator accessor visible');
    Check(LDoc.Root.IsAssigned, 'root node assigned');
    CheckEqual('ok', LDoc.Root.FindChild('item').Text, 'XmlParseWith works');
  finally
    LDoc.Done;
  end;

  LToks := XmlTokenizeWith('<root/>', DefaultAllocator);
  CheckEqual(Int64(1), Int64(Length(LToks)), 'XmlTokenizeWith token count');
  Check(LToks[0].Kind = xtkEmptyElement, 'XmlTokenizeWith kind');
end;

{ === XmlDecodeEntities === }

procedure TestXmlDecodeEntities;
begin
  CheckEqual('<a> & "b" ''c''', XmlDecodeEntities('&lt;a&gt; &amp; &quot;b&quot; &apos;c&apos;'),
    'decode named entities');
end;

procedure TestXmlDecodeNumeric;
begin
  CheckEqual('AB', XmlDecodeEntities('&#65;&#66;'), 'decode decimal numeric');
  CheckEqual('AB', XmlDecodeEntities('&#x41;&#x42;'), 'decode hex numeric');
end;

{ === XmlEncodeText / XmlEncodeAttr === }

procedure TestXmlEncodeText;
begin
  CheckEqual('a &lt;b&gt; &amp; c', XmlEncodeText('a <b> & c'), 'encode text special chars');
end;

procedure TestXmlEncodeAttr;
begin
  CheckEqual('say &quot;hi&quot; &amp; bye', XmlEncodeAttr('say "hi" & bye'),
    'encode attr quotes + amp');
end;

procedure TestEncodeDecodeRoundTrip;
var
  LOriginal, LEncoded: string;
begin
  LOriginal := 'tags <x> & "quotes" mixed';
  LEncoded := XmlEncodeText(LOriginal);
  CheckEqual(LOriginal, XmlDecodeEntities(LEncoded), 'encode/decode round-trip');
end;

{ === 边界场景 === }

procedure TestXmlParseIgnoresDeclAndDoctype;
var
  LDoc: TXmlDocument;
begin
  { 声明与 DTD 不进入 DOM，根仍为 root }
  LDoc := XmlParse('<?xml version="1.0"?><!DOCTYPE root><root/>');
  try
    Check(LDoc.Root.IsAssigned, 'root present despite decl/doctype');
    CheckEqual('root', LDoc.Root.Name.Local, 'root name after decl/doctype');
  finally
    LDoc.Free;
  end;
end;

procedure TestXmlParseAllowsDocumentWhitespace;
var
  LDoc: TXmlDocument;
begin
  LDoc := XmlParse('  ' + #10 + '<root/>' + #10 + '  ');
  try
    Check(LDoc.Root.IsAssigned, 'root present with surrounding whitespace');
    CheckEqual('root', LDoc.Root.Name.Local, 'root name with surrounding whitespace');
  finally
    LDoc.Free;
  end;
end;

procedure TestXmlParseAllowsPreRootDoctype;
var
  LDoc: TXmlDocument;
begin
  LDoc := XmlParse('<?xml version="1.0"?><!--pre--><!DOCTYPE root><root/><?tail data?>');
  try
    Check(LDoc.Root.IsAssigned, 'root present with pre-root doctype');
    CheckEqual('root', LDoc.Root.Name.Local, 'root name with pre-root doctype');
  finally
    LDoc.Free;
  end;
end;

procedure TestXmlTokenizeEmptyInput;
var
  LToks: TXmlTokenArray;
begin
  LToks := XmlTokenize('');
  CheckEqual(Int64(0), Int64(Length(LToks)), 'empty input yields zero tokens');
end;

procedure TestXmlTokenizePropagatesError;
var
  LRaised: Boolean;
begin
  { 非法 XML 必须抛 EXmlError，而非静默返回部分 token }
  LRaised := False;
  try
    XmlTokenize('<root><unclosed>');
  except
    on E: EXmlError do
      LRaised := True;
  end;
  Check(LRaised, 'malformed XML raises EXmlError');
end;

procedure TestXmlTokenizeReportsExactEofPosition;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    XmlTokenize('<root><unclosed>');
  except
    on E: EXmlError do
    begin
      LRaised := True;
      Check(Pos('Unclosed element: unclosed', E.Message) > 0,
        'EOF error text');
      CheckEqual(Int64(16), Int64(E.Pos.ByteOffset),
        'EOF error byte offset');
      CheckEqual(Int64(1), Int64(E.Pos.Line), 'EOF error line');
      CheckEqual(Int64(17), Int64(E.Pos.Column), 'EOF error column');
    end;
  end;
  Check(LRaised, 'EOF error raises EXmlError');
end;

procedure TestXmlTokenizeReportsExactCROnlyEofPosition;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    XmlTokenize('<root>' + #13 + '<unclosed>');
  except
    on E: EXmlError do
    begin
      LRaised := True;
      Check(Pos('Unclosed element: unclosed', E.Message) > 0,
        'CR-only EOF error text');
      CheckEqual(Int64(17), Int64(E.Pos.ByteOffset),
        'CR-only EOF error byte offset');
      CheckEqual(Int64(2), Int64(E.Pos.Line), 'CR-only EOF error line');
      CheckEqual(Int64(11), Int64(E.Pos.Column),
        'CR-only EOF error column');
    end;
  end;
  Check(LRaised, 'CR-only EOF error raises EXmlError');
end;

procedure TestXmlTokenizeRejectsInvalidReservedNamespaceBinding;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    XmlTokenize('<root xmlns:xmlns="urn:x"/>');
  except
    on E: EXmlError do
    begin
      LRaised := True;
      Check(Pos('prefix "xmlns" is reserved', E.Message) > 0,
        'reserved namespace failure text');
      CheckEqual(Int64(1), Int64(E.Pos.Line), 'error line');
      Check(E.Pos.Column > 1, 'error column recorded');
    end;
  end;
  Check(LRaised, 'invalid reserved namespace binding raises EXmlError');
end;

procedure TestXmlTokenizeRejectsUnboundNamespacePrefix;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    XmlTokenize('<ns:root/>');
  except
    on E: EXmlError do
    begin
      LRaised := True;
      Check(Pos('namespace prefix "ns" is not bound', E.Message) > 0,
        'unbound namespace failure text');
      CheckEqual(Int64(1), Int64(E.Pos.Line), 'error line');
      Check(E.Pos.Column > 1, 'error column recorded');
    end;
  end;
  Check(LRaised, 'unbound namespace prefix raises EXmlError');
end;

procedure TestXmlRejectsInvalidCommentPayload;
  procedure ExpectCommentError(const AXml, AExpectedFragment,
    ALabel: string);
  var
    LRaised: Boolean;
    LDoc: TXmlDocument;
  begin
    LRaised := False;
    LDoc := TXmlDocument.None;
    try
      try
        XmlTokenize(AXml);
      except
        on E: EXmlError do
        begin
          LRaised := True;
          Check(Pos(AExpectedFragment, E.Message) > 0,
            ALabel + ' tokenize reports comment payload error');
          Check(E.Pos.Line > 0, ALabel + ' tokenize error line recorded');
          Check(E.Pos.Column > 0, ALabel + ' tokenize error column recorded');
        end;
      end;
      Check(LRaised, ALabel + ' XmlTokenize raises EXmlError');

      Check(not TryXmlParse(AXml, LDoc),
        ALabel + ' TryXmlParse rejects invalid comment payload');
      Check(not LDoc.IsAssigned, ALabel + ' TryXmlParse keeps nil doc');
    finally
      LDoc.Free;
    end;
  end;
begin
  ExpectCommentError('<root><!--alpha--omega--></root>',
    'comment text must not contain "--"',
    'comment with double hyphen payload');
  ExpectCommentError('<root><!--alpha---></root>',
    'comment text must not end with "-"',
    'comment with trailing hyphen payload');
end;

procedure TestXmlRejectsInvalidDocumentStructure;
  procedure ExpectParseError(const AXml, AExpectedFragment, ALabel: string);
  var
    LRaised: Boolean;
    LDoc: TXmlDocument;
  begin
    LRaised := False;
    LDoc := TXmlDocument.None;
    try
      try
        LDoc := XmlParse(AXml);
      except
        on E: EXmlError do
        begin
          LRaised := True;
          Check(Pos(AExpectedFragment, E.Message) > 0,
            ALabel + ' reports the expected error text');
          CheckEqual(Int64(1), Int64(E.Pos.Line), ALabel + ' error line');
          Check(E.Pos.Column > 0, ALabel + ' error column recorded');
        end;
      end;
      Check(LRaised, ALabel + ' raises EXmlError');
    finally
      LDoc.Free;
    end;
  end;
var
  LDoc: TXmlDocument;
begin
  ExpectParseError(
    'hello<root/>',
    'Document text outside root element must be whitespace only',
    'leading document text');
  ExpectParseError(
    '<root/>tail',
    'Document text outside root element must be whitespace only',
    'trailing document text');
  ExpectParseError(
    '<![CDATA[text]]><root/>',
    'Document text outside root element must be whitespace only',
    'leading document cdata');
  ExpectParseError(
    '<a/><b/>',
    'Multiple root elements',
    'multiple root elements');

  LDoc := TXmlDocument.None;
  Check(not TryXmlParse('hello<root/>', LDoc),
    'TryXmlParse rejects leading document text');
  Check(not LDoc.IsAssigned, 'TryXmlParse keeps nil doc for leading document text');
  Check(not TryXmlParse('<root/>tail', LDoc),
    'TryXmlParse rejects trailing document text');
  Check(not LDoc.IsAssigned, 'TryXmlParse keeps nil doc for trailing document text');
  Check(not TryXmlParse('<a/><b/>', LDoc),
    'TryXmlParse rejects multiple root elements');
  Check(not LDoc.IsAssigned, 'TryXmlParse keeps nil doc for multiple root elements');
end;

procedure TestXmlRejectsMisplacedDoctype;
  procedure ExpectParseError(const AXml, AExpectedFragment, ALabel: string);
  var
    LRaised: Boolean;
    LDoc: TXmlDocument;
  begin
    LRaised := False;
    LDoc := TXmlDocument.None;
    try
      try
        LDoc := XmlParse(AXml);
      except
        on E: EXmlError do
        begin
          LRaised := True;
          Check(Pos(AExpectedFragment, E.Message) > 0,
            ALabel + ' reports the expected error text');
          CheckEqual(Int64(1), Int64(E.Pos.Line), ALabel + ' error line');
          Check(E.Pos.Column > 0, ALabel + ' error column recorded');
        end;
      end;
      Check(LRaised, ALabel + ' raises EXmlError');
    finally
      LDoc.Free;
    end;
  end;
var
  LDoc: TXmlDocument;
begin
  ExpectParseError(
    '<!DOCTYPE root><!DOCTYPE root><root/>',
    'DOCTYPE must not appear more than once',
    'duplicate doctype');
  ExpectParseError(
    '<root/><!DOCTYPE root>',
    'DOCTYPE must appear before the root element',
    'post-root doctype');
  ExpectParseError(
    '<root><!DOCTYPE root></root>',
    'DOCTYPE must appear before the root element',
    'in-content doctype');

  LDoc := TXmlDocument.None;
  Check(not TryXmlParse('<!DOCTYPE root><!DOCTYPE root><root/>', LDoc),
    'TryXmlParse rejects duplicate doctype');
  Check(not LDoc.IsAssigned, 'TryXmlParse keeps nil doc for duplicate doctype');
  Check(not TryXmlParse('<root/><!DOCTYPE root>', LDoc),
    'TryXmlParse rejects post-root doctype');
  Check(not LDoc.IsAssigned, 'TryXmlParse keeps nil doc for post-root doctype');
end;

procedure TestXmlRejectsMissingRootElement;
  procedure ExpectParseError(const AXml, AExpectedFragment, ALabel: string);
  var
    LRaised: Boolean;
    LDoc: TXmlDocument;
  begin
    LRaised := False;
    LDoc := TXmlDocument.None;
    try
      try
        LDoc := XmlParse(AXml);
      except
        on E: EXmlError do
        begin
          LRaised := True;
          Check(Pos(AExpectedFragment, E.Message) > 0,
            ALabel + ' reports the expected error text');
          CheckEqual(Int64(1), Int64(E.Pos.Line), ALabel + ' error line');
          Check(E.Pos.Column > 0, ALabel + ' error column recorded');
        end;
      end;
      Check(LRaised, ALabel + ' raises EXmlError');
    finally
      LDoc.Free;
    end;
  end;
var
  LDoc: TXmlDocument;
begin
  ExpectParseError(
    '<?xml version="1.0"?>',
    'Document must contain a root element',
    'xml declaration only');
  ExpectParseError(
    '<!--comment-->',
    'Document must contain a root element',
    'comment only');
  ExpectParseError(
    '<?target data?>',
    'Document must contain a root element',
    'processing instruction only');
  ExpectParseError(
    '<!DOCTYPE root>',
    'Document must contain a root element',
    'doctype only');

  LDoc := TXmlDocument.None;
  Check(not TryXmlParse('<?xml version="1.0"?>', LDoc),
    'TryXmlParse rejects xml declaration without root');
  Check(not LDoc.IsAssigned, 'TryXmlParse keeps nil doc for xml declaration without root');
  Check(not TryXmlParse('<!DOCTYPE root>', LDoc),
    'TryXmlParse rejects doctype without root');
  Check(not LDoc.IsAssigned, 'TryXmlParse keeps nil doc for doctype without root');
end;

procedure TestXmlTokenizeRejectsInvalidNames;
  procedure ExpectTokenizeError(
    const AXml, AExpectedFragment, ALabel: string);
  var
    LRaised: Boolean;
  begin
    LRaised := False;
    try
      XmlTokenize(AXml);
    except
      on E: EXmlError do
      begin
        LRaised := True;
        Check(Pos(AExpectedFragment, E.Message) > 0,
          ALabel + ' reports the expected error text');
        CheckEqual(Int64(1), Int64(E.Pos.Line), ALabel + ' error line');
        Check(E.Pos.Column > 1, ALabel + ' error column recorded');
      end;
    end;
    Check(LRaised, ALabel + ' raises EXmlError');
  end;
begin
  ExpectTokenizeError(
    '<ns:bad:name/>',
    'element name must be a valid XML QName',
    'invalid element QName');
  ExpectTokenizeError(
    '<?XML version="1.0"?>',
    'processing-instruction target "xml" is reserved for XML declarations',
    'reserved XML processing-instruction target');
end;

procedure TestXmlRejectsMisplacedXmlDecl;
  procedure ExpectXmlError(
    const AXml, AExpectedFragment, ALabel: string; AUseParse: Boolean);
  var
    LRaised: Boolean;
    LDoc: TXmlDocument;
  begin
    LRaised := False;
    LDoc := TXmlDocument.None;
    try
      try
        if AUseParse then
          LDoc := XmlParse(AXml)
        else
          XmlTokenize(AXml);
      except
        on E: EXmlError do
        begin
          LRaised := True;
          Check(Pos(AExpectedFragment, E.Message) > 0,
            ALabel + ' reports the expected error text');
          CheckEqual(Int64(1), Int64(E.Pos.Line), ALabel + ' error line');
          Check(E.Pos.Column > 1, ALabel + ' error column recorded');
        end;
      end;
      Check(LRaised, ALabel + ' raises EXmlError');
    finally
      LDoc.Free;
    end;
  end;
begin
  ExpectXmlError(
    '<root/><?xml version="1.0"?>',
    'XML declaration must be the first token in the document',
    'tokenize late xml declaration',
    False);
  ExpectXmlError(
    '<?xml version="1.0"?><?xml version="1.0"?><root/>',
    'XML declaration must be the first token in the document',
    'parse duplicate xml declaration',
    True);
end;

procedure TestXmlRejectsInvalidXmlDeclAttributes;
  procedure ExpectXmlError(
    const AXml, AExpectedFragment, ALabel: string; AUseParse: Boolean);
  var
    LRaised: Boolean;
    LDoc: TXmlDocument;
  begin
    LRaised := False;
    LDoc := TXmlDocument.None;
    try
      try
        if AUseParse then
          LDoc := XmlParse(AXml)
        else
          XmlTokenize(AXml);
      except
        on E: EXmlError do
        begin
          LRaised := True;
          Check(Pos(AExpectedFragment, E.Message) > 0,
            ALabel + ' reports the expected error text');
          CheckEqual(Int64(1), Int64(E.Pos.Line), ALabel + ' error line');
          Check(E.Pos.Column > 1, ALabel + ' error column recorded');
        end;
      end;
      Check(LRaised, ALabel + ' raises EXmlError');
    finally
      LDoc.Free;
    end;
  end;
begin
  ExpectXmlError(
    '<?xml encoding="UTF-8"?><root/>',
    'XML declaration must include a version attribute first',
    'tokenize missing declaration version',
    False);
  ExpectXmlError(
    '<?xml version="1.0" standalone="yes" encoding="UTF-8"?><root/>',
    'XML declaration attribute "encoding" must appear before "standalone"',
    'parse invalid declaration attribute order',
    True);
  ExpectXmlError(
    '<?xml version="1.0"><root/>',
    'XML declaration must end with ?>',
    'tokenize declaration without pi terminator',
    False);
end;

procedure TestXmlRejectsDuplicateAttributes;
var
  LDoc: TXmlDocument;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    XmlTokenize('<r a="1" a="2"/>');
  except
    on E: EXmlError do
    begin
      LRaised := True;
      Check(Pos('attribute "a" must not appear more than once',
        E.Message) > 0, 'tokenize duplicate attribute error text');
      CheckEqual(Int64(1), Int64(E.Pos.Line),
        'tokenize duplicate attribute error line');
      Check(E.Pos.Column > 1, 'tokenize duplicate attribute error column');
    end;
  end;
  Check(LRaised, 'XmlTokenize rejects duplicate attributes');

  LDoc := TXmlDocument.None;
  Check(not TryXmlParse('<r a="1" a="2"/>', LDoc),
    'TryXmlParse rejects duplicate attributes');
  Check(not LDoc.IsAssigned, 'TryXmlParse keeps nil doc for duplicate attributes');

  LRaised := False;
  try
    LDoc := XmlParse('<r a="1" a="2"/>');
  except
    on E: EXmlError do
    begin
      LRaised := True;
      Check(Pos('attribute "a" must not appear more than once',
        E.Message) > 0, 'XmlParse duplicate attribute error text');
    end;
  end;
  try
    Check(LRaised, 'XmlParse rejects duplicate attributes');
  finally
    LDoc.Free;
  end;

  LRaised := False;
  try
    XmlTokenize('<r xmlns:p="urn:x" xmlns:q="urn:x" p:a="1" q:a="2"/>');
  except
    on E: EXmlError do
    begin
      LRaised := True;
      Check(Pos('must not appear more than once', E.Message) > 0,
        'tokenize duplicate expanded attribute error text');
    end;
  end;
  Check(LRaised, 'XmlTokenize rejects duplicate expanded attributes');

  LDoc := TXmlDocument.None;
  Check(not TryXmlParse(
    '<r xmlns:p="urn:x" xmlns:q="urn:x" p:a="1" q:a="2"/>',
    LDoc),
    'TryXmlParse rejects duplicate expanded attributes');
  Check(not LDoc.IsAssigned,
    'TryXmlParse keeps nil doc for duplicate expanded attributes');

  LRaised := False;
  try
    LDoc := XmlParse(
      '<r xmlns:p="urn:x" xmlns:q="urn:x" p:a="1" q:a="2"/>');
  except
    on E: EXmlError do
    begin
      LRaised := True;
      Check(Pos('must not appear more than once', E.Message) > 0,
        'XmlParse duplicate expanded attribute error text');
    end;
  end;
  try
    Check(LRaised, 'XmlParse rejects duplicate expanded attributes');
  finally
    LDoc.Free;
  end;
end;

procedure TestXmlRejectsRawLessThanInAttributeValue;
var
  LDoc: TXmlDocument;
  LToks: TXmlTokenArray;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    XmlTokenize('<r a="raw<bad"/>');
  except
    on E: EXmlError do
    begin
      LRaised := True;
      Check(Pos('attribute value must not contain raw <', E.Message) > 0,
        'XmlTokenize raw less-than attribute error text');
      CheckEqual(Int64(1), Int64(E.Pos.Line),
        'XmlTokenize raw less-than attribute error line');
      Check(E.Pos.Column > 1,
        'XmlTokenize raw less-than attribute error column');
    end;
  end;
  Check(LRaised, 'XmlTokenize rejects raw less-than in attribute value');

  LDoc := TXmlDocument.None;
  Check(not TryXmlParse('<r a="raw<bad"/>', LDoc),
    'TryXmlParse rejects raw less-than in attribute value');
  Check(not LDoc.IsAssigned,
    'TryXmlParse keeps nil doc for raw less-than in attribute value');

  LRaised := False;
  try
    LDoc := XmlParse('<r a="raw<bad"/>');
  except
    on E: EXmlError do
    begin
      LRaised := True;
      Check(Pos('attribute value must not contain raw <', E.Message) > 0,
        'XmlParse raw less-than attribute error text');
    end;
  end;
  try
    Check(LRaised, 'XmlParse rejects raw less-than in attribute value');
  finally
    LDoc.Free;
  end;

  LToks := XmlTokenize('<r a="safe&lt;value"/>');
  CheckEqual(Int64(1), Int64(Length(LToks)),
    'XmlTokenize keeps escaped less-than attribute valid');
  CheckEqual('safe<value', LToks[0].Attributes[0].Value,
    'XmlTokenize decodes escaped less-than attribute value');
end;

procedure TestXmlAllowsDistinctExpandedAttributes;
var
  LDoc: TXmlDocument;
  LToks: TXmlTokenArray;
begin
  LToks := XmlTokenize(
    '<r p:a="1" q:a="2" xmlns:p="urn:p" xmlns:q="urn:q"/>');
  CheckEqual(Int64(1), Int64(Length(LToks)),
    'distinct namespace attributes tokenize one token');
  CheckEqual(Int64(4), Int64(Length(LToks[0].Attributes)),
    'distinct namespace attributes and declarations are retained');

  LDoc := TXmlDocument.None;
  Check(TryXmlParse(
    '<r p:a="1" q:a="2" xmlns:p="urn:p" xmlns:q="urn:q"/>',
    LDoc),
    'TryXmlParse allows same local attributes in distinct namespaces');
  try
    Check(LDoc.IsAssigned,
      'TryXmlParse returns doc for distinct namespace attributes');
  finally
    LDoc.Free;
  end;

  LDoc := XmlParse(
    '<r a="1" p:a="2" xmlns="urn:x" xmlns:p="urn:x"/>');
  try
    Check(LDoc.Root.IsAssigned,
      'XmlParse allows unprefixed attr beside same-URI prefixed attr');
    CheckEqual('1', LDoc.Root.GetAttr('a'),
      'unprefixed attribute remains visible by local name');
  finally
    LDoc.Free;
  end;
end;

procedure TestXmlEncodeAttrApos;
begin
  CheckEqual('it&apos;s', XmlEncodeAttr('it''s'), 'encode single quote in attr');
end;

begin
  T := TTestRunner.Create('XML Facade');
  T.Run('XmlParseSimple', @TestXmlParseSimple);
  T.Run('XmlParseNested', @TestXmlParseNested);
  T.Run('TryXmlParseSuccess', @TestTryXmlParseSuccess);
  T.Run('TryXmlParseFailureReturnsNil', @TestTryXmlParseFailureReturnsNil);
  T.Run('TryXmlParseWithSuccess', @TestTryXmlParseWithSuccess);
  T.Run('TryXmlParseWithFailureReturnsNil',
    @TestTryXmlParseWithFailureReturnsNil);
  T.Run('XmlTokenizeBasic', @TestXmlTokenizeBasic);
  T.Run('XmlTokenizeEmpty', @TestXmlTokenizeEmpty);
  T.Run('XmlTokenizeText', @TestXmlTokenizeText);
  T.Run('XmlAllocatorSurface', @TestXmlAllocatorSurface);
  T.Run('XmlDecodeEntities', @TestXmlDecodeEntities);
  T.Run('XmlDecodeNumeric', @TestXmlDecodeNumeric);
  T.Run('XmlEncodeText', @TestXmlEncodeText);
  T.Run('XmlEncodeAttr', @TestXmlEncodeAttr);
  T.Run('EncodeDecodeRoundTrip', @TestEncodeDecodeRoundTrip);
  T.Run('XmlParseIgnoresDeclAndDoctype', @TestXmlParseIgnoresDeclAndDoctype);
  T.Run('XmlParseAllowsDocumentWhitespace', @TestXmlParseAllowsDocumentWhitespace);
  T.Run('XmlParseAllowsPreRootDoctype', @TestXmlParseAllowsPreRootDoctype);
  T.Run('XmlTokenizeEmptyInput', @TestXmlTokenizeEmptyInput);
  T.Run('XmlTokenizePropagatesError', @TestXmlTokenizePropagatesError);
  T.Run('XmlTokenizeReportsExactEofPosition',
    @TestXmlTokenizeReportsExactEofPosition);
  T.Run('XmlTokenizeReportsExactCROnlyEofPosition',
    @TestXmlTokenizeReportsExactCROnlyEofPosition);
  T.Run('XmlTokenizeRejectsInvalidReservedNamespaceBinding',
    @TestXmlTokenizeRejectsInvalidReservedNamespaceBinding);
  T.Run('XmlTokenizeRejectsUnboundNamespacePrefix',
    @TestXmlTokenizeRejectsUnboundNamespacePrefix);
  T.Run('XmlRejectsInvalidCommentPayload',
    @TestXmlRejectsInvalidCommentPayload);
  T.Run('XmlRejectsInvalidDocumentStructure',
    @TestXmlRejectsInvalidDocumentStructure);
  T.Run('XmlRejectsMisplacedDoctype',
    @TestXmlRejectsMisplacedDoctype);
  T.Run('XmlRejectsMissingRootElement',
    @TestXmlRejectsMissingRootElement);
  T.Run('XmlTokenizeRejectsInvalidNames',
    @TestXmlTokenizeRejectsInvalidNames);
  T.Run('XmlRejectsMisplacedXmlDecl',
    @TestXmlRejectsMisplacedXmlDecl);
  T.Run('XmlRejectsInvalidXmlDeclAttributes',
    @TestXmlRejectsInvalidXmlDeclAttributes);
  T.Run('XmlRejectsDuplicateAttributes',
    @TestXmlRejectsDuplicateAttributes);
  T.Run('XmlRejectsRawLessThanInAttributeValue',
    @TestXmlRejectsRawLessThanInAttributeValue);
  T.Run('XmlAllowsDistinctExpandedAttributes',
    @TestXmlAllowsDistinctExpandedAttributes);
  T.Run('XmlEncodeAttrApos', @TestXmlEncodeAttrApos);
  T.Summary;
end.
