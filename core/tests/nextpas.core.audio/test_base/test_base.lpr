program test_base;

{$mode objfpc}{$H+}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.audio.base,
  nextpas.core.audio.errors,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.pcm,
  nextpas.core.audio;

type
  T = class
    procedure TestBlockAlign_ByteRate;
    procedure TestByteRate_Int64_NoOverflow;
    procedure TestFramesForMs_Boundaries;
    procedure TestFramesForMs_Zero_Negative;
    procedure TestChannelMask_Layouts;
    procedure TestChannelMask_LayoutRoundTrip;
    procedure TestChannelMask_NonStandardChannels;
    procedure TestIsValid_RejectsIllegal;
    procedure TestIsValid_AcceptsValid;
    procedure TestFormatEquals;
    procedure TestAudioFormatCreate_ThrowsOnIllegal;
    procedure TestAudioFormatCreate_DerivesMask;
    procedure TestAudioClock_ToDurationNs;
    procedure TestAudioClock_ZeroRate;
    procedure TestBuffer_IsEmpty_SampleCount;
    procedure TestPcm_Conversions_RoundTrip;
    procedure TestPcm_Clamp;
    procedure TestPcm_Interleave_Deinterleave;
    procedure TestErrors_Hierarchy;
    procedure TestFacade_Aliases;
  end;

procedure T.TestBlockAlign_ByteRate;
var
  LFmt: TAudioFormat;
begin
  LFmt := AudioFormatCreate(44100, 2, sfS16);
  CheckEqual(2, LFmt.BytesPerSample, 'S16 BytesPerSample');
  CheckEqual(4, LFmt.BlockAlign, 'stereo S16 BlockAlign');
  CheckEqual(Int64(44100) * 4, LFmt.ByteRate, 'ByteRate 44100*4');

  LFmt := AudioFormatCreate(48000, 1, sfU8);
  CheckEqual(1, LFmt.BlockAlign, 'mono U8 BlockAlign');
  CheckEqual(Int64(48000), LFmt.ByteRate, 'ByteRate mono U8');

  LFmt := AudioFormatCreate(8000, 8, sfS24);
  CheckEqual(3, LFmt.BytesPerSample, 'S24 BytesPerSample');
  CheckEqual(24, LFmt.BlockAlign, '8ch S24 BlockAlign');
  CheckEqual(Int64(8000) * 24, LFmt.ByteRate, 'ByteRate 8000 8ch S24');
end;

procedure T.TestByteRate_Int64_NoOverflow;
var
  LFmt: TAudioFormat;
  LRate: Int64;
begin
  LFmt := AudioFormatCreate(192000, 8, sfF32);
  CheckEqual(4, LFmt.BytesPerSample, 'F32 BytesPerSample');
  CheckEqual(32, LFmt.BlockAlign, '8ch F32 BlockAlign');
  LRate := LFmt.ByteRate;
  CheckEqual(Int64(192000) * 32, LRate, 'ByteRate 192k 8ch F32 no overflow');
  CheckEqual(Int64(6144000), LRate, 'ByteRate expected 6144000');
  Check(LRate <= High(Int64), 'ByteRate fits Int64');
  Check(LRate = Int64(192000) * 32, 'ByteRate Int64 calculation correct');
  { Also check max via S32 same size }
  LFmt := AudioFormatCreate(192000, 8, sfS32);
  CheckEqual(Int64(6144000), LFmt.ByteRate, 'S32 same byte rate');
end;

procedure T.TestFramesForMs_Boundaries;
var
  LFmt: TAudioFormat;
begin
  LFmt := AudioFormatCreate(8000, 1, sfS16);
  CheckEqual(8, LFmt.FramesForMs(1), '8000Hz 1ms = 8 frames');
  CheckEqual(8000, LFmt.FramesForMs(1000), '8000Hz 1000ms');
  CheckEqual(4000, LFmt.FramesForMs(500), '8000Hz 500ms');

  LFmt := AudioFormatCreate(44100, 2, sfS16);
  CheckEqual(44100, LFmt.FramesForMs(1000), '44100 1000ms');
  CheckEqual(44, LFmt.FramesForMs(1), '44100 1ms trunc');

  LFmt := AudioFormatCreate(48000, 2, sfF32);
  CheckEqual(48000, LFmt.FramesForMs(1000), '48000 1000ms');
  CheckEqual(24000, LFmt.FramesForMs(500), '48000 500ms');

  LFmt := AudioFormatCreate(192000, 2, sfS16);
  CheckEqual(192, LFmt.FramesForMs(1), '192k 1ms');
  CheckEqual(192000, LFmt.FramesForMs(1000), '192k 1000ms');
