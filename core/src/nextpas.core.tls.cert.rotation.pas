{**
 * nextpas.core.tls.cert.rotation - Certificate Rotation and Hot Reload
 *
 * Implements automatic certificate rotation with hot reload capability.
 * Monitors certificate files for changes and reloads them without disrupting
 * active connections.
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-31
 *
 * Features:
 * - File system monitoring for certificate changes
 * - Automatic reload on certificate update
 * - Expiry monitoring with configurable thresholds
 * - Thread-safe context reconfiguration
 * - Zero-downtime certificate updates
 *}
unit nextpas.core.tls.cert.rotation;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  SysUtils, nextpas.core.sync,
  nextpas.core.platform.thread,
  nextpas.core.fs, nextpas.core.text.conv, nextpas.core.time,
  nextpas.core.tls.base, nextpas.core.tls.errors, nextpas.core.tls.logging, nextpas.core.tls.exceptions;

type
  {**
   * Certificate rotation event types
   *}
  TRotationEventType = (
    retCertificateExpiring,    // Certificate approaching expiry
    retCertificateExpired,     // Certificate has expired
    retFileChanged,            // Certificate file modified
    retReloadSuccess,          // Certificate reloaded successfully
    retReloadFailed            // Certificate reload failed
  );

  {**
   * Certificate rotation event callback
   *
   * @param AEventType Type of rotation event
   * @param AMessage Human-readable event message
   * @param ACertPath Path to certificate file
   *}
  TRotationEventCallback = procedure(AEventType: TRotationEventType;
    const AMessage: string; const ACertPath: string) of object;

  {**
   * Certificate rotation configuration
   *}
  TRotationConfig = record
    CertificatePath: string;           // Path to certificate file
    PrivateKeyPath: string;            // Path to private key file
    PrivateKeyPassword: string;        // Password for encrypted key
    ExpiryWarningDays: Integer;        // Days before expiry to trigger warning (default: 30)
    CheckIntervalSeconds: Integer;     // How often to check for changes (default: 3600)
    AutoReloadOnChange: Boolean;       // Automatically reload on file change (default: True)
    AutoReloadOnExpiry: Boolean;       // Automatically reload on expiry warning (default: False)
  end;

  {**
   * Certificate rotation manager
   *
   * Monitors certificate files and handles automatic rotation.
   * Thread-safe implementation with background monitoring.
   *}
  TCertificateRotationManager = class
  private
    FContext: ISSLContext;
    FConfig: TRotationConfig;
    FMonitorThread: TPlatformThreadRecord;
    FLock: IMutex;
    FActive: LongInt;  // atomic flag: 0=inactive, 1=active
    FLastCertModTime: TDateTime;
    FLastKeyModTime: TDateTime;
    FLastExpiryCheck: TDateTime;
    FOnRotationEvent: TRotationEventCallback;

    {** Atomic read of FActive *}
    function GetActive: Boolean;

    {** Get file modification time *}
    function GetFileModTime(const AFilePath: string): TDateTime;

    {** Check if certificate is expiring soon *}
    function CheckCertificateExpiry(out ADaysRemaining: Integer): Boolean;

    {** Reload certificate and private key *}
    function ReloadCertificate: Boolean;

    {** Monitor thread procedure *}
    procedure MonitorThreadProc;

    {** Trigger rotation event *}
    procedure TriggerEvent(AEventType: TRotationEventType;
      const AMessage: string);

  public
    constructor Create(AContext: ISSLContext);
    destructor Destroy; override;

    {**
     * Start certificate rotation monitoring
     *
     * @param AConfig Rotation configuration
     * @returns True if monitoring started successfully
     *}
    function Start(const AConfig: TRotationConfig): Boolean;

    {**
     * Stop certificate rotation monitoring
     *}
    procedure Stop;

    {**
     * Manually trigger certificate reload
     *
     * @returns True if reload successful
     *}
    function ManualReload: Boolean;

    {**
     * Check certificate expiry status
     *
     * @param ADaysRemaining Days until certificate expires
     * @returns True if certificate is valid
     *}
    function CheckExpiry(out ADaysRemaining: Integer): Boolean;

    {**
     * Get current rotation status
     *}
    function GetStatus: string;

    {**
     * Whether monitoring is active
     *}
    property Active: Boolean read GetActive;

    {**
     * Rotation event callback
     *}
    property OnRotationEvent: TRotationEventCallback
      read FOnRotationEvent write FOnRotationEvent;
  end;

