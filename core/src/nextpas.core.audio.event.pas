unit nextpas.core.audio.event;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Math,
  nextpas.core.base,
  nextpas.core.sync.mutex,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.spatial.intf,
  nextpas.core.audio.spatial,
  nextpas.core.audio.event.intf,
  nextpas.core.audio.mix,
  nextpas.core.audio.pcm,
  nextpas.core.audio.errors;

type
  TEventVoice = class(TInterfacedObject, IRealtimeAudioSource, IAudioSource)
  private
    FFormat: TAudioFormat;
    FData: TBytes;
    FFrames: Integer;
    FPos: Double;
    FGain: Single;
    FPan: Single;
    FPitch: Single;
    FLoop: Boolean;
    FEof: Boolean;
    FChannels: Integer;
    FSpatial: TAudioSpatialParams;
    FListener: TAudioListener;
  public
    constructor Create(const ABuffer: TAudioBuffer; AGain, APitch: Single; APan: Single; ALoop: Boolean; const ASpatial: TAudioSpatialParams; const AListener: TAudioListener);
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    procedure SetGain(AGain: Single);
    procedure SetPan(APan: Single);
    procedure SetPitch(APitch: Single);
    procedure SetPosition(const APos: TAudioVec3);
    property Eof: Boolean read FEof;
  end;

  TAudioEventSystemImpl = class(TInterfacedObject, IAudioEventSystem, IRealtimeAudioSource, IAudioSource)
  private
    FFormat: TAudioFormat;
    FLock: TRecursiveMutex;
    FEvents: array of record Id: TAudioEventId; Desc: TAudioEventDesc; Alive: Boolean; end;
    FInstances: array of record InstanceId: TAudioEventInstanceId; EventId: TAudioEventId; Voice: TEventVoice; Params: array[0..CAudioMaxEventParams-1] of Single; Alive: Boolean; Priority: Integer; end;
    FGlobalParams: array[0..CAudioMaxEventParams-1] of Single;
    FListener: TAudioListener;
    FNextEvent: Integer;
    FNextInstance: Integer;
    FMaxVoices: Integer;
    FScratch: TBytes;
    FSnapshotVoices: array of TEventVoice;
    // capacity polish: geometric growth, call outside lock alloc region
    procedure EnsureEventCapacity(ANeeded: Integer); inline;
    procedure EnsureInstanceCapacity(ANeeded: Integer); inline;
    function FindEvent(AId: TAudioEventId): Integer;
    function FindInstance(AId: TAudioEventInstanceId): Integer;
    procedure ReapFinished;
    procedure EnsureScratch(ANeeded: Integer);
  public
    constructor Create(const AFormat: TAudioFormat; AMaxVoices: Integer = 32);
    destructor Destroy; override;
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function RegisterEvent(const ADesc: TAudioEventDesc): TAudioEventId;
    procedure Unregister(AId: TAudioEventId);
    function GetEventCount: Integer;
    function Play(AEvent: TAudioEventId): TAudioEventInstanceId; overload;
    function Play(AEvent: TAudioEventId; AGain: Single; APitch: Single; const APos: TAudioVec3): TAudioEventInstanceId; overload;
    function Play(AEvent: TAudioEventId; const AParams: TAudioSpatialParams; AGain: Single = 1.0; APitch: Single = 1.0): TAudioEventInstanceId; overload;
    function SetInstanceParam(AInstance: TAudioEventInstanceId; AParam: TAudioEventParamId; AValue: Single): Boolean;
    function GetInstanceParam(AInstance: TAudioEventInstanceId; AParam: TAudioEventParamId): Single;
    function SetInstancePosition(AInstance: TAudioEventInstanceId; const APos: TAudioVec3): Boolean;
    function GetInstancePosition(AInstance: TAudioEventInstanceId): TAudioVec3;
    function StopInstance(AInstance: TAudioEventInstanceId): Boolean;
    procedure StopAll;
    function IsPlaying(AInstance: TAudioEventInstanceId): Boolean;
    function GetInstanceCount: Integer;
    function SetGlobalParam(AParam: TAudioEventParamId; AValue: Single): Boolean;
    function GetGlobalParam(AParam: TAudioEventParamId): Single;
    procedure SetListener(const AListener: TAudioListener);
    function GetListener: TAudioListener;
  end;

