program bench_dns_encode;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.dns.base,
  nextpas.core.text.conv,
  nextpas.core.time.stopwatch;

const
  ITERATIONS = 200000;
  NAME = 'mx.example.com';

var
  LQuery: TBytes;
  LSW: TStopwatch;
  LI: Integer;
  LTotal: Int64;
  LCheck: Integer;

begin
  { 热身: 首轮含字符串常量初始化/首包分配, 不计时 }
  for LI := 1 to 10000 do
    if not DnsEncodeQuery(NAME, dqMX, UInt16(LI), LQuery) then
      Halt(1);

  LSW := TStopwatch.StartNew;
  LCheck := 0;
  for LI := 1 to ITERATIONS do
  begin
    if DnsEncodeQuery(NAME, dqMX, UInt16(LI), LQuery) then
      LCheck := LCheck xor LQuery[0]
    else
      LCheck := LCheck xor 1;
  end;
  LSW.Stop;

  LTotal := LSW.ElapsedMilliseconds;
  if LTotal < 1 then
    LTotal := 1;
  WriteLn('dns encode: ' + IntToStr(ITERATIONS) + ' iters in '
    + IntToStr(LTotal) + ' ms => ' + IntToStr(ITERATIONS * 1000 div LTotal)
    + ' ops/s (check=' + IntToStr(LCheck) + ')');
end.
