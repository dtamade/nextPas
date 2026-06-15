{
  nextpas.core.tls.logging - Unified Logging Infrastructure

  Provides a centralized interface for logging security-relevant events,
  audits, alerts, debug information, and performance metrics.

  Version: 2.0

  Features:
  - 7-level logging (Trace, Debug, Info, Warning, Error, Audit, Critical)
  - Multiple output targets (Console, File, Memory, Callback)
  - File rotation support
  - Performance profiling
  - Thread-safe operations
}

unit nextpas.core.tls.logging;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, nextpas.core.text.conv,
  nextpas.core.tls.base;  // P2: TSSLProtocolVersions for shared helpers

{$IFDEF USE_SYNCOBJS}
  {$DEFINE HAS_CRITICAL_SECTION}
{$ELSE}
  {$IFDEF UNIX}
    {$DEFINE HAS_PTHREAD_LOCK}
  {$ENDIF}
{$ENDIF}

type
  { Security/Log Event Level - ordered by severity }
  TSecurityEventLevel = (
    selTrace,     // Detailed tracing (function entry/exit)
    selDebug,     // Debug information for development
    selInfo,      // General information (e.g., context created)
    selWarning,   // Potential issues (e.g., deprecated cipher used)
    selError,     // Operations failed (e.g., handshake failed)
    selAudit,     // Security audit events (e.g., key access, user login)
    selCritical   // Critical security breaches (e.g., integrity check failed)
  );

  { Alias for backward compatibility }
  TLogLevel = TSecurityEventLevel;
  
  {**
   * ISecurityLogger - Security Logger Interface
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ISecurityLogger = interface
    ['{A1B2C3D4-E5F6-4789-0123-456789ABCDEF}']

    // Generic log
    procedure Log(ALevel: TSecurityEventLevel; const ACategory, AMessage: string);

    // Level-specific helpers
    procedure LogTrace(const ACategory, AMessage: string);
    procedure LogDebug(const ACategory, AMessage: string);
    procedure LogInfo(const ACategory, AMessage: string);
    procedure LogWarning(const ACategory, AMessage: string);
    procedure LogError(const ACategory, AMessage: string; AException: Exception = nil);
    procedure LogAudit(const ACategory, AAction, AUser, ADetails: string);
    procedure LogCritical(const ACategory, AMessage: string);

    // Configuration
    procedure SetMinLevel(ALevel: TSecurityEventLevel);
    function GetMinLevel: TSecurityEventLevel;
  end;

  { Base Logger Implementation }
  TBaseLogger = class(TInterfacedObject, ISecurityLogger)
  private
    FMinLevel: TSecurityEventLevel;
  protected
    function FormatMessage(ALevel: TSecurityEventLevel; const ACategory, AMessage: string): string; virtual;
    procedure WriteLog(const AMessage: string); virtual; abstract;
  public
    constructor Create; virtual;

    procedure Log(ALevel: TSecurityEventLevel; const ACategory, AMessage: string); virtual;
    procedure LogTrace(const ACategory, AMessage: string); virtual;
    procedure LogDebug(const ACategory, AMessage: string); virtual;
    procedure LogInfo(const ACategory, AMessage: string); virtual;
    procedure LogWarning(const ACategory, AMessage: string); virtual;
    procedure LogError(const ACategory, AMessage: string; AException: Exception = nil); virtual;
    procedure LogAudit(const ACategory, AAction, AUser, ADetails: string); virtual;
    procedure LogCritical(const ACategory, AMessage: string); virtual;

    procedure SetMinLevel(ALevel: TSecurityEventLevel);
    function GetMinLevel: TSecurityEventLevel;

    property MinLevel: TSecurityEventLevel read FMinLevel write FMinLevel;
  end;

  { Console Logger - Writes to StdOut/StdErr }
  TConsoleLogger = class(TBaseLogger)
  protected
    procedure WriteLog(const AMessage: string); override;
  end;

  { File Logger - Writes to a secure log file with rotation support }
  TFileLogger = class(TBaseLogger)
  private
    FFileName: string;
    FLock: TRTLCriticalSection;
    FMaxSize: Int64;        // Max file size before rotation (default 10MB)
    FMaxFiles: Integer;     // Max number of rotated files (default 5)
    FCurrentSize: Int64;
    procedure RotateLogFile;
    procedure CheckRotation;
  protected
    procedure WriteLog(const AMessage: string); override;
  public
    constructor Create(const AFileName: string); reintroduce;
    constructor Create(const AFileName: string; AMaxSize: Int64; AMaxFiles: Integer); reintroduce;
    destructor Destroy; override;

    property MaxSize: Int64 read FMaxSize write FMaxSize;
    property MaxFiles: Integer read FMaxFiles write FMaxFiles;
  end;

  { Composite Logger - Broadcasts to multiple loggers }
  TCompositeLogger = class(TInterfacedObject, ISecurityLogger)
  private
    FLoggers: TInterfaceList;
    FLock: TRTLCriticalSection;
    FMinLevel: TSecurityEventLevel;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddLogger(ALogger: ISecurityLogger);
    procedure RemoveLogger(ALogger: ISecurityLogger);

    procedure Log(ALevel: TSecurityEventLevel; const ACategory, AMessage: string);
    procedure LogTrace(const ACategory, AMessage: string);
    procedure LogDebug(const ACategory, AMessage: string);
    procedure LogInfo(const ACategory, AMessage: string);
    procedure LogWarning(const ACategory, AMessage: string);
    procedure LogError(const ACategory, AMessage: string; AException: Exception = nil);
    procedure LogAudit(const ACategory, AAction, AUser, ADetails: string);
    procedure LogCritical(const ACategory, AMessage: string);

    procedure SetMinLevel(ALevel: TSecurityEventLevel);
    function GetMinLevel: TSecurityEventLevel;
  end;

  { Global Access }
  TSecurityLog = class
  private
    class var FLogger: ISecurityLogger;
    class var FDefaultLogger: ISecurityLogger;
    class constructor Create;
  public
    class property Logger: ISecurityLogger read FLogger write FLogger;

    // Convenience methods forwarding to global Logger
    class procedure Trace(const ACategory, AMessage: string);
    class procedure Debug(const ACategory, AMessage: string);
    class procedure Info(const ACategory, AMessage: string);
    class procedure Warning(const ACategory, AMessage: string);
    class procedure Error(const ACategory, AMessage: string; AException: Exception = nil);
    class procedure Audit(const ACategory, AAction, AUser, ADetails: string);
    class procedure Critical(const ACategory, AMessage: string);

    // Configuration
    class procedure SetMinLevel(ALevel: TSecurityEventLevel);
  end;

  { Performance Profiler - Singleton for measuring execution times }
  TSSLProfiler = class
  public type
    TProfileEntry = record
      Name: string;
      Count: Integer;
      TotalTimeMs: Int64;
      MinTimeMs: Int64;
      MaxTimeMs: Int64;
    end;
  private
    class var FInstance: TSSLProfiler;
    class var FEnabled: Boolean;
    FEntries: TStringList;
    FLock: TRTLCriticalSection;
  public
    constructor CreateInstance;
    class function Instance: TSSLProfiler;
    class procedure FreeProfilerInstance; reintroduce;
    class property Enabled: Boolean read FEnabled write FEnabled;

    destructor Destroy; override;

    function StartMeasure(const AName: string): Int64;
    procedure EndMeasure(const AName: string; AStartTime: Int64);
    function GetReport: string;
    procedure Clear;
  end;

const
  LOG_LEVEL_NAMES: array[TSecurityEventLevel] of string = (
    'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'AUDIT', 'CRIT'
  );

  DEFAULT_MAX_LOG_SIZE = 10 * 1024 * 1024;  // 10 MB
  DEFAULT_MAX_LOG_FILES = 5;

{ P2: 共享辅助函数 - 废弃协议警告 }
procedure LogDeprecatedProtocolWarnings(const ABackendName: string; AVersions: TSSLProtocolVersions);

implementation

uses
  nextpas.core.text.strings;


{ P2: 共享辅助函数 - 废弃协议警告 }
procedure LogDeprecatedProtocolWarnings(const ABackendName: string; AVersions: TSSLProtocolVersions);
const
  DEPRECATED_PROTOCOLS: TSSLProtocolVersions = [
    sslProtocolSSL2, sslProtocolSSL3, sslProtocolTLS10, sslProtocolTLS11
  ];
var
  LDeprecated: TSSLProtocolVersions;
begin
  LDeprecated := AVersions * DEPRECATED_PROTOCOLS;
  if LDeprecated <> [] then
  begin
    if sslProtocolSSL2 in LDeprecated then
      TSecurityLog.Warning(ABackendName, 'SSL 2.0 已废弃且不安全，强烈建议禁用');
    if sslProtocolSSL3 in LDeprecated then
      TSecurityLog.Warning(ABackendName, 'SSL 3.0 已废弃（POODLE漏洞），强烈建议禁用');
    if sslProtocolTLS10 in LDeprecated then
      TSecurityLog.Warning(ABackendName, 'TLS 1.0 已废弃，建议升级到 TLS 1.2 或更高版本');
    if sslProtocolTLS11 in LDeprecated then
      TSecurityLog.Warning(ABackendName, 'TLS 1.1 已废弃，建议升级到 TLS 1.2 或更高版本');

    TSecurityLog.Warning(ABackendName,
      '配置了废弃的协议版本。生产环境建议仅使用 TLS 1.2 和 TLS 1.3');
  end;
end;

{ TBaseLogger }

constructor TBaseLogger.Create;
begin
  inherited Create;
  FMinLevel := selInfo;  // Default to Info level
end;

function TBaseLogger.FormatMessage(ALevel: TSecurityEventLevel; const ACategory, AMessage: string): string;
var
  LTimeStr: string;
begin
  LTimeStr := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
  // Format: [Time] [Level] [Category] Message
  Result := nextpas.core.text.conv.Format(
    '[%s] [%s] [%s] %s',
    [LTimeStr, LOG_LEVEL_NAMES[ALevel], ACategory, AMessage]
  );
end;

procedure TBaseLogger.Log(ALevel: TSecurityEventLevel; const ACategory, AMessage: string);
begin
  if ALevel < FMinLevel then
    Exit;
  WriteLog(FormatMessage(ALevel, ACategory, AMessage));
end;

procedure TBaseLogger.LogTrace(const ACategory, AMessage: string);
begin
  Log(selTrace, ACategory, AMessage);
end;

procedure TBaseLogger.LogDebug(const ACategory, AMessage: string);
begin
  Log(selDebug, ACategory, AMessage);
end;

procedure TBaseLogger.LogInfo(const ACategory, AMessage: string);
begin
  Log(selInfo, ACategory, AMessage);
end;

procedure TBaseLogger.LogWarning(const ACategory, AMessage: string);
begin
  Log(selWarning, ACategory, AMessage);
end;

procedure TBaseLogger.LogError(const ACategory, AMessage: string; AException: Exception);
var
  LMsg: string;
begin
  LMsg := AMessage;
  if AException <> nil then
    LMsg := LMsg + ' (Exception: ' + AException.ClassName + ': ' + AException.Message + ')';
  Log(selError, ACategory, LMsg);
end;

procedure TBaseLogger.LogAudit(const ACategory, AAction, AUser, ADetails: string);
var
  LMsg: string;
begin
  LMsg := nextpas.core.text.conv.Format(
    'Action=%s User=%s Details=%s',
    [AAction, AUser, ADetails]
  );
  Log(selAudit, ACategory, LMsg);
end;

procedure TBaseLogger.LogCritical(const ACategory, AMessage: string);
begin
  Log(selCritical, ACategory, AMessage);
end;

procedure TBaseLogger.SetMinLevel(ALevel: TSecurityEventLevel);
begin
  FMinLevel := ALevel;
end;

function TBaseLogger.GetMinLevel: TSecurityEventLevel;
begin
  Result := FMinLevel;
end;

{ TConsoleLogger }

procedure TConsoleLogger.WriteLog(const AMessage: string);
begin
  // Thread-safe console writing is tricky in standard Pascal, but WriteLn is usually atomic enough for lines
  // or we could use a lock if needed. For now, simple WriteLn.
  WriteLn(AMessage);
end;

{ TFileLogger }

constructor TFileLogger.Create(const AFileName: string);
begin
  Create(AFileName, DEFAULT_MAX_LOG_SIZE, DEFAULT_MAX_LOG_FILES);
end;

constructor TFileLogger.Create(const AFileName: string; AMaxSize: Int64; AMaxFiles: Integer);
var
  LDir: string;
begin
  inherited Create;
  FFileName := AFileName;
  FMaxSize := AMaxSize;
  FMaxFiles := AMaxFiles;
  FCurrentSize := 0;
  InitCriticalSection(FLock);

  // Ensure log directory exists
  LDir := ExtractFilePath(AFileName);
  if (LDir <> '') and not DirectoryExists(LDir) then
    ForceDirectories(LDir);

  // Get current file size if exists
  if FileExists(FFileName) then
  begin
    try
      with TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite) do
      try
        FCurrentSize := Size;
      finally
        Free;
      end;
    except
      FCurrentSize := 0;
    end;
  end;
