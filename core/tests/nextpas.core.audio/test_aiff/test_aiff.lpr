program test_aiff;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.io,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.codec.intf,
  nextpas.core.audio.codec.aiff,
  nextpas.core.audio.errors;

type
  T = class
    procedure TestProbe;
    procedure TestMono16_8000_10Frames;
    procedure TestStereo24_44100_5Frames;
    procedure TestMonoFloat32_AifcFl32;
    procedure TestSowtLittle;
    procedure TestSsndOffset;
    procedure TestRejectTruncatedComm;
    procedure TestRejectUnknownCompression;
    procedure TestRejectTruncatedSsnd;
    procedure TestStreaming;
    procedure TestExtendedRate48000;
  end;

var
  GEmpty: TBytes;

procedure AppendTag(var ABytes: TBytes; const ATag: string);
var
  LOld: Integer;
begin
  LOld := Length(ABytes);
  SetLength(ABytes, LOld + 4);
  ABytes[LOld] := Ord(ATag[1]);
  ABytes[LOld + 1] := Ord(ATag[2]);
  ABytes[LOld + 2] := Ord(ATag[3]);
  ABytes[LOld + 3] := Ord(ATag[4]);
end;

procedure AppendWordBE(var ABytes: TBytes; AValue: Word);
var
  LOld: Integer;
begin
  LOld := Length(ABytes);
  SetLength(ABytes, LOld + 2);
  ABytes[LOld] := (AValue shr 8) and $FF;
  ABytes[LOld + 1] := AValue and $FF;
end;

procedure AppendDWordBE(var ABytes: TBytes; AValue: DWord);
var
  LOld: Integer;
begin
  LOld := Length(ABytes);
  SetLength(ABytes, LOld + 4);
  ABytes[LOld] := (AValue shr 24) and $FF;
  ABytes[LOld + 1] := (AValue shr 16) and $FF;
  ABytes[LOld + 2] := (AValue shr 8) and $FF;
  ABytes[LOld + 3] := AValue and $FF;
end;

procedure AppendByte(var ABytes: TBytes; AValue: Byte);
var
  LOld: Integer;
begin
  LOld := Length(ABytes);
  SetLength(ABytes, LOld + 1);
  ABytes[LOld] := AValue;
end;

procedure AppendBytes(var ABytes: TBytes; const AData: TBytes);
var
  LOld, LI: Integer;
begin
  if Length(AData) = 0 then Exit;
  LOld := Length(ABytes);
  SetLength(ABytes, LOld + Length(AData));
  for LI := 0 to High(AData) do
    ABytes[LOld + LI] := AData[LI];
end;

procedure AppendExtended80(var ABytes: TBytes; ARate: Integer);
var
  LOld: Integer;
begin
  LOld := Length(ABytes);
  SetLength(ABytes, LOld + 10);
  case ARate of
    8000:
      begin
        ABytes[LOld] := $40; ABytes[LOld+1] := $0E;
        ABytes[LOld+2] := $1F; ABytes[LOld+3] := $40;
        ABytes[LOld+4] := $00; ABytes[LOld+5] := $00;
        ABytes[LOld+6] := $00; ABytes[LOld+7] := $00;
        ABytes[LOld+8] := $00; ABytes[LOld+9] := $00;
      end;
    44100:
      begin
        ABytes[LOld] := $40; ABytes[LOld+1] := $0E;
        ABytes[LOld+2] := $AC; ABytes[LOld+3] := $44;
        ABytes[LOld+4] := $00; ABytes[LOld+5] := $00;
        ABytes[LOld+6] := $00; ABytes[LOld+7] := $00;
        ABytes[LOld+8] := $00; ABytes[LOld+9] := $00;
      end;
    48000:
      begin
        ABytes[LOld] := $40; ABytes[LOld+1] := $0E;
        ABytes[LOld+2] := $BB; ABytes[LOld+3] := $80;
        ABytes[LOld+4] := $00; ABytes[LOld+5] := $00;
        ABytes[LOld+6] := $00; ABytes[LOld+7] := $00;
        ABytes[LOld+8] := $00; ABytes[LOld+9] := $00;
      end;
  else
    begin
      // fallback to 44100
      ABytes[LOld] := $40; ABytes[LOld+1] := $0E;
      ABytes[LOld+2] := $AC; ABytes[LOld+3] := $44;
      ABytes[LOld+4] := $00; ABytes[LOld+5] := $00;
      ABytes[LOld+6] := $00; ABytes[LOld+7] := $00;
      ABytes[LOld+8] := $00; ABytes[LOld+9] := $00;
    end;
  end;
