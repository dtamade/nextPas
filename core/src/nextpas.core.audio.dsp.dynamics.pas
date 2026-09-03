unit nextpas.core.audio.dsp.dynamics;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf;

type
  TCompressor = record
  private
    FThreshold: Single;
    FRatio: Single;
    FGainExp: Single; // (1/Ratio -1) precomputed
    FAttackCoeff: Single;
    FReleaseCoeff: Single;
    FMakeup: Single;
    FEnv: Single;
    FGainSmooth: Single;
    function GainForEnv(AEnv: Single): Single; inline;
  public
    procedure Reset; inline;
    function ProcessSample(AX: Single): Single; inline;
    procedure ProcessBuffer(var ABuf: TAudioBuffer);
    class function Create(AThresholdDB, ARatio, AAttackMs, AReleaseMs, AMakeupDB: Single; ASampleRate: Integer): TCompressor; static;
  end;

  TCompressorProcessor = class(TInterfacedObject, IAudioProcessor)
  private
    FComp: TCompressor;
    procedure EnsureScratch(var ADest: TBytes; ARequired: SizeUInt); inline;
  public
    constructor Create(AThresholdDB, ARatio, AAttackMs, AReleaseMs, AMakeupDB: Single; ASampleRate, AChannels: Integer);
    function LatencyFrames: Integer; inline;
    procedure Process(const AInput: TAudioBuffer; out AOutput: TAudioBuffer);
    procedure Reset; inline;
  end;

  TLimiter = TCompressor;

implementation

uses
  nextpas.core.bytes.ops, // single source for BytesCopy inline zero-copy, no base.utils dual source
  nextpas.core.math.trig;

const
  C_GAIN_LUT_BITS = 9;
  C_GAIN_LUT_SIZE = 1 shl C_GAIN_LUT_BITS; // 512

var
  GLog2Table: array[0..511] of Single;
  GExp2Table: array[0..511] of Single;
  GGainLUTInit: Boolean;

procedure InitGainLUT;
var
  I: Integer;
  F: Double;
begin
  if GGainLUTInit then Exit;
  for I := 0 to C_GAIN_LUT_SIZE - 1 do
  begin
    F := I / C_GAIN_LUT_SIZE;
    GLog2Table[I] := Single(System.Ln(1.0 + F) / 0.69314718055994530942);
    GExp2Table[I] := Single(System.Exp(F * 0.69314718055994530942));
  end;
  GGainLUTInit := True;
end;

function FastLog2Approx(const X: Single): Single; inline;
var
  U: UInt32;
  E: Int32;
  Mbits: UInt32;
  Idx: UInt32;
  Frac: Single;
  V0, V1: Single;
begin
  Move(X, U, SizeOf(U));
  E := Int32((U shr 23) and 255) - 127;
  Mbits := U and UInt32($007FFFFF);
  Idx := Mbits shr 14;
  Frac := Single(Mbits and UInt32($3FFF)) / 16384.0;
  V0 := GLog2Table[Idx];
  if Idx = 511 then V1 := 1.0 else V1 := GLog2Table[Idx + 1];
  Result := Single(E) + V0 + Frac * (V1 - V0);
end;

function FastExp2Approx(const X: Single): Single; inline;
var
  I: Int32;
  F: Single;
  Idx: UInt32;
  Frac: Single;
  V0, V1, Pow2Int: Single;
  U: UInt32;
begin
  I := Trunc(X);
  if Single(I) > X then Dec(I);
  F := X - Single(I);
  if I < -126 then Exit(0.0);
  if I > 127 then Exit(1.0e30);
  Idx := UInt32(Trunc(F * 512.0));
  if Idx > 511 then Idx := 511;
  Frac := F * 512.0 - Single(Idx);
  V0 := GExp2Table[Idx];
  if Idx = 511 then V1 := 2.0 else V1 := GExp2Table[Idx + 1];
  V0 := V0 + Frac * (V1 - V0);
  U := UInt32((I + 127) shl 23);
  Move(U, Pow2Int, SizeOf(Pow2Int));
  Result := Pow2Int * V0;
end;

function FastGainApprox(const ARatioLin, AExp: Single): Single; inline;
var
  LLog2: Single;
begin
  if (ARatioLin <= 0) or (AExp = 0) then Exit(1.0);
  LLog2 := FastLog2Approx(ARatioLin);
  Result := FastExp2Approx(AExp * LLog2);
  if Result > 1.0 then Result := 1.0 else if Result < 0 then Result := 0;
end;

procedure TCompressorProcessor.EnsureScratch(var ADest: TBytes; ARequired: SizeUInt); inline;
begin
  // perf: inline geometric doubling via bytes.ops single source, steady zero alloc per INV-6
  if SizeUInt(Length(ADest)) >= ARequired then Exit;
  BytesEnsureCapacity(ADest, ARequired);
end;


class function TCompressor.Create(AThresholdDB, ARatio, AAttackMs, AReleaseMs, AMakeupDB: Single; ASampleRate: Integer): TCompressor;
var
  LThrLin, LMakeLin: Single;
  LAttack, LRelease: Double;