function CreateAudioEventSystem(const AFormat: TAudioFormat; AMaxVoices: Integer = 32): IAudioEventSystem;

implementation

constructor TEventVoice.Create(const ABuffer: TAudioBuffer; AGain, APitch: Single; APan: Single; ALoop: Boolean; const ASpatial: TAudioSpatialParams; const AListener: TAudioListener);
begin
  inherited Create;
  if ABuffer.Format.SampleFormat <> sfF32 then raise EAudioGraphError.Create('EventVoice: buffer must be sfF32');
  FFormat := ABuffer.Format;
  FData := Copy(ABuffer.Data, 0, Length(ABuffer.Data));
  FFrames := ABuffer.FrameCount;
  FPos := 0;
  FGain := AGain; if FGain < 0 then FGain := 0 else if FGain > 4 then FGain := 4;
  FPan := APan; if FPan < -1 then FPan := -1 else if FPan > 1 then FPan := 1;
  FPitch := APitch; if FPitch < 0.25 then FPitch := 0.25 else if FPitch > 4 then FPitch := 4;
  FLoop := ALoop;
  FEof := False;
  FChannels := FFormat.Channels;
  FSpatial := ASpatial;
  FListener := AListener;
end;

function TEventVoice.GetFormat: TAudioFormat; begin Result := FFormat; end;
function TEventVoice.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer; begin Result := FillRealtime(ABuffer, AFrames); end;
function TEventVoice.SeekTo(AFrame: UInt64): Boolean; begin FPos := AFrame; FEof := False; Result := True; end;
procedure TEventVoice.SetGain(AGain: Single); begin if AGain < 0 then AGain := 0 else if AGain > 4 then AGain := 4; FGain := AGain; end;
procedure TEventVoice.SetPan(APan: Single); begin if APan < -1 then APan := -1 else if APan > 1 then APan := 1; FPan := APan; end;
procedure TEventVoice.SetPitch(APitch: Single); begin if APitch < 0.25 then APitch := 0.25 else if APitch > 4 then APitch := 4; FPitch := APitch; end;
procedure TEventVoice.SetPosition(const APos: TAudioVec3); begin FSpatial.Position := APos; end;

function TEventVoice.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var OutPtr, SrcPtr: PSingle; I, Ch, Idx0, Idx1: Integer; Frac, V0, V1, V: Single; LG: TAudioPanGains; LGain, LPan: Single; LAtt: Single; Needed: Integer;
begin
  Needed := Integer(Int64(AFrames) * Int64(FFormat.BlockAlign));
  if Needed < 0 then
    Needed := 0;
  if Length(ABuffer.Data) < Needed then
  begin
    AFrames := Length(ABuffer.Data) div FFormat.BlockAlign;
    if AFrames <= 0 then Exit(0);
    Needed := Integer(Int64(AFrames) * Int64(FFormat.BlockAlign));
    if Needed < 0 then
      Needed := 0;
  end;
  if FEof and not FLoop then begin FillChar(ABuffer.Data[0], Needed, 0); ABuffer.FrameCount := AFrames; Exit(0); end;
  LAtt := AudioComputeAttenuation(FListener, FSpatial);
  LPan := AudioComputePan(FListener, FSpatial.Position);
  LPan := (LPan + FPan) * 0.5;
  if LPan < -1 then LPan := -1 else if LPan > 1 then LPan := 1;
  LG := PanLawGains0dB(LPan);
  LGain := FGain * LAtt;
  OutPtr := PSingle(@ABuffer.Data[0]);
  SrcPtr := PSingle(@FData[0]);
  for I := 0 to AFrames -1 do
  begin
    if FPos >= FFrames then
    begin
      if FLoop then FPos := FPos - FFrames else begin FEof := True; Break; end;
    end;
    Idx0 := Trunc(FPos); Frac := FPos - Idx0; Idx1 := Idx0 +1;
    if Idx1 >= FFrames then if FLoop then Idx1:=0 else Idx1:=Idx0;
    for Ch := 0 to FChannels-1 do
    begin
      V0 := SrcPtr[Idx0*FChannels+Ch]; V1 := SrcPtr[Idx1*FChannels+Ch]; V := V0 + (V1-V0)*Frac;
      V := V * LGain;
      if FChannels = 2 then
      begin
        if Ch=0 then V := V * LG.X else V := V * LG.Y;
      end;
      OutPtr[I*FChannels+Ch] := V;
    end;
    FPos := FPos + FPitch;
  end;
  if FEof then
  begin
    for I := I to AFrames-1 do for Ch:=0 to FChannels-1 do OutPtr[I*FChannels+Ch]:=0;
    ABuffer.FrameCount := AFrames; Result:=0; Exit;
  end;
  ABuffer.FrameCount := AFrames; ABuffer.Format := FFormat; Result := AFrames;
  for I:=0 to Result*FChannels-1 do begin if OutPtr[I]>1.0 then OutPtr[I]:=1.0 else if OutPtr[I]<-1.0 then OutPtr[I]:=-1.0; end;
