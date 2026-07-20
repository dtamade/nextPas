program xml_smoke;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.xml;

var
  LDoc: IXmlDocument;
  LName: TXmlNode;

begin
  WriteLn('xml-smoke=ready');

  LDoc := XmlParseDoc('<config><name>app</name></config>');
  if LDoc.HasError then
  begin
    WriteLn('xml-smoke-status=fail');
    Halt(1);
  end;

  LName := LDoc.Root.FindChild('name');
  if not LName.IsAssigned then
  begin
    WriteLn('xml-smoke-status=fail');
    WriteLn('error=missing name child');
    Halt(1);
  end;

  WriteLn('name=', LName.Text);
  WriteLn('xml=', LDoc.Stringify);
  WriteLn('xml-smoke-status=pass');
end.
