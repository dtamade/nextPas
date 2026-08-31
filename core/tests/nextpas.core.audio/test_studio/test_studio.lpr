program test_studio;

{$mode objfpc}{$H+}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.studio.intf,
  nextpas.core.audio.studio.project,
  nextpas.core.audio.studio.sequencer,
  nextpas.core.audio.bus,
  nextpas.core.audio.bank;

type T = class
  procedure TestBpmToFrames;
  procedure TestQuantize;
  procedure TestProject;
  procedure TestProjectBpmClamp;
  procedure TestSequencerCreate;
  procedure TestSequencerAddNote;
  procedure TestSequencerFill;
  procedure TestSequencerPlayStop;
  procedure TestBusMixer;
  procedure TestBusGain;
  procedure TestBankAddGet;
  procedure TestBankPack;
  procedure TestBankClear;
  procedure TestBankCount;
  procedure TestSequencerMidiFreq;
  procedure TestBusCount;
end;

procedure T.TestBpmToFrames;
begin
  CheckEqual(48000, StudioBpmToFramesPerBeat(60,48000), '60 bpm');
  CheckEqual(24000, StudioBpmToFramesPerBeat(120,48000), '120 bpm');
end;

procedure T.TestQuantize;
var Q: UInt64;
begin
  Q:=StudioQuantizeFrame(100,120,48000);
  CheckTrue(Q mod UInt64(24000)=0, 'quantized');
end;

procedure T.TestProject;
var P: IStudioProject;
begin
  P:=CreateStudioProject('test',120,AudioFormatCreate(48000,2,sfF32));
  CheckEqual('test', P.GetName, 'name');
  CheckNear(120, P.GetBpm, 1e-6, 'bpm');
end;

procedure T.TestProjectBpmClamp;
var P: IStudioProject;
begin
  P:=CreateStudioProject('x',-5,AudioFormatCreate(48000,2,sfF32));
  CheckTrue(P.GetBpm>0, 'bpm clamp');
end;

procedure T.TestSequencerCreate;
var S: IAudioSequencer;
begin
  S:=CreateAudioSequencer(AudioFormatCreate(48000,2,sfF32),120);
  CheckEqual(0, S.NoteCount, '0 notes');
end;

procedure T.TestSequencerAddNote;
var S: IAudioSequencer; N: TMidiNote;
begin
  S:=CreateAudioSequencer(AudioFormatCreate(48000,2,sfF32),120);
  N.Pitch:=60; N.Velocity:=100; N.StartFrame:=0; N.DurationFrames:=100;
  S.AddNote(N);
  CheckEqual(1, S.NoteCount, '1 note');
end;

procedure T.TestSequencerFill;
var S: IAudioSequencer; B: TAudioBuffer; N: TMidiNote;
begin
  S:=CreateAudioSequencer(AudioFormatCreate(48000,2,sfF32),120);
  N.Pitch:=60; N.Velocity:=100; N.StartFrame:=0; N.DurationFrames:=100; S.AddNote(N); S.Play;
  B.Format:=AudioFormatCreate(48000,2,sfF32); B.FrameCount:=10; SetLength(B.Data,10*B.Format.BlockAlign);
  CheckEqual(10, S.FillRealtime(B,10), 'fill');
end;

procedure T.TestSequencerPlayStop;
var S: IAudioSequencer; B: TAudioBuffer;
begin
  S:=CreateAudioSequencer(AudioFormatCreate(48000,2,sfF32),120);
  S.Play; S.Stop;
  B.Format:=AudioFormatCreate(48000,2,sfF32); B.FrameCount:=10; SetLength(B.Data,10*B.Format.BlockAlign);
  CheckEqual(10, S.FillRealtime(B,10), 'fill after stop');
end;

procedure T.TestBusMixer;
var M: IAudioBusMixer; B: IAudioBus;
begin
  M:=CreateAudioBusMixer;
  B:=M.CreateBus(AudioFormatCreate(48000,2,sfF32));
  CheckEqual(1, M.BusCount, '1 bus');
  CheckTrue(B.GetId>0, 'id');
