program test_xml_writer;
{**
 * @desc XML Writer 测试套件：15+ 测试覆盖输出、格式化、转义等场景。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.xml.base,
  nextpas.core.xml.reader,
  nextpas.core.xml.writer;

var
  T: TTestRunner;

{ === Tests === }

procedure TestBasicElement;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LW.Text('hello');
    LW.EndElement('root');
    CheckEqual('<root>hello</root>', LW.ToString, 'basic element');
  finally
    LW.Free;
  end;
end;

procedure TestCompactNested;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('a');
    LW.StartElement('b');
    LW.Text('x');
    LW.EndElement('b');
    LW.EndElement('a');
    CheckEqual('<a><b>x</b></a>', LW.ToString, 'compact nested');
  finally
    LW.Free;
  end;
end;

procedure TestPrettyPrint;
var
  LW: TXmlWriter;
  LExpected: string;
begin
  LW := TXmlWriter.Create(True, '  ');
  try
    LW.StartElement('root');
    LW.StartElement('child');
    LW.Text('value');
    LW.EndElement('child');
    LW.EndElement('root');
    LExpected := '<root>' + #10 + '  <child>value</child>' + #10 + '</root>';
    CheckEqual(LExpected, LW.ToString, 'pretty print');
  finally
    LW.Free;
  end;
end;

procedure TestPrettyDeepNesting;
var
  LW: TXmlWriter;
  LExpected: string;
begin
  LW := TXmlWriter.Create(True, '  ');
  try
    LW.StartElement('a');
    LW.StartElement('b');
    LW.StartElement('c');
    LW.Text('deep');
    LW.EndElement('c');
    LW.EndElement('b');
    LW.EndElement('a');
    LExpected := '<a>' + #10 + '  <b>' + #10 + '    <c>deep</c>' + #10 + '  </b>' + #10 + '</a>';
    CheckEqual(LExpected, LW.ToString, 'deep nesting');
  finally
    LW.Free;
  end;
end;

procedure TestAttributeEscape;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('a');
    LW.Attribute('v', 'x<y&"z');
    LW.EndElement('a');
    CheckEqual('<a v="x&lt;y&amp;&quot;z"/>', LW.ToString, 'attr escape');
  finally
    LW.Free;
  end;
end;

procedure TestNamespaceDecl;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LW.NamespaceDecl('ns', 'http://example.com');
    LW.EndElement('root');
    CheckEqual('<root xmlns:ns="http://example.com"/>', LW.ToString, 'ns decl');
  finally
    LW.Free;
  end;
end;

procedure TestDefaultNamespaceDecl;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LW.NamespaceDecl('', 'http://default.ns');
    LW.Text('x');
    LW.EndElement('root');
    CheckEqual('<root xmlns="http://default.ns">x</root>', LW.ToString, 'default ns');
  finally
    LW.Free;
  end;
end;

procedure TestCDataOutput;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('r');
    LW.CData('<not>&markup');
    LW.EndElement('r');
    CheckEqual('<r><![CDATA[<not>&markup]]></r>', LW.ToString, 'cdata');
  finally
    LW.Free;
  end;
end;

procedure TestCommentOutput;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.Comment(' hello ');
    CheckEqual('<!-- hello -->', LW.ToString, 'comment');
  finally
    LW.Free;
  end;
end;

procedure TestPIOutput;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.PI('target', 'data here');
    CheckEqual('<?target data here?>', LW.ToString, 'pi');
  finally
    LW.Free;
  end;
end;

procedure TestPINoData;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.PI('noop', '');
    CheckEqual('<?noop?>', LW.ToString, 'pi no data');
  finally
    LW.Free;
  end;
end;

procedure TestEmptyElement;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.EmptyElement('br');
    CheckEqual('<br/>', LW.ToString, 'empty element');
  finally
    LW.Free;
  end;
end;

procedure TestEndElementCollapsesEmpty;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('item');
    LW.Attribute('id', '1');
    LW.EndElement('item');
    CheckEqual('<item id="1"/>', LW.ToString, 'collapse empty');
  finally
    LW.Free;
  end;
end;

procedure TestEndElementRejectsMismatchedName;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LRaised := False;
    try
      LW.EndElement('child');
      Fail('mismatched closing name must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'mismatched closing name raises EArgumentError');
  finally
    LW.Free;
  end;
end;

procedure TestEndElementRejectsUnexpectedClose;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.EndElement('root');
      Fail('closing without an open element must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'unexpected closing name raises EArgumentError');
  finally
    LW.Free;
  end;
end;

procedure TestXmlDecl;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.WriteXmlDecl;
    LW.StartElement('r');
    LW.EndElement('r');
    CheckEqual('<?xml version="1.0" encoding="UTF-8"?><r/>', LW.ToString, 'xml decl');
  finally
    LW.Free;
  end;
end;

procedure TestXmlDeclPretty;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(True);
  try
    LW.WriteXmlDecl('1.0', 'UTF-8');
    LW.StartElement('r');
    LW.EndElement('r');
    CheckEqual('<?xml version="1.0" encoding="UTF-8"?>' + #10 + '<r/>', LW.ToString, 'xml decl pretty');
  finally
    LW.Free;
  end;
end;

procedure TestTextEscape;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('r');
    LW.Text('a<b>c&d');
    LW.EndElement('r');
    CheckEqual('<r>a&lt;b&gt;c&amp;d</r>', LW.ToString, 'text escape');
  finally
    LW.Free;
  end;
end;

procedure TestPrefixedElement;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('ns', 'root');
    LW.NamespaceDecl('ns', 'urn:x');
    LW.EndElement('ns:root');
    CheckEqual('<ns:root xmlns:ns="urn:x"/>', LW.ToString, 'prefixed element');
  finally
    LW.Free;
  end;
end;

procedure TestRawOutput;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.Raw('<!-- raw -->');
    CheckEqual('<!-- raw -->', LW.ToString, 'raw');
  finally
    LW.Free;
  end;
end;

procedure TestClear;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('a');
    LW.EndElement('a');
    LW.Clear;
    LW.StartElement('b');
    LW.EndElement('b');
    CheckEqual('<b/>', LW.ToString, 'clear');
  finally
    LW.Free;
  end;
end;

procedure TestRoundTrip;
var
  LW: TXmlWriter;
  LXml: string;
  LReader: TXmlReader;
  LTok: TXmlToken;
  LToks1, LToks2: TXmlTokenArray;
  LCount, LCap, LI: Integer;
begin
  { Build XML with writer }
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LW.Attribute('id', '1');
    LW.StartElement('child');
    LW.Text('hello & world');
    LW.EndElement('child');
    LW.EmptyElement('br');
    LW.EndElement('root');
    LXml := LW.ToString;
  finally
    LW.Free;
  end;

  { Parse it back }
  LReader := TXmlReader.Create(LXml);
  try
    LCount := 0;
    LCap := 16;
    SetLength(LToks1, LCap);
    while LReader.Next(LTok) do
    begin
      if LCount >= LCap then begin LCap := LCap * 2; SetLength(LToks1, LCap); end;
      LToks1[LCount] := LTok;
      Inc(LCount);
    end;
    SetLength(LToks1, LCount);
    Check(not LReader.HasError, 'no parse error: ' + LReader.GetError);
  finally
    LReader.Free;
  end;

  { Verify structure }
  CheckEqual(Int64(6), Int64(Length(LToks1)), 'roundtrip token count');
  Check(LToks1[0].Kind = xtkStartElement, 'rt root start');
  CheckEqual('root', LToks1[0].Name.Local, 'rt root name');
  CheckEqual('1', LToks1[0].Attributes[0].Value, 'rt root attr');
  Check(LToks1[1].Kind = xtkStartElement, 'rt child start');
  Check(LToks1[2].Kind = xtkText, 'rt text');
  CheckEqual('hello & world', LToks1[2].Value, 'rt text value');
  Check(LToks1[3].Kind = xtkEndElement, 'rt child end');
  Check(LToks1[4].Kind = xtkEmptyElement, 'rt br');
  Check(LToks1[5].Kind = xtkEndElement, 'rt root end');
end;

procedure TestMultipleAttributes;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('div');
    LW.Attribute('id', 'main');
    LW.Attribute('class', 'big');
    LW.Text('x');
    LW.EndElement('div');
    CheckEqual('<div id="main" class="big">x</div>', LW.ToString, 'multi attrs');
  finally
    LW.Free;
  end;
end;


{ === Additional Coverage Tests === }

procedure TestNamespaceDeclMultiple;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LW.NamespaceDecl('a', 'urn:a');
    LW.NamespaceDecl('b', 'urn:b');
    LW.EndElement('root');
    CheckEqual('<root xmlns:a="urn:a" xmlns:b="urn:b"/>', LW.ToString, 'multi ns decl');
  finally
    LW.Free;
  end;
end;

procedure TestRawUnescaped;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('r');
    LW.Text('before');
    LW.EndElement('r');
    LW.Raw('<custom a="b">raw & unescaped</custom>');
    CheckEqual('<r>before</r><custom a="b">raw & unescaped</custom>', LW.ToString, 'raw unescaped');
  finally
    LW.Free;
  end;
end;

procedure TestClearResetsCompletely;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(True, '  ');
  try
    LW.StartElement('deep');
    LW.StartElement('nested');
    LW.Text('x');
    LW.EndElement('nested');
    LW.EndElement('deep');
    LW.Clear;
    { After clear, depth should be 0 and output empty }
    LW.StartElement('fresh');
    LW.EndElement('fresh');
    CheckEqual('<fresh/>', LW.ToString, 'clear resets depth');
  finally
    LW.Free;
  end;
end;

procedure TestConsecutiveStartEndDepth;
var
  LW: TXmlWriter;
  LExpected: string;
begin
  LW := TXmlWriter.Create(True, '  ');
  try
    LW.StartElement('a');
    LW.StartElement('b');
    LW.StartElement('c');
    LW.Text('leaf');
    LW.EndElement('c');
    LW.EndElement('b');
    LW.StartElement('d');
    LW.Text('sibling');
    LW.EndElement('d');
    LW.EndElement('a');
    LExpected := '<a>' + #10 +
                 '  <b>' + #10 +
                 '    <c>leaf</c>' + #10 +
                 '  </b>' + #10 +
                 '  <d>sibling</d>' + #10 +
                 '</a>';
    CheckEqual(LExpected, LW.ToString, 'depth tracking');
  finally
    LW.Free;
  end;
end;

{ === Main === }

begin
  T := TTestRunner.Create('XML Writer');
  T.Run('BasicElement', @TestBasicElement);
  T.Run('CompactNested', @TestCompactNested);
  T.Run('PrettyPrint', @TestPrettyPrint);
  T.Run('PrettyDeepNesting', @TestPrettyDeepNesting);
  T.Run('AttributeEscape', @TestAttributeEscape);
  T.Run('NamespaceDecl', @TestNamespaceDecl);
  T.Run('DefaultNamespaceDecl', @TestDefaultNamespaceDecl);
  T.Run('CDataOutput', @TestCDataOutput);
  T.Run('CommentOutput', @TestCommentOutput);
  T.Run('PIOutput', @TestPIOutput);
  T.Run('PINoData', @TestPINoData);
  T.Run('EmptyElement', @TestEmptyElement);
  T.Run('EndElementCollapsesEmpty', @TestEndElementCollapsesEmpty);
  T.Run('EndElementRejectsMismatchedName', @TestEndElementRejectsMismatchedName);
  T.Run('EndElementRejectsUnexpectedClose', @TestEndElementRejectsUnexpectedClose);
  T.Run('XmlDecl', @TestXmlDecl);
  T.Run('XmlDeclPretty', @TestXmlDeclPretty);
  T.Run('TextEscape', @TestTextEscape);
  T.Run('PrefixedElement', @TestPrefixedElement);
  T.Run('RawOutput', @TestRawOutput);
  T.Run('Clear', @TestClear);
  T.Run('RoundTrip', @TestRoundTrip);
  T.Run('MultipleAttributes', @TestMultipleAttributes);
  T.Run('NamespaceDeclMultiple', @TestNamespaceDeclMultiple);
  T.Run('RawUnescaped', @TestRawUnescaped);
  T.Run('ClearResetsCompletely', @TestClearResetsCompletely);
  T.Run('ConsecutiveStartEndDepth', @TestConsecutiveStartEndDepth);
  T.Summary;
end.
