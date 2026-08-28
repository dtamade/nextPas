unit nextpas.core.audio.studio.sequencer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
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
function MidiPitchToFreq(APitch: Integer): Double;

implementation

uses
  nextpas.core.audio.errors,
  Math;

function MidiPitchToFreq(APitch: Integer): Double;
begin
  Result := 440.0 * Power(2, (APitch - 69) / 12.0);
end;

type
  TAudioSequencer = class(TInterfacedObject, IAudioSequencer, IRealtimeAudioSource)
  private
    FFormat: TAudioFormat;
    FBpm: Double;
    FNotes: array of TMidiNote;
    FPos: UInt64;
    FState: TSequencerState;
    FLock: TRTLCriticalSection;
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
  InitCriticalSection(FLock);
end;

destructor TAudioSequencer.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

function TAudioSequencer.GetFormat: TAudioFormat; begin Result := FFormat; end;
function TAudioSequencer.GetBpm: Double; begin EnterCriticalSection(FLock); try Result := FBpm; finally LeaveCriticalSection(FLock); end; end;
procedure TAudioSequencer.SetBpm(ABpm: Double); begin EnterCriticalSection(FLock); try if ABpm > 0 then FBpm := ABpm; finally LeaveCriticalSection(FLock); end; end;

function TAudioSequencer.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin Result := FillRealtime(ABuffer, AFrames); end;

function TAudioSequencer.SeekTo(AFrame: UInt64): Boolean;
begin EnterCriticalSection(FLock); try FPos := AFrame; Result := True; finally LeaveCriticalSection(FLock); end; end;

procedure TAudioSequencer.AddNote(const ANote: TMidiNote);
var L: Integer;
begin
  if (ANote.Pitch < 0) or (ANote.Pitch > 127) then Exit;
  EnterCriticalSection(FLock);
  try
    L := Length(FNotes);
    SetLength(FNotes, L + 1);
    FNotes[L] := ANote;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TAudioSequencer.Clear;
begin
  EnterCriticalSection(FLock);
  try SetLength(FNotes, 0); FPos := 0;
  finally LeaveCriticalSection(FLock); end;
end;

function TAudioSequencer.NoteCount: Integer;
begin EnterCriticalSection(FLock); try Result := Length(FNotes); finally LeaveCriticalSection(FLock); end; end;

procedure TAudioSequencer.Play; begin EnterCriticalSection(FLock); try FState := seqPlaying; finally LeaveCriticalSection(FLock); end; end;
procedure TAudioSequencer.Stop; begin EnterCriticalSection(FLock); try FState := seqStopped; FPos := 0; finally LeaveCriticalSection(FLock); end; end;

function TAudioSequencer.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  LNeeded, I, J: Integer;
  LPhase: Double;
  LFreq: Double;
  LGain: Single;
  LNotes: array of TMidiNote;
  LPos: UInt64;
  LState: TSequencerState;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  LNeeded := AFrames * FFormat.BlockAlign;
  if Length(ABuffer.Data) < LNeeded then Exit(0);
  FillChar(ABuffer.Data[0], LNeeded, 0);
  ABuffer.Format := FFormat;
  ABuffer.FrameCount := AFrames;
  EnterCriticalSection(FLock);
  try
    LState := FState;
    LPos := FPos;
    LNotes := Copy(FNotes, 0, Length(FNotes));
  finally
    LeaveCriticalSection(FLock);
  end;
  if LState <> seqPlaying then Exit(AFrames);
  // simple sine synthesis for active notes
  for I := 0 to AFrames - 1 do
  begin
    LGain := 0;
    for J := 0 to High(LNotes) do
    begin
      if (LPos + UInt64(I) >= LNotes[J].StartFrame) and
         (LPos + UInt64(I) < LNotes[J].StartFrame + LNotes[J].DurationFrames) then
      begin
        LFreq := MidiPitchToFreq(LNotes[J].Pitch);
        LPhase := 2 * Pi * LFreq * (LPos + UInt64(I)) / FFormat.SampleRate;
        LGain := LGain + Single(Sin(LPhase) * (LNotes[J].Velocity / 127.0) * 0.2);
      end;
    end;
    if LGain > 1 then LGain := 1 else if LGain < -1 then LGain := -1;
    for J := 0 to FFormat.Channels - 1 do
      PSingle(@ABuffer.Data[(I * FFormat.Channels + J) * 4])^ := LGain;
  end;
  EnterCriticalSection(FLock);
  try Inc(FPos, UInt64(AFrames));
  finally LeaveCriticalSection(FLock); end;
  Result := AFrames;
end;

function CreateAudioSequencer(const AFormat: TAudioFormat; ABpm: Double): IAudioSequencer;
begin
  Result := TAudioSequencer.Create(AFormat, ABpm);
end;

end.