end;

procedure T.TestBusGain;
var M: IAudioBusMixer; B: IAudioBus;
begin
  M:=CreateAudioBusMixer; B:=M.CreateBus(AudioFormatCreate(48000,2,sfF32));
  B.SetGain(0.5); CheckNear(0.5, B.GetGain, 1e-6, 'gain');
end;

procedure T.TestBankAddGet;
var Bk: TAudioBank; Buf: TAudioBuffer; E: TAudioBankEntry;
begin
  Bk:=CreateAudioBank;
  Buf.Format:=AudioFormatCreate(48000,2,sfF32); Buf.FrameCount:=10; SetLength(Buf.Data,10*Buf.Format.BlockAlign);
  Bk.Add('s1', Buf, Default(TAudioTags));
  CheckTrue(Bk.TryGet('s1',E), 'get');
  CheckEqual('s1', E.Id, 'id');
  Bk.Free;
end;

procedure T.TestBankPack;
var Bk: TAudioBank; Buf: TAudioBuffer; D: TBytes;
begin
  Bk:=CreateAudioBank;
  Buf.Format:=AudioFormatCreate(48000,2,sfF32); Buf.FrameCount:=5; SetLength(Buf.Data,5*Buf.Format.BlockAlign);
  Bk.Add('a', Buf, Default(TAudioTags));
  D:=Bk.PackToBytes;
  CheckTrue(Length(D)>0, 'pack');
  Bk.Free;
end;

procedure T.TestBankClear;
var Bk: TAudioBank; Buf: TAudioBuffer;
begin
  Bk:=CreateAudioBank;
  Buf.Format:=AudioFormatCreate(48000,2,sfF32); Buf.FrameCount:=1; SetLength(Buf.Data,Buf.Format.BlockAlign);
  Bk.Add('x', Buf, Default(TAudioTags)); Bk.Clear;
  CheckEqual(0, Bk.Count, 'clear');
  Bk.Free;
end;

procedure T.TestBankCount;
var Bk: TAudioBank; Buf: TAudioBuffer;
begin
  Bk:=CreateAudioBank;
  CheckEqual(0, Bk.Count, '0');
  Buf.Format:=AudioFormatCreate(48000,2,sfF32); Buf.FrameCount:=1; SetLength(Buf.Data,Buf.Format.BlockAlign);
  Bk.Add('a', Buf, Default(TAudioTags));
  CheckEqual(1, Bk.Count, '1');
  Bk.Free;
end;

procedure T.TestSequencerMidiFreq;
begin
  CheckNear(440, MidiPitchToFreq(69), 0.1, 'A4');
end;

procedure T.TestBusCount;
var M: IAudioBusMixer;
begin
  M:=CreateAudioBusMixer;
  CheckEqual(0, M.BusCount, '0');
end;

var Suite: TTestSuite; C: T;
begin
  C:=T.Create; Suite:=TTestSuite.Create('audio.studio');
  Suite.Test('bpm to frames', @C.TestBpmToFrames);
  Suite.Test('quantize', @C.TestQuantize);
  Suite.Test('project', @C.TestProject);
  Suite.Test('project bpm clamp', @C.TestProjectBpmClamp);
  Suite.Test('sequencer create', @C.TestSequencerCreate);
  Suite.Test('sequencer add note', @C.TestSequencerAddNote);
  Suite.Test('sequencer fill', @C.TestSequencerFill);
  Suite.Test('sequencer play stop', @C.TestSequencerPlayStop);
  Suite.Test('bus mixer', @C.TestBusMixer);
  Suite.Test('bus gain', @C.TestBusGain);
  Suite.Test('bank add get', @C.TestBankAddGet);
  Suite.Test('bank pack', @C.TestBankPack);
  Suite.Test('bank clear', @C.TestBankClear);
  Suite.Test('bank count', @C.TestBankCount);
  Suite.Test('midi freq', @C.TestSequencerMidiFreq);
  Suite.Test('bus count', @C.TestBusCount);
  C.Free;
  if not Suite.Run then Halt(1);
end.
