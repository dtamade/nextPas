unit nextpas.core.audio.graph;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops, // single source for BytesCopy/BytesZero inline zero-copy, no base.utils dual source
  nextpas.core.math.scalar,
  nextpas.core.sync.mutex,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.graph.intf,
  nextpas.core.audio.errors,
  nextpas.core.audio.simd;

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
    FLock: TRecursiveMutex;
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
    procedure EnsureScratch(var AScratch: TBytes; ANeeded: Integer); inline;
    procedure EnsureSnapshotCapacity(ANodes, AProcs: Integer); inline;
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
  FLock := TRecursiveMutex.Create;
  SetLength(FNodes, 0);
  SetLength(FProcessors, 0);
  FNextId := 1;
  FPosition := 0;
  FVolume := 1.0;
  FUnderruns := 0;
  FViolations := 0;
  // INV-6 steady zero heap growth: preallocate scratch for realtime FillRealtime reuse (geometric, bytes.ops single source via AudioEnsureCapacity), control-plane snapshot pre-grows elsewhere
  SetLength(FScratchTmp, 8192 * FFormat.BlockAlign);
  SetLength(FScratchOut, 8192 * FFormat.BlockAlign);
  SetLength(FSnapshotNodes, 0);
  SetLength(FSnapshotProcs, 0);
  SetLength(FNodeFree, 0);
  SetLength(FProcFree, 0);
  FNodeDead := 0;
  FProcDead := 0;
end;

destructor TAudioGraph.Destroy;
begin
  // stability: resource release not lost, HEAPTRC zero leak
  SetLength(FScratchTmp, 0);
  SetLength(FScratchOut, 0);
  SetLength(FSnapshotNodes, 0);
  SetLength(FSnapshotProcs, 0);
  SetLength(FNodes, 0);
  SetLength(FProcessors, 0);
  SetLength(FNodeFree, 0);
  SetLength(FProcFree, 0);
  FLock.Free;
  inherited;
end;

function TAudioGraph.GetFormat: TAudioFormat;
begin Result := FFormat; end;

function TAudioGraph.GetState: TGraphState;
begin
  FLock.Acquire;
  try Result := FState;
  finally FLock.Release; end;
end;

function TAudioGraph.NodeCount: Integer;
var I, C: Integer;
begin
  FLock.Acquire;
  try
    C := 0;
    for I := 0 to High(FNodes) do if FNodes[I].Alive then Inc(C);
    Result := C;
  finally FLock.Release; end;
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

procedure TAudioGraph.EnsureScratch(var AScratch: TBytes; ANeeded: Integer); inline;
var LCap: Integer;
begin
  // perf: inline + single source via audio.base AudioEnsureCapacity geometric doubling, control-plane prealloc; realtime FillRealtime reuses without heap growth (INV-6)
  if Length(AScratch) >= ANeeded then Exit;
  LCap := Length(AScratch);
  AudioEnsureCapacity(LCap, ANeeded, 64);
  if Length(AScratch) <> LCap then SetLength(AScratch, LCap);
end;

procedure TAudioGraph.EnsureSnapshotCapacity(ANodes, AProcs: Integer); inline;
var LCap: Integer;
begin
  // control-plane growth only (AddSource/AddProcessor), realtime FillRealtime reuses snapshot scratch steady zero alloc per INV-6 via AudioEnsureCapacity single source
  if ANodes > 0 then
  begin
    LCap := Length(FSnapshotNodes);
    AudioEnsureCapacity(LCap, ANodes, 4);
    if Length(FSnapshotNodes) <> LCap then SetLength(FSnapshotNodes, LCap);
  end;
  if AProcs > 0 then
  begin
    LCap := Length(FSnapshotProcs);
    AudioEnsureCapacity(LCap, AProcs, 4);
    if Length(FSnapshotProcs) <> LCap then SetLength(FSnapshotProcs, LCap);
  end;
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
  if IsNan(AGain) or IsInfinite(AGain) then AGain := 1.0;
  FLock.Acquire;
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
    // control-plane snapshot pre-grow: ensure FillRealtime steady zero alloc (INV-6)
    EnsureSnapshotCapacity(Length(FNodes), Length(FProcessors));
  finally FLock.Release; end;
end;