begin
  if ARatio < 1 then ARatio := 1;
  if ASampleRate <= 0 then ASampleRate := 48000;
  if AAttackMs < 0.1 then AAttackMs := 0.1;
  if AReleaseMs < 1 then AReleaseMs := 1;
  LThrLin := Power(10, AThresholdDB / 20);
  LMakeLin := Power(10, AMakeupDB / 20);
  LAttack := Exp(-2200.0 / (AAttackMs * ASampleRate));
  LRelease := Exp(-2200.0 / (AReleaseMs * ASampleRate));
  Result.FThreshold := LThrLin;
  Result.FRatio := ARatio;
  if ARatio = 1 then Result.FGainExp := 0
  else Result.FGainExp := Single((1.0 / ARatio) - 1.0);
  Result.FAttackCoeff := Single(LAttack);
  Result.FReleaseCoeff := Single(LRelease);
  Result.FMakeup := LMakeLin;
  Result.FEnv := 0;
  Result.FGainSmooth := 1;
end;

procedure TCompressor.Reset; inline;
begin FEnv := 0; FGainSmooth := 1; end;

function TCompressor.GainForEnv(AEnv: Single): Single; inline;
var
  LRatio: Single;
begin
  if AEnv < FThreshold then Exit(1.0);
  if FGainExp = 0 then Exit(1.0);
  if FThreshold <= 0 then Exit(1.0);
  LRatio := AEnv / FThreshold;
  // perf: LUT lerp FastGainApprox, inline, zero alloc, no Exp/Ln per sample
  if LRatio <= 0 then Exit(1.0);
  Result := FastGainApprox(LRatio, FGainExp);
end;

function TCompressor.ProcessSample(AX: Single): Single; inline;
var LAbs, LGain: Single;
begin
  LAbs := AX; if LAbs < 0 then LAbs := -LAbs;
  if LAbs > FEnv then
    FEnv := FEnv * FAttackCoeff + (1 - FAttackCoeff) * LAbs
  else
    FEnv := FEnv * FReleaseCoeff + (1 - FReleaseCoeff) * LAbs;
  LGain := GainForEnv(FEnv);
  FGainSmooth := FGainSmooth * 0.92 + LGain * 0.08;
  Result := AX * FGainSmooth * FMakeup;
  if Result > 1 then Result := 1 else if Result < -1 then Result := -1;
end;

procedure TCompressor.ProcessBuffer(var ABuf: TAudioBuffer);
var
  I, N: Integer;
  P: PSingle;
  LThr, LRatio, LExp, LAtk, LRel, LMake, LEnv, LSmooth: Single;
  LOneMinusAtk, LOneMinusRel: Single;
  LAbs, LGain, LOut: Single;
  LRatioLin: Single;
begin
  if (ABuf.Format.SampleFormat <> sfF32) or ABuf.IsEmpty then Exit;
  N := ABuf.FrameCount * ABuf.Format.Channels;
  if Length(ABuf.Data) < N * SizeOf(Single) then Exit;
  P := PSingle(@ABuf.Data[0]);
  // Hoist fields into registers - zero extra alloc, no per-sample field access.
  LThr := FThreshold; LRatio := FRatio; LExp := FGainExp;
  LAtk := FAttackCoeff; LRel := FReleaseCoeff; LMake := FMakeup;
  LEnv := FEnv; LSmooth := FGainSmooth;
  LOneMinusAtk := 1 - LAtk; LOneMinusRel := 1 - LRel;
  // Envelope has cross-sample dependency -> scalar by design. SIMD dispatch
  // not applicable here (sequential IIR). We keep tight scalar loop with
  // inline gain and branchless clamp.
  for I := 0 to N - 1 do
  begin
    LAbs := P[I]; if LAbs < 0 then LAbs := -LAbs;
    if LAbs > LEnv then
      LEnv := LEnv * LAtk + LOneMinusAtk * LAbs
    else
      LEnv := LEnv * LRel + LOneMinusRel * LAbs;
    if (LEnv < LThr) or (LExp = 0) then LGain := 1
    else
    begin
      LRatioLin := LEnv / LThr;
      // perf: FastGainApprox LUT lerp, inline, zero alloc, no Exp/Ln per sample
      if LRatioLin <= 0 then LGain := 1
      else LGain := FastGainApprox(LRatioLin, LExp);
    end;
    LSmooth := LSmooth * 0.92 + LGain * 0.08;
    LOut := P[I] * LSmooth * LMake;
    if LOut > 1 then LOut := 1 else if LOut < -1 then LOut := -1;
    P[I] := LOut;
  end;
  FEnv := LEnv; FGainSmooth := LSmooth;
end;

constructor TCompressorProcessor.Create(AThresholdDB, ARatio, AAttackMs, AReleaseMs, AMakeupDB: Single; ASampleRate, AChannels: Integer);
begin
  inherited Create;
  FComp := TCompressor.Create(AThresholdDB, ARatio, AAttackMs, AReleaseMs, AMakeupDB, ASampleRate);
end;

function TCompressorProcessor.LatencyFrames: Integer; inline;
begin Result := 0; end;

procedure TCompressorProcessor.Process(const AInput: TAudioBuffer; out AOutput: TAudioBuffer);
var LCopy: Integer;
begin
  AOutput.Format := AInput.Format; AOutput.FrameCount := AInput.FrameCount;
  LCopy := Length(AInput.Data);
  // INV-6 steady zero heap growth: geometric prealloc via EnsureScratch/BytesEnsureCapacity single source, single BytesCopy non-overlapping SizeUInt guard
  EnsureScratch(AOutput.Data, SizeUInt(LCopy));
  if LCopy > 0 then
    // single source: bytes.ops BytesCopy inline zero-copy, SizeUInt(LCopy) guard, non-overlapping
    BytesCopy(@AOutput.Data[0], @AInput.Data[0], SizeUInt(LCopy));
  FComp.ProcessBuffer(AOutput);
end;

procedure TCompressorProcessor.Reset; inline;
begin FComp.Reset; end;

initialization
  InitGainLUT;

end.