end;

destructor TFileLogger.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

procedure TFileLogger.CheckRotation;
begin
  if (FMaxSize > 0) and (FCurrentSize >= FMaxSize) then
    RotateLogFile;
end;

procedure TFileLogger.RotateLogFile;
var
  I: Integer;
  LOldName, LNewName: string;
begin
  // Delete oldest file if exists
  if FMaxFiles > 0 then
  begin
    LOldName := FFileName + '.' + nextpas.core.text.conv.IntToStr(FMaxFiles);
    if FileExists(LOldName) then
      DeleteFile(LOldName);

    // Rename existing rotated files
    for I := FMaxFiles - 1 downto 1 do
    begin
      LOldName := FFileName + '.' + nextpas.core.text.conv.IntToStr(I);
      LNewName := FFileName + '.' + nextpas.core.text.conv.IntToStr(I + 1);
      if FileExists(LOldName) then
        RenameFile(LOldName, LNewName);
    end;

    // Rename current log file
    if FileExists(FFileName) then
      RenameFile(FFileName, FFileName + '.1');
  end;

  FCurrentSize := 0;
end;

procedure TFileLogger.WriteLog(const AMessage: string);
var
  LFile: TextFile;
  LMsgLen: Integer;
begin
  EnterCriticalSection(FLock);
  try
    // Check if rotation needed before writing
    CheckRotation;

    AssignFile(LFile, FFileName);
    if FileExists(FFileName) then
      Append(LFile)
    else
      Rewrite(LFile);
    try
      WriteLn(LFile, AMessage);
      LMsgLen := Length(AMessage) + 2;  // +2 for line ending
      Inc(FCurrentSize, LMsgLen);
    finally
      CloseFile(LFile);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