function TAudioGraph.RemoveSource(AId: Integer): Boolean;
var Idx: Integer;
begin
  FLock.Acquire;
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
  finally FLock.Release; end;
end;

function TAudioGraph.SetGain(AId: Integer; AGain: Single): Boolean;
var Idx: Integer;
begin
  if IsNan(AGain) or IsInfinite(AGain) then Exit(False);
  FLock.Acquire;
  try
    Idx := FindNode(AId);
    if Idx < 0 then Exit(False);
    FNodes[Idx].Gain := AGain;
    Result := True;
  finally FLock.Release; end;
end;

function TAudioGraph.AddProcessor(const AProcessor: IAudioProcessor): Integer;
var Idx: Integer;
begin
  if not Assigned(AProcessor) then
    raise EAudioGraphError.Create('AddProcessor: nil');
  FLock.Acquire;
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
    EnsureSnapshotCapacity(Length(FNodes), Length(FProcessors));
  finally FLock.Release; end;
end;

function TAudioGraph.RemoveProcessor(AId: Integer): Boolean;
var Idx: Integer;
begin
  FLock.Acquire;
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
  finally FLock.Release; end;
end;

procedure TAudioGraph.Clear;
var I: Integer;
begin
  FLock.Acquire;
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
  finally FLock.Release; end;
end;

function TAudioGraph.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result := FillRealtime(ABuffer, AFrames);
end;

function TAudioGraph.SeekTo(AFrame: UInt64): Boolean;
var I: Integer; OK: Boolean;
begin
  FLock.Acquire;
  try
    OK := True;
    for I := 0 to High(FNodes) do
      if FNodes[I].Alive then
        if not FNodes[I].Source.SeekTo(AFrame) then OK := False;
    if OK then InterlockedExchange64(FPosition, Int64(AFrame));
    Result := OK;
  finally FLock.Release; end;
end;

