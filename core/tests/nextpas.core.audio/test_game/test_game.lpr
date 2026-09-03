program test_game;
{$mode objfpc}{$H+}
uses SysUtils, Math, nextpas.core.base, nextpas.core.test, nextpas.core.audio.base, nextpas.core.audio.sfx.intf, nextpas.core.audio.game, nextpas.core.audio.device.null, nextpas.core.audio;
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
  Result.Format:=AFmt;
  Result.FrameCount:=AFrames;
  SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
  P:=PSingle(@Result.Data[0]);
  for I:=0 to AFrames*AFmt.Channels-1 do P[I]:=AVal;
end;
type T=class
  procedure TestLoadPlay;
  procedure TestPan;
  procedure TestPitch;
  procedure TestLoop;
  procedure TestMasterGain;
  procedure TestVoiceSteal;
  procedure TestStopVoice;
  procedure TestStopAll;
  procedure TestSfxCount;
  procedure TestLoadMismatchThrows;
  procedure TestPlayUnknownThrows;
  procedure TestConcurrentVoicesMix;
  procedure TestEofReap;
  procedure TestFacade;
  procedure TestLoadFromFileMissingThrows;
end;
procedure T.TestLoadPlay;
var G: IGameAudio; S: TGameSfxId; V: TGameVoiceId;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,2,sfF32), 8);
  S:=G.Load(MakeBuf(100,0.5));
  V:=G.Play(S);
  CheckTrue(V>0,'voice>0');
  CheckEqual(1, G.VoiceCount,'1 voice');
  G.Device.Drive(10);
  CheckEqual(UInt64(10), G.Device.GetPosition.Frame,'pos 10');
end;
procedure T.TestPan;
var G: IGameAudio; S: TGameSfxId; Buf: TAudioBuffer; P: PSingle;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,2,sfF32), 8);
  S:=G.Load(MakeBuf(10,1.0));
  G.Play(S, 1.0, -1, 1.0, False);
  SetLength(Buf.Data, 4*G.Graph.GetFormat.BlockAlign); Buf.Format:=G.Graph.GetFormat; Buf.FrameCount:=4;
  G.Graph.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]);
  CheckTrue(P[0] > P[1], 'pan left L>R');
  G.StopAll;
  G.Play(S, 1.0, 1, 1.0, False);
  G.Graph.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]);
  CheckTrue(P[1] > P[0], 'pan right R>L');
end;
procedure T.TestPitch;
var G: IGameAudio; S: TGameSfxId; Buf: TAudioBuffer; P: PSingle; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,1,sfF32);
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, Fmt, 8);
  S:=G.Load(MakeBufForFmt(Fmt,20,0.5));
  G.Play(S, 1.0, 0, 2.0, False);
  SetLength(Buf.Data, 10*Fmt.BlockAlign); Buf.Format:=Fmt; Buf.FrameCount:=10;
  G.Graph.FillRealtime(Buf,10);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.5, P[0], 1e-5,'pitch 2x still 0.5');
end;
procedure T.TestLoop;
var G: IGameAudio; S: TGameSfxId; Buf: TAudioBuffer;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,1,sfF32), 8);
  S:=G.Load(MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),5,0.7));
  G.Play(S, 1.0, 0, 1.0, True);
  SetLength(Buf.Data, 10*AudioFormatCreate(48000,1,sfF32).BlockAlign); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=10;
  G.Graph.FillRealtime(Buf,10);
  CheckEqual(1, G.VoiceCount,'loop still alive');
end;
procedure T.TestMasterGain;
var G: IGameAudio; S: TGameSfxId; Buf: TAudioBuffer; P: PSingle;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,1,sfF32), 8);
  S:=G.Load(MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),10,1.0));
  G.SetMasterGain(0.5);
  G.Play(S);
  SetLength(Buf.Data, 4*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=4;
  G.Graph.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.5, P[0], 1e-5,'master 0.5');
end;
procedure T.TestVoiceSteal;
var G: IGameAudio; S: TGameSfxId;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,1,sfF32), 2);
  S:=G.Load(MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),100,0.1));
  G.Play(S); G.Play(S); G.Play(S);
  CheckEqual(2, G.VoiceCount,'max 2 steal');
