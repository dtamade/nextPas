program test_xml_edge_cases;
{**
 * @desc XML edge-case suite for empty/malformed/boundary inputs and
 *       entity/encoding extremes via the nextpas.core.xml facade.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.mem.default,
  nextpas.core.test,
  nextpas.core.xml,
  nextpas.core.xml.base;

var
  T: TTestSuite;

procedure TestEmptyInputTryParse;
var
  LDoc: TXmlDocument;
begin
  { Empty input currently parses as a document shell with no root
    (root is only required after PI/comment/doctype/xml-decl tokens). }
  LDoc := TXmlDocument.None;
  Check(TryXmlParse('', LDoc), 'empty input try parse succeeds as empty doc');
  try
    Check(LDoc.IsAssigned, 'empty input yields assigned document shell');
    Check(not LDoc.Root.IsAssigned, 'empty input has no root element');
  finally
    LDoc.Free;
  end;
end;

procedure TestWhitespaceOnlyTryParse;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.None;
  Check(TryXmlParse('   ' + #9 + #10, LDoc),
    'whitespace-only document text is accepted outside root');
  try
    Check(LDoc.IsAssigned, 'whitespace-only yields assigned document shell');
    Check(not LDoc.Root.IsAssigned, 'whitespace-only has no root element');
  finally
    LDoc.Free;
  end;
end;

procedure TestEmptyElementRoundTripText;
var
  LDoc: TXmlDocument;
begin
  LDoc := XmlParse('<empty/>');
  try
    Check(LDoc.Root.IsAssigned, 'empty element has root');
    CheckEqual('empty', LDoc.Root.Name.Local, 'empty element name');
    CheckEqual('', LDoc.Root.Text, 'empty element text is empty');
    CheckEqual(Int64(0), Int64(LDoc.Root.ChildCount), 'empty element has no children');
  finally
    LDoc.Free;
  end;
end;

procedure TestDeepNesting;
var
  LXml: string;
  LDoc: TXmlDocument;
  LNode: TXmlNode;
  I: Integer;
begin
  LXml := '';
  for I := 1 to 32 do
    LXml := LXml + '<n' + IntToStr(I) + '>';
  LXml := LXml + 'leaf';
  for I := 32 downto 1 do
    LXml := LXml + '</n' + IntToStr(I) + '>';

  LDoc := XmlParse(LXml);
  try
    LNode := LDoc.Root;
    for I := 1 to 31 do
    begin
      Check(LNode.IsAssigned, 'depth node assigned');
      CheckEqual('n' + IntToStr(I), LNode.Name.Local, 'depth name');
      CheckEqual(Int64(1), Int64(LNode.ChildCount), 'single child');
      LNode := LNode.FindChild('n' + IntToStr(I + 1));
    end;
    CheckEqual('leaf', LNode.Text, 'deep leaf text');
  finally
    LDoc.Free;
  end;
end;

procedure TestLargeTextPayload;
var
  LBody, LXml: string;
  LDoc: TXmlDocument;
  I: Integer;
begin
  SetLength(LBody, 4096);
  for I := 1 to Length(LBody) do
    LBody[I] := Chr(Ord('a') + ((I - 1) mod 26));
  LXml := '<root>' + LBody + '</root>';
  LDoc := XmlParse(LXml);
  try
    CheckEqual(Int64(Length(LBody)), Int64(Length(LDoc.Root.Text)), 'large text length');
    CheckEqual(LBody, LDoc.Root.Text, 'large text content');
  finally
    LDoc.Free;
  end;
end;

procedure TestMalformedUnclosedRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    XmlParse('<root><child>');
  except
    on E: EXmlError do
      LRaised := True;
  end;
  Check(LRaised, 'unclosed tags raise EXmlError');
end;

procedure TestMalformedUnmatchedEndRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    XmlParse('<root></other>');
  except
    on E: EXmlError do
      LRaised := True;
  end;
  Check(LRaised, 'mismatched end tag raises EXmlError');
end;

procedure TestMultipleRootsRejected;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.None;
  Check(not TryXmlParse('<a/><b/>', LDoc), 'multiple roots rejected');
  Check(not LDoc.IsAssigned, 'multiple roots leave doc unassigned');
end;

procedure TestEntityRoundTrip;
begin
  CheckEqual('&<>"''', XmlDecodeEntities('&amp;&lt;&gt;&quot;&apos;'),
    'named entities decode');
  CheckEqual('&amp;&lt;&gt;', XmlEncodeText('&<>'), 'text encode escapes markup');
  CheckEqual('&quot;x&quot;', XmlEncodeAttr('"x"'), 'attr encode escapes quotes');
end;

procedure TestNumericEntityDecode;
begin
  CheckEqual(Chr(65), XmlDecodeEntities('&#65;'), 'decimal numeric entity');
  CheckEqual(Chr(66), XmlDecodeEntities('&#x42;'), 'hex numeric entity');
end;

procedure TestCDataPreservesMarkupChars;
var
  LDoc: TXmlDocument;
begin
  LDoc := XmlParse('<r><![CDATA[raw<>&data]]></r>');
  try
    CheckEqual('raw<>&data', LDoc.Root.Text, 'CDATA preserves markup chars');
  finally
    LDoc.Free;
  end;
end;

{ Preallocated builder: naive concat is O(n^2) at attack-scale depths. }
function BuildNestedXml(const ADepth: Integer; const ALeaf: string): string;
var
  I, LBase: Integer;
begin
  Result := '';
  SetLength(Result, ADepth * 7 + Length(ALeaf));
  for I := 0 to ADepth - 1 do
    Move(PChar('<a>')^, Result[1 + I * 3], 3);
  LBase := 1 + ADepth * 3;
  if Length(ALeaf) > 0 then
    Move(PChar(ALeaf)^, Result[LBase], Length(ALeaf));
  LBase := LBase + Length(ALeaf);
  for I := 0 to ADepth - 1 do
    Move(PChar('</a>')^, Result[LBase + I * 4], 4);
end;

procedure TestNestingDepthAtLimitParses;
var
  LDoc: TXmlDocument;
begin
  LDoc := TXmlDocument.None;
  Check(TryXmlParse(BuildNestedXml(XML_MAX_NESTING_DEPTH, 'leaf'), LDoc),
    'depth at XML_MAX_NESTING_DEPTH parses');
  try
    Check(LDoc.Root.IsAssigned, 'at-limit doc has root');
    CheckEqual('leaf', LDoc.Root.Text, 'at-limit leaf text reachable');
  finally
    LDoc.Free;
  end;
end;

procedure TestNestingDepthOverLimitRejected;
var
  LDoc: TXmlDocument;
  LRaised: Boolean;
begin
  LDoc := TXmlDocument.None;
  Check(not TryXmlParse(BuildNestedXml(XML_MAX_NESTING_DEPTH + 1, 'x'), LDoc),
    'depth over limit is rejected');
  Check(not LDoc.IsAssigned, 'over-limit doc stays unassigned');
  LRaised := False;
  try
    XmlParse(BuildNestedXml(XML_MAX_NESTING_DEPTH + 1, 'x'));
  except
    on E: EXmlError do
      LRaised := True;
  end;
  Check(LRaised, 'over-limit XmlParse raises EXmlError');
end;

procedure TestNestingDepthEmptyElementCounts;
var
  LDoc: TXmlDocument;
begin
  { <b/> 是树节点，深度按父级+1 计：满深度下再挂空元素必须拒绝。 }
  LDoc := TXmlDocument.None;
  Check(not TryXmlParse(BuildNestedXml(XML_MAX_NESTING_DEPTH, '<b/>'), LDoc),
    'empty element beyond limit is rejected');
  Check(not LDoc.IsAssigned, 'empty-element over-limit doc stays unassigned');
  LDoc := TXmlDocument.None;
  Check(TryXmlParse(BuildNestedXml(XML_MAX_NESTING_DEPTH - 1, '<b/>'), LDoc),
    'empty element at limit parses');
  LDoc.Free;
end;

procedure TestNestingDepthAttackFailsFast;
var
  LDoc: TXmlDocument;
begin
  { 回归：200k 深文档曾 parse 通过、Root.Text 递归 SIGSEGV。 }
  LDoc := TXmlDocument.None;
  Check(not TryXmlParse(BuildNestedXml(200000, 'x'), LDoc),
    'attack-scale deep document fails fast');
  Check(not LDoc.IsAssigned, 'attack-scale doc stays unassigned');
end;

procedure TestEmptyInputTokenize;
var
  LToks: TXmlTokenArray;
begin
  LToks := XmlTokenize('');
  CheckEqual(Int64(0), Int64(Length(LToks)), 'empty input yields zero tokens');
end;

procedure TestSelfClosingWithAttrs;
var
  LDoc: TXmlDocument;
begin
  LDoc := XmlParse('<item id="42" flag="true"/>');
  try
    CheckEqual('item', LDoc.Root.Name.Local, 'self-closing name');
    CheckEqual('42', LDoc.Root.GetAttr('id'), 'id attr');
    CheckEqual('true', LDoc.Root.GetAttr('flag'), 'flag attr');
  finally
    LDoc.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.xml.edge_cases');
  T.Test('empty input try parse', @TestEmptyInputTryParse);
  T.Test('whitespace-only try parse', @TestWhitespaceOnlyTryParse);
  T.Test('empty element round trip', @TestEmptyElementRoundTripText);
  T.Test('deep nesting', @TestDeepNesting);
  T.Test('nesting depth at limit parses', @TestNestingDepthAtLimitParses);
  T.Test('nesting depth over limit rejected', @TestNestingDepthOverLimitRejected);
  T.Test('nesting depth counts empty elements', @TestNestingDepthEmptyElementCounts);
  T.Test('nesting depth attack fails fast', @TestNestingDepthAttackFailsFast);
  T.Test('large text payload', @TestLargeTextPayload);
  T.Test('malformed unclosed raises', @TestMalformedUnclosedRaises);
  T.Test('malformed unmatched end raises', @TestMalformedUnmatchedEndRaises);
  T.Test('multiple roots rejected', @TestMultipleRootsRejected);
  T.Test('entity round trip', @TestEntityRoundTrip);
  T.Test('numeric entity decode', @TestNumericEntityDecode);
  T.Test('CDATA preserves markup', @TestCDataPreservesMarkupChars);
  T.Test('empty input tokenize', @TestEmptyInputTokenize);
  T.Test('self-closing with attrs', @TestSelfClosingWithAttrs);
  if not T.Run then Halt(1);
end.