end;

procedure PatchFormSize(var ABytes: TBytes);
var
  LSize: DWord;
begin
  LSize := DWord(Length(ABytes) - 8);
  ABytes[4] := (LSize shr 24) and $FF;
  ABytes[5] := (LSize shr 16) and $FF;
  ABytes[6] := (LSize shr 8) and $FF;
  ABytes[7] := LSize and $FF;
end;

function StreamFromBytes(const ABytes: TBytes): IStream;
var
  LStream: IStream;
begin
  LStream := BytesStream(0);
  if Length(ABytes) > 0 then
    LStream.Write(ABytes[0], Length(ABytes));
  LStream.Position := 0;
  Result := LStream;
end;

procedure BuildAiffHeader(var ABytes: TBytes; const AFormType: string);
begin
  AppendTag(ABytes, 'FORM');
  AppendDWordBE(ABytes, 0); // placeholder
  AppendTag(ABytes, AFormType);
end;

procedure BuildCommAIFF(var ABytes: TBytes; AChannels: Word; ANumFrames: DWord; ASampleSize: Word; ARate: Integer);
begin
  AppendTag(ABytes, 'COMM');
  AppendDWordBE(ABytes, 18);
  AppendWordBE(ABytes, AChannels);
  AppendDWordBE(ABytes, ANumFrames);
  AppendWordBE(ABytes, ASampleSize);
  AppendExtended80(ABytes, ARate);
end;

procedure BuildCommAIFC(var ABytes: TBytes; AChannels: Word; ANumFrames: DWord; ASampleSize: Word; ARate: Integer; const ACompType: string; const ACompName: string);
var
  LNameLen: Integer;
  LPad: Integer;
  LSize: DWord;
  LI: Integer;
begin
  // ACompType must be 4 chars
  LNameLen := Length(ACompName);
  // size = 2+4+2+10+4+1+LNameLen+pad
  LSize := 2+4+2+10+4+1+DWord(LNameLen);
  if ((1 + LNameLen) and 1) <> 0 then Inc(LSize);
  AppendTag(ABytes, 'COMM');
  AppendDWordBE(ABytes, LSize);
  AppendWordBE(ABytes, AChannels);
  AppendDWordBE(ABytes, ANumFrames);
  AppendWordBE(ABytes, ASampleSize);
  AppendExtended80(ABytes, ARate);
  AppendTag(ABytes, ACompType);
  AppendByte(ABytes, Byte(LNameLen));
  for LI := 1 to LNameLen do
    AppendByte(ABytes, Ord(ACompName[LI]));
  if ((1 + LNameLen) and 1) <> 0 then
    AppendByte(ABytes, 0);
end;

procedure BuildSSND(var ABytes: TBytes; AOffset, ABlockSize: DWord; const AData: TBytes; const AFiller: TBytes);
var
  LPayloadSize: DWord;
  LPad: Integer;
begin
  AppendTag(ABytes, 'SSND');
  LPayloadSize := 8 + DWord(Length(AFiller)) + DWord(Length(AData));
  AppendDWordBE(ABytes, LPayloadSize);
  AppendDWordBE(ABytes, AOffset);
  AppendDWordBE(ABytes, ABlockSize);
  if Length(AFiller) > 0 then
    AppendBytes(ABytes, AFiller);
  if Length(AData) > 0 then
    AppendBytes(ABytes, AData);
  LPad := LPayloadSize and 1;
  if LPad <> 0 then
    AppendByte(ABytes, 0);
end;

procedure T.TestProbe;
var
  LPrefix: TBytes;
  LDec: IAudioDecoder;