end;

constructor TAudioEventSystemImpl.Create(const AFormat: TAudioFormat; AMaxVoices: Integer);
var I: Integer;
begin
  inherited Create;
  if not AFormat.IsValid then raise EInvalidArgument.Create('EventSystem: invalid format');
  if AFormat.SampleFormat <> sfF32 then raise EAudioGraphError.Create('EventSystem: format must be sfF32');
  FFormat := AFormat;
  FLock := TRecursiveMutex.Create;
  FMaxVoices := AMaxVoices; if FMaxVoices <1 then FMaxVoices:=1; if FMaxVoices>128 then FMaxVoices:=128;
  FNextEvent := 1; FNextInstance := 1;
  FListener := AudioListenerDefault;
  for I:=0 to CAudioMaxEventParams-1 do FGlobalParams[I]:=0;
  SetLength(FSnapshotVoices, 0);
end;

destructor TAudioEventSystemImpl.Destroy;
var I: Integer;
begin
  for I:=0 to High(FInstances) do if Assigned(FInstances[I].Voice) then FreeAndNil(FInstances[I].Voice);
  FLock.Free; inherited;
end;

procedure TAudioEventSystemImpl.EnsureEventCapacity(ANeeded: Integer);
var Cap: Integer;
begin
  if Length(FEvents) >= ANeeded then Exit;
  Cap := Length(FEvents); if Cap<4 then Cap:=4; while Cap<ANeeded do Cap:=Cap*2; SetLength(FEvents, Cap);
end;

procedure TAudioEventSystemImpl.EnsureInstanceCapacity(ANeeded: Integer);
var Cap: Integer;
begin
  if Length(FInstances) >= ANeeded then Exit;
  Cap := Length(FInstances); if Cap<8 then Cap:=8; while Cap<ANeeded do Cap:=Cap*2; SetLength(FInstances, Cap);
end;

function TAudioEventSystemImpl.FindEvent(AId: TAudioEventId): Integer;
var I: Integer;
begin
  for I:=0 to High(FEvents) do if FEvents[I].Alive and (FEvents[I].Id=AId) then Exit(I); Result:=-1;
end;

function TAudioEventSystemImpl.FindInstance(AId: TAudioEventInstanceId): Integer;
var I: Integer;
begin
  for I:=0 to High(FInstances) do if FInstances[I].Alive and (FInstances[I].InstanceId=AId) then Exit(I); Result:=-1;
end;

procedure TAudioEventSystemImpl.ReapFinished;
var I: Integer;
begin
  for I:=High(FInstances) downto 0 do if FInstances[I].Alive and Assigned(FInstances[I].Voice) and FInstances[I].Voice.Eof then
  begin
    FreeAndNil(FInstances[I].Voice);
    FInstances[I].Alive := False;
  end;
end;

procedure TAudioEventSystemImpl.EnsureScratch(ANeeded: Integer);
var
  LCap: Integer;
begin
  if Length(FScratch) < ANeeded then
  begin
    LCap := Length(FScratch);
    if LCap < 256 then
      LCap := 256;
    while LCap < ANeeded do
      LCap := LCap * 2;
    SetLength(FScratch, LCap);
  end;
end;

function TAudioEventSystemImpl.GetFormat: TAudioFormat; begin Result := FFormat; end;
function TAudioEventSystemImpl.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer; begin Result := FillRealtime(ABuffer, AFrames); end;
function TAudioEventSystemImpl.SeekTo(AFrame: UInt64): Boolean; begin Result := False; end;

