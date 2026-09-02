unit nextpas.core.audio.bus.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.bus.base,
  nextpas.core.audio.bus.intf;

function CreateAudioBusMixer: IAudioBusMixer;

implementation

uses
  nextpas.core.base,
  nextpas.core.audio.errors,
  nextpas.core.audio.simd,
  nextpas.core.bytes.ops,
  nextpas.core.sync;

type
  TAudioBus = class(TInterfacedObject, IAudioBus, IRealtimeAudioSource)
  private
    FId: TAudioBusId;
    FGain: Single;
    FFormat: TAudioFormat;
    FSource: IRealtimeAudioSource;
    FScratch: TAudioBuffer;
    FLock: IMutex;
    function GetId: TAudioBusId; inline;
    function GetGain: Single;
    procedure SetGain(AGain: Single);
    function GetFormat: TAudioFormat; inline;
    function GetSource: IRealtimeAudioSource;
    function GetFormatI: TAudioFormat; inline;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    procedure EnsureScratch(ANeeded: Integer); inline;
  public
    constructor Create(AId: TAudioBusId; const AFormat: TAudioFormat);
    destructor Destroy; override;
    procedure AttachSource(const ASource: IRealtimeAudioSource);
  end;

  TAudioBusMixer = class(TInterfacedObject, IAudioBusMixer)
  private
    FBuses: array of IAudioBus;
    FBusCount: Integer;
    FNextId: TAudioBusId;
    FScratch: TAudioBuffer;
    FSnapshotBuses: array of IAudioBus;
    FLock: IMutex;
    FViolations: Int64;
    procedure EnsureScratch(ANeeded: Integer); inline;
    procedure EnsureSnapshotCapacity(ANeeded: Integer); inline;
  public
    constructor Create;
    destructor Destroy; override;
    function CreateBus(const AFormat: TAudioFormat): IAudioBus;
    function GetBus(AId: TAudioBusId): IAudioBus;
    function BusCount: Integer;
    function MixRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  end;

{ TAudioBus }

constructor TAudioBus.Create(AId: TAudioBusId; const AFormat: TAudioFormat);
var Cap: Integer;
begin
  inherited Create;
  FId := AId;
  FGain := 1.0;
  FFormat := AFormat;
  FLock := Mutex;
  Cap := CAudioBusMaxScratchFrames * AFormat.BlockAlign;
  SetLength(FScratch.Data, Cap);
  FScratch.Format := AFormat;
end;

destructor TAudioBus.Destroy;
begin
  SetLength(FScratch.Data, 0);
  FLock := nil;
  inherited;
end;

function TAudioBus.GetId: TAudioBusId; inline; begin Result := FId; end;
function TAudioBus.GetGain: Single;
begin
  FLock.Acquire;
  try Result := FGain; finally FLock.Release; end;
end;
procedure TAudioBus.SetGain(AGain: Single);
begin
  FLock.Acquire;
  try FGain := AGain; finally FLock.Release; end;
end;
function TAudioBus.GetFormat: TAudioFormat; inline; begin Result := FFormat; end;
function TAudioBus.GetFormatI: TAudioFormat; inline; begin Result := FFormat; end;
function TAudioBus.GetSource: IRealtimeAudioSource;
begin
  FLock.Acquire;
  try Result := FSource; finally FLock.Release; end;
end;

procedure TAudioBus.AttachSource(const ASource: IRealtimeAudioSource);
begin
  FLock.Acquire;
  try FSource := ASource; finally FLock.Release; end;
end;

procedure TAudioBus.EnsureScratch(ANeeded: Integer); inline;
var LCap: Integer;
begin
  if Length(FScratch.Data) >= ANeeded then Exit;
  LCap := Length(FScratch.Data);
  AudioEnsureCapacity(LCap, ANeeded, 256);
  if Length(FScratch.Data) <> LCap then SetLength(FScratch.Data, LCap);
  FScratch.Format := FFormat;
end;

function TAudioBus.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin Result := FillRealtime(ABuffer, AFrames); end;

function TAudioBus.SeekTo(AFrame: UInt64): Boolean;
var LSrc: IRealtimeAudioSource;
begin
  LSrc := GetSource;
  if Assigned(LSrc) then Result := LSrc.SeekTo(AFrame) else Result := False;
end;

function TAudioBus.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var LSrc: IRealtimeAudioSource; LGain: Single; LNeeded: Integer;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  if AudioBytesForFrames(FFormat, AFrames)>High(Integer) then Exit(0);
  LNeeded := Integer(AudioBytesForFrames(FFormat, AFrames));
  if Length(ABuffer.Data) < LNeeded then Exit(0);
  AudioSilentFill(ABuffer, FFormat, AFrames);
  // two-phase snapshot: copy source/gain under lock, mixing lock-free — realtime no alloc
  FLock.Acquire; try LSrc := FSource; LGain := FGain; finally FLock.Release; end;
  if not Assigned(LSrc) then Exit(AFrames);
  if Length(FScratch.Data) < LNeeded then Exit(AFrames);
  FScratch.FrameCount := AFrames;
  try
    LSrc.FillRealtime(FScratch, AFrames);
  except
    Exit(AFrames);
  end;
  SimdAddF32(PSingle(@FScratch.Data[0]), PSingle(@ABuffer.Data[0]), AFrames * FFormat.Channels, LGain);
  Result := AFrames;
end;

{ TAudioBusMixer }

