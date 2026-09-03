unit nextpas.core.audio.studio.sequencer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sync.mutex,
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  TMidiNote = record
    Pitch: Integer; // 0..127
    Velocity: Integer; // 0..127
    StartFrame: UInt64;
    DurationFrames: UInt64;
  end;

  TSequencerState = (seqStopped, seqPlaying);

  IAudioSequencer = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000072}']
    function GetBpm: Double;
    procedure SetBpm(ABpm: Double);
    procedure AddNote(const ANote: TMidiNote);
    procedure Clear;
    function NoteCount: Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    procedure Play;
    procedure Stop;
    function GetFormat: TAudioFormat;
  end;

function CreateAudioSequencer(const AFormat: TAudioFormat; ABpm: Double): IAudioSequencer;
function MidiPitchToFreq(APitch: Integer): Double; inline;

const
  C_SINE_TABLE_BITS = 11;
  C_SINE_TABLE_SIZE = 1 shl C_SINE_TABLE_BITS; // 2048
  C_SINE_TABLE_MASK = C_SINE_TABLE_SIZE - 1;

var
  GSineTable: array[0..2047] of Single;
  GSineInit: Boolean;

procedure InitSineTable;
function FastSin(APhase: Double): Single; inline;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig;

procedure InitSineTable;
var I: Integer;
begin
  if GSineInit then Exit;
  for I := 0 to C_SINE_TABLE_SIZE - 1 do
    GSineTable[I] := Sin(2 * PI_VALUE * I / C_SINE_TABLE_SIZE);
  GSineInit := True;
end;

function FastSin(APhase: Double): Single; inline;
var Idx: Double; I0, I1: Integer; Frac: Double; V0, V1: Single;
begin
  Idx := APhase * (C_SINE_TABLE_SIZE / (2 * PI_VALUE));
  I0 := Trunc(Idx) and C_SINE_TABLE_MASK;
  if I0 < 0 then I0 := (I0 and C_SINE_TABLE_MASK);
  Frac := Idx - Trunc(Idx);
  if Frac < 0 then Frac := Frac + 1;
  I1 := (I0 + 1) and C_SINE_TABLE_MASK;
  V0 := GSineTable[I0]; V1 := GSineTable[I1];
  Result := V0 + (V1 - V0) * Single(Frac);
end;

function MidiPitchToFreq(APitch: Integer): Double; inline;
begin
  Result := 440.0 * Power(2, (APitch - 69) / 12.0);
end;

type
  TAudioSequencer = class(TInterfacedObject, IAudioSequencer, IRealtimeAudioSource)
  private
    FFormat: TAudioFormat;
    FBpm: Double;
    FNotes: array of TMidiNote;
    FNoteInc: array of Double;   // 2*PI_VALUE*Freq/SampleRate, per-note cache (realtime zero-alloc)
    FNoteVel: array of Single;   // Velocity/127*0.2
    FSnapshotNotes: array of TMidiNote;
    FSnapshotInc: array of Double;
    FSnapshotVel: array of Single;
    FPos: UInt64;
    FState: TSequencerState;
    FLock: TRecursiveMutex;
    procedure RebuildNoteCache;
    procedure EnsureSnapshotCapacity(ANeeded: Integer); inline;
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  public
    constructor Create(const AFormat: TAudioFormat; ABpm: Double);
    destructor Destroy; override;
    function GetBpm: Double;
    procedure SetBpm(ABpm: Double);
    procedure AddNote(const ANote: TMidiNote);
    procedure Clear;
    function NoteCount: Integer;
    procedure Play;
    procedure Stop;
  end;

constructor TAudioSequencer.Create(const AFormat: TAudioFormat; ABpm: Double);
begin
  inherited Create;
  if not AFormat.IsValid then
    raise EAudioDeviceError.Create('sequencer: invalid format');
  FFormat := AFormat;
  if ABpm <= 0 then FBpm := 120 else FBpm := ABpm;
  FState := seqStopped;
  FPos := 0;
  FLock := TRecursiveMutex.Create;
  InitSineTable;
end;

destructor TAudioSequencer.Destroy;
begin
  SetLength(FSnapshotNotes, 0);
  SetLength(FSnapshotInc, 0);
  SetLength(FSnapshotVel, 0);
  FLock.Free;
  inherited;
end;

function TAudioSequencer.GetFormat: TAudioFormat; begin Result := FFormat; end;
function TAudioSequencer.GetBpm: Double; begin FLock.Acquire; try Result := FBpm; finally FLock.Release; end; end;
procedure TAudioSequencer.SetBpm(ABpm: Double); begin FLock.Acquire; try if ABpm > 0 then FBpm := ABpm; finally FLock.Release; end; end;

function TAudioSequencer.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin Result := FillRealtime(ABuffer, AFrames); end;

function TAudioSequencer.SeekTo(AFrame: UInt64): Boolean;
begin FLock.Acquire; try FPos := AFrame; Result := True; finally FLock.Release; end; end;

