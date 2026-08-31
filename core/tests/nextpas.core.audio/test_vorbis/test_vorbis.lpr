program test_vorbis;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.io,
  nextpas.core.fs,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.codec.vorbis.decoder,
  nextpas.core.audio.codec.registry,
  nextpas.core.audio.errors;

type
  T = class
    procedure TestProbeOggVorbis;
    procedure TestProbeUnknown;
    procedure TestDecodeWholeFixture;
    procedure TestViaRegistry;
    procedure TestStreaming;
    procedure TestFuzz;
  end;

const FIXTURE = '/home/dtamade/projects/music888/tests/fixtures/tone_stereo_44k1.ogg';

procedure T.TestProbeOggVorbis;
var P: TBytes; R: TAudioProbeResult; S: IStream;
begin
  S := nextpas.core.fs.Open(FIXTURE, [fmRead]);
  SetLength(P, 4096);
  S.Read(P[0], 4096);
  R := VorbisProbe(P);
  CheckEqual(Ord(prOggVorbis), Ord(R), 'vorbis probe');
  R := AudioDetectProbe(P);
  CheckEqual(Ord(prOggVorbis), Ord(R), 'detect via registry');
end;

procedure T.TestProbeUnknown;
var P: TBytes; R: TAudioProbeResult;
begin
  SetLength(P,4); P[0]:=Ord('f'); P[1]:=Ord('L'); P[2]:=Ord('a'); P[3]:=Ord('C');
  R := VorbisProbe(P);
  CheckEqual(Ord(prUnknown), Ord(R), 'unknown');
end;

procedure T.TestDecodeWholeFixture;
var Dec: IAudioDecoder; S: IStream; Buf: TAudioBuffer;
begin
  Dec := CreateVorbisDecoder;
  S := nextpas.core.fs.Open(FIXTURE, [fmRead]);
  Buf := Dec.DecodeWhole(S);
  CheckTrue(Buf.FrameCount>0, 'frames >0');
  CheckEqual(2, Buf.Format.Channels, 'ch 2');
  CheckEqual(44100, Buf.Format.SampleRate, 'sr');
  CheckEqual(Ord(sfF32), Ord(Buf.Format.SampleFormat), 'f32');
  // golden approx: tone_stereo_44k1.ogg ~ 176448 frames
  CheckTrue(Buf.FrameCount > 100000, 'large');
end;

procedure T.TestViaRegistry;
var Buf: TAudioBuffer; Tags: TAudioTags; Ok: Boolean;
begin
  Ok := TryDecodeWholeFile(FIXTURE, Buf, Tags);
  CheckTrue(Ok, 'registry ok');
  CheckTrue(Buf.FrameCount>0, 'frames');
end;

procedure T.TestStreaming;
var Dec: IAudioDecoder; S: IStream; Src: IAudioSource; RSrc: IRealtimeAudioSource; OutBuf: TAudioBuffer; N: Integer;
begin
  Dec := CreateVorbisDecoder;
  S := nextpas.core.fs.Open(FIXTURE, [fmRead]);
  Src := Dec.OpenStreaming(S);
  CheckTrue(Assigned(Src), 'src');
  RSrc := Src as IRealtimeAudioSource;
  SetLength(OutBuf.Data, 2048*Src.Format.BlockAlign); OutBuf.Format:=Src.Format;
  N := Src.Fill(OutBuf, 2048);
  CheckEqual(2048, N, 'fill 2048');
  CheckTrue(Src.SeekTo(0), 'seek');
  N := RSrc.FillRealtime(OutBuf, 512);
  CheckEqual(512, N, 'realtime');
end;

procedure T.TestFuzz;
var B: TBytes; S: IStream; Dec: IAudioDecoder; Buf: TAudioBuffer; I, N: Integer; Ok: Boolean;
begin
  for I:=0 to 100 do
  begin
    SetLength(B, Random(2048));
    if Length(B)>0 then for N:=0 to High(B) do B[N]:=Byte(Random(256));
    S := BytesStream(0);
    if Length(B)>0 then S.Write(B[0], Length(B));
    S.Position:=0;
    Dec := CreateVorbisDecoder;
    Ok := TryDecodeWhole(Dec, S, Buf);
    if Ok then CheckTrue(Buf.FrameCount>=0, 'fuzz ok');
  end;
  CheckTrue(True, 'fuzz done');
end;

var
  S: TTestSuite; C: T;
begin
  RandSeed:=42;
  C := T.Create;
  S := TTestSuite.Create('nextpas.core.audio.vorbis');
  S.Test('probe ogg vorbis', @C.TestProbeOggVorbis);
  S.Test('probe unknown', @C.TestProbeUnknown);
  S.Test('decode whole fixture', @C.TestDecodeWholeFixture);
  S.Test('via registry', @C.TestViaRegistry);
  S.Test('streaming', @C.TestStreaming);
  S.Test('fuzz', @C.TestFuzz);
  C.Free;
  if not S.Run then Halt(1);
end.