{ TCompositeLogger }

constructor TCompositeLogger.Create;
begin
  inherited;
  FLoggers := TInterfaceList.Create;
  FMinLevel := selInfo;
  InitCriticalSection(FLock);
end;

destructor TCompositeLogger.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

procedure TCompositeLogger.AddLogger(ALogger: ISecurityLogger);
begin
  EnterCriticalSection(FLock);
  try
    if FLoggers.IndexOf(ALogger) < 0 then
      FLoggers.Add(ALogger);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TCompositeLogger.RemoveLogger(ALogger: ISecurityLogger);
begin
  EnterCriticalSection(FLock);
  try
    FLoggers.Remove(ALogger);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TCompositeLogger.Log(ALevel: TSecurityEventLevel; const ACategory, AMessage: string);
var
  I: Integer;
begin
  if ALevel < FMinLevel then
    Exit;
  EnterCriticalSection(FLock);
  try
    for I := 0 to FLoggers.Count - 1 do
      (FLoggers[I] as ISecurityLogger).Log(ALevel, ACategory, AMessage);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TCompositeLogger.LogTrace(const ACategory, AMessage: string);
begin
  Log(selTrace, ACategory, AMessage);
end;

procedure TCompositeLogger.LogDebug(const ACategory, AMessage: string);
begin
  Log(selDebug, ACategory, AMessage);
