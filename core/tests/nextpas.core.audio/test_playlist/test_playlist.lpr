program test_playlist;

{$mode objfpc}{$H+}

uses
  nextpas.core.test,
  nextpas.core.audio.base,
  nextpas.core.audio.playlist;

type T = class
  procedure TestCreate;
  procedure TestAddAndCount;
  procedure TestPlayAndFill;
  procedure TestNext;
  procedure TestPause;
  procedure TestStop;
  procedure TestClear;
  procedure TestFillZero;
end;

function MakeBuf(AFrames: Integer): TAudioBuffer;
var I: Integer;
begin
  Result.Format:=AudioFormatCreate(48000,2,sfF32);
  Result.FrameCount:=AFrames;
  SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
  for I:=0 to AFrames*2-1 do PSingle(@Result.Data[I*4])^:=0.1;
end;

procedure T.TestCreate;
var P: IAudioPlaylist;
begin
  P:=CreateAudioPlaylist(AudioFormatCreate(48000,2,sfF32));
  CheckEqual(0, P.GetCount, '0 count');
  CheckEqual(Ord(psStopped), Ord(P.GetState), 'stopped');
end;

procedure T.TestAddAndCount;
var P: IAudioPlaylist;
begin
  P:=CreateAudioPlaylist(AudioFormatCreate(48000,2,sfF32));
  P.Add(MakeBuf(10),1.0,0);
  P.Add(MakeBuf(10),0.5,100);
  CheckEqual(2, P.GetCount, '2');
end;

procedure T.TestPlayAndFill;
var P: IAudioPlaylist; B: TAudioBuffer; N: Integer;
begin
  P:=CreateAudioPlaylist(AudioFormatCreate(48000,2,sfF32));
  P.Add(MakeBuf(100),1.0,0);
  P.Play;
  B.Format:=AudioFormatCreate(48000,2,sfF32); B.FrameCount:=10; SetLength(B.Data,10*B.Format.BlockAlign);
  N:=P.FillRealtime(B,10);
  CheckEqual(10, N, 'fill 10');
end;

procedure T.TestNext;
var P: IAudioPlaylist;
begin
  P:=CreateAudioPlaylist(AudioFormatCreate(48000,2,sfF32));
  P.Add(MakeBuf(5),1.0,0); P.Add(MakeBuf(5),1.0,0);
  P.Play;
  CheckEqual(0, P.CurrentIndex, '0');
  P.Next;
  CheckEqual(1, P.CurrentIndex, '1');
end;

procedure T.TestPause;
var P: IAudioPlaylist;
begin
  P:=CreateAudioPlaylist(AudioFormatCreate(48000,2,sfF32));
  P.Add(MakeBuf(5),1.0,0); P.Play; P.Pause;
  CheckEqual(Ord(psPaused), Ord(P.GetState), 'paused');
end;

procedure T.TestStop;
var P: IAudioPlaylist;
begin
  P:=CreateAudioPlaylist(AudioFormatCreate(48000,2,sfF32));
  P.Add(MakeBuf(5),1.0,0); P.Play; P.Stop;
  CheckEqual(Ord(psStopped), Ord(P.GetState), 'stopped');
end;

procedure T.TestClear;
var P: IAudioPlaylist;
begin
  P:=CreateAudioPlaylist(AudioFormatCreate(48000,2,sfF32));
  P.Add(MakeBuf(5),1.0,0); P.Clear;
  CheckEqual(0, P.GetCount, 'clear');
end;

procedure T.TestFillZero;
var P: IAudioPlaylist; B: TAudioBuffer;
begin
  P:=CreateAudioPlaylist(AudioFormatCreate(48000,2,sfF32));
  B.Format:=AudioFormatCreate(48000,2,sfF32); B.FrameCount:=0; SetLength(B.Data,0);
  CheckEqual(0, P.FillRealtime(B,0), 'zero');
end;

var Suite: TTestSuite; C: T;
begin
  C:=T.Create; Suite:=TTestSuite.Create('audio.playlist');
  Suite.Test('create', @C.TestCreate);
  Suite.Test('add count', @C.TestAddAndCount);
  Suite.Test('play fill', @C.TestPlayAndFill);
  Suite.Test('next', @C.TestNext);
  Suite.Test('pause', @C.TestPause);
  Suite.Test('stop', @C.TestStop);
  Suite.Test('clear', @C.TestClear);
  Suite.Test('fill zero', @C.TestFillZero);
  C.Free;
  if not Suite.Run then Halt(1);
end.
