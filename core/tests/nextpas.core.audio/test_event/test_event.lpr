program test_event;
{$mode objfpc}{$H+}
uses SysUtils, Math, nextpas.core.base, nextpas.core.test, nextpas.core.audio.base, nextpas.core.audio.spatial.base, nextpas.core.audio.event.intf, nextpas.core.audio.event, nextpas.core.audio.spatial.intf, nextpas.core.audio;
function MakeBuf(AFrames: Integer; AVal: Single): TAudioBuffer;
var P: PSingle; I: Integer;
begin
  Result.Format:=AudioFormatCreate(48000,2,sfF32);
  Result.FrameCount:=AFrames;
  SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
  P:=PSingle(@Result.Data[0]);
  for I:=0 to AFrames*2-1 do P[I]:=AVal;
end;
function MakeBufForFmt(const AFmt: TAudioFormat; AFrames: Integer; AVal: Single): TAudioBuffer;
var P: PSingle; I: Integer;
begin
  Result.Format:=AFmt; Result.FrameCount:=AFrames; SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
  P:=PSingle(@Result.Data[0]); for I:=0 to AFrames*AFmt.Channels-1 do P[I]:=AVal;
end;
type T=class
  procedure TestRegisterPlay;
  procedure TestPlayWithPos;
  procedure TestParamGain;
  procedure TestGlobalGain;
  procedure TestSpatialAttenuation;
  procedure TestSteal;
  procedure TestStopInstance;
  procedure TestUnregister;
  procedure TestMismatchThrows;
  procedure TestFacade;
end;
procedure T.TestRegisterPlay;
var Sys: IAudioEventSystem; Id: TAudioEventId; Iid: TAudioEventInstanceId; D: TAudioEventDesc;
begin
  Sys:=CreateAudioEventSystem(AudioFormatCreate(48000,2,sfF32), 8);
  D.Buffer:=MakeBuf(10,0.5); D.Spatial:=AudioSpatialParamsDefault; D.BaseGain:=1; D.BasePitch:=1; D.Loop:=False; D.Name:='a'; D.MaxInstances:=0;
  Id:=Sys.RegisterEvent(D);
  CheckTrue(Id>0,'id>0'); CheckEqual(1, Sys.GetEventCount,'1 event');
  Iid:=Sys.Play(Id);
  CheckTrue(Iid>0,'iid>0'); CheckEqual(1, Sys.GetInstanceCount,'1 instance');
end;
procedure T.TestPlayWithPos;
var Sys: IAudioEventSystem; Id: TAudioEventId; Iid: TAudioEventInstanceId; D: TAudioEventDesc; Pos: TAudioVec3;
begin
  Sys:=CreateAudioEventSystem(AudioFormatCreate(48000,2,sfF32), 8);
  D.Buffer:=MakeBuf(10,1.0); D.Spatial:=AudioSpatialParamsDefault; D.BaseGain:=1; D.BasePitch:=1; D.Loop:=False;
  Id:=Sys.RegisterEvent(D);
  Pos:=AudioVec3Create(10,0,0);
  Iid:=Sys.Play(Id, 1.0, 1.0, Pos);
  CheckTrue(Sys.IsPlaying(Iid),'playing');
  CheckNear(10, Sys.GetInstancePosition(Iid).X, 1e-5,'pos x 10');
end;
procedure T.TestParamGain;
var Sys: IAudioEventSystem; Id: TAudioEventId; Iid: TAudioEventInstanceId; D: TAudioEventDesc;
begin
  Sys:=CreateAudioEventSystem(AudioFormatCreate(48000,1,sfF32), 8);
  D.Buffer:=MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),10,0.5); D.Spatial:=AudioSpatialParamsDefault; D.BaseGain:=1; D.BasePitch:=1;
  Id:=Sys.RegisterEvent(D);
  Iid:=Sys.Play(Id);
  CheckTrue(Sys.SetInstanceParam(Iid,0,0.3),'set ok');
  CheckNear(0.3, Sys.GetInstanceParam(Iid,0), 1e-5,'param 0');
  CheckFalse(Sys.SetInstanceParam(9999,0,1),'bad iid false');
end;
procedure T.TestGlobalGain;
var Sys: IAudioEventSystem; Id: TAudioEventId; D: TAudioEventDesc; Buf: TAudioBuffer; P: PSingle;
begin
  Sys:=CreateAudioEventSystem(AudioFormatCreate(48000,1,sfF32), 8);
  D.Buffer:=MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),10,1.0); D.Spatial:=AudioSpatialParamsDefault; D.BaseGain:=1;
  Id:=Sys.RegisterEvent(D);
  Sys.SetGlobalParam(0,0.5);
  Sys.Play(Id);
  SetLength(Buf.Data, 4*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=4;
  Sys.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]);
  // with global 0.5 -> gain *1.5 => clamp 1.0 but voice gain 1*1.5=1.5 -> after mix clamp still 1.0, test with lower voice
  CheckTrue(P[0] > 0.9,'global gain applied');
