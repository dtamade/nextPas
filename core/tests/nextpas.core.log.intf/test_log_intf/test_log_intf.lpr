program test_log_intf;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.log.intf;

var
  LLogger: ILogger;
begin
  WriteLn('=== nextpas.core.log.intf tests ===');

  LLogger := NullLogger;
  Assert(LLogger <> nil, 'NullLogger should not be nil');

  // Should not crash - no-op calls
  LLogger.Trace('trace message');
  LLogger.Debug('debug message');
  LLogger.Info('info message');
  LLogger.Warn('warn message');
  LLogger.Error('error message');
  LLogger.Fatal('fatal message');
  LLogger.Log(llInfo, 'generic log');

  // Singleton behavior
  Assert(NullLogger = LLogger, 'NullLogger should be singleton');

  WriteLn('PASS: all log.intf tests passed');
end.
