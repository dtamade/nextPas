program test_resample;
{$mode objfpc}{$H+}
uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.resample,
  nextpas.core.audio.resample.sinc,
  nextpas.core.audio;

type T = class
  procedure TestLinear_Upsample_2x;
  procedure TestLinear_Downsample_Half;
  procedure TestLinear_441to48;
  procedure TestLinear_Stereo;
  procedure TestLinear_S16_Input;
  procedure TestLinear_Empty;
  procedure TestLinear_SameRate;
  procedure TestLinear_InvalidRate_Throws;
  procedure TestLinear_RoundTrip_NearIdentity;
  procedure TestSinc_Draft_vs_Best_Quality;
  procedure TestSinc_Empty;
  procedure TestSinc_InvalidRate_Throws;
  procedure TestCreateResampler_Interfaces;
  procedure TestLatency;
end;

function MakeSine(AType: TAudioSampleFormat; ARate, ACh, AFrames: Integer): TAudioBuffer;
var I, Ch: Integer; V: Single; P: PSingle;
begin
  Result.Format:=AudioFormatCreate(ARate, ACh, AType);
  Result.FrameCount:=AFrames;
  SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
  if AType=sfF32 then
  begin
    P:=PSingle(@Result.Data[0]);
    for I:=0 to AFrames-1 do
      for Ch:=0 to ACh-1 do
      begin
        V:=Sin(2*Pi*440*I/ARate);
        P[I*ACh+Ch]:=V*0.5;
      end;
  end else
    FillChar(Result.Data[0], Length(Result.Data), 0);
end;

function MakeS16Ramp(ARate, ACh, AFrames: Integer): TAudioBuffer;
var I: Integer; P: PSmallInt;
begin
  Result.Format:=AudioFormatCreate(ARate, ACh, sfS16);
  Result.FrameCount:=AFrames;
  SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
  P:=PSmallInt(@Result.Data[0]);
  for I:=0 to AFrames*ACh-1 do P[I]:=SmallInt(I*100);
end;

procedure T.TestLinear_Upsample_2x;
var B, O: TAudioBuffer;
begin
  B:=MakeSine(sfF32, 8000, 1, 80);
  O:=AudioResampleLinear(B, 16000);
  CheckEqual(160, O.FrameCount, 'upsample 2x frames');
  CheckEqual(16000, O.Format.SampleRate, 'upsample rate');
  CheckEqual(1, O.Format.Channels, 'ch');
  CheckTrue(O.Format.SampleFormat=sfF32, 'out sfF32');
end;

procedure T.TestLinear_Downsample_Half;
var B, O: TAudioBuffer;
begin
  B:=MakeSine(sfF32, 48000, 2, 480);
  O:=AudioResampleLinear(B, 24000);
  CheckEqual(240, O.FrameCount, 'down half');
  CheckEqual(24000, O.Format.SampleRate, 'down rate');
end;

procedure T.TestLinear_441to48;
var B, O: TAudioBuffer; Expected: Integer;
begin
  B:=MakeSine(sfF32, 44100, 1, 44100);
  O:=AudioResampleLinear(B, 48000);
  Expected:=Round(44100*48000/44100);
  CheckEqual(Expected, O.FrameCount, '441->48 frames');
end;

procedure T.TestLinear_Stereo;
var B, O: TAudioBuffer;
begin
  B:=MakeSine(sfF32, 8000, 2, 100);
  O:=AudioResampleLinear(B, 16000);
  CheckEqual(2, O.Format.Channels, 'stereo ch');
  CheckEqual(200, O.FrameCount, 'stereo frames');
end;

procedure T.TestLinear_S16_Input;
var B, O: TAudioBuffer;
begin
  B:=MakeS16Ramp(8000,1,100);
  O:=AudioResampleLinear(B, 16000);
  CheckEqual(200, O.FrameCount, 's16 upsample');
  CheckTrue(O.Format.SampleFormat=sfF32, 's16->f32');
end;

procedure T.TestLinear_Empty;
var B, O: TAudioBuffer;
begin
  B.Format:=AudioFormatCreate(44100,1,sfF32); B.FrameCount:=0; SetLength(B.Data,0);
  O:=AudioResampleLinear(B, 48000);
  CheckEqual(0, O.FrameCount, 'empty out 0');
  CheckEqual(48000, O.Format.SampleRate, 'empty rate');
end;

procedure T.TestLinear_SameRate;
var B, O: TAudioBuffer; I: Integer; P1, P2: PSingle;
begin
  B:=MakeSine(sfF32, 48000, 1, 100);
  O:=AudioResampleLinear(B, 48000);
  CheckEqual(100, O.FrameCount, 'same rate frames');
  P1:=PSingle(@B.Data[0]); P2:=PSingle(@O.Data[0]);
  for I:=0 to 99 do CheckNear(P1[I], P2[I], 1e-5, 'same rate sample');
