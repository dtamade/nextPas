program test_bus;

{$mode objfpc}{$H+}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.bus.base,
  nextpas.core.audio.bus.intf,
  nextpas.core.audio.bus.impl,
  nextpas.core.audio;

type T = class
  procedure TestMixerCreate;
  procedure TestBusCreate;
  procedure TestBusCount;
  procedure TestBusGain;
  procedure TestBusFormat;
  procedure TestMixerMixRealtime;
  procedure TestMixerZeroAlloc;
  procedure TestFacadeAlias;
end;

procedure T.TestMixerCreate;
var M: IAudioBusMixer;
begin
  M:=CreateAudioBusMixer;
  CheckTrue(Assigned(M), 'mixer created');
  CheckEqual(0, M.BusCount, '0 buses');
end;

procedure T.TestBusCreate;
var M: IAudioBusMixer; B: IAudioBus; F: TAudioFormat;
begin
  M:=CreateAudioBusMixer;
  F:=AudioFormatCreate(48000,2,sfF32);
  B:=M.CreateBus(F);
  CheckTrue(Assigned(B), 'bus created');
  CheckTrue(B.GetId<>0, 'id non-zero');
  CheckEqual(1, M.BusCount, '1 bus');
end;

procedure T.TestBusCount;
var M: IAudioBusMixer; F: TAudioFormat;
begin
  M:=CreateAudioBusMixer;
  F:=AudioFormatCreate(48000,2,sfF32);
  M.CreateBus(F); M.CreateBus(F);
  CheckEqual(2, M.BusCount, '2 buses');
end;

procedure T.TestBusGain;
var M: IAudioBusMixer; B: IAudioBus; F: TAudioFormat;
begin
  M:=CreateAudioBusMixer;
  F:=AudioFormatCreate(48000,2,sfF32);
  B:=M.CreateBus(F);
  B.SetGain(0.5);
  CheckNear(0.5, B.GetGain, 1e-6, 'gain 0.5');
  B.SetGain(1.0);
  CheckNear(1.0, B.GetGain, 1e-6, 'gain 1.0');
end;

procedure T.TestBusFormat;
var M: IAudioBusMixer; B: IAudioBus; F: TAudioFormat;
begin
  M:=CreateAudioBusMixer;
  F:=AudioFormatCreate(44100,2,sfF32);
  B:=M.CreateBus(F);
  CheckTrue(B.GetFormat.Equals(F), 'format equals');
end;

procedure T.TestMixerMixRealtime;
var M: IAudioBusMixer; Buf: TAudioBuffer; F: TAudioFormat;
begin
  M:=CreateAudioBusMixer;
  F:=AudioFormatCreate(48000,2,sfF32);
  M.CreateBus(F);
  Buf.Format:=F; Buf.FrameCount:=10; SetLength(Buf.Data,10*F.BlockAlign);
  CheckEqual(10, M.MixRealtime(Buf,10), 'mix 10');
end;

procedure T.TestMixerZeroAlloc;
var M: IAudioBusMixer; Buf: TAudioBuffer; F: TAudioFormat; I: Integer;
begin
  M:=CreateAudioBusMixer;
  F:=AudioFormatCreate(48000,2,sfF32);
  M.CreateBus(F);
  Buf.Format:=F; Buf.FrameCount:=64; SetLength(Buf.Data,64*F.BlockAlign);
  // warmup geometric
  M.MixRealtime(Buf,64);
  I:=Length(Buf.Data);
  M.MixRealtime(Buf,64);
  CheckEqual(I, Length(Buf.Data), 'zero alloc steady');
end;

procedure T.TestFacadeAlias;
var M: IAudioBusMixer;
begin
  M:=CreateAudioBusMixer;
  CheckTrue(Assigned(M), 'facade mixer');
end;

var Suite: TTestSuite; C: T;
begin
  C:=T.Create;
  Suite:=TTestSuite.Create('nextpas.core.audio.bus');
  Suite.Test('mixer create', @C.TestMixerCreate);
  Suite.Test('bus create', @C.TestBusCreate);
  Suite.Test('bus count', @C.TestBusCount);
  Suite.Test('bus gain', @C.TestBusGain);
  Suite.Test('bus format', @C.TestBusFormat);
  Suite.Test('mixer mix realtime', @C.TestMixerMixRealtime);
  Suite.Test('mixer zero alloc', @C.TestMixerZeroAlloc);
  Suite.Test('facade alias', @C.TestFacadeAlias);
  C.Free;
  if not Suite.Run then Halt(1);
end.
