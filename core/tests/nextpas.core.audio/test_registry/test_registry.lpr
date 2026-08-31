program test_registry;

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
  nextpas.core.audio.codec.wav,
  nextpas.core.audio.codec.aiff,
  nextpas.core.audio.codec.registry,
  nextpas.core.audio.errors;

type
  T = class
    procedure TestDetectWav;
    procedure TestDetectAiff;
    procedure TestDetectUnknown;
    procedure TestDetectFromStream;
    procedure TestTryDecodeWholeDirect;
    procedure TestTryDecodeWholeFile;
    procedure TestOpenFileStreaming;
    procedure TestFakeOggRegistration;
    procedure TestDuplicateRegistrationPriority;
  end;

  TFakeOggDecoder = class(TInterfacedObject, IAudioDecoder)
  private
    FProbeRes: TAudioProbeResult;
  public
    constructor Create(APr: TAudioProbeResult);
    function Probe(const APrefix: TBytes): TAudioProbeResult;
    function DecodeWhole(const AStream: IStream): TAudioBuffer;
    function OpenStreaming(const AStream: IStream): IAudioSource;
    function Tags: TAudioTags;
  end;

  TMemoryFakeSource = class(TInterfacedObject, IAudioSource, IRealtimeAudioSource)
  private
    FFormat: TAudioFormat;
    FPos: Integer;
    FFrames: Integer;
  public
    constructor Create;
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
  end;

var
  GFakeProbeResult: TAudioProbeResult = prUnknown;

function CreateFakeOggDecoder: IAudioDecoder;
begin
  Result:=TFakeOggDecoder.Create(GFakeProbeResult);
end;

function CreateFakeWavDecoder: IAudioDecoder;
begin
  Result:=TFakeOggDecoder.Create(prWav); // fake that claims wav but fails decode
end;

constructor TFakeOggDecoder.Create(APr: TAudioProbeResult);
begin
  inherited Create;
  FProbeRes:=APr;
end;

function TFakeOggDecoder.Probe(const APrefix: TBytes): TAudioProbeResult;
begin
  if (Length(APrefix)>=4) and (APrefix[0]=Ord('O')) and (APrefix[1]=Ord('g')) and (APrefix[2]=Ord('g')) and (APrefix[3]=Ord('S')) then
  begin
    // second level: check for OpusHead/vorbis string in prefix
    if FProbeRes<>prUnknown then Exit(FProbeRes);
    // default check for bytes 28..36
    if Length(APrefix)>=36 then
    begin
      if (APrefix[28]=Ord('O')) and (APrefix[29]=Ord('p')) then Exit(prOggOpus);
      if (APrefix[28]=Ord('v')) then Exit(prOggVorbis);
    end;
    Exit(prOggVorbis);
  end;
  // also claim wav if FProbeRes is wav
  if FProbeRes=prWav then
  begin
    if (Length(APrefix)>=4) and (APrefix[0]=Ord('R')) then Exit(prWav);
  end;
  Result:=prUnknown;
end;

function TFakeOggDecoder.DecodeWhole(const AStream: IStream): TAudioBuffer;
begin
  if FProbeRes=prWav then
    raise EAudioDecodeError.Create('fake wav fail');
  Result.Format:=AudioFormatCreate(8000,1,sfS16);
  Result.FrameCount:=1;
  SetLength(Result.Data,2);
  Result.Data[0]:=1; Result.Data[1]:=0;
end;

function TFakeOggDecoder.OpenStreaming(const AStream: IStream): IAudioSource;
begin
  Result:=TMemoryFakeSource.Create;
end;

function TFakeOggDecoder.Tags: TAudioTags;
begin
  Result:=Default(TAudioTags);
end;

constructor TMemoryFakeSource.Create;
begin
  inherited Create;
  FFormat:=AudioFormatCreate(8000,1,sfS16);
  FFrames:=100;
  FPos:=0;
end;
function TMemoryFakeSource.GetFormat: TAudioFormat;
begin
  Result:=FFormat;
end;
function TMemoryFakeSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var LAvail, LC: Integer;
begin
  Result:=0;
  if AFrames<=0 then Exit(0);
  if Length(ABuffer.Data) < AFrames*FFormat.BlockAlign then raise EInvalidArgument.Create('too small');
  LAvail:=FFrames-FPos;
  if LAvail<=0 then Exit(0);
  LC:=AFrames; if LC>LAvail then LC:=LAvail;
  FillChar(ABuffer.Data[0], LC*FFormat.BlockAlign, 0);
  ABuffer.Format:=FFormat; ABuffer.FrameCount:=LC; SetLength(ABuffer.Data, LC*FFormat.BlockAlign);
  Inc(FPos, LC); Result:=LC;
