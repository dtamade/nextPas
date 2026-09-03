program test_bank;
{$mode objfpc}{$H+}
uses cthreads, SysUtils, Math, nextpas.core.base, nextpas.core.test, nextpas.core.audio.base, nextpas.core.audio.bank.intf, nextpas.core.audio.bank, nextpas.core.audio;
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
function MakeStereoRamp(AFrames: Integer): TAudioBuffer;
var P: PSingle; I: Integer;
begin
  Result.Format:=AudioFormatCreate(48000,2,sfF32);
  Result.FrameCount:=AFrames;
  SetLength(Result.Data, AFrames*Result.Format.BlockAlign);
  P:=PSingle(@Result.Data[0]);
  for I:=0 to AFrames-1 do begin P[I*2]:=I*0.1; P[I*2+1]:=-I*0.1; end;
end;
type T=class
  procedure TestAddFind;
  procedure TestAddDuplicateRefCount;
  procedure TestAcquireReleaseRef;
  procedure TestTryGetBufferDeepCopy;
  procedure TestRemoveClear;
  procedure TestPlayMix;
  procedure TestPan;
  procedure TestPitchLoop;
  procedure TestStopVoice;
  procedure TestStopAll;
  procedure TestVoiceCountReap;
  procedure TestMismatchThrows;
  procedure TestUnknownPlayThrows;
  procedure TestEmptyNameThrows;
  procedure TestFacade;
end;
procedure T.TestAddFind;
var Bank: IAudioBank; Id: TAudioBankId;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,2,sfF32));
  Id:=Bank.Add('kick', MakeBuf(10,0.5));
  CheckTrue(Id>0,'id>0'); CheckEqual(1, Bank.GetCount,'1 entry');
  CheckEqual(Id, Bank.FindByName('kick'),'find by name');
  CheckEqual(0, Bank.FindByName('missing'),'missing 0');
end;
procedure T.TestAddDuplicateRefCount;
var Bank: IAudioBank; Id1, Id2: TAudioBankId;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,2,sfF32));
  Id1:=Bank.Add('snare', MakeBuf(8,0.3));
  Id2:=Bank.Add('snare', MakeBuf(8,0.3));
  CheckEqual(Id1, Id2,'duplicate returns same id');
  CheckEqual(1, Bank.GetCount,'still 1');
  CheckEqual(2, Bank.GetRefCount(Id1),'refcount 2');
end;
procedure T.TestAcquireReleaseRef;
var Bank: IAudioBank; Id: TAudioBankId;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,2,sfF32));
  Id:=Bank.Add('hihat', MakeBuf(10,0.1));
  CheckEqual(2, Bank.AcquireRef(Id),'acquire 2');
  CheckEqual(2, Bank.GetRefCount(Id),'get 2');
  CheckEqual(1, Bank.ReleaseRef(Id),'release 1');
  CheckEqual(1, Bank.GetRefCount(Id),'still 1');
  CheckEqual(0, Bank.ReleaseRef(Id),'release 0 removes');
  CheckEqual(0, Bank.GetCount,'0 after release 0');
end;
procedure T.TestTryGetBufferDeepCopy;
var Bank: IAudioBank; Id: TAudioBankId; Buf, OutBuf: TAudioBuffer; P: PSingle;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,2,sfF32));
  Buf:=MakeBuf(4,0.7);
  Id:=Bank.Add('deep', Buf);
  CheckTrue(Bank.TryGetBuffer(Id, OutBuf),'try get');
  CheckEqual(4, OutBuf.FrameCount,'framecount 4');
  P:=PSingle(@OutBuf.Data[0]); P[0]:=9.9;
  CheckTrue(Bank.TryGetBuffer(Id, OutBuf),'second get');
  P:=PSingle(@OutBuf.Data[0]); CheckNear(0.7, P[0], 1e-5,'deep copy isolated');
  CheckFalse(Bank.TryGetBuffer(9999, OutBuf),'unknown false');
end;
procedure T.TestRemoveClear;
var Bank: IAudioBank; Id: TAudioBankId;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,1,sfF32));
  Id:=Bank.Add('a', MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),10,0.2));
  CheckTrue(Bank.Remove(Id),'remove true');
  CheckEqual(0, Bank.GetCount,'0 after remove');
  CheckFalse(Bank.Remove(9999),'bad remove false');
  Bank.Add('b', MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),10,0.2));
  Bank.Add('c', MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),10,0.2));
  CheckEqual(2, Bank.GetCount,'2 before clear');
  Bank.Clear; CheckEqual(0, Bank.GetCount,'0 after clear');
end;
procedure T.TestPlayMix;
var Bank: IAudioBank; Id: TAudioBankId; Buf: TAudioBuffer; P: PSingle;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,1,sfF32));
  Id:=Bank.Add('mix', MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),10,0.4));
  Bank.Play(Id); Bank.Play(Id);
  SetLength(Buf.Data, 4*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=4;
  Bank.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.8, P[0], 1e-5,'2 voices mix 0.8');
end;
procedure T.TestPan;
var Bank: IAudioBank; Id: TAudioBankId; Buf: TAudioBuffer; P: PSingle;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,2,sfF32));
  Id:=Bank.Add('pan', MakeBuf(10,1.0));
  Bank.Play(Id, 1.0, -1.0, 1.0, False);
  SetLength(Buf.Data, 4*Bank.GetFormat.BlockAlign); Buf.Format:=Bank.GetFormat; Buf.FrameCount:=4;
  Bank.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckTrue(P[0] > P[1],'pan left L>R');
  Bank.StopAll;
  Bank.Play(Id, 1.0, 1.0, 1.0, False);
  Bank.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckTrue(P[1] > P[0],'pan right R>L');
