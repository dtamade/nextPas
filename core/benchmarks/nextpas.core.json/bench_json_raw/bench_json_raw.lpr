program bench_json_raw;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.platform.time,
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.writer;

const
  SMALL_JSON = '{"name":"Alice","age":30,"active":true,"score":3.14}';
  MEDIUM_JSON = '{"users":[{"id":1,"name":"Alice","email":"alice@example.com","age":30},' +
    '{"id":2,"name":"Bob","email":"bob@example.com","age":25},' +
    '{"id":3,"name":"Charlie","email":"charlie@example.com","age":35}],' +
    '"total":3,"page":1,"hasMore":false}';

var
  LARGE_JSON: string;

procedure BuildLargeJson;
var
  B: TStringBuilder;
  W: TJsonWriter;
  I: Int32;
begin
  B.Init(8192);
  W.Init(B);
  W.BeginObject;
    W.Key('items'); W.BeginArray;
    for I := 0 to 99 do
    begin
      W.BeginObject;
        W.Key('id'); W.Int(I);
        W.Key('name'); W.Str('item_' + IntToStr(I));
        W.Key('value'); W.Float(I * 1.5);
        W.Key('active'); W.Bool(I mod 2 = 0);
      W.EndObject;
    end;
    W.EndArray;
    W.Key('count'); W.Int(100);
  W.EndObject;
  LARGE_JSON := B.ToString;
  B.Done;
end;

procedure Bench(const AName: string; const AInput: string; N: Int64);
var
  I: Int64;
  Doc: TJsonDocument;
  LView: TStringView;
  LStart, LEnd: UInt64;
  LNsPerOp: Double;
begin
  LView := TStringView.FromStr(AInput);
  Doc.Init(DefaultAllocator);
  Doc.Parse(LView);
  Doc.Done;

  Doc.Init(DefaultAllocator);
  LStart := platform_monotonic_ns;
  for I := 1 to N do
  begin
    Doc.Parse(LView);
  end;
  LEnd := platform_monotonic_ns;
  Doc.Done;

  LNsPerOp := (LEnd - LStart) / N;
  WriteLn(Format('  %-45s %8.0f ns/op  (%d bytes)', [AName, LNsPerOp, Length(AInput)]));
end;

begin
  BuildLargeJson;
  WriteLn('=== JSON raw parser (no facade/class overhead) ===');
  WriteLn;
  Bench('parse small (52B)', SMALL_JSON, 100000);
  Bench('parse medium (250B)', MEDIUM_JSON, 50000);
  Bench('parse large (' + IntToStr(Length(LARGE_JSON)) + 'B)', LARGE_JSON, 5000);
  WriteLn;
  WriteLn('done.');
end.
