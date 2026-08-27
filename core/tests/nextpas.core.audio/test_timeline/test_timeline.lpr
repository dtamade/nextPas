program test_timeline;
{$mode objfpc}{$H+}
uses SysUtils, Math, nextpas.core.base, nextpas.core.test,
  nextpas.core.audio.base, nextpas.core.audio.timeline.intf,
  nextpas.core.audio.timeline, nextpas.core.audio.device.null, nextpas.core.audio;

function MakeBuf(AFrames: Integer; AVal: Single; ASr: Integer = 48000; ACh: Integer = 2): TAudioBuffer;
var P: PSingle; I: Integer;
begin
  Result.Format:=AudioFormatCreate(ASr,ACh,sfF32);
  Result.FrameCount:=AFrames;
  SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
  P:=PSingle(@Result.Data[0]);
  for I:=0 to AFrames*ACh-1 do P[I]:=AVal;
end;

type T=class
  procedure TestAddTrackClip;
  procedure TestClipSorted;
  procedure TestFormatMismatchThrows;
  procedure TestMute;
  procedure TestSolo;
  procedure TestRemoveClip;
  procedure TestRemoveTrack;
  procedure TestClear;
  procedure TestDuration;
  procedure TestSeek;
  procedure TestLoop;
  procedure TestOverlapMix;
  procedure TestPanLaw;
  procedure TestGain;
  procedure TestDeviceDrive;
  procedure TestFacade;
end;

procedure T.TestAddTrackClip;
var TL: IAudioTimeline; Tr: TTimelineTrackId; Cl: TTimelineClipId;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  Tr:=TL.AddTrack;
  Cl:=TL.AddClip(Tr, MakeBuf(100,0.5), 0);
  CheckTrue(Cl>0,'clip>0');
  CheckEqual(1, TL.TrackCount,'1 track');
  CheckEqual(1, TL.ClipCount(Tr),'1 clip');
end;

procedure T.TestClipSorted;
var TL: IAudioTimeline; Tr: TTimelineTrackId; OutBuf: TAudioBuffer; P: PSingle;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  Tr:=TL.AddTrack;
  TL.AddClip(Tr, MakeBuf(10,0.2), 20);
  TL.AddClip(Tr, MakeBuf(10,0.4), 0);
  TL.AddClip(Tr, MakeBuf(10,0.8), 10);
  SetLength(OutBuf.Data, 10*8); OutBuf.Format:=AudioFormatCreate(48000,2,sfF32); OutBuf.FrameCount:=10;
  TL.FillRealtime(OutBuf,10);
  P:=PSingle(@OutBuf.Data[0]);
  CheckNear(0.4, P[0], 1e-5,'sorted first 0.4');
end;

procedure T.TestFormatMismatchThrows;
var TL: IAudioTimeline; Tr: TTimelineTrackId; OK: Boolean; Bad: TAudioBuffer;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  Tr:=TL.AddTrack;
  Bad:=MakeBuf(10,0.1,44100,2);
  OK:=False; try TL.AddClip(Tr, Bad, 0); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'mismatch throws sr');
  Bad:=MakeBuf(10,0.1,48000,1);
  OK:=False; try TL.AddClip(Tr, Bad, 0); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'mismatch throws ch');
end;

procedure T.TestMute;
var TL: IAudioTimeline; Tr: TTimelineTrackId; Buf: TAudioBuffer; P: PSingle;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  Tr:=TL.AddTrack;
  TL.AddClip(Tr, MakeBuf(10,1.0),0);
  TL.SetTrackMute(Tr, True);
  SetLength(Buf.Data, 4*8); Buf.Format:=AudioFormatCreate(48000,2,sfF32); Buf.FrameCount:=4;
  TL.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(0, P[0], 1e-5,'muted 0');
end;

procedure T.TestSolo;
var TL: IAudioTimeline; T1,T2: TTimelineTrackId; Buf: TAudioBuffer; P: PSingle;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  T1:=TL.AddTrack; T2:=TL.AddTrack;
  TL.AddClip(T1, MakeBuf(10,0.9),0);
  TL.AddClip(T2, MakeBuf(10,0.1),0);
  TL.SetTrackSolo(T2, True);
  SetLength(Buf.Data, 4*8); Buf.Format:=AudioFormatCreate(48000,2,sfF32); Buf.FrameCount:=4;
  TL.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.1, P[0], 1e-4,'solo only T2 0.1 not 1.0');
end;

procedure T.TestRemoveClip;
var TL: IAudioTimeline; Tr: TTimelineTrackId; Cl: TTimelineClipId; Buf: TAudioBuffer; P: PSingle;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  Tr:=TL.AddTrack;
  Cl:=TL.AddClip(Tr, MakeBuf(10,1.0),0);
  CheckTrue(TL.RemoveClip(Tr,Cl),'remove true');
  CheckEqual(0, TL.ClipCount(Tr),'0 after remove');
  SetLength(Buf.Data, 4*8); Buf.Format:=AudioFormatCreate(48000,2,sfF32); Buf.FrameCount:=4;
  TL.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(0, P[0], 1e-5,'after remove 0');
end;

procedure T.TestRemoveTrack;
var TL: IAudioTimeline; Tr: TTimelineTrackId;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  Tr:=TL.AddTrack;
  TL.AddClip(Tr, MakeBuf(10,0.5),0);
  CheckTrue(TL.RemoveTrack(Tr),'remove track');
  CheckEqual(0, TL.TrackCount,'0 tracks');
  CheckFalse(TL.RemoveTrack(999),'bad track false');
end;

