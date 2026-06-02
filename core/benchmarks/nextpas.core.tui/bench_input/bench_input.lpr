program bench_input;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.event,
  nextpas.core.tui.input,
  nextpas.core.bench;

var
  AsciiKey: array[0..0] of Byte;
  CsiArrow: array[0..2] of Byte;
  SgrMouse: array[0..8] of Byte;
  Utf8Cjk: array[0..2] of Byte;
  Ev: TEvent;
  Consumed: Integer;

procedure BenchAsciiKey(AIters: Int64);
var LI: Int64;
begin
  AsciiKey[0] := Ord('A');
  for LI := 1 to AIters do
    ParseOne(AsciiKey[0], 1, True, Ev, Consumed);
end;

procedure BenchCsiArrow(AIters: Int64);
var LI: Int64;
begin
  CsiArrow[0] := 27; CsiArrow[1] := Ord('['); CsiArrow[2] := Ord('A');
  for LI := 1 to AIters do
    ParseOne(CsiArrow[0], 3, True, Ev, Consumed);
end;

procedure BenchSgrMouse(AIters: Int64);
var LI: Int64;
begin
  { CSI < 0;10;5M }
  SgrMouse[0] := 27; SgrMouse[1] := Ord('['); SgrMouse[2] := Ord('<');
  SgrMouse[3] := Ord('0'); SgrMouse[4] := Ord(';');
  SgrMouse[5] := Ord('1'); SgrMouse[6] := Ord('0'); SgrMouse[7] := Ord(';');
  SgrMouse[8] := Ord('5');
  { Need final M }
  for LI := 1 to AIters do
    ParseOne(SgrMouse[0], 9, True, Ev, Consumed);
end;

procedure BenchUtf8Cjk(AIters: Int64);
var LI: Int64;
begin
  { '中' = E4 B8 AD }
  Utf8Cjk[0] := $E4; Utf8Cjk[1] := $B8; Utf8Cjk[2] := $AD;
  for LI := 1 to AIters do
    ParseOne(Utf8Cjk[0], 3, True, Ev, Consumed);
end;

var
  Runner: TBenchRunner;
begin
  Runner := TBenchRunner.Create;
  Runner.Run('ParseOne ASCII key', @BenchAsciiKey);
  Runner.Run('ParseOne CSI arrow', @BenchCsiArrow);
  Runner.Run('ParseOne SGR mouse (incomplete)', @BenchSgrMouse);
  Runner.Run('ParseOne UTF-8 CJK', @BenchUtf8Cjk);
  Runner.Summary;
end.
