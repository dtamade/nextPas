program test_log;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.log.intf,
  nextpas.core.log;

var
  T: TTestRunner;
  GCaptured: array of TLogRecord;
  GCaptureCount: Int32;

type
  TCaptureHandler = class(TInterfacedObject, ILogHandler)
  public
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
    procedure Close;
  end;

procedure TCaptureHandler.Handle(const ARecord: TLogRecord);
begin
  if GCaptureCount >= Length(GCaptured) then
    SetLength(GCaptured, Length(GCaptured) * 2 + 8);
  GCaptured[GCaptureCount] := ARecord;
  Inc(GCaptureCount);
end;

procedure TCaptureHandler.Flush;
begin
end;

procedure TCaptureHandler.Close;
begin
end;

procedure ResetCapture;
begin
  GCaptureCount := 0;
  SetLength(GCaptured, 16);
end;

procedure TestLogLevels;
var
  LL: ILogger;
begin
  ResetCapture;
  LL := LogWith(TCaptureHandler.Create, llTrace);
  LL.Trace('t');
  LL.Debug('d');
  LL.Info('i');
  LL.Warn('w');
  LL.Error('e');
  LL.Fatal('f');
  CheckEqual(Int64(6), Int64(GCaptureCount), 'all 6 levels captured');
  Check(GCaptured[0].Level = llTrace, 'level 0 = trace');
  Check(GCaptured[5].Level = llFatal, 'level 5 = fatal');
end;

procedure TestLevelFiltering;
var
  LL: ILogger;
begin
  ResetCapture;
  LL := LogWith(TCaptureHandler.Create, llWarn);
  LL.Trace('t');
  LL.Debug('d');
  LL.Info('i');
  LL.Warn('w');
  LL.Error('e');
  CheckEqual(Int64(2), Int64(GCaptureCount), 'only warn+error pass');
  Check(GCaptured[0].Level = llWarn, 'first = warn');
  Check(GCaptured[1].Level = llError, 'second = error');
end;

procedure TestMessageContent;
var
  LL: ILogger;
begin
  ResetCapture;
  LL := LogWith(TCaptureHandler.Create, llInfo);
  LL.Info('hello world');
  Check(GCaptured[0].Message = 'hello world', 'message preserved');
end;

procedure TestTimestamp;
var
  LL: ILogger;
begin
  ResetCapture;
  LL := LogWith(TCaptureHandler.Create, llInfo);
  LL.Info('ts test');
  Check(GCaptured[0].TimestampNs > 0, 'timestamp > 0');
end;

procedure TestNullLogger;
var
  LL: ILogger;
begin
  LL := NullLogger;
  LL.Info('should not crash');
  LL.Error('also fine');
  Check(True, 'null logger no crash');
end;

procedure TestDefaultLogger;
begin
  ResetCapture;
  LogSetDefault(LogWith(TCaptureHandler.Create, llInfo));
  LogInfo('default test');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'default logger works');
  Check(GCaptured[0].Message = 'default test', 'default msg');
  LogSetDefault(nil);
end;

procedure TestConsoleLogger;
var
  LL: ILogger;
begin
  LL := LogConsole(llError);
  LL.Error('console error test');
  Check(True, 'console logger no crash');
end;

procedure TestMultipleHandlers;
var
  LL1, LL2: ILogger;
begin
  ResetCapture;
  LL1 := LogWith(TCaptureHandler.Create, llInfo);
  LL1.Info('first');
  LL2 := LogWith(TCaptureHandler.Create, llInfo);
  LL2.Info('second');
  CheckEqual(Int64(2), Int64(GCaptureCount), 'both loggers work');
end;

procedure TestLogGeneric;
var
  LL: ILogger;
begin
  ResetCapture;
  LL := LogWith(TCaptureHandler.Create, llTrace);
  LL.Log(llDebug, 'generic log');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'generic log works');
  Check(GCaptured[0].Level = llDebug, 'level = debug');
  Check(GCaptured[0].Message = 'generic log', 'msg');
end;

begin
  T := TTestRunner.Create('nextpas.core.log');
  T.Run('Log levels', @TestLogLevels);
  T.Run('Level filtering', @TestLevelFiltering);
  T.Run('Message content', @TestMessageContent);
  T.Run('Timestamp', @TestTimestamp);
  T.Run('Null logger', @TestNullLogger);
  T.Run('Default logger', @TestDefaultLogger);
  T.Run('Console logger', @TestConsoleLogger);
  T.Run('Multiple handlers', @TestMultipleHandlers);
  T.Run('Log generic', @TestLogGeneric);
  T.Summary;
end.
