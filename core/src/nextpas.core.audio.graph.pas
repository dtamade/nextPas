unit nextpas.core.audio.graph;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.math.scalar,
  nextpas.core.platform.sync,
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
    FLock: TPlatformMutex; // owner platform.sync (L0) via sync facade — zero SysUtils/SyncObjs, single source mutex
    FNodes: array of TGraphNode;
    FProcessors: array of TProcessorSlot;
    FNextId: Integer;
    FPosition: Int64; // atomic UInt64 via Interlocked
    FVolume: Single;
    FUnderruns: Int64;
    FViolations: Int64;
    FScratchTmp: TBytes;
    FScratchOut: TBytes;
    FSnapshotNodes: array of TGraphNode;
    FSnapshotProcs: array of TProcessorSlot;
    FNodeFree: array of Integer;
    FProcFree: array of Integer;
    FNodeDead: Integer;
    FProcDead: Integer;
    function FindNode(AId: Integer): Integer;
    function FindProcessor(AId: Integer): Integer;
    procedure EnsureScratch(var AScratch: TBytes; ANeeded: Integer); // not inline per red-line 1/2: SetLength+Move single source via bytes.ops
    procedure MaybeCompactNodes;
    procedure MaybeCompactProcs;
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
  if platform_mutex_init(FLock, PLATFORM_MUTEX_ERRORCHECK) <> 0 then
    raise EAudioGraphError.Create('Graph: mutex init failed');
  SetLength(FNodes, 0);
  SetLength(FProcessors, 0);
  FNextId := 1;
  FPosition := 0;
  FVolume := 1.0;
  FUnderruns := 0;
  FViolations := 0;
  SetLength(FScratchTmp, 0);
  SetLength(FScratchOut, 0);
  SetLength(FSnapshotNodes, 0);
  SetLength(FSnapshotProcs, 0);
  SetLength(FNodeFree, 0);
  SetLength(FProcFree, 0);
  FNodeDead := 0;
  FProcDead := 0;
end;

destructor TAudioGraph.Destroy;
begin
  platform_mutex_destroy(FLock);
  inherited;
end;

function TAudioGraph.GetFormat: TAudioFormat;
begin Result := FFormat; end;

function TAudioGraph.GetState: TGraphState;
begin
  platform_mutex_lock(FLock);
  try Result := FState;
  finally platform_mutex_unlock(FLock); end;
end;

function TAudioGraph.NodeCount: Integer;
var I, C: Integer;
begin
  platform_mutex_lock(FLock);
  try
    C := 0;
    for I := 0 to High(FNodes) do if FNodes[I].Alive then Inc(C);
    Result := C;
  finally platform_mutex_unlock(FLock); end;
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

procedure TAudioGraph.EnsureScratch(var AScratch: TBytes; ANeeded: Integer);
begin
  // perf: single source via bytes.ops — exponential grow amortized O(1), single SetLength+Move zero-copy not inline red-line 1/2
  // stability: exception-safe SetLength, capacity retained via BytesEnsureCapacity
  if Length(AScratch) < ANeeded then
    BytesEnsureCapacity(AScratch, SizeUInt(ANeeded));
end;

procedure TAudioGraph.MaybeCompactNodes;
var I, J, N: Integer;
begin
  // caller holds FLock
  if (Length(FNodes) <= 64) or (FNodeDead <= Length(FNodes) div 2) then Exit;
  N := 0;
  for I := 0 to High(FNodes) do if FNodes[I].Alive then Inc(N);
  J := 0;
  for I := 0 to High(FNodes) do if FNodes[I].Alive then
  begin
    if I <> J then FNodes[J] := FNodes[I];
    Inc(J);
  end;
  SetLength(FNodes, N);
  SetLength(FNodeFree, 0);
  FNodeDead := 0;
end;

