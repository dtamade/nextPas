unit nextpas.core.audio.playlist.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.playlist.base,
  nextpas.core.audio.playlist.intf;

function CreateAudioPlaylist(const AFormat: TAudioFormat): IAudioPlaylist;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.sync.mutex,
  nextpas.core.audio.errors,
  nextpas.core.audio.simd;

type
  TAudioPlaylist = class(TInterfacedObject, IAudioPlaylist, IRealtimeAudioSource)
  private
    FFormat: TAudioFormat;
    FItems: array of TPlaylistItem;
    FCount: Integer;
    FIndex: Integer;
    FPos: Integer;
    FState: TPlaylistState;
    FLock: TRecursiveMutex;
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  public
    constructor Create(const AFormat: TAudioFormat);
    destructor Destroy; override;
    function GetCount: Integer;
    function GetState: TPlaylistState;
    procedure Add(const ABuffer: TAudioBuffer; AGain: Single; ACrossfadeMs: Integer);
    procedure Clear;
    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure Next;
    function CurrentIndex: Integer;
  end;

constructor TAudioPlaylist.Create(const AFormat: TAudioFormat);
begin
  inherited Create;
  if not AFormat.IsValid then
    raise EAudioDeviceError.Create('playlist: invalid format');
  FFormat := AFormat;
  FCount := 0;
  FIndex := 0;
  FPos := 0;
  FState := psStopped;
  FLock := TRecursiveMutex.Create;
end;

destructor TAudioPlaylist.Destroy;
var I: Integer;
begin
  if Assigned(FLock) then
  begin
    FLock.Acquire;
    try
      for I := 0 to High(FItems) do SetLength(FItems[I].Buffer.Data, 0);
      SetLength(FItems, 0);
    finally FLock.Release; end;
  end;
  FLock.Free;
  inherited;
end;

function TAudioPlaylist.GetFormat: TAudioFormat;
begin Result := FFormat; end;

function TAudioPlaylist.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := FillRealtime(ABuffer, AFrames);
end;

function TAudioPlaylist.SeekTo(AFrame: UInt64): Boolean;
begin
  FLock.Acquire;
  try
    FPos := Integer(AFrame);
    Result := True;
  finally
    FLock.Release;
  end;
end;

function TAudioPlaylist.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  LNeeded, LFramesToCopy, LOffset, LAvail, LCopied: Integer;
  LSrc: PSingle;
  LDst: PSingle;
  LItem: TPlaylistItem;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  if AudioBytesForFrames(FFormat, AFrames)>High(Integer) then Exit(0);
  LNeeded := AFrames * FFormat.BlockAlign;
  if Length(ABuffer.Data) < LNeeded then Exit(0);
  AudioSilentFill(ABuffer, FFormat, AFrames);
  if FState <> psPlaying then Exit(AFrames);
  if (FIndex < 0) or (FIndex >= FCount) then Exit(AFrames);
  LItem := FItems[FIndex];
  LOffset := FPos;
  LAvail := LItem.Buffer.FrameCount - LOffset;
  if LAvail <= 0 then Exit(AFrames);
  LFramesToCopy := AFrames;
  if LFramesToCopy > LAvail then LFramesToCopy := LAvail;
  if LFramesToCopy <= 0 then Exit(AFrames);
  LCopied := LFramesToCopy * FFormat.Channels;
  if Length(LItem.Buffer.Data) < (LOffset + LFramesToCopy) * FFormat.BlockAlign then Exit(AFrames);
  LDst := PSingle(@ABuffer.Data[0]);
  LSrc := PSingle(@LItem.Buffer.Data[LOffset * FFormat.Channels]);
  SimdAddF32(LSrc, LDst, LCopied, LItem.Gain);
  Inc(FPos, LFramesToCopy);
  if FPos >= LItem.Buffer.FrameCount then
  begin
    Inc(FIndex);
    FPos := 0;
    if FIndex >= FCount then
      FState := psStopped;
  end;
  Result := AFrames;
end;

function TAudioPlaylist.GetCount: Integer;
begin
  FLock.Acquire;
  try Result := FCount;
  finally FLock.Release; end;
end;

function TAudioPlaylist.GetState: TPlaylistState;
begin
  FLock.Acquire;
  try Result := FState;
  finally FLock.Release; end;
end;

procedure TAudioPlaylist.Add(const ABuffer: TAudioBuffer; AGain: Single; ACrossfadeMs: Integer);
var LCap: Integer;
begin
  if not ABuffer.Format.IsValid then
    raise EAudioDecodeError.Create('playlist Add: invalid buffer format');
  if (ABuffer.Format.SampleRate <> FFormat.SampleRate) or (ABuffer.Format.Channels <> FFormat.Channels) then
    raise EAudioDecodeError.Create('playlist Add: format mismatch');
  FLock.Acquire;
  try
    LCap := Length(FItems);
    AudioEnsureCapacity(LCap, FCount + 1, 4);
    if Length(FItems) <> LCap then SetLength(FItems, LCap);
    FItems[FCount].Buffer := ABuffer;
    FItems[FCount].Buffer.Data := SpanClone(TByteSpan.FromBytes(ABuffer.Data)); // bytes.ops 单源 deep copy 隔离
    FItems[FCount].Gain := AGain;
    FItems[FCount].CrossfadeMs := ACrossfadeMs;
    Inc(FCount);
  finally
    FLock.Release;
  end;
end;

procedure TAudioPlaylist.Clear;
var I: Integer;
begin
  FLock.Acquire;
  try
    for I := 0 to High(FItems) do SetLength(FItems[I].Buffer.Data, 0);
    SetLength(FItems, 0);
    FCount := 0;
    FIndex := 0;
    FPos := 0;
    FState := psStopped;
  finally
    FLock.Release;
  end;
end;

procedure TAudioPlaylist.Play;
begin
  FLock.Acquire;
  try
    if FCount = 0 then Exit;
    FState := psPlaying;
  finally
    FLock.Release;
  end;
end;

procedure TAudioPlaylist.Pause;
begin
  FLock.Acquire;
  try FState := psPaused; finally FLock.Release; end;
end;

procedure TAudioPlaylist.Stop;
begin
  FLock.Acquire;
  try
    FState := psStopped;
    FPos := 0;
  finally
    FLock.Release;
  end;
end;

procedure TAudioPlaylist.Next;
begin
  FLock.Acquire;
  try
    if FIndex + 1 < FCount then
    begin Inc(FIndex); FPos := 0; end
    else
    begin FState := psStopped; end;
  finally
    FLock.Release;
  end;
end;

function TAudioPlaylist.CurrentIndex: Integer;
begin
  FLock.Acquire;
  try Result := FIndex;
  finally FLock.Release; end;
end;

function CreateAudioPlaylist(const AFormat: TAudioFormat): IAudioPlaylist;
begin
  Result := TAudioPlaylist.Create(AFormat);
end;

end.
