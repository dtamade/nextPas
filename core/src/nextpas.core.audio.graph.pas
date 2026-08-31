unit nextpas.core.audio.graph;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  Classes,
  SyncObjs,
  Math,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.graph.intf,
  nextpas.core.audio.errors;

type
  TGraphNode = record
    Id: Integer;
    Source: IRealtimeAudioSource;
    Gain: Single;
    Alive: Boolean;
  end;

  TProcessorSlot = record
    Id: Integer;
    Processor: IAudioProcessor;
    Alive: Boolean;
  end;

  TAudioGraph = class(TInterfacedObject, IAudioGraph, IAudioSource, IRealtimeAudioSource)
  private
    FFormat: TAudioFormat;
    FState: TGraphState;
    FLock: TCriticalSection;
    FNodes: array of TGraphNode;
    FProcessors: array of TProcessorSlot;
    FNextId: Integer;
    FPosition: UInt64;
    FVolume: Single;
    FUnderruns: Int64;
    FViolations: Int64;
    FScratchNodes: array of TGraphNode;
    FScratchProcs: array of TProcessorSlot;
    FScratchTmp: TAudioBuffer;
    FScratchOut: TAudioBuffer;
    function FindNode(AId: Integer): Integer;
    function FindProcessor(AId: Integer): Integer;
  public
    constructor Create(const AFormat: TAudioFormat);
    destructor Destroy; override;
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function GetState: TGraphState;
    function NodeCount: Integer;
    function AddSource(const ASource: IRealtimeAudioSource; AGain: Single): Integer;
    function RemoveSource(AId: Integer): Boolean;
    function SetGain(AId: Integer; AGain: Single): Boolean;
    function AddProcessor(const AProcessor: IAudioProcessor): Integer;
    function RemoveProcessor(AId: Integer): Boolean;
    procedure Clear;
    property Volume: Single read FVolume write FVolume;
  end;

function CreateAudioGraph(const AFormat: TAudioFormat): IAudioGraph;

implementation

function CreateAudioGraph(const AFormat: TAudioFormat): IAudioGraph;
begin
  Result := TAudioGraph.Create(AFormat);
end;

constructor TAudioGraph.Create(const AFormat: TAudioFormat);
begin
  inherited Create;
  if not AFormat.IsValid then
    raise EAudioGraphError.Create('Graph: invalid format');
  if AFormat.SampleFormat <> sfF32 then
    raise EAudioGraphError.Create('Graph: format must be sfF32 (canonical mix format)');
  FFormat := AFormat;
  FState := gsStopped;
  FLock := TCriticalSection.Create;
  SetLength(FNodes, 0);
  SetLength(FProcessors, 0);
  FNextId := 1;
  FPosition := 0;
  FVolume := 1.0;
  FUnderruns := 0;
  FViolations := 0;
end;

destructor TAudioGraph.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TAudioGraph.GetFormat: TAudioFormat;
begin Result := FFormat; end;

function TAudioGraph.GetState: TGraphState;
begin
  FLock.Enter;
  try Result := FState;
  finally FLock.Leave; end;
end;

function TAudioGraph.NodeCount: Integer;
var I, C: Integer;
begin
  FLock.Enter;
  try
    C := 0;
    for I := 0 to High(FNodes) do if FNodes[I].Alive then Inc(C);
    Result := C;
  finally FLock.Leave; end;
end;

function TAudioGraph.FindNode(AId: Integer): Integer;
var I: Integer;
begin
  for I := 0 to High(FNodes) do if (FNodes[I].Id = AId) and FNodes[I].Alive then Exit(I);
  Result := -1;
end;

function TAudioGraph.FindProcessor(AId: Integer): Integer;
var I: Integer;
begin
  for I := 0 to High(FProcessors) do if (FProcessors[I].Id = AId) and FProcessors[I].Alive then Exit(I);
  Result := -1;
end;

