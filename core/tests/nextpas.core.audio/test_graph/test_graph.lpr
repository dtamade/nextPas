program test_graph;
{$mode objfpc}{$H+}
uses
  nextpas.core.exception,
  nextpas.core.base, nextpas.core.test,
  nextpas.core.audio.base, nextpas.core.audio.intf,
  nextpas.core.audio.graph.intf, nextpas.core.audio.graph, nextpas.core.audio.player,
  nextpas.core.audio.device.intf, nextpas.core.audio.device.null,
  nextpas.core.audio;

type
  TConstSource = class(TInterfacedObject, IRealtimeAudioSource, IAudioSource)
  private FFormat: TAudioFormat; FValue: Single;
  public constructor Create(const AFormat: TAudioFormat; AValue: Single);
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
  end;

  TGainProcessor = class(TInterfacedObject, IAudioProcessor)
  private FGain: Single;
  public constructor Create(AGain: Single);
    function LatencyFrames: Integer;
    procedure Process(const AInput: TAudioBuffer; out AOutput: TAudioBuffer);
    procedure Reset;
  end;

  T = class
    procedure TestCreateValid;
    procedure TestCreateInvalidThrows;
    procedure TestAddSourceMismatchThrows;
    procedure TestMixTwoSources;
    procedure TestSetGain;
    procedure TestRemoveSource;
    procedure TestNodeCount;
    procedure TestProcessorChain;
    procedure TestRemoveProcessor;
    procedure TestGraphViaDevice;
    procedure TestClear;
    procedure TestSeek;
    procedure TestPlayerCreate;
    procedure TestPlayerPlayPauseStop;
    procedure TestPlayerVolume;
    procedure TestFacadeHelpers;
  end;

constructor TConstSource.Create(const AFormat: TAudioFormat; AValue: Single);
begin inherited Create; FFormat:=AFormat; FValue:=AValue; end;
function TConstSource.GetFormat: TAudioFormat; begin Result:=FFormat; end;
function TConstSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer; begin Result:=FillRealtime(ABuffer, AFrames); end;
function TConstSource.SeekTo(AFrame: UInt64): Boolean; begin Result:=True; end;
function TConstSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var I: Integer; P: PSingle;
begin
  if Length(ABuffer.Data) < AFrames*FFormat.BlockAlign then Exit(0);
  P:=PSingle(@ABuffer.Data[0]);
  for I:=0 to AFrames*FFormat.Channels-1 do P[I]:=FValue;
  ABuffer.FrameCount:=AFrames;
  Result:=AFrames;
end;

constructor TGainProcessor.Create(AGain: Single); begin inherited Create; FGain:=AGain; end;
function TGainProcessor.LatencyFrames: Integer; begin Result:=0; end;
procedure TGainProcessor.Reset; begin end;
procedure TGainProcessor.Process(const AInput: TAudioBuffer; out AOutput: TAudioBuffer);
var I: Integer; PIn: PSingle;
begin
  AOutput.Format:=AInput.Format; AOutput.FrameCount:=AInput.FrameCount;
  SetLength(AOutput.Data, Length(AInput.Data));
  if Length(AInput.Data)>0 then Move(AInput.Data[0], AOutput.Data[0], Length(AInput.Data));
  if AInput.Format.SampleFormat<>sfF32 then Exit;
  PIn:=PSingle(@AOutput.Data[0]);
  for I:=0 to AInput.FrameCount*AInput.Format.Channels-1 do PIn[I]:=PIn[I]*FGain;
end;

procedure T.TestCreateValid;
var G: IAudioGraph; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,2,sfF32);
  G:=CreateAudioGraph(Fmt);
  CheckTrue(Assigned(G),'graph assigned');
  CheckEqual(Ord(gsStopped), Ord(G.State),'stopped');
  CheckEqual(0, G.NodeCount,'0 nodes');
end;

procedure T.TestCreateInvalidThrows;
var OK: Boolean; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,2,sfS16);
  OK:=False;
  try CreateAudioGraph(Fmt); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'non-F32 throws');
end;

procedure T.TestAddSourceMismatchThrows;
var G: IAudioGraph; OK: Boolean; S: IRealtimeAudioSource;
begin
  G:=CreateAudioGraph(AudioFormatCreate(48000,2,sfF32));
  S:=TConstSource.Create(AudioFormatCreate(44100,2,sfF32), 0.1);
  OK:=False;
  try G.AddSource(S); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'mismatch throws');
end;

