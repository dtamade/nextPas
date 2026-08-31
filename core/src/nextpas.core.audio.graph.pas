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
  nextpas.core.audio.simd,
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
    FScratch: TAudioBuffer;
    FOut: TAudioBuffer;
    FNodeSnap: array of TGraphNode; // realtime scratch: steady-state zero-alloc
    FProcSnap: array of TProcessorSlot;
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
  SetLength(FScratch.Data, 1024 * 1024);
  FScratch.Format := AFormat;
  SetLength(FOut.Data, 1024 * 1024);
  FOut.Format := AFormat;
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
  Needed, I, J, LSnapNodes, LSnapProcs: Integer;
  MixPtr, TmpPtr: PSingle;
  Gain: Single;
  HasData, HasProcessor: Boolean;
begin
  if AFrames <= 0 then Exit(0);
  if (AFrames>0) and (AudioBytesForFrames(FFormat, AFrames)>High(Integer)) then Exit(0);
  Needed := AFrames * FFormat.BlockAlign;
  if Length(ABuffer.Data) < Needed then
  begin
    InterlockedExchangeAdd64(FViolations, 1);
    AFrames := Length(ABuffer.Data) div FFormat.BlockAlign;
    if AFrames <= 0 then Exit(0);
    Needed := AFrames * FFormat.BlockAlign;
  end;
  if Length(FScratch.Data) < Needed then
  begin
    SetLength(FScratch.Data, Needed);
    FScratch.Format := FFormat;
    if Length(FScratch.Data) < Needed then begin InterlockedExchangeAdd64(FViolations, 1); Exit(0); end;
  end;
  if Length(FOut.Data) < Needed then
  begin
    SetLength(FOut.Data, Needed);
    FOut.Format := FFormat;
    if Length(FOut.Data) < Needed then begin InterlockedExchangeAdd64(FViolations, 1); Exit(0); end;
  end;
  // snapshot nodes/processors once (single lock, steady-state zero-alloc when counts stable)
  FLock.Enter;
  try
    LSnapNodes := Length(FNodes);
    if Length(FNodeSnap) <> LSnapNodes then
      SetLength(FNodeSnap, LSnapNodes);
    for I := 0 to LSnapNodes - 1 do
      FNodeSnap[I] := FNodes[I];
    LSnapProcs := Length(FProcessors);
    if Length(FProcSnap) <> LSnapProcs then
      SetLength(FProcSnap, LSnapProcs);
    for I := 0 to LSnapProcs - 1 do
      FProcSnap[I] := FProcessors[I];
  finally
    FLock.Leave;
  end;
  if LSnapNodes = 0 then
  begin
    AudioSilentFill(ABuffer, FFormat, AFrames);
    FPosition := FPosition + UInt64(AFrames);
    Exit(AFrames);
  end;

  AudioSilentFill(ABuffer, FFormat, AFrames);
  MixPtr := PSingle(@ABuffer.Data[0]);
  HasData := False;
  FScratch.Format := FFormat;
  FScratch.FrameCount := AFrames;
  for I := 0 to High(FNodeSnap) do
  begin
    if not FNodeSnap[I].Alive then Continue;
    if not Assigned(FNodeSnap[I].Source) then Continue;
    Gain := FNodeSnap[I].Gain * FVolume;
    try
      J := FNodeSnap[I].Source.FillRealtime(FScratch, AFrames);
    except
      InterlockedExchangeAdd64(FViolations, 1);
      Continue;
    end;
    if J = 0 then Continue;
    if J <> AFrames then
      InterlockedExchangeAdd64(FUnderruns, 1);
    HasData := True;
    TmpPtr := PSingle(@FScratch.Data[0]);
    SimdAddF32(TmpPtr, MixPtr, AFrames * FFormat.Channels, Gain);
  end;

  if not HasData then
  begin
    AudioSilentFill(ABuffer, FFormat, AFrames);
    Result := 0;
    Exit;
  end;

  SimdClampF32(MixPtr, AFrames * FFormat.Channels, -1.0, 1.0);

  HasProcessor := False;
  for I := 0 to High(FProcSnap) do if FProcSnap[I].Alive and Assigned(FProcSnap[I].Processor) then HasProcessor := True;
  if HasProcessor then
  begin
    FOut.Format := FFormat;
    FOut.FrameCount := AFrames;
    FScratch.Format := FFormat;
    FScratch.FrameCount := AFrames;
    Move(ABuffer.Data[0], FOut.Data[0], Needed);
    for I := 0 to High(FProcSnap) do
    begin
      if not FProcSnap[I].Alive then Continue;
      if not Assigned(FProcSnap[I].Processor) then Continue;
      try
        FProcSnap[I].Processor.Process(FOut, FScratch);
        // swap buffers without alloc: exchange data pointers via temp move through ABuffer
        Move(FScratch.Data[0], ABuffer.Data[0], Needed);
        Move(FOut.Data[0], FScratch.Data[0], Needed);
        Move(ABuffer.Data[0], FOut.Data[0], Needed);
      except
        InterlockedExchangeAdd64(FViolations, 1);
      end;
    end;
    if (LSnapProcs > 0) and FProcSnap[High(FProcSnap)].Alive then
      Move(FOut.Data[0], ABuffer.Data[0], Needed)
    else
      Move(FOut.Data[0], ABuffer.Data[0], Needed);
  end;

  ABuffer.FrameCount := AFrames;
  ABuffer.Format := FFormat;
  FPosition := FPosition + UInt64(AFrames);
  Result := AFrames;
end;

end.
