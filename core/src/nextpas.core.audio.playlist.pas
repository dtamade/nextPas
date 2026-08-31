unit nextpas.core.audio.playlist;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

const
  PLAYLIST_GUID = '{F1A2B3C4-D5E6-7890-ABCD-A00000000080}';

type
  TPlaylistItem = record
    Buffer: TAudioBuffer;
    Gain: Single;
    CrossfadeMs: Integer;
  end;

  TPlaylistState = (psStopped, psPlaying, psPaused);

  IAudioPlaylist = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-A00000000080}']
    function GetCount: Integer;
    function GetState: TPlaylistState;
    procedure Add(const ABuffer: TAudioBuffer; AGain: Single; ACrossfadeMs: Integer);
    procedure Clear;
    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure Next;
    function CurrentIndex: Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  end;

function CreateAudioPlaylist(const AFormat: TAudioFormat): IAudioPlaylist;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.audio.simd;

type
  TAudioPlaylist = class(TInterfacedObject, IAudioPlaylist, IRealtimeAudioSource)
  private
    FFormat: TAudioFormat;
    FItems: array of TPlaylistItem;
    FIndex: Integer;
    FPos: Integer;
    FState: TPlaylistState;
    FLock: TRTLCriticalSection;
    // IAudioSource
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    // IRealtimeAudioSource
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
  FIndex := 0;
  FPos := 0;
  FState := psStopped;
  InitCriticalSection(FLock);
end;

destructor TAudioPlaylist.Destroy;
begin
  DoneCriticalSection(FLock);
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
  EnterCriticalSection(FLock);
  try
    FPos := Integer(AFrame);
    Result := True;
  finally
    LeaveCriticalSection(FLock);
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
  // realtime: lock-free snapshot (control plane uses lock)
  if FState <> psPlaying then Exit(AFrames);
  if (FIndex < 0) or (FIndex >= Length(FItems)) then Exit(AFrames);
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
  // lock-free advance (single writer is realtime thread)
  Inc(FPos, LFramesToCopy);
  if FPos >= LItem.Buffer.FrameCount then
  begin
    Inc(FIndex);
    FPos := 0;
    if FIndex >= Length(FItems) then
      FState := psStopped;
  end;
  Result := AFrames;
end;

function TAudioPlaylist.GetCount: Integer;
begin
  EnterCriticalSection(FLock);
  try Result := Length(FItems);
  finally LeaveCriticalSection(FLock); end;
end;

function TAudioPlaylist.GetState: TPlaylistState;
begin
  EnterCriticalSection(FLock);
  try Result := FState;
  finally LeaveCriticalSection(FLock); end;
end;

procedure TAudioPlaylist.Add(const ABuffer: TAudioBuffer; AGain: Single; ACrossfadeMs: Integer);
var L: Integer;
begin
  if not ABuffer.Format.IsValid then
    raise EAudioDecodeError.Create('playlist Add: invalid buffer format');
  if (ABuffer.Format.SampleRate <> FFormat.SampleRate) or (ABuffer.Format.Channels <> FFormat.Channels) then
    raise EAudioDecodeError.Create('playlist Add: format mismatch');
  EnterCriticalSection(FLock);
  try
    L := Length(FItems);
    SetLength(FItems, L + 1);
    FItems[L].Buffer := ABuffer;
    FItems[L].Gain := AGain;
    FItems[L].CrossfadeMs := ACrossfadeMs;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TAudioPlaylist.Clear;
begin
  EnterCriticalSection(FLock);
  try
    SetLength(FItems, 0);
    FIndex := 0;
    FPos := 0;
    FState := psStopped;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TAudioPlaylist.Play;
begin
  EnterCriticalSection(FLock);
  try
    if Length(FItems) = 0 then Exit;
    FState := psPlaying;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TAudioPlaylist.Pause;
begin
  EnterCriticalSection(FLock);
  try FState := psPaused; finally LeaveCriticalSection(FLock); end;
end;

procedure TAudioPlaylist.Stop;
begin
  EnterCriticalSection(FLock);
  try
    FState := psStopped;
    FPos := 0;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TAudioPlaylist.Next;
begin
  EnterCriticalSection(FLock);
  try
    if FIndex + 1 < Length(FItems) then
    begin Inc(FIndex); FPos := 0; end
    else
    begin FState := psStopped; end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TAudioPlaylist.CurrentIndex: Integer;
begin
  EnterCriticalSection(FLock);
  try Result := FIndex;
  finally LeaveCriticalSection(FLock); end;
end;

function CreateAudioPlaylist(const AFormat: TAudioFormat): IAudioPlaylist;
begin
  Result := TAudioPlaylist.Create(AFormat);
end;

end.
