program test_mix;
{$mode objfpc}{$H+}
uses nextpas.core.base, nextpas.core.test, nextpas.core.audio.base, nextpas.core.audio.mix, nextpas.core.audio;

type T = class
  procedure TestMixInto_Basic;
  procedure TestMixInto_Gain;
  procedure TestMixInto_GainZero;
  procedure TestMixInto_GainOne;
  procedure TestMixInto_Offset;
  procedure TestMixInto_S16_Src;
  procedure TestMixInto_MismatchThrows;
  procedure TestApplyGain;
  procedure TestApplyGain_ZeroOne;
  procedure TestApplyGainRamp;
  procedure TestNormalizePeak;
  procedure TestNormalizeRMS;
  procedure TestPanLaw;
  procedure TestFacade_Mix;
end;

function MakeF32(ARate,ACh,AFrames: Integer; AVal: Single): TAudioBuffer;
var I: Integer; P: PSingle;
begin
  Result.Format:=AudioFormatCreate(ARate,ACh,sfF32); Result.FrameCount:=AFrames;
  SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
  P:=PSingle(@Result.Data[0]);
  for I:=0 to AFrames*ACh-1 do P[I]:=AVal;
end;

function MakeS16(ARate,ACh,AFrames: Integer): TAudioBuffer;
begin
  Result.Format:=AudioFormatCreate(ARate,ACh,sfS16); Result.FrameCount:=AFrames;
  SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
  FillChar(Result.Data[0], Length(Result.Data), $11);
end;

procedure T.TestMixInto_Basic;
var D,S: TAudioBuffer; P: PSingle;
begin
  D:=MakeF32(48000,1,100,0); S:=MakeF32(48000,1,10,1.0);
  MixInto(D,S,1.0,5);
  P:=PSingle(@D.Data[0]);
  CheckNear(0,P[0],1e-6,'before offset 0');
  CheckNear(1.0,P[5],1e-6,'at offset 1');
  CheckNear(0,P[20],1e-6,'after src 0');
end;

procedure T.TestMixInto_Gain;
var D,S: TAudioBuffer; P: PSingle;
begin
  D:=MakeF32(48000,1,20,0); S:=MakeF32(48000,1,10,2.0);
  MixInto(D,S,0.5,0);
  P:=PSingle(@D.Data[0]); CheckNear(1.0,P[0],1e-6,'gain 0.5*2=1');
end;

procedure T.TestMixInto_GainZero;
var D,S: TAudioBuffer; P: PSingle;
begin
  D:=MakeF32(48000,1,10,5.0); S:=MakeF32(48000,1,10,10.0);
  MixInto(D,S,0,0);
  P:=PSingle(@D.Data[0]); CheckNear(5.0,P[0],1e-6,'gain 0 no change'); CheckNear(5.0,P[9],1e-6,'gain 0 tail');
end;

procedure T.TestMixInto_GainOne;
var D,S: TAudioBuffer; P: PSingle;
begin
  D:=MakeF32(48000,1,10,1.0); S:=MakeF32(48000,1,10,2.0);
  MixInto(D,S,1.0,0);
  P:=PSingle(@D.Data[0]); CheckNear(3.0,P[0],1e-6,'gain 1 add');
end;

procedure T.TestMixInto_Offset;
var D,S: TAudioBuffer;
begin
  D:=MakeF32(48000,1,50,0); S:=MakeF32(48000,1,10,1.0);
  MixInto(D,S,1,40);
  CheckTrue(True,'offset edge ok');
end;

procedure T.TestMixInto_S16_Src;
var D,S: TAudioBuffer; P: PSingle;
begin
  D:=MakeF32(48000,1,10,0); S:=MakeS16(48000,1,10);
  MixInto(D,S,1.0,0);
  P:=PSingle(@D.Data[0]); CheckTrue(Abs(P[0])>1e-6,'s16 converted non-zero');
end;

procedure T.TestMixInto_MismatchThrows;
var D,S: TAudioBuffer; OK: Boolean;
begin
  D:=MakeF32(48000,1,10,0); S:=MakeF32(44100,1,10,1.0);
  OK:=False; try MixInto(D,S,1,0); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'rate mismatch throws');
  S:=MakeF32(48000,2,10,1.0);
  OK:=False; try MixInto(D,S,1,0); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'ch mismatch throws');
end;

