program csv_smoke;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.csv;

var
  LReader: TCsvReader;
  LFields: TStringArray;
  LWriter: TCsvWriter;
  LRows: Integer;

begin
  WriteLn('csv-smoke=ready');

  LReader := TCsvReader.Create(
    'name,age' + #10 +
    'Alice,30' + #10 +
    'Bob,25' + #10);
  LRows := 0;
  while LReader.ReadRow(LFields) do
  begin
    Inc(LRows);
    if LRows = 2 then
      WriteLn('row2=', LFields[0], '/', LFields[1]);
  end;
  if LReader.HasError then
  begin
    WriteLn('csv-smoke-status=fail');
    WriteLn('error=', LReader.GetError);
    Halt(1);
  end;
  WriteLn('rows=', LRows);

  LWriter := TCsvWriter.Create;
  LWriter.WriteRow(['x', 'y']);
  LWriter.WriteRow(['1', '2']);
  WriteLn('written=', LWriter.ToString);
  WriteLn('csv-smoke-status=pass');
end.
