unit nextpas.core.audio.studio;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.studio.base,
  nextpas.core.audio.studio.intf,
  nextpas.core.audio.studio.automation,
  nextpas.core.audio.studio.project,
  nextpas.core.audio.studio.sequencer;

type
  TAudioStudio = nextpas.core.audio.studio.intf.IAudioStudio;
  IAudioStudio = nextpas.core.audio.studio.intf.IAudioStudio;
  IStudioProject = nextpas.core.audio.studio.intf.IStudioProject;
  TStudioProject = nextpas.core.audio.studio.project.TStudioProject;
  IAudioSequencer = nextpas.core.audio.studio.sequencer.IAudioSequencer;
  TSequencerState = nextpas.core.audio.studio.sequencer.TSequencerState;
  TMidiNote = nextpas.core.audio.studio.sequencer.TMidiNote;
  TAutomationPoint = nextpas.core.audio.studio.automation.TAutomationPoint;
  TAutomationCurve = nextpas.core.audio.studio.automation.TAutomationCurve;

function StudioBpmToFramesPerBeat(ABpm: Double; ASampleRate: Integer): Integer; inline;
function StudioQuantizeFrame(AFrame: UInt64; ABpm: Double; ASampleRate: Integer): UInt64; inline;
function CreateStudioProject(const AName: string; ABpm: Double; const AFormat: TAudioFormat): IStudioProject; inline;
function CreateAudioSequencer(const AFormat: TAudioFormat; ABpm: Double): IAudioSequencer; inline;

implementation

function StudioBpmToFramesPerBeat(ABpm: Double; ASampleRate: Integer): Integer; inline;
begin
  Result := nextpas.core.audio.studio.intf.StudioBpmToFramesPerBeat(ABpm, ASampleRate);
end;

function StudioQuantizeFrame(AFrame: UInt64; ABpm: Double; ASampleRate: Integer): UInt64; inline;
begin
  Result := nextpas.core.audio.studio.intf.StudioQuantizeFrame(AFrame, ABpm, ASampleRate);
end;

function CreateStudioProject(const AName: string; ABpm: Double; const AFormat: TAudioFormat): IStudioProject; inline;
begin
  Result := nextpas.core.audio.studio.project.CreateStudioProject(AName, ABpm, AFormat);
end;

function CreateAudioSequencer(const AFormat: TAudioFormat; ABpm: Double): IAudioSequencer; inline;
begin
  Result := nextpas.core.audio.studio.sequencer.CreateAudioSequencer(AFormat, ABpm);
end;

end.