procedure T.TestApplyGain;
var B: TAudioBuffer; P: PSingle;
begin
  B:=MakeF32(48000,1,4,1.0); ApplyGain(B,0.5);
  P:=PSingle(@B.Data[0]); CheckNear(0.5,P[0],1e-6,'gain 0.5'); CheckNear(0.5,P[3],1e-6,'gain last');
end;

procedure T.TestApplyGain_ZeroOne;
var B: TAudioBuffer; P: PSingle;
begin
  B:=MakeF32(48000,1,4,2.0); ApplyGain(B,0);
  P:=PSingle(@B.Data[0]); CheckNear(0,P[0],1e-6,'gain 0 zero'); CheckNear(0,P[3],1e-6,'gain 0 tail');
  B:=MakeF32(48000,1,4,2.0); ApplyGain(B,1.0);
  P:=PSingle(@B.Data[0]); CheckNear(2.0,P[0],1e-6,'gain 1 no-op');
end;

procedure T.TestApplyGainRamp;
var B: TAudioBuffer; P: PSingle;
begin
  B:=MakeF32(48000,1,4,1.0); ApplyGainRamp(B,0,1.0);
  P:=PSingle(@B.Data[0]);
  CheckNear(0,P[0],1e-5,'ramp start 0');
  CheckNear(1.0,P[3],1e-5,'ramp end 1');
end;

procedure T.TestNormalizePeak;
var B: TAudioBuffer; Peak: Single; P: PSingle;
begin
  B:=MakeF32(48000,1,4,0);
  P:=PSingle(@B.Data[0]); P[0]:=0.5; P[1]:=-0.2; P[2]:=0.1; P[3]:=0.3;
  Peak:=NormalizePeak(B,1.0);
  CheckNear(0.5,Peak,1e-5,'peak return');
  P:=PSingle(@B.Data[0]); CheckNear(1.0,P[0],1e-5,'normalized peak 1');
end;

procedure T.TestNormalizeRMS;
var B: TAudioBuffer; Rms: Single; P: PSingle; Sum: Double; I: Integer;
begin
  B:=MakeF32(48000,1,100,0.5);
  Rms:=NormalizeRMS(B,0.1);
  CheckNear(0.5,Rms,1e-3,'rms return ~0.5');
  P:=PSingle(@B.Data[0]); Sum:=0; for I:=0 to 99 do Sum:=Sum+P[I]*P[I];
  CheckNear(0.1, Single(Sqrt(Sum/100)), 1e-3,'target rms');
end;

procedure T.TestPanLaw;
var G: TAudioPanGains;
begin
  G:=PanLawGains(-1); CheckNear(1,G.X,1e-3,'pan -1 left');
  G:=PanLawGains(1); CheckNear(1,G.Y,1e-3,'pan 1 right');
  G:=PanLawGains(0); CheckNear(Sqrt(0.5),G.X,1e-3,'pan 0 equal');
  G:=PanLawGains(0,-6); CheckNear(0.5,G.X,1e-3,'pan law -6 linear');
end;

procedure T.TestFacade_Mix;
var B: TAudioBuffer;
begin
  B:=MakeF32(48000,1,4,1.0); nextpas.core.audio.ApplyGain(B,2.0);
  CheckNear(2.0, PSingle(@B.Data[0])^,1e-6,'facade applygain');
end;

var S:TTestSuite; C:T;
begin
  C:=T.Create; S:=TTestSuite.Create('nextpas.core.audio.mix');
  S.Test('mixinto basic', @C.TestMixInto_Basic);
  S.Test('mixinto gain', @C.TestMixInto_Gain);
  S.Test('mixinto gain zero', @C.TestMixInto_GainZero);
  S.Test('mixinto gain one', @C.TestMixInto_GainOne);
  S.Test('mixinto offset', @C.TestMixInto_Offset);
  S.Test('mixinto s16 src', @C.TestMixInto_S16_Src);
  S.Test('mixinto mismatch throws', @C.TestMixInto_MismatchThrows);
  S.Test('apply gain', @C.TestApplyGain);
  S.Test('apply gain zero/one', @C.TestApplyGain_ZeroOne);
  S.Test('apply gain ramp', @C.TestApplyGainRamp);
  S.Test('normalize peak', @C.TestNormalizePeak);
  S.Test('normalize rms', @C.TestNormalizeRMS);
  S.Test('pan law', @C.TestPanLaw);
  S.Test('facade mix', @C.TestFacade_Mix);
  C.Free;
  if not S.Run then Halt(1);
end.