end;

procedure TCompositeLogger.LogInfo(const ACategory, AMessage: string);
begin
  Log(selInfo, ACategory, AMessage);
end;

procedure TCompositeLogger.LogWarning(const ACategory, AMessage: string);
begin
  Log(selWarning, ACategory, AMessage);
end;

procedure TCompositeLogger.LogError(const ACategory, AMessage: string; AException: Exception);
var
  I: Integer;
begin
  if selError < FMinLevel then
    Exit;
  EnterCriticalSection(FLock);
  try
    for I := 0 to FLoggers.Count - 1 do
      (FLoggers[I] as ISecurityLogger).LogError(ACategory, AMessage, AException);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TCompositeLogger.LogAudit(const ACategory, AAction, AUser, ADetails: string);
var
  I: Integer;
begin
  if selAudit < FMinLevel then
    Exit;
  EnterCriticalSection(FLock);
  try
    for I := 0 to FLoggers.Count - 1 do
      (FLoggers[I] as ISecurityLogger).LogAudit(ACategory, AAction, AUser, ADetails);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TCompositeLogger.LogCritical(const ACategory, AMessage: string);
begin
  Log(selCritical, ACategory, AMessage);
end;

procedure TCompositeLogger.SetMinLevel(ALevel: TSecurityEventLevel);
begin
  FMinLevel := ALevel;