function TAudioEventSystemImpl.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  LNeed, LFrames, I, J, LCh: Integer;
  LSrc: TAudioBuffer;
  LOut: PSingle;
  LCount: Integer;
  LGlobalGain: Single;
  LListenerSnap: TAudioListener;
begin
  if AFrames <=0 then Exit(0);
  LNeed := AFrames * FFormat.BlockAlign;
  if Length(ABuffer.Data) < LNeed then
  begin
    LFrames := Length(ABuffer.Data) div FFormat.BlockAlign;
    if LFrames <=0 then Exit(0);
    AFrames := LFrames; LNeed := AFrames * FFormat.BlockAlign;
  end;
  FillChar(ABuffer.Data[0], LNeed, 0);
  ABuffer.FrameCount := AFrames; ABuffer.Format := FFormat;
  LCh := FFormat.Channels;
  EnsureScratch(LNeed);
  LSrc.Format := FFormat; LSrc.FrameCount := AFrames; LSrc.Data := FScratch;
  // two-phase snapshot: collect alive voices under lock, mixing lock-free
  FLock.Acquire;
  try
    ReapFinished;
    LCount := 0;
    for I:=0 to High(FInstances) do if FInstances[I].Alive and Assigned(FInstances[I].Voice) then Inc(LCount);
    LGlobalGain := FGlobalParams[0];
    LListenerSnap := FListener;
  finally FLock.Release; end;
  // snapshot scratch reuse: preallocated FSnapshotVoices reuse, steady zero alloc
  if Length(FSnapshotVoices) < LCount then
    SetLength(FSnapshotVoices, LCount);
  if LCount > 0 then
  begin
    FLock.Acquire;
    try
      J:=0;
      for I:=0 to High(FInstances) do if FInstances[I].Alive and Assigned(FInstances[I].Voice) then
      begin
        if J < LCount then
        begin
          FInstances[I].Voice.FListener := LListenerSnap;
          FSnapshotVoices[J] := FInstances[I].Voice;
          Inc(J);
        end;
      end;
      LCount := J;
    finally FLock.Release; end;
  end;
  // snapshot mixing - lock free
  for I:=0 to LCount-1 do
  begin
    FillChar(LSrc.Data[0], LNeed, 0);
    LSrc.FrameCount := AFrames;
    if FSnapshotVoices[I].FillRealtime(LSrc, AFrames) >0 then
    begin
      LOut := PSingle(@ABuffer.Data[0]);
      if LGlobalGain <> 0 then
      begin
        for J:=0 to AFrames*LCh-1 do
          LOut[J] := LOut[J] + PSingle(@LSrc.Data[0])[J] * (1+LGlobalGain);
      end else
      begin
        for J:=0 to AFrames*LCh-1 do
          LOut[J] := LOut[J] + PSingle(@LSrc.Data[0])[J];
      end;
    end;
  end;
  // clamp
  LOut := PSingle(@ABuffer.Data[0]);
  for J:=0 to AFrames*LCh-1 do
  begin
    if LOut[J] > 1.0 then LOut[J] := 1.0 else if LOut[J] < -1.0 then LOut[J] := -1.0;
  end;
  Result := AFrames;
end;

function TAudioEventSystemImpl.RegisterEvent(const ADesc: TAudioEventDesc): TAudioEventId;
var Idx, I: Integer;
begin
  if not ADesc.Buffer.Format.IsValid then raise EAudioGraphError.Create('RegisterEvent: invalid buffer');
  if ADesc.Buffer.Format.SampleFormat <> sfF32 then raise EAudioGraphError.Create('RegisterEvent: buffer must be sfF32');
  if (ADesc.Buffer.Format.SampleRate <> FFormat.SampleRate) or (ADesc.Buffer.Format.Channels <> FFormat.Channels) then raise EAudioGraphError.Create('RegisterEvent: buffer format mismatch');
  FLock.Acquire;
  try
    Result := FNextEvent; Inc(FNextEvent);
    Idx := -1; for I:=0 to High(FEvents) do if not FEvents[I].Alive then begin Idx:=I; Break; end;
    if Idx<0 then begin Idx:=Length(FEvents); EnsureEventCapacity(Idx+1); end;
    FEvents[Idx].Id := Result; FEvents[Idx].Desc := ADesc;
    FEvents[Idx].Desc.Buffer.Data := Copy(ADesc.Buffer.Data, 0, Length(ADesc.Buffer.Data));
    FEvents[Idx].Alive := True;
  finally FLock.Release; end;
