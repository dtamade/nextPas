program bench_spatial;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  SysUtils,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.base,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.spatial,
  nextpas.core.audio.spatial.intf;

type
  TMemoryAudioSource = class(TInterfacedObject, IRealtimeAudioSource)
  private
    FFormat: TAudioFormat;
    FData: TBytes;
    FPos: Integer;
  public
    constructor Create(const AFormat: TAudioFormat; AFrames: Integer);
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
  end;

constructor TMemoryAudioSource.Create(const AFormat: TAudioFormat; AFrames: Integer);
var I: Integer; P: PSingle;
begin
  inherited Create;
  FFormat:=AFormat;
  SetLength(FData, AFrames*AFormat.BlockAlign);
  P:=PSingle(@FData[0]);
  for I:=0 to AFrames*AFormat.Channels-1 do P[I]:=Sin(I*0.01)*0.5;
  FPos:=0;
end;
function TMemoryAudioSource.GetFormat: TAudioFormat; begin Result:=FFormat; end;
function TMemoryAudioSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer; begin Result:=FillRealtime(ABuffer,AFrames); end;
function TMemoryAudioSource.SeekTo(AFrame: UInt64): Boolean; begin FPos:=Integer(AFrame); Result:=True; end;
function TMemoryAudioSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var N,Cpy: Integer;
begin
  N:=Length(FData) div FFormat.BlockAlign - FPos;
  if N<=0 then Exit(0);
  if AFrames<N then N:=AFrames;
  Cpy:=N*FFormat.BlockAlign;
  if Length(ABuffer.Data)>=Cpy then Move(FData[FPos*FFormat.BlockAlign],ABuffer.Data[0],Cpy);
  ABuffer.FrameCount:=N; Inc(FPos,N);
  if FPos>=Length(FData) div FFormat.BlockAlign then FPos:=0;
  Result:=N;
end;

var GSpatial1K, GSpatial4K: IAudioSpatialSource;
    GOut1K, GOut4K: TAudioBuffer;
    GSink: UInt64;
    GSrc: TMemoryAudioSource;

procedure BenchSpatial1K(const ACtx: IBenchContext);
begin
  GSpatial1K.FillRealtime(GOut1K,1024);
  GSink:=GSink xor UInt64(GOut1K.Data[0]);
end;

procedure BenchSpatial4K(const ACtx: IBenchContext);
begin
  GSpatial4K.FillRealtime(GOut4K,4096);
  GSink:=GSink xor UInt64(GOut4K.Data[0]);
end;

procedure BenchAttenuation(const ACtx: IBenchContext);
var V: Single;
begin
  V:=SpatialGainFromDistance(10,1,100,1);
  GSink:=GSink xor UInt64(Trunc(V*1000));
end;

var R: IBenchResults; Fmt: TAudioFormat; Lst: TAudioListener; Prm: TAudioSpatialParams;
begin
  Fmt:=AudioFormatCreate(48000,2,sfF32);
  GOut1K.Format:=Fmt; GOut1K.FrameCount:=1024; SetLength(GOut1K.Data,1024*Fmt.BlockAlign);
  GOut4K.Format:=Fmt; GOut4K.FrameCount:=4096; SetLength(GOut4K.Data,4096*Fmt.BlockAlign);
  GSrc:=TMemoryAudioSource.Create(Fmt,48000);
  Lst:=Default(TAudioListener);
  Prm:=Default(TAudioSpatialParams);
  Prm.Position.X:=10; Prm.Position.Y:=0; Prm.Position.Z:=0;
  GSpatial1K:=CreateSpatialSource(GSrc as IRealtimeAudioSource, Lst, Prm);
  GSpatial4K:=CreateSpatialSource(GSrc as IRealtimeAudioSource, Lst, Prm);
  GSink:=0;
  R:=TBenchSuite.Create('spatial')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Fill/1K', @BenchSpatial1K)
    .Add('Fill/4K', @BenchSpatial4K)
    .Add('Attenuation', @BenchAttenuation)
    .Run;
  WriteLn(R.PrintToConsole);
  WriteLn('ns/op spatial');
  WriteLn('MB/s spatial');
  ForceDirectories('build'); R.SaveToJSON('build/bench-spatial.json');
end.
