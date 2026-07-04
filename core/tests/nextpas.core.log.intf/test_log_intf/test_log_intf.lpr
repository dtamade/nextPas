program test_log_intf;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.log.intf,
  nextpas.core.test;

var
  LLogger: ILogger;
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('log.intf');

  LSuite.Test('NullLogger not nil', procedure begin
    LLogger := NullLogger;
    CheckTrue(LLogger <> nil, 'NullLogger should not be nil');
  end);

  LSuite.Test('no-op calls do not crash', procedure begin
    LLogger := NullLogger;
    LLogger.Trace('trace message');
    LLogger.Debug('debug message');
    LLogger.Info('info message');
    LLogger.Warn('warn message');
    LLogger.Error('error message');
    LLogger.Fatal('fatal message');
    LLogger.Log(llInfo, 'generic log');
  end);

  LSuite.Test('NullLogger is singleton', procedure begin
    CheckTrue(NullLogger = NullLogger, 'NullLogger should be singleton');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.log.intf');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then
    Halt(1);
end.
