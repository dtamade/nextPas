unit nextpas.compiler.frontend.phase_timing;

{**
 * Env-gated phase timing (P0, plan §4.2.1): when NEXTPAS_PHASE_TIMING=1,
 * each PhaseEnd appends one TSV line "name\tms" to /tmp/m2-phase-timing.tsv.
 * Disabled = one boolean check per boundary, zero writes. Cold path only:
 * wrap session phases (syntax/resolution/sema/mir), never per-node walks.
 * Append-per-end keeps flush-free semantics even on aborted sessions;
 * nested phases are supported via a tiny name-matched stack. Single-threaded
 * compilation only — no locking by design.
 *}

{$mode objfpc}{$H+}

interface

procedure PhaseBegin(const AName: string);
procedure PhaseEnd(const AName: string);

implementation

uses
  nextpas.core.os.env, nextpas.core.time.stopwatch;

type
  TPhaseFrame = record
    Name: string;
    SW: TStopwatch;
  end;

const
  TimingEnvName = 'NEXTPAS_PHASE_TIMING';
  TimingFilePath = '/tmp/m2-phase-timing.tsv';

var
  GEnabled: Boolean = False;
  GChecked: Boolean = False;
  GFrames: array of TPhaseFrame;

procedure EnsureEnabledCheck;
var
  Raw: string;
begin
  if GChecked then
    Exit;
  GChecked := True;
  Raw := GetEnvironmentVariable(TimingEnvName);
  GEnabled := (Raw = '1') or (Raw = 'true') or (Raw = 'on');
end;

procedure PhaseBegin(const AName: string);
begin
  EnsureEnabledCheck;
  if not GEnabled then
    Exit;
  SetLength(GFrames, Length(GFrames) + 1);
  GFrames[High(GFrames)].Name := AName;
  GFrames[High(GFrames)].SW := TStopwatch.StartNew;
end;

procedure PhaseEnd(const AName: string);
var
  FrameIndex: SizeInt;
  Entry: TPhaseFrame;
  F: Text;
begin
  if not GEnabled then
    Exit;
  { Match nearest enclosing frame with the same name (LIFO). }
  FrameIndex := -1;
  for FrameIndex := High(GFrames) downto 0 do
    if GFrames[FrameIndex].Name = AName then
      Break;
  if FrameIndex < 0 then
    Exit;
  Entry := GFrames[FrameIndex];
  if FrameIndex < High(GFrames) then
    Move(GFrames[FrameIndex + 1], GFrames[FrameIndex],
      SizeOf(TPhaseFrame) * SizeInt(High(GFrames) - FrameIndex));
  SetLength(GFrames, Length(GFrames) - 1);
  Entry.SW.Stop;
  {$I-}
  Assign(F, TimingFilePath);
  Append(F);
  if IOResult <> 0 then
  begin
    Rewrite(F);
    if IOResult <> 0 then
      Exit;
  end;
  WriteLn(F, AName, #9, Entry.SW.ElapsedMilliseconds);
  Close(F);
  {$I+}
end;

end.
