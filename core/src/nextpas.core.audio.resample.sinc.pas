unit nextpas.core.audio.resample.sinc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.pcm;

type
  TResampleQuality = (rsDraft, rsGood, rsBest);

  TSingleArray = array of Single;
  // caller scratch for INV-6 steady zero heap growth; geometric doubling via EnsureScratch
  TResampleScratch = record
    InF32: TSingleArray;
    PlanesIn: TAudioPlaneArray;
    PlanesOut: TAudioPlaneArray;
  end;

  TSincResampler = class(TInterfacedObject, IAudioResampler)
  private
    FQuality: TResampleQuality;
    FTaps: Integer;
    FBeta: Double;
    FKaiserTable: array of Double;
    FKaiserDen: Double;
    // perf: polyphase kernel cache — PhaseCount * FTaps Single, precomputed Sinc*Kaiser, normalized per phase
    FPhaseCount: Integer;
    FKernels: array of Single;
    procedure BuildKaiserTable;
    procedure BuildKernels;
    function GetKernelPtr(APhase: Integer): PSingle; inline;
    function BesselI0(AX: Double): Double; inline;
    function KaiserWindow(AIdx: Integer): Double; inline;
    function Sinc(AX: Double): Double; inline;
    // perf: inline dot via SIMD dispatch — zero-copy, 4/8-wide, no trig per sample
    function DotKernelF32(const AIn: PSingle; const AKernel: PSingle; ACount: Integer): Single; inline;
    function KernelSumF32(const AKernel: PSingle; ACount: Integer): Single; inline;
    procedure EnsurePlanes(var AInF32: TSingleArray; var APlanesIn, APlanesOut: TAudioPlaneArray; ANeededIn, ABytesIn, ABytesOut, AChannels: Integer); inline;
    procedure EnsureScratch(var AScratch: TResampleScratch; ANeededIn, ABytesIn, ABytesOut, AChannels: Integer); inline;
    procedure EnsureThreadScratch(ANeededIn, ABytesIn, ABytesOut, AChannels: Integer); inline;
    // single source core — deduplicates ~110 lines between overloads, I-Cache/branch pressure down
    function ResampleCore(const AInput: TAudioBuffer; ANewRate: Integer; var AInF32: TSingleArray; var APlanesIn, APlanesOut: TAudioPlaneArray): TAudioBuffer;
  public
    constructor Create(AQuality: TResampleQuality = rsGood);
    function Resample(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer; overload;
    // realtime zero-alloc: caller provides scratch, Result.Data reused via BytesEnsureCapacity
    function Resample(const AInput: TAudioBuffer; ANewRate: Integer; var AScratch: TResampleScratch): TAudioBuffer; overload;
    // streaming variant: caller provides output buffer for reuse (steady zero alloc)
    function ResampleTo(const AInput: TAudioBuffer; ANewRate: Integer; var AOutput: TAudioBuffer; var AScratch: TResampleScratch): Integer;
    function LatencyFrames: Integer;
  end;

function CreateSincResampler(AQuality: TResampleQuality = rsGood): IAudioResampler;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.math.base,
  nextpas.core.math.scalar,
  nextpas.core.math.trig,
  nextpas.core.audio.errors,
  nextpas.core.simd.arrays;

threadvar
  // per-thread geometric scratch, amortized O(1) after warmup; no global FScratch竞写 per INV-6
  GScratch: TResampleScratch;

constructor TSincResampler.Create(AQuality: TResampleQuality);
begin
  inherited Create;
  FQuality := AQuality;
  case AQuality of
    rsDraft: begin FTaps := 16; FBeta := 6.0; FPhaseCount := 32; end;
    rsGood:  begin FTaps := 64; FBeta := 8.0; FPhaseCount := 64; end;
    rsBest:  begin FTaps := 128; FBeta := 10.0; FPhaseCount := 64; end;
  end;
  if (FTaps and 1) <> 0 then Inc(FTaps);
  if FPhaseCount <= 0 then FPhaseCount := 64;
  BuildKaiserTable;
  BuildKernels;
end;

function TSincResampler.LatencyFrames: Integer;
begin
  Result := FTaps div 2;
end;

function TSincResampler.BesselI0(AX: Double): Double; inline;
var
  DS, S: Double;
  K: Integer;
begin
  // Abramowitz & Stegun 9.8.1 series: I0(x)= sum (x/2)^{2k}/(k!^2)
  // Converges quickly for x<=10 (our beta<=10). Use 25 terms.
  S := 1.0;
  DS := 1.0;
  for K := 1 to 25 do
  begin
    DS := DS * (AX * AX) / (4.0 * K * K);
    S := S + DS;
    if DS < 1e-14 * S then Break;
  end;
  Result := S;
end;

procedure TSincResampler.BuildKaiserTable;
var
  I: Integer;
  R, Arg, Num: Double;
begin
  SetLength(FKaiserTable, FTaps);
  if FTaps <= 0 then Exit;
  // Den precomputed once, not per tap
  FKaiserDen := BesselI0(FBeta);
  if FKaiserDen = 0 then FKaiserDen := 1.0;
  for I := 0 to FTaps - 1 do
  begin
    if FTaps <= 1 then
      FKaiserTable[I] := 1.0
    else
    begin
      R := (2.0 * I / (FTaps - 1) - 1.0);
      R := 1.0 - R * R;
      if R < 0 then R := 0;
      R := Sqrt(R);
      Arg := FBeta * R;
      Num := BesselI0(Arg);
      FKaiserTable[I] := Num / FKaiserDen;
    end;
  end;
end;

procedure TSincResampler.BuildKernels;
var
  P, T: Integer;
  Frac, X, W, Sum: Double;
  LBase: Integer;
begin
  if (FTaps <= 0) or (FPhaseCount <= 0) then Exit;
  SetLength(FKernels, FPhaseCount * FTaps);
  for P := 0 to FPhaseCount - 1 do
  begin
    Frac := P / FPhaseCount;
    Sum := 0;
    LBase := P * FTaps;
    for T := 0 to FTaps - 1 do
    begin
      X := T - FTaps / 2 - Frac + 0.5;
      W := Sinc(X) * FKaiserTable[T];
      FKernels[LBase + T] := Single(W);
      Sum := Sum + W;
    end;
    if Sum <> 0 then
      for T := 0 to FTaps - 1 do
        FKernels[LBase + T] := Single(Double(FKernels[LBase + T]) / Sum);
  end;
end;

function TSincResampler.GetKernelPtr(APhase: Integer): PSingle; inline;
begin
  // perf: inline zero-copy pointer arithmetic, no bounds check in hot path (caller clamps)
  if (APhase < 0) then APhase := 0
  else if (APhase >= FPhaseCount) then APhase := FPhaseCount - 1;
  Result := @FKernels[APhase * FTaps];
end;

function TSincResampler.DotKernelF32(const AIn: PSingle; const AKernel: PSingle; ACount: Integer): Single; inline;
begin
  // perf: inline SIMD dot via single-source simd.arrays dispatch (SSE2/AVX2/NEON or scalar fallback), zero-copy
  Result := SimdArrayDotProductF32(AIn, AKernel, SizeUInt(ACount));
end;

function TSincResampler.KaiserWindow(AIdx: Integer): Double; inline;
begin
  // table lookup, no Bessel per call
  if (AIdx < 0) or (AIdx >= Length(FKaiserTable)) then Exit(0);
  Result := FKaiserTable[AIdx];
end;

function TSincResampler.Sinc(AX: Double): Double; inline;
begin
  if Abs(AX) < 1e-12 then Exit(1.0);
  Result := Sin(PI_VALUE * AX) / (PI_VALUE * AX);
end;

procedure TSincResampler.EnsurePlanes(var AInF32: TSingleArray; var APlanesIn, APlanesOut: TAudioPlaneArray; ANeededIn, ABytesIn, ABytesOut, AChannels: Integer); inline;
var
  LCap: Integer;
  LCh: Integer;
begin
  // perf: inline geometric growth single source via AudioEnsureCapacity/BytesEnsureCapacity, steady zero alloc; reused by both scratch paths
  if Length(AInF32) < ANeededIn then
  begin
    LCap := Length(AInF32);
    AudioEnsureCapacity(LCap, ANeededIn, 256);
    SetLength(AInF32, LCap);
  end;
  if Length(APlanesIn) <> AChannels then
    SetLength(APlanesIn, AChannels);
  if Length(APlanesOut) <> AChannels then
    SetLength(APlanesOut, AChannels);
  for LCh := 0 to AChannels - 1 do
  begin
    AudioEnsureBytesCapacity(APlanesIn[LCh], SizeUInt(ABytesIn));
    if Length(APlanesIn[LCh]) < ABytesIn then
      SetLength(APlanesIn[LCh], ABytesIn);
    AudioEnsureBytesCapacity(APlanesOut[LCh], SizeUInt(ABytesOut));
    if Length(APlanesOut[LCh]) < ABytesOut then
      SetLength(APlanesOut[LCh], ABytesOut);
  end;
end;

procedure TSincResampler.EnsureScratch(var AScratch: TResampleScratch; ANeededIn, ABytesIn, ABytesOut, AChannels: Integer); inline;
begin
  // thin forwarding to single-source EnsurePlanes, keeps L0-L3 owner boundary (bytes.ops only)
  EnsurePlanes(AScratch.InF32, AScratch.PlanesIn, AScratch.PlanesOut, ANeededIn, ABytesIn, ABytesOut, AChannels);
end;

procedure TSincResampler.EnsureThreadScratch(ANeededIn, ABytesIn, ABytesOut, AChannels: Integer); inline;
begin
  // thin forwarding to single-source EnsurePlanes, threadvar geometric reuse, no global竞写
  EnsurePlanes(GScratch.InF32, GScratch.PlanesIn, GScratch.PlanesOut, ANeededIn, ABytesIn, ABytesOut, AChannels);
end;

function TSincResampler.KernelSumF32(const AKernel: PSingle; ACount: Integer): Single; inline;
begin
  // perf: inline SIMD sum via single-source simd.arrays, zero-copy, 8-wide
  Result := SimdArraySumF32(AKernel, SizeUInt(ACount));
end;

function TSincResampler.ResampleCore(const AInput: TAudioBuffer; ANewRate: Integer; var AInF32: TSingleArray; var APlanesIn, APlanesOut: TAudioPlaneArray): TAudioBuffer;
var
  LRatio: Double;
  LOutFrames: Integer;
  LCh, LOutFrame, LSrcBase, LPhase: Integer;
  LSrcPos, LFrac, LSum: Double;
  LWsum: Single;
  I: Integer;
  LNeededIn: Integer;
  LBytesIn, LBytesOut: Integer;
  LOutBytes: Integer;
  PKernel, PKernelSlice, PIn: PSingle;
  // edge SIMD contiguous window
  LClipStart, LClipEnd, LValidCount, LKernelOff: Integer;
begin
  if (ANewRate < MinAudioSampleRate) or (ANewRate > MaxAudioSampleRate) then
    raise EInvalidArgument.CreateFmt('SincResample: rate %d out of range', [ANewRate]);
  if not AInput.Format.IsValid then
    raise EAudioError.Create('SincResample: invalid input format');
  if AInput.IsEmpty then
  begin
    Result.Format := AudioFormatCreate(ANewRate, AInput.Format.Channels, sfF32);
    Result.Format.ChannelMask := AInput.Format.ChannelMask;
    Result.Format.ChannelLayout := AInput.Format.ChannelLayout;
    Result.FrameCount := 0;
    Result.Data := nil;
    Exit;
  end;
  LRatio := AInput.Format.SampleRate / ANewRate;
  // Int64 guard for Frame*Rate overflow (INV-8)
  if Int64(AInput.FrameCount) * Int64(ANewRate) > Int64(High(Integer)) * Int64(AInput.Format.SampleRate) then
    LOutFrames := High(Integer)
  else
    LOutFrames := Integer(Int64(AInput.FrameCount) * Int64(ANewRate) div Int64(AInput.Format.SampleRate));
  if LOutFrames < 0 then LOutFrames := 0;
  Result.Format := AudioFormatCreate(ANewRate, AInput.Format.Channels, sfF32);
  Result.Format.ChannelMask := AInput.Format.ChannelMask;
  Result.Format.ChannelLayout := AInput.Format.ChannelLayout;
  Result.FrameCount := LOutFrames;
  // output buffer guard: 16MiB limit (INV-8 style)
  if Int64(LOutFrames) * Int64(Result.Format.BlockAlign) > 16*1024*1024 then
    raise EInvalidArgument.CreateFmt('SincResample: output %d bytes exceeds 16MiB limit', [Int64(LOutFrames) * Int64(Result.Format.BlockAlign)]);
  LOutBytes := LOutFrames * Result.Format.BlockAlign;
  // INV-6 geometric reuse: Result.Data via AudioEnsureBytesCapacity/BytesEnsureCapacity single source, steady zero heap growth
  AudioEnsureBytesCapacity(Result.Data, SizeUInt(LOutBytes));
  if Length(Result.Data) < LOutBytes then
    SetLength(Result.Data, LOutBytes);
  if LOutFrames = 0 then Exit;

  // scratch reuse: geometric growth via AudioEnsureCapacity/BytesEnsureCapacity, amortized O(1) after warmup; caller/threadvar paths unified
  LNeededIn := AInput.FrameCount * AInput.Format.Channels;
  LBytesIn := AInput.FrameCount * SizeOf(Single);
  LBytesOut := LOutFrames * SizeOf(Single);
  EnsurePlanes(AInF32, APlanesIn, APlanesOut, LNeededIn, LBytesIn, LBytesOut, AInput.Format.Channels);
  if AInput.Format.SampleFormat = sfF32 then
    // single source: base.utils CopyMem → bytes.ops, SizeUInt guard, non-overlapping
    CopyMem(@AInF32[0], @AInput.Data[0], SizeUInt(Length(AInput.Data)))
  else
  begin
    for I := 0 to LNeededIn - 1 do
    begin
      case AInput.Format.SampleFormat of
        sfS16: PSingle(@AInF32[I])^ := PcmS16ToF32(PSmallInt(@AInput.Data[I * 2])^);
        sfS32: PSingle(@AInF32[I])^ := PcmS32ToF32(PLongInt(@AInput.Data[I * 4])^);
        sfU8:  PSingle(@AInF32[I])^ := PcmU8ToF32(AInput.Data[I]);
        sfS24: PSingle(@AInF32[I])^ := PcmS24ToF32(PcmReadS24LE(AInput.Data, I * 3));
      else
        AInF32[I] := 0;
      end;
    end;
  end;

  for LCh := 0 to AInput.Format.Channels - 1 do
    for I := 0 to AInput.FrameCount - 1 do
      PSingle(@APlanesIn[LCh][I * SizeOf(Single)])^ := AInF32[I * AInput.Format.Channels + LCh];

  for LCh := 0 to AInput.Format.Channels - 1 do
    for LOutFrame := 0 to LOutFrames - 1 do
    begin
      LSrcPos := LOutFrame * LRatio;
      LSrcBase := Trunc(LSrcPos) - FTaps div 2 + 1;
      LFrac := LSrcPos - Trunc(LSrcPos);
      if LFrac < 0 then LFrac := 0 else if LFrac >= 1 then LFrac := 0.999999;
      LPhase := Trunc(LFrac * FPhaseCount);
      if LPhase < 0 then LPhase := 0 else if LPhase >= FPhaseCount then LPhase := FPhaseCount - 1;
      PKernel := GetKernelPtr(LPhase);
      // fast interior: contiguous window inside buffer → SIMD dot, no per-tap branch/trig, O(Taps) with 4/8-wide
      if (LSrcBase >= 0) and (LSrcBase + FTaps <= AInput.FrameCount) then
      begin
        PIn := PSingle(@APlanesIn[LCh][LSrcBase * SizeOf(Single)]);
        LSum := DotKernelF32(PIn, PKernel, FTaps);
      end
      else
      begin
        // edge: contiguous clipped window → SIMD dot + SIMD kernel sum renormalize, no per-tap mask branch/div per tap
        // TODO(SIMD): keep contiguous DotKernelF32/KernelSumF32; fallback scalar mask only if SIMD unavailable
        LClipStart := LSrcBase;
        if LClipStart < 0 then LClipStart := 0;
        LClipEnd := LSrcBase + FTaps - 1;
        if LClipEnd >= AInput.FrameCount then LClipEnd := AInput.FrameCount - 1;
        LValidCount := LClipEnd - LClipStart + 1;
        if LValidCount <= 0 then
          LSum := 0
        else
        begin
          LKernelOff := LClipStart - LSrcBase;
          PKernelSlice := @PKernel[LKernelOff];
          PIn := PSingle(@APlanesIn[LCh][LClipStart * SizeOf(Single)]);
          LSum := DotKernelF32(PIn, PKernelSlice, LValidCount);
          // renormalize truncated window via SIMD sum, single div per frame (not per tap)
          LWsum := KernelSumF32(PKernelSlice, LValidCount);
          if LWsum <> 0 then LSum := LSum / LWsum else LSum := 0;
        end;
      end;
      if LSum > 1 then LSum := 1 else if LSum < -1 then LSum := -1;
      PSingle(@APlanesOut[LCh][LOutFrame * SizeOf(Single)])^ := Single(LSum);
    end;

  for I := 0 to LOutFrames - 1 do
    for LCh := 0 to AInput.Format.Channels - 1 do
      PSingle(@Result.Data[(I * AInput.Format.Channels + LCh) * SizeOf(Single)])^ :=
        PSingle(@APlanesOut[LCh][I * SizeOf(Single)])^;
end;

function TSincResampler.Resample(const AInput: TAudioBuffer; ANewRate: Integer; var AScratch: TResampleScratch): TAudioBuffer;
begin
  // single source via ResampleCore — eliminates ~110 lines duplicate, I-Cache/branch pressure down
  Result := ResampleCore(AInput, ANewRate, AScratch.InF32, AScratch.PlanesIn, AScratch.PlanesOut);
end;

function TSincResampler.Resample(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
begin
  // thin forwarding to scratch overload via threadvar — geometric reuse, zero heap churn after warmup
  Result := Resample(AInput, ANewRate, GScratch);
end;

function TSincResampler.ResampleTo(const AInput: TAudioBuffer; ANewRate: Integer; var AOutput: TAudioBuffer; var AScratch: TResampleScratch): Integer;
var
  LBuf: TAudioBuffer;
begin
  LBuf := Resample(AInput, ANewRate, AScratch);
  // caller-provided output reuse: geometric BytesEnsureCapacity single source
  AudioEnsureBytesCapacity(AOutput.Data, SizeUInt(Length(LBuf.Data)));
  if Length(AOutput.Data) < Length(LBuf.Data) then
    SetLength(AOutput.Data, Length(LBuf.Data));
  if Length(LBuf.Data) > 0 then
    CopyMem(@AOutput.Data[0], @LBuf.Data[0], SizeUInt(Length(LBuf.Data)));
  AOutput.Format := LBuf.Format;
  AOutput.FrameCount := LBuf.FrameCount;
  Result := LBuf.FrameCount;
end;

function CreateSincResampler(AQuality: TResampleQuality): IAudioResampler;
begin
  Result := TSincResampler.Create(AQuality);
end;

end.