end;

procedure TAudioEventSystemImpl.Unregister(AId: TAudioEventId);
var Idx: Integer;
begin
  FLock.Acquire; try Idx:=FindEvent(AId); if Idx>=0 then begin FEvents[Idx].Alive:=False; SetLength(FEvents[Idx].Desc.Buffer.Data,0); end; finally FLock.Release; end;
end;

function TAudioEventSystemImpl.GetEventCount: Integer;
var I,C: Integer;
begin
  FLock.Acquire; try C:=0; for I:=0 to High(FEvents) do if FEvents[I].Alive then Inc(C); Result:=C; finally FLock.Release; end;
end;

function TAudioEventSystemImpl.Play(AEvent: TAudioEventId): TAudioEventInstanceId;
var Idx: Integer; Desc: TAudioEventDesc;
begin
  FLock.Acquire; try Idx:=FindEvent(AEvent); if Idx<0 then raise EAudioGraphError.CreateFmt('Play: unknown event %d', [AEvent]); Desc:=FEvents[Idx].Desc; finally FLock.Release; end;
  Result := Play(AEvent, Desc.Spatial, Desc.BaseGain, Desc.BasePitch);
end;

function TAudioEventSystemImpl.Play(AEvent: TAudioEventId; AGain: Single; APitch: Single; const APos: TAudioVec3): TAudioEventInstanceId;
var Sp: TAudioSpatialParams;
begin
  Sp := AudioSpatialParamsDefault; Sp.Position := APos;
  Result := Play(AEvent, Sp, AGain, APitch);
end;

function TAudioEventSystemImpl.Play(AEvent: TAudioEventId; const AParams: TAudioSpatialParams; AGain: Single; APitch: Single): TAudioEventInstanceId;
var EIdx, VIdx, StealIdx, I: Integer; Voice: TEventVoice; Desc: TAudioEventDesc; AliveCount: Integer;
begin
  FLock.Acquire;
  try
    ReapFinished;
    EIdx := FindEvent(AEvent);
    if EIdx<0 then raise EAudioGraphError.CreateFmt('Play: unknown event %d', [AEvent]);
    Desc := FEvents[EIdx].Desc;
    AliveCount:=0; for I:=0 to High(FInstances) do if FInstances[I].Alive then Inc(AliveCount);
    if AliveCount >= FMaxVoices then
    begin
      StealIdx:=-1;
      for I:=0 to High(FInstances) do if FInstances[I].Alive then if (StealIdx=-1) or (FInstances[I].Priority < FInstances[StealIdx].Priority) then StealIdx:=I;
      if StealIdx>=0 then begin FreeAndNil(FInstances[StealIdx].Voice); FInstances[StealIdx].Alive:=False; end;
    end;
    Voice := TEventVoice.Create(Desc.Buffer, AGain * Desc.BaseGain, APitch * Desc.BasePitch, 0, Desc.Loop, AParams, FListener);
    Result := FNextInstance; Inc(FNextInstance);
    VIdx:=-1; for I:=0 to High(FInstances) do if not FInstances[I].Alive then begin VIdx:=I; Break; end;
    if VIdx<0 then begin VIdx:=Length(FInstances); EnsureInstanceCapacity(VIdx+1); end;
    FInstances[VIdx].InstanceId := Result;
    FInstances[VIdx].EventId := AEvent;
    FInstances[VIdx].Voice := Voice;
    for I:=0 to CAudioMaxEventParams-1 do FInstances[VIdx].Params[I]:=0;
    FInstances[VIdx].Alive := True; FInstances[VIdx].Priority:=0;
  finally FLock.Release; end;
end;

function TAudioEventSystemImpl.SetInstanceParam(AInstance: TAudioEventInstanceId; AParam: TAudioEventParamId; AValue: Single): Boolean;
var Idx: Integer;
begin
  if (AParam<0) or (AParam>=CAudioMaxEventParams) then Exit(False);
  FLock.Acquire; try Idx:=FindInstance(AInstance); if Idx<0 then Exit(False); FInstances[Idx].Params[AParam]:=AValue;
    case AParam of
      0: if Assigned(FInstances[Idx].Voice) then FInstances[Idx].Voice.SetGain(AValue);
      1: if Assigned(FInstances[Idx].Voice) then FInstances[Idx].Voice.SetPitch(AValue);
      2: if Assigned(FInstances[Idx].Voice) then FInstances[Idx].Voice.SetPan(AValue);
    end;
    Result:=True; finally FLock.Release; end;