end;

function TCompositeLogger.GetMinLevel: TSecurityEventLevel;
begin
  Result := FMinLevel;
end;

{ TSecurityLog }

class constructor TSecurityLog.Create;
begin
  // Default to Console Logger
  FDefaultLogger := TConsoleLogger.Create;
  FLogger := FDefaultLogger;
end;

class procedure TSecurityLog.Trace(const ACategory, AMessage: string);
begin
  if FLogger <> nil then FLogger.Log(selTrace, ACategory, AMessage);
end;

class procedure TSecurityLog.Debug(const ACategory, AMessage: string);
begin
  if FLogger <> nil then FLogger.Log(selDebug, ACategory, AMessage);
end;

class procedure TSecurityLog.Info(const ACategory, AMessage: string);
begin
  if FLogger <> nil then FLogger.Log(selInfo, ACategory, AMessage);
end;

class procedure TSecurityLog.Warning(const ACategory, AMessage: string);
begin
  if FLogger <> nil then FLogger.Log(selWarning, ACategory, AMessage);
end;

class procedure TSecurityLog.Error(const ACategory, AMessage: string; AException: Exception);
begin
  if FLogger <> nil then FLogger.LogError(ACategory, AMessage, AException);
end;

class procedure TSecurityLog.Audit(const ACategory, AAction, AUser, ADetails: string);
begin
  if FLogger <> nil then FLogger.LogAudit(ACategory, AAction, AUser, ADetails);
end;

class procedure TSecurityLog.Critical(const ACategory, AMessage: string);
begin
  if FLogger <> nil then FLogger.Log(selCritical, ACategory, AMessage);
end;

class procedure TSecurityLog.SetMinLevel(ALevel: TSecurityEventLevel);
begin
  if FLogger <> nil then FLogger.SetMinLevel(ALevel);
end;

{ TSSLProfiler }

constructor TSSLProfiler.CreateInstance;
begin
  inherited Create;
  FEntries.Sorted := True;
  InitCriticalSection(FLock);
end;