constructor TAudioBusMixer.Create;
begin
  inherited Create;
  FBusCount := 0;
  FNextId := 1;
  FLock := Mutex;
  SetLength(FScratch.Data, CAudioBusMixerScratchBytes);
end;

destructor TAudioBusMixer.Destroy;
begin
  SetLength(FScratch.Data, 0);
  SetLength(FSnapshotBuses, 0);
  FLock := nil;
  inherited;
end;

procedure TAudioBusMixer.EnsureScratch(ANeeded: Integer); inline;
var LCap: Integer;
begin
  if Length(FScratch.Data) >= ANeeded then Exit;
  LCap := Length(FScratch.Data);
  AudioEnsureCapacity(LCap, ANeeded, 256);
  if Length(FScratch.Data) <> LCap then SetLength(FScratch.Data, LCap);
end;

procedure TAudioBusMixer.EnsureSnapshotCapacity(ANeeded: Integer); inline;
var LCap: Integer;
begin
  LCap := Length(FSnapshotBuses);
  AudioEnsureCapacity(LCap, ANeeded, 4);
  if Length(FSnapshotBuses) <> LCap then SetLength(FSnapshotBuses, LCap);
end;

function TAudioBusMixer.CreateBus(const AFormat: TAudioFormat): IAudioBus;
var LCap: Integer; B: TAudioBus;
begin
  if not AFormat.IsValid then
    raise EAudioDeviceError.Create('bus: invalid format');
  FLock.Acquire;
  try
    B := TAudioBus.Create(FNextId, AFormat);
    Inc(FNextId);
    LCap := Length(FBuses);
    AudioEnsureCapacity(LCap, FBusCount + 1, 4);
    if Length(FBuses) <> LCap then SetLength(FBuses, LCap);
    FBuses[FBusCount] := B;
    Inc(FBusCount);
    // control-plane preallocate snapshot capacity (geometric, zero violation steady)
    if Length(FSnapshotBuses) < FBusCount then EnsureSnapshotCapacity(FBusCount);
    Result := B;
  finally
    FLock.Release;
  end;
end;

function TAudioBusMixer.GetBus(AId: TAudioBusId): IAudioBus;
var I: Integer;
begin
  Result := nil;
  FLock.Acquire;
  try
    for I := 0 to FBusCount - 1 do
      if FBuses[I].GetId = AId then Exit(FBuses[I]);
  finally
    FLock.Release;
  end;
end;

function TAudioBusMixer.BusCount: Integer;
begin
  FLock.Acquire;
  try Result := FBusCount;
  finally FLock.Release; end;
end;

function TAudioBusMixer.MixRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var I, LCount, LNeeded: Integer; LFmt: TAudioFormat; LBus: IAudioBus;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  // two-phase snapshot: count+format under lock, then scratch+snapshot outside
  FLock.Acquire; try LCount := FBusCount; if LCount > 0 then LFmt := FBuses[0].GetFormat; finally FLock.Release; end;
  if LCount = 0 then Exit(0);
  if not LFmt.IsValid then Exit(0);
  if AudioBytesForFrames(LFmt, AFrames)>High(Integer) then Exit(0);
  LNeeded := Integer(AudioBytesForFrames(LFmt, AFrames));
  if Length(ABuffer.Data) < LNeeded then Exit(0);
  AudioSilentFill(ABuffer, LFmt, AFrames);
  // INV-6: realtime no alloc — scratch/snapshot preallocated at CreateBus (geometric), violation counted
  if Length(FScratch.Data) < LNeeded then
  begin
    InterlockedExchangeAdd64(FViolations, 1);
    Exit(AFrames);
  end;
  // snapshot buses lock-free mixing — guard nil + local ref (B-prefix异形, zero-alloc steady, avoid double fetch)
  if Length(FSnapshotBuses) < LCount then
  begin
    InterlockedExchangeAdd64(FViolations, 1);
    EnsureSnapshotCapacity(LCount);
    if Length(FSnapshotBuses) < LCount then Exit(AFrames);
  end;
  FLock.Acquire; try for I:=0 to LCount-1 do if I < FBusCount then FSnapshotBuses[I] := FBuses[I]; finally FLock.Release; end;
  for I := 0 to LCount - 1 do
  begin
    if (I < 0) or (I >= Length(FSnapshotBuses)) then Continue;
    LBus := FSnapshotBuses[I];
    if not Assigned(LBus) then Continue;
    if not LBus.GetFormat.IsValid then Continue;
    // per-bus byte check (heterogeneous Channels/BlockAlign) — violation counted, no alloc
    if AudioBytesForFrames(LBus.GetFormat, AFrames) > High(Integer) then Continue;
    if Length(FScratch.Data) < Integer(AudioBytesForFrames(LBus.GetFormat, AFrames)) then
    begin
      InterlockedExchangeAdd64(FViolations, 1);
      Continue;
    end;
    AudioSilentFill(FScratch, LBus.GetFormat, AFrames);
    try
      (LBus as IRealtimeAudioSource).FillRealtime(FScratch, AFrames);
    except
      Continue;
    end;
    if (Length(FScratch.Data)=0) or (Length(ABuffer.Data)=0) then Continue;
    SimdAddF32(PSingle(@FScratch.Data[0]), PSingle(@ABuffer.Data[0]), AFrames * LBus.GetFormat.Channels, 1.0);
  end;
  Result := AFrames;
end;

function CreateAudioBusMixer: IAudioBusMixer;
begin
  Result := TAudioBusMixer.Create;
end;

end.
