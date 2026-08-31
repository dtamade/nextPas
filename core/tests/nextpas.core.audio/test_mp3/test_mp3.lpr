program test_mp3;

{$mode objfpc}{$H+}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.registry,
  nextpas.core.audio.codec.mp3,
  nextpas.core.audio.codec.mp3.decoder,
  nextpas.core.audio.errors;

type T = class
  procedure TestProbeID3;
  procedure TestProbeSync;
  procedure TestProbeUnknown;
  procedure TestDecodeWhole;
  procedure TestInvalidRaises;
  procedure TestRegistry;
end;

procedure T.TestProbeID3;
var B: TBytes;
begin
  SetLength(B,3); B[0]:=$49; B[1]:=$44; B[2]:=$33;
  CheckEqual(Ord(prMp3), Ord(Mp3Probe(B)), 'id3');
end;

procedure T.TestProbeSync;
var B: TBytes;
begin
  SetLength(B,2); B[0]:=$FF; B[1]:=$FB;
  CheckEqual(Ord(prMp3), Ord(Mp3Probe(B)), 'sync');
end;

procedure T.TestProbeUnknown;
var B: TBytes;
begin
  SetLength(B,2); B[0]:=0; B[1]:=0;
  CheckEqual(Ord(prUnknown), Ord(Mp3Probe(B)), 'unknown');
end;

procedure T.TestDecodeWhole;
var S: IStream; Buf: TAudioBuffer; B: TBytes;
begin
  SetLength(B,100); FillChar(B[0],100,0); B[0]:=$FF; B[1]:=$FB;
  S:=BytesStream(0); S.Write(B[0], Length(B)); S.Position:=0;
  Buf:=CreateMp3Decoder.DecodeWhole(S);
  CheckTrue(Buf.FrameCount>0, 'frames');
  CheckEqual(44100, Buf.Format.SampleRate, 'rate');
end;

procedure T.TestInvalidRaises;
var S: IStream; B: TBytes; Ok: Boolean;
begin
  SetLength(B,4);
  S:=BytesStream(0); S.Write(B[0], Length(B)); S.Position:=0;
  Ok:=False; try CreateMp3Decoder.DecodeWhole(S); except on E:EAudioDecodeError do Ok:=True; end;
  CheckTrue(Ok, 'raise');
end;

procedure T.TestRegistry;
var B: TBytes;
begin
  SetLength(B,2); B[0]:=$FF; B[1]:=$FB;
  CheckEqual(Ord(prMp3), Ord(AudioDetectProbe(B)), 'registry mp3');
end;

var Suite: TTestSuite; C: T;
begin
  C:=T.Create; Suite:=TTestSuite.Create('audio.mp3');
  Suite.Test('probe id3', @C.TestProbeID3);
  Suite.Test('probe sync', @C.TestProbeSync);
  Suite.Test('probe unknown', @C.TestProbeUnknown);
  Suite.Test('decode whole', @C.TestDecodeWhole);
  Suite.Test('invalid raises', @C.TestInvalidRaises);
  Suite.Test('registry', @C.TestRegistry);
  C.Free;
  if not Suite.Run then Halt(1);
end.
