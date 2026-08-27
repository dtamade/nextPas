program test_flac;

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
  nextpas.core.audio.codec.flac.decoder,
  nextpas.core.audio.codec.registry,
  nextpas.core.audio.errors;

type
  T = class
    procedure TestProbeNative;
    procedure TestProbeOgg;
    procedure TestProbeUnknown;
    procedure TestDecodeWholeFixture;
    procedure TestDecodeViaRegistry;
    procedure TestOpenStreaming;
    procedure TestTruncatedDoesNotLeak;
    procedure TestSeekAndFillRealtime;
  end;

const
  FIXTURE = '/home/dtamade/projects/music888/tests/fixtures/tone_stereo_16.flac';

function LoadPrefix(const APath: string; ALen: Integer): TBytes;
var S: IStream;
begin
  Result := nil;
  S := nextpas.core.fs.Open(APath, [fmRead]);
  SetLength(Result, ALen);
  if ALen>0 then S.Read(Result[0], ALen);
end;

procedure T.TestProbeNative;
var P: TBytes; R: TAudioProbeResult;
begin
  P := LoadPrefix(FIXTURE, 16);
  R := FlacProbe(P);
  CheckEqual(Ord(prFlac), Ord(R), 'probe native');
  R := AudioDetectProbe(P);
  CheckEqual(Ord(prFlac), Ord(R), 'detect via registry');
end;

procedure T.TestProbeOgg;
var P: TBytes; R: TAudioProbeResult;
begin
  SetLength(P, 8);
  P[0]:=Ord('O'); P[1]:=Ord('g'); P[2]:=Ord('g'); P[3]:=Ord('S');
  P[4]:=0; P[5]:=0; P[6]:=Ord('F'); P[7]:=Ord('L');
  // contains FLAC marker
  P[4]:=Ord('F'); P[5]:=Ord('L'); P[6]:=Ord('A'); P[7]:=Ord('C');
  R := FlacProbe(P);
  CheckEqual(Ord(prFlac), Ord(R), 'probe ogg flac');
end;

procedure T.TestProbeUnknown;
var P: TBytes; R: TAudioProbeResult;
begin
  SetLength(P,4); P[0]:=1; P[1]:=2; P[2]:=3; P[3]:=4;
  R := FlacProbe(P);
  CheckEqual(Ord(prUnknown), Ord(R), 'unknown');
end;

procedure T.TestDecodeWholeFixture;
var Dec: IAudioDecoder; S: IStream; Buf: TAudioBuffer;
begin
  Dec := CreateFlacDecoder;
  S := nextpas.core.fs.Open(FIXTURE, [fmRead]);
  Buf := Dec.DecodeWhole(S);
  CheckTrue(Buf.FrameCount > 0, 'frames >0');
  CheckEqual(2, Buf.Format.Channels, 'ch 2');
  CheckEqual(44100, Buf.Format.SampleRate, 'sr 44100');
  CheckEqual(Ord(sfF32), Ord(Buf.Format.SampleFormat), 'f32');
  CheckEqual(Buf.FrameCount * Buf.Format.BlockAlign, Length(Buf.Data), 'data len');
  // golden frames 33075 as per music888 bench
  CheckEqual(33075, Buf.FrameCount, 'golden frames');
end;

procedure T.TestDecodeViaRegistry;
var Buf: TAudioBuffer; Tags: TAudioTags; Ok: Boolean;
begin
  Ok := TryDecodeWholeFile(FIXTURE, Buf, Tags);
  CheckTrue(Ok, 'registry decode ok');
  CheckEqual(33075, Buf.FrameCount, 'registry frames');
end;

procedure T.TestOpenStreaming;
var Dec: IAudioDecoder; S: IStream; Src: IAudioSource; RSrc: IRealtimeAudioSource; OutBuf: TAudioBuffer; N: Integer;
begin
  Dec := CreateFlacDecoder;
  S := nextpas.core.fs.Open(FIXTURE, [fmRead]);
  Src := Dec.OpenStreaming(S);
  CheckTrue(Assigned(Src), 'src assigned');
  CheckEqual(Ord(sfF32), Ord(Src.GetFormat.SampleFormat), 'src fmt');
  SetLength(OutBuf.Data, 1024*Src.GetFormat.BlockAlign); OutBuf.Format:=Src.GetFormat;
  N := Src.Fill(OutBuf, 1024);
  CheckEqual(1024, N, 'fill 1024');
  CheckTrue(Src.SeekTo(0), 'seek 0');
  RSrc := Src as IRealtimeAudioSource;
  N := RSrc.FillRealtime(OutBuf, 512);
  CheckEqual(512, N, 'realtime 512');
end;

procedure T.TestTruncatedDoesNotLeak;
var Dec: IAudioDecoder; S: IStream; B: TBytes; Ok: Boolean; Buf: TAudioBuffer;
  I, N: Integer;
begin
  // truncated fuzz – must not leak/raise beyond EAudioDecodeError
  for I:=0 to 20 do
  begin
    SetLength(B, Random(4096));
    if Length(B)>0 then for N:=0 to High(B) do B[N]:=Byte(Random(256));
    S := BytesStream(0);
    if Length(B)>0 then S.Write(B[0], Length(B));
    S.Position:=0;
    Dec := CreateFlacDecoder;
    Ok := TryDecodeWhole(Dec, S, Buf);
    // either false or true, but should not crash/leak – HEAPTRC gate covers leak
    if Ok then CheckTrue(Buf.FrameCount>=0, 'fuzz ok frames');
  end;
  CheckTrue(True, 'fuzz done');
end;

procedure T.TestSeekAndFillRealtime;
var Dec: IAudioDecoder; S: IStream; Src: IAudioSource; RSrc: IRealtimeAudioSource; A,B: TAudioBuffer; N: Integer;
begin
  Dec := CreateFlacDecoder;
  S := nextpas.core.fs.Open(FIXTURE, [fmRead]);
  Src := Dec.OpenStreaming(S);
  RSrc := Src as IRealtimeAudioSource;
  SetLength(A.Data, 100*Src.GetFormat.BlockAlign); A.Format:=Src.GetFormat;
  SetLength(B.Data, 100*Src.GetFormat.BlockAlign); B.Format:=Src.GetFormat;
  CheckTrue(Src.SeekTo(1000), 'seek 1000');
  N := Src.Fill(A, 100);
  CheckEqual(100, N, 'fill after seek');
  CheckTrue(Src.SeekTo(1000), 'seek again');
  N := RSrc.FillRealtime(B, 100);
  CheckEqual(100, N, 'realtime after seek');
  CheckTrue(Length(A.Data)=Length(B.Data), 'len eq');
  if Length(A.Data)>0 then CheckTrue(CompareMem(@A.Data[0], @B.Data[0], Length(A.Data)), 'seek deterministic');
end;

var
  S: TTestSuite; C: T;
begin
  RandSeed := 12345;
  C := T.Create;
  S := TTestSuite.Create('nextpas.core.audio.flac');
  S.Test('probe native', @C.TestProbeNative);
  S.Test('probe ogg', @C.TestProbeOgg);
  S.Test('probe unknown', @C.TestProbeUnknown);
  S.Test('decode whole fixture', @C.TestDecodeWholeFixture);
  S.Test('decode via registry', @C.TestDecodeViaRegistry);
  S.Test('open streaming', @C.TestOpenStreaming);
  S.Test('truncated fuzz', @C.TestTruncatedDoesNotLeak);
  S.Test('seek + realtime', @C.TestSeekAndFillRealtime);
  C.Free;
  if not S.Run then Halt(1);
end.