implementation

  Math,
  nextpas.core.base.utils,
  nextpas.core.tls.utils,
  nextpas.core.tls.factory;

function RotationMonitorEntry(AArg: Pointer): Pointer; cdecl; forward;

{ TCertificateRotationManager }

constructor TCertificateRotationManager.Create(AContext: ISSLContext);
begin
  inherited Create;
  FContext := AContext;
  FLock := Mutex;
  FActive := 0;
  FMonitorThread.Handle := nil;
  FLastExpiryCheck := 0;
end;

destructor TCertificateRotationManager.Destroy;
begin
  Stop;
  FLock := nil;
  inherited Destroy;
end;

function TCertificateRotationManager.GetActive: Boolean;
begin
  Result := InterlockedCompareExchange(FActive, 0, 0) <> 0;
end;

function TCertificateRotationManager.GetFileModTime(const AFilePath: string): TDateTime;
var
  SearchRec: TSearchRec;
begin
  Result := 0;
  if FindFirst(AFilePath, faAnyFile, SearchRec) = 0 then
  begin
    try
      Result := SearchRec.TimeStamp;
    finally
      FindClose(SearchRec);
    end;
  end;
end;

function TCertificateRotationManager.CheckCertificateExpiry(
  out ADaysRemaining: Integer): Boolean;
var
  CertInfo: TSSLCertificateInfo;
  NotAfter: TDateTime;
begin
  Result := False;
  ADaysRemaining := 0;

  try
    if Trim(FConfig.CertificatePath) = '' then
    begin
      TSecurityLog.Warning('CertRotation',
        'Certificate expiry check skipped: certificate path is not configured');
      Exit;
    end;

    if not nextpas.core.fs.IsFile(FConfig.CertificatePath) then
    begin
      TSecurityLog.Error('CertRotation',
        nextpas.core.text.conv.Format('Certificate expiry check failed: file not found: %s',
          [FConfig.CertificatePath]));
      Exit;
    end;

    CertInfo := TSSLHelper.GetCertificateInfo(FConfig.CertificatePath);
    NotAfter := CertInfo.NotAfter;

    if NotAfter <= 0 then
      raise ESSLException.CreateWithContext(
        nextpas.core.text.conv.Format('Certificate does not contain a valid NotAfter timestamp: %s',
          [FConfig.CertificatePath]),
        sslErrCertificate,
        'TCertificateRotationManager.CheckCertificateExpiry',
        0,
        sslAutoDetect
      );

    ADaysRemaining := Floor(NotAfter - nextpas.core.time.DateTimeNow);
    Result := nextpas.core.time.DateTimeNow <= NotAfter;

    TSecurityLog.Debug('CertRotation',
      nextpas.core.text.conv.Format('Certificate expiry check: path=%s, notAfter=%s, daysRemaining=%d, valid=%s',
        [FConfig.CertificatePath,
        nextpas.core.time.DateTimeToStr(NotAfter),
        ADaysRemaining,
        BoolToStr(Result, True)]));
  except
    on E: Exception do
    begin
      TSecurityLog.Error('CertRotation',
        nextpas.core.text.conv.Format('Failed to check certificate expiry: %s', [E.Message]));
    end;
  end;
end;