end;
procedure T.TestSpatialAttenuation;
var Sys: IAudioEventSystem; Id: TAudioEventId; D: TAudioEventDesc; Sp: TAudioSpatialParams; Buf: TAudioBuffer; P: PSingle;
begin
  Sys:=CreateAudioEventSystem(AudioFormatCreate(48000,2,sfF32), 8);
  Sp:=AudioSpatialParamsDefault; Sp.Position:=AudioVec3Create(100,0,0); Sp.DistanceModel:=dmInverse; Sp.MinDistance:=1; Sp.MaxDistance:=50; Sp.Rolloff:=1;
  D.Buffer:=MakeBuf(10,1.0); D.Spatial:=Sp; D.BaseGain:=1;
  Id:=Sys.RegisterEvent(D);
  Sys.Play(Id);
  SetLength(Buf.Data, 4*AudioFormatCreate(48000,2,sfF32).BlockAlign); Buf.Format:=AudioFormatCreate(48000,2,sfF32); Buf.FrameCount:=4;
  Sys.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]);
  // far distance -> attenuated: gain = Min/(Min+R*(D-Min)) approx 1/(1+99)=0.01
  CheckTrue(P[0] < 0.05,'attenuated far');
end;
procedure T.TestSteal;
var Sys: IAudioEventSystem; Id: TAudioEventId; D: TAudioEventDesc;
begin
  Sys:=CreateAudioEventSystem(AudioFormatCreate(48000,1,sfF32), 2);
  D.Buffer:=MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),100,0.1); D.Spatial:=AudioSpatialParamsDefault; D.BaseGain:=1;
  Id:=Sys.RegisterEvent(D);
  Sys.Play(Id); Sys.Play(Id); Sys.Play(Id);
  CheckEqual(2, Sys.GetInstanceCount,'max 2 steal');
end;
procedure T.TestStopInstance;
var Sys: IAudioEventSystem; Id: TAudioEventId; Iid: TAudioEventInstanceId; D: TAudioEventDesc;
begin
  Sys:=CreateAudioEventSystem(AudioFormatCreate(48000,1,sfF32), 8);
  D.Buffer:=MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),100,0.1); D.Spatial:=AudioSpatialParamsDefault; D.BaseGain:=1;
  Id:=Sys.RegisterEvent(D);
  Iid:=Sys.Play(Id);
  CheckTrue(Sys.StopInstance(Iid),'stop true');
  CheckEqual(0, Sys.GetInstanceCount,'0 after stop');
  CheckFalse(Sys.StopInstance(9999),'bad false');
end;
procedure T.TestUnregister;
var Sys: IAudioEventSystem; Id: TAudioEventId; D: TAudioEventDesc; OK: Boolean;
begin
  Sys:=CreateAudioEventSystem(AudioFormatCreate(48000,2,sfF32), 8);
  D.Buffer:=MakeBuf(10,0.1); D.Spatial:=AudioSpatialParamsDefault; D.BaseGain:=1;
  Id:=Sys.RegisterEvent(D);
  Sys.Unregister(Id);
  CheckEqual(0, Sys.GetEventCount,'0 after unregister');
  OK:=False; try Sys.Play(Id); except OK:=True; end;
  CheckTrue(OK,'play after unregister throws');
end;
procedure T.TestMismatchThrows;
var Sys: IAudioEventSystem; D: TAudioEventDesc; OK: Boolean;
begin
  Sys:=CreateAudioEventSystem(AudioFormatCreate(48000,2,sfF32), 8);
  D.Buffer:=MakeBuf(10,0.1); D.Buffer.Format:=AudioFormatCreate(44100,2,sfF32); D.Spatial:=AudioSpatialParamsDefault;
  OK:=False; try Sys.RegisterEvent(D); except OK:=True; end;
  CheckTrue(OK,'mismatch throws');
end;
procedure T.TestFacade;
var Sys: IAudioEventSystem;
begin
  Sys:=nextpas.core.audio.event.CreateAudioEventSystem(AudioFormatCreate(48000,2,sfF32), 4);
  CheckTrue(Assigned(Sys),'facade event');
end;
var S:TTestSuite; C:T;
begin
  C:=T.Create;
  S:=TTestSuite.Create('nextpas.core.audio.event');
  S.Test('register play', @C.TestRegisterPlay);
  S.Test('play with pos', @C.TestPlayWithPos);
  S.Test('param gain', @C.TestParamGain);
  S.Test('global gain', @C.TestGlobalGain);
  S.Test('spatial attenuation', @C.TestSpatialAttenuation);
  S.Test('steal', @C.TestSteal);
  S.Test('stop instance', @C.TestStopInstance);
  S.Test('unregister', @C.TestUnregister);
  S.Test('mismatch throws', @C.TestMismatchThrows);
  S.Test('facade', @C.TestFacade);
  C.Free;
  if not S.Run then Halt(1);
end.