destructor TSSLProfiler.Destroy;
var
  I: Integer;
  LEntry: ^TProfileEntry;
begin
  for I := 0 to FEntries.Count - 1 do
  begin
    LEntry := Pointer(FEntries.Objects[I]);
    if LEntry <> nil then
      Dispose(LEntry);
  end;
  DoneCriticalSection(FLock);
  inherited;
end;

class function TSSLProfiler.Instance: TSSLProfiler;
begin
  if FInstance = nil then
  begin
    FInstance := TSSLProfiler.CreateInstance;
    FEnabled := True;
  end;
  Result := FInstance;
end;

class procedure TSSLProfiler.FreeProfilerInstance;
begin
  FreeAndNil(FInstance);
end;

function TSSLProfiler.StartMeasure(const AName: string): Int64;
begin
  if FEnabled then
    Result := GetTickCount64
  else
    Result := 0;
end;

procedure TSSLProfiler.EndMeasure(const AName: string; AStartTime: Int64);
var
  LElapsed: Int64;
  LIndex: Integer;
  LEntry: ^TProfileEntry;
begin
  if not FEnabled or (AStartTime = 0) then
    Exit;

  LElapsed := GetTickCount64 - AStartTime;

  EnterCriticalSection(FLock);
  try
    LIndex := FEntries.IndexOf(AName);
    if LIndex < 0 then
    begin
      New(LEntry);
      LEntry^.Name := AName;
      LEntry^.Count := 0;
      LEntry^.TotalTimeMs := 0;
      LEntry^.MinTimeMs := High(Int64);
      LEntry^.MaxTimeMs := 0;
      FEntries.AddObject(AName, TObject(LEntry));
    end
    else
      LEntry := Pointer(FEntries.Objects[LIndex]);

    Inc(LEntry^.Count);
    Inc(LEntry^.TotalTimeMs, LElapsed);
    if LElapsed < LEntry^.MinTimeMs then
      LEntry^.MinTimeMs := LElapsed;
    if LElapsed > LEntry^.MaxTimeMs then
      LEntry^.MaxTimeMs := LElapsed;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TSSLProfiler.GetReport: string;
var
  I: Integer;
  LEntry: ^TProfileEntry;
  LAvg: Double;
  LResult: TStringArray;
begin
  try
    LResult.Add('Performance Profile Report');
    LResult.Add(StringOfChar('=', 80));
    LResult.Add(nextpas.core.text.conv.Format(
      '%-30s %8s %10s %10s %10s %10s',
      ['Name', 'Count', 'Total(ms)', 'Avg(ms)', 'Min(ms)', 'Max(ms)']
    ));
    LResult.Add(StringOfChar('-', 80));

    EnterCriticalSection(FLock);
    try
      for I := 0 to FEntries.Count - 1 do
      begin
        LEntry := Pointer(FEntries.Objects[I]);
        if LEntry^.Count > 0 then
          LAvg := LEntry^.TotalTimeMs / LEntry^.Count
        else
          LAvg := 0;

        LResult.Add(nextpas.core.text.conv.Format(
          '%-30s %8d %10d %10.2f %10d %10d',
          [LEntry^.Name, LEntry^.Count, LEntry^.TotalTimeMs,
          LAvg, LEntry^.MinTimeMs, LEntry^.MaxTimeMs]
        ));
      end;
    finally
      LeaveCriticalSection(FLock);
    end;

    LResult.Add(StringOfChar('=', 80));
    Result := StringsJoin(LResult, sLineBreak);
  finally
  end;
end;

procedure TSSLProfiler.Clear;
var
  I: Integer;
  LEntry: ^TProfileEntry;
begin
  EnterCriticalSection(FLock);
  try
    for I := 0 to FEntries.Count - 1 do
    begin
      LEntry := Pointer(FEntries.Objects[I]);
      if LEntry <> nil then
        Dispose(LEntry);
    end;
    FEntries.Clear;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

finalization
  TSSLProfiler.FreeProfilerInstance;

end.
