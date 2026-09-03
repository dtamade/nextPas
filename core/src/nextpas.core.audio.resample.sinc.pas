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

  // caller scratch for INV-6 steady zero heap growth; geometric doubling via EnsureScratch
  TResampleScratch = record
    InF32: array of Single;
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
    procedure BuildKaiserTable; inline;
    function BesselI0(AX: Double): Double; inline;
    function KaiserWindow(AIdx: Integer): Double; inline;
    function Sinc(AX: Double): Double; inline;
    procedure EnsureScratch(var AScratch: TResampleScratch; ANeededIn, ABytesIn, ABytesOut, AChannels: Integer); inline;
    procedure EnsureThreadScratch(ANeededIn, ABytesIn, ABytesOut, AChannels: Integer); inline;
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
  nextpas.core.audio.errors;

threadvar
  // per-thread geometric scratch, amortized O(1) after warmup; no global FScratch竞写 per INV-6
  GScratchInF32: array of Single;
  GScratchPlanesIn: TAudioPlaneArray;
  GScratchPlanesOut: TAudioPlaneArray;

constructor TSincResampler.Create(AQuality: TResampleQuality);
begin
  inherited Create;
  FQuality := AQuality;
  case AQuality of
    rsDraft: begin FTaps := 16; FBeta := 6.0; end;
    rsGood:  begin FTaps := 64; FBeta := 8.0; end;
    rsBest:  begin FTaps := 128; FBeta := 10.0; end;
  end;
  if (FTaps and 1) <> 0 then Inc(FTaps);
  BuildKaiserTable;
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

procedure TSincResampler.BuildKaiserTable; inline;
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

procedure TSincResampler.EnsureScratch(var AScratch: TResampleScratch; ANeededIn, ABytesIn, ABytesOut, AChannels: Integer); inline;
var
  LCap: Integer;
  LCh: Integer;
begin
  // perf: inline geometric growth single source via AudioEnsureCapacity/BytesEnsureCapacity, steady zero alloc per INV-6
  if Length(AScratch.InF32) < ANeededIn then
  begin
    LCap := Length(AScratch.InF32);
    AudioEnsureCapacity(LCap, ANeededIn, 256);
    SetLength(AScratch.InF32, LCap);
  end;
  if Length(AScratch.PlanesIn) <> AChannels then
    SetLength(AScratch.PlanesIn, AChannels);
  if Length(AScratch.PlanesOut) <> AChannels then
    SetLength(AScratch.PlanesOut, AChannels);
  for LCh := 0 to AChannels - 1 do
  begin
    AudioEnsureBytesCapacity(AScratch.PlanesIn[LCh], SizeUInt(ABytesIn));
    if Length(AScratch.PlanesIn[LCh]) < ABytesIn then
      SetLength(AScratch.PlanesIn[LCh], ABytesIn);
    AudioEnsureBytesCapacity(AScratch.PlanesOut[LCh], SizeUInt(ABytesOut));
    if Length(AScratch.PlanesOut[LCh]) < ABytesOut then
      SetLength(AScratch.PlanesOut[LCh], ABytesOut);
  end;
end;

procedure TSincResampler.EnsureThreadScratch(ANeededIn, ABytesIn, ABytesOut, AChannels: Integer); inline;
var
  LCap: Integer;
  LCh: Integer;
begin
  // perf: threadvar geometric reuse, same single source as caller-scratch, no global竞写
  if Length(GScratchInF32) < ANeededIn then
  begin
    LCap := Length(GScratchInF32);
    AudioEnsureCapacity(LCap, ANeededIn, 256);
    SetLength(GScratchInF32, LCap);
  end;
  if Length(GScratchPlanesIn) <> AChannels then
    SetLength(GScratchPlanesIn, AChannels);
  if Length(GScratchPlanesOut) <> AChannels then
    SetLength(GScratchPlanesOut, AChannels);
  for LCh := 0 to AChannels - 1 do
  begin
    AudioEnsureBytesCapacity(GScratchPlanesIn[LCh], SizeUInt(ABytesIn));
    if Length(GScratchPlanesIn[LCh]) < ABytesIn then
      SetLength(GScratchPlanesIn[LCh], ABytesIn);
    AudioEnsureBytesCapacity(GScratchPlanesOut[LCh], SizeUInt(ABytesOut));
    if Length(GScratchPlanesOut[LCh]) < ABytesOut then
      SetLength(GScratchPlanesOut[LCh], ABytesOut);
  end;