begin
  SetLength(LPrefix, 12);
  LPrefix[0]:=Ord('F'); LPrefix[1]:=Ord('O'); LPrefix[2]:=Ord('R'); LPrefix[3]:=Ord('M');
  LPrefix[4]:=0; LPrefix[5]:=0; LPrefix[6]:=0; LPrefix[7]:=0;
  LPrefix[8]:=Ord('A'); LPrefix[9]:=Ord('I'); LPrefix[10]:=Ord('F'); LPrefix[11]:=Ord('F');
  CheckEqual(Ord(prAiff), Ord(AiffProbe(LPrefix)), 'probe FORM AIFF');
  LDec := CreateAiffDecoder;
  CheckEqual(Ord(prAiff), Ord(LDec.Probe(LPrefix)), 'decoder probe AIFF');

  LPrefix[8]:=Ord('A'); LPrefix[9]:=Ord('I'); LPrefix[10]:=Ord('F'); LPrefix[11]:=Ord('C');
  CheckEqual(Ord(prAiff), Ord(AiffProbe(LPrefix)), 'probe FORM AIFC');
  CheckEqual(Ord(prAiff), Ord(LDec.Probe(LPrefix)), 'decoder probe AIFC');

  SetLength(LPrefix,12);
  LPrefix[0]:=Ord('R'); LPrefix[1]:=Ord('I'); LPrefix[2]:=Ord('F'); LPrefix[3]:=Ord('F');
  LPrefix[4]:=0; LPrefix[5]:=0; LPrefix[6]:=0; LPrefix[7]:=0;
  LPrefix[8]:=Ord('W'); LPrefix[9]:=Ord('A'); LPrefix[10]:=Ord('V'); LPrefix[11]:=Ord('E');
  CheckEqual(Ord(prUnknown), Ord(AiffProbe(LPrefix)), 'probe RIFF WAVE unknown');
  CheckEqual(Ord(prUnknown), Ord(LDec.Probe(LPrefix)), 'decoder probe unknown WAVE');

  SetLength(LPrefix,4);
  LPrefix[0]:=0; LPrefix[1]:=1; LPrefix[2]:=2; LPrefix[3]:=3;
  CheckEqual(Ord(prUnknown), Ord(AiffProbe(LPrefix)), 'probe truncated unknown');
end;

procedure T.TestMono16_8000_10Frames;
var
  LBytes, LDataBE: TBytes;
  LI, LVal: Integer;
  LStream: IStream;
  LDec: IAudioDecoder;
  LBuf: TAudioBuffer;
begin
  SetLength(LDataBE, 20);
  for LI := 0 to 9 do
  begin
    LVal := LI * 100;
    // BE 16bit
    LDataBE[LI*2] := (LVal shr 8) and $FF;
    LDataBE[LI*2+1] := LVal and $FF;
  end;
  LBytes := nil;
  BuildAiffHeader(LBytes, 'AIFF');
  BuildCommAIFF(LBytes, 1, 10, 16, 8000);
  BuildSSND(LBytes, 0, 0, LDataBE, GEmpty);
  PatchFormSize(LBytes);
  LStream := StreamFromBytes(LBytes);
  LDec := CreateAiffDecoder;
  LBuf := LDec.DecodeWhole(LStream);
  CheckEqual(8000, LBuf.Format.SampleRate, 'mono16 rate');
  CheckEqual(1, LBuf.Format.Channels, 'mono16 ch');
  CheckEqual(Ord(sfS16), Ord(LBuf.Format.SampleFormat), 'mono16 fmt');
  CheckEqual(10, LBuf.FrameCount, 'mono16 frames');
  CheckEqual(2, LBuf.Format.BlockAlign, 'mono16 blockAlign');
  CheckEqual(20, Length(LBuf.Data), 'mono16 data len');
  for LI := 0 to 9 do
  begin
    LVal := LI * 100;
    CheckEqual(Int64(LVal), Int64(SmallInt(PWord(@LBuf.Data[LI*2])^)), 'mono16 sample '+IntToStr(LI));
  end;
end;

procedure T.TestStereo24_44100_5Frames;
var
  LBytes, LDataBE: TBytes;
  LI, LSampleIdx, LVal: Integer;
  LStream: IStream;
  LDec: IAudioDecoder;
  LBuf: TAudioBuffer;
  LB0, LB1, LB2: Byte;
