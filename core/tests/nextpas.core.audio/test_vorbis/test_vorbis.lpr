program test_vorbis;

{$mode objfpc}{$H+}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.io,
  nextpas.core.audio.base,
  nextpas.core.audio.codec.registry,
  nextpas.core.audio.codec.vorbis,
  nextpas.core.audio.codec.vorbis.decoder,
  nextpas.core.audio.codec.vorbis.sse,
  nextpas.core.audio.errors;

type T = class
  procedure TestProbeOggVorbis;
  procedure TestProbeUnknown;
  procedure TestDecodeWhole;
  procedure TestInvalidRaises;
  procedure TestRegistry;
  procedure TestSseWindow;
end;

procedure T.TestProbeOggVorbis;
var B: TBytes; I: Integer;
begin
  SetLength(B,40); FillChar(B[0],40,0);
  B[0]:=$4F; B[1]:=$67; B[2]:=$67; B[3]:=$53;
  for I:=0 to 5 do
    case I of 0:B[10]:=$76; 1:B[11]:=$6F; 2:B[12]:=$72; 3:B[13]:=$62; 4:B[14]:=$69; 5:B[15]:=$73; end;
  CheckEqual(Ord(prOggVorbis), Ord(VorbisProbe(B)), 'ogg vorbis');
end;

procedure T.TestProbeUnknown;
var B: TBytes;
begin
  SetLength(B,4); B[0]:=1; B[1]:=2; B[2]:=3; B[3]:=4;
  CheckEqual(Ord(prUnknown), Ord(VorbisProbe(B)), 'unknown');
end;

procedure T.TestDecodeWhole;
var S: IStream; Buf: TAudioBuffer; B: TBytes; I: Integer;
begin
  SetLength(B,100); FillChar(B[0],100,0);
  B[0]:=$4F; B[1]:=$67; B[2]:=$67; B[3]:=$53;
  B[10]:=$76; B[11]:=$6F; B[12]:=$72; B[13]:=$62; B[14]:=$69; B[15]:=$73;
  S:=BytesStream(0); S.Write(B[0], Length(B)); S.Position:=0;
  Buf:=CreateVorbisDecoder.DecodeWhole(S);
  CheckTrue(Buf.FrameCount>0, 'frames');
end;

procedure T.TestInvalidRaises;
var S: IStream; B: TBytes; Ok: Boolean;
begin
  SetLength(B,4);
  S:=BytesStream(0); S.Write(B[0], Length(B)); S.Position:=0;
  Ok:=False; try CreateVorbisDecoder.DecodeWhole(S); except on E:EAudioDecodeError do Ok:=True; end;
  CheckTrue(Ok, 'raise');
end;

procedure T.TestRegistry;
var B: TBytes;
begin
  SetLength(B,40); FillChar(B[0],40,0);
  B[0]:=$4F; B[1]:=$67; B[2]:=$67; B[3]:=$53;
  B[10]:=$76; B[11]:=$6F; B[12]:=$72; B[13]:=$62; B[14]:=$69; B[15]:=$73;
  CheckEqual(Ord(prOggVorbis), Ord(AudioDetectProbe(B)), 'registry');
end;

procedure T.TestSseWindow;
var A,B: array of Single; Ok: Boolean; I: Integer;
begin
  SetLength(A,8); SetLength(B,8);
  for I:=0 to 7 do A[I]:=1.0;
  Ok:=VorbisSseWindow(A,B);
  CheckTrue(Ok, 'sse window ok');
end;

var Suite: TTestSuite; C: T;
begin
  C:=T.Create; Suite:=TTestSuite.Create('audio.vorbis');
  Suite.Test('probe ogg vorbis', @C.TestProbeOggVorbis);
  Suite.Test('probe unknown', @C.TestProbeUnknown);
  Suite.Test('decode whole', @C.TestDecodeWhole);
  Suite.Test('invalid raises', @C.TestInvalidRaises);
  Suite.Test('registry', @C.TestRegistry);
  Suite.Test('sse window', @C.TestSseWindow);
  C.Free;
  if not Suite.Run then Halt(1);
end.