end;

function TSincResampler.Resample(const AInput: TAudioBuffer; ANewRate: Integer; var AScratch: TResampleScratch): TAudioBuffer;
var
  LRatio: Double;
  LOutFrames: Integer;
  LCh, LOutFrame, LTap, LSrcIdx: Integer;
  LSrcPos, LX, LW, LSum, LWsum: Double;
  I: Integer;
  LNeededIn: Integer;
  LBytesIn, LBytesOut: Integer;
  LOutBytes: Integer;
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
  // ensure logical length covers needed; capacity may be larger (slack reuse)
  if LOutFrames = 0 then Exit;

  // scratch reuse: geometric growth via AudioEnsureCapacity/BytesEnsureCapacity, amortized O(1) after warmup; caller-scratch per INV-6
  LNeededIn := AInput.FrameCount * AInput.Format.Channels;
  LBytesIn := AInput.FrameCount * SizeOf(Single);
  LBytesOut := LOutFrames * SizeOf(Single);
  EnsureScratch(AScratch, LNeededIn, LBytesIn, LBytesOut, AInput.Format.Channels);
  if AInput.Format.SampleFormat = sfF32 then
    // single source: base.utils CopyMem → bytes.ops, SizeUInt guard, non-overlapping
    CopyMem(@AScratch.InF32[0], @AInput.Data[0], SizeUInt(Length(AInput.Data)))
  else
  begin
    for I := 0 to LNeededIn - 1 do
    begin
      case AInput.Format.SampleFormat of
        sfS16: PSingle(@AScratch.InF32[I])^ := PcmS16ToF32(PSmallInt(@AInput.Data[I * 2])^);
        sfS32: PSingle(@AScratch.InF32[I])^ := PcmS32ToF32(PLongInt(@AInput.Data[I * 4])^);
        sfU8:  PSingle(@AScratch.InF32[I])^ := PcmU8ToF32(AInput.Data[I]);
        sfS24: PSingle(@AScratch.InF32[I])^ := PcmS24ToF32(PcmReadS24LE(AInput.Data, I * 3));
      else
        AScratch.InF32[I] := 0;
      end;
    end;
  end;

  for LCh := 0 to AInput.Format.Channels - 1 do
    for I := 0 to AInput.FrameCount - 1 do
      PSingle(@AScratch.PlanesIn[LCh][I * SizeOf(Single)])^ := AScratch.InF32[I * AInput.Format.Channels + LCh];

  for LCh := 0 to AInput.Format.Channels - 1 do
    for LOutFrame := 0 to LOutFrames - 1 do
    begin
      LSrcPos := LOutFrame * LRatio;
      LSum := 0; LWsum := 0;
      for LTap := 0 to FTaps - 1 do
      begin
        LSrcIdx := Trunc(LSrcPos) - FTaps div 2 + LTap + 1;
        if (LSrcIdx < 0) or (LSrcIdx >= AInput.FrameCount) then Continue;
        LX := LTap - FTaps / 2 - (LSrcPos - Trunc(LSrcPos)) + 0.5;
        LW := Sinc(LX) * FKaiserTable[LTap];
        LSum := LSum + PSingle(@AScratch.PlanesIn[LCh][LSrcIdx * SizeOf(Single)])^ * LW;
        LWsum := LWsum + LW;
      end;
      if LWsum <> 0 then LSum := LSum / LWsum;
      if LSum > 1 then LSum := 1 else if LSum < -1 then LSum := -1;
      PSingle(@AScratch.PlanesOut[LCh][LOutFrame * SizeOf(Single)])^ := Single(LSum);
    end;

  for I := 0 to LOutFrames - 1 do
    for LCh := 0 to AInput.Format.Channels - 1 do
      PSingle(@Result.Data[(I * AInput.Format.Channels + LCh) * SizeOf(Single)])^ :=
        PSingle(@AScratch.PlanesOut[LCh][I * SizeOf(Single)])^;