function TAudioGraph.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var
  Needed, I, J, AliveN, AliveP, FillIdx, NSamples: Integer;
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
  Needed := Integer(AudioBytesForFrames(FFormat, AFrames));
  if (Needed <= 0) or (Length(ABuffer.Data) < Needed) then
  begin
    InterlockedExchangeAdd64(FViolations, 1);
    AFrames := Length(ABuffer.Data) div FFormat.BlockAlign;
    if AFrames <= 0 then Exit(0);
    Needed := Integer(AudioBytesForFrames(FFormat, AFrames));
    if Needed <= 0 then Exit(0);
  end;
  // two-phase snapshot: count under lock -> ensure capacity (control-plane pre-grow) -> copy under lock
  // 两阶段快照契约：锁内仅计数→锁外按需增长（ violations 计数，AudioEnsureCapacity 单源）→锁内深拷贝，混音无锁
  // INV-6 稳态零堆增长：控制面 AddSource/AddProcessor 已预增 FSnapshot* 容量，实时路径仅在容量不足时增长（违例计数），稳态复用零分配；统一字节预算经 AudioBytesForFrames 单源
  FLock.Acquire;
  try
    AliveN := 0;
    for I := 0 to High(FNodes) do if FNodes[I].Alive then Inc(AliveN);
    AliveP := 0;
    for I := 0 to High(FProcessors) do if FProcessors[I].Alive then Inc(AliveP);
    SnapVol := FVolume;
  finally FLock.Release; end;
  // snapshot scratch reuse: preallocated via control-plane EnsureSnapshotCapacity, steady zero alloc after warmup (INV-6); realtime never allocates, truncate to available capacity (violation counted)
  if (Length(FSnapshotNodes) < AliveN) or (Length(FSnapshotProcs) < AliveP) then
  begin
    InterlockedExchangeAdd64(FViolations, 1);
    if Length(FSnapshotNodes) < AliveN then AliveN := Length(FSnapshotNodes);
    if Length(FSnapshotProcs) < AliveP then AliveP := Length(FSnapshotProcs);
  end;
  if (AliveN > 0) or (AliveP > 0) then
  begin
    FLock.Acquire;
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
    finally FLock.Release; end;
  end;

  if AliveN = 0 then
  begin
    BytesZero(@ABuffer.Data[0], SizeUInt(Needed));
    ABuffer.FrameCount := AFrames;
    ABuffer.Format := FFormat;
    InterlockedExchangeAdd64(FPosition, Int64(AFrames));
    Exit(AFrames);
  end;

  BytesZero(@ABuffer.Data[0], SizeUInt(Needed));
  MixPtr := PSingle(@ABuffer.Data[0]);
  HasData := False;
  // INV-6 steady zero heap growth: realtime reuses preallocated FScratchTmp (constructor 8192 frames, control-plane geometric), never SetLength here; violation truncates
  if Length(FScratchTmp) < Needed then
  begin
    InterlockedExchangeAdd64(FViolations, 1);
    if Length(FScratchTmp) >= FFormat.BlockAlign then
    begin
      AFrames := Length(FScratchTmp) div FFormat.BlockAlign;
      Needed := AFrames * FFormat.BlockAlign;
    end else
    begin
      ABuffer.FrameCount := AFrames;
      ABuffer.Format := FFormat;
      InterlockedExchangeAdd64(FPosition, Int64(AFrames));
      Exit(AFrames);
    end;
  end;
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
    // zero tmp tail guard before fill — BytesZero single source inline zero-copy
    BytesZero(@Tmp.Data[0], SizeUInt(Needed));
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
      // source contract: should have zero-filled tail, but ensure — BytesZero single source inline zero-copy
      BytesZero(PByte(@Tmp.Data[0]) + J * FFormat.BlockAlign, SizeUInt((AFrames - J) * FFormat.BlockAlign));
      J := AFrames;
    end;
    HasData := True;
    TmpPtr := PSingle(@Tmp.Data[0]);
    NSamples := AFrames * FFormat.Channels;
    // perf: inline SIMD Owner audio.simd SimdAddF32 (AVX2 8-wide / SSE2 4-wide, scalar fallback), single source, zero alloc, replaces scalar weighted loop
    SimdAddF32(TmpPtr, MixPtr, NSamples, Gain);
  end;

  if not HasData then
  begin
    BytesZero(@ABuffer.Data[0], SizeUInt(Needed));
    ABuffer.FrameCount := AFrames;
    ABuffer.Format := FFormat;
    InterlockedExchangeAdd64(FPosition, Int64(AFrames));
    Result := AFrames;
    Exit;
  end;

  NSamples := AFrames * FFormat.Channels;
  // perf: inline SIMD Owner audio.simd SimdClampF32 (SSE2/AVX2, scalar fallback), single source, replaces scalar clamp loop
  SimdClampF32(MixPtr, NSamples, -1.0, 1.0);

  if AliveP > 0 then
  begin
    // INV-6 steady zero heap growth: realtime reuses preallocated FScratchOut/FScratchTmp, never SetLength; violation counted, no heap growth
    if Length(FScratchOut) < Needed then InterlockedExchangeAdd64(FViolations, 1);
    if Length(FScratchTmp) < Needed then InterlockedExchangeAdd64(FViolations, 1);
    if (Length(FScratchOut) < Needed) or (Length(FScratchTmp) < Needed) then
    begin
      // insufficient scratch for processor chain, keep clamped mix and exit without processing (zero alloc)
      ABuffer.FrameCount := AFrames;
      ABuffer.Format := FFormat;
      InterlockedExchangeAdd64(FPosition, Int64(AFrames));
      Result := AFrames;
      Exit;
    end;
    // single source: bytes.ops BytesCopy inline zero-copy, SizeUInt(Needed) boundary, non-overlapping
    BytesCopy(@FScratchOut[0], @ABuffer.Data[0], SizeUInt(Needed));
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
      // single source: bytes.ops BytesCopy inline zero-copy, SizeUInt(Needed) boundary, non-overlapping final blit
      BytesCopy(@ABuffer.Data[0], @OutBuf.Data[0], SizeUInt(Needed))
    else if Length(OutBuf.Data) > 0 then
    begin
      BytesZero(@ABuffer.Data[0], SizeUInt(Needed));
      // single source: bytes.ops BytesCopy inline zero-copy, SizeUInt(Min(Needed,Length)) variable boundary, non-overlapping partial blit
      BytesCopy(@ABuffer.Data[0], @OutBuf.Data[0], SizeUInt(Min(Needed, Length(OutBuf.Data))));
    end;
  end;

  ABuffer.FrameCount := AFrames;
  ABuffer.Format := FFormat;
  InterlockedExchangeAdd64(FPosition, Int64(AFrames));
  Result := AFrames;
end;

end.
