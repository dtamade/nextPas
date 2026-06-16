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

procedure TestAttributeRejectsInvalidControlChar;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LRaised := False;
    try
      LW.Attribute('v', 'bad' + #1 + 'value');
      Fail('attribute with invalid control char must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid attribute control char raises EArgumentError');
    LW.EndElement('root');
    CheckEqual('<root/>', LW.ToString,
      'invalid attribute control char leaves open element recoverable');
  finally
    LW.Free;
  end;
end;

procedure TestAttributeRejectsEmptyName;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LRaised := False;
    try
      LW.Attribute('', 'x');
      Fail('attribute with empty name must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'empty attribute name raises EArgumentError');
    LW.EndElement('root');
    CheckEqual('<root/>', LW.ToString, 'empty attribute name leaves output valid');
  finally
    LW.Free;
  end;
end;

procedure TestAttributeOutsideStartTagIgnoresInvalidName;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LW.EndElement('root');
    LW.Attribute('bad name', 'x');
    CheckEqual('<root/>', LW.ToString,
      'attribute outside start tag remains a no-op even for invalid name');
  finally
    LW.Free;
  end;
end;

procedure TestWriterRejectsInvalidQNames;
var
  LW: TXmlWriter;
  LRaised: Boolean;

  procedure ExpectInvalidStartElement(const AName, ALabel: string);
  begin
    LW.Clear;
    LRaised := False;
    try
      LW.StartElement(AName);
      Fail(ALabel + ' must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, ALabel + ' raises EArgumentError');
    CheckEqual('', LW.ToString, ALabel + ' leaves output unchanged');
  end;

begin
  LW := TXmlWriter.Create(False);
  try
    ExpectInvalidStartElement('1root', 'digit-start element name');
    ExpectInvalidStartElement('bad name', 'space-containing element name');
    ExpectInvalidStartElement('ns:', 'empty-local QName');
    ExpectInvalidStartElement(':local', 'empty-prefix QName');
    ExpectInvalidStartElement('a:b:c', 'multi-colon QName');

    LRaised := False;
    try
      LW.EmptyElement('bad name');
      Fail('empty element with invalid QName must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid empty-element QName raises EArgumentError');
    CheckEqual('', LW.ToString, 'invalid empty-element QName leaves output unchanged');

    LW.StartElement('root');
    LRaised := False;
    try
      LW.StartElement('bad name');
      Fail('nested start element with invalid QName must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid nested start-element QName raises EArgumentError');
    CheckEqual('<root', LW.ToString,
      'invalid nested start-element QName does not flush open start tag');

    LRaised := False;
    try
      LW.EmptyElement('bad name');
      Fail('nested empty element with invalid QName must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid nested empty-element QName raises EArgumentError');
    CheckEqual('<root', LW.ToString,
      'invalid nested empty-element QName does not flush open start tag');

    LRaised := False;
    try
      LW.Attribute('bad name', 'x');
      Fail('attribute with invalid QName must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid attribute QName raises EArgumentError');
    LW.EndElement('root');
    CheckEqual('<root/>', LW.ToString, 'invalid attribute QName leaves open element recoverable');
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

procedure TestNamespaceDeclAllowsXmlPrefixBinding;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LW.NamespaceDecl('xml', 'http://www.w3.org/XML/1998/namespace');
    LW.EndElement('root');
    CheckEqual(
      '<root xmlns:xml="http://www.w3.org/XML/1998/namespace"/>',
      LW.ToString,
      'xml prefix may be declared only with the standard XML namespace');
  finally
    LW.Free;
  end;
end;

procedure TestNamespaceDeclRejectsInvalidReservedBindings;
var
  LW: TXmlWriter;
  LRaised: Boolean;

  procedure ExpectInvalidNamespaceDecl(
    const APrefix, AURI, ALabel: string);
  begin
    LW.Clear;
    LW.StartElement('root');
    LRaised := False;
    try
      LW.NamespaceDecl(APrefix, AURI);
      Fail(ALabel + ' must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, ALabel + ' raises EArgumentError');
    CheckEqual('<root', LW.ToString,
      ALabel + ' does not flush or mutate the open start tag');
    LW.EndElement('root');
    CheckEqual('<root/>', LW.ToString,
      ALabel + ' leaves the writer recoverable');
  end;

begin
  LW := TXmlWriter.Create(False);
  try
    ExpectInvalidNamespaceDecl('xmlns', 'urn:x',
      'reserved xmlns prefix declaration');
    ExpectInvalidNamespaceDecl('xml', 'urn:x',
      'xml prefix bound to a non-standard namespace');
    ExpectInvalidNamespaceDecl('ns', '',
      'prefixed namespace undeclaration');
    ExpectInvalidNamespaceDecl('ns', 'http://www.w3.org/XML/1998/namespace',
      'non-xml prefix bound to the xml namespace');
    ExpectInvalidNamespaceDecl('', 'http://www.w3.org/XML/1998/namespace',
      'xml namespace declared as the default namespace');
    ExpectInvalidNamespaceDecl('ns', 'http://www.w3.org/2000/xmlns/',
      'non-xmlns prefix bound to the xmlns namespace');
    ExpectInvalidNamespaceDecl('', 'http://www.w3.org/2000/xmlns/',
      'xmlns namespace declared as the default namespace');
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

procedure TestCDataSplitsEmbeddedEndMarker;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('r');
    LW.CData('alpha]]>omega');
    LW.EndElement('r');
    CheckEqual('<r><![CDATA[alpha]]]]><![CDATA[>omega]]></r>',
      LW.ToString, 'cdata splits embedded end marker');
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

procedure TestCommentRejectsEmbeddedDoubleDash;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.Comment('alpha--omega');
      Fail('comment with embedded -- must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'embedded -- comment raises EArgumentError');
  finally
    LW.Free;
  end;
end;

procedure TestCommentRejectsTrailingDash;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.Comment('alpha-');
      Fail('comment ending with - must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'trailing - comment raises EArgumentError');
  finally
    LW.Free;
  end;
end;

procedure TestCommentRejectsInvalidControlChar;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LRaised := False;
    try
      LW.Comment('bad' + #1 + 'value');
      Fail('comment with invalid control char must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid comment control char raises EArgumentError');
    LW.EndElement('root');
    CheckEqual('<root/>', LW.ToString,
      'invalid comment control char leaves open element recoverable');
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

procedure TestPISplitsEmbeddedEndMarker;
var
  LW: TXmlWriter;
  LReader: TXmlReader;
  LTok: TXmlToken;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.PI('target', 'alpha?>omega');
    CheckEqual('<?target alpha??><?target >omega?>', LW.ToString,
      'pi splits embedded end marker');

    LReader := TXmlReader.Create(LW.ToString);
    try
      Check(LReader.Next(LTok), 'first split pi token');
      Check(LTok.Kind = xtkProcessingInstr, 'first split pi kind');
      CheckEqual('target', LTok.Name.Local, 'first split pi target');
      CheckEqual('alpha?', LTok.Value, 'first split pi value');

      Check(LReader.Next(LTok), 'second split pi token');
      Check(LTok.Kind = xtkProcessingInstr, 'second split pi kind');
      CheckEqual('target', LTok.Name.Local, 'second split pi target');
      CheckEqual('>omega', LTok.Value, 'second split pi value');

      Check(not LReader.Next(LTok), 'split pi writer output exhausted');
      Check(not LReader.HasError, 'split pi writer output parses cleanly');
    finally
      LReader.Free;
    end;
  finally
    LW.Free;
  end;
end;

procedure TestPIRejectsInvalidControlChar;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LRaised := False;
    try
      LW.PI('target', 'bad' + #1 + 'value');
      Fail('PI data with invalid control char must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid PI control char raises EArgumentError');
    LW.EndElement('root');
    CheckEqual('<root/>', LW.ToString,
      'invalid PI control char leaves open element recoverable');
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

procedure TestPIRejectsReservedXmlTarget;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.PI('xml', 'version="1.0"');
      Fail('reserved xml PI target must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'reserved xml PI target raises EArgumentError');
  finally
    LW.Free;
  end;
end;

procedure TestPIRejectsEmptyTarget;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.PI('', 'payload');
      Fail('empty PI target must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'empty PI target raises EArgumentError');
  finally
    LW.Free;
  end;
end;

procedure TestPIRejectsInvalidTarget;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.PI('bad target', 'payload');
      Fail('PI target with whitespace must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'whitespace PI target raises EArgumentError');
    CheckEqual('', LW.ToString, 'invalid PI target leaves output unchanged');

    LW.StartElement('root');
    LRaised := False;
    try
      LW.PI('1target', 'payload');
      Fail('PI target starting with digit must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'digit-start PI target raises EArgumentError');
    LW.EndElement('root');
    CheckEqual('<root/>', LW.ToString, 'invalid PI target leaves open element recoverable');
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

procedure TestStartElementRejectsEmptyName;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.StartElement('');
      Fail('start element with empty name must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'empty start element name raises EArgumentError');
    CheckEqual('', LW.ToString, 'empty start element name leaves output unchanged');
  finally
    LW.Free;
  end;
end;

procedure TestEmptyElementRejectsEmptyName;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.EmptyElement('');
      Fail('empty element with empty name must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'empty element name raises EArgumentError');
    CheckEqual('', LW.ToString, 'empty element name leaves output unchanged');
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

procedure TestXmlDeclWithStandalone;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.WriteXmlDecl('1.0', 'UTF-8', 'yes');
    LW.StartElement('r');
    LW.EndElement('r');
    CheckEqual(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><r/>',
      LW.ToString,
      'xml decl with standalone yes');

    LW.Clear;
    LW.WriteXmlDecl('1.0', 'UTF-8', 'no');
    LW.EmptyElement('r');
    CheckEqual(
      '<?xml version="1.0" encoding="UTF-8" standalone="no"?><r/>',
      LW.ToString,
      'xml decl with standalone no');
  finally
    LW.Free;
  end;
end;

procedure TestXmlDeclRejectsLateCall;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('r');
    LW.EndElement('r');
    LRaised := False;
    try
      LW.WriteXmlDecl;
      Fail('xml declaration after document output must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'late xml declaration raises EArgumentError');
  finally
    LW.Free;
  end;
end;

procedure TestXmlDeclRejectsInvalidStandaloneValue;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.WriteXmlDecl('1.0', 'UTF-8', 'maybe');
      Fail('xml declaration with invalid standalone value must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid xml declaration standalone raises EArgumentError');
    CheckEqual('', LW.ToString,
      'invalid xml declaration standalone leaves output unchanged');
  finally
    LW.Free;
  end;
end;

procedure TestXmlDeclRejectsEmptyVersion;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.WriteXmlDecl('', 'UTF-8');
      Fail('xml declaration with empty version must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'empty xml declaration version raises EArgumentError');
  finally
    LW.Free;
  end;
end;

procedure TestXmlDeclRejectsInvalidVersionNumber;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.WriteXmlDecl('1 0', 'UTF-8');
      Fail('xml declaration with invalid version number must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid xml declaration version raises EArgumentError');
  finally
    LW.Free;
  end;
end;

procedure TestXmlDeclAllowsOmittedEncoding;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.WriteXmlDecl('1.0', '');
    LW.EmptyElement('r');
    CheckEqual('<?xml version="1.0"?><r/>', LW.ToString,
      'xml decl without encoding');

    LW.Clear;
    LW.WriteXmlDecl('1.0', '', 'yes');
    LW.EmptyElement('r');
    CheckEqual('<?xml version="1.0" standalone="yes"?><r/>', LW.ToString,
      'xml decl without encoding keeps standalone after version');
  finally
    LW.Free;
  end;
end;

procedure TestXmlDeclRejectsInvalidEncodingName;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LRaised := False;
    try
      LW.WriteXmlDecl('1.0', 'UTF 8');
      Fail('xml declaration with invalid encoding name must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid xml declaration encoding raises EArgumentError');
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

procedure TestTextRejectsInvalidControlChar;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LRaised := False;
    try
      LW.Text('bad' + #1 + 'value');
      Fail('text with invalid control char must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid text control char raises EArgumentError');
    LW.EndElement('root');
    CheckEqual('<root/>', LW.ToString,
      'invalid text control char leaves open element recoverable');
  finally
    LW.Free;
  end;
end;

procedure TestCDataRejectsInvalidControlChar;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LRaised := False;
    try
      LW.CData('bad' + #1 + 'value');
      Fail('CDATA with invalid control char must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'invalid CDATA control char raises EArgumentError');
    LW.EndElement('root');
    CheckEqual('<root/>', LW.ToString,
      'invalid CDATA control char leaves open element recoverable');
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

procedure TestAttributeRejectsDuplicateRawQName;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LW.Attribute('id', '1');
    LRaised := False;
    try
      LW.Attribute('id', '2');
      Fail('duplicate raw attribute QName must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'duplicate raw attribute QName raises EArgumentError');
    LW.EndElement('root');
    CheckEqual('<root id="1"/>', LW.ToString,
      'rejected duplicate attribute leaves output valid');
  finally
    LW.Free;
  end;
end;

procedure TestAttributeAllowsSameQNameOnDifferentElements;
var
  LW: TXmlWriter;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('a');
    LW.Attribute('id', '1');
    LW.StartElement('b');
    LW.Attribute('id', '2');
    LW.EndElement('b');
    LW.EndElement('a');
    CheckEqual('<a id="1"><b id="2"/></a>', LW.ToString,
      'same raw attribute QName is scoped to one start tag');
  finally
    LW.Free;
  end;
end;

procedure TestNamespaceDeclRejectsDuplicateRawQName;
var
  LW: TXmlWriter;
  LRaised: Boolean;
begin
  LW := TXmlWriter.Create(False);
  try
    LW.StartElement('root');
    LW.Attribute('xmlns:ns', 'urn:a');
    LRaised := False;
    try
      LW.NamespaceDecl('ns', 'urn:b');
      Fail('duplicate namespace declaration QName must be rejected');
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'duplicate namespace declaration QName raises EArgumentError');
    LW.EndElement('root');
    CheckEqual('<root xmlns:ns="urn:a"/>', LW.ToString,
      'rejected duplicate namespace declaration leaves output valid');
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
  T.Run('AttributeRejectsInvalidControlChar',
    @TestAttributeRejectsInvalidControlChar);
  T.Run('AttributeRejectsEmptyName', @TestAttributeRejectsEmptyName);
  T.Run('AttributeOutsideStartTagIgnoresInvalidName',
    @TestAttributeOutsideStartTagIgnoresInvalidName);
  T.Run('WriterRejectsInvalidQNames', @TestWriterRejectsInvalidQNames);
  T.Run('NamespaceDecl', @TestNamespaceDecl);
  T.Run('DefaultNamespaceDecl', @TestDefaultNamespaceDecl);
  T.Run('NamespaceDeclAllowsXmlPrefixBinding',
    @TestNamespaceDeclAllowsXmlPrefixBinding);
  T.Run('NamespaceDeclRejectsInvalidReservedBindings',
    @TestNamespaceDeclRejectsInvalidReservedBindings);
  T.Run('CDataOutput', @TestCDataOutput);
  T.Run('CDataSplitsEmbeddedEndMarker', @TestCDataSplitsEmbeddedEndMarker);
  T.Run('CommentOutput', @TestCommentOutput);
  T.Run('CommentRejectsEmbeddedDoubleDash', @TestCommentRejectsEmbeddedDoubleDash);
  T.Run('CommentRejectsTrailingDash', @TestCommentRejectsTrailingDash);
  T.Run('CommentRejectsInvalidControlChar',
    @TestCommentRejectsInvalidControlChar);
  T.Run('PIOutput', @TestPIOutput);
  T.Run('PISplitsEmbeddedEndMarker', @TestPISplitsEmbeddedEndMarker);
  T.Run('PIRejectsInvalidControlChar', @TestPIRejectsInvalidControlChar);
  T.Run('PINoData', @TestPINoData);
  T.Run('PIRejectsReservedXmlTarget', @TestPIRejectsReservedXmlTarget);
  T.Run('PIRejectsEmptyTarget', @TestPIRejectsEmptyTarget);
  T.Run('PIRejectsInvalidTarget', @TestPIRejectsInvalidTarget);
  T.Run('EmptyElement', @TestEmptyElement);
  T.Run('StartElementRejectsEmptyName', @TestStartElementRejectsEmptyName);
  T.Run('EmptyElementRejectsEmptyName', @TestEmptyElementRejectsEmptyName);
  T.Run('EndElementCollapsesEmpty', @TestEndElementCollapsesEmpty);
  T.Run('EndElementRejectsMismatchedName', @TestEndElementRejectsMismatchedName);
  T.Run('EndElementRejectsUnexpectedClose', @TestEndElementRejectsUnexpectedClose);
  T.Run('XmlDecl', @TestXmlDecl);
  T.Run('XmlDeclPretty', @TestXmlDeclPretty);
  T.Run('XmlDeclWithStandalone', @TestXmlDeclWithStandalone);
  T.Run('XmlDeclRejectsLateCall', @TestXmlDeclRejectsLateCall);
  T.Run('XmlDeclRejectsInvalidStandaloneValue',
    @TestXmlDeclRejectsInvalidStandaloneValue);
  T.Run('XmlDeclRejectsEmptyVersion', @TestXmlDeclRejectsEmptyVersion);
  T.Run('XmlDeclRejectsInvalidVersionNumber', @TestXmlDeclRejectsInvalidVersionNumber);
  T.Run('XmlDeclAllowsOmittedEncoding', @TestXmlDeclAllowsOmittedEncoding);
  T.Run('XmlDeclRejectsInvalidEncodingName', @TestXmlDeclRejectsInvalidEncodingName);
  T.Run('TextEscape', @TestTextEscape);
  T.Run('TextRejectsInvalidControlChar', @TestTextRejectsInvalidControlChar);
  T.Run('CDataRejectsInvalidControlChar', @TestCDataRejectsInvalidControlChar);
  T.Run('PrefixedElement', @TestPrefixedElement);
  T.Run('RawOutput', @TestRawOutput);
  T.Run('Clear', @TestClear);
  T.Run('RoundTrip', @TestRoundTrip);
  T.Run('MultipleAttributes', @TestMultipleAttributes);
  T.Run('AttributeRejectsDuplicateRawQName',
    @TestAttributeRejectsDuplicateRawQName);
  T.Run('AttributeAllowsSameQNameOnDifferentElements',
    @TestAttributeAllowsSameQNameOnDifferentElements);
  T.Run('NamespaceDeclRejectsDuplicateRawQName',
    @TestNamespaceDeclRejectsDuplicateRawQName);
  T.Run('NamespaceDeclMultiple', @TestNamespaceDeclMultiple);
  T.Run('RawUnescaped', @TestRawUnescaped);
  T.Run('ClearResetsCompletely', @TestClearResetsCompletely);
  T.Run('ConsecutiveStartEndDepth', @TestConsecutiveStartEndDepth);
  T.Summary;
end.
