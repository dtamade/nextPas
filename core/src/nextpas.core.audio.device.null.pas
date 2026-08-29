unit nextpas.core.audio.device.null;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  Classes,
  SyncObjs,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.device.intf,
  nextpas.core.audio.errors;

type
  TNullAudioDevice = class(TInterfacedObject, IAudioDevice)
  private
    FInfo: TAudioDeviceInfo;
    FFormat: TAudioFormat;
    FState: TDeviceState;
    FSource: IRealtimeAudioSource;
    FLock: TCriticalSection;
    FPosition: UInt64;
    FUnderruns: Int64;
    FViolations: Int64;
    FEvents: TDeviceEventArray;
    FConsecutiveUnderruns: Integer;
    FScratch: TBytes;
    procedure PushEvent(AKind: TDeviceEventKind; const AMsg: string);
  public
    constructor Create(const AInfo: TAudioDeviceInfo; const AFormat: TAudioFormat);
    destructor Destroy; override;
    function GetInfo: TAudioDeviceInfo;
    function GetFormat: TAudioFormat;
    function GetState: TDeviceState;
    function GetPosition: TAudioClock;
    function GetUnderrunCount: UInt64;
    function GetContractViolationCount: UInt64;
    function PollEvent(out AEvent: TDeviceEvent): Boolean;
    procedure SetSource(const ASource: IRealtimeAudioSource);
    function Start: Boolean;
    function Stop: Boolean;
    function Drive(AFrames: Integer): Integer;
  end;

  TNullAudioDeviceProvider = class(TInterfacedObject, IAudioDeviceProvider)
  private
    FDevices: TAudioDeviceInfoArray;
  public
    constructor Create;
    function Enumerate: TAudioDeviceInfoArray;
    function GetDefault: TAudioDeviceInfo;
    function CreateDevice(const AID: string; const AFormat: TAudioFormat): IAudioDevice;
    function CreateDefaultDevice(const AFormat: TAudioFormat): IAudioDevice;
  end;

function CreateNullAudioProvider: IAudioDeviceProvider;

implementation

function CreateNullAudioProvider: IAudioDeviceProvider;
begin
  Result := TNullAudioDeviceProvider.Create;
end;

constructor TNullAudioDevice.Create(const AInfo: TAudioDeviceInfo; const AFormat: TAudioFormat);
begin
  inherited Create;
  if not AFormat.IsValid then
    raise EAudioDeviceError.Create('NullDevice: invalid format');
  FInfo := AInfo;
  FFormat := AFormat;
  FState := dsOpened;
  FLock := TCriticalSection.Create;
  FPosition := 0;
  FUnderruns := 0;
  FViolations := 0;
  SetLength(FEvents, 0);
  FConsecutiveUnderruns := 0;
end;

destructor TNullAudioDevice.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TNullAudioDevice.PushEvent(AKind: TDeviceEventKind; const AMsg: string);
var L: Integer;
begin
  FLock.Enter;
  try
    L := Length(FEvents);
    SetLength(FEvents, L + 1);
    FEvents[L].Kind := AKind;
    FEvents[L].DeviceID := FInfo.ID;
    FEvents[L].Message := AMsg;
    FEvents[L].Position.Frame := FPosition;
    FEvents[L].Position.SampleRate := FFormat.SampleRate;
  finally
    FLock.Leave;
  end;
end;

function TNullAudioDevice.GetInfo: TAudioDeviceInfo;
begin Result := FInfo; end;

function TNullAudioDevice.GetFormat: TAudioFormat;
begin Result := FFormat; end;

function TNullAudioDevice.GetState: TDeviceState;
begin
  FLock.Enter;
  try Result := FState;
  finally FLock.Leave; end;
end;

function TNullAudioDevice.GetPosition: TAudioClock;
begin
  Result.Frame := FPosition;
  Result.SampleRate := FFormat.SampleRate;
end;

function TNullAudioDevice.GetUnderrunCount: UInt64;
begin Result := UInt64(FUnderruns); end;

function TNullAudioDevice.GetContractViolationCount: UInt64;
begin Result := UInt64(FViolations); end;

function TNullAudioDevice.PollEvent(out AEvent: TDeviceEvent): Boolean;
var I: Integer;
begin
  FLock.Enter;
  try
    if Length(FEvents) = 0 then Exit(False);
    AEvent := FEvents[0];
    for I := 1 to High(FEvents) do
      FEvents[I - 1] := FEvents[I];
    SetLength(FEvents, Length(FEvents) - 1);
    Result := True;
  finally
    FLock.Leave;
  end;
end;

procedure TNullAudioDevice.SetSource(const ASource: IRealtimeAudioSource);
begin
  FLock.Enter;
  try
    if FState = dsStarted then
      raise EAudioDeviceError.Create('SetSource: cannot change while started');
    FSource := ASource;
  finally
    FLock.Leave;
  end;
end;

