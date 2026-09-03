program test_webview_fake_eval;
{ Eval 异步契约门禁：预载 FIFO 顺序、pending→Queue 兑现、
  exactly-one（INV-7）、Close 时在途统一 EWebviewEvalFailed 收尾、
  closed 后 Eval 拒绝。heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.fake,
  nextpas.core.webview.factory, nextpas.core.exception;

procedure TestQueuedResultImmediate;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
  LGot: string;
  LErrs: Integer;
begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    LFake.QueueEvalResult('{"n":42}');
    W.Eval('answer()',
      procedure(const AResultJson: string)
      begin
        LGot := AResultJson;
      end,
      procedure(const AError: Exception)
      begin
        LErrs := LErrs + 1;
      end);
    CheckEqual('{"n":42}', LGot);
    Check(LFake.EvalRecordAt(0).Answered, 'record answered');
    CheckEqual('{"n":42}', LFake.EvalRecordAt(0).ResultJson);
    CheckEqual('', LFake.EvalRecordAt(0).ErrorMessage);
  finally
    W := nil;
  end;
end;

procedure TestQueuedErrorPath;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
  LOks: Integer;
  LErrMsg: string;
begin
  LOks := 0;
  LErrMsg := '';
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    LFake.QueueEvalError('engine exploded');
    W.Eval('boom()',
      procedure(const AResultJson: string)
      begin
        LOks := LOks + 1;
      end,
      procedure(const AError: Exception)
      begin
        Check(AError is EWebviewEvalFailed, 'error must be EWebviewEvalFailed');
        LErrMsg := AError.Message;
      end);
    CheckEqual(0, LOks, 'callback must not fire on error path');
    CheckEqual('engine exploded', LErrMsg);
    CheckEqual('engine exploded', LFake.EvalRecordAt(0).ErrorMessage);
  finally
    W := nil;
  end;
end;

procedure TestFifoOrder;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
  LOrder: string;
begin
  LOrder := '';
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    LFake.QueueEvalResult('"1"');
    LFake.QueueEvalResult('"2"');
    LFake.QueueEvalResult('"3"');
    W.Eval('1', procedure(const AResultJson: string)
      begin
        LOrder := LOrder + AResultJson;
      end,
      procedure(const AError: Exception) begin end);
    W.Eval('2', procedure(const AResultJson: string)
      begin
        LOrder := LOrder + AResultJson;
      end,
      procedure(const AError: Exception) begin end);
    W.Eval('3', procedure(const AResultJson: string)
      begin
        LOrder := LOrder + AResultJson;
      end,
      procedure(const AError: Exception) begin end);
    CheckEqual('"1""2""3"', LOrder, 'FIFO order preserved');
  finally
    W := nil;
  end;
end;

procedure TestPendingThenSettledExactlyOnce;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
  LOks: Integer;
  LErrs: Integer;
begin
  LOks := 0;
  LErrs := 0;
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    W.Eval('slow()',
      procedure(const AResultJson: string)
      begin
        LOks := LOks + 1;
      end,
      procedure(const AError: Exception)
      begin
        LErrs := LErrs + 1;
      end);
    CheckEqual(0, LOks + LErrs, 'no settle before answer');
    Check(not LFake.EvalRecordAt(0).Answered, 'pending unanswered');

    { 预载到达：兑现最老 pending，恰好一次 }
    LFake.QueueEvalResult('"late"');
    CheckEqual(1, LOks, 'exactly one callback');
    CheckEqual(0, LErrs, 'error callback untouched');
    Check(LFake.EvalRecordAt(0).Answered, 'answered');
    CheckEqual('"late"', LFake.EvalRecordAt(0).ResultJson);

    { 再 Queue 无 pending → 进预载 FIFO，不产生新回调 }
    LFake.QueueEvalResult('"spare"');
    CheckEqual(1, LOks + LErrs, 'still exactly one');
  finally
    W := nil;
  end;
end;

procedure TestCloseResolvesPendingAsError;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
  LOks: Integer;
  LErrMsg: string;
begin
  LOks := 0;
  LErrMsg := '';
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  W.Eval('never.answers()',
    procedure(const AResultJson: string)
    begin
      LOks := LOks + 1;
    end,
    procedure(const AError: Exception)
    begin
      LErrMsg := AError.Message;
    end);
  W.Close;
  CheckEqual(0, LOks, 'success callback must not fire after close');
  CheckEqual('window closed', LErrMsg);
  Check(LFake.EvalRecordAt(0).Answered, 'settled by close');
  CheckEqual('window closed',
    LFake.EvalRecordAt(0).ErrorMessage);
end;

procedure TestEvalAfterCloseRaises;
var
  W: IWebviewWindow;
  LRaised: Boolean;
begin
  W := CreateFakeWebview(DefaultWebviewOptions);
  W.Close;
  LRaised := False;
  try
    W.Eval('1+1',
      procedure(const AResultJson: string) begin end,
      procedure(const AError: Exception) begin end);
  except
    on E: EWebviewClosed do LRaised := True;
  end;
  Check(LRaised, 'eval after close must raise EWebviewClosed');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.fake.eval');
  T.Test('queued result immediate', @TestQueuedResultImmediate);
  T.Test('queued error path', @TestQueuedErrorPath);
  T.Test('fifo order', @TestFifoOrder);
  T.Test('pending then settled exactly once',
    @TestPendingThenSettledExactlyOnce);
  T.Test('close resolves pending as error',
    @TestCloseResolvesPendingAsError);
  T.Test('eval after close raises', @TestEvalAfterCloseRaises);
  if not T.Run then Halt(1);
end.