procedure T.TestClear;
var TL: IAudioTimeline;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  TL.AddTrack; TL.AddTrack;
  TL.Clear;
  CheckEqual(0, TL.TrackCount,'clear 0');
  CheckEqual(UInt64(0), TL.Duration,'dur 0');
  CheckEqual(UInt64(0), TL.Position,'pos 0');
end;

procedure T.TestDuration;
var TL: IAudioTimeline; Tr: TTimelineTrackId;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  Tr:=TL.AddTrack;
  TL.AddClip(Tr, MakeBuf(100,0.5), 50);
  CheckEqual(UInt64(150), TL.Duration,'dur 150');
  TL.AddClip(Tr, MakeBuf(20,0.5), 200);
  CheckEqual(UInt64(220), TL.Duration,'dur 220');
end;

procedure T.TestSeek;
var TL: IAudioTimeline; Tr: TTimelineTrackId; Buf: TAudioBuffer; P: PSingle;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,1,sfF32));
  Tr:=TL.AddTrack;
  TL.AddClip(Tr, MakeBuf(20, 0.6, 48000, 1), 10);
  (TL as IAudioSource).SeekTo(10);
  CheckEqual(UInt64(10), TL.Position,'pos 10');
  SetLength(Buf.Data, 5*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=5;
  TL.FillRealtime(Buf,5);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.6, P[0], 1e-5,'seek then fill 0.6');
end;

procedure T.TestLoop;
var TL: IAudioTimeline; Tr: TTimelineTrackId; Buf: TAudioBuffer; P: PSingle;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,1,sfF32));
  Tr:=TL.AddTrack;
  TL.AddClip(Tr, MakeBuf(10, 0.5, 48000,1), 0);
  TL.Loop:=True;
  (TL as IAudioSource).SeekTo(8);
  SetLength(Buf.Data, 5*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=5;
  TL.FillRealtime(Buf,5);
  CheckTrue(TL.Position < TL.Duration,'wrapped');
  SetLength(Buf.Data, 5*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=5;
  TL.FillRealtime(Buf,5);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.5, P[0], 1e-5,'loop continues');
end;

procedure T.TestOverlapMix;
var TL: IAudioTimeline; T1: TTimelineTrackId; Buf: TAudioBuffer; P: PSingle;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,1,sfF32));
  T1:=TL.AddTrack;
  TL.AddClip(T1, MakeBuf(10, 0.3, 48000,1), 0);
  TL.AddClip(T1, MakeBuf(10, 0.4, 48000,1), 0);
  SetLength(Buf.Data, 4*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=4;
  TL.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.7, P[0], 1e-5,'overlap 0.7');
end;

procedure T.TestPanLaw;
var TL: IAudioTimeline; Tr: TTimelineTrackId; Buf: TAudioBuffer; P: PSingle;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  Tr:=TL.AddTrack;
  TL.SetTrackPan(Tr, -1);
  TL.AddClip(Tr, MakeBuf(10,1.0),0);
  SetLength(Buf.Data, 4*8); Buf.Format:=AudioFormatCreate(48000,2,sfF32); Buf.FrameCount:=4;
  TL.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]);
  CheckTrue(P[0] > P[1], 'pan left L>R');
end;

procedure T.TestGain;
var TL: IAudioTimeline; Tr: TTimelineTrackId; Buf: TAudioBuffer; P: PSingle;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,1,sfF32));
  Tr:=TL.AddTrack(0.5);
  TL.AddClip(Tr, MakeBuf(10, 1.0, 48000,1), 0, 0.5);
  SetLength(Buf.Data, 4*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=4;
  TL.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.25, P[0], 1e-5,'gain 0.5*0.5=0.25');
end;

procedure T.TestDeviceDrive;
var TL: IAudioTimeline; Prov: IAudioDeviceProvider; Dev: IAudioDevice;
begin
  TL:=nextpas.core.audio.timeline.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  TL.AddClip(TL.AddTrack, MakeBuf(100,0.5),0);
  Prov:=CreateNullAudioProvider;
  Dev:=Prov.CreateDefaultDevice(AudioFormatCreate(48000,2,sfF32));
  Dev.SetSource(TL as IRealtimeAudioSource);
  Dev.Start;
  Dev.Drive(10);
  CheckEqual(UInt64(10), TL.Position,'drive advanced');
  Dev.Stop;
end;

procedure T.TestFacade;
var TL: IAudioTimeline;
begin
  TL:=nextpas.core.audio.CreateAudioTimeline(AudioFormatCreate(48000,2,sfF32));
  CheckTrue(Assigned(TL),'facade timeline');
end;

var S:TTestSuite; C:T;
begin
  C:=T.Create;
  S:=TTestSuite.Create('nextpas.core.audio.timeline');
  S.Test('add track clip', @C.TestAddTrackClip);
  S.Test('clip sorted', @C.TestClipSorted);
  S.Test('format mismatch throws', @C.TestFormatMismatchThrows);
  S.Test('mute', @C.TestMute);
  S.Test('solo', @C.TestSolo);
  S.Test('remove clip', @C.TestRemoveClip);
  S.Test('remove track', @C.TestRemoveTrack);
  S.Test('clear', @C.TestClear);
  S.Test('duration', @C.TestDuration);
  S.Test('seek', @C.TestSeek);
  S.Test('loop', @C.TestLoop);
  S.Test('overlap mix', @C.TestOverlapMix);
  S.Test('pan law', @C.TestPanLaw);
  S.Test('gain', @C.TestGain);
  S.Test('device drive', @C.TestDeviceDrive);
  S.Test('facade', @C.TestFacade);
  C.Free;
  if not S.Run then Halt(1);
end.