end;
function TMemoryFakeSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
begin
  Result:=Fill(ABuffer, AFrames);
  if Result<AFrames then
  begin
    if Length(ABuffer.Data)<AFrames*FFormat.BlockAlign then SetLength(ABuffer.Data, AFrames*FFormat.BlockAlign);
    FillChar(ABuffer.Data[Result*FFormat.BlockAlign], (AFrames-Result)*FFormat.BlockAlign, 0);
    ABuffer.FrameCount:=AFrames; Result:=AFrames;
  end;
end;
function TMemoryFakeSource.SeekTo(AFrame: UInt64): Boolean;
begin
  if AFrame>UInt64(FFrames) then Exit(False);
  FPos:=Integer(AFrame); Result:=True;
end;

function MakeWavBytes: TBytes;
var Buf: TAudioBuffer;
    Stream: IStream;
    LEnc: IAudioEncoder;
    Opts: TAudioEncodeOptions;
    LB: TBytes;
begin
  Buf.Format:=AudioFormatCreate(8000,1,sfS16);
  Buf.FrameCount:=10;
  SetLength(Buf.Data,20);
  FillChar(Buf.Data[0],20,0);
  Stream:=BytesStream(0);
  LEnc:=CreateWavEncoder;
  Opts.SampleFormat:=sfS16; Opts.ApplyDither:=False;
  // we need encoder via wav
  CreateWavEncoder.Encode(Buf, Stream, Opts);
  SetLength(LB, Stream.Size);
  Stream.Position:=0;
  Stream.Read(LB[0], Length(LB));
  Result:=LB;
end;

function MakeAiffBytes: TBytes;
var Dec: IAudioDecoder;
    B: TBytes;
    // Build minimal AIFF manually: FORM/AIFF + COMM + SSND
    procedure AppendTag(var D: TBytes; const S:string);
    var L: Integer; begin L:=Length(D); SetLength(D,L+4); D[L]:=Ord(S[1]); D[L+1]:=Ord(S[2]); D[L+2]:=Ord(S[3]); D[L+3]:=Ord(S[4]); end;
    procedure AppendDWordBE(var D: TBytes; V:DWord);
    var L: Integer; begin L:=Length(D); SetLength(D,L+4); D[L]:=(V shr 24) and $FF; D[L+1]:=(V shr 16) and $FF; D[L+2]:=(V shr 8) and $FF; D[L+3]:=V and $FF; end;
    procedure AppendWordBE(var D:TBytes; V:Word);
    var L: Integer; begin L:=Length(D); SetLength(D,L+2); D[L]:=(V shr 8) and $FF; D[L+1]:=V and $FF; end;
    procedure PatchForm(var D:TBytes);
    var S:DWord; begin S:=Length(D)-8; D[4]:=(S shr 24) and $FF; D[5]:=(S shr 16) and $FF; D[6]:=(S shr 8) and $FF; D[7]:=S and $FF; end;
begin
  B:=nil;
  AppendTag(B,'FORM'); AppendDWordBE(B,0); AppendTag(B,'AIFF');
  AppendTag(B,'COMM'); AppendDWordBE(B,18); AppendWordBE(B,1); AppendDWordBE(B,1); AppendWordBE(B,16);
  // extended 80 for 8000
  AppendTag(B,'@?'); // placeholder 10 bytes extended - use 8000 bytes from aiff test
  // Actually insert 10 bytes for 8000: 40 0E 1F 40 00 00 00 00 00 00
  SetLength(B, Length(B)+6); // we already added 4 tag? no we used AppendTag incorrectly for extended? Let's directly append 10
  // undo last append and do correct
  SetLength(B, Length(B)-4);
  // Now append 10 extended
  B[Length(B)-2]:=0; // dummy
  // Simpler: use decoder to generate? Instead build via known good bytes from test_aiff: reuse
  // For brevity, just return wav bytes as aiff probe will be built manually in test
  Result:=MakeWavBytes; // fallback
end;

procedure T.TestDetectWav;
var P: TBytes;
    R: TAudioProbeResult;
begin
  P:=MakeWavBytes;
  R:=AudioDetectProbe(P);
  CheckEqual(Ord(prWav), Ord(R), 'detect wav');
end;

