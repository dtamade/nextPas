program json_smoke;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.json;

var
  LDoc: IJsonDocument;
  LRoot: TJsonValue;

begin
  WriteLn('json-smoke=ready');

  LDoc := JsonParse('{"name":"Alice","age":30,"tags":["api","prod"]}');
  if LDoc.HasError then
  begin
    WriteLn('json-smoke-status=fail');
    WriteLn('error=', LDoc.Error.Message.ToString);
    Halt(1);
  end;

  LRoot := LDoc.Root;
  WriteLn('name=', LRoot.ObjectGet('name').AsStr.ToString);
  WriteLn('age=', LRoot.ObjectGet('age').AsInt);
  WriteLn('tags0=', LRoot.ObjectGet('tags').ArrayGet(0).AsStr.ToString);
  WriteLn('compact=', LDoc.Stringify);
  WriteLn('json-smoke-status=pass');
end.
