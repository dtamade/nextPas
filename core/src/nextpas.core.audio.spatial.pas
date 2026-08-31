unit nextpas.core.audio.spatial;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.spatial.intf,
  nextpas.core.sync.mutex;

type
  TAudioSpatialSource = class(TInterfacedObject, IAudioSpatialSource, IRealtimeAudioSource, IAudioSource)
  private
    FSource: IRealtimeAudioSource;
    FFormat: TAudioFormat;
    FListener: TAudioListener;
    FParams: TAudioSpatialParams;
    FLock: TRecursiveMutex;
    // snapshot scratch for FillRealtime (mono->stereo pan)
    FScratch: TBytes;
    procedure EnsureScratch(ANeeded: Integer);
  public
    constructor Create(const ASource: IRealtimeAudioSource; const AListener: TAudioListener; const AParams: TAudioSpatialParams);
    destructor Destroy; override;
    // IAudioSource
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    // IRealtimeAudioSource
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    // IAudioSpatialSource
    procedure SetPosition(const APos: TAudioVec3);
    function GetPosition: TAudioVec3;
    procedure SetVelocity(const AVel: TAudioVec3);
    function GetVelocity: TAudioVec3;
    procedure SetSpatialParams(const AParams: TAudioSpatialParams);
    function GetSpatialParams: TAudioSpatialParams;
    procedure SetListener(const AListener: TAudioListener);
    function GetListener: TAudioListener;
  end;

function CreateSpatialSource(const ASource: IRealtimeAudioSource; const AListener: TAudioListener; const AParams: TAudioSpatialParams): IAudioSpatialSource;

implementation

uses nextpas.core.base.utils, nextpas.core.audio.mix;

function CreateSpatialSource(const ASource: IRealtimeAudioSource; const AListener: TAudioListener; const AParams: TAudioSpatialParams): IAudioSpatialSource;
begin
  Result := TAudioSpatialSource.Create(ASource, AListener, AParams);
end;

constructor TAudioSpatialSource.Create(const ASource: IRealtimeAudioSource; const AListener: TAudioListener; const AParams: TAudioSpatialParams);
begin
  inherited Create;
  if not Assigned(ASource) then raise EInvalidArgument.Create('spatial: nil source');
  FSource := ASource;
  FFormat := ASource.GetFormat;
  if not FFormat.IsValid then raise EInvalidArgument.Create('spatial: invalid source format');
  // v1: spatial panning requires mono or stereo sfF32 for zero-alloc; other formats via PcmConvert in FillRealtime is allowed but keep F32 — offline path preallocated, realtime path already F32 via EnsureF32
  FListener := AListener;
  FParams := AParams;
  FLock := TRecursiveMutex.Create;
end;

destructor TAudioSpatialSource.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TAudioSpatialSource.EnsureScratch(ANeeded: Integer);
var LCap: Integer;
begin
  LCap := Length(FScratch);
  AudioEnsureCapacity(LCap, ANeeded, 256);
  if Length(FScratch) <> LCap then SetLength(FScratch, LCap);
end;

function TAudioSpatialSource.GetFormat: TAudioFormat;
begin
  Result := FFormat;
end;

function TAudioSpatialSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := FillRealtime(ABuffer, AFrames);
end;

function TAudioSpatialSource.SeekTo(AFrame: UInt64): Boolean;
var Src: IAudioSource;
begin
  if Supports(FSource, IAudioSource, Src) then Result := Src.SeekTo(AFrame) else Result := False;
end;

procedure TAudioSpatialSource.SetPosition(const APos: TAudioVec3);
begin
  FLock.Acquire; try FParams.Position := APos; finally FLock.Release; end;
end;

function TAudioSpatialSource.GetPosition: TAudioVec3;
begin
  FLock.Acquire; try Result := FParams.Position; finally FLock.Release; end;
end;

procedure TAudioSpatialSource.SetVelocity(const AVel: TAudioVec3);
begin
  FLock.Acquire; try FParams.Velocity := AVel; finally FLock.Release; end;
end;

function TAudioSpatialSource.GetVelocity: TAudioVec3;
begin
  FLock.Acquire; try Result := FParams.Velocity; finally FLock.Release; end;
end;

