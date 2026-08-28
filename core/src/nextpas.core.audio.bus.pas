unit nextpas.core.audio.bus;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  TAudioBusId = Integer;

  IAudioBus = interface
    ['{B1A2B3C4-D5E6-7890-ABCD-C00000000001}']
    function GetId: TAudioBusId;
    function GetGain: Single;
    procedure SetGain(AGain: Single);
    function GetFormat: TAudioFormat;
    function GetSource: IRealtimeAudioSource;
    property Id: TAudioBusId read GetId;
    property Gain: Single read GetGain write SetGain;
    property Format: TAudioFormat read GetFormat;
  end;

  IAudioBusMixer = interface
    ['{B1A2B3C4-D5E6-7890-ABCD-C00000000002}']
    function CreateBus(const AFormat: TAudioFormat): IAudioBus;
    function GetBus(AId: TAudioBusId): IAudioBus;
    function BusCount: Integer;
    function MixRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  end;

function CreateAudioBusMixer: IAudioBusMixer;

implementation

uses
  nextpas.core.audio.errors,
  nextpas.core.audio.simd;

type
  TAudioBus = class(TInterfacedObject, IAudioBus, IRealtimeAudioSource)
  private
    FId: TAudioBusId;
    FGain: Single;
    FFormat: TAudioFormat;
    FSource: IRealtimeAudioSource;
    FScratch: TAudioBuffer;
    FLock: TRTLCriticalSection;
    function GetId: TAudioBusId;
    function GetGain: Single;
    procedure SetGain(AGain: Single);
    function GetFormat: TAudioFormat;
    function GetSource: IRealtimeAudioSource;
    function GetFormatI: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  public
    constructor Create(AId: TAudioBusId; const AFormat: TAudioFormat);
    destructor Destroy; override;
    procedure AttachSource(const ASource: IRealtimeAudioSource);
  end;

  TAudioBusMixer = class(TInterfacedObject, IAudioBusMixer)
  private
    FBuses: array of IAudioBus;
    FNextId: TAudioBusId;
    FScratch: TAudioBuffer;
    FLock: TRTLCriticalSection;
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
  // pre-allocate realtime scratch to cover large frames without alloc in FillRealtime (8192 stereo f32)
  Cap := 8192 * AFormat.BlockAlign;
  SetLength(FScratch.Data, Cap);
  FScratch.Format := AFormat;
  InitCriticalSection(FLock);
end;

destructor TAudioBus.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

function TAudioBus.GetId: TAudioBusId; begin Result := FId; end;
function TAudioBus.GetGain: Single; begin EnterCriticalSection(FLock); try Result := FGain; finally LeaveCriticalSection(FLock); end; end;
procedure TAudioBus.SetGain(AGain: Single); begin EnterCriticalSection(FLock); try FGain := AGain; finally LeaveCriticalSection(FLock); end; end;
function TAudioBus.GetFormat: TAudioFormat; begin Result := FFormat; end;
function TAudioBus.GetFormatI: TAudioFormat; begin Result := FFormat; end;
function TAudioBus.GetSource: IRealtimeAudioSource; begin EnterCriticalSection(FLock); try Result := FSource; finally LeaveCriticalSection(FLock); end; end;
procedure TAudioBus.AttachSource(const ASource: IRealtimeAudioSource);
begin
  EnterCriticalSection(FLock);
  try FSource := ASource; finally LeaveCriticalSection(FLock); end;
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
  LNeeded := AFrames * FFormat.BlockAlign;
  if Length(ABuffer.Data) < LNeeded then Exit(0);
  FillChar(ABuffer.Data[0], LNeeded, 0);
  ABuffer.Format := FFormat;
  ABuffer.FrameCount := AFrames;
  // realtime: snapshot without lock (control plane uses lock)
  LSrc := FSource;
  LGain := FGain;
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
  FNextId := 1;
  SetLength(FScratch.Data, 1024 * 1024);
  InitCriticalSection(FLock);
end;

destructor TAudioBusMixer.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

function TAudioBusMixer.CreateBus(const AFormat: TAudioFormat): IAudioBus;
var L: Integer; B: TAudioBus;
begin
  if not AFormat.IsValid then
    raise EAudioDeviceError.Create('bus: invalid format');
  EnterCriticalSection(FLock);
  try
    B := TAudioBus.Create(FNextId, AFormat);
    Inc(FNextId);
    L := Length(FBuses);
    SetLength(FBuses, L + 1);
    FBuses[L] := B;
    Result := B;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TAudioBusMixer.GetBus(AId: TAudioBusId): IAudioBus;
var I: Integer;
begin
  Result := nil;
  EnterCriticalSection(FLock);
  try
    for I := 0 to High(FBuses) do
      if FBuses[I].GetId = AId then Exit(FBuses[I]);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TAudioBusMixer.BusCount: Integer;
begin
  EnterCriticalSection(FLock);
  try Result := Length(FBuses);
  finally LeaveCriticalSection(FLock); end;
end;

function TAudioBusMixer.MixRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var I: Integer; LNeeded: Integer;
begin
  Result := 0;
  if AFrames <= 0 then Exit(0);
  if Length(FBuses) = 0 then Exit(0);
  LNeeded := AFrames * FBuses[0].GetFormat.BlockAlign;
  if Length(ABuffer.Data) < LNeeded then Exit(0);
  FillChar(ABuffer.Data[0], LNeeded, 0);
  ABuffer.Format := FBuses[0].GetFormat;
  ABuffer.FrameCount := AFrames;
  if Length(FScratch.Data) < LNeeded then Exit(AFrames);
  for I := 0 to High(FBuses) do
  begin
    FScratch.Format := FBuses[I].GetFormat;
    FScratch.FrameCount := AFrames;
    FillChar(FScratch.Data[0], LNeeded, 0);
    try
      (FBuses[I] as IRealtimeAudioSource).FillRealtime(FScratch, AFrames);
    except
      Continue;
    end;
    SimdAddF32(PSingle(@FScratch.Data[0]), PSingle(@ABuffer.Data[0]), AFrames * FBuses[I].GetFormat.Channels, 1.0);
  end;
  Result := AFrames;
end;

function CreateAudioBusMixer: IAudioBusMixer;
begin
  Result := TAudioBusMixer.Create;
end;

end.
