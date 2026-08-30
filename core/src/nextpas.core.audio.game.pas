unit nextpas.core.audio.game;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes, SyncObjs, Math,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.device.intf,
  nextpas.core.audio.graph.intf,
  nextpas.core.audio.game.intf,
  nextpas.core.audio.graph,
  nextpas.core.audio.device.null,
  nextpas.core.audio.mix,
  nextpas.core.audio.pcm,
  nextpas.core.audio.errors;

type
  TGameVoiceSource = class(TInterfacedObject, IRealtimeAudioSource, IAudioSource)
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
  public
    constructor Create(const ABuffer: TAudioBuffer; const AParams: TGamePlayParams);
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    property Eof: Boolean read FEof;
  end;

  TGameAudio = class(TInterfacedObject, IGameAudio)
  private
    FGraph: IAudioGraph;
    FDevice: IAudioDevice;
    FFormat: TAudioFormat;
    FLock: TCriticalSection;
    FMasterGain: Single;
    FMaxVoices: Integer;
    FSfx: array of record Id: Integer; Buffer: TAudioBuffer; Alive: Boolean; end;
    FVoices: array of record VoiceId: Integer; SfxId: Integer; NodeId: Integer; Source: TGameVoiceSource; Priority: Integer; Alive: Boolean; end;
    FNextSfx: Integer;
    FNextVoice: Integer;
    FGameSfxDead: Integer;
    FGameVoiceDead: Integer;
    function FindSfx(AId: Integer): Integer;
    function FindVoice(AVoice: Integer): Integer;
    procedure ReapFinished;
    procedure MaybeCompactGame;
  public
    constructor Create(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer = 32);
    destructor Destroy; override;
    function GetGraph: IAudioGraph;
    function GetDevice: IAudioDevice;
    function GetMasterGain: Single;
    procedure SetMasterGain(AGain: Single);
    function Load(const ABuffer: TAudioBuffer): TGameSfxId;
    function LoadFromFile(const APath: string): TGameSfxId;
    procedure Unload(AId: TGameSfxId);
    function Play(AId: TGameSfxId): TGameVoiceId; overload;
    function Play(AId: TGameSfxId; const AParams: TGamePlayParams): TGameVoiceId; overload;
    function Play(AId: TGameSfxId; AGain: Single; APan: Single; APitch: Single; ALoop: Boolean): TGameVoiceId; overload;
    function StopVoice(AVoice: TGameVoiceId): Boolean;
    procedure StopAll;
    function VoiceCount: Integer;
    function SfxCount: Integer;
  end;

function CreateGameAudio(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer = 32): IGameAudio;
function CreateGameAudioForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat; AMaxVoices: Integer = 32): IGameAudio;

implementation

uses nextpas.core.audio.codec.registry;

constructor TGameVoiceSource.Create(const ABuffer: TAudioBuffer; const AParams: TGamePlayParams);
begin
  inherited Create;
  if ABuffer.Format.SampleFormat <> sfF32 then
    raise EAudioGraphError.Create('Voice: buffer must be sfF32');
  FFormat := ABuffer.Format;
  FData := Copy(ABuffer.Data, 0, Length(ABuffer.Data));
  FFrames := ABuffer.FrameCount;
  FPos := 0;
  FGain := AParams.Gain;
  if FGain < 0 then FGain := 0 else if FGain > 4 then FGain := 4;
  FPan := AParams.Pan;
  if FPan < -1 then FPan := -1 else if FPan > 1 then FPan := 1;
  FPitch := AParams.Pitch;
  if FPitch < 0.25 then FPitch := 0.25 else if FPitch > 4 then FPitch := 4;
  FLoop := AParams.Loop;
  FEof := False;
  FChannels := FFormat.Channels;
end;

function TGameVoiceSource.GetFormat: TAudioFormat; begin Result := FFormat; end;
function TGameVoiceSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer; begin Result := FillRealtime(ABuffer, AFrames); end;
function TGameVoiceSource.SeekTo(AFrame: UInt64): Boolean; begin FPos := AFrame; FEof := False; Result := True; end;

function TGameVoiceSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  OutPtr: PSingle;
  I, Ch, Idx0, Idx1: Integer;
  Frac, V0, V1, V: Single;
  SrcPtr: PSingle;
  Lgain, Rgain: Single;
  Needed: Integer;