function TCertificateRotationManager.ReloadCertificate: Boolean;
begin
  Result := False;
  FLock.Acquire;
  try
    try
      TSecurityLog.Info('CertRotation', 'Reloading certificate...');

      // Reload certificate
      FContext.LoadCertificate(FConfig.CertificatePath);

      // Reload private key
      if FConfig.PrivateKeyPath <> '' then
        FContext.LoadPrivateKey(FConfig.PrivateKeyPath, FConfig.PrivateKeyPassword);

      // Update modification times
      FLastCertModTime := GetFileModTime(FConfig.CertificatePath);
      if FConfig.PrivateKeyPath <> '' then
        FLastKeyModTime := GetFileModTime(FConfig.PrivateKeyPath);

      Result := True;
      TSecurityLog.Info('CertRotation', 'Certificate reloaded successfully');
      TriggerEvent(retReloadSuccess, 'Certificate reloaded successfully');
    except
      on E: Exception do
      begin
        TSecurityLog.Error('CertRotation',
          nextpas.core.text.conv.Format('Failed to reload certificate: %s', [E.Message]));
        TriggerEvent(retReloadFailed,
          nextpas.core.text.conv.Format('Certificate reload failed: %s', [E.Message]));
      end;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TCertificateRotationManager.MonitorThreadProc;
var
  CurrentCertModTime, CurrentKeyModTime: TDateTime;
  DaysRemaining: Integer;
  NeedReload: Boolean;
begin
  while InterlockedCompareExchange(FActive, 0, 0) <> 0 do
  begin
    try
      NeedReload := False;

      // Check for file changes
      if FConfig.AutoReloadOnChange then
      begin
        CurrentCertModTime := GetFileModTime(FConfig.CertificatePath);
        if CurrentCertModTime > FLastCertModTime then
        begin
          TSecurityLog.Info('CertRotation', 'Certificate file changed');
          TriggerEvent(retFileChanged, 'Certificate file modified');
          NeedReload := True;
        end;

        if FConfig.PrivateKeyPath <> '' then
        begin
          CurrentKeyModTime := GetFileModTime(FConfig.PrivateKeyPath);
          if CurrentKeyModTime > FLastKeyModTime then
          begin
            TSecurityLog.Info('CertRotation', 'Private key file changed');
            TriggerEvent(retFileChanged, 'Private key file modified');
            NeedReload := True;
          end;
        end;
      end;

      // Check certificate expiry (once per day)
      if (nextpas.core.time.DateTimeNow - FLastExpiryCheck) >= 1.0 then
      begin
        if CheckCertificateExpiry(DaysRemaining) then
        begin
          if DaysRemaining <= FConfig.ExpiryWarningDays then
          begin
            TSecurityLog.Warning('CertRotation',
              nextpas.core.text.conv.Format('Certificate expiring in %d days', [DaysRemaining]));
            TriggerEvent(retCertificateExpiring,
              nextpas.core.text.conv.Format('Certificate expiring in %d days', [DaysRemaining]));

            if FConfig.AutoReloadOnExpiry then
              NeedReload := True;
          end;

          if DaysRemaining <= 0 then
          begin
            TSecurityLog.Error('CertRotation', 'Certificate has expired!');
            TriggerEvent(retCertificateExpired, 'Certificate has expired');
          end;
        end;
        FLastExpiryCheck := nextpas.core.time.DateTimeNow;
      end;

      // Perform reload if needed
      if NeedReload then
        ReloadCertificate;

    except
      on E: Exception do
        TSecurityLog.Error('CertRotation',
          nextpas.core.text.conv.Format('Monitor thread error: %s', [E.Message]));
    end;

    // Sleep for check interval
    // Sleep for check interval (NOTE: Stop() may block up to this duration)
    Sleep(FConfig.CheckIntervalSeconds * 1000);
  end;
end;

procedure TCertificateRotationManager.TriggerEvent(
  AEventType: TRotationEventType; const AMessage: string);
begin
  if Assigned(FOnRotationEvent) then
  begin
    try
      FOnRotationEvent(AEventType, AMessage, FConfig.CertificatePath);
    except
      on E: Exception do
        TSecurityLog.Error('CertRotation',
          nextpas.core.text.conv.Format('Error in rotation event callback: %s', [E.Message]));
    end;
  end;
end;