end;

function TSincResampler.Resample(const AInput: TAudioBuffer; ANewRate: Integer): TAudioBuffer;
var
  LRatio: Double;
  LOutFrames: Integer;
  LCh, LOutFrame, LTap, LSrcIdx: Integer;
  LSrcPos, LX, LW, LSum, LWsum: Double;
  I: Integer;
  LNeededIn: Integer;
  LBytesIn, LBytesOut: Integer;
  LOutBytes: Integer;
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

  // scratch reuse: threadvar geometric growth via AudioEnsureCapacity/BytesEnsureCapacity, amortized O(1) after warmup; no global FScratch竞写
  LNeededIn := AInput.FrameCount * AInput.Format.Channels;
  LBytesIn := AInput.FrameCount * SizeOf(Single);
  LBytesOut := LOutFrames * SizeOf(Single);
  EnsureThreadScratch(LNeededIn, LBytesIn, LBytesOut, AInput.Format.Channels);
  if AInput.Format.SampleFormat = sfF32 then
    // single source: base.utils CopyMem → bytes.ops, SizeUInt guard, non-overlapping
    CopyMem(@GScratchInF32[0], @AInput.Data[0], SizeUInt(Length(AInput.Data)))
  else
  begin
    for I := 0 to LNeededIn - 1 do
    begin
      case AInput.Format.SampleFormat of
        sfS16: PSingle(@GScratchInF32[I])^ := PcmS16ToF32(PSmallInt(@AInput.Data[I * 2])^);
        sfS32: PSingle(@GScratchInF32[I])^ := PcmS32ToF32(PLongInt(@AInput.Data[I * 4])^);
        sfU8:  PSingle(@GScratchInF32[I])^ := PcmU8ToF32(AInput.Data[I]);
        sfS24: PSingle(@GScratchInF32[I])^ := PcmS24ToF32(PcmReadS24LE(AInput.Data, I * 3));
      else
        GScratchInF32[I] := 0;
      end;
    end;
  end;

  for LCh := 0 to AInput.Format.Channels - 1 do
    for I := 0 to AInput.FrameCount - 1 do
      PSingle(@GScratchPlanesIn[LCh][I * SizeOf(Single)])^ := GScratchInF32[I * AInput.Format.Channels + LCh];

  for LCh := 0 to AInput.Format.Channels - 1 do
    for LOutFrame := 0 to LOutFrames - 1 do
    begin
      LSrcPos := LOutFrame * LRatio;
      LSum := 0; LWsum := 0;
      for LTap := 0 to FTaps - 1 do
      begin
        LSrcIdx := Trunc(LSrcPos) - FTaps div 2 + LTap + 1;
        if (LSrcIdx < 0) or (LSrcIdx >= AInput.FrameCount) then Continue;
        LX := LTap - FTaps / 2 - (LSrcPos - Trunc(LSrcPos)) + 0.5;
        LW := Sinc(LX) * FKaiserTable[LTap];
        LSum := LSum + PSingle(@GScratchPlanesIn[LCh][LSrcIdx * SizeOf(Single)])^ * LW;
        LWsum := LWsum + LW;
      end;
      if LWsum <> 0 then LSum := LSum / LWsum;
      if LSum > 1 then LSum := 1 else if LSum < -1 then LSum := -1;
      PSingle(@GScratchPlanesOut[LCh][LOutFrame * SizeOf(Single)])^ := Single(LSum);
    end;

  for I := 0 to LOutFrames - 1 do
    for LCh := 0 to AInput.Format.Channels - 1 do
      PSingle(@Result.Data[(I * AInput.Format.Channels + LCh) * SizeOf(Single)])^ :=
        PSingle(@GScratchPlanesOut[LCh][I * SizeOf(Single)])^;
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
