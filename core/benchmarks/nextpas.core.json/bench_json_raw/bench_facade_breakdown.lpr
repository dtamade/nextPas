program bench_json_facade_breakdown;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.platform.time,
  nextpas.core.text.view,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json;

const
  SMALL_JSON = '{"name":"Alice","age":30,"active":true,"score":3.14}';
  N = 100000;

var
  LStart, LEnd: UInt64;

procedure BenchRawReuse;
var
  I: Int64;
  Doc: TJsonDocument;
  LView: TStringView;
begin
  LView := TStringView.FromStr(SMALL_JSON);
  Doc.Init(DefaultAllocator);
  LStart := platform_monotonic_ns;
  for I := 1 to N do
    Doc.Parse(LView);
  LEnd := platform_monotonic_ns;
  Doc.Done;
  WriteLn(Format('  raw reuse (no alloc):          %8.0f ns/op', [(LEnd - LStart) / N]));
end;

procedure BenchRawInitDone;
var
  I: Int64;
  Doc: TJsonDocument;
  LView: TStringView;
begin
  LView := TStringView.FromStr(SMALL_JSON);
  LStart := platform_monotonic_ns;
  for I := 1 to N do
  begin
    Doc.Init(DefaultAllocator);
    Doc.Parse(LView);
    Doc.Done;
  end;
  LEnd := platform_monotonic_ns;
  WriteLn(Format('  raw init+parse+done:           %8.0f ns/op', [(LEnd - LStart) / N]));
end;

procedure BenchFacade;
var
  I: Int64;
  Doc: IJsonDocument;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to N do
    Doc := JsonParse(SMALL_JSON);
  LEnd := platform_monotonic_ns;
  WriteLn(Format('  facade JsonParse(string):      %8.0f ns/op', [(LEnd - LStart) / N]));
end;

procedure BenchFacadeView;
var
  I: Int64;
  Doc: IJsonDocument;
  LView: TStringView;
begin
  LView := TStringView.FromStr(SMALL_JSON);
  LStart := platform_monotonic_ns;
  for I := 1 to N do
    Doc := JsonParse(LView);
  LEnd := platform_monotonic_ns;
  WriteLn(Format('  facade JsonParse(view):        %8.0f ns/op', [(LEnd - LStart) / N]));
end;

begin
  WriteLn('=== JSON facade overhead breakdown (small 52B) ===');
  WriteLn;
  BenchRawReuse;
  BenchRawInitDone;
  BenchFacade;
  BenchFacadeView;
  WriteLn;
  WriteLn('  overhead = facade - raw_reuse');
  WriteLn('done.');
end.