begin
  Needed := AFrames * FFormat.BlockAlign;
  if Length(ABuffer.Data) < Needed then
  begin
    AFrames := Length(ABuffer.Data) div FFormat.BlockAlign;
    if AFrames <= 0 then Exit(0);
    Needed := AFrames * FFormat.BlockAlign;
  end;
  if FEof and not FLoop then
  begin
    FillChar(ABuffer.Data[0], Needed, 0);
    ABuffer.FrameCount := AFrames;
    Exit(0);
  end;
  OutPtr := PSingle(@ABuffer.Data[0]);
  SrcPtr := PSingle(@FData[0]);
  if FChannels = 2 then
  begin
    Lgain := Cos((FPan+1)*Pi/4);
    Rgain := Sin((FPan+1)*Pi/4);
  end else begin Lgain:=1; Rgain:=1; end;
  for I := 0 to AFrames - 1 do
  begin
    if FPos >= FFrames then
    begin
      if FLoop then FPos := FPos - FFrames
      else begin FEof := True; Break; end;
    end;
    Idx0 := Trunc(FPos);
    Frac := FPos - Idx0;
    Idx1 := Idx0 + 1;
    if Idx1 >= FFrames then
    begin
      if FLoop then Idx1 := 0 else Idx1 := Idx0;
    end;
    for Ch := 0 to FChannels - 1 do
    begin
      V0 := SrcPtr[Idx0*FChannels + Ch];
      V1 := SrcPtr[Idx1*FChannels + Ch];
      V := V0 + (V1 - V0)*Frac;
      V := V * FGain;
      if FChannels = 2 then
      begin
        if Ch = 0 then V := V * Lgain * 1.414213562
        else V := V * Rgain * 1.414213562;
      end;
      OutPtr[I*FChannels + Ch] := V;
    end;
    FPos := FPos + FPitch;
  end;
  if FEof then
  begin
    for I := I to AFrames -1 do
      for Ch := 0 to FChannels-1 do
        OutPtr[I*FChannels+Ch] := 0;
    ABuffer.FrameCount := AFrames;
    Result := 0;
    Exit;
  end;
  ABuffer.FrameCount := AFrames;
  ABuffer.Format := FFormat;
  Result := AFrames;
end;

constructor TGameAudio.Create(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer);
begin
  inherited Create;
  if not Assigned(ADevice) then raise EAudioDeviceError.Create('Game: nil device');
  if not Assigned(AGraph) then raise EAudioGraphError.Create('Game: nil graph');
  if AMaxVoices < 1 then AMaxVoices := 1;
  if AMaxVoices > 128 then AMaxVoices := 128;
  FDevice := ADevice;
  FGraph := AGraph;
  FFormat := AGraph.GetFormat;
  if (FDevice.Format.SampleRate <> FFormat.SampleRate) or (FDevice.Format.Channels <> FFormat.Channels) then
    raise EAudioGraphError.Create('Game: device/graph mismatch');
  FLock := TCriticalSection.Create;
  FMasterGain := 1.0;
  FMaxVoices := AMaxVoices;
  FNextSfx := 1;
  FNextVoice := 1;
  FGameSfxDead := 0;
  FGameVoiceDead := 0;
end;

destructor TGameAudio.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TGameAudio.GetGraph: IAudioGraph; begin Result := FGraph; end;
function TGameAudio.GetDevice: IAudioDevice; begin Result := FDevice; end;
function TGameAudio.GetMasterGain: Single; begin Result := FMasterGain; end;
procedure TGameAudio.SetMasterGain(AGain: Single);
begin
  if AGain < 0 then AGain := 0 else if AGain > 4 then AGain := 4;
  FLock.Enter; try FMasterGain := AGain; (FGraph as TAudioGraph).Volume := AGain; finally FLock.Leave; end;
end;

function TGameAudio.FindSfx(AId: Integer): Integer;
var I: Integer;
begin for I:=0 to High(FSfx) do if FSfx[I].Alive and (FSfx[I].Id=AId) then Exit(I); Result:=-1; end;
function TGameAudio.FindVoice(AVoice: Integer): Integer;
var I: Integer;
begin for I:=0 to High(FVoices) do if FVoices[I].Alive and (FVoices[I].VoiceId=AVoice) then Exit(I); Result:=-1; end;