end;

procedure T.TestFramesForMs_Zero_Negative;
var
  LFmt: TAudioFormat;
begin
  LFmt := AudioFormatCreate(44100, 1, sfS16);
  CheckEqual(0, LFmt.FramesForMs(0), '0ms => 0');
  CheckEqual(0, LFmt.FramesForMs(-5), '-5ms => 0');
end;

procedure T.TestChannelMask_Layouts;
begin
  CheckEqual(UInt32($4), AudioChannelMaskForLayout(clMono), 'mono mask FC');
  CheckEqual(UInt32($3), AudioChannelMaskForLayout(clStereo), 'stereo mask');
  CheckEqual(UInt32($33), AudioChannelMaskForLayout(clQuad), 'quad mask 0x33');
  CheckEqual(UInt32($3F), AudioChannelMaskForLayout(clSurround51), '5.1 mask 0x3F');
  CheckEqual(UInt32($63F), AudioChannelMaskForLayout(clSurround71), '7.1 mask 0x63F');
end;

procedure T.TestChannelMask_LayoutRoundTrip;
var
  LMask: UInt32;
  LLayout: TAudioChannelLayout;
begin
  LMask := AudioChannelMaskForLayout(clStereo);
  LLayout := AudioChannelLayoutForMask(LMask, 2);
  CheckEqual(Ord(clStereo), Ord(LLayout), 'stereo round-trip');

  LMask := AudioChannelMaskForLayout(clSurround51);
  LLayout := AudioChannelLayoutForMask(LMask, 6);
  CheckEqual(Ord(clSurround51), Ord(LLayout), '5.1 round-trip');

  LMask := AudioChannelMaskForLayout(clSurround71);
  LLayout := AudioChannelLayoutForMask(LMask, 8);
  CheckEqual(Ord(clSurround71), Ord(LLayout), '7.1 round-trip');

  { Non-canonical mask with 2 channels falls back to stereo }
  LLayout := AudioChannelLayoutForMask(UInt32($5), 2);
  CheckEqual(Ord(clStereo), Ord(LLayout), 'non-canonical 2ch fallback stereo');
end;

procedure T.TestChannelMask_NonStandardChannels;
var
  LFmt: TAudioFormat;
begin
  LFmt := AudioFormatCreate(44100, 3, sfS16);
  CheckEqual(3, LFmt.Channels, '3 channels kept');
  { Mask for 3ch is FL|FR|FC = 0x7 }
  CheckEqual(UInt32($7), LFmt.ChannelMask, '3ch mask 0x7');

  LFmt := AudioFormatCreate(48000, 5, sfS16);
  CheckEqual(5, LFmt.Channels, '5 channels');

  LFmt := AudioFormatCreate(48000, 7, sfS16);
  CheckEqual(7, LFmt.Channels, '7 channels');
end;

procedure T.TestIsValid_RejectsIllegal;
var
  LFmt: TAudioFormat;
begin
  LFmt.SampleRate := 0;
  LFmt.Channels := 2;
  LFmt.SampleFormat := sfS16;
  LFmt.ChannelMask := AudioChannelMaskForLayout(clStereo);
  LFmt.ChannelLayout := clStereo;
  CheckFalse(LFmt.IsValid, '0 sample rate invalid');

  LFmt.SampleRate := 44100;
  LFmt.Channels := 9;
  CheckFalse(LFmt.IsValid, '9 channels invalid');

  LFmt.Channels := 0;
  CheckFalse(LFmt.IsValid, '0 channels invalid');

  LFmt.Channels := 2;
  LFmt.SampleRate := 7999;
  CheckFalse(LFmt.IsValid, '7999 < Min invalid');

  LFmt.SampleRate := 192001;
  CheckFalse(LFmt.IsValid, '192001 > Max invalid');

  LFmt.SampleRate := 44100;
  LFmt.SampleFormat := TAudioSampleFormat(99);
  CheckFalse(LFmt.IsValid, 'invalid format enum');
end;

procedure T.TestIsValid_AcceptsValid;
var
  LFmt: TAudioFormat;
