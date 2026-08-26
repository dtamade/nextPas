program test_webview_bridge;
{ 桥协议 v1 唯一实现门禁：invoke 帧解码全判据矩阵、回执/事件 Eval 脚本
  构造（含转义 round-trip 属性验证）、错误码归一化、注入脚本不变量、
  fake 后端完整走协议栈（DeliverFrame → outcome + resolve/reject 回执捕获、
  异步 marshal 回执时序、非法帧 EWebviewBadFrame、关闭后拒绝）。
  heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.json,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.bridge,
  nextpas.core.webview.fake;

var
  { handler 收到的 payload 文本（canonicalization 断言用） }
  GLastPayload: string;

function MakeEcho(const ATag: string): TWebviewInvokeSyncHandler;
begin
  Result :=
    function(const APayloadJson: string): string
    begin
      GLastPayload := APayloadJson;
      Result := '{"tag":"' + ATag + '"}';
    end;
end;

procedure TestDecodeValidMatrix;
var
  LFrame: TWebviewFrame;
begin
  { 全字段帧 }
  Check(TryDecodeFrame('{"v":1,"id":42,"cmd":"ping","payload":{"hello":"world"}}',
    LFrame), 'full frame decodes');
  CheckEqual(Int64(42), LFrame.Id);
  CheckEqual('ping', LFrame.Cmd);
  CheckEqual('{"hello":"world"}', LFrame.PayloadJson);

  { payload 缺省 → 'null' }
  Check(TryDecodeFrame('{"v":1,"id":1,"cmd":"a"}', LFrame), 'absent payload');
  CheckEqual('null', LFrame.PayloadJson);

  { payload 显式 null → 'null' }
  Check(TryDecodeFrame('{"v":1,"id":1,"cmd":"a","payload":null}', LFrame),
    'explicit null payload');
  CheckEqual('null', LFrame.PayloadJson);

  { 标量/数组 payload 规范化保真 }
  Check(TryDecodeFrame('{"v":1,"id":2,"cmd":"a","payload":"txt"}', LFrame),
    'string payload');
  CheckEqual('"txt"', LFrame.PayloadJson);
  Check(TryDecodeFrame('{"v":1,"id":3,"cmd":"a","payload":[1, 2, 3]}', LFrame),
    'array payload canonicalized');
  CheckEqual('[1,2,3]', LFrame.PayloadJson);

  { u53 上边界内可解 }
  Check(TryDecodeFrame('{"v":1,"id":9007199254740991,"cmd":"a"}', LFrame),
    'max safe id');
  CheckEqual(Int64(9007199254740991), LFrame.Id);
end;

procedure TestDecodeInvalidMatrix;
const
  BAD: array[0..12] of string = (
    '',                                     { 空文本 }
    'not json',                             { 非法 JSON }
    '[1,2]',                                { 顶层非对象 }
    '{"id":1,"cmd":"c"}',                   { v 缺失 }
    '{"v":2,"id":1,"cmd":"c"}',             { 版本不符 }
    '{"v":"1","id":1,"cmd":"c"}',           { v 非整数 }
    '{"v":1.0,"id":1,"cmd":"c"}',           { v 浮点 }
    '{"v":1,"cmd":"c"}',                    { id 缺失 }
    '{"v":1,"id":0,"cmd":"c"}',             { id 非正 }
    '{"v":1,"id":-5,"cmd":"c"}',            { id 负数 }
    '{"v":1,"id":"7","cmd":"c"}',           { id 非整数 }
    '{"v":1,"id":9007199254740992,"cmd":"c"}', { id 超 u53 }
    '{"v":1,"id":1}'                        { cmd 缺失 }
  );
var
  I: Integer;
  LFrame: TWebviewFrame;
begin
  for I := Low(BAD) to High(BAD) do
    Check(not TryDecodeFrame(BAD[I], LFrame),
      'bad frame rejected #' + IntToStr(I));
  { cmd 空/非字符串单测（表内放不下带引号转义的行） }
  Check(not TryDecodeFrame('{"v":1,"id":1,"cmd":""}', LFrame), 'empty cmd');
  Check(not TryDecodeFrame('{"v":1,"id":1,"cmd":7}', LFrame), 'non-string cmd');
end;

procedure TestResolveBuilder;
begin
  CheckEqual('__npw.__resolve(42,"{\"pong\":true}")',
    BuildResolveScript(42, '{"pong":true}'), 'resolve exact text');
  CheckEqual('__npw.__resolve(9,"null")',
    BuildResolveScript(9, ''), 'resolve empty result as null');
  CheckEqual('__npw.__resolve(0,"1")',
    BuildResolveScript(0, '1'), 'scalar result embeds');
end;

procedure TestRejectBuilder;
var
  LFull: string;
  LInner: string;
  LParsed: IJsonDocument;
  LMiddle: string;
begin
  { 无特殊字符：精确文本 }
  CheckEqual(
    '__npw.__reject(7,"{\"code\":\"app.x\",\"message\":\"boom\"}")',
    BuildRejectScript(7, 'app.x', 'boom'), 'reject exact text');

  { 空码补默认 npw.bad_request }
  Check(Pos('npw.bad_request',
    BuildRejectScript(1, '', 'late')) > 0, 'default code embedded');

  { 含引号消息：嵌入字面量必须是合法 JSON 字符串，解析还原原文 }
  LInner := '{"code":"a.b","message":"he said \"hi\""}';
  LFull := BuildRejectScript(8, 'a.b', 'he said "hi"');
  Check(Pos('__npw.__reject(8,', LFull) = 1, 'escaping prefix');
  LMiddle := Copy(LFull, Length('__npw.__reject(8,') + 1,
    Length(LFull) - Length('__npw.__reject(8,') - 1);
  Check(TryJsonParse(LMiddle, LParsed), 'embedded literal is valid JSON');
  CheckEqual(LInner, LParsed.Root.AsStr.ToString, 'round-trip restores message');
end;

procedure TestEmitBuilder;
begin
  CheckEqual('__npw.__emit("tick","{\"n\":3}")',
    BuildEmitScript('tick', '{"n":3}'), 'emit exact text');
  CheckEqual('__npw.__emit("tick","null")',
    BuildEmitScript('tick', ''), 'emit empty payload as null');
  try
    BuildEmitScript('', '{}');
    Check(False, 'empty event must raise');
  except
    on E: EWebviewInvalidState do
      Check(True, '');
  end;
end;

procedure TestNormalizeInvokeCode;
begin
  CheckEqual('npw.bad_request', NormalizeInvokeCode(''), 'empty to default');
  CheckEqual('app.quota', NormalizeInvokeCode('app.quota'), 'custom passthrough');
  CheckEqual('npw.handler_missing', NormalizeInvokeCode('npw.handler_missing'),
    'vocab passthrough');
end;

procedure TestBridgeScriptInvariants;
const
  TOKENS: array[0..10] of string = (
    'window.__npw',
    '__resolve',
    '__reject',
    '__emit',
    'ready:',
    'messageHandlers.npw',
    'chrome.webview',
    'JSON.parse',
    'Object.freeze',
    '9007199254740991',
    'version: 1'
  );
var
  I: Integer;
begin
  Check(NPW_BRIDGE_SCRIPT <> '', 'script non-empty');
  for I := Low(TOKENS) to High(TOKENS) do
    Check(Pos(TOKENS[I], NPW_BRIDGE_SCRIPT) > 0,
      'script invariant: ' + TOKENS[I]);
end;

procedure TestFakeFrameHappyPath;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    W.Invokes.Register('echo', MakeEcho('ok'));

    { 对照组：driver 直呼不产生回执 }
    LFake.DeliverInvoke('echo', '{}');
    CheckEqual(0, LFake.CaptureEvalCount, 'driver path leaves no receipt');

    GLastPayload := '';
    LFake.DeliverFrame('{"v":1,"id":42,"cmd":"echo","payload":{"x": 1}}');
    CheckEqual(2, LFake.OutcomeCount, 'frame outcome recorded');
    Check(LFake.LastOutcome.IsError = False, 'frame outcome ok');
    CheckEqual('{"tag":"ok"}', LFake.LastOutcome.ResultJson, 'result json');

    { payload 经 json owner 规范化（空格剥离） }
    CheckEqual('{"x":1}', GLastPayload, 'payload canonicalized');

    { 回执脚本：id 回显 + 结果以字符串字面量嵌入 }
    CheckEqual(1, LFake.CaptureEvalCount, 'one receipt');
    CheckEqual('__npw.__resolve(42,"{\"tag\":\"ok\"}")',
      LFake.CaptureEvalAt(0), 'resolve receipt text');
  finally
    W := nil;
  end;
end;

procedure TestFakeFrameErrorReceipts;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    { handler 抛自定义错误码：透传进 reject }
    W.Invokes.Register('quota',
      function(const APayloadJson: string): string
      begin
        raise EWebviewInvokeError.Create('over limit', 'app.quota');
        Result := '';
      end);
    LFake.DeliverFrame('{"v":1,"id":7,"cmd":"quota"}');
    Check(LFake.LastOutcome.IsError, 'quota outcome error');
    CheckEqual('app.quota', LFake.LastOutcome.Code, 'code passthrough');
    CheckEqual(
      '__npw.__reject(7,"{\"code\":\"app.quota\",\"message\":\"over limit\"}")',
      LFake.CaptureEvalAt(0), 'custom code reject text');

    { 未注册 cmd：handler_missing 回执 }
    LFake.DeliverFrame('{"v":1,"id":9,"cmd":"nope"}');
    CheckEqual('npw.handler_missing', LFake.LastOutcome.Code, 'missing cmd');
    CheckEqual(
      '__npw.__reject(9,"{\"code\":\"npw.handler_missing\",\"message\":\"no handler registered for cmd\"}")',
      LFake.CaptureEvalAt(1), 'missing cmd reject text');
  finally
    W := nil;
  end;
end;

procedure TestFakeFrameInvalidRaisesBadFrame;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
  LRaised: Boolean;

  procedure ExpectBadFrame(const AJson: string);
  begin
    LRaised := False;
    try
      LFake.DeliverFrame(AJson);
    except
      on E: EWebviewBadFrame do LRaised := True;
    end;
    Check(LRaised, 'expected EWebviewBadFrame for: ' + AJson);
  end;

begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    W.Invokes.Register('echo', MakeEcho('x'));
    ExpectBadFrame('not json');
    ExpectBadFrame('{"v":2,"id":1,"cmd":"echo"}');
    ExpectBadFrame('{"v":1,"id":0,"cmd":"echo"}');
    CheckEqual(0, LFake.OutcomeCount, 'no outcome from bad frames');
    CheckEqual(0, LFake.CaptureEvalCount, 'no receipt from bad frames');
  finally
    W := nil;
  end;
end;

procedure TestFakeFrameAsyncMarshalReceipt;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    W.Invokes.RegisterAsync('slow.calc',
      procedure(const APayloadJson: string;
        const ACompletion: IWebviewInvokeCompletion)
      begin
        ACompletion.Ok('{"done":true}');
      end);

    LFake.DeliverFrame('{"v":1,"id":5,"cmd":"slow.calc"}');
    CheckEqual(0, LFake.OutcomeCount, 'async not settled before pump');
    CheckEqual(0, LFake.CaptureEvalCount, 'receipt waits for pump');

    LFake.PumpAll;
    CheckEqual(1, LFake.OutcomeCount, 'settled after pump');
    CheckEqual(1, LFake.CaptureEvalCount, 'receipt after pump');
    CheckEqual('__npw.__resolve(5,"{\"done\":true}")',
      LFake.CaptureEvalAt(0), 'async resolve receipt');
  finally
    W := nil;
  end;
end;

procedure TestFakeFrameClosedWindow;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
  LRaised: Boolean;
begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    W.Close;
    LRaised := False;
    try
      LFake.DeliverFrame('{"v":1,"id":1,"cmd":"echo"}');
    except
      on E: EWebviewClosed do LRaised := True;
    end;
    Check(LRaised, 'closed window rejects frames');
  finally
    W := nil;
  end;
end;

{ ---- 资产前缀路由：TWebviewAssetsImpl 行为钉死（CONTRACT §3）---- }

type
  TProbeEntry = record
    Key: string;
    Mime: string;
  end;

  { 记录型 provider：捕获收到的路径形态，按表命中 }
  TProbeProvider = class(TInterfacedObject, IWebviewAssetProvider)
  public
    LastPath: string;
    Table: array of TProbeEntry;
    function TryResolve(const APath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
  end;

function TProbeProvider.TryResolve(const APath: string;
  out ABytes: TBytes; out AMimeType: string): Boolean;
var
  I: Integer;
begin
  LastPath := APath;
  AMimeType := 'text/plain';
  Result := False;
  for I := 0 to High(Table) do
    if Table[I].Key = APath then
    begin
      SetLength(ABytes, 1);
      ABytes[0] := Ord('x');
      AMimeType := Table[I].Mime;
      Exit(True);
    end;
end;

procedure TestAssetsPrefixRouting;
var
  LAssets: IWebviewAssets;
  LRoot, LStatic: TProbeProvider;
  LBytes: TBytes;
  LMime: string;
begin
  LRoot := TProbeProvider.Create;
  SetLength(LRoot.Table, 1);
  LRoot.Table[0].Key := 'page.html';
  LRoot.Table[0].Mime := 'text/html';
  LStatic := TProbeProvider.Create;
  SetLength(LStatic.Table, 2);
  LStatic.Table[0].Key := 'static/a.js';
  LStatic.Table[0].Mime := 'text/javascript';
  LStatic.Table[1].Key := 'other.txt';
  LStatic.Table[1].Mime := 'text/plain';

  LAssets := TWebviewAssetsImpl.Create;
  LAssets.MountEmbedded('', LRoot);        { 根挂载：空前缀匹配一切 }
  LAssets.MountEmbedded('static', LStatic);

  { 命中：最长前缀胜过根挂载；provider 收到剥离后的相对路径 }
  Check(LAssets.TryResolve('/static/a.js', LBytes, LMime), 'longest prefix hit');
  CheckEqual(LStatic.LastPath, 'static/a.js', 'provider gets stripped path');
  CheckEqual(LMime, 'text/javascript', 'mime from winning provider');

  { 空前缀回退（FPC Pos('',s)=0 回归钉死） }
  Check(LAssets.TryResolve('page.html', LBytes, LMime), 'root mount fallback');
  CheckEqual(LRoot.LastPath, 'page.html', 'root provider path form');

  { 多余前导斜杠统一归一；命名空间内未命中不跨挂载回退 }
  Check(not LAssets.TryResolve('//static/other.txt', LBytes, LMime),
    'namespace miss does not fall through');
  CheckEqual(LStatic.LastPath, 'static/other.txt', 'routed to owning namespace');
end;

procedure TestAssetsMissAndValidation;
var
  LAssets, LFresh: IWebviewAssets;
  LProv: TProbeProvider;
  LBytes: TBytes;
  LMime: string;
  LRaised: Boolean;
begin
  LProv := TProbeProvider.Create;
  LAssets := TWebviewAssetsImpl.Create;
  LAssets.MountEmbedded('app', LProv);

  Check(not LAssets.TryResolve('zzz.bin', LBytes, LMime), 'unmatched prefix misses');
  Check(not LAssets.TryResolve('', LBytes, LMime), 'empty path misses');
  Check(not LAssets.TryResolve('app/nope.txt', LBytes, LMime),
    'prefix hit but table miss is provider False');

  { 先持引用再触发拒绝路径——实例随接口变量收尾释放（heaptrc 0） }
  LFresh := TWebviewAssetsImpl.Create;
  LRaised := False;
  try
    LFresh.MountEmbedded('', nil);
  except
    on E: EWebviewInvalidState do LRaised := True;
  end;
  Check(LRaised, 'nil provider rejected');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.bridge');
  T.Test('decode valid matrix', @TestDecodeValidMatrix);
  T.Test('decode invalid matrix', @TestDecodeInvalidMatrix);
  T.Test('resolve builder', @TestResolveBuilder);
  T.Test('reject builder', @TestRejectBuilder);
  T.Test('emit builder', @TestEmitBuilder);
  T.Test('normalize invoke code', @TestNormalizeInvokeCode);
  T.Test('bridge script invariants', @TestBridgeScriptInvariants);
  T.Test('fake frame happy path', @TestFakeFrameHappyPath);
  T.Test('fake frame error receipts', @TestFakeFrameErrorReceipts);
  T.Test('fake frame invalid raises bad frame',
    @TestFakeFrameInvalidRaisesBadFrame);
  T.Test('fake frame async marshal receipt', @TestFakeFrameAsyncMarshalReceipt);
  T.Test('fake frame closed window', @TestFakeFrameClosedWindow);
  T.Test('assets prefix routing', @TestAssetsPrefixRouting);
  T.Test('assets miss and validation', @TestAssetsMissAndValidation);
  if not T.Run then Halt(1);
end.
