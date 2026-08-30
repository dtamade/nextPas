program bench_wire_headers;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.agent.base,
  nextpas.core.agent.provider.common,
  nextpas.core.fs;

{ bench_wire_headers（W15 性能锚定）：wire 头部校验吞吐。
  主张（ROADMAP-FINAL W15.6 / SECURITY §3）：AgentValidateWireHeaders 单遍
  CR/LF 检测 + 8 KiB/64 KiB 限，典型 5 头网关 QPS 路径 p50 <5µs，且
  10 头 + 空头分流均在阈值内；禁止回退为 4×Pos 扫描。 }

var
  GHeaders5: TWireHeaderArray;
  GHeaders10: TWireHeaderArray;
  GHeadersEmpty: TWireHeaderArray;
  GSink: Integer;

procedure InitFixtures;
var
  I: Integer;
begin
  SetLength(GHeaders5, 5);
  GHeaders5[0].Name := 'Authorization';
  GHeaders5[0].Value := 'Bearer sk-bench-0123456789abcdef';
  GHeaders5[1].Name := 'Content-Type';
  GHeaders5[1].Value := 'application/json';
  GHeaders5[2].Name := 'X-Request-Id';
  GHeaders5[2].Value := 'req-bench-0001';
  GHeaders5[3].Name := 'OpenAI-Organization';
  GHeaders5[3].Value := 'org-bench';
  GHeaders5[4].Name := 'X-Custom';
  GHeaders5[4].Value := 'bench-value-' + StringOfChar('a', 32);

  SetLength(GHeaders10, 10);
  for I := 0 to 9 do
  begin
    GHeaders10[I].Name := 'X-H' + IntToStr(I);
    GHeaders10[I].Value := 'v-' + StringOfChar('x', 64);
  end;

  SetLength(GHeadersEmpty, 0);
end;

procedure BenchValidate5(const ACtx: IBenchContext);
begin
  AgentValidateWireHeaders(GHeaders5);
  Inc(GSink);
end;

procedure BenchValidate10(const ACtx: IBenchContext);
begin
  AgentValidateWireHeaders(GHeaders10);
  Inc(GSink);
end;

procedure BenchValidateEmpty(const ACtx: IBenchContext);
begin
  AgentValidateWireHeaders(GHeadersEmpty);
  Inc(GSink);
end;

var
  LResults: IBenchResults;
begin
  InitFixtures;
  { 自检：夹具必须通过校验，否则基准无意义 }
  AgentValidateWireHeaders(GHeaders5);
  AgentValidateWireHeaders(GHeaders10);
  AgentValidateWireHeaders(GHeadersEmpty);
  LResults := TBenchSuite.Create('agent')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('wire/validate-5-headers', @BenchValidate5)
    .Add('wire/validate-10-headers', @BenchValidate10)
    .Add('wire/validate-empty', @BenchValidateEmpty)
    .Run;
  WriteLn('sink: ', GSink);
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-agent-wire-headers.json');
end.
