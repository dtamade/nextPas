program bench_webview_bridge;

{** @desc 桥协议热路径基线：web→native 帧解码（TryDecodeFrame）与
       native→web 回执/事件脚本构造（Build*Script）的单核吞吐。
       先做正确性抽检再计时——禁止无断言的假基线。中位数取 5 轮。 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.platform.time,
  nextpas.core.text.view,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.bridge,
  nextpas.core.webview.metrics, nextpas.core.text, nextpas.core.text.format;

const
  { 典型 invoke 帧：3 字段对象负载，~70B }
  FRAME_JSON = '{"v":1,"id":42,"cmd":"demo.sum",' +
    '"payload":{"a":19,"b":23,"name":"npw"}}';
  RESULT_JSON = '{"sum":42,"items":[1,2,3]}';
  REJECT_CODE = 'npw.demo.bad_payload';
  REJECT_MSG = 'payload must be a JSON object';
  EVENT_NAME = 'demo.event';
  EVENT_PAYLOAD = '{"note":"pushed from Pascal","seq":7}';
  ITER = 200000;
  RUNS = 5;

type
  TDoubles = array of Double;

var
  GFrame: TWebviewFrame;
  GScript: string;
  GKeep: Boolean;

function MedianNanos(AVals: TDoubles): Double;
var
  I, J: Integer;
  LTmp: Double;
begin
  for I := 0 to High(AVals) do
    for J := I + 1 to High(AVals) do
      if AVals[J] < AVals[I] then
      begin
        LTmp := AVals[I];
        AVals[I] := AVals[J];
        AVals[J] := LTmp;
      end;
  Result := AVals[Length(AVals) div 2];
end;

procedure Report(const AName: string; const AVals: TDoubles);
var
  LMed: Double;
begin
  LMed := MedianNanos(AVals);
  WriteLn(TextFormat('%-22s %10.1f ns/op %12.0f ops/sec',
    [AName, LMed, 1e9 / LMed]));
end;

procedure CaseDecode;
begin
  GKeep := TryDecodeFrame(FRAME_JSON, GFrame);
end;

procedure CaseResolve;
begin
  GScript := BuildResolveScript(7, RESULT_JSON);
end;

procedure CaseReject;
begin
  GScript := BuildRejectScript(7, REJECT_CODE, REJECT_MSG);
end;

procedure CaseEmit;
begin
  GScript := BuildEmitScript(EVENT_NAME, EVENT_PAYLOAD);
end;

procedure CaseIsOversized;
var
  LView: TStringView;
begin
  LView := TStringView.FromStr(FRAME_JSON);
  GKeep := IsWebviewFrameOversizedView(LView);
end;

procedure CaseIsOversizedExpanded;
var
  LView, LPayload: TStringView;
begin
  LView := TStringView.FromStr(FRAME_JSON);
  LPayload := TStringView.FromStr('{"a":1}');
  GKeep := IsWebviewFrameOversizedExpanded(LView, LPayload);
end;

procedure TimeCase(const AName: string; AOnce: TWebviewProc);
var
  LVals: TDoubles;
  LR, I: Integer;
  T0: UInt64;
begin
  SetLength(LVals, RUNS);
  for LR := 0 to RUNS - 1 do
  begin
    T0 := platform_monotonic_ns;
    for I := 1 to ITER do
      AOnce();
    LVals[LR] := (platform_monotonic_ns - T0) / ITER;
  end;
  Report(AName, LVals);
end;

var
  LScript: string;
begin
  { ---- 正确性抽检（计时前硬校验） ---- }
  if not TryDecodeFrame(FRAME_JSON, GFrame) then
  begin
    WriteLn('BENCH-ABORT decode broken');
    Halt(1);
  end;
  if (GFrame.Id <> 42) or (GFrame.Cmd <> 'demo.sum') or
     (Pos('"b":23', GFrame.Payload.ToString) = 0) then
  begin
    WriteLn('BENCH-ABORT decode fields wrong');
    Halt(1);
  end;
  LScript := BuildResolveScript(7, RESULT_JSON);
  if Pos('__resolve(7,', LScript) = 0 then
  begin
    WriteLn('BENCH-ABORT resolve script wrong');
    Halt(1);
  end;

  WriteLn('=== webview bridge protocol benchmark ===');
  WriteLn(TextFormat('iterations/run: %d, runs(median): %d', [ITER, RUNS]));

  TimeCase('TryDecodeFrame', @CaseDecode);
  TimeCase('BuildResolveScript', @CaseResolve);
  TimeCase('BuildRejectScript', @CaseReject);
  TimeCase('BuildEmitScript', @CaseEmit);
  TimeCase('IsOversizedView', @CaseIsOversized);
  TimeCase('IsOversizedExpanded', @CaseIsOversizedExpanded);

  { 防死代码消除：消费全部产物 }
  if (not GKeep) and (LScript = '') then
    WriteLn('unreachable');
end.