function TAudioGraph.AddSource(const ASource: IRealtimeAudioSource; AGain: Single): Integer;
var Idx: Integer;
begin
  if not Assigned(ASource) then
    raise EAudioGraphError.Create('AddSource: nil');
  if (ASource.Format.SampleRate <> FFormat.SampleRate) or (ASource.Format.Channels <> FFormat.Channels) then
    raise EAudioGraphError.Create('AddSource: format mismatch');
  if IsNan(AGain) or IsInfinite(AGain) then AGain := 1.0;
  FLock.Enter;
  try
    Result := FNextId; Inc(FNextId);
    Idx := Length(FNodes);
    SetLength(FNodes, Idx + 1);
    FNodes[Idx].Id := Result;
    FNodes[Idx].Source := ASource;
    FNodes[Idx].Gain := AGain;
    FNodes[Idx].Alive := True;
    if FState = gsStopped then FState := gsPlaying;
  finally FLock.Leave; end;
end;

function TAudioGraph.RemoveSource(AId: Integer): Boolean;
var Idx: Integer;
begin
  FLock.Enter;
  try
    Idx := FindNode(AId);
    if Idx < 0 then Exit(False);
    FNodes[Idx].Alive := False;
    FNodes[Idx].Source := nil;
    Result := True;
  finally FLock.Leave; end;
end;

function TAudioGraph.SetGain(AId: Integer; AGain: Single): Boolean;
var Idx: Integer;
begin
  if IsNan(AGain) or IsInfinite(AGain) then Exit(False);
  FLock.Enter;
  try
    Idx := FindNode(AId);
    if Idx < 0 then Exit(False);
    FNodes[Idx].Gain := AGain;
    Result := True;
  finally FLock.Leave; end;
end;

function TAudioGraph.AddProcessor(const AProcessor: IAudioProcessor): Integer;
var Idx: Integer;
begin
  if not Assigned(AProcessor) then
    raise EAudioGraphError.Create('AddProcessor: nil');
  FLock.Enter;
  try
    Result := FNextId; Inc(FNextId);
    Idx := Length(FProcessors);
    SetLength(FProcessors, Idx + 1);
    FProcessors[Idx].Id := Result;
    FProcessors[Idx].Processor := AProcessor;
    FProcessors[Idx].Alive := True;
  finally FLock.Leave; end;
end;

function TAudioGraph.RemoveProcessor(AId: Integer): Boolean;
var Idx: Integer;
begin
  FLock.Enter;
  try
    Idx := FindProcessor(AId);
    if Idx < 0 then Exit(False);
    FProcessors[Idx].Alive := False;
    FProcessors[Idx].Processor := nil;
    Result := True;
  finally FLock.Leave; end;
end;

procedure TAudioGraph.Clear;
var I: Integer;
begin
  FLock.Enter;
  try
    for I := 0 to High(FNodes) do
    begin FNodes[I].Alive := False; FNodes[I].Source := nil; end;
    for I := 0 to High(FProcessors) do
    begin FProcessors[I].Alive := False; FProcessors[I].Processor := nil; end;
    SetLength(FNodes, 0);
    SetLength(FProcessors, 0);
    FState := gsStopped;
    FPosition := 0;
  finally FLock.Leave; end;
end;

function TAudioGraph.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := FillRealtime(ABuffer, AFrames);
end;

function TAudioGraph.SeekTo(AFrame: UInt64): Boolean;
var I: Integer; OK: Boolean;
begin
  FLock.Enter;
  try
    OK := True;
    for I := 0 to High(FNodes) do
      if FNodes[I].Alive then
        if not FNodes[I].Source.SeekTo(AFrame) then OK := False;
    if OK then FPosition := AFrame;
    Result := OK;
  finally FLock.Leave; end;
end;

function TAudioGraph.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  Needed, I, J, NCount, PCount: Integer;
  MixPtr, TmpPtr: PSingle;
  Gain: Single;
  HasData: Boolean;
  SwapBuf: TAudioBuffer;
