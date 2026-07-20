program test_xml_facade_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
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

begin
  T := TTestSuite.Create('nextpas.core.xml (facade surface)');
  T.Test('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Test('facade exposes namespace surface',
    @TestFacadeExposesNamespaceSurface);
  if not T.Run then Halt(1);
end.
