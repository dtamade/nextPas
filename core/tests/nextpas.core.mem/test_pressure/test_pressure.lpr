program test_pressure;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.test,
  nextpas.core.mem.pressure;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- TMemoryPressure tests --- }

procedure TestPressureInitiallyNone;
var
  LPressure: TMemoryPressure;
begin
  LPressure := TMemoryPressure.Create;
  try
    Check(LPressure.CurrentLevel = mplNone, 'initially none');
    Check(LPressure.TotalMemKB = 0, 'total=0 before check');
  finally
    LPressure.Free;
  end;
end;

procedure TestPressureShouldCheck;
var
  LPressure: TMemoryPressure;
  LI: Integer;
  LCheckCount: Integer;
begin
  LPressure := TMemoryPressure.Create(10); // 每10次检查一次
  try
    LCheckCount := 0;
    for LI := 0 to 99 do
    begin
      if LPressure.ShouldCheck then
        Inc(LCheckCount);
    end;
    // 100 次调用，间隔 10，应该检查 10 次
    Check(LCheckCount = 10, 'checked 10 times in 100 calls');
  finally
    LPressure.Free;
  end;
end;

procedure TestPressureReadsMemInfo;
var
  LPressure: TMemoryPressure;
  LLevel: TMemoryPressureLevel;
begin
  LPressure := TMemoryPressure.Create;
  try
    LLevel := LPressure.Check;
    // 在 Linux 上应该能读到内存信息
    Check(LPressure.TotalMemKB > 0, 'total mem > 0');
    Check(LPressure.AvailMemKB > 0, 'avail mem > 0');
    Check(LPressure.UsagePercent > 0.0, 'usage > 0');
    Check(LPressure.UsagePercent < 1.0, 'usage < 1');
    // 压力等级应该是合理的
    Check(LLevel in [mplNone, mplLow, mplMedium, mplHigh, mplCritical],
      'valid pressure level');
  finally
    LPressure.Free;
  end;
end;

var
  GPressureCallbackCount: Integer;
  GLastLevel: TMemoryPressureLevel;

procedure PressureHandler(ALevel: TMemoryPressureLevel; AUsedPercent: Double);
begin
  Inc(GPressureCallbackCount);
  GLastLevel := ALevel;
end;

procedure TestPressureCallback;
var
  LPressure: TMemoryPressure;
begin
  LPressure := TMemoryPressure.Create;
  try
    LPressure.OnPressure := @PressureHandler;
    GPressureCallbackCount := 0;
    GLastLevel := mplNone;

    LPressure.Check;
    // 如果系统有压力，回调应该被调用
    if LPressure.CurrentLevel <> mplNone then
      Check(GPressureCallbackCount = 1, 'callback fired')
    else
      Check(GPressureCallbackCount = 0, 'no callback when none');
  finally
    LPressure.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.pressure');

  T.Test('initially none', @TestPressureInitiallyNone);
  T.Test('should check interval', @TestPressureShouldCheck);
  T.Test('reads meminfo', @TestPressureReadsMemInfo);
  T.Test('callback', @TestPressureCallback);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
