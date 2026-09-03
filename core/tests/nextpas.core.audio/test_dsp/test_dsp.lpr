program test_dsp;
{$mode objfpc}{$H+}
uses
  nextpas.core.math,
  nextpas.core.exception,
  nextpas.core.base, nextpas.core.test, nextpas.core.audio.base,
  nextpas.core.audio.dsp.filters,
  nextpas.core.audio.dsp.dynamics,
  nextpas.core.audio.dsp.fft,
  nextpas.core.audio;

type T = class
  procedure TestBiquad_LowPass_DCBypass;
  procedure TestBiquad_HighPass_DCAttenuate;
  procedure TestBiquad_Processor_Stereo;
  procedure TestBiquad_Reset;
  procedure TestBiquad_AllTypes_NotNaN;
  procedure TestCompressor_ReducePeak;
  procedure TestCompressor_Limiter;
  procedure TestCompressor_Reset;
  procedure TestFFT_Impulse;
  procedure TestFFT_IFFT_RoundTrip;
  procedure TestFFT_Sine_Mag;
  procedure TestWindowHann;
  procedure TestIsPowerOfTwo;
  procedure TestFFT_NotPowerOfTwo_Throws;
end;

function MakeF32(ARate,ACh,AFrames: Integer): TAudioBuffer;
begin
  Result.Format:=AudioFormatCreate(ARate,ACh,sfF32); Result.FrameCount:=AFrames;
  SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
end;

procedure T.TestBiquad_LowPass_DCBypass;
var Q: TBiquad; X,Y: Single; I: Integer;
begin
  Q:=TBiquad.Design(bqLowPass, 48000, 1000, 0.707, 0);
  Q.Reset; Y:=0;
  for I:=0 to 200 do Y:=Q.Process(1.0);
  CheckNear(1.0, Y, 0.05, 'lowpass DC ~1');
end;

procedure T.TestBiquad_HighPass_DCAttenuate;
var Q: TBiquad; Y: Single; I: Integer;
begin
  Q:=TBiquad.Design(bqHighPass, 48000, 1000, 0.707, 0);
  Q.Reset; Y:=0;
  for I:=0 to 500 do Y:=Q.Process(1.0);
  CheckTrue(Abs(Y)<0.1, 'highpass DC attenuated');
end;

procedure T.TestBiquad_Processor_Stereo;
var P: IAudioProcessor; InB, OutB: TAudioBuffer; I: Integer; PS: PSingle;
begin
  InB:=MakeF32(48000,2,64);
  PS:=PSingle(@InB.Data[0]); for I:=0 to 127 do PS[I]:=0.5;
  P:=TBiquadProcessor.Create(bqLowPass, 48000, 2000, 0.707, 0, 2);
  P.Process(InB, OutB);
  CheckEqual(64, OutB.FrameCount, 'processor frames');
  CheckEqual(2, OutB.Format.Channels, 'processor ch');
  CheckEqual(0, P.LatencyFrames, 'latency 0');
end;

procedure T.TestBiquad_Reset;
var Q: TBiquad;
begin
  Q:=TBiquad.Design(bqLowPass, 48000, 500, 0.707, 0);
  Q.Process(1.0); Q.Process(1.0); Q.Reset;
  CheckNear(0, Q.Z1, 1e-6, 'Z1 0 after reset'); CheckNear(0, Q.Z2, 1e-6, 'Z2 0');
end;

procedure T.TestBiquad_AllTypes_NotNaN;
var Tp: TBiquadType; Q: TBiquad; Y: Single;
begin
  for Tp:=Low(TBiquadType) to High(TBiquadType) do
  begin
    Q:=TBiquad.Design(Tp, 48000, 1000, 1.0, 6.0); Q.Reset;
    Y:=Q.Process(0.5);
    CheckTrue((not IsNan(Y)) and (not IsInfinite(Y)), 'type not nan');
  end;
end;

procedure T.TestCompressor_ReducePeak;
var C: TCompressor; InB: TAudioBuffer; P: PSingle; I: Integer; PeakBefore, PeakAfter: Single;
begin
  C:=TCompressor.Create(-20, 4, 10, 100, 0, 48000);
  InB:=MakeF32(48000,1,1000);
  P:=PSingle(@InB.Data[0]); for I:=0 to 999 do P[I]:=Sin(2*Pi*100*I/48000);
  // drive loud: scale to 1
  PeakBefore:=0; for I:=0 to 999 do if Abs(P[I])>PeakBefore then PeakBefore:=Abs(P[I]);
  C.ProcessBuffer(InB);
  PeakAfter:=0; for I:=0 to 999 do if Abs(P[I])>PeakAfter then PeakAfter:=Abs(P[I]);
  CheckTrue(PeakAfter<=PeakBefore+1e-6, 'compressor reduces or keeps');
end;