begin
  LFmt := AudioFormatCreate(8000, 1, sfU8);
  CheckTrue(LFmt.IsValid, '8000 mono U8 valid');

  LFmt := AudioFormatCreate(192000, 8, sfF32);
  CheckTrue(LFmt.IsValid, '192k 8ch F32 valid');

  LFmt := AudioFormatCreate(44100, 2, sfS16);
  CheckTrue(LFmt.IsValid, '44100 stereo S16 valid');
end;

procedure T.TestFormatEquals;
var
  LA, LB: TAudioFormat;
begin
  LA := AudioFormatCreate(44100, 2, sfS16);
  LB := AudioFormatCreate(44100, 2, sfS16);
  CheckTrue(LA.Equals(LB), 'equal formats');

  LB.SampleRate := 48000;
  CheckFalse(LA.Equals(LB), 'different rate not equal');

  LB := LA;
  LB.ChannelMask := UInt32($5);
  CheckFalse(LA.Equals(LB), 'different mask not equal');
end;

procedure T.TestAudioFormatCreate_ThrowsOnIllegal;
var
  LOk: Boolean;
begin
  LOk := False;
  try
    AudioFormatCreate(0, 2, sfS16);
  except
    on E: EInvalidArgument do LOk := True;
    on E: Exception do LOk := True;
  end;
  CheckTrue(LOk, '0 rate should raise');

  LOk := False;
  try
    AudioFormatCreate(44100, 9, sfS16);
  except
    on E: Exception do LOk := True;
  end;
  CheckTrue(LOk, '9 channels should raise');

  LOk := False;
  try
    AudioFormatCreate(7999, 2, sfS16);
  except
    on E: Exception do LOk := True;
  end;
  CheckTrue(LOk, '7999 rate should raise');
end;

procedure T.TestAudioFormatCreate_DerivesMask;
var
  LFmt: TAudioFormat;
begin
  LFmt := AudioFormatCreate(44100, 1, sfS16);
  CheckEqual(UInt32($4), LFmt.ChannelMask, 'mono derives FC mask');
  CheckEqual(Ord(clMono), Ord(LFmt.ChannelLayout), 'mono layout');

  LFmt := AudioFormatCreate(44100, 2, sfS16);
  CheckEqual(UInt32($3), LFmt.ChannelMask, 'stereo derives 0x3');
  CheckEqual(Ord(clStereo), Ord(LFmt.ChannelLayout), 'stereo layout');

  LFmt := AudioFormatCreate(48000, 6, sfS16);
  CheckEqual(UInt32($3F), LFmt.ChannelMask, '6ch derives 0x3F');
end;

procedure T.TestAudioClock_ToDurationNs;
var
  LClock: TAudioClock;
begin
  LClock.Frame := 48000;
  LClock.SampleRate := 48000;
  CheckEqual(Int64(1000000000), LClock.ToDurationNs, '48000 frames @48k = 1s');

  LClock.Frame := 44100;
  LClock.SampleRate := 44100;
  CheckEqual(Int64(1000000000), LClock.ToDurationNs, '44100 frames @44.1k = 1s');

  LClock.Frame := 0;
  LClock.SampleRate := 48000;
  CheckEqual(Int64(0), LClock.ToDurationNs, '0 frames');

  LClock.Frame := 1;
  LClock.SampleRate := 48000;
  CheckEqual(Int64(20833), LClock.ToDurationNs, '1 frame @48k ~20833 ns');

  LClock.Frame := 96000;
  LClock.SampleRate := 48000;
  CheckEqual(Int64(2000000000), LClock.ToDurationNs, '96000 frames 2s');
end;

procedure T.TestAudioClock_ZeroRate;
var
  LClock: TAudioClock;
begin
  LClock.Frame := 100;
  LClock.SampleRate := 0;
  CheckEqual(Int64(0), LClock.ToDurationNs, '0 rate => 0 ns');
end;

procedure T.TestBuffer_IsEmpty_SampleCount;
var
  LBuf: TAudioBuffer;
begin
  LBuf.Format := AudioFormatCreate(44100, 2, sfS16);
  LBuf.FrameCount := 0;
  SetLength(LBuf.Data, 0);
  CheckTrue(LBuf.IsEmpty, '0 frames empty');

  LBuf.FrameCount := 100;
  SetLength(LBuf.Data, 100 * LBuf.Format.BlockAlign);
  CheckFalse(LBuf.IsEmpty, '100 frames not empty');
  CheckEqual(200, LBuf.SampleCount, '100 frames stereo => 200 samples');

  LBuf.FrameCount := 1;
  SetLength(LBuf.Data, 0);
  CheckTrue(LBuf.IsEmpty, 'data len 0 empty even if FrameCount 1');
