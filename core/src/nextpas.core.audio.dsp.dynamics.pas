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
  public
    constructor Create(AThresholdDB, ARatio, AAttackMs, AReleaseMs, AMakeupDB: Single; ASampleRate, AChannels: Integer);
    function LatencyFrames: Integer; inline;
    procedure Process(const AInput: TAudioBuffer; out AOutput: TAudioBuffer);
    procedure Reset; inline;
  end;

  TLimiter = TCompressor;

implementation

uses Math;

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
  // Power(LRatio, FGainExp) - use Exp(Ln) directly; FGainExp negative so no overflow.
  // Cold path still uses Math.Power but with hoisted exponent; hot path stays inline.
  if LRatio <= 0 then Exit(1.0);
  Result := Single(Exp(FGainExp * Ln(LRatio)));
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
      if LRatioLin <= 0 then LGain := 1
      else LGain := Single(Exp(LExp * Ln(LRatioLin)));
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
  LCopy := Length(AInput.Data); SetLength(AOutput.Data, LCopy);
  if LCopy > 0 then Move(AInput.Data[0], AOutput.Data[0], LCopy);
  FComp.ProcessBuffer(AOutput);
end;

procedure TCompressorProcessor.Reset; inline;
begin FComp.Reset; end;

end.