begin
  // 5 frames *2 ch =10 samples, 3 bytes each =>30 bytes
  SetLength(LDataBE, 30);
  for LSampleIdx := 0 to 9 do
  begin
    LVal := (LSampleIdx+1)*1000; // avoid zero confusion
    LB0 := (LVal shr 16) and $FF;
    LB1 := (LVal shr 8) and $FF;
    LB2 := LVal and $FF;
    LDataBE[LSampleIdx*3] := LB0;
    LDataBE[LSampleIdx*3+1] := LB1;
    LDataBE[LSampleIdx*3+2] := LB2;
  end;
  LBytes := nil;
  BuildAiffHeader(LBytes, 'AIFF');
  BuildCommAIFF(LBytes, 2, 5, 24, 44100);
  BuildSSND(LBytes, 0, 0, LDataBE, GEmpty);
  PatchFormSize(LBytes);
  LStream := StreamFromBytes(LBytes);
  LDec := CreateAiffDecoder;
  LBuf := LDec.DecodeWhole(LStream);
  CheckEqual(44100, LBuf.Format.SampleRate, 'stereo24 rate');
  CheckEqual(2, LBuf.Format.Channels, 'stereo24 ch');
  CheckEqual(Ord(sfS24), Ord(LBuf.Format.SampleFormat), 'stereo24 fmt');
  CheckEqual(5, LBuf.FrameCount, 'stereo24 frames');
  CheckEqual(6, LBuf.Format.BlockAlign, 'stereo24 blockAlign');
  CheckEqual(30, Length(LBuf.Data), 'stereo24 data len');
  for LSampleIdx := 0 to 9 do
  begin
    LVal := (LSampleIdx+1)*1000;
    LB0 := (LVal shr 16) and $FF;
    LB1 := (LVal shr 8) and $FF;
    LB2 := LVal and $FF;
    // decoded LE should be B2,B1,B0 swapped
    CheckEqual(Int64(LB2), Int64(LBuf.Data[LSampleIdx*3]), 'stereo24 b2 '+IntToStr(LSampleIdx));
    CheckEqual(Int64(LB1), Int64(LBuf.Data[LSampleIdx*3+1]), 'stereo24 b1 '+IntToStr(LSampleIdx));
    CheckEqual(Int64(LB0), Int64(LBuf.Data[LSampleIdx*3+2]), 'stereo24 b0 '+IntToStr(LSampleIdx));
  end;
end;

procedure T.TestMonoFloat32_AifcFl32;
var
  LBytes, LDataBE: TBytes;
  LStream: IStream;
  LDec: IAudioDecoder;
  LBuf: TAudioBuffer;
begin
  // 0.5 BE = 3F 00 00 00 ; LE = 00 00 00 3F
  SetLength(LDataBE, 4);
  LDataBE[0]:=$3F; LDataBE[1]:=$00; LDataBE[2]:=$00; LDataBE[3]:=$00;
  LBytes := nil;
  BuildAiffHeader(LBytes, 'AIFC');
  BuildCommAIFC(LBytes, 1, 1, 32, 44100, 'fl32', '');
  BuildSSND(LBytes, 0, 0, LDataBE, GEmpty);
  PatchFormSize(LBytes);
  LStream := StreamFromBytes(LBytes);
  LDec := CreateAiffDecoder;
  LBuf := LDec.DecodeWhole(LStream);
  CheckEqual(44100, LBuf.Format.SampleRate, 'fl32 rate');
  CheckEqual(1, LBuf.Format.Channels, 'fl32 ch');
  CheckEqual(Ord(sfF32), Ord(LBuf.Format.SampleFormat), 'fl32 fmt');
  CheckEqual(1, LBuf.FrameCount, 'fl32 frames');
  CheckEqual(4, LBuf.Format.BlockAlign, 'fl32 blockAlign');
  CheckEqual(4, Length(LBuf.Data), 'fl32 data len');
  CheckEqual(Int64($00), Int64(LBuf.Data[0]), 'fl32 le0');
  CheckEqual(Int64($00), Int64(LBuf.Data[1]), 'fl32 le1');
  CheckEqual(Int64($00), Int64(LBuf.Data[2]), 'fl32 le2');
  CheckEqual(Int64($3F), Int64(LBuf.Data[3]), 'fl32 le3');
end;

procedure T.TestSowtLittle;
var
  LBytes, LDataLE: TBytes;
  LStream: IStream;
  LDec: IAudioDecoder;
  LBuf: TAudioBuffer;