procedure TAudioGraph.MaybeCompactProcs;
var I, J, N: Integer;
begin
  if (Length(FProcessors) <= 32) or (FProcDead <= Length(FProcessors) div 2) then Exit;
  N := 0;
  for I := 0 to High(FProcessors) do if FProcessors[I].Alive then Inc(N);
  J := 0;
  for I := 0 to High(FProcessors) do if FProcessors[I].Alive then
  begin
    if I <> J then FProcessors[J] := FProcessors[I];
    Inc(J);
  end;
  SetLength(FProcessors, N);
  SetLength(FProcFree, 0);
  FProcDead := 0;
end;

function TAudioGraph.AddSource(const ASource: IRealtimeAudioSource; AGain: Single): Integer;
var Idx: Integer;
begin
  if not Assigned(ASource) then
    raise EAudioGraphError.Create('AddSource: nil');
  if (ASource.Format.SampleRate <> FFormat.SampleRate) or (ASource.Format.Channels <> FFormat.Channels) then
    raise EAudioGraphError.Create('AddSource: format mismatch');
  if IsNaN(AGain) or IsInfinite(AGain) then AGain := 1.0;
  platform_mutex_lock(FLock);
  try
    Result := FNextId; Inc(FNextId);
    if Length(FNodeFree) > 0 then
    begin
      Idx := FNodeFree[High(FNodeFree)];
      SetLength(FNodeFree, Length(FNodeFree)-1);
      Dec(FNodeDead);
      FNodes[Idx].Id := Result;
      FNodes[Idx].Source := ASource;
      FNodes[Idx].Gain := AGain;
      FNodes[Idx].Alive := True;
    end else
    begin
      Idx := Length(FNodes);
      SetLength(FNodes, Idx + 1);
      FNodes[Idx].Id := Result;
      FNodes[Idx].Source := ASource;
      FNodes[Idx].Gain := AGain;
      FNodes[Idx].Alive := True;
    end;
    if FState = gsStopped then FState := gsPlaying;
  finally platform_mutex_unlock(FLock); end;
end;

function TAudioGraph.RemoveSource(AId: Integer): Boolean;
var Idx: Integer;
begin
  platform_mutex_lock(FLock);
  try
    Idx := FindNode(AId);
    if Idx < 0 then Exit(False);
    FNodes[Idx].Alive := False;
    FNodes[Idx].Source := nil;
    SetLength(FNodeFree, Length(FNodeFree)+1);
    FNodeFree[High(FNodeFree)] := Idx;
    Inc(FNodeDead);
    MaybeCompactNodes;
    Result := True;
  finally platform_mutex_unlock(FLock); end;
end;

function TAudioGraph.SetGain(AId: Integer; AGain: Single): Boolean;
var Idx: Integer;
begin
  if IsNaN(AGain) or IsInfinite(AGain) then Exit(False);
  platform_mutex_lock(FLock);
  try
    Idx := FindNode(AId);
    if Idx < 0 then Exit(False);
    FNodes[Idx].Gain := AGain;
    Result := True;
  finally platform_mutex_unlock(FLock); end;
end;

function TAudioGraph.AddProcessor(const AProcessor: IAudioProcessor): Integer;
var Idx: Integer;
begin
  if not Assigned(AProcessor) then
    raise EAudioGraphError.Create('AddProcessor: nil');
  platform_mutex_lock(FLock);
  try
    Result := FNextId; Inc(FNextId);
    if Length(FProcFree) > 0 then
    begin
      Idx := FProcFree[High(FProcFree)];
      SetLength(FProcFree, Length(FProcFree)-1);
      Dec(FProcDead);
      FProcessors[Idx].Id := Result;
      FProcessors[Idx].Processor := AProcessor;
      FProcessors[Idx].Alive := True;
    end else
    begin
      Idx := Length(FProcessors);
      SetLength(FProcessors, Idx + 1);
      FProcessors[Idx].Id := Result;
      FProcessors[Idx].Processor := AProcessor;
      FProcessors[Idx].Alive := True;
    end;
  finally platform_mutex_unlock(FLock); end;
end;

