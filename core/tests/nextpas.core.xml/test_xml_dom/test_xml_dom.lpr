program test_xml_dom;
{**
 * @desc XML DOM 测试套件：20+ 测试覆盖树构建、查询、路径选择等场景。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.xml.base,
  nextpas.core.xml.dom;

var
  T: TTestRunner;

{ === Tests === }

procedure TestParseSimple;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<root>hello</root>');
  try
    Check(LDoc.Root <> nil, 'root not nil');
    CheckEqual('root', LDoc.Root.Name.Local, 'root name');
    CheckEqual('hello', LDoc.Root.Text, 'root text');
  finally
    LDoc.Free;
  end;
end;

procedure TestParseNested;
var
  LDoc: TXmlDocument;
  LChild: TXmlNode;
begin
  LDoc := TXmlDocument.Parse('<a><b>inner</b></a>');
  try
    Check(LDoc.Root <> nil, 'root');
    CheckEqual('a', LDoc.Root.Name.Local, 'root name');
    CheckEqual(Int64(1), Int64(LDoc.Root.ChildCount), 'child count');
    LChild := LDoc.Root.FindChild('b');
    Check(LChild <> nil, 'find b');
    CheckEqual('inner', LChild.Text, 'b text');
  finally
    LDoc.Free;
  end;
end;

procedure TestParseAttributes;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<item id="42" name="test">x</item>');
  try
    CheckEqual('42', LDoc.Root.GetAttr('id'), 'id attr');
    CheckEqual('test', LDoc.Root.GetAttr('name'), 'name attr');
    CheckEqual('default', LDoc.Root.GetAttr('missing', 'default'), 'default attr');
  finally
    LDoc.Free;
  end;
end;

procedure TestParseRejectsDuplicateAttributes;
var
  LDoc: TXmlDocument;
  LRaised: Boolean;
begin
  LRaised := False;
  LDoc := nil;
  try
    try
      LDoc := TXmlDocument.Parse('<r a="1" a="2"/>');
    except
      on E: EXmlError do
      begin
        LRaised := True;
        Check(Pos('attribute "a" must not appear more than once',
          E.Message) > 0, 'duplicate attribute error text');
        CheckEqual(Int64(1), Int64(E.Pos.Line),
          'duplicate attribute error line');
        Check(E.Pos.Column > 1, 'duplicate attribute error column');
      end;
    end;
    Check(LRaised, 'DOM parse rejects duplicate attributes');
  finally
    LDoc.Free;
  end;
end;

procedure TestParseRejectsDuplicateExpandedAttributes;
var
  LDoc: TXmlDocument;
  LRaised: Boolean;
begin
  LRaised := False;
  LDoc := nil;
  try
    try
      LDoc := TXmlDocument.Parse(
        '<r xmlns:p="urn:x" xmlns:q="urn:x" p:a="1" q:a="2"/>');
    except
      on E: EXmlError do
      begin
        LRaised := True;
        Check(Pos('must not appear more than once', E.Message) > 0,
          'duplicate expanded attribute error text');
        CheckEqual(Int64(1), Int64(E.Pos.Line),
          'duplicate expanded attribute error line');
        Check(E.Pos.Column > 1, 'duplicate expanded attribute error column');
      end;
    end;
    Check(LRaised, 'DOM parse rejects duplicate expanded attributes');
  finally
    LDoc.Free;
  end;
end;

procedure TestParseAllowsDistinctExpandedAttributes;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse(
    '<r p:a="1" q:a="2" xmlns:p="urn:p" xmlns:q="urn:q"/>');
  try
    Check(LDoc.Root <> nil,
      'DOM parse allows same local attributes in distinct namespaces');
  finally
    LDoc.Free;
  end;

  LDoc := TXmlDocument.Parse(
    '<r a="1" p:a="2" xmlns="urn:x" xmlns:p="urn:x"/>');
  try
    Check(LDoc.Root <> nil,
      'DOM parse allows default namespace plus prefixed same local attr');
  finally
    LDoc.Free;
  end;
end;

procedure TestParseRejectsUnboundNamespacePrefix;
var
  LDoc: TXmlDocument;
  LRaised: Boolean;
begin
  LRaised := False;
  LDoc := nil;
  try
    try
      LDoc := TXmlDocument.Parse('<root bad:attr="x"/>');
    except
      on E: EXmlError do
      begin
        LRaised := True;
        Check(Pos('namespace prefix "bad" is not bound', E.Message) > 0,
          'unbound namespace error text');
        CheckEqual(Int64(1), Int64(E.Pos.Line),
          'unbound namespace error line');
        Check(E.Pos.Column > 1, 'unbound namespace error column');
      end;
    end;
    Check(LRaised, 'DOM parse rejects unbound namespace prefix');
  finally
    LDoc.Free;
  end;
end;

procedure TestParseRejectsRawLessThanInAttributeValue;
var
  LDoc: TXmlDocument;
  LRaised: Boolean;
begin
  LRaised := False;
  LDoc := nil;
  try
    try
      LDoc := TXmlDocument.Parse('<root attr="raw<bad"/>');
    except
      on E: EXmlError do
      begin
        LRaised := True;
        Check(Pos('attribute value must not contain raw <', E.Message) > 0,
          'raw less-than attribute error text');
        CheckEqual(Int64(1), Int64(E.Pos.Line),
          'raw less-than attribute error line');
        Check(E.Pos.Column > 1, 'raw less-than attribute error column');
      end;
    end;
    Check(LRaised, 'DOM parse rejects raw less-than in attribute value');
  finally
    LDoc.Free;
  end;

  LDoc := TXmlDocument.Parse('<root attr="safe&lt;value"/>');
  try
    CheckEqual('safe<value', LDoc.Root.GetAttr('attr'),
      'DOM parse keeps escaped less-than attribute valid');
  finally
    LDoc.Free;
  end;
end;

procedure TestFindChild;
var
  LDoc: TXmlDocument;
  LChild: TXmlNode;
begin
  LDoc := TXmlDocument.Parse('<r><a>1</a><b>2</b><c>3</c></r>');
  try
    LChild := LDoc.Root.FindChild('b');
    Check(LChild <> nil, 'find b');
    CheckEqual('2', LChild.Text, 'b text');
    LChild := LDoc.Root.FindChild('missing');
    Check(LChild = nil, 'missing is nil');
  finally
    LDoc.Free;
  end;
end;

procedure TestFindChildren;
var
  LDoc: TXmlDocument;
  LItems: TXmlNodeArray;
begin
  LDoc := TXmlDocument.Parse('<r><item>a</item><other/><item>b</item><item>c</item></r>');
  try
    LItems := LDoc.Root.FindChildren('item');
    CheckEqual(Int64(3), Int64(Length(LItems)), 'item count');
    CheckEqual('a', LItems[0].Text, 'item 0');
    CheckEqual('b', LItems[1].Text, 'item 1');
    CheckEqual('c', LItems[2].Text, 'item 2');
  finally
    LDoc.Free;
  end;
end;

procedure TestTextConcat;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<r>hello <![CDATA[world]]> end</r>');
  try
    CheckEqual('hello world end', LDoc.Root.Text, 'text concat');
  finally
    LDoc.Free;
  end;
end;

procedure TestTextRecursive;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<p>Hello <b>world</b>!</p>');
  try
    CheckEqual('Hello world!', LDoc.Root.Text, 'recursive text');
  finally
    LDoc.Free;
  end;
end;

procedure TestSelectPathSimple;
var
  LDoc: TXmlDocument;
  LNodes: TXmlNodeArray;
begin
  LDoc := TXmlDocument.Parse('<root><child><name>test</name></child></root>');
  try
    LNodes := LDoc.SelectPath('/root/child/name');
    CheckEqual(Int64(1), Int64(Length(LNodes)), 'path count');
    CheckEqual('test', LNodes[0].Text, 'path text');
  finally
    LDoc.Free;
  end;
end;

procedure TestSelectPathMultiple;
var
  LDoc: TXmlDocument;
  LNodes: TXmlNodeArray;
begin
  LDoc := TXmlDocument.Parse('<root><items><item>a</item><item>b</item></items></root>');
  try
    LNodes := LDoc.SelectPath('/root/items/item');
    CheckEqual(Int64(2), Int64(Length(LNodes)), 'path count');
    CheckEqual('a', LNodes[0].Text, 'item 0');
    CheckEqual('b', LNodes[1].Text, 'item 1');
  finally
    LDoc.Free;
  end;
end;

procedure TestSelectPathNoMatch;
var
  LDoc: TXmlDocument;
  LNodes: TXmlNodeArray;
begin
  LDoc := TXmlDocument.Parse('<root><a/></root>');
  try
    LNodes := LDoc.SelectPath('/root/missing');
    CheckEqual(Int64(0), Int64(Length(LNodes)), 'no match');
  finally
    LDoc.Free;
  end;
end;

procedure TestSelectPathRootMismatch;
var
  LDoc: TXmlDocument;
  LNodes: TXmlNodeArray;
begin
  LDoc := TXmlDocument.Parse('<root/>');
  try
    LNodes := LDoc.SelectPath('/other');
    CheckEqual(Int64(0), Int64(Length(LNodes)), 'root mismatch');
  finally
    LDoc.Free;
  end;
end;

procedure TestEmptyDocument;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('');
  try
    Check(LDoc.Root = nil, 'empty doc root nil');
  finally
    LDoc.Free;
  end;
end;

procedure TestDocumentWhitespace;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('  ' + #10 + '<root/>' + #10 + '  ');
  try
    Check(LDoc.Root <> nil, 'root present with surrounding whitespace');
    CheckEqual('root', LDoc.Root.Name.Local, 'root name with surrounding whitespace');
  finally
    LDoc.Free;
  end;
end;

procedure TestPreRootDoctype;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<?xml version="1.0"?><!--pre--><!DOCTYPE root><root/><?tail data?>');
  try
    Check(LDoc.Root <> nil, 'root present with pre-root doctype');
    CheckEqual('root', LDoc.Root.Name.Local, 'root name with pre-root doctype');
  finally
    LDoc.Free;
  end;
end;

procedure TestInvalidDocumentText;
  procedure ExpectParseError(const AXml, AExpectedFragment, ALabel: string);
  var
    LRaised: Boolean;
    LDoc: TXmlDocument;
  begin
    LRaised := False;
    LDoc := nil;
    try
      try
        LDoc := TXmlDocument.Parse(AXml);
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
end;

procedure TestMisplacedDoctype;
  procedure ExpectParseError(const AXml, AExpectedFragment, ALabel: string);
  var
    LRaised: Boolean;
    LDoc: TXmlDocument;
  begin
    LRaised := False;
    LDoc := nil;
    try
      try
        LDoc := TXmlDocument.Parse(AXml);
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
end;

procedure TestMissingRootElement;
  procedure ExpectParseError(const AXml, AExpectedFragment, ALabel: string);
  var
    LRaised: Boolean;
    LDoc: TXmlDocument;
  begin
    LRaised := False;
    LDoc := nil;
    try
      try
        LDoc := TXmlDocument.Parse(AXml);
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
end;

procedure TestSelfClosingElement;
var
  LDoc: TXmlDocument;
  LChild: TXmlNode;
begin
  LDoc := TXmlDocument.Parse('<r><br/><hr/></r>');
  try
    CheckEqual(Int64(2), Int64(LDoc.Root.ChildCount), 'child count');
    LChild := LDoc.Root.FindChild('br');
    Check(LChild <> nil, 'br found');
    CheckEqual(Int64(0), Int64(LChild.ChildCount), 'br no children');
  finally
    LDoc.Free;
  end;
end;

procedure TestCommentNode;
var
  LDoc: TXmlDocument;
  LI: Integer;
  LFound: Boolean;
begin
  LDoc := TXmlDocument.Parse('<r><!-- hello --><a/></r>');
  try
    LFound := False;
    for LI := 0 to LDoc.Root.ChildCount - 1 do
      if LDoc.Root.Children[LI].Kind = xnkComment then
      begin
        CheckEqual(' hello ', LDoc.Root.Children[LI].Value, 'comment value');
        LFound := True;
      end;
    Check(LFound, 'comment found');
  finally
    LDoc.Free;
  end;
end;

procedure TestRejectsInvalidCommentPayload;
  procedure ExpectParseError(const AXml, AExpectedFragment, ALabel: string);
  var
    LRaised: Boolean;
    LDoc: TXmlDocument;
  begin
    LRaised := False;
    LDoc := nil;
    try
      try
        LDoc := TXmlDocument.Parse(AXml);
      except
        on E: EXmlError do
        begin
          LRaised := True;
          Check(Pos(AExpectedFragment, E.Message) > 0,
            ALabel + ' reports comment payload error');
          Check(E.Pos.Line > 0, ALabel + ' error line recorded');
          Check(E.Pos.Column > 0, ALabel + ' error column recorded');
        end;
      end;
      Check(LRaised, ALabel + ' raises EXmlError');
    finally
      LDoc.Free;
    end;
  end;
begin
  ExpectParseError('<root><!--alpha--omega--></root>',
    'comment text must not contain "--"',
    'comment with double hyphen payload');
  ExpectParseError('<root><!--alpha---></root>',
    'comment text must not end with "-"',
    'comment with trailing hyphen payload');
end;

procedure TestCDataNode;
var
  LDoc: TXmlDocument;
  LI: Integer;
  LFound: Boolean;
begin
  LDoc := TXmlDocument.Parse('<r><![CDATA[raw<>&data]]></r>');
  try
    LFound := False;
    for LI := 0 to LDoc.Root.ChildCount - 1 do
      if LDoc.Root.Children[LI].Kind = xnkCData then
      begin
        CheckEqual('raw<>&data', LDoc.Root.Children[LI].Value, 'cdata value');
        LFound := True;
      end;
    Check(LFound, 'cdata found');
  finally
    LDoc.Free;
  end;
end;

procedure TestPINode;
var
  LDoc: TXmlDocument;
  LI: Integer;
  LFound: Boolean;
begin
  LDoc := TXmlDocument.Parse('<?target data?><r/>');
  try
    LFound := False;
    for LI := 0 to LDoc.ChildCount - 1 do
      if LDoc.Children[LI].Kind = xnkPI then
      begin
        CheckEqual('target', LDoc.Children[LI].Name.Local, 'pi target');
        CheckEqual('data', LDoc.Children[LI].Value, 'pi data');
        LFound := True;
      end;
    Check(LFound, 'pi found');
  finally
    LDoc.Free;
  end;
end;

procedure TestNamespacedAttributes;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<r xmlns:ns="urn:x" ns:attr="val">x</r>');
  try
    CheckEqual('val', LDoc.Root.GetAttr('attr'), 'ns attr');
  finally
    LDoc.Free;
  end;
end;

procedure TestDeepNesting;
var
  LXml: string;
  LI: Integer;
  LDoc: TXmlDocument;
  LNode: TXmlNode;
begin
  LXml := '';
  for LI := 1 to 20 do
    LXml := LXml + '<d' + IntToStr(LI) + '>';
  LXml := LXml + 'deep';
  for LI := 20 downto 1 do
    LXml := LXml + '</d' + IntToStr(LI) + '>';
  LDoc := TXmlDocument.Parse(LXml);
  try
    Check(LDoc.Root <> nil, 'root');
    CheckEqual('d1', LDoc.Root.Name.Local, 'root name');
    { Navigate to deepest }
    LNode := LDoc.Root;
    for LI := 2 to 20 do
    begin
      LNode := LNode.FindChild('d' + IntToStr(LI));
      Check(LNode <> nil, 'd' + IntToStr(LI) + ' found');
    end;
    CheckEqual('deep', LNode.Text, 'deep text');
  finally
    LDoc.Free;
  end;
end;

procedure TestLargeDocument;
var
  LXml: string;
  LI: Integer;
  LDoc: TXmlDocument;
  LItems: TXmlNodeArray;
begin
  LXml := '<root>';
  for LI := 1 to 200 do
    LXml := LXml + '<item id="' + IntToStr(LI) + '">val' + IntToStr(LI) + '</item>';
  LXml := LXml + '</root>';
  LDoc := TXmlDocument.Parse(LXml);
  try
    LItems := LDoc.Root.FindChildren('item');
    CheckEqual(Int64(200), Int64(Length(LItems)), 'item count');
    CheckEqual('1', LItems[0].GetAttr('id'), 'first id');
    CheckEqual('val1', LItems[0].Text, 'first text');
    CheckEqual('200', LItems[199].GetAttr('id'), 'last id');
    CheckEqual('val200', LItems[199].Text, 'last text');
  finally
    LDoc.Free;
  end;
end;

procedure TestParentLink;
var
  LDoc: TXmlDocument;
  LChild: TXmlNode;
begin
  LDoc := TXmlDocument.Parse('<a><b>x</b></a>');
  try
    LChild := LDoc.Root.FindChild('b');
    Check(LChild <> nil, 'b found');
    Check(LChild.Parent = LDoc.Root, 'parent is root');
    Check(LDoc.Root.Parent = LDoc, 'root parent is doc');
  finally
    LDoc.Free;
  end;
end;

procedure TestNodeKinds;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<r/>');
  try
    Check(LDoc.Kind = xnkDocument, 'doc kind');
    Check(LDoc.Root.Kind = xnkElement, 'root kind');
  finally
    LDoc.Free;
  end;
end;

procedure TestMixedContent;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<p>Hello <b>world</b> end</p>');
  try
    { p has: text("Hello "), element(b), text(" end") }
    CheckEqual(Int64(3), Int64(LDoc.Root.ChildCount), 'child count');
    Check(LDoc.Root.Children[0].Kind = xnkText, 'text node');
    Check(LDoc.Root.Children[1].Kind = xnkElement, 'element node');
    Check(LDoc.Root.Children[2].Kind = xnkText, 'text node 2');
  finally
    LDoc.Free;
  end;
end;

procedure TestSelectPathDeep;
var
  LDoc: TXmlDocument;
  LNodes: TXmlNodeArray;
begin
  LDoc := TXmlDocument.Parse('<a><b><c><d>found</d></c></b></a>');
  try
    LNodes := LDoc.SelectPath('/a/b/c/d');
    CheckEqual(Int64(1), Int64(Length(LNodes)), 'deep path count');
    CheckEqual('found', LNodes[0].Text, 'deep path text');
  finally
    LDoc.Free;
  end;
end;

procedure TestGetAttrWithPrefix;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<r xml:lang="en" id="1">x</r>');
  try
    CheckEqual('en', LDoc.Root.GetAttr('lang'), 'prefixed attr');
    CheckEqual('1', LDoc.Root.GetAttr('id'), 'plain attr');
  finally
    LDoc.Free;
  end;
end;

procedure TestEmptyRoot;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<empty/>');
  try
    Check(LDoc.Root <> nil, 'root not nil');
    CheckEqual('empty', LDoc.Root.Name.Local, 'root name');
    CheckEqual(Int64(0), Int64(LDoc.Root.ChildCount), 'no children');
    CheckEqual('', LDoc.Root.Text, 'empty text');
  finally
    LDoc.Free;
  end;
end;


{ === Additional SelectPath & ChildCount Tests === }

procedure TestSelectPathEmpty;
var
  LDoc: TXmlDocument;
  LNodes: TXmlNodeArray;
begin
  LDoc := TXmlDocument.Parse('<root><a/></root>');
  try
    LNodes := LDoc.SelectPath('');
    CheckEqual(Int64(0), Int64(Length(LNodes)), 'empty path returns nothing');
  finally
    LDoc.Free;
  end;
end;

procedure TestSelectPathNonExistentDeep;
var
  LDoc: TXmlDocument;
  LNodes: TXmlNodeArray;
begin
  LDoc := TXmlDocument.Parse('<root><a><b>x</b></a></root>');
  try
    LNodes := LDoc.SelectPath('/root/a/b/c/d/e');
    CheckEqual(Int64(0), Int64(Length(LNodes)), 'deep non-existent path');
  finally
    LDoc.Free;
  end;
end;

procedure TestSelectPathMultiDepth;
var
  LDoc: TXmlDocument;
  LNodes: TXmlNodeArray;
begin
  LDoc := TXmlDocument.Parse(
    '<root><level1><level2><level3><target>found</target></level3></level2></level1></root>');
  try
    LNodes := LDoc.SelectPath('/root/level1/level2/level3/target');
    CheckEqual(Int64(1), Int64(Length(LNodes)), 'multi depth count');
    CheckEqual('found', LNodes[0].Text, 'multi depth text');
  finally
    LDoc.Free;
  end;
end;

procedure TestChildCountVaried;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<r><a/><b/><c/><d/><e/></r>');
  try
    CheckEqual(Int64(5), Int64(LDoc.Root.ChildCount), '5 children');
  finally
    LDoc.Free;
  end;
end;

procedure TestChildCountZero;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.Parse('<empty/>');
  try
    CheckEqual(Int64(0), Int64(LDoc.Root.ChildCount), 'zero children');
  finally
    LDoc.Free;
  end;
end;

{ === Main === }

begin
  T := TTestRunner.Create('XML DOM');
  T.Run('ParseSimple', @TestParseSimple);
  T.Run('ParseNested', @TestParseNested);
  T.Run('ParseAttributes', @TestParseAttributes);
  T.Run('ParseRejectsDuplicateAttributes', @TestParseRejectsDuplicateAttributes);
  T.Run('ParseRejectsDuplicateExpandedAttributes',
    @TestParseRejectsDuplicateExpandedAttributes);
  T.Run('ParseAllowsDistinctExpandedAttributes',
    @TestParseAllowsDistinctExpandedAttributes);
  T.Run('ParseRejectsUnboundNamespacePrefix',
    @TestParseRejectsUnboundNamespacePrefix);
  T.Run('ParseRejectsRawLessThanInAttributeValue',
    @TestParseRejectsRawLessThanInAttributeValue);
  T.Run('FindChild', @TestFindChild);
  T.Run('FindChildren', @TestFindChildren);
  T.Run('TextConcat', @TestTextConcat);
  T.Run('TextRecursive', @TestTextRecursive);
  T.Run('SelectPathSimple', @TestSelectPathSimple);
  T.Run('SelectPathMultiple', @TestSelectPathMultiple);
  T.Run('SelectPathNoMatch', @TestSelectPathNoMatch);
  T.Run('SelectPathRootMismatch', @TestSelectPathRootMismatch);
  T.Run('EmptyDocument', @TestEmptyDocument);
  T.Run('DocumentWhitespace', @TestDocumentWhitespace);
  T.Run('PreRootDoctype', @TestPreRootDoctype);
  T.Run('InvalidDocumentText', @TestInvalidDocumentText);
  T.Run('MisplacedDoctype', @TestMisplacedDoctype);
  T.Run('MissingRootElement', @TestMissingRootElement);
  T.Run('SelfClosingElement', @TestSelfClosingElement);
  T.Run('CommentNode', @TestCommentNode);
  T.Run('RejectsInvalidCommentPayload', @TestRejectsInvalidCommentPayload);
  T.Run('CDataNode', @TestCDataNode);
  T.Run('PINode', @TestPINode);
  T.Run('NamespacedAttributes', @TestNamespacedAttributes);
  T.Run('DeepNesting', @TestDeepNesting);
  T.Run('LargeDocument', @TestLargeDocument);
  T.Run('ParentLink', @TestParentLink);
  T.Run('NodeKinds', @TestNodeKinds);
  T.Run('MixedContent', @TestMixedContent);
  T.Run('SelectPathDeep', @TestSelectPathDeep);
  T.Run('GetAttrWithPrefix', @TestGetAttrWithPrefix);
  T.Run('EmptyRoot', @TestEmptyRoot);
  T.Run('SelectPathEmpty', @TestSelectPathEmpty);
  T.Run('SelectPathNonExistentDeep', @TestSelectPathNonExistentDeep);
  T.Run('SelectPathMultiDepth', @TestSelectPathMultiDepth);
  T.Run('ChildCountVaried', @TestChildCountVaried);
  T.Run('ChildCountZero', @TestChildCountZero);
  T.Summary;
end.
