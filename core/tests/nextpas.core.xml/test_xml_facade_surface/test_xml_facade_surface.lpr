program test_xml_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.xml,
  nextpas.core.mem.default,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestFacadeExposesCoreSurface;
var
  LDoc: TXmlDocument;
  LXDoc: IXmlDocument;
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

  { IXmlDocument interface surface }
  LXDoc := XmlParseDoc('<root><child>hello</child></root>');
  Check(LXDoc <> nil, 'XmlParseDoc returns non-nil');
  Check(LXDoc.Root.IsAssigned, 'IXmlDocument Root is assigned');
  Check(not LXDoc.HasError, 'IXmlDocument HasError false on success');
  Check(LXDoc.Error = nil, 'IXmlDocument Error nil on success');
  Check(LXDoc.Document.IsAssigned, 'IXmlDocument Document assigned');
  Check(Pos('<root>', LXDoc.Stringify) > 0, 'IXmlDocument Stringify works');

  LXDoc := XmlParseDoc('<invalid><unclosed>');
  Check(LXDoc <> nil, 'XmlParseDoc error doc is non-nil');
  Check(LXDoc.HasError, 'IXmlDocument HasError true on error');
  Check(LXDoc.Error <> nil, 'IXmlDocument Error non-nil on error');
  Check(not LXDoc.Root.IsAssigned, 'IXmlDocument Root None on error');
  LXDoc := nil;

  { TryXmlParseDoc surface }
  Check(TryXmlParseDoc('<root/>', LXDoc), 'TryXmlParseDoc succeeds');
  Check(LXDoc.Root.IsAssigned, 'TryXmlParseDoc root assigned');
  LXDoc := nil;
  Check(not TryXmlParseDoc('<invalid><unclosed>', LXDoc),
    'TryXmlParseDoc false on error');
  Check(LXDoc.HasError, 'TryXmlParseDoc error carried');
  LXDoc := nil;

  { XmlParseDocWith / TryXmlParseDocWith with allocator }
  LXDoc := XmlParseDocWith('<root/>', DefaultAllocator);
  Check(LXDoc.Root.IsAssigned, 'XmlParseDocWith root assigned');
  LXDoc := nil;
  Check(TryXmlParseDocWith('<root/>', DefaultAllocator, LXDoc),
    'TryXmlParseDocWith succeeds');
  Check(LXDoc.Root.IsAssigned, 'TryXmlParseDocWith root assigned');
  LXDoc := nil;

  { XmlTokenizeWith surface }
  Check(Length(XmlTokenizeWith('<r/>', DefaultAllocator)) = 1,
    'XmlTokenizeWith returns tokens');

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
  T := TTestRunner.Create('nextpas.core.xml (facade surface)');
  T.Run('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
