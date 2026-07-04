program test_xml_facade_surface;

{$I nextpas.core.settings.inc}

uses
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

begin
  T := TTestSuite.Create('nextpas.core.xml (facade surface)');
  T.Test('facade exposes core surface', @TestFacadeExposesCoreSurface);
  if not T.Run then Halt(1);
end.