end;
procedure T.TestStopVoice;
var G: IGameAudio; S: TGameSfxId; V: TGameVoiceId;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,1,sfF32), 8);
  S:=G.Load(MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),100,0.1));
  V:=G.Play(S);
  CheckTrue(G.StopVoice(V),'stop true');
  CheckEqual(0, G.VoiceCount,'0 after stop');
  CheckFalse(G.StopVoice(9999),'bad voice false');
end;
procedure T.TestStopAll;
var G: IGameAudio; S: TGameSfxId;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,1,sfF32), 8);
  S:=G.Load(MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),10,0.1));
  G.Play(S); G.Play(S);
  G.StopAll;
  CheckEqual(0, G.VoiceCount,'stop all 0');
end;
procedure T.TestSfxCount;
var G: IGameAudio;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,2,sfF32), 8);
  G.Load(MakeBuf(10,0.1)); G.Load(MakeBuf(10,0.2));
  CheckEqual(2, G.SfxCount,'2 sfx');
  G.Unload(1);
  CheckEqual(1, G.SfxCount,'1 after unload');
end;
procedure T.TestLoadMismatchThrows;
var G: IGameAudio; OK: Boolean; Buf: TAudioBuffer;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,2,sfF32), 8);
  Buf:=MakeBuf(10,0.1); Buf.Format:=AudioFormatCreate(44100,2,sfF32);
  OK:=False; try G.Load(Buf); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'mismatch throws');
end;
procedure T.TestPlayUnknownThrows;
var G: IGameAudio; OK: Boolean;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,2,sfF32), 8);
  OK:=False; try G.Play(999); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'unknown sfx throws');
end;
procedure T.TestConcurrentVoicesMix;
var G: IGameAudio; S: TGameSfxId; Buf: TAudioBuffer; P: PSingle;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,1,sfF32), 8);
  S:=G.Load(MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),10,0.4));
  G.Play(S); G.Play(S);
  SetLength(Buf.Data, 4*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=4;
  G.Graph.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.8, P[0], 1e-5,'2 voices mix 0.8');
end;
procedure T.TestEofReap;
var G: IGameAudio; S: TGameSfxId; Buf: TAudioBuffer;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,1,sfF32), 8);
  S:=G.Load(MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),5,0.5));
  G.Play(S);
  SetLength(Buf.Data, 10*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=10;
  G.Graph.FillRealtime(Buf,10);
  CheckEqual(0, G.VoiceCount,'reaped after eof');
end;
procedure T.TestFacade;
var G: IGameAudio;
begin
  G:=nextpas.core.audio.CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,2,sfF32), 4);
  CheckTrue(Assigned(G),'facade game');
end;
procedure T.TestLoadFromFileMissingThrows;
var G: IGameAudio; OK: Boolean;
begin
  G:=CreateGameAudioForFormat(CreateNullAudioProvider, AudioFormatCreate(48000,2,sfF32), 8);
  OK:=False; try G.LoadFromFile('/tmp/no_such.wav'); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'missing file throws');
end;
var S:TTestSuite; C:T;
begin
  C:=T.Create;
  S:=TTestSuite.Create('nextpas.core.audio.game');
  S.Test('load play', @C.TestLoadPlay);
  S.Test('pan', @C.TestPan);
  S.Test('pitch', @C.TestPitch);
  S.Test('loop', @C.TestLoop);
  S.Test('master gain', @C.TestMasterGain);
  S.Test('voice steal', @C.TestVoiceSteal);
  S.Test('stop voice', @C.TestStopVoice);
  S.Test('stop all', @C.TestStopAll);
  S.Test('sfx count', @C.TestSfxCount);
  S.Test('load mismatch throws', @C.TestLoadMismatchThrows);
  S.Test('play unknown throws', @C.TestPlayUnknownThrows);
  S.Test('concurrent mix', @C.TestConcurrentVoicesMix);
  S.Test('eof reap', @C.TestEofReap);
  S.Test('facade', @C.TestFacade);
  S.Test('load from file missing throws', @C.TestLoadFromFileMissingThrows);
  C.Free;
  if not S.Run then Halt(1);
end.