end;

procedure T.TestPcm_Conversions_RoundTrip;
var
  LF: Single;
  LU8: Byte;
  LS16: SmallInt;
  LS24: Integer;
  LS32: LongInt;
begin
  { U8 }
  LU8 := 128;
  LF := PcmU8ToF32(LU8);
  CheckNear(0.0, LF, 0.01, 'U8 128 -> ~0');
  LU8 := PcmF32ToU8(0.0);
  CheckEqual(128, Integer(LU8), 'F32 0 -> U8 128');

  { S16 }
  LS16 := 0;
  LF := PcmS16ToF32(LS16);
  CheckNear(0.0, LF, 1e-6, 'S16 0 -> 0');
  LS16 := PcmF32ToS16(0.0);
  CheckEqual(0, LS16, 'F32 0 -> S16 0');
  LS16 := PcmF32ToS16(1.0);
  CheckEqual(32767, LS16, 'F32 1 -> S16 max');
  LS16 := PcmF32ToS16(-1.0);
  CheckEqual(-32768, LS16, 'F32 -1 -> S16 min');

  { S24 }
  LS24 := 0;
  LF := PcmS24ToF32(LS24);
  CheckNear(0.0, LF, 1e-6, 'S24 0 -> 0');
  LS24 := PcmF32ToS24(1.0);
  CheckEqual(8388607, LS24, 'F32 1 -> S24 max');

  { S32 }
  LS32 := 0;
  LF := PcmS32ToF32(LS32);
  CheckNear(0.0, LF, 1e-6, 'S32 0 -> 0');
  LS32 := PcmF32ToS32(1.0);
  CheckEqual(2147483647, LS32, 'F32 1 -> S32 max');

  { Bulk convert round-trip S16->F32->S16 }
  CheckNear(0.5, PcmS16ToF32(PcmF32ToS16(0.5)), 0.001, 'bulk S16 round-trip');
end;

procedure T.TestPcm_Clamp;
begin
  CheckNear(-1.0, Double(PcmClampF32(-2.0)), 1e-6, 'clamp -2 to -1');
  CheckNear(1.0, Double(PcmClampF32(2.0)), 1e-6, 'clamp 2 to 1');
  CheckNear(0.5, Double(PcmClampF32(0.5)), 1e-6, 'clamp 0.5 stays');
  CheckEqual(-32768, PcmClampS16(-40000), 'clamp S16 low');
  CheckEqual(32767, PcmClampS16(40000), 'clamp S16 high');
end;

procedure T.TestPcm_Interleave_Deinterleave;
var
  LPlanes: array of TBytes;
  LInterleaved: TBytes;
  LOutPlanes: TAudioPlaneArray;
  LI: Integer;
begin
  SetLength(LPlanes, 2);
  SetLength(LPlanes[0], 4);
  SetLength(LPlanes[1], 4);
  { Plane0: 0x01 0x02 0x03 0x04 (2 frames, 2 bytes per sample) }
  LPlanes[0][0] := 1; LPlanes[0][1] := 2; LPlanes[0][2] := 3; LPlanes[0][3] := 4;
  LPlanes[1][0] := 5; LPlanes[1][1] := 6; LPlanes[1][2] := 7; LPlanes[1][3] := 8;
  PcmInterleave(LPlanes, 2, 2, 2, LInterleaved);
  CheckEqual(8, Length(LInterleaved), 'interleaved len');
  CheckEqual(1, LInterleaved[0], 'interleave 0');
  CheckEqual(2, LInterleaved[1], 'interleave 1');
  CheckEqual(5, LInterleaved[2], 'interleave 2');
  CheckEqual(6, LInterleaved[3], 'interleave 3');
  CheckEqual(3, LInterleaved[4], 'interleave 4');
  CheckEqual(4, LInterleaved[5], 'interleave 5');
  CheckEqual(7, LInterleaved[6], 'interleave 6');
  CheckEqual(8, LInterleaved[7], 'interleave 7');

  PcmDeinterleave(LInterleaved, 2, 2, 2, LOutPlanes);
  CheckEqual(2, Length(LOutPlanes), 'deinterleave planes count');
  for LI := 0 to 3 do
  begin
    CheckEqual(LPlanes[0][LI], LOutPlanes[0][LI], 'plane0 round-trip ' + IntToStr(LI));
    CheckEqual(LPlanes[1][LI], LOutPlanes[1][LI], 'plane1 round-trip ' + IntToStr(LI));
  end;