procedure TAudioSequencer.RebuildNoteCache;
var I: Integer; F: Double;
begin
  SetLength(FNoteInc, Length(FNotes));
  SetLength(FNoteVel, Length(FNotes));
  for I := 0 to High(FNotes) do
  begin
    F := MidiPitchToFreq(FNotes[I].Pitch);
    FNoteInc[I] := 2 * PI_VALUE * F / FFormat.SampleRate;
    FNoteVel[I] := Single(FNotes[I].Velocity / 127.0 * CAudioSeqVelScale);
  end;
  // control-plane preallocate snapshot capacity geometric
  EnsureSnapshotCapacity(Length(FNotes));
end;

procedure TAudioSequencer.EnsureSnapshotCapacity(ANeeded: Integer); inline;
var LCap: Integer;
begin
  LCap := Length(FSnapshotNotes);
  AudioEnsureCapacity(LCap, ANeeded, 4);
  if Length(FSnapshotNotes) <> LCap then SetLength(FSnapshotNotes, LCap);
  LCap := Length(FSnapshotInc);
  AudioEnsureCapacity(LCap, ANeeded, 4);
  if Length(FSnapshotInc) <> LCap then SetLength(FSnapshotInc, LCap);
  LCap := Length(FSnapshotVel);
  AudioEnsureCapacity(LCap, ANeeded, 4);
  if Length(FSnapshotVel) <> LCap then SetLength(FSnapshotVel, LCap);
end;

procedure TAudioSequencer.AddNote(const ANote: TMidiNote);
var L: Integer;
begin
  if (ANote.Pitch < 0) or (ANote.Pitch > 127) then Exit;
  FLock.Acquire;
  try
    L := Length(FNotes);
    SetLength(FNotes, L + 1);
    FNotes[L] := ANote;
    RebuildNoteCache;
  finally
    FLock.Release;
  end;
end;

procedure TAudioSequencer.Clear;
begin
  FLock.Acquire;
  try SetLength(FNotes, 0); SetLength(FNoteInc, 0); SetLength(FNoteVel, 0); FPos := 0;
  finally FLock.Release; end;
end;

function TAudioSequencer.NoteCount: Integer;
begin FLock.Acquire; try Result := Length(FNotes); finally FLock.Release; end; end;

procedure TAudioSequencer.Play; begin FLock.Acquire; try FState := seqPlaying; finally FLock.Release; end; end;
procedure TAudioSequencer.Stop; begin FLock.Acquire; try FState := seqStopped; FPos := 0; finally FLock.Release; end; end;

function TAudioSequencer.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  LNeeded, I, J, LCount: Integer;
  LPhase: Double;
  LGain: Single;
  LPos: UInt64;
  LState: TSequencerState;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  if AudioBytesForFrames(FFormat, AFrames)>High(Integer) then Exit(0);
  LNeeded := AFrames * FFormat.BlockAlign;
  if Length(ABuffer.Data) < LNeeded then Exit(0);
  AudioSilentFill(ABuffer, FFormat, AFrames);
  // two-phase snapshot: copy notes/inc/vel under lock, mixing lock-free
  FLock.Acquire;
  try
    LState := FState;
    LPos := FPos;
    LCount := Length(FNotes);
    // realtime must not GetMem: clamp to preallocated snapshot capacity (control plane ensures geometric growth)
    if LCount > Length(FSnapshotNotes) then LCount := Length(FSnapshotNotes);
    if LCount > Length(FSnapshotInc) then LCount := Length(FSnapshotInc);
    if LCount > Length(FSnapshotVel) then LCount := Length(FSnapshotVel);
    for J := 0 to LCount - 1 do
    begin
      FSnapshotNotes[J] := FNotes[J];
      FSnapshotInc[J] := FNoteInc[J];
      FSnapshotVel[J] := FNoteVel[J];
    end;
  finally FLock.Release; end;
  if LState <> seqPlaying then Exit(AFrames);
  if LCount <= 0 then
  begin
    FLock.Acquire; try Inc(FPos, UInt64(AFrames)); finally FLock.Release; end;
    Exit(AFrames);
  end;
  for I := 0 to AFrames - 1 do
  begin
    LGain := 0;
    for J := 0 to LCount - 1 do
    begin
      if (LPos + UInt64(I) >= FSnapshotNotes[J].StartFrame) and
         (LPos + UInt64(I) < FSnapshotNotes[J].StartFrame + FSnapshotNotes[J].DurationFrames) then
      begin
        LPhase := FSnapshotInc[J] * (LPos + UInt64(I));
        LGain := LGain + FastSin(LPhase) * FSnapshotVel[J];
      end;
    end;
    if LGain > 1 then LGain := 1 else if LGain < -1 then LGain := -1;
    for J := 0 to FFormat.Channels - 1 do
      PSingle(@ABuffer.Data[(I * FFormat.Channels + J) * 4])^ := LGain;
  end;
  FLock.Acquire; try Inc(FPos, UInt64(AFrames)); finally FLock.Release; end;
  Result := AFrames;
end;

function CreateAudioSequencer(const AFormat: TAudioFormat; ABpm: Double): IAudioSequencer;
begin
  Result := TAudioSequencer.Create(AFormat, ABpm);
end;

end.
