program test_xml_facade_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.xml,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestFacadeExposesCoreSurface;
var
  LDoc: TXmlDocument;
  LReader: TXmlReader;
  LToken: TXmlToken;
  LWriter: TXmlWriter;
  LNamespace: TXmlNamespace;
  LNamespaces: TXmlNamespaceArray;
begin
  LNamespace.Prefix := 'x';
  LNamespace.URI := 'urn:demo';
  SetLength(LNamespaces, 1);
  LNamespaces[0] := LNamespace;
  CheckEqual('x', LNamespaces[0].Prefix, 'namespace prefix type visible');
  CheckEqual('urn:demo', LNamespaces[0].URI, 'namespace uri type visible');

  LDoc := XmlParse('<root><name>demo</name></root>');
  try
    Check(LDoc.Root.IsAssigned, 'dom parse via facade succeeds');
    Check(LDoc.Root.Kind = xnkElement, 'dom node kind constants visible');
    Check(LDoc.Root.FindChild('name').Text = 'demo', 'dom helpers visible');
  finally
    LDoc.Free;
  end;

  LReader := TXmlReader.Create('<root/>');
  try
    Check(LReader.Next(LToken), 'reader token available via facade');
    Check(LToken.Kind = xtkEmptyElement, 'token kind constants visible');
  finally
    LReader.Free;
  end;

  LWriter := TXmlWriter.Create;
  try
    LWriter.WriteXmlDecl('1.0', 'utf-8');
    LWriter.EmptyElement('root');
    Check(Pos('<?xml', LWriter.ToString) = 1, 'writer available via facade');
  finally
    LWriter.Free;
  end;
end;

procedure TestFacadeExposesNamespaceSurface;
var
  LWriter: TXmlWriter;
  LDoc: TXmlDocument;
  LText: string;
  LRaised: Boolean;
begin
  LWriter := TXmlWriter.Create;
  try
    LWriter.StartElement('root');
    LWriter.NamespaceDecl('ns', 'urn:demo');
    LWriter.StartElement('ns', 'item');
    LWriter.Text('x');
    LWriter.EndElement('ns:item');
    LWriter.EndElement('root');
    LText := LWriter.ToString;
    Check(Pos('xmlns:ns="urn:demo"', LText) > 0, 'namespace decl written');
    Check(Pos('<ns:item>', LText) > 0, 'prefixed element written');
  finally
    LWriter.Free;
  end;

  LDoc := XmlParse(LText);
  try
    Check(LDoc.Root.IsAssigned, 'namespaced document parses');
    CheckEqual('root', LDoc.Root.Name.Local, 'root local name');
  finally
    LDoc.Free;
  end;

  LRaised := False;
  LWriter := TXmlWriter.Create;
  try
    try
      LWriter.StartElement('root');
      LWriter.NamespaceDecl('xmlns', 'urn:bad');
    except
      on E: Exception do
        LRaised := True;
    end;
  finally
    LWriter.Free;
  end;
  Check(LRaised, 'reserved xmlns prefix rejected');

  LRaised := False;
  LWriter := TXmlWriter.Create;
  try
    try
      LWriter.StartElement('root');
      LWriter.NamespaceDecl('xml', 'urn:not-xml-ns');
    except
      on E: Exception do
        LRaised := True;
    end;
  finally
    LWriter.Free;
  end;
  Check(LRaised, 'xml prefix must bind XML namespace URI');
end;

function XmlBytesFromString(const AText: string): TBytes;
var
  LI: Integer;
begin
  SetLength(Result, Length(AText));
  for LI := 1 to Length(AText) do
    Result[LI - 1] := Byte(AText[LI]);
end;

procedure TestFacadeExposesReaderParse;
var
  LStream: IStream;
  LDoc: TXmlDocument;
  LRaised: Boolean;
begin
  LStream := CreateBytesStreamFrom(XmlBytesFromString('<root>x</root>'));
  LDoc := XmlParse(LStream as IReader);
  try
    Check(LDoc.Root.IsAssigned, 'XmlParse IReader');
    CheckEqual('root', LDoc.Root.Name.Local, 'root local');
  finally
    LDoc.Free;
  end;
  LRaised := False;
  try
    XmlParse(IReader(nil));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'nil IReader raises');
end;

procedure TestFacadeCdataEntityAndDefaultNs;
var
  LDoc: TXmlDocument;
  LWriter: TXmlWriter;
  LText: string;
  LOk: Boolean;
begin
  LDoc := XmlParse('<root><![CDATA[raw<>&data]]></root>');
  try
    Check(LDoc.Root.IsAssigned, 'cdata root');
    Check(Pos('raw', LDoc.Root.Text) > 0, 'cdata text retained');
    Check(Pos('<', LDoc.Root.Text) > 0, 'cdata angle retained');
  finally
    LDoc.Free;
  end;

  CheckEqual('&lt;a&gt;', XmlEncodeText('<a>'), 'XmlEncodeText facade');
  CheckEqual('<a>', XmlDecodeEntities('&lt;a&gt;'), 'XmlDecodeEntities facade');

  LWriter := TXmlWriter.Create;
  try
    LWriter.StartElement('root');
    LWriter.NamespaceDecl('', 'urn:default');
    LWriter.StartElement('child');
    LWriter.Text('x');
    LWriter.EndElement('child');
    LWriter.EndElement('root');
    LText := LWriter.ToString;
    Check(Pos('xmlns="urn:default"', LText) > 0, 'default ns written');
  finally
    LWriter.Free;
  end;
  LDoc := XmlParse(LText);
  try
    Check(LDoc.Root.IsAssigned, 'default ns reparse');
    CheckEqual('root', LDoc.Root.Name.Local, 'default ns root local');
  finally
    LDoc.Free;
  end;

  LOk := TryXmlParse('<root><unclosed>', LDoc);
  CheckEqual(False, LOk, 'malformed TryXmlParse fails');
end;

begin
  T := TTestSuite.Create('nextpas.core.xml (facade surface)');
  T.Test('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Test('facade exposes namespace surface',
    @TestFacadeExposesNamespaceSurface);
  T.Test('facade exposes reader parse', @TestFacadeExposesReaderParse);
  T.Test('facade cdata entity default-ns',
    @TestFacadeCdataEntityAndDefaultNs);
  if not T.Run then Halt(1);
end.