end;

function TAudioEventSystemImpl.GetInstanceParam(AInstance: TAudioEventInstanceId; AParam: TAudioEventParamId): Single;
var Idx: Integer;
begin
  if (AParam<0) or (AParam>=CAudioMaxEventParams) then Exit(0);
  FLock.Acquire; try Idx:=FindInstance(AInstance); if Idx<0 then Exit(0); Result:=FInstances[Idx].Params[AParam]; finally FLock.Release; end;
end;

function TAudioEventSystemImpl.SetInstancePosition(AInstance: TAudioEventInstanceId; const APos: TAudioVec3): Boolean;
var Idx: Integer;
begin
  FLock.Acquire; try Idx:=FindInstance(AInstance); if Idx<0 then Exit(False); if Assigned(FInstances[Idx].Voice) then FInstances[Idx].Voice.SetPosition(APos); Result:=True; finally FLock.Release; end;
end;

function TAudioEventSystemImpl.GetInstancePosition(AInstance: TAudioEventInstanceId): TAudioVec3;
var Idx: Integer;
begin
  FLock.Acquire; try Idx:=FindInstance(AInstance); if Idx<0 then Exit(AudioVec3Zero); Result:=FInstances[Idx].Voice.FSpatial.Position; finally FLock.Release; end;
end;

function TAudioEventSystemImpl.StopInstance(AInstance: TAudioEventInstanceId): Boolean;
var Idx: Integer;
begin
  FLock.Acquire; try Idx:=FindInstance(AInstance); if Idx<0 then Exit(False); FreeAndNil(FInstances[Idx].Voice); FInstances[Idx].Alive:=False; Result:=True; finally FLock.Release; end;
end;

procedure TAudioEventSystemImpl.StopAll;
var I: Integer;
begin
  FLock.Acquire; try for I:=0 to High(FInstances) do if FInstances[I].Alive then begin FreeAndNil(FInstances[I].Voice); FInstances[I].Alive:=False; end; finally FLock.Release; end;
end;

function TAudioEventSystemImpl.IsPlaying(AInstance: TAudioEventInstanceId): Boolean;
var Idx: Integer;
begin
  FLock.Acquire; try Idx:=FindInstance(AInstance); Result:=(Idx>=0) and FInstances[Idx].Alive and Assigned(FInstances[Idx].Voice) and not FInstances[Idx].Voice.Eof; finally FLock.Release; end;
end;

function TAudioEventSystemImpl.GetInstanceCount: Integer;
var I,C: Integer;
begin
  FLock.Acquire; try ReapFinished; C:=0; for I:=0 to High(FInstances) do if FInstances[I].Alive then Inc(C); Result:=C; finally FLock.Release; end;
end;

function TAudioEventSystemImpl.SetGlobalParam(AParam: TAudioEventParamId; AValue: Single): Boolean;
begin
  if (AParam<0) or (AParam>=CAudioMaxEventParams) then Exit(False);
  FLock.Acquire; try FGlobalParams[AParam]:=AValue; Result:=True; finally FLock.Release; end;
end;

function TAudioEventSystemImpl.GetGlobalParam(AParam: TAudioEventParamId): Single;
begin
  if (AParam<0) or (AParam>=CAudioMaxEventParams) then Exit(0);
  FLock.Acquire; try Result:=FGlobalParams[AParam]; finally FLock.Release; end;
end;

procedure TAudioEventSystemImpl.SetListener(const AListener: TAudioListener);
begin
  FLock.Acquire; try FListener:=AListener; finally FLock.Release; end;
end;

function TAudioEventSystemImpl.GetListener: TAudioListener;
begin
  FLock.Acquire; try Result:=FListener; finally FLock.Release; end;
end;

function CreateAudioEventSystem(const AFormat: TAudioFormat; AMaxVoices: Integer): IAudioEventSystem;
begin
  Result := TAudioEventSystemImpl.Create(AFormat, AMaxVoices);
end;

end.
