program test_streambox;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.agent.base,
  nextpas.core.agent.streambox,
  nextpas.core.test,
  nextpas.core.text.conv;

procedure TestBasicPushPop;
var
  Box: TAgentStreamBox;
  D, OutD: TStreamDelta;
begin
  Box := TAgentStreamBox.Create(42);
  try
    Check(Box.Id = 42, 'id kept');
    Check(not Box.IsDone, 'not done initially');
    D := Default(TStreamDelta);
    D.Kind := sdkTextDelta;
    D.TextDelta := 'hello';
    Box.Push(D, 42);
    Check(Box.TryPop(OutD), 'pop succeeds');
    Check(OutD.TextDelta = 'hello', 'fifo preserved');
    Check(not Box.TryPop(OutD), 'empty after pop');
  finally
    Box.Free;
  end;
end;

procedure TestFIFOOrder;
var
  Box: TAgentStreamBox;
  D: TStreamDelta;
  OutD: TStreamDelta;
  i: Integer;
begin
  Box := TAgentStreamBox.Create(7);
  try
    for i := 0 to 9 do
    begin
      D := Default(TStreamDelta);
      D.Kind := sdkTextDelta;
      D.TextDelta := 'msg' + IntToStr(i);
      Box.Push(D, 7);
    end;
    for i := 0 to 9 do
    begin
      Check(Box.TryPop(OutD), 'fifo pop ' + IntToStr(i));
      Check(OutD.TextDelta = 'msg' + IntToStr(i), 'order '+IntToStr(i));
    end;
    Check(not Box.TryPop(OutD), 'empty at end');
  finally
    Box.Free;
  end;
end;

procedure TestIdMismatchDropped;
var
  Box: TAgentStreamBox;
  D, OutD: TStreamDelta;
begin
  Box := TAgentStreamBox.Create(100);
  try
    D := Default(TStreamDelta);
    D.Kind := sdkTextDelta;
    D.TextDelta := 'stale';
    Box.Push(D, 99); // mismatch
    Check(not Box.TryPop(OutD), 'mismatch dropped');
    D.TextDelta := 'good';
    Box.Push(D, 100);
    Check(Box.TryPop(OutD), 'good accepted');
    Check(OutD.TextDelta = 'good', 'good content');
  finally
    Box.Free;
  end;
end;

procedure TestDoneBlocksPush;
var
  Box: TAgentStreamBox;
  D, OutD: TStreamDelta;
begin
  Box := TAgentStreamBox.Create(1);
  try
    D := Default(TStreamDelta);
    D.Kind := sdkTextDelta;
    D.TextDelta := 'before';
    Box.Push(D, 1);
    Box.MarkDone;
    Check(Box.IsDone, 'done flag');
    D.TextDelta := 'after';
    Box.Push(D, 1);
    // only before should be present
    Check(Box.TryPop(OutD), 'before still poppable');
    Check(OutD.TextDelta = 'before', 'before content');
    Check(not Box.TryPop(OutD), 'after dropped after done');
  finally
    Box.Free;
  end;
end;

procedure TestRingCompaction;
var
  Box: TAgentStreamBox;
  D, OutD: TStreamDelta;
  i: Integer;
begin
  Box := TAgentStreamBox.Create(5);
  try
    // push 200, pop 150, then push 50 more -> triggers compaction path FHead>64 and > half
    for i := 0 to 199 do
    begin
      D := Default(TStreamDelta);
      D.Kind := sdkTextDelta;
      D.TextDelta := 'x' + IntToStr(i);
      Box.Push(D, 5);
    end;
    for i := 0 to 149 do
    begin
      Check(Box.TryPop(OutD), 'pop pre ' + IntToStr(i));
      Check(OutD.TextDelta = 'x' + IntToStr(i), 'pre order');
    end;
    // now 50 remain (150..199), push 50 more
    for i := 200 to 249 do
    begin
      D := Default(TStreamDelta);
      D.Kind := sdkTextDelta;
      D.TextDelta := 'x' + IntToStr(i);
      Box.Push(D, 5);
    end;
    for i := 150 to 249 do
    begin
      Check(Box.TryPop(OutD), 'pop post ' + IntToStr(i));
      Check(OutD.TextDelta = 'x' + IntToStr(i), 'post order');
    end;
    Check(not Box.TryPop(OutD), 'empty after ring');
  finally
    Box.Free;
  end;
end;

procedure TestIntToStrHelper;
var
  s: string;
begin
  s := IntToStr(123);
  Check(s = '123', 'IntToStr sanity');
end;

var
  Suite: TTestSuite;
begin
  Suite := TTestSuite.Create('nextpas.core.agent.streambox');
  Suite.Test('basic push pop', @TestBasicPushPop);
  Suite.Test('fifo order', @TestFIFOOrder);
  Suite.Test('id mismatch dropped', @TestIdMismatchDropped);
  Suite.Test('done blocks push', @TestDoneBlocksPush);
  Suite.Test('ring compaction', @TestRingCompaction);
  Suite.Test('helper sanity', @TestIntToStrHelper);
  if not Suite.Run then Halt(1);
end.
