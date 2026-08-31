unit nextpas.core.audio.player;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.device.intf,
  nextpas.core.audio.graph.intf,
  nextpas.core.audio.graph,
  nextpas.core.audio.errors;

type
  TAudioPlayer = class(TInterfacedObject, IAudioPlayer)
  private
    FGraph: IAudioGraph;
    FDevice: IAudioDevice;
    FVolume: Single;
  public
    constructor Create(const ADevice: IAudioDevice; const AGraph: IAudioGraph);
    function GetGraph: IAudioGraph;
    function GetDevice: IAudioDevice;
    function GetState: TGraphState;
    function GetPosition: TAudioClock;
    function Play: Boolean;
    function Pause: Boolean;
    function Stop: Boolean;
    function Seek(AFrame: UInt64): Boolean;
    function SetVolume(AVolume: Single): Boolean;
    function GetVolume: Single;
    function PollEvent(out AEvent: TDeviceEvent): Boolean;
  end;

function CreateAudioPlayer(const ADevice: IAudioDevice; const AGraph: IAudioGraph): IAudioPlayer;
function CreateAudioPlayerForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat): IAudioPlayer;

implementation

function CreateAudioPlayer(const ADevice: IAudioDevice; const AGraph: IAudioGraph): IAudioPlayer;
begin
  Result := TAudioPlayer.Create(ADevice, AGraph);
end;

function CreateAudioPlayerForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat): IAudioPlayer;
var G: IAudioGraph; D: IAudioDevice;
begin
  if not Assigned(AProvider) then
    raise EAudioDeviceError.Create('CreateAudioPlayerForFormat: nil provider');
  G := CreateAudioGraph(AFormat);
  D := AProvider.CreateDefaultDevice(AFormat);
  D.SetSource(G as IRealtimeAudioSource);
  Result := TAudioPlayer.Create(D, G);
end;

constructor TAudioPlayer.Create(const ADevice: IAudioDevice; const AGraph: IAudioGraph);
begin
  inherited Create;
  if not Assigned(ADevice) then
    raise EAudioDeviceError.Create('Player: nil device');
  if not Assigned(AGraph) then
    raise EAudioGraphError.Create('Player: nil graph');
  if (ADevice.Format.SampleRate <> AGraph.GetFormat.SampleRate) or
     (ADevice.Format.Channels <> AGraph.GetFormat.Channels) then
    raise EAudioGraphError.Create('Player: device/graph format mismatch');
  FDevice := ADevice;
  FGraph := AGraph;
  FVolume := 1.0;
  try FDevice.SetSource(AGraph as IRealtimeAudioSource); except end;
end;

function TAudioPlayer.GetGraph: IAudioGraph; begin Result := FGraph; end;
function TAudioPlayer.GetDevice: IAudioDevice; begin Result := FDevice; end;

function TAudioPlayer.GetState: TGraphState;
begin
  if FDevice.State = dsStarted then Result := gsPlaying
  else Result := gsStopped;
end;

function TAudioPlayer.GetPosition: TAudioClock;
begin Result := FDevice.GetPosition; end;

function TAudioPlayer.Play: Boolean;
begin
  Result := FDevice.Start;
end;

function TAudioPlayer.Pause: Boolean;
begin
  Result := FDevice.Stop;
end;

function TAudioPlayer.Stop: Boolean;
begin
  Result := FDevice.Stop;
  FGraph.SeekTo(0);
end;

function TAudioPlayer.Seek(AFrame: UInt64): Boolean;
var WasPlaying: Boolean;
begin
  WasPlaying := FDevice.State = dsStarted;
  if WasPlaying then FDevice.Stop;
  Result := FGraph.SeekTo(AFrame);
  if WasPlaying then FDevice.Start;
end;

function TAudioPlayer.SetVolume(AVolume: Single): Boolean;
begin
  if (AVolume < 0) or (AVolume > 4.0) then Exit(False);
  FVolume := AVolume;
  (FGraph as TAudioGraph).Volume := AVolume;
  Result := True;
end;

function TAudioPlayer.GetVolume: Single; begin Result := FVolume; end;

function TAudioPlayer.PollEvent(out AEvent: TDeviceEvent): Boolean;
begin Result := FDevice.PollEvent(AEvent); end;

end.