function TAudioGraph.RemoveProcessor(AId: Integer): Boolean;
var Idx: Integer;
begin
  platform_mutex_lock(FLock);
  try
    Idx := FindProcessor(AId);
    if Idx < 0 then Exit(False);
    FProcessors[Idx].Alive := False;
    FProcessors[Idx].Processor := nil;
    SetLength(FProcFree, Length(FProcFree)+1);
    FProcFree[High(FProcFree)] := Idx;
    Inc(FProcDead);
    MaybeCompactProcs;
    Result := True;
  finally platform_mutex_unlock(FLock); end;
end;

procedure TAudioGraph.Clear;
var I: Integer;
begin
  platform_mutex_lock(FLock);
  try
    for I := 0 to High(FNodes) do
    begin FNodes[I].Alive := False; FNodes[I].Source := nil; end;
    for I := 0 to High(FProcessors) do
    begin FProcessors[I].Alive := False; FProcessors[I].Processor := nil; end;
    SetLength(FNodes, 0);
    SetLength(FProcessors, 0);
    SetLength(FNodeFree, 0);
    SetLength(FProcFree, 0);
    FNodeDead := 0;
    FProcDead := 0;
    FState := gsStopped;
    InterlockedExchange64(FPosition, 0);
  finally platform_mutex_unlock(FLock); end;
end;

function TAudioGraph.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := FillRealtime(ABuffer, AFrames);
end;

function TAudioGraph.SeekTo(AFrame: UInt64): Boolean;
var I: Integer; OK: Boolean;
begin
  platform_mutex_lock(FLock);
  try
    OK := True;
    for I := 0 to High(FNodes) do
      if FNodes[I].Alive then
        if not FNodes[I].Source.SeekTo(AFrame) then OK := False;
    if OK then InterlockedExchange64(FPosition, Int64(AFrame));
    Result := OK;
  finally platform_mutex_unlock(FLock); end;
end;

function TAudioGraph.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  Needed, I, J, AliveN, AliveP, FillIdx: Integer;
  NodesSnap: array of TGraphNode;
  ProcsSnap: array of TProcessorSlot;
  Tmp: TAudioBuffer;
  MixPtr, TmpPtr: PSingle;
  Gain, SnapVol: Single;
  HasData: Boolean;
  OutBuf, SwapBuf: TAudioBuffer;
  SrcFmt: TAudioFormat;
