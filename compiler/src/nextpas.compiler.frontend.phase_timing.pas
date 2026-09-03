unit nextpas.compiler.frontend.phase_timing;

{**
 * Env-gated phase timing (P0, plan §4.2.1): when NEXTPAS_PHASE_TIMING=1,
 * each PhaseEnd appends one TSV line "name\tms" to a per-PID file
 * /tmp/m2-phase-timing.<pid>.tsv with flock. Disabled = one boolean check
 * per boundary, zero writes. Cold path only: wrap session phases
 * (syntax/resolution/sema/mir), never per-node walks. Append-per-end keeps
 * flush-free semantics even on aborted sessions; nested phases via name-matched
 * stack. Thread-safe: GFrames guarded by platform mutex, file append under flock.
 *}

{$mode objfpc}{$H+}

interface

procedure PhaseBegin(const AName: string);
procedure PhaseEnd(const AName: string);

implementation

uses
  SysUtils,
  nextpas.core.os.env, nextpas.core.time.stopwatch,
  nextpas.core.process,
  nextpas.core.platform.files, nextpas.core.platform.files.base,
  nextpas.core.platform.sync;

type
  TPhaseFrame = record
    Name: string;
    SW: TStopwatch;
  end;

const
  TimingEnvName = 'NEXTPAS_PHASE_TIMING';

var
  GEnabled: Boolean = False;
  GChecked: Boolean = False;
  GFrames: array of TPhaseFrame;
  GLock: TPlatformMutex;
  GLockReady: Boolean = False;

function TimingFilePath: string;
var
  Pid: Int32;
begin
  Pid := CurrentPid;
  if Pid <= 0 then
    Pid := 1;
  Result := '/tmp/m2-phase-timing.' + IntToStr(Pid) + '.tsv';
end;

procedure EnsureLock;
begin
  if GLockReady then
    Exit;
  if platform_mutex_init(GLock, PLATFORM_MUTEX_ERRORCHECK) = 0 then
    GLockReady := True;
end;

procedure EnsureEnabledCheck;
var
  Raw: string;
begin
  if GChecked then
    Exit;
  EnsureLock;
  if GLockReady then
    platform_mutex_lock(GLock);
  try
    if GChecked then
      Exit;
    GChecked := True;
    Raw := GetEnvironmentVariable(TimingEnvName);
    GEnabled := (Raw = '1') or (Raw = 'true') or (Raw = 'on');
  finally
    if GLockReady then
      platform_mutex_unlock(GLock);
  end;
end;

procedure AppendTimingLine(const AName: string; const AMs: Int64);
var
  H: TPlatformFileHandle;
  LPath: string;
  LLine: string;
  LWritten: PtrUInt;
begin
  LPath := TimingFilePath;
  LLine := AName + #9 + IntToStr(AMs) + LineEnding;
  if platform_file_open_ex(PAnsiChar(LPath), fomWriteOnly, fcmOpenOrCreate, True, False, 420, H) <> 0 then
    Exit;
  if platform_file_lock(H, True) <> 0 then
  begin
    platform_file_close(H);
    Exit;
  end;
  try
    if Length(LLine) > 0 then
      platform_file_write(H, @LLine[1], Length(LLine), LWritten);
  finally
    platform_file_unlock(H);
    platform_file_close(H);
  end;
end;

procedure PhaseBegin(const AName: string);
begin
  EnsureEnabledCheck;
  if not GEnabled then
    Exit;
  EnsureLock;
  if GLockReady then
    platform_mutex_lock(GLock);
  try
    SetLength(GFrames, Length(GFrames) + 1);
    GFrames[High(GFrames)].Name := AName;
    GFrames[High(GFrames)].SW := TStopwatch.StartNew;
  finally
    if GLockReady then
      platform_mutex_unlock(GLock);
  end;
end;

procedure PhaseEnd(const AName: string);
var
  FrameIndex: SizeInt;
  Entry: TPhaseFrame;
  Found: Boolean;
  ElapsedMs: Int64;
begin
  if not GEnabled then
    Exit;
  EnsureLock;
  Found := False;
  if GLockReady then
    platform_mutex_lock(GLock);
  try
    FrameIndex := -1;
    for FrameIndex := High(GFrames) downto 0 do
      if GFrames[FrameIndex].Name = AName then
        Break;
    if FrameIndex < 0 then
      Exit;
    if (FrameIndex < 0) or (FrameIndex > High(GFrames)) then
      Exit;
    if GFrames[FrameIndex].Name <> AName then
      Exit;
    Entry := GFrames[FrameIndex];
    if FrameIndex < High(GFrames) then
      Move(GFrames[FrameIndex + 1], GFrames[FrameIndex],
        SizeOf(TPhaseFrame) * SizeInt(High(GFrames) - FrameIndex));
    SetLength(GFrames, Length(GFrames) - 1);
    Found := True;
  finally
    if GLockReady then
      platform_mutex_unlock(GLock);
  end;
  if not Found then
    Exit;
  Entry.SW.Stop;
  ElapsedMs := Entry.SW.ElapsedMilliseconds;
  AppendTimingLine(AName, ElapsedMs);
end;

initialization
  EnsureLock;

finalization
  if GLockReady then
  begin
    platform_mutex_destroy(GLock);
    GLockReady := False;
  end;

end.