function TCertificateRotationManager.Start(const AConfig: TRotationConfig): Boolean;
begin
  Result := False;

  if InterlockedCompareExchange(FActive, 0, 0) <> 0 then
  begin
    TSecurityLog.Warning('CertRotation', 'Rotation manager already active');
    Exit;
  end;

  // Validate configuration
  if not nextpas.core.fs.IsFile(AConfig.CertificatePath) then
  begin
    TSecurityLog.Error('CertRotation',
      nextpas.core.text.conv.Format('Certificate file not found: %s', [AConfig.CertificatePath]));
    Exit;
  end;

  if (AConfig.PrivateKeyPath <> '') and not nextpas.core.fs.IsFile(AConfig.PrivateKeyPath) then
  begin
    TSecurityLog.Error('CertRotation',
      nextpas.core.text.conv.Format('Private key file not found: %s', [AConfig.PrivateKeyPath]));
    Exit;
  end;

  // Store configuration
  FConfig := AConfig;

  // Set defaults
  if FConfig.ExpiryWarningDays <= 0 then
    FConfig.ExpiryWarningDays := 30;
  if FConfig.CheckIntervalSeconds <= 0 then
    FConfig.CheckIntervalSeconds := 3600;  // 1 hour

  // Initialize modification times
  FLastCertModTime := GetFileModTime(FConfig.CertificatePath);
  if FConfig.PrivateKeyPath <> '' then
    FLastKeyModTime := GetFileModTime(FConfig.PrivateKeyPath);
  FLastExpiryCheck := 0;

  // Start monitor thread
  InterlockedExchange(FActive, 1);
  platform_thread_spawn(FMonitorThread, @RotationMonitorEntry, Self);

  TSecurityLog.Info('CertRotation',
    nextpas.core.text.conv.Format('Certificate rotation monitoring started (check interval: %d seconds)',
      [FConfig.CheckIntervalSeconds]));

  Result := True;
end;

procedure TCertificateRotationManager.Stop;
begin
  if InterlockedCompareExchange(FActive, 0, 0) = 0 then
    Exit;

  TSecurityLog.Info('CertRotation', 'Stopping certificate rotation monitoring...');

  InterlockedExchange(FActive, 0);

  if platform_thread_is_alive(FMonitorThread) then
    platform_thread_wait(FMonitorThread);

  TSecurityLog.Info('CertRotation', 'Certificate rotation monitoring stopped');
end;

function TCertificateRotationManager.ManualReload: Boolean;
begin
  TSecurityLog.Info('CertRotation', 'Manual certificate reload requested');
  Result := ReloadCertificate;
end;

function TCertificateRotationManager.CheckExpiry(out ADaysRemaining: Integer): Boolean;
begin
  Result := CheckCertificateExpiry(ADaysRemaining);
end;

function TCertificateRotationManager.GetStatus: string;
var
  DaysRemaining: Integer;
  ActiveStr, AutoReloadStr, PrivKeyStr: string;
begin
  if InterlockedCompareExchange(FActive, 0, 0) <> 0 then
    ActiveStr := 'Yes'
  else
    ActiveStr := 'No';
  
  if FConfig.AutoReloadOnChange then
    AutoReloadStr := 'Yes'
  else
    AutoReloadStr := 'No';
  
  if FConfig.PrivateKeyPath <> '' then
    PrivKeyStr := FConfig.PrivateKeyPath
  else
    PrivKeyStr := 'N/A';

  Result := nextpas.core.text.conv.Format('Certificate Rotation Status:' + LineEnding +
    '  Active: %s' + LineEnding +
    '  Certificate: %s' + LineEnding +
    '  Private Key: %s' + LineEnding +
    '  Auto-reload on change: %s' + LineEnding +
    '  Check interval: %d seconds' + LineEnding,
    [ActiveStr,
    FConfig.CertificatePath,
    PrivKeyStr,
    AutoReloadStr,
    FConfig.CheckIntervalSeconds]);

  if CheckCertificateExpiry(DaysRemaining) then
    Result := Result + nextpas.core.text.conv.Format('  Days until expiry: %d' + LineEnding, [DaysRemaining]);
end;

{ Rotation monitor thread entry }

function RotationMonitorEntry(AArg: Pointer): Pointer; cdecl;
var
  LManager: TCertificateRotationManager;
begin
  LManager := TCertificateRotationManager(AArg);
  LManager.MonitorThreadProc;
  Result := nil;
end;

end.
