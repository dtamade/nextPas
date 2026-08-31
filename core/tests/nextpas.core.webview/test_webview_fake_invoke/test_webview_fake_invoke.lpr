program test_webview_fake_invoke;
{ invoke 注册表与分发矩阵：同步/异步 handler 三形式、异常→协议错误码
  映射（EWebviewInvokeError 空码补默认/非空透传/其他异常 handler_error）、
  保留命名空间、重复注册、completion at-most-once、跨线程 Ok/Fail
  marshal 与跨线程 Post。heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  cthreads,
  SysUtils,
  Classes,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.fake,
  nextpas.core.webview.factory,
  nextpas.core.window.intf;

type
  { 跨线程 Post 测试载体：worker 只投递，主线程泵 — 已复用 IWindowDispatcher 单队列 }
  TPostWorker = class(TThread)
  public
    Disp: IWindowDispatcher;
    procedure Execute; override;
  end;

var
  GPostCounter: Integer = 0;

procedure TPostWorker.Execute;
begin
  Disp.Post(procedure
    begin
      GPostCounter := GPostCounter + 1;
    end);
end;

procedure TestSyncHandlerForms;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    { 匿名函数形 }
    W.Invokes.Register('a.anon',
      function(const APayloadJson: string): string
      begin
        Result := '{"via":"anon"}';
      end);

    { method 形 }
    LFake.DeliverInvoke('a.anon', '{}');
    CheckEqual(1, LFake.OutcomeCount);
    Check(not LFake.LastOutcome.IsError, 'anon outcome ok');
    CheckEqual('{"via":"anon"}', LFake.LastOutcome.ResultJson);

    { proc 形 }
    W.Invokes.Register('b.proc',
      function(const APayloadJson: string): string
      begin
        Result := 'null';
      end);
    LFake.DeliverInvoke('b.proc', '{}');
    CheckEqual('null', LFake.LastOutcome.ResultJson);
  finally
    W := nil;
  end;
end;

function MakeEcho(const ATag: string): TWebviewInvokeSyncHandler;
begin
  Result :=
    function(const APayloadJson: string): string
    begin
      Result := '{"tag":"' + ATag + '"}';
    end;
end;

procedure TestBuilderStyleRegistration;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
begin
  { Kind(wvFake) 钉确定性后端：缺省 kind 在探测到 WebKitGTK 的机器上
    是 wvGtk，FromWindow 判别与 DeliverInvoke 驱动只对 fake 成立 }
  W := TWebviewBuilder.New
    .Kind(wvFake)
    .RegisterInvoke('echo', MakeEcho('builder'))
    .Build;
  try
    LFake := TFakeWebview.FromWindow(W);
    Check(Assigned(LFake), 'FromWindow resolves builder product');
    LFake.DeliverInvoke('echo', '{}');
    CheckEqual('{"tag":"builder"}', LFake.LastOutcome.ResultJson);
  finally
    if not W.IsClosed then
      W.Close;
    W := nil;
  end;
end;

procedure TestAsyncCompletionMarshal;
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

    LFake.DeliverInvoke('slow.calc', '{}');
    { completion 经 dispatcher marshal：未泵前无 outcome }
    Check(LFake.PendingPosts > 0, 'marshal queued before pump');
    CheckEqual(0, LFake.OutcomeCount);
    LFake.PumpAll;
    CheckEqual(1, LFake.OutcomeCount);
    CheckEqual('{"done":true}', LFake.LastOutcome.ResultJson);

    { Fail 路径同样经 marshal }
    W.Invokes.RegisterAsync('slow.fail',
      procedure(const APayloadJson: string;
        const ACompletion: IWebviewInvokeCompletion)
      begin
        ACompletion.Fail('app.denied', 'nope');
      end);
    LFake.DeliverInvoke('slow.fail', '{}');
    LFake.PumpAll;
    Check(LFake.LastOutcome.IsError, 'fail outcome');
    CheckEqual('app.denied', LFake.LastOutcome.Code);
  finally
    W := nil;
  end;
end;

procedure TestExceptionToErrorCodeMapping;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    { EWebviewInvokeError 非空码透传 }
    W.Invokes.Register('x.quota',
      function(const APayloadJson: string): string
      begin
        raise EWebviewInvokeError.Create('over limit', 'app.quota');
        Result := '';
      end);
    LFake.DeliverInvoke('x.quota', '{}');
    Check(LFake.LastOutcome.IsError, 'quota error');
    CheckEqual('app.quota', LFake.LastOutcome.Code);
    CheckEqual('over limit', LFake.LastOutcome.Message);

    { EWebviewInvokeError 空码 → 默认 npw.bad_request }
    W.Invokes.Register('x.badreq',
      function(const APayloadJson: string): string
      begin
        raise EWebviewInvokeError.Create('bad input', '');
        Result := '';
      end);
    LFake.DeliverInvoke('x.badreq', '{}');
    CheckEqual('npw.bad_request', LFake.LastOutcome.Code);

    { 其他异常 → npw.handler_error，消息原文 }
    W.Invokes.Register('x.boom',
      function(const APayloadJson: string): string
      begin
        raise Exception.Create('kaboom');
        Result := '';
      end);
    LFake.DeliverInvoke('x.boom', '{}');
    CheckEqual('npw.handler_error', LFake.LastOutcome.Code);
    CheckEqual('kaboom', LFake.LastOutcome.Message);

    { 未注册 cmd → npw.handler_missing }
    LFake.DeliverInvoke('missing.cmd', '{}');
    CheckEqual('npw.handler_missing', LFake.LastOutcome.Code);
  finally
    W := nil;
  end;
end;

procedure TestReservedAndDuplicateRegistration;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
  LRaised: Boolean;

  procedure ExpectInvalid(AProc: TTestClosure);
  begin
    LRaised := False;
    try
      AProc();
    except
      on E: EWebviewInvalidState do LRaised := True;
    end;
    Check(LRaised, 'expected EWebviewInvalidState');
  end;

begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    ExpectInvalid(procedure
      begin
        W.Invokes.Register('', TWebviewInvokeSyncHandler(nil));
      end);
    ExpectInvalid(procedure
      begin
        W.Invokes.Register('npw.x', TWebviewInvokeSyncHandler(nil));
      end);
    ExpectInvalid(procedure
      begin
        W.Invokes.Register('_p', TWebviewInvokeSyncHandler(nil));
      end);

    W.Invokes.Register('dup',
      function(const APayloadJson: string): string
      begin
        Result := '1';
      end);
    ExpectInvalid(procedure
      begin
        W.Invokes.Register('dup',
          function(const APayloadJson: string): string
          begin
            Result := '2';
          end);
      end);

    { Unregister 后可重注册；未注册的 Unregister 是静默 no-op }
    W.Invokes.Unregister('dup');
    W.Invokes.Unregister('never-existed');
    W.Invokes.Register('dup',
      function(const APayloadJson: string): string
      begin
        Result := '3';
      end);
    LFake.DeliverInvoke('dup', '{}');
    CheckEqual('3', LFake.LastOutcome.ResultJson);
  finally
    W := nil;
  end;
end;

procedure TestCompletionAtMostOnce;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
  LSecondRaise: Boolean;
begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    W.Invokes.RegisterAsync('once.only',
      procedure(const APayloadJson: string;
        const ACompletion: IWebviewInvokeCompletion)
      begin
        ACompletion.Ok('{}');
        try
          ACompletion.Ok('{}');
          Check(False, 'second Ok must raise');
        except
          on E: EWebviewInvalidState do ;   { at-most-once 契约 }
        end;
        try
          ACompletion.Fail('npw.closed', 'late');
          Check(False, 'Fail after Ok must raise');
        except
          on E: EWebviewInvalidState do ;
        end;
      end);
    LFake.DeliverInvoke('once.only', '{}');
    LFake.PumpAll;
    CheckEqual(1, LFake.OutcomeCount);
  finally
    W := nil;
  end;
end;

procedure TestCrossThreadPostAndCompletion;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
  Worker: TPostWorker;
begin
  GPostCounter := 0;
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    Worker := TPostWorker.Create(True);
    try
      Worker.Disp := W.Window.Dispatcher;
      Worker.Start;
      Worker.WaitFor;
    finally
      Worker.Free;
    end;
    CheckEqual(1, LFake.PendingPosts, 'queued from worker thread');
    LFake.PumpOnce;
    CheckEqual(1, GPostCounter, 'closure executed on pumping thread');

    { 跨线程 completion：异步 handler 在 worker 里调 Fail，
      outcome 必须落回主线程泵 }
    W.Invokes.RegisterAsync('thread.fail',
      procedure(const APayloadJson: string;
        const ACompletion: IWebviewInvokeCompletion)
      var
        LT: TThread;
      begin
        LT := TThread.CreateAnonymousThread(
          procedure
          begin
            ACompletion.Fail('app.async', 'from worker');
          end);
        LT.Start;
        LT.WaitFor;
      end);
    LFake.DeliverInvoke('thread.fail', '{}');
    CheckEqual(0, LFake.OutcomeCount, 'not settled before pump');
    LFake.PumpAll;
    CheckEqual('app.async', LFake.LastOutcome.Code);
  finally
    W := nil;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.fake.invoke');
  T.Test('sync handler forms', @TestSyncHandlerForms);
  T.Test('builder style registration', @TestBuilderStyleRegistration);
  T.Test('async completion marshal', @TestAsyncCompletionMarshal);
  T.Test('exception to error code mapping', @TestExceptionToErrorCodeMapping);
  T.Test('reserved and duplicate registration',
    @TestReservedAndDuplicateRegistration);
  T.Test('completion at most once', @TestCompletionAtMostOnce);
  T.Test('cross thread post and completion', @TestCrossThreadPostAndCompletion, 2);
  if not T.Run then Halt(1);
end.