procedure T.TestCompressor_Limiter;
var Prc: IAudioProcessor; InB, OutB: TAudioBuffer; PS: PSingle; I: Integer;
begin
  InB:=MakeF32(48000,1,256); PS:=PSingle(@InB.Data[0]); for I:=0 to 255 do PS[I]:=1.5;
  Prc:=TCompressorProcessor.Create(-6, 20, 1, 50, 0, 48000, 1);
  Prc.Process(InB, OutB);
  PS:=PSingle(@OutB.Data[0]);
  CheckTrue(PS[255]<=1.01, 'limiter clamp <=1');
end;

procedure T.TestCompressor_Reset;
var C: TCompressor; InB: TAudioBuffer; P: PSingle;
begin
  C:=TCompressor.Create(-10,2,5,50,0,48000);
  InB:=MakeF32(48000,1,4); P:=PSingle(@InB.Data[0]); P[0]:=1; P[1]:=1; P[2]:=1; P[3]:=1;
  C.ProcessBuffer(InB);
  C.Reset;
  // after reset, processing silence should not raise
  InB:=MakeF32(48000,1,4);
  C.ProcessBuffer(InB);
  CheckTrue(True,'reset ok');
end;

procedure T.TestFFT_Impulse;
var Re,Im: array of Single; I,N: Integer;
begin
  N:=8; SetLength(Re,N); SetLength(Im,N);
  Re[0]:=1; for I:=1 to 7 do Re[I]:=0; for I:=0 to 7 do Im[I]:=0;
  FFT(Re,Im);
  for I:=0 to 7 do CheckNear(1.0, Re[I], 1e-4, 'impulse FFT Re=1');
end;

procedure T.TestFFT_IFFT_RoundTrip;
var Re,Im,Re2,Im2: array of Single; I,N: Integer;
begin
  N:=16; SetLength(Re,N); SetLength(Im,N);
  for I:=0 to N-1 do begin Re[I]:=Sin(2*Pi*I/N); Im[I]:=0; end;
  SetLength(Re2,N); SetLength(Im2,N); for I:=0 to N-1 do begin Re2[I]:=Re[I]; Im2[I]:=Im[I]; end;
  FFT(Re2,Im2); IFFT(Re2,Im2);
  for I:=0 to N-1 do CheckNear(Re[I], Re2[I], 1e-3, 'IFFT roundtrip');
end;

procedure T.TestFFT_Sine_Mag;
var Re,Im: TSingleArray; InS: array of Single; N,I: Integer; Mag: Double;
begin
  N:=64; SetLength(InS,N);
  for I:=0 to N-1 do InS[I]:=Sin(2*Pi*4*I/N);
  FFTReal(InS, Re, Im);
  Mag:=Sqrt(Re[4]*Re[4]+Im[4]*Im[4]);
  CheckTrue(Mag>10,'sine bin mag >10');
end;

procedure T.TestWindowHann;
begin
  CheckNear(0, WindowHann(64,0),1e-6,'hann 0 =0');
  CheckNear(1.0, WindowHann(64,32),0.02,'hann middle ~1');
  CheckNear(0, WindowHann(64,63),1e-6,'hann end 0');
  CheckNear(1.0, WindowHann(1,0),1e-6,'hann N=1');
end;

procedure T.TestIsPowerOfTwo;
begin
  CheckTrue(IsPowerOfTwo(1),'1 pow2'); CheckTrue(IsPowerOfTwo(64),'64 pow2');
  CheckFalse(IsPowerOfTwo(0),'0 not'); CheckFalse(IsPowerOfTwo(3),'3 not');
end;

procedure T.TestFFT_NotPowerOfTwo_Throws;
var Re,Im: array of Single; OK: Boolean;
begin
  SetLength(Re,3); SetLength(Im,3);
  OK:=False; try FFT(Re,Im); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'FFT 3 throws');
end;

var S:TTestSuite; C:T;
begin
  C:=T.Create; S:=TTestSuite.Create('nextpas.core.audio.dsp');
  S.Test('biquad lowpass DC bypass', @C.TestBiquad_LowPass_DCBypass);
  S.Test('biquad highpass DC attenuate', @C.TestBiquad_HighPass_DCAttenuate);
  S.Test('biquad processor stereo', @C.TestBiquad_Processor_Stereo);
  S.Test('biquad reset', @C.TestBiquad_Reset);
  S.Test('biquad all types not nan', @C.TestBiquad_AllTypes_NotNaN);
  S.Test('compressor reduce peak', @C.TestCompressor_ReducePeak);
  S.Test('compressor limiter clamp', @C.TestCompressor_Limiter);
  S.Test('compressor reset', @C.TestCompressor_Reset);
  S.Test('FFT impulse', @C.TestFFT_Impulse);
  S.Test('FFT IFFT roundtrip', @C.TestFFT_IFFT_RoundTrip);
  S.Test('FFT sine mag', @C.TestFFT_Sine_Mag);
  S.Test('WindowHann', @C.TestWindowHann);
  S.Test('IsPowerOfTwo', @C.TestIsPowerOfTwo);
  S.Test('FFT not power of two throws', @C.TestFFT_NotPowerOfTwo_Throws);
  C.Free;
  if not S.Run then Halt(1);
end.
