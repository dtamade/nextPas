program test_xml_roundtrip;
{**
 * @desc XML roundtrip 测试套件：Parse -> Stringify -> Re-parse -> Compare DOM。
 *       验证 IXmlDocument.Stringify 输出可被再次解析并保持 DOM 结构一致。
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.view,
  nextpas.core.mem.default,
  nextpas.core.mem.intf,
  nextpas.core.xml,
  nextpas.core.xml.base,
  nextpas.core.xml.dom,
  nextpas.core.testing;

var
  T: TTestRunner;

{ === Helper: parse twice, compare root structure === }

procedure RoundtripAndCompare(const AXml, ALabel: string;
  AExpectedRootName: string; AExpectedChildCount: Integer;
  AExpectedText: string);
var
  LDoc1, LDoc2: IXmlDocument;
  LStr: string;
begin
  { First parse }
  LDoc1 := XmlParseDoc(AXml);
  Check(not LDoc1.HasError, ALabel + ': first parse has no error');
  Check(LDoc1.Root.IsAssigned, ALabel + ': first parse root assigned');
  CheckEqual(AExpectedRootName, LDoc1.Root.Name.Local, ALabel + ': root name');

  { Stringify and re-parse }
  LStr := LDoc1.Stringify;
  Check(LStr <> '', ALabel + ': stringify non-empty');

  LDoc2 := XmlParseDoc(LStr);
  Check(not LDoc2.HasError, ALabel + ': re-parse has no error');
  Check(LDoc2.Root.IsAssigned, ALabel + ': re-parse root assigned');

  { Compare DOM structure }
  CheckEqual(LDoc1.Root.Name.Local, LDoc2.Root.Name.Local,
    ALabel + ': root name roundtrip');
  CheckEqual(Int64(AExpectedChildCount), Int64(LDoc2.Root.ChildCount),
    ALabel + ': child count roundtrip');

  if AExpectedText <> '' then
    CheckEqual(AExpectedText, LDoc2.Root.Text, ALabel + ': text roundtrip');
end;

{ === Test 1: Basic roundtrip === }

procedure TestBasicRoundtrip;
begin
  RoundtripAndCompare(
    '<root><item>hello</item></root>',
    'basic',
    'root', 1, 'hello');
end;

{ === Test 2: Attributes roundtrip === }

procedure TestAttributesRoundtrip;
var
  LDoc1, LDoc2: IXmlDocument;
  LStr: string;
  LChild: TXmlNode;
begin
  LDoc1 := XmlParseDoc('<root id="1" name="test"><child/></root>');
  Check(not LDoc1.HasError, 'attrs: first parse ok');

  CheckEqual('1', LDoc1.Root.GetAttr('id'), 'attrs: id before');
  CheckEqual('test', LDoc1.Root.GetAttr('name'), 'attrs: name before');

  LStr := LDoc1.Stringify;
  LDoc2 := XmlParseDoc(LStr);
  Check(not LDoc2.HasError, 'attrs: re-parse ok');

  CheckEqual('root', LDoc2.Root.Name.Local, 'attrs: root name');
  CheckEqual('1', LDoc2.Root.GetAttr('id'), 'attrs: id roundtrip');
  CheckEqual('test', LDoc2.Root.GetAttr('name'), 'attrs: name roundtrip');

  LChild := LDoc2.Root.FindChild('child');
  Check(LChild.IsAssigned, 'attrs: child found after roundtrip');
end;

{ === Test 3: CDATA roundtrip === }

procedure TestCDataRoundtrip;
var
  LDoc1, LDoc2: IXmlDocument;
  LStr: string;
begin
  LDoc1 := XmlParseDoc('<root><![CDATA[<special>&chars]]></root>');
  Check(not LDoc1.HasError, 'cdata: first parse ok');
  Check(LDoc1.Root.IsAssigned, 'cdata: root assigned');

  { CDATA content should be preserved in DOM Text }
  CheckEqual('<special>&chars', LDoc1.Root.Text, 'cdata: text before');

  LStr := LDoc1.Stringify;
  LDoc2 := XmlParseDoc(LStr);
  Check(not LDoc2.HasError, 'cdata: re-parse ok');

  CheckEqual('<special>&chars', LDoc2.Root.Text, 'cdata: text roundtrip');
  CheckEqual(Int64(1), Int64(LDoc2.Root.ChildCount), 'cdata: child count');
end;

{ === Test 4: Comment roundtrip === }

procedure TestCommentRoundtrip;
var
  LDoc1, LDoc2: IXmlDocument;
  LStr: string;
  LChild0: TXmlNode;
begin
  LDoc1 := XmlParseDoc('<root><!-- comment --><item/></root>');
  Check(not LDoc1.HasError, 'comment: first parse ok');

  { Root has 2 children: comment + item }
  CheckEqual(Int64(2), Int64(LDoc1.Root.ChildCount), 'comment: child count before');

  LChild0 := LDoc1.Root.Child(0);
  CheckEqual(Int64(Ord(xnkComment)), Int64(Ord(LChild0.Kind)),
    'comment: first child is comment');
  CheckEqual(' comment ', LChild0.Value, 'comment: value before');

  LStr := LDoc1.Stringify;
  LDoc2 := XmlParseDoc(LStr);
  Check(not LDoc2.HasError, 'comment: re-parse ok');

  CheckEqual(Int64(2), Int64(LDoc2.Root.ChildCount), 'comment: child count roundtrip');

  LChild0 := LDoc2.Root.Child(0);
  CheckEqual(Int64(Ord(xnkComment)), Int64(Ord(LChild0.Kind)),
    'comment: first child is comment after roundtrip');
  CheckEqual(' comment ', LChild0.Value, 'comment: value roundtrip');
end;

{ === Test 5: Mixed content roundtrip === }

procedure TestMixedContentRoundtrip;
var
  LDoc1, LDoc2: IXmlDocument;
  LStr: string;
begin
  LDoc1 := XmlParseDoc('<root>text<child/>more</root>');
  Check(not LDoc1.HasError, 'mixed: first parse ok');
  Check(LDoc1.Root.IsAssigned, 'mixed: root assigned');

  { Text should concatenate text + child.Text + text }
  CheckEqual('textmore', LDoc1.Root.Text, 'mixed: text before');

  LStr := LDoc1.Stringify;
  LDoc2 := XmlParseDoc(LStr);
  Check(not LDoc2.HasError, 'mixed: re-parse ok');

  CheckEqual('textmore', LDoc2.Root.Text, 'mixed: text roundtrip');
  Check(LDoc2.Root.FindChild('child').IsAssigned, 'mixed: child found');
end;

{ === Test 6: Self-closing roundtrip === }

procedure TestSelfClosingRoundtrip;
var
  LDoc1, LDoc2: IXmlDocument;
  LStr: string;
begin
  LDoc1 := XmlParseDoc('<root><br/><hr/></root>');
  Check(not LDoc1.HasError, 'selfclose: first parse ok');

  CheckEqual(Int64(2), Int64(LDoc1.Root.ChildCount), 'selfclose: child count before');
  CheckEqual('br', LDoc1.Root.Child(0).Name.Local, 'selfclose: first child');
  CheckEqual('hr', LDoc1.Root.Child(1).Name.Local, 'selfclose: second child');

  LStr := LDoc1.Stringify;
  LDoc2 := XmlParseDoc(LStr);
  Check(not LDoc2.HasError, 'selfclose: re-parse ok');

  CheckEqual(Int64(2), Int64(LDoc2.Root.ChildCount), 'selfclose: child count roundtrip');
  CheckEqual('br', LDoc2.Root.Child(0).Name.Local, 'selfclose: first child roundtrip');
  CheckEqual('hr', LDoc2.Root.Child(1).Name.Local, 'selfclose: second child roundtrip');
end;

{ === Test 7: Namespace roundtrip === }

procedure TestNamespaceRoundtrip;
var
  LDoc1, LDoc2: IXmlDocument;
  LStr: string;
  LChild: TXmlNode;
begin
  LDoc1 := XmlParseDoc('<root xmlns:ns="http://example.com"><ns:item/></root>');
  Check(not LDoc1.HasError, 'ns: first parse ok');

  LChild := LDoc1.Root.Child(0);
  Check(LChild.IsAssigned, 'ns: child exists');
  CheckEqual('item', LChild.Name.Local, 'ns: child local name');
  CheckEqual('ns', LChild.Name.Prefix, 'ns: child prefix');

  LStr := LDoc1.Stringify;
  LDoc2 := XmlParseDoc(LStr);
  Check(not LDoc2.HasError, 'ns: re-parse ok');

  LChild := LDoc2.Root.Child(0);
  Check(LChild.IsAssigned, 'ns: child exists after roundtrip');
  CheckEqual('item', LChild.Name.Local, 'ns: child local name roundtrip');
  CheckEqual('ns', LChild.Name.Prefix, 'ns: child prefix roundtrip');
end;

{ === Test 8: Empty element roundtrip === }

procedure TestEmptyElementRoundtrip;
var
  LDoc1, LDoc2: IXmlDocument;
  LStr: string;
begin
  LDoc1 := XmlParseDoc('<root></root>');
  Check(not LDoc1.HasError, 'empty: first parse ok');
  CheckEqual('root', LDoc1.Root.Name.Local, 'empty: root name');
  CheckEqual(Int64(0), Int64(LDoc1.Root.ChildCount), 'empty: no children');

  LStr := LDoc1.Stringify;
  LDoc2 := XmlParseDoc(LStr);
  Check(not LDoc2.HasError, 'empty: re-parse ok');

  CheckEqual('root', LDoc2.Root.Name.Local, 'empty: root name roundtrip');
  CheckEqual(Int64(0), Int64(LDoc2.Root.ChildCount), 'empty: no children roundtrip');
end;

{ === Test 9: Deep nesting roundtrip === }

procedure TestDeepNestingRoundtrip;
const
  DEPTH = 10;
var
  LXml: string;
  LI: Integer;
  LDoc1, LDoc2: IXmlDocument;
  LStr: string;
  LNode1, LNode2: TXmlNode;
begin
  { Build 10-level nested XML: <n0><n1>...<n9>deep</n9>...</n1></n0> }
  LXml := '';
  for LI := 0 to DEPTH - 1 do
    LXml := LXml + '<n' + IntToStr(LI) + '>';
  LXml := LXml + 'deep';
  for LI := DEPTH - 1 downto 0 do
    LXml := LXml + '</n' + IntToStr(LI) + '>';

  LDoc1 := XmlParseDoc(LXml);
  Check(not LDoc1.HasError, 'deep: first parse ok');
  CheckEqual('n0', LDoc1.Root.Name.Local, 'deep: root name');

  { Navigate to the deepest node }
  LNode1 := LDoc1.Root;
  for LI := 1 to DEPTH - 1 do
  begin
    LNode1 := LNode1.Child(0);
    Check(LNode1.IsAssigned, 'deep: child at level ' + IntToStr(LI));
    CheckEqual('n' + IntToStr(LI), LNode1.Name.Local,
      'deep: name at level ' + IntToStr(LI));
  end;
  CheckEqual('deep', LNode1.Text, 'deep: deepest text');

  LStr := LDoc1.Stringify;
  LDoc2 := XmlParseDoc(LStr);
  Check(not LDoc2.HasError, 'deep: re-parse ok');
  CheckEqual('n0', LDoc2.Root.Name.Local, 'deep: root name roundtrip');

  { Verify same depth in roundtripped doc }
  LNode2 := LDoc2.Root;
  for LI := 1 to DEPTH - 1 do
  begin
    LNode2 := LNode2.Child(0);
    Check(LNode2.IsAssigned, 'deep: roundtrip child at level ' + IntToStr(LI));
    CheckEqual('n' + IntToStr(LI), LNode2.Name.Local,
      'deep: roundtrip name at level ' + IntToStr(LI));
  end;
  CheckEqual('deep', LNode2.Text, 'deep: roundtrip deepest text');
end;

{ === Test 10: Multiple children roundtrip === }

procedure TestMultipleChildrenRoundtrip;
var
  LDoc1, LDoc2: IXmlDocument;
  LStr: string;
  LI: Integer;
begin
  LDoc1 := XmlParseDoc('<root><a/><b/><c/></root>');
  Check(not LDoc1.HasError, 'multi: first parse ok');

  CheckEqual(Int64(3), Int64(LDoc1.Root.ChildCount), 'multi: child count before');
  CheckEqual('a', LDoc1.Root.Child(0).Name.Local, 'multi: child 0');
  CheckEqual('b', LDoc1.Root.Child(1).Name.Local, 'multi: child 1');
  CheckEqual('c', LDoc1.Root.Child(2).Name.Local, 'multi: child 2');

  LStr := LDoc1.Stringify;
  LDoc2 := XmlParseDoc(LStr);
  Check(not LDoc2.HasError, 'multi: re-parse ok');

  CheckEqual(Int64(3), Int64(LDoc2.Root.ChildCount), 'multi: child count roundtrip');
  for LI := 0 to 2 do
    CheckEqual(LDoc1.Root.Child(LI).Name.Local,
      LDoc2.Root.Child(LI).Name.Local,
      'multi: child ' + IntToStr(LI) + ' name roundtrip');
end;

begin
  T := TTestRunner.Create('XML Roundtrip');
  T.Run('BasicRoundtrip', @TestBasicRoundtrip);
  T.Run('AttributesRoundtrip', @TestAttributesRoundtrip);
  T.Run('CDataRoundtrip', @TestCDataRoundtrip);
  T.Run('CommentRoundtrip', @TestCommentRoundtrip);
  T.Run('MixedContentRoundtrip', @TestMixedContentRoundtrip);
  T.Run('SelfClosingRoundtrip', @TestSelfClosingRoundtrip);
  T.Run('NamespaceRoundtrip', @TestNamespaceRoundtrip);
  T.Run('EmptyElementRoundtrip', @TestEmptyElementRoundtrip);
  T.Run('DeepNestingRoundtrip', @TestDeepNestingRoundtrip);
  T.Run('MultipleChildrenRoundtrip', @TestMultipleChildrenRoundtrip);
  T.Summary;
end.
