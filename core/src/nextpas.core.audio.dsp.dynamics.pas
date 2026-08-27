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
    FAttackCoeff: Single;
    FReleaseCoeff: Single;
    FMakeup: Single;
    FEnv: Single;
    FGainSmooth: Single;
  public
    procedure Reset;
    function ProcessSample(AX: Single): Single;
    procedure ProcessBuffer(var ABuf: TAudioBuffer);
    class function Create(AThresholdDB, ARatio, AAttackMs, AReleaseMs, AMakeupDB: Single; ASampleRate: Integer): TCompressor; static;
  end;

  TCompressorProcessor = class(TInterfacedObject, IAudioProcessor)
  private
    FComp: TCompressor;
  public
    constructor Create(AThresholdDB, ARatio, AAttackMs, AReleaseMs, AMakeupDB: Single; ASampleRate, AChannels: Integer);
    function LatencyFrames: Integer;
    procedure Process(const AInput: TAudioBuffer; out AOutput: TAudioBuffer);
    procedure Reset;
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
  // One-pole smooth: coeff = exp(-1 / (timeSec*sr)) ; timeSec = ms/1000
  // Use -2.2 factor so that coeff corresponds to 10%-90% rise time (legacy compat)
  LAttack := Exp(-2200.0 / (AAttackMs * ASampleRate));
  LRelease := Exp(-2200.0 / (AReleaseMs * ASampleRate));
  Result.FThreshold := LThrLin;
  Result.FRatio := ARatio;
  Result.FAttackCoeff := Single(LAttack);
  Result.FReleaseCoeff := Single(LRelease);
  Result.FMakeup := LMakeLin;
  Result.FEnv := 0;
  Result.FGainSmooth := 1;
end;

procedure TCompressor.Reset;
begin FEnv := 0; FGainSmooth := 1; end;

function TCompressor.ProcessSample(AX: Single): Single;
var LAbs, LGain: Single;
begin
  LAbs := Abs(AX);
  if LAbs > FEnv then
    FEnv := FEnv * FAttackCoeff + (1 - FAttackCoeff) * LAbs
  else
    FEnv := FEnv * FReleaseCoeff + (1 - FReleaseCoeff) * LAbs;
  if FEnv < FThreshold then LGain := 1
  else LGain := Power(FEnv / FThreshold, (1 / FRatio) - 1);
  FGainSmooth := FGainSmooth * 0.92 + LGain * 0.08;
  Result := AX * FGainSmooth * FMakeup;
  if Result > 1 then Result := 1 else if Result < -1 then Result := -1;
end;

procedure TCompressor.ProcessBuffer(var ABuf: TAudioBuffer);
var I, N: Integer; P: PSingle;
begin
  if (ABuf.Format.SampleFormat <> sfF32) or ABuf.IsEmpty then Exit;
  N := ABuf.FrameCount * ABuf.Format.Channels;
  if Length(ABuf.Data) < N * SizeOf(Single) then Exit;
  P := PSingle(@ABuf.Data[0]);
  for I := 0 to N - 1 do P[I] := ProcessSample(P[I]);
end;

constructor TCompressorProcessor.Create(AThresholdDB, ARatio, AAttackMs, AReleaseMs, AMakeupDB: Single; ASampleRate, AChannels: Integer);
begin
  inherited Create;
  FComp := TCompressor.Create(AThresholdDB, ARatio, AAttackMs, AReleaseMs, AMakeupDB, ASampleRate);
end;

function TCompressorProcessor.LatencyFrames: Integer;
begin Result := 0; end;

procedure TCompressorProcessor.Process(const AInput: TAudioBuffer; out AOutput: TAudioBuffer);
var LCopy: Integer;
begin
  AOutput.Format := AInput.Format; AOutput.FrameCount := AInput.FrameCount;
  LCopy := Length(AInput.Data); SetLength(AOutput.Data, LCopy);
  if LCopy > 0 then Move(AInput.Data[0], AOutput.Data[0], LCopy);
  FComp.ProcessBuffer(AOutput);
end;

procedure TCompressorProcessor.Reset;
begin FComp.Reset; end;

end.