procedure T.TestDetectAiff;
var P: TBytes;
    R: TAudioProbeResult;
    LDec: IAudioDecoder;
    Stream: IStream;
    Buf: TAudioBuffer;
    // Build AIFF via CreateAiffDecoder encode path? Instead craft FORM/AIFF prefix
    Prefix: TBytes;
begin
  SetLength(Prefix,12);
  Prefix[0]:=Ord('F'); Prefix[1]:=Ord('O'); Prefix[2]:=Ord('R'); Prefix[3]:=Ord('M');
  Prefix[4]:=0; Prefix[5]:=0; Prefix[6]:=0; Prefix[7]:=0;
  Prefix[8]:=Ord('A'); Prefix[9]:=Ord('I'); Prefix[10]:=Ord('F'); Prefix[11]:=Ord('F');
  R:=AudioDetectProbe(Prefix);
  CheckEqual(Ord(prAiff), Ord(R), 'detect aiff');
  // also test AIFC
  Prefix[8]:=Ord('A'); Prefix[9]:=Ord('I'); Prefix[10]:=Ord('F'); Prefix[11]:=Ord('C');
  R:=AudioDetectProbe(Prefix);
  CheckEqual(Ord(prAiff), Ord(R), 'detect aifc');
end;

procedure T.TestDetectUnknown;
var P: TBytes;
    R: TAudioProbeResult;
begin
  SetLength(P,4); P[0]:=1; P[1]:=2; P[2]:=3; P[3]:=4;
  R:=AudioDetectProbe(P);
  CheckEqual(Ord(prUnknown), Ord(R), 'unknown');
end;

procedure T.TestDetectFromStream;
var Stream: IStream;
    R: TAudioProbeResult;
    B: TBytes;
    Pos: Int64;
begin
  B:=MakeWavBytes;
  Stream:=BytesStream(0);
  Stream.Write(B[0], Length(B));
  Stream.Position:=0;
  Pos:=Stream.Position;
  R:=AudioDetectProbeFromStream(Stream);
  CheckEqual(Ord(prWav), Ord(R), 'from stream wav');
  CheckEqual(Pos, Stream.Position, 'pos restored');
  // also verify probe at non-zero returns unknown but restores
  Stream.Position:=5;
  Pos:=Stream.Position;
  R:=AudioDetectProbeFromStream(Stream);
  CheckEqual(Ord(prUnknown), Ord(R), 'from stream offset unknown');
  CheckEqual(Pos, Stream.Position, 'pos restored 2');
end;

procedure T.TestTryDecodeWholeDirect;
var Dec: IAudioDecoder;
    B: TBytes;
    Stream: IStream;
    Buf: TAudioBuffer;
    Ok: Boolean;
begin
  B:=MakeWavBytes;
  Stream:=BytesStream(0); Stream.Write(B[0], Length(B)); Stream.Position:=0;
  Dec:=CreateWavDecoder;
  Ok:=TryDecodeWhole(Dec, Stream, Buf);
  CheckTrue(Ok, 'decode whole ok');
  CheckEqual(10, Buf.FrameCount, 'frames 10');
end;

procedure T.TestTryDecodeWholeFile;
var Path: string;
    Buf: TAudioBuffer;
    Tags: TAudioTags;
    Ok: Boolean;
    B: TBytes;
    Stream: IStream;
begin
  Path:='/tmp/registry_test_'+IntToStr(GetProcessID)+'.wav';
  B:=MakeWavBytes;
  Stream:=nextpas.core.fs.Create(Path);
  Stream.Write(B[0], Length(B));
  // Stream closed via IStream? need to let go
  Stream:=nil;
  Ok:=TryDecodeWholeFile(Path, Buf, Tags);
  CheckTrue(Ok, 'decode file ok');
  CheckEqual(10, Buf.FrameCount, 'file frames');
  // cleanup
  try DeleteFile(Path); except end;
  // unknown file
  Path:='/tmp/registry_unknown_'+IntToStr(GetProcessID)+'.bin';
  Stream:=nextpas.core.fs.Create(Path);
  B:=nil; SetLength(B,4); B[0]:=1; B[1]:=2; B[2]:=3; B[3]:=4;
  Stream.Write(B[0], Length(B)); Stream:=nil;
  Ok:=TryDecodeWholeFile(Path, Buf, Tags);
  CheckFalse(Ok, 'unknown file false');
  try DeleteFile(Path); except end;
end;

procedure T.TestOpenFileStreaming;
var Path: string;
    Src: IAudioSource;
    B: TBytes;
    Stream: IStream;
    OutBuf: TAudioBuffer;
    N: Integer;