procedure TGameAudio.MaybeCompactGame;
var I, J, N: Integer;
begin
  // caller holds FLock; tombstone discipline aligned with graph.timeline (64, dead>half)
  if (Length(FSfx) > 64) and (FGameSfxDead > Length(FSfx) div 2) then
  begin
    N := 0;
    for I := 0 to High(FSfx) do if FSfx[I].Alive then Inc(N);
    J := 0;
    for I := 0 to High(FSfx) do if FSfx[I].Alive then
    begin
      if I <> J then FSfx[J] := FSfx[I];
      Inc(J);
    end;
    SetLength(FSfx, N);
    FGameSfxDead := 0;
  end;
  if (Length(FVoices) > 64) and (FGameVoiceDead > Length(FVoices) div 2) then
  begin
    N := 0;
    for I := 0 to High(FVoices) do if FVoices[I].Alive then Inc(N);
    J := 0;
    for I := 0 to High(FVoices) do if FVoices[I].Alive then
    begin
      if I <> J then FVoices[J] := FVoices[I];
      Inc(J);
    end;
    SetLength(FVoices, N);
    FGameVoiceDead := 0;
  end;
end;

procedure TGameAudio.ReapFinished;
var I: Integer;
begin
  for I:=High(FVoices) downto 0 do
    if FVoices[I].Alive and Assigned(FVoices[I].Source) and FVoices[I].Source.Eof then
    begin
      try FGraph.RemoveSource(FVoices[I].NodeId); except end;
      FVoices[I].Alive := False;
      FVoices[I].Source := nil;
      Inc(FGameVoiceDead);
    end;
  MaybeCompactGame;
end;

function TGameAudio.Load(const ABuffer: TAudioBuffer): TGameSfxId;
var Idx: Integer;
begin
  if not ABuffer.Format.IsValid then raise EAudioGraphError.Create('Load: invalid buffer format');
  if ABuffer.Format.SampleFormat <> sfF32 then raise EAudioGraphError.Create('Load: buffer must be sfF32');
  if (ABuffer.Format.SampleRate <> FFormat.SampleRate) or (ABuffer.Format.Channels <> FFormat.Channels) then
    raise EAudioGraphError.Create('Load: buffer format mismatch graph');
  FLock.Enter;
  try
    Result := FNextSfx; Inc(FNextSfx);
    Idx := Length(FSfx);
    SetLength(FSfx, Idx+1);
    FSfx[Idx].Id := Result;
    FSfx[Idx].Buffer := ABuffer;
    FSfx[Idx].Buffer.Data := Copy(ABuffer.Data, 0, Length(ABuffer.Data));
    FSfx[Idx].Alive := True;
    MaybeCompactGame;
  finally FLock.Leave; end;
end;

function TGameAudio.LoadFromFile(const APath: string): TGameSfxId;
var Buf: TAudioBuffer; Tags: TAudioTags; OK: Boolean;
begin
  OK := TryDecodeWholeFile(APath, Buf, Tags);
  if not OK then raise EAudioDecodeError.CreateFmt('LoadFromFile: decode failed %s', [APath]);
  if Buf.Format.SampleFormat <> sfF32 then
  begin
    // PcmConvert returns independent TBytes; keep separate copy to avoid aliasing AV (F-22)
    Buf.Data := PcmConvert(Buf.Data, Buf.Format.SampleFormat, sfF32, Buf.FrameCount, Buf.Format.Channels, False);
    Buf.Format.SampleFormat := sfF32;
  end;
  if (Buf.Format.SampleRate <> FFormat.SampleRate) or (Buf.Format.Channels <> FFormat.Channels) then
    raise EAudioGraphError.Create('LoadFromFile: file format mismatch graph (resample todo)');
  Result := Load(Buf);
end;

procedure TGameAudio.Unload(AId: TGameSfxId);
var Idx: Integer;
begin
  FLock.Enter;
  try
    Idx := FindSfx(AId);
    if Idx<0 then Exit;
    // only mark SFX dead; do not kill already issued Voices (voice holds independent Copy data, F-22 contract)
    FSfx[Idx].Alive := False;
    SetLength(FSfx[Idx].Buffer.Data,0);
    Inc(FGameSfxDead);
    MaybeCompactGame;
  finally FLock.Leave; end;
end;

function TGameAudio.Play(AId: TGameSfxId): TGameVoiceId;
var P: TGamePlayParams;
begin P:=TGamePlayParams.Default; Result:=Play(AId, P); end;

function TGameAudio.Play(AId: TGameSfxId; const AParams: TGamePlayParams): TGameVoiceId;
var
  SIdx, VIdx, StealIdx, I, AliveN: Integer;
  Src: TGameVoiceSource;
  NodeId: Integer;