begin
  if AFrames <= 0 then Exit(0);
  Needed := AFrames * FFormat.BlockAlign;
  if Length(ABuffer.Data) < Needed then
  begin
    InterlockedExchangeAdd64(FViolations, 1);
    AFrames := Length(ABuffer.Data) div FFormat.BlockAlign;
    if AFrames <= 0 then Exit(0);
    Needed := AFrames * FFormat.BlockAlign;
  end;
  FLock.Enter;
  try
    if Length(FScratchNodes) < Length(FNodes) then SetLength(FScratchNodes, Length(FNodes));
    NCount := 0;
    for I := 0 to High(FNodes) do if FNodes[I].Alive then
    begin FScratchNodes[NCount] := FNodes[I]; Inc(NCount); end;
    if Length(FScratchProcs) < Length(FProcessors) then SetLength(FScratchProcs, Length(FProcessors));
    PCount := 0;
    for I := 0 to High(FProcessors) do if FProcessors[I].Alive then
    begin FScratchProcs[PCount] := FProcessors[I]; Inc(PCount); end;
  finally FLock.Leave; end;

  if NCount = 0 then
  begin
    FillChar(ABuffer.Data[0], Needed, 0);
    ABuffer.FrameCount := AFrames;
    FPosition := FPosition + UInt64(AFrames);
    Exit(AFrames);
  end;

  FillChar(ABuffer.Data[0], Needed, 0);
  MixPtr := PSingle(@ABuffer.Data[0]);
  HasData := False;
  if Length(FScratchTmp.Data) < Needed then SetLength(FScratchTmp.Data, Needed);
  FScratchTmp.Format := FFormat;
  FScratchTmp.FrameCount := AFrames;
  for I := 0 to NCount-1 do
  begin
    Gain := FScratchNodes[I].Gain * FVolume;
    try
      J := FScratchNodes[I].Source.FillRealtime(FScratchTmp, AFrames);
    except
      InterlockedExchangeAdd64(FViolations, 1);
      Continue;
    end;
    if J = 0 then Continue;
    if J <> AFrames then
      InterlockedExchangeAdd64(FUnderruns, 1);
    HasData := True;
    TmpPtr := PSingle(@FScratchTmp.Data[0]);
    if Gain = 1.0 then
      for J := 0 to AFrames * FFormat.Channels - 1 do
        MixPtr[J] := MixPtr[J] + TmpPtr[J]
    else
      for J := 0 to AFrames * FFormat.Channels - 1 do
        MixPtr[J] := MixPtr[J] + TmpPtr[J] * Gain;
  end;

  if not HasData then
  begin
    FillChar(ABuffer.Data[0], Needed, 0);
    Result := 0;
    Exit;
  end;

  for I := 0 to AFrames * FFormat.Channels - 1 do
  begin
    if MixPtr[I] > 1.0 then MixPtr[I] := 1.0
    else if MixPtr[I] < -1.0 then MixPtr[I] := -1.0;
  end;

  if PCount > 0 then
  begin
    if Length(FScratchOut.Data) < Needed then SetLength(FScratchOut.Data, Needed);
    FScratchOut.Format := FFormat;
    FScratchOut.FrameCount := AFrames;
    Move(ABuffer.Data[0], FScratchOut.Data[0], Needed);
    for I := 0 to PCount-1 do
    begin
      try
        FScratchProcs[I].Processor.Process(FScratchOut, FScratchTmp);
        SwapBuf := FScratchOut;
        FScratchOut := FScratchTmp;
        FScratchTmp := SwapBuf;
      except
        InterlockedExchangeAdd64(FViolations, 1);
      end;
    end;
    if Length(FScratchOut.Data) >= Needed then
      Move(FScratchOut.Data[0], ABuffer.Data[0], Needed)
    else if Length(FScratchOut.Data) > 0 then
    begin
      FillChar(ABuffer.Data[0], Needed, 0);
      Move(FScratchOut.Data[0], ABuffer.Data[0], Min(Needed, Length(FScratchOut.Data)));
    end;
  end;

  ABuffer.FrameCount := AFrames;
  ABuffer.Format := FFormat;
  FPosition := FPosition + UInt64(AFrames);
  Result := AFrames;
end;

end.