begin
  // value $0102 little = bytes 02 01, should stay 02 01 after decode (no swap)
  SetLength(LDataLE, 2);
  LDataLE[0]:=$02; LDataLE[1]:=$01;
  LBytes := nil;
  BuildAiffHeader(LBytes, 'AIFC');
  BuildCommAIFC(LBytes, 1, 1, 16, 44100, 'sowt', '');
  BuildSSND(LBytes, 0, 0, LDataLE, GEmpty);
  PatchFormSize(LBytes);
  LStream := StreamFromBytes(LBytes);
  LDec := CreateAiffDecoder;
  LBuf := LDec.DecodeWhole(LStream);
  CheckEqual(Ord(sfS16), Ord(LBuf.Format.SampleFormat), 'sowt fmt');
  CheckEqual(1, LBuf.FrameCount, 'sowt frames');
  CheckEqual(2, Length(LBuf.Data), 'sowt len');
  CheckEqual(Int64($02), Int64(LBuf.Data[0]), 'sowt byte0 no swap');
  CheckEqual(Int64($01), Int64(LBuf.Data[1]), 'sowt byte1 no swap');
end;

procedure T.TestSsndOffset;
var
  LBytes, LDataBE, LFiller: TBytes;
  LI, LVal: Integer;
  LStream: IStream;
  LDec: IAudioDecoder;
  LBuf: TAudioBuffer;
begin
  SetLength(LDataBE, 20);
  for LI := 0 to 9 do
  begin
    LVal := LI*100;
    LDataBE[LI*2] := (LVal shr 8) and $FF;
    LDataBE[LI*2+1] := LVal and $FF;
  end;
  SetLength(LFiller, 4);
  LFiller[0]:=$AA; LFiller[1]:=$BB; LFiller[2]:=$CC; LFiller[3]:=$DD;
  LBytes := nil;
  BuildAiffHeader(LBytes, 'AIFF');
  BuildCommAIFF(LBytes, 1, 10, 16, 8000);
  BuildSSND(LBytes, 4, 0, LDataBE, LFiller);
  PatchFormSize(LBytes);
  LStream := StreamFromBytes(LBytes);
  LDec := CreateAiffDecoder;
  LBuf := LDec.DecodeWhole(LStream);
  CheckEqual(10, LBuf.FrameCount, 'offset frames');
  CheckEqual(20, Length(LBuf.Data), 'offset data len');
  for LI := 0 to 9 do
  begin
    LVal := LI*100;
    CheckEqual(Int64(LVal), Int64(SmallInt(PWord(@LBuf.Data[LI*2])^)), 'offset sample '+IntToStr(LI));
  end;
end;

procedure T.TestRejectTruncatedComm;
var
  LBytes: TBytes;
  LStream: IStream;
  LDec: IAudioDecoder;
  LBuf: TAudioBuffer;
  LCaught: Boolean;
begin
  // COMM size too small (10 <18)
  LBytes := nil;
  BuildAiffHeader(LBytes, 'AIFF');
  AppendTag(LBytes, 'COMM');
  AppendDWordBE(LBytes, 10);
  AppendWordBE(LBytes, 1);
  AppendDWordBE(LBytes, 10);
  AppendWordBE(LBytes, 16);
  AppendByte(LBytes, $40); AppendByte(LBytes, $0E); AppendByte(LBytes, $1F); AppendByte(LBytes, $40);
  // pad COMM chunk to even if needed? size 10 already even
  // SSND anyway
  SetLength(LBytes, Length(LBytes)); // no extra
  AppendTag(LBytes, 'SSND');
  AppendDWordBE(LBytes, 8+20);
  AppendDWordBE(LBytes, 0);
  AppendDWordBE(LBytes, 0);
  AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0);
  AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0);
  AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0);
  AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0); AppendByte(LBytes, 0);
  PatchFormSize(LBytes);
  LStream := StreamFromBytes(LBytes);
  LDec := CreateAiffDecoder;
  LCaught := False;
  try
    LBuf := LDec.DecodeWhole(LStream);
  except
    on E: EAudioDecodeError do LCaught := True;
    on E: Exception do LCaught := False;
  end;
  CheckTrue(LCaught, 'reject truncated COMM');
  // also test channel 0 case
  LBytes := nil;
  BuildAiffHeader(LBytes, 'AIFF');
  BuildCommAIFF(LBytes, 0, 10, 16, 8000);
  AppendTag(LBytes, 'SSND');
  AppendDWordBE(LBytes, 8);
  AppendDWordBE(LBytes, 0);
  AppendDWordBE(LBytes, 0);
  PatchFormSize(LBytes);
  LStream := StreamFromBytes(LBytes);
  LCaught := False;
  try
    LBuf := LDec.DecodeWhole(LStream);
  except
    on E: EAudioDecodeError do LCaught := True;
  end;
  CheckTrue(LCaught, 'reject COMM channels 0');