begin
  FLock.Enter;
  try
    ReapFinished;
    SIdx := FindSfx(AId);
    if SIdx<0 then raise EAudioGraphError.CreateFmt('Play: unknown sfx %d', [AId]);
    AliveN := 0;
    for I := 0 to High(FVoices) do if FVoices[I].Alive then Inc(AliveN);
    if AliveN >= FMaxVoices then
    begin
      StealIdx := -1;
      for I:=0 to High(FVoices) do if FVoices[I].Alive then
        if (StealIdx=-1) or (FVoices[I].Priority < FVoices[StealIdx].Priority) then StealIdx:=I;
      if StealIdx>=0 then
      begin
        try FGraph.RemoveSource(FVoices[StealIdx].NodeId); except end;
        FVoices[StealIdx].Alive := False;
        FVoices[StealIdx].Source := nil;
        Inc(FGameVoiceDead);
      end;
    end;
    Src := TGameVoiceSource.Create(FSfx[SIdx].Buffer, AParams);
    NodeId := FGraph.AddSource(Src as IRealtimeAudioSource, 1.0);
    Result := FNextVoice; Inc(FNextVoice);
    VIdx := Length(FVoices);
    SetLength(FVoices, VIdx+1);
    FVoices[VIdx].VoiceId := Result;
    FVoices[VIdx].SfxId := AId;
    FVoices[VIdx].NodeId := NodeId;
    FVoices[VIdx].Source := Src;
    FVoices[VIdx].Priority := AParams.Priority;
    FVoices[VIdx].Alive := True;
    MaybeCompactGame;
    try if FDevice.State <> dsStarted then FDevice.Start; except end;
  finally FLock.Leave; end;
end;

function TGameAudio.Play(AId: TGameSfxId; AGain: Single; APan: Single; APitch: Single; ALoop: Boolean): TGameVoiceId;
var P: TGamePlayParams;
begin
  P.Gain:=AGain; P.Pan:=APan; P.Pitch:=APitch; P.Loop:=ALoop; P.Priority:=0;
  Result := Play(AId, P);
end;

function TGameAudio.StopVoice(AVoice: TGameVoiceId): Boolean;
var Idx: Integer;
begin
  FLock.Enter;
  try
    Idx := FindVoice(AVoice);
    if Idx<0 then Exit(False);
    try FGraph.RemoveSource(FVoices[Idx].NodeId); except end;
    FVoices[Idx].Alive := False;
    FVoices[Idx].Source := nil;
    Inc(FGameVoiceDead);
    MaybeCompactGame;
    Result := True;
  finally FLock.Leave; end;
end;

procedure TGameAudio.StopAll;
var I: Integer;
begin
  FLock.Enter;
  try
    for I:=0 to High(FVoices) do if FVoices[I].Alive then
    begin try FGraph.RemoveSource(FVoices[I].NodeId); except end; FVoices[I].Alive:=False; FVoices[I].Source:=nil; Inc(FGameVoiceDead); end;
    MaybeCompactGame;
  finally FLock.Leave; end;
end;

function TGameAudio.VoiceCount: Integer;
var I,C: Integer;
begin
  FLock.Enter;
  try
    ReapFinished;
    C:=0; for I:=0 to High(FVoices) do if FVoices[I].Alive then Inc(C);
    Result:=C;
  finally FLock.Leave; end;
end;

function TGameAudio.SfxCount: Integer;
var I,C: Integer;
begin
  FLock.Enter;
  try C:=0; for I:=0 to High(FSfx) do if FSfx[I].Alive then Inc(C); Result:=C;
  finally FLock.Leave; end;
end;

function CreateGameAudio(const ADevice: IAudioDevice; const AGraph: IAudioGraph; AMaxVoices: Integer): IGameAudio;
begin Result := TGameAudio.Create(ADevice, AGraph, AMaxVoices); end;

function CreateGameAudioForFormat(const AProvider: IAudioDeviceProvider; const AFormat: TAudioFormat; AMaxVoices: Integer): IGameAudio;
var G: IAudioGraph; D: IAudioDevice;
begin
  G := CreateAudioGraph(AFormat);
  D := AProvider.CreateDefaultDevice(AFormat);
  D.SetSource(G as IRealtimeAudioSource);
  Result := TGameAudio.Create(D, G, AMaxVoices);
end;

end.
