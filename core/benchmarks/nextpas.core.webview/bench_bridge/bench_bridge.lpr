program bench_bridge;
{** @desc bench: 桥协议热路径基线（bench 框架版）。
       计时前硬校验正确性，暴露解码/回执构造吞吐与退化曲线。
       框架：nextpas.core.bench，禁自定义计时。 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.base,
  nextpas.core.webview.base,
  nextpas.core.webview.bridge;

const
  FRAME_JSON = '{"v":1,"id":42,"cmd":"demo.sum","payload":{"a":19,"b":23,"name":"npw"}}';
  RESULT_JSON = '{"sum":42,"items":[1,2,3]}';
  REJECT_CODE = 'npw.demo.bad_payload';
  REJECT_MSG = 'payload must be a JSON object';
  EVENT_NAME = 'demo.event';
  EVENT_PAYLOAD = '{"note":"pushed from Pascal","seq":7}';

var
  GFrame: TWebviewFrame;
  GSink: string = '';
  GKeep: Boolean = False;

procedure CheckSetup;
var
  LScript: string;
begin
  if not TryDecodeFrame(FRAME_JSON, GFrame) then
    raise Exception.Create('setup: decode broken');
  if (GFrame.Id <> 42) or (GFrame.Cmd <> 'demo.sum') then
    raise Exception.Create('setup: decode fields wrong');
  if Pos('"b":23', GFrame.PayloadJson) = 0 then
    raise Exception.Create('setup: payload canonicalization broken');
  LScript := BuildResolveScript(7, RESULT_JSON);
  if Pos('__resolve(7,', LScript) = 0 then
    raise Exception.Create('setup: resolve script wrong');
  LScript := BuildRejectScript(7, REJECT_CODE, REJECT_MSG);
  if Pos('__reject(7,', LScript) = 0 then
    raise Exception.Create('setup: reject script wrong');
  LScript := BuildEmitScript(EVENT_NAME, EVENT_PAYLOAD);
  if Pos('__emit(', LScript) = 0 then
    raise Exception.Create('setup: emit script wrong');
  GSink := LScript;
end;

procedure BenchDecode(const ACtx: IBenchContext);
begin
  GKeep := TryDecodeFrame(FRAME_JSON, GFrame);
  GSink := GFrame.Cmd;
end;

procedure BenchResolve(const ACtx: IBenchContext);
begin
  GSink := BuildResolveScript(7, RESULT_JSON);
end;

procedure BenchReject(const ACtx: IBenchContext);
begin
  GSink := BuildRejectScript(7, REJECT_CODE, REJECT_MSG);
end;

procedure BenchEmit(const ACtx: IBenchContext);
begin
  GSink := BuildEmitScript(EVENT_NAME, EVENT_PAYLOAD);
end;

var
  LSuite: IBenchSuite;
begin
  CheckSetup;
  LSuite := TBenchSuite.Create('bridge-protocol');
  LSuite.Add('TryDecodeFrame', @BenchDecode);
  LSuite.Add('BuildResolveScript', @BenchResolve);
  LSuite.Add('BuildRejectScript', @BenchReject);
  LSuite.Add('BuildEmitScript', @BenchEmit);
  WriteLn(LSuite.Run.PrintToConsole);
  WriteLn('sink=', Length(GSink), ' keep=', GKeep);
end.