procedure TAudioSpatialSource.SetSpatialParams(const AParams: TAudioSpatialParams);
begin
  FLock.Acquire; try FParams := AParams; finally FLock.Release; end;
end;

function TAudioSpatialSource.GetSpatialParams: TAudioSpatialParams;
begin
  FLock.Acquire; try Result := FParams; finally FLock.Release; end;
end;

procedure TAudioSpatialSource.SetListener(const AListener: TAudioListener);
begin
  FLock.Acquire; try FListener := AListener; finally FLock.Release; end;
end;

function TAudioSpatialSource.GetListener: TAudioListener;
begin
  FLock.Acquire; try Result := FListener; finally FLock.Release; end;
end;

function TAudioSpatialSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  LGain, LPan, LDoppler: Single;
  LListener: TAudioListener;
  LParams: TAudioSpatialParams;
  LNeed: Integer;
  LSrcBuf: TAudioBuffer;
  LSrcData: TBytes;
  LGains: TAudioPanGains;
  LSrcPtr, LDstPtr: PSingle;
  LI, LFrames, LCh: Integer;
begin
  // two-phase snapshot: copy listener+params under lock, mixing lock-free
  FLock.Acquire; try LListener := FListener; LParams := FParams; finally FLock.Release; end;
  // snapshot mixing - lock free: compute spatial
  AudioSpatialize(LListener, LParams, LGain, LPan, LDoppler);
  // Doppler: v1 expose via GetSpatialParams, not resampled here (would need resampler)
  // Fill source into scratch then pan
  if (AFrames <= 0) then Exit(0);
  LNeed := Integer(Int64(AFrames) * Int64(FFormat.BlockAlign));
  if LNeed < 0 then
    LNeed := 0;
  if Length(ABuffer.Data) < LNeed then
  begin
    // realtime violation: clamp
    LFrames := Length(ABuffer.Data) div FFormat.BlockAlign;
    if LFrames <= 0 then Exit(0);
    AFrames := LFrames;
  end;
  // ensure FScratch for source fetch (reuse)
  EnsureScratch(AFrames * FFormat.BlockAlign);
  LSrcBuf.Format := FFormat;
  LSrcBuf.FrameCount := AFrames;
  LSrcBuf.Data := FScratch;
  // keep FScratch reference alive via LSrcData
  LSrcData := FScratch;
  LSrcBuf.Data := LSrcData;
  Result := FSource.FillRealtime(LSrcBuf, AFrames);
  if Result <= 0 then
  begin
    FillChar(ABuffer.Data[0], AFrames * FFormat.BlockAlign, 0);
    Exit(Result);
  end;
  // apply distance gain + pan
  LCh := FFormat.Channels;
  if FFormat.SampleFormat <> sfF32 then
  begin
    // fallback: already F32 canonical per EnsureF32 in pipeline, but keep guard
    Move(LSrcBuf.Data[0], ABuffer.Data[0], Result * FFormat.BlockAlign);
    Exit(Result);
  end;
  // 0dB center for game loudness (reuse PanLawGains0dB)
  LGains := PanLawGains0dB(LPan);
  LSrcPtr := PSingle(@LSrcBuf.Data[0]);
  LDstPtr := PSingle(@ABuffer.Data[0]);
  if LCh = 1 then
  begin
    // mono: distance gain only, pan is informational (future mono->stereo via channel conversion)
    for LI := 0 to Result - 1 do
      LDstPtr[LI] := LSrcPtr[LI] * LGain;
  end else if LCh = 2 then
  begin
    for LI := 0 to Result - 1 do
    begin
      LDstPtr[LI*2] := LSrcPtr[LI*2] * LGain * LGains.X;
      LDstPtr[LI*2+1] := LSrcPtr[LI*2+1] * LGain * LGains.Y;
    end;
  end else
  begin
    // 1..8ch fallback: apply gain to all
    for LI := 0 to Result * LCh - 1 do
      LDstPtr[LI] := LSrcPtr[LI] * LGain;
  end;
  // clamp
  for LI := 0 to Result * LCh - 1 do
  begin
    if LDstPtr[LI] > 1.0 then LDstPtr[LI] := 1.0 else if LDstPtr[LI] < -1.0 then LDstPtr[LI] := -1.0;
  end;
end;

end.