function TNullAudioDevice.Start: Boolean;
begin
  FLock.Enter;
  try
    if FState = dsStarted then Exit(True);
    if FState = dsClosed then
      raise EAudioDeviceError.Create('Start: device closed');
    if not Assigned(FSource) then
      raise EAudioDeviceError.Create('Start: no source');
    if (FSource.Format.SampleRate <> FFormat.SampleRate) or
       (FSource.Format.Channels <> FFormat.Channels) then
      raise EAudioDeviceError.Create('Start: source format mismatch rate/ch');
    FState := dsStarted;
  finally
    FLock.Leave;
  end;
  PushEvent(devStarted, 'started');
  Result := True;
end;

function TNullAudioDevice.Stop: Boolean;
begin
  FLock.Enter;
  try
    if FState <> dsStarted then Exit(True);
    FState := dsOpened;
    Result := True;
  finally
    FLock.Leave;
  end;
  PushEvent(devStopped, 'stopped');
end;

function TNullAudioDevice.Drive(AFrames: Integer): Integer;
var
  LBuf: TAudioBuffer;
  LNeeded: Integer;
  LRet: Integer;
begin
  if AFrames <= 0 then Exit(0);
  FLock.Enter;
  try
    if FState <> dsStarted then Exit(0);
    if not Assigned(FSource) then Exit(0);
  finally
    FLock.Leave;
  end;
  if (AFrames>0) and (AudioBytesForFrames(FFormat, AFrames)>High(Integer)) then Exit(0);
  LNeeded := AFrames * FFormat.BlockAlign;
  if Length(FScratch) <> LNeeded then
    SetLength(FScratch, LNeeded);
  LBuf.Data := FScratch;
  LBuf.Format := FFormat;
  LBuf.FrameCount := AFrames;
  try
    LRet := FSource.FillRealtime(LBuf, AFrames);
  except
    InterlockedExchangeAdd64(FViolations, 1);
    FillChar(LBuf.Data[0], Length(LBuf.Data), 0);
    LRet := AFrames;
    PushEvent(devDeviceError, 'FillRealtime raised exception — muted');
    FPosition := FPosition + UInt64(AFrames);
    Exit(AFrames);
  end;
  if LRet < 0 then
  begin
    InterlockedExchangeAdd64(FViolations, 1);
    LRet := 0;
  end;
  if LRet = 0 then
  begin
    FConsecutiveUnderruns := 0;
    PushEvent(devStopped, 'eof');
    FLock.Enter;
    try FState := dsOpened; finally FLock.Leave; end;
    Result := 0;
    Exit;
  end;
  FPosition := FPosition + UInt64(AFrames);
  if LRet < AFrames then
  begin
    InterlockedExchangeAdd64(FUnderruns, 1);
    Inc(FConsecutiveUnderruns);
    if FConsecutiveUnderruns >= 5 then
    begin
      PushEvent(devUnderrun, 'consecutive underrun >=5');
      FConsecutiveUnderruns := 0;
    end;
  end
  else
    FConsecutiveUnderruns := 0;
  if LRet <> AFrames then
    InterlockedExchangeAdd64(FViolations, 1);
  Result := AFrames;
end;

constructor TNullAudioDeviceProvider.Create;
var LInfo: TAudioDeviceInfo;
begin
  inherited Create;
  SetLength(FDevices, 2);
  LInfo.ID := 'null-default';
  LInfo.Name := 'Null Default Output';
  LInfo.IsDefault := True;
  LInfo.MaxChannels := 8;
  LInfo.DefaultFormat := AudioFormatCreate(48000, 2, sfF32);
  FDevices[0] := LInfo;
  LInfo.ID := 'null-secondary';
  LInfo.Name := 'Null Secondary Output';
  LInfo.IsDefault := False;
  LInfo.MaxChannels := 2;
  LInfo.DefaultFormat := AudioFormatCreate(44100, 2, sfF32);
  FDevices[1] := LInfo;
end;

function TNullAudioDeviceProvider.Enumerate: TAudioDeviceInfoArray;
var I: Integer;
begin
  SetLength(Result, Length(FDevices));
  for I := 0 to High(FDevices) do
    Result[I] := FDevices[I];
end;

function TNullAudioDeviceProvider.GetDefault: TAudioDeviceInfo;
begin
  Result := FDevices[0];
end;

function TNullAudioDeviceProvider.CreateDevice(const AID: string; const AFormat: TAudioFormat): IAudioDevice;
var I: Integer; LInfo: TAudioDeviceInfo; Found: Boolean;
begin
  Found := False;
  for I := 0 to High(FDevices) do
    if FDevices[I].ID = AID then
    begin LInfo := FDevices[I]; Found := True; Break; end;
  if not Found then
    raise EAudioDeviceError.CreateFmt('CreateDevice: unknown id "%s"', [AID]);
  if not AFormat.IsValid then
    raise EAudioDeviceError.Create('CreateDevice: invalid format');
  Result := TNullAudioDevice.Create(LInfo, AFormat);
end;

function TNullAudioDeviceProvider.CreateDefaultDevice(const AFormat: TAudioFormat): IAudioDevice;
begin
  Result := CreateDevice(FDevices[0].ID, AFormat);
end;

end.