procedure T.TestMixTwoSources;
var G: IAudioGraph; S1,S2: IRealtimeAudioSource; Buf: TAudioBuffer; P: PSingle; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,1,sfF32);
  G:=CreateAudioGraph(Fmt);
  S1:=TConstSource.Create(Fmt, 0.3); S2:=TConstSource.Create(Fmt, 0.4);
  G.AddSource(S1,1.0); G.AddSource(S2,1.0);
  SetLength(Buf.Data, 10*Fmt.BlockAlign); Buf.Format:=Fmt; Buf.FrameCount:=10;
  G.FillRealtime(Buf,10);
  P:=PSingle(@Buf.Data[0]);
  CheckNear(0.7, P[0], 1e-5,'mix 0.3+0.4');
end;

procedure T.TestSetGain;
var G: IAudioGraph; Id: Integer; Buf: TAudioBuffer; P: PSingle; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,1,sfF32);
  G:=CreateAudioGraph(Fmt);
  Id:=G.AddSource(TConstSource.Create(Fmt,1.0),1.0);
  CheckTrue(G.SetGain(Id,0.5),'setgain true');
  SetLength(Buf.Data, 4*Fmt.BlockAlign); Buf.Format:=Fmt; Buf.FrameCount:=4;
  G.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.5, P[0], 1e-5,'gain 0.5');
  CheckFalse(G.SetGain(9999,1.0),'bad id false');
end;

procedure T.TestRemoveSource;
var G: IAudioGraph; Id: Integer; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,1,sfF32);
  G:=CreateAudioGraph(Fmt);
  Id:=G.AddSource(TConstSource.Create(Fmt,0.1),1.0);
  CheckEqual(1,G.NodeCount,'1');
  CheckTrue(G.RemoveSource(Id),'remove true');
  CheckEqual(0,G.NodeCount,'0 after');
  CheckFalse(G.RemoveSource(Id),'again false');
end;

procedure T.TestNodeCount;
var G: IAudioGraph; Fmt: TAudioFormat; I: Integer;
begin
  Fmt:=AudioFormatCreate(48000,2,sfF32);
  G:=CreateAudioGraph(Fmt);
  for I:=1 to 3 do G.AddSource(TConstSource.Create(Fmt,0.1),1.0);
  CheckEqual(3,G.NodeCount,'3');
end;

procedure T.TestProcessorChain;
var G: IAudioGraph; Buf: TAudioBuffer; P: PSingle; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,1,sfF32);
  G:=CreateAudioGraph(Fmt);
  G.AddSource(TConstSource.Create(Fmt,1.0),1.0);
  G.AddProcessor(TGainProcessor.Create(0.5));
  SetLength(Buf.Data, 4*Fmt.BlockAlign); Buf.Format:=Fmt; Buf.FrameCount:=4;
  G.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.5, P[0], 1e-5,'proc 0.5');
end;

procedure T.TestRemoveProcessor;
var G: IAudioGraph; Pid: Integer; Buf: TAudioBuffer; P: PSingle; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,1,sfF32);
  G:=CreateAudioGraph(Fmt);
  G.AddSource(TConstSource.Create(Fmt,1.0),1.0);
  Pid:=G.AddProcessor(TGainProcessor.Create(0.1));
  CheckTrue(G.RemoveProcessor(Pid),'remove proc true');
  CheckFalse(G.RemoveProcessor(Pid),'again false');
  SetLength(Buf.Data, 4*Fmt.BlockAlign); Buf.Format:=Fmt; Buf.FrameCount:=4;
  G.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(1.0,P[0],1e-5,'after remove no gain');
end;

procedure T.TestGraphViaDevice;
var Prov: IAudioDeviceProvider; Dev: IAudioDevice; G: IAudioGraph; Fmt: TAudioFormat;
begin
  Prov:=CreateNullAudioProvider;
  Fmt:=AudioFormatCreate(48000,2,sfF32);
  G:=CreateAudioGraph(Fmt);
  G.AddSource(TConstSource.Create(Fmt,0.2),1.0);
  Dev:=Prov.CreateDefaultDevice(Fmt);
  Dev.SetSource(G as IRealtimeAudioSource);
  Dev.Start;
  Dev.Drive(10);
  CheckEqual(UInt64(10), Dev.GetPosition.Frame,'device pos via graph');
  CheckEqual(Ord(dsStarted), Ord(Dev.State),'still started');
end;

procedure T.TestClear;
var G: IAudioGraph; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,1,sfF32);
  G:=CreateAudioGraph(Fmt);
  G.AddSource(TConstSource.Create(Fmt,0.1),1.0);
  G.AddProcessor(TGainProcessor.Create(0.5));
  G.Clear;
  CheckEqual(0,G.NodeCount,'clear nodes 0');