end;
procedure T.TestPitchLoop;
var Bank: IAudioBank; Id: TAudioBankId; Buf: TAudioBuffer;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,1,sfF32));
  Id:=Bank.Add('pitch', MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),5,0.6));
  Bank.Play(Id, 1.0, 0, 2.0, False);
  SetLength(Buf.Data, 10*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=10;
  Bank.FillRealtime(Buf,10);
  CheckTrue(Bank.VoiceCount<=1,'pitch 2x still valid');
  Bank.StopAll;
  Id:=Bank.Add('loop', MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),5,0.5));
  // separate bank for loop to avoid id conflict? reuse same bank but new name
  Bank.Play(Id, 1.0, 0, 1.0, True);
  SetLength(Buf.Data, 10*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=10;
  Bank.FillRealtime(Buf,10);
  CheckEqual(1, Bank.VoiceCount,'loop alive after wrap');
end;
procedure T.TestStopVoice;
var Bank: IAudioBank; Id: TAudioBankId; V: TBankVoiceId;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,1,sfF32));
  Id:=Bank.Add('s', MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),100,0.1));
  V:=Bank.Play(Id);
  CheckTrue(Bank.StopVoice(V),'stop true');
  CheckEqual(0, Bank.VoiceCount,'0 after stop');
  CheckFalse(Bank.StopVoice(9999),'bad false');
end;
procedure T.TestStopAll;
var Bank: IAudioBank; Id: TAudioBankId;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,1,sfF32));
  Id:=Bank.Add('a', MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),10,0.1));
  Bank.Play(Id); Bank.Play(Id);
  Bank.StopAll; CheckEqual(0, Bank.VoiceCount,'stop all 0');
end;
procedure T.TestVoiceCountReap;
var Bank: IAudioBank; Id: TAudioBankId; Buf: TAudioBuffer;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,1,sfF32));
  Id:=Bank.Add('short', MakeBufForFmt(AudioFormatCreate(48000,1,sfF32),5,0.5));
  Bank.Play(Id);
  SetLength(Buf.Data, 10*4); Buf.Format:=AudioFormatCreate(48000,1,sfF32); Buf.FrameCount:=10;
  Bank.FillRealtime(Buf,10);
  CheckEqual(0, Bank.VoiceCount,'reaped after eof');
end;
procedure T.TestMismatchThrows;
var Bank: IAudioBank; OK: Boolean; Buf: TAudioBuffer;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,2,sfF32));
  Buf:=MakeBuf(10,0.1); Buf.Format:=AudioFormatCreate(44100,2,sfF32);
  OK:=False; try Bank.Add('bad', Buf); except OK:=True; end;
  CheckTrue(OK,'mismatch throws');
  Buf:=MakeBuf(10,0.1); Buf.Format:=AudioFormatCreate(48000,1,sfS16);
  OK:=False; try Bank.Add('bad2', Buf); except OK:=True; end;
  CheckTrue(OK,'non-f32 throws');
end;
procedure T.TestUnknownPlayThrows;
var Bank: IAudioBank; OK: Boolean;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,2,sfF32));
  OK:=False; try Bank.Play(9999); except OK:=True; end;
  CheckTrue(OK,'unknown play throws');
end;
procedure T.TestEmptyNameThrows;
var Bank: IAudioBank; OK: Boolean;
begin
  Bank:=CreateAudioBank(AudioFormatCreate(48000,2,sfF32));
  OK:=False; try Bank.Add('', MakeBuf(10,0.1)); except OK:=True; end;
  CheckTrue(OK,'empty name throws');
end;
procedure T.TestFacade;
var Bank: IAudioBank;
begin
  Bank:=nextpas.core.audio.bank.CreateAudioBank(AudioFormatCreate(48000,2,sfF32));
  CheckTrue(Assigned(Bank),'facade bank');
  CheckTrue(Bank.GetFormat.IsValid,'format valid');
end;
var S:TTestSuite; C:T;
begin
  C:=T.Create;
  S:=TTestSuite.Create('nextpas.core.audio.bank');
  S.Test('add find', @C.TestAddFind);
  S.Test('add duplicate refcount', @C.TestAddDuplicateRefCount);
  S.Test('acquire release ref', @C.TestAcquireReleaseRef);
  S.Test('tryGetBuffer deep copy', @C.TestTryGetBufferDeepCopy);
  S.Test('remove clear', @C.TestRemoveClear);
  S.Test('play mix', @C.TestPlayMix);
  S.Test('pan', @C.TestPan);
  S.Test('pitch loop', @C.TestPitchLoop);
  S.Test('stop voice', @C.TestStopVoice);
  S.Test('stop all', @C.TestStopAll);
  S.Test('voice reap', @C.TestVoiceCountReap);
  S.Test('mismatch throws', @C.TestMismatchThrows);
  S.Test('unknown play throws', @C.TestUnknownPlayThrows);
  S.Test('empty name throws', @C.TestEmptyNameThrows);
  S.Test('facade', @C.TestFacade);
  C.Free;
  if not S.Run then Halt(1);
end.