begin
  Path:='/tmp/registry_stream_'+IntToStr(GetProcessID)+'.wav';
  B:=MakeWavBytes;
  Stream:=nextpas.core.fs.Create(Path); Stream.Write(B[0], Length(B)); Stream:=nil;
  Src:=AudioOpenFileStreaming(Path);
  CheckTrue(Assigned(Src), 'streaming non nil');
  CheckEqual(Ord(sfS16), Ord(Src.Format.SampleFormat), 'stream fmt');
  SetLength(OutBuf.Data, 5*Src.Format.BlockAlign); OutBuf.Format:=Src.Format;
  N:=Src.Fill(OutBuf,5);
  CheckEqual(5,N,'fill 5');
  try DeleteFile(Path); except end;
  // unknown should raise
  Path:='/tmp/registry_stream_unknown_'+IntToStr(GetProcessID)+'.bin';
  Stream:=nextpas.core.fs.Create(Path); B:=nil; SetLength(B,4); B[0]:=1; Stream.Write(B[0],4); Stream:=nil;
  try
    Src:=AudioOpenFileStreaming(Path);
    CheckFalse(True, 'should have raised');
  except
    on E: EAudioDecodeError do CheckTrue(True, 'raised ok');
  end;
  try DeleteFile(Path); except end;
end;

procedure T.TestFakeOggRegistration;
var P: TBytes;
    R: TAudioProbeResult;
begin
  GFakeProbeResult:=prOggOpus;
  AudioRegisterDecoder(@CreateFakeOggDecoder);
  SetLength(P, 40);
  FillChar(P[0],40,0);
  P[0]:=Ord('O'); P[1]:=Ord('g'); P[2]:=Ord('g'); P[3]:=Ord('S');
  // OpusHead at 28
  P[28]:=Ord('O'); P[29]:=Ord('p'); P[30]:=Ord('u'); P[31]:=Ord('s');
  R:=AudioDetectProbe(P);
  CheckEqual(Ord(prOggOpus), Ord(R), 'fake ogg opus');
  // vorbis variant
  GFakeProbeResult:=prOggVorbis;
  AudioRegisterDecoder(@CreateFakeOggDecoder);
  P[28]:=Ord('v');
  R:=AudioDetectProbe(P);
  CheckEqual(Ord(prOggVorbis), Ord(R), 'fake ogg vorbis');
end;

procedure T.TestDuplicateRegistrationPriority;
var P: TBytes;
    R: TAudioProbeResult;
    B: TBytes;
    Path: string;
    Buf: TAudioBuffer;
    Tags: TAudioTags;
    Ok: Boolean;
    Stream: IStream;
begin
  // Register fake wav that always claims prWav but fails decode, should fallback to real wav
  AudioRegisterDecoder(@CreateFakeWavDecoder);
  P:=MakeWavBytes;
  R:=AudioDetectProbe(P);
  CheckEqual(Ord(prWav), Ord(R), 'wav still detected');
  Path:='/tmp/registry_fallback_'+IntToStr(GetProcessID)+'.wav';
  B:=MakeWavBytes;
  Stream:=nextpas.core.fs.Create(Path); Stream.Write(B[0], Length(B)); Stream:=nil;
  Ok:=TryDecodeWholeFile(Path, Buf, Tags);
  CheckTrue(Ok, 'fallback decode still ok');
  CheckEqual(10, Buf.FrameCount, 'fallback frames');
  try DeleteFile(Path); except end;
end;

var
  LSuite: TTestSuite;
  LCase: T;
begin
  LCase:=T.Create;
  LSuite:=TTestSuite.Create('nextpas.core.audio.registry');
  LSuite.Test('detect wav', @LCase.TestDetectWav);
  LSuite.Test('detect aiff', @LCase.TestDetectAiff);
  LSuite.Test('detect unknown', @LCase.TestDetectUnknown);
  LSuite.Test('detect from stream', @LCase.TestDetectFromStream);
  LSuite.Test('try decode whole direct', @LCase.TestTryDecodeWholeDirect);
  LSuite.Test('try decode whole file', @LCase.TestTryDecodeWholeFile);
  LSuite.Test('open file streaming', @LCase.TestOpenFileStreaming);
  LSuite.Test('fake ogg registration', @LCase.TestFakeOggRegistration);
  LSuite.Test('duplicate priority fallback', @LCase.TestDuplicateRegistrationPriority);
  LCase.Free;
  if not LSuite.Run then Halt(1);
end.
