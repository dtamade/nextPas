program test_resilience;

{$I nextpas.core.settings.inc}

{ 刀 82 反哺：LLM 流式韧性原语门测——
  StreamHasError 断流指纹 / WaitCancelMs 取消感知毫秒等待（溢出守卫）/
  ClampHintMs 重试提示钳帽。
  锚三家：「等待或取消」在 grok-build(tokio select)/codex(run_until_cancelled)/
  opencode(Effect interrupt) 均为一等原语，ObjFPC 以库函数供给 }

uses
  nextpas.core.base,
  nextpas.core.thread,
  nextpas.core.thread.cancel,
  nextpas.core.agent.base,
  nextpas.core.agent.resilience,
  nextpas.core.test;

procedure TestStreamHasErrorFingerprint;
var
  Deltas: TStreamDeltaArray;
begin
  { 空流无指纹 }
  SetLength(Deltas, 0);
  CheckFalse(StreamHasError(Deltas, aecTransport), 'empty stream clean');

  { 非 error 帧（text/finish/usage）不构成指纹 }
  SetLength(Deltas, 2);
  Deltas[0] := Default(TStreamDelta);
  Deltas[0].Kind := sdkTextDelta;
  Deltas[0].TextDelta := 'par';
  Deltas[1] := Default(TStreamDelta);
  Deltas[1].Kind := sdkFinish;
  CheckFalse(StreamHasError(Deltas, aecTransport), 'no error frames');

  { 目标码命中 }
  SetLength(Deltas, 3);
  Deltas[2] := Default(TStreamDelta);
  Deltas[2].Kind := sdkError;
  Deltas[2].Error.Code := aecTransport;
  CheckTrue(StreamHasError(Deltas, aecTransport), 'transport fingerprint');

  { 只匹配指定码：同流对其他码无指纹 }
  CheckFalse(StreamHasError(Deltas, aecTimeout), 'code must match exactly');

  { 多帧中首位命中 }
  Deltas[0] := Default(TStreamDelta);
  Deltas[0].Kind := sdkError;
  Deltas[0].Error.Code := aecRateLimited;
  CheckTrue(StreamHasError(Deltas, aecRateLimited), 'first-frame hit');
end;

procedure TestWaitCancelMsGuards;
var
  Src: ICancellationSource;
begin
  { nil 源吸收：不等待不算取消 }
  CheckFalse(WaitCancelMs(nil, 5), 'nil source is not cancelled');
  Src := nil;
  CheckFalse(WaitCancelMs(Src, 5), 'nil var is not cancelled');

  { 非正延迟：只查已取消态，不等待 }
  Src := CreateCancellationSource;
  CheckFalse(WaitCancelMs(Src, 0), 'zero delay not cancelled');
  CheckFalse(WaitCancelMs(Src, -3), 'negative delay not cancelled');

  { ms→ns 溢出守卫：极端延迟立即返回 False 不挂死 }
  CheckFalse(WaitCancelMs(Src, High(Int64)), 'overflow guard skips wait');
end;

procedure TestWaitCancelMsCancelled;
var
  Src: ICancellationSource;
begin
  { 进入前已取消 → True（取消优先于退避） }
  Src := CreateCancellationSource;
  Src.Cancel;
  CheckTrue(WaitCancelMs(Src, 50), 'pre-cancelled wins');
end;

procedure TestWaitCancelMsFullWait;
var
  Src: ICancellationSource;
begin
  { 未取消的小等待：完整等待返回 False（未被取消） }
  Src := CreateCancellationSource;
  CheckFalse(WaitCancelMs(Src, 30), 'full wait returns false');
end;

procedure TestClampHintMsSemantics;
begin
  { 负数 = 无提示哨兵透传（调用方回退计算退避） }
  CheckEqual(Int64(-1), ClampHintMs(-1, 10000), 'negative passthrough');
  CheckEqual(Int64(-7), ClampHintMs(-7, 10000), 'negative passthrough any');
  { 正常直通 }
  CheckEqual(Int64(500), ClampHintMs(500, 10000), 'in-cap passthrough');
  { 帽边界与超帽钳制（防服务端长窗静默冻结重试循环） }
  CheckEqual(Int64(10000), ClampHintMs(10000, 10000), 'at cap boundary');
  CheckEqual(Int64(10000), ClampHintMs(99999, 10000), 'over cap clamped');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.resilience');
  T.Test('stream has error fingerprint', @TestStreamHasErrorFingerprint);
  T.Test('wait cancel ms guards', @TestWaitCancelMsGuards);
  T.Test('wait cancel ms pre-cancelled', @TestWaitCancelMsCancelled);
  T.Test('wait cancel ms full wait', @TestWaitCancelMsFullWait);
  T.Test('clamp hint ms semantics', @TestClampHintMsSemantics);
  if not T.Run then Halt(1);
end.