end;

procedure T.TestLinear_InvalidRate_Throws;
var B: TAudioBuffer; OK: Boolean;
begin
  B:=MakeSine(sfF32, 48000,1,10);
  OK:=False; try AudioResampleLinear(B, 0); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'0 rate throws');
  OK:=False; try AudioResampleLinear(B, 300000); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'300k throws');
end;

procedure T.TestLinear_RoundTrip_NearIdentity;
var B, Up, Down: TAudioBuffer; I: Integer; P1,P2: PSingle; Err: Double;
begin
  B:=MakeSine(sfF32, 8000,1,80);
  Up:=AudioResampleLinear(B, 16000);
  Down:=AudioResampleLinear(Up, 8000);
  CheckEqual(80, Down.FrameCount, 'roundtrip frames');
  P1:=PSingle(@B.Data[0]); P2:=PSingle(@Down.Data[0]);
  Err:=0; for I:=0 to 79 do Err:=Err+Abs(P1[I]-P2[I]);
  CheckTrue(Err<5,'roundtrip err <5');
end;

procedure T.TestSinc_Draft_vs_Best_Quality;
var B, D, G, Bx: TAudioBuffer; R: IAudioResampler;
begin
  B:=MakeSine(sfF32, 8000,1,80);
  R:=CreateSincResampler(rsDraft); D:=R.Resample(B,16000);
  CheckEqual(160, D.FrameCount,'sinc draft frames');
  R:=CreateSincResampler(rsGood); G:=R.Resample(B,16000);
  CheckEqual(160, G.FrameCount,'sinc good frames');
  R:=CreateSincResampler(rsBest); Bx:=R.Resample(B,16000);
  CheckEqual(160, Bx.FrameCount,'sinc best frames');
  CheckEqual(64, (R as TSincResampler).LatencyFrames, 'best latency 64');
end;

procedure T.TestSinc_Empty;
var B, O: TAudioBuffer; R: IAudioResampler;
begin
  B.Format:=AudioFormatCreate(48000,2,sfF32); B.FrameCount:=0; SetLength(B.Data,0);
  R:=CreateSincResampler(rsGood); O:=R.Resample(B,44100);
  CheckEqual(0,O.FrameCount,'sinc empty');
end;

procedure T.TestSinc_InvalidRate_Throws;
var B: TAudioBuffer; R: IAudioResampler; OK: Boolean;
begin
  B:=MakeSine(sfF32,48000,1,10); R:=CreateSincResampler(rsGood);
  OK:=False; try R.Resample(B,1); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'sinc 1 throws');
end;

procedure T.TestCreateResampler_Interfaces;
var R1,R2: IAudioResampler;
begin
  R1:=CreateLinearResampler; CheckTrue(Assigned(R1),'linear assigned');
  R2:=CreateSincResampler(rsGood); CheckTrue(Assigned(R2),'sinc assigned');
  CheckTrue(R1.Resample(MakeSine(sfF32,8000,1,10),16000).FrameCount=20,'linear via intf');
end;

procedure T.TestLatency;
var R: TSincResampler;
begin
  R:=TSincResampler.Create(rsDraft); try CheckEqual(8,R.LatencyFrames,'draft latency 8'); finally R.Free; end;
  R:=TSincResampler.Create(rsGood); try CheckEqual(32,R.LatencyFrames,'good latency 32'); finally R.Free; end;
  R:=TSincResampler.Create(rsBest); try CheckEqual(64,R.LatencyFrames,'best latency 64'); finally R.Free; end;
end;

var S:TTestSuite; C:T;
begin
  C:=T.Create; S:=TTestSuite.Create('nextpas.core.audio.resample');
  S.Test('linear upsample 2x', @C.TestLinear_Upsample_2x);
  S.Test('linear downsample half', @C.TestLinear_Downsample_Half);
  S.Test('linear 441->48', @C.TestLinear_441to48);
  S.Test('linear stereo', @C.TestLinear_Stereo);
  S.Test('linear s16 input', @C.TestLinear_S16_Input);
  S.Test('linear empty', @C.TestLinear_Empty);
  S.Test('linear same rate', @C.TestLinear_SameRate);
  S.Test('linear invalid rate throws', @C.TestLinear_InvalidRate_Throws);
  S.Test('linear round-trip', @C.TestLinear_RoundTrip_NearIdentity);
  S.Test('sinc draft vs best', @C.TestSinc_Draft_vs_Best_Quality);
  S.Test('sinc empty', @C.TestSinc_Empty);
  S.Test('sinc invalid rate throws', @C.TestSinc_InvalidRate_Throws);
  S.Test('create resampler intf', @C.TestCreateResampler_Interfaces);
  S.Test('latency', @C.TestLatency);
  C.Free;
  if not S.Run then Halt(1);
end.
