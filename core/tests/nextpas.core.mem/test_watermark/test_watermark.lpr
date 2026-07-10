program test_watermark;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.watermark;

var
  T: TTestSuite;
  LRunPassed: Boolean;
  GHighFired: Integer;
  GCriticalFired: Integer;
  GLastLevel: TWatermarkLevel;
  GLastBytes: UInt64;

procedure OnHighWatermark(ALevel: TWatermarkLevel; AUsedBytes: UInt64);
begin
  Inc(GHighFired);
  GLastLevel := ALevel;
  GLastBytes := AUsedBytes;
end;

procedure OnCriticalWatermark(ALevel: TWatermarkLevel; AUsedBytes: UInt64);
begin
  Inc(GCriticalFired);
  GLastLevel := ALevel;
  GLastBytes := AUsedBytes;
end;

procedure ResetGlobals;
begin
  GHighFired := 0;
  GCriticalFired := 0;
  GLastLevel := wlNormal;
  GLastBytes := 0;
end;

procedure TestCreateAndDestroy;
var
  LW: TMemoryWatermark;
begin
  LW := TMemoryWatermark.Create(100, 200);
  try
    Check(LW.HighBytes = 100, 'HighBytes should be 100');
    Check(LW.CriticalBytes = 200, 'CriticalBytes should be 200');
    Check(LW.CurrentLevel = wlNormal, 'initial level should be normal');
  finally
    LW.Free;
  end;
end;

procedure TestInvalidThresholds;
var
  LW: TMemoryWatermark;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    LW := TMemoryWatermark.Create(200, 100); { critical < high }
    LW.Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'should raise when critical <= high');
end;

procedure TestNormalToHigh;
var
  LW: TMemoryWatermark;
begin
  ResetGlobals;
  LW := TMemoryWatermark.Create(100, 200);
  try
    LW.RegisterHandler(wlHigh, @OnHighWatermark);
    LW.Check(50); { below high }
    Check(GHighFired = 0, 'should not fire below high');
    Check(LW.CurrentLevel = wlNormal, 'should be normal');

    LW.Check(100); { at high }
    Check(GHighFired = 1, 'should fire at high');
    Check(LW.CurrentLevel = wlHigh, 'should be high');
    Check(GLastBytes = 100, 'should report used bytes');
  finally
    LW.Free;
  end;
end;

procedure TestHighToCritical;
var
  LW: TMemoryWatermark;
begin
  ResetGlobals;
  LW := TMemoryWatermark.Create(100, 200);
  try
    LW.RegisterHandler(wlHigh, @OnHighWatermark);
    LW.RegisterHandler(wlCritical, @OnCriticalWatermark);

    LW.Check(150); { high }
    Check(GHighFired = 1, 'should fire high');
    Check(GCriticalFired = 0, 'should not fire critical yet');

    LW.Check(200); { critical }
    Check(GCriticalFired = 1, 'should fire critical');
    Check(LW.CurrentLevel = wlCritical, 'should be critical');
  finally
    LW.Free;
  end;
end;

procedure TestNoRepeatFiring;
var
  LW: TMemoryWatermark;
begin
  ResetGlobals;
  LW := TMemoryWatermark.Create(100, 200);
  try
    LW.RegisterHandler(wlHigh, @OnHighWatermark);

    LW.Check(100); { high }
    Check(GHighFired = 1, 'should fire once');

    LW.Check(150); { still high }
    Check(GHighFired = 1, 'should not fire again at same level');

    LW.Check(200); { critical, but only wlHigh handler }
    Check(GHighFired = 1, 'should not fire high again');
  finally
    LW.Free;
  end;
end;

procedure TestDowngradeNoCallback;
var
  LW: TMemoryWatermark;
begin
  ResetGlobals;
  LW := TMemoryWatermark.Create(100, 200);
  try
    LW.RegisterHandler(wlHigh, @OnHighWatermark);

    LW.Check(150); { high }
    Check(GHighFired = 1, 'should fire high');

    LW.Check(50); { back to normal }
    Check(GHighFired = 1, 'should not fire on downgrade');
    Check(LW.CurrentLevel = wlNormal, 'should be normal');
  finally
    LW.Free;
  end;
end;

procedure TestNilHandlerIgnored;
var
  LW: TMemoryWatermark;
begin
  LW := TMemoryWatermark.Create(100, 200);
  try
    LW.RegisterHandler(wlHigh, nil); { should not crash }
    LW.Check(150); { should not crash }
    Check(LW.CurrentLevel = wlHigh, 'should be high');
  finally
    LW.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_watermark');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('invalid_thresholds', @TestInvalidThresholds);
  T.Test('normal_to_high', @TestNormalToHigh);
  T.Test('high_to_critical', @TestHighToCritical);
  T.Test('no_repeat_firing', @TestNoRepeatFiring);
  T.Test('downgrade_no_callback', @TestDowngradeNoCallback);
  T.Test('nil_handler_ignored', @TestNilHandlerIgnored);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