end;

procedure T.TestRejectUnknownCompression;
var
  LBytes, LData: TBytes;
  LStream: IStream;
  LDec: IAudioDecoder;
  LBuf: TAudioBuffer;
  LCaught: Boolean;
begin
  SetLength(LData, 4);
  LData[0]:=0; LData[1]:=0; LData[2]:=0; LData[3]:=0;
  LBytes := nil;
  BuildAiffHeader(LBytes, 'AIFC');
  BuildCommAIFC(LBytes, 1, 1, 8, 44100, 'ULAW', '');
  BuildSSND(LBytes, 0, 0, LData, GEmpty);
  PatchFormSize(LBytes);
  LStream := StreamFromBytes(LBytes);
  LDec := CreateAiffDecoder;
  LCaught := False;
  try
    LBuf := LDec.DecodeWhole(LStream);
  except
    on E: EAudioDecodeError do LCaught := True;
  end;
  CheckTrue(LCaught, 'reject unknown compression ULAW');
end;

procedure T.TestRejectTruncatedSsnd;
var
  LBytes, LDataBE: TBytes;
  LStream: IStream;
  LDec: IAudioDecoder;
  LBuf: TAudioBuffer;
  LCaught: Boolean;
begin
  // declare 10 frames but only 2 frames data (4 bytes)
  SetLength(LDataBE, 4);
  LDataBE[0]:=$00; LDataBE[1]:=$64; LDataBE[2]:=$00; LDataBE[3]:=$C8; // dummy 100,200 BE
  LBytes := nil;
  BuildAiffHeader(LBytes, 'AIFF');
  BuildCommAIFF(LBytes, 1, 10, 16, 8000);
  BuildSSND(LBytes, 0, 0, LDataBE, GEmpty);
  PatchFormSize(LBytes);
  LStream := StreamFromBytes(LBytes);
  LDec := CreateAiffDecoder;
  LCaught := False;
  try
    LBuf := LDec.DecodeWhole(LStream);
  except
    on E: EAudioDecodeError do LCaught := True;
  end;
  CheckTrue(LCaught, 'reject truncated SSND mismatch');
end;

procedure T.TestStreaming;
var
  LBytes, LDataBE: TBytes;
  LI, LVal: Integer;
  LStream: IStream;
  LDec: IAudioDecoder;
  LWhole, LOut: TAudioBuffer;
  LSrc: IAudioSource;
  LFrames: Integer;
