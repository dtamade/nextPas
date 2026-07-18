program test_xml_edge_cases;
{**
 * @desc XML edge-case suite for empty/malformed/boundary inputs and
 *       entity/encoding extremes via the nextpas.core.xml facade.
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
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