end;

procedure T.TestSeek;
var G: IAudioGraph; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,1,sfF32);
  G:=CreateAudioGraph(Fmt);
  G.AddSource(TConstSource.Create(Fmt,0.1),1.0);
  CheckTrue(G.SeekTo(100),'seek true');
end;

procedure T.TestPlayerCreate;
var Prov: IAudioDeviceProvider; Player: IAudioPlayer; Fmt: TAudioFormat;
begin
  Prov:=CreateNullAudioProvider;
  Fmt:=AudioFormatCreate(48000,2,sfF32);
  Player:=CreateAudioPlayerForFormat(Prov,Fmt);
  CheckTrue(Assigned(Player),'player assigned');
  CheckTrue(Assigned(Player.Graph),'graph');
  CheckTrue(Assigned(Player.Device),'device');
end;

procedure T.TestPlayerPlayPauseStop;
var Prov: IAudioDeviceProvider; Player: IAudioPlayer; Fmt: TAudioFormat;
begin
  Prov:=CreateNullAudioProvider;
  Fmt:=AudioFormatCreate(48000,1,sfF32);
  Player:=CreateAudioPlayerForFormat(Prov,Fmt);
  Player.Graph.AddSource(TConstSource.Create(Fmt,0.1),1.0);
  CheckTrue(Player.Play,'play');
  CheckEqual(Ord(gsPlaying), Ord(Player.State),'playing');
  Player.Device.Drive(5);
  CheckEqual(UInt64(5), Player.GetPosition.Frame,'pos 5');
  CheckTrue(Player.Pause,'pause');
  CheckEqual(Ord(gsStopped), Ord(Player.State),'stopped after pause');
  CheckTrue(Player.Play,'play again');
  CheckTrue(Player.Stop,'stop');
  CheckTrue(Player.Graph.SeekTo(0),'seek zero ok');
end;

procedure T.TestPlayerVolume;
var Prov: IAudioDeviceProvider; Player: IAudioPlayer; Fmt: TAudioFormat; Buf: TAudioBuffer; P: PSingle;
begin
  Prov:=CreateNullAudioProvider;
  Fmt:=AudioFormatCreate(48000,1,sfF32);
  Player:=CreateAudioPlayerForFormat(Prov,Fmt);
  Player.Graph.AddSource(TConstSource.Create(Fmt,1.0),1.0);
  CheckTrue(Player.SetVolume(0.5),'vol 0.5');
  CheckNear(0.5, Player.GetVolume,1e-6,'get vol');
  CheckFalse(Player.SetVolume(-1),'vol -1 false');
  Player.Play;
  SetLength(Buf.Data, 4*Fmt.BlockAlign); Buf.Format:=Fmt; Buf.FrameCount:=4;
  Player.Graph.FillRealtime(Buf,4);
  P:=PSingle(@Buf.Data[0]); CheckNear(0.5,P[0],1e-5,'volume applied');
end;

procedure T.TestFacadeHelpers;
var G: IAudioGraph; Fmt: TAudioFormat;
begin
  Fmt:=AudioFormatCreate(48000,2,sfF32);
  G:=nextpas.core.audio.CreateAudioGraph(Fmt);
  CheckTrue(Assigned(G),'facade graph');
end;

var S:TTestSuite; C:T;
begin
  C:=T.Create;
  S:=TTestSuite.Create('nextpas.core.audio.graph');
  S.Test('create valid', @C.TestCreateValid);
  S.Test('create invalid throws', @C.TestCreateInvalidThrows);
  S.Test('add source mismatch throws', @C.TestAddSourceMismatchThrows);
  S.Test('mix two sources', @C.TestMixTwoSources);
  S.Test('set gain', @C.TestSetGain);
  S.Test('remove source', @C.TestRemoveSource);
  S.Test('node count', @C.TestNodeCount);
  S.Test('processor chain', @C.TestProcessorChain);
  S.Test('remove processor', @C.TestRemoveProcessor);
  S.Test('graph via device', @C.TestGraphViaDevice);
  S.Test('clear', @C.TestClear);
  S.Test('seek', @C.TestSeek);
  S.Test('player create', @C.TestPlayerCreate);
  S.Test('player play pause stop', @C.TestPlayerPlayPauseStop);
  S.Test('player volume', @C.TestPlayerVolume);
  S.Test('facade helpers', @C.TestFacadeHelpers);
  C.Free;
  if not S.Run then Halt(1);
end.