begin
  SetLength(LDataBE, 20);
  for LI := 0 to 9 do
  begin
    LVal := LI*100;
    LDataBE[LI*2] := (LVal shr 8) and $FF;
    LDataBE[LI*2+1] := LVal and $FF;
  end;
  LBytes := nil;
  BuildAiffHeader(LBytes, 'AIFF');
  BuildCommAIFF(LBytes, 1, 10, 16, 8000);
  BuildSSND(LBytes, 0, 0, LDataBE, GEmpty);
  PatchFormSize(LBytes);
  LStream := StreamFromBytes(LBytes);
  LDec := CreateAiffDecoder;
  LWhole := LDec.DecodeWhole(LStream);
  LStream.Position := 0;
  LSrc := LDec.OpenStreaming(LStream);
  CheckEqual(LWhole.Format.SampleRate, LSrc.Format.SampleRate, 'stream rate');
  CheckEqual(LWhole.Format.Channels, LSrc.Format.Channels, 'stream ch');
  CheckEqual(Ord(LWhole.Format.SampleFormat), Ord(LSrc.Format.SampleFormat), 'stream fmt');
  // Fill 10 at once
  SetLength(LOut.Data, 10 * LSrc.Format.BlockAlign);
  LOut.Format := LSrc.Format;
  LFrames := LSrc.Fill(LOut, 10);
  CheckEqual(10, LFrames, 'stream fill 10');
  CheckEqual(10, LOut.FrameCount, 'stream out frames 10');
  CheckEqual(Length(LWhole.Data), Length(LOut.Data), 'stream data len');
  CheckTrue(Length(LWhole.Data)=Length(LOut.Data), 'stream data equal len');
  for LI:=0 to High(LWhole.Data) do CheckEqual(Int64(LWhole.Data[LI]), Int64(LOut.Data[LI]), 'stream byte '+IntToStr(LI));
  // SeekTo(0) and refill piecewise
  CheckTrue(LSrc.SeekTo(0), 'stream seek 0');
  SetLength(LOut.Data, 5 * LSrc.Format.BlockAlign);
  LOut.Format := LSrc.Format;
  LFrames := LSrc.Fill(LOut, 5);
  CheckEqual(5, LFrames, 'stream fill 5 after seek');
  CheckEqual(5, LOut.FrameCount, 'stream out 5');
  // remaining 5
  SetLength(LOut.Data, 5 * LSrc.Format.BlockAlign);
  LOut.Format := LSrc.Format;
  LFrames := LSrc.Fill(LOut, 5);
  CheckEqual(5, LFrames, 'stream fill remaining 5');
  // seek again and fill again full to verify repeatable
  CheckTrue(LSrc.SeekTo(0), 'stream seek 0 again');
  SetLength(LOut.Data, 10 * LSrc.Format.BlockAlign);
  LOut.Format := LSrc.Format;
  LFrames := LSrc.Fill(LOut, 10);
  CheckEqual(10, LFrames, 'stream fill 10 again');
  CheckTrue(Length(LWhole.Data)=Length(LOut.Data), 'stream data equal len again');
  for LI:=0 to High(LWhole.Data) do CheckEqual(Int64(LWhole.Data[LI]), Int64(LOut.Data[LI]), 'stream byte2 '+IntToStr(LI));
end;

procedure T.TestExtendedRate48000;
var
  LBytes, LDataBE: TBytes;
  LStream: IStream;
  LDec: IAudioDecoder;
  LBuf: TAudioBuffer;
begin
  SetLength(LDataBE, 2);
  LDataBE[0]:=$01; LDataBE[1]:=$02; // dummy sample $0102 BE
  LBytes := nil;
  BuildAiffHeader(LBytes, 'AIFF');
  BuildCommAIFF(LBytes, 1, 1, 16, 48000);
  BuildSSND(LBytes, 0, 0, LDataBE, GEmpty);
  PatchFormSize(LBytes);
  LStream := StreamFromBytes(LBytes);
  LDec := CreateAiffDecoder;
  LBuf := LDec.DecodeWhole(LStream);
  CheckEqual(48000, LBuf.Format.SampleRate, 'ext 48000 rate');
  CheckEqual(1, LBuf.FrameCount, 'ext 48000 frames');
  // decoded LE should be 02 01
  CheckEqual(Int64($02), Int64(LBuf.Data[0]), 'ext 48000 b0');
  CheckEqual(Int64($01), Int64(LBuf.Data[1]), 'ext 48000 b1');
end;

var
  LSuite: TTestSuite;
  LCase: T;

begin
  LCase := T.Create;
  LSuite := TTestSuite.Create('nextpas.core.audio.aiff');
  LSuite.Test('probe_aiff', @LCase.TestProbe);
  LSuite.Test('mono16 8000 10frames', @LCase.TestMono16_8000_10Frames);
  LSuite.Test('stereo24 44100 5frames', @LCase.TestStereo24_44100_5Frames);
  LSuite.Test('mono float32 AIFC fl32', @LCase.TestMonoFloat32_AifcFl32);
  LSuite.Test('sowt little', @LCase.TestSowtLittle);
  LSuite.Test('ssnd offset', @LCase.TestSsndOffset);
  LSuite.Test('reject truncated COMM', @LCase.TestRejectTruncatedComm);
  LSuite.Test('reject unknown compression', @LCase.TestRejectUnknownCompression);
  LSuite.Test('reject truncated SSND', @LCase.TestRejectTruncatedSsnd);
  LSuite.Test('streaming', @LCase.TestStreaming);
  LSuite.Test('extended rate 48000', @LCase.TestExtendedRate48000);
  LCase.Free;
  if not LSuite.Run then Halt(1);
end.