end;

procedure T.TestErrors_Hierarchy;
var
  LE: EAudioDecodeError;
  LE2: EAudioEncodeError;
  LE3: EAudioDeviceError;
  LE4: EAudioGraphError;
  LE5: EAudioTimelineError;
begin
  LE := EAudioDecodeError.Create('decode fail');
  try
    CheckTrue(LE is EAudioError, 'decode is EAudioError');
    CheckTrue(LE is EIOError, 'decode is EIOError');
    CheckTrue(LE is Exception, 'decode is Exception');
  finally
    LE.Free;
  end;
  LE2 := EAudioEncodeError.Create('x');
  try
    CheckTrue(LE2 is EAudioError, 'encode hierarchy');
  finally
    LE2.Free;
  end;
  LE3 := EAudioDeviceError.Create('x');
  try
    CheckTrue(LE3 is EAudioError, 'device hierarchy');
  finally
    LE3.Free;
  end;
  LE4 := EAudioGraphError.Create('x');
  try
    CheckTrue(LE4 is EAudioError, 'graph hierarchy');
  finally
    LE4.Free;
  end;
  LE5 := EAudioTimelineError.Create('x');
  try
    CheckTrue(LE5 is EAudioError, 'timeline hierarchy');
  finally
    LE5.Free;
  end;
end;

procedure T.TestFacade_Aliases;
var
  LFmt: TAudioFormat;
  LBuf: TAudioBuffer;
begin
  LFmt := nextpas.core.audio.AudioFormatCreate(44100, 2, sfS16);
  CheckTrue(LFmt.IsValid, 'facade AudioFormatCreate');
  CheckEqual(4, LFmt.BlockAlign, 'facade BlockAlign');
  LBuf.Format := LFmt;
  LBuf.FrameCount := 0;
  SetLength(LBuf.Data, 0);
  CheckTrue(LBuf.IsEmpty, 'facade buffer alias');
  { pcm via facade }
  CheckNear(0.0, nextpas.core.audio.PcmS16ToF32(0), 1e-6, 'facade pcm');
end;

var
  LSuite: TTestSuite;
  LCase: T;

begin
  LCase := T.Create;
  LSuite := TTestSuite.Create('nextpas.core.audio.base');
  LSuite.Test('BlockAlign/ByteRate', @LCase.TestBlockAlign_ByteRate);
  LSuite.Test('ByteRate Int64 no overflow', @LCase.TestByteRate_Int64_NoOverflow);
  LSuite.Test('FramesForMs boundaries', @LCase.TestFramesForMs_Boundaries);
  LSuite.Test('FramesForMs zero/negative', @LCase.TestFramesForMs_Zero_Negative);
  LSuite.Test('ChannelMask layouts', @LCase.TestChannelMask_Layouts);
  LSuite.Test('ChannelMask round-trip', @LCase.TestChannelMask_LayoutRoundTrip);
  LSuite.Test('non-standard channels mask', @LCase.TestChannelMask_NonStandardChannels);
  LSuite.Test('IsValid rejects illegal', @LCase.TestIsValid_RejectsIllegal);
  LSuite.Test('IsValid accepts valid', @LCase.TestIsValid_AcceptsValid);
  LSuite.Test('Format Equals', @LCase.TestFormatEquals);
  LSuite.Test('AudioFormatCreate throws', @LCase.TestAudioFormatCreate_ThrowsOnIllegal);
  LSuite.Test('AudioFormatCreate derives mask', @LCase.TestAudioFormatCreate_DerivesMask);
  LSuite.Test('AudioClock ToDurationNs', @LCase.TestAudioClock_ToDurationNs);
  LSuite.Test('AudioClock zero rate', @LCase.TestAudioClock_ZeroRate);
  LSuite.Test('Buffer IsEmpty/SampleCount', @LCase.TestBuffer_IsEmpty_SampleCount);
  LSuite.Test('PCM conversions round-trip', @LCase.TestPcm_Conversions_RoundTrip);
  LSuite.Test('PCM clamp', @LCase.TestPcm_Clamp);
  LSuite.Test('PCM interleave/deinterleave', @LCase.TestPcm_Interleave_Deinterleave);
  LSuite.Test('Errors hierarchy', @LCase.TestErrors_Hierarchy);
  LSuite.Test('Facade aliases', @LCase.TestFacade_Aliases);
  LCase.Free;
  if not LSuite.Run then Halt(1);
end.
