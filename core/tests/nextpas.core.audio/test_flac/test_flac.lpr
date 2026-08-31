program test_flac;

{$mode objfpc}{$H+}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.codec.registry,
  nextpas.core.audio.codec.flac,
  nextpas.core.audio.codec.flac.decoder,
  nextpas.core.audio.errors;

type T = class
  procedure TestProbeFlac;
  procedure TestProbeUnknown;
  procedure TestProbeLimit4K;
  procedure TestDecodeWhole;
  procedure TestDecodeInvalidRaises;
  procedure TestDecoderViaInterface;
  procedure TestRegistryProbe;
  procedure TestTagsEmpty;
end;

procedure T.TestProbeFlac;
var B: TBytes;
begin
  SetLength(B,4); B[0]:=$66; B[1]:=$4C; B[2]:=$61; B[3]:=$43;
  CheckEqual(Ord(prFlac), Ord(FlacProbe(B)), 'flac probe');
  CheckEqual(Ord(prFlac), Ord(FlacProbeBytes(B)), 'flac probe bytes');
end;

procedure T.TestProbeUnknown;
var B: TBytes;
begin
  SetLength(B,4); B[0]:=1; B[1]:=2; B[2]:=3; B[3]:=4;
  CheckEqual(Ord(prUnknown), Ord(FlacProbe(B)), 'unknown');
end;

procedure T.TestProbeLimit4K;
var B: TBytes;
begin
  SetLength(B,5000); FillChar(B[0],5000,0);
  B[0]:=$66; B[1]:=$4C; B[2]:=$61; B[3]:=$43;
  CheckEqual(Ord(prFlac), Ord(FlacProbe(B)), '4k limit still detects');
end;

procedure T.TestDecodeWhole;
var S: IStream; Buf: TAudioBuffer; B: TBytes;
begin
  SetLength(B,100); FillChar(B[0],100,0);
  B[0]:=$66; B[1]:=$4C; B[2]:=$61; B[3]:=$43;
  S:=BytesStream(0); S.Write(B[0], Length(B));
  S.Position:=0;
  Buf:=CreateFlacDecoder.DecodeWhole(S);
  CheckTrue(Buf.FrameCount>0, 'frames>0');
  CheckTrue(Buf.Format.IsValid, 'valid format');
  CheckEqual(44100, Buf.Format.SampleRate, 'rate');
end;

procedure T.TestDecodeInvalidRaises;
var S: IStream; B: TBytes; Ok: Boolean;
begin
  SetLength(B,4); B[0]:=0; B[1]:=0; B[2]:=0; B[3]:=0;
  S:=BytesStream(0); S.Write(B[0], Length(B));
  S.Position:=0;
  Ok:=False; try CreateFlacDecoder.DecodeWhole(S); except on E:EAudioDecodeError do Ok:=True; end;
  CheckTrue(Ok, 'invalid should raise');
end;

procedure T.TestDecoderViaInterface;
var D: IAudioDecoder; B: TBytes;
begin
  D:=CreateFlacDecoder;
  SetLength(B,4); B[0]:=$66; B[1]:=$4C; B[2]:=$61; B[3]:=$43;
  CheckEqual(Ord(prFlac), Ord(D.Probe(B)), 'interface probe');
end;

procedure T.TestRegistryProbe;
var B: TBytes;
begin
  SetLength(B,4); B[0]:=$66; B[1]:=$4C; B[2]:=$61; B[3]:=$43;
  CheckEqual(Ord(prFlac), Ord(AudioDetectProbe(B)), 'registry');
end;

procedure T.TestTagsEmpty;
var D: IAudioDecoder;
begin
  D:=CreateFlacDecoder;
  CheckEqual('', D.Tags.Title, 'empty tags');
end;

var Suite: TTestSuite; C: T;
begin
  C:=T.Create; Suite:=TTestSuite.Create('audio.flac');
  Suite.Test('probe flac', @C.TestProbeFlac);
  Suite.Test('probe unknown', @C.TestProbeUnknown);
  Suite.Test('probe 4k', @C.TestProbeLimit4K);
  Suite.Test('decode whole', @C.TestDecodeWhole);
  Suite.Test('decode invalid', @C.TestDecodeInvalidRaises);
  Suite.Test('via interface', @C.TestDecoderViaInterface);
  Suite.Test('registry probe', @C.TestRegistryProbe);
  Suite.Test('tags empty', @C.TestTagsEmpty);
  C.Free;
  if not Suite.Run then Halt(1);
end.