begin
  if AFrames <= 0 then Exit(0);
  Needed := Integer(Int64(AFrames) * Int64(FFormat.BlockAlign));
  if Length(ABuffer.Data) < Needed then
  begin
    InterlockedExchangeAdd64(FViolations, 1);
    AFrames := Length(ABuffer.Data) div FFormat.BlockAlign;
    if AFrames <= 0 then Exit(0);
    Needed := Integer(Int64(AFrames) * Int64(FFormat.BlockAlign));
  end;
  // two-phase snapshot: count under lock -> alloc outside -> copy under lock
  // 两阶段快照契约：锁内仅计数→锁外分配→锁内深拷贝，混音无锁
  // S4 冻结：分配仍在实时路径（SetLength 保留，文档先冻契约，S6 再零分配），混音阶段无锁
  platform_mutex_lock(FLock);
  try
    AliveN := 0;
    for I := 0 to High(FNodes) do if FNodes[I].Alive then Inc(AliveN);
    AliveP := 0;
    for I := 0 to High(FProcessors) do if FProcessors[I].Alive then Inc(AliveP);
    SnapVol := FVolume;
  finally platform_mutex_unlock(FLock); end;
  // snapshot scratch reuse: preallocated FSnapshotNodes/Procs reuse, steady zero alloc
  if Length(FSnapshotNodes) < AliveN then SetLength(FSnapshotNodes, AliveN);
  if Length(FSnapshotProcs) < AliveP then SetLength(FSnapshotProcs, AliveP);
  if (AliveN > 0) or (AliveP > 0) then
  begin
    platform_mutex_lock(FLock);
    try
      FillIdx := 0;
      for I := 0 to High(FNodes) do if FNodes[I].Alive then
      begin
        if FillIdx < AliveN then
        begin FSnapshotNodes[FillIdx] := FNodes[I]; Inc(FillIdx); end;
      end;
      FillIdx := 0;
      for I := 0 to High(FProcessors) do if FProcessors[I].Alive then
      begin
        if FillIdx < AliveP then
        begin FSnapshotProcs[FillIdx] := FProcessors[I]; Inc(FillIdx); end;
      end;
      SnapVol := FVolume;
    finally platform_mutex_unlock(FLock); end;
  end;

  if AliveN = 0 then
  begin
    FillChar(ABuffer.Data[0], Needed, 0);
    ABuffer.FrameCount := AFrames;
    ABuffer.Format := FFormat;
    InterlockedExchangeAdd64(FPosition, Int64(AFrames));
    Exit(AFrames);
  end;

  FillChar(ABuffer.Data[0], Needed, 0);
  MixPtr := PSingle(@ABuffer.Data[0]);
  HasData := False;
  EnsureScratch(FScratchTmp, Needed);
  Tmp.Data := FScratchTmp;
  Tmp.Format := FFormat;
  Tmp.FrameCount := AFrames;
  for I := 0 to AliveN - 1 do
  begin
    // mismatch not tear
    SrcFmt := FSnapshotNodes[I].Source.Format;
    if (SrcFmt.SampleRate <> FFormat.SampleRate) or (SrcFmt.Channels <> FFormat.Channels) then
    begin
      InterlockedExchangeAdd64(FViolations, 1);
      Continue;
    end;
    Gain := FSnapshotNodes[I].Gain * SnapVol;
    // zero tmp tail guard before fill
    FillChar(Tmp.Data[0], Needed, 0);
    try
      J := FSnapshotNodes[I].Source.FillRealtime(Tmp, AFrames);
    except
      InterlockedExchangeAdd64(FViolations, 1);
      Continue;
    end;
    if J < 0 then
    begin
      InterlockedExchangeAdd64(FViolations, 1);
      Continue;
    end;
    if J = 0 then Continue;
    if J < AFrames then
    begin
      InterlockedExchangeAdd64(FUnderruns, 1);
      // source contract: should have zero-filled tail, but ensure
      FillChar((PByte(@Tmp.Data[0]) + J * FFormat.BlockAlign)^, (AFrames - J) * FFormat.BlockAlign, 0);
      J := AFrames;
    end;
    HasData := True;
    TmpPtr := PSingle(@Tmp.Data[0]);
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
    ABuffer.FrameCount := AFrames;
    ABuffer.Format := FFormat;
    InterlockedExchangeAdd64(FPosition, Int64(AFrames));
    Result := AFrames;
    Exit;
  end;

  for I := 0 to AFrames * FFormat.Channels - 1 do
  begin
    if MixPtr[I] > 1.0 then MixPtr[I] := 1.0
    else if MixPtr[I] < -1.0 then MixPtr[I] := -1.0;
  end;

  if AliveP > 0 then
  begin
    EnsureScratch(FScratchOut, Needed);
    EnsureScratch(FScratchTmp, Needed);
    Move(ABuffer.Data[0], FScratchOut[0], Needed);
    OutBuf.Format := FFormat;
    OutBuf.FrameCount := AFrames;
    OutBuf.Data := FScratchOut;
    Tmp.Format := FFormat;
    Tmp.FrameCount := AFrames;
    Tmp.Data := FScratchTmp;
    for I := 0 to AliveP - 1 do
    begin
      try
        FSnapshotProcs[I].Processor.Process(OutBuf, Tmp);
        SwapBuf := OutBuf;
        OutBuf := Tmp;
        Tmp := SwapBuf;
      except
        InterlockedExchangeAdd64(FViolations, 1);
      end;
    end;
    if Length(OutBuf.Data) >= Needed then
      Move(OutBuf.Data[0], ABuffer.Data[0], Needed)
    else if Length(OutBuf.Data) > 0 then
    begin
      FillChar(ABuffer.Data[0], Needed, 0);
      Move(OutBuf.Data[0], ABuffer.Data[0], Min(Needed, Length(OutBuf.Data)));
    end;
  end;

  ABuffer.FrameCount := AFrames;
  ABuffer.Format := FFormat;
  InterlockedExchangeAdd64(FPosition, Int64(AFrames));
  Result := AFrames;
end;

end.
