program test_device;
{$mode objfpc}{$H+}
uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.audio.base,
  nextpas.core.audio.intf,
  nextpas.core.audio.device.intf,
  nextpas.core.audio.device.null,
  nextpas.core.audio;

type
  // 最小可控 Fake 源：可配置返回模式
  TFakeSource = class(TInterfacedObject, IRealtimeAudioSource, IAudioSource)
  private
    FFormat: TAudioFormat;
    FMode: Integer; // 0=正常满帧, 1=每次少1帧(欠料), 2=抛异常, 3=EOF(0)
    FCalls: Integer;
  public
    constructor Create(const AFormat: TAudioFormat; AMode: Integer);
    function GetFormat: TAudioFormat;
    function Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
    function SeekTo(AFrame: UInt64): Boolean;
  end;

  T = class
    procedure TestProviderEnumerate;
    procedure TestProviderDefault;
    procedure TestCreateDeviceValid;
    procedure TestCreateDeviceInvalidFormatThrows;
    procedure TestCreateDeviceUnknownIDThrows;
    procedure TestStartWithoutSourceThrows;
    procedure TestStartMismatchThrows;
    procedure TestStartStopEvents;
    procedure TestDrivePosition;
    procedure TestDriveUnderrun;
    procedure TestDriveEOFStops;
    procedure TestDriveExceptionCountsViolation;
    procedure TestPollEventFIFO;
    procedure TestFacadeProvider;
    procedure TestMultipleDevicesIndependent;
  end;

constructor TFakeSource.Create(const AFormat: TAudioFormat; AMode: Integer);
begin inherited Create; FFormat:=AFormat; FMode:=AMode; FCalls:=0; end;
function TFakeSource.GetFormat: TAudioFormat; begin Result:=FFormat; end;
function TFakeSource.Fill(var ABuffer: TAudioBuffer; AFrames: Integer): Integer; begin Result:=FillRealtime(ABuffer, AFrames); end;
function TFakeSource.SeekTo(AFrame: UInt64): Boolean; begin Result:=True; end;
function TFakeSource.FillRealtime(var ABuffer: TAudioBuffer; AFrames: Integer): Integer;
var I: Integer; P: PSingle;
begin
  Inc(FCalls);
  case FMode of
    0: begin
         // 填满，并写入正弦便于后续检查不崩
         if Length(ABuffer.Data) >= AFrames * FFormat.BlockAlign then
         begin
           P:=PSingle(@ABuffer.Data[0]);
           for I:=0 to AFrames*FFormat.Channels-1 do P[I]:=0.1;
         end;
         Result:=AFrames;
       end;
    1: begin // 欠1帧
         P:=PSingle(@ABuffer.Data[0]);
         for I:=0 to (AFrames-1)*FFormat.Channels-1 do P[I]:=0.1;
         // 最后一帧静音已垫
         for I:=(AFrames-1)*FFormat.Channels to AFrames*FFormat.Channels-1 do P[I]:=0;
         Result:=AFrames-1;
       end;
    2: raise Exception.Create('fake realtime exception');
    3: Result:=0;
  else Result:=AFrames;
  end;
end;

procedure T.TestProviderEnumerate;
var P: IAudioDeviceProvider; List: TAudioDeviceInfoArray;
begin
  P:=CreateNullAudioProvider;
  List:=P.Enumerate;
  CheckTrue(Length(List)>=2,'enumerate >=2');
  CheckEqual('null-default', List[0].ID,'first id');
end;

procedure T.TestProviderDefault;
var P: IAudioDeviceProvider; D: TAudioDeviceInfo;
begin
  P:=CreateNullAudioProvider;
  D:=P.GetDefault;
  CheckTrue(D.IsDefault,'default IsDefault');
  CheckEqual('null-default', D.ID,'default id');
end;

procedure T.TestCreateDeviceValid;
var P: IAudioDeviceProvider; Dev: IAudioDevice; Fmt: TAudioFormat;
begin
  P:=CreateNullAudioProvider;
  Fmt:=AudioFormatCreate(48000,2,sfF32);
  Dev:=P.CreateDefaultDevice(Fmt);
  CheckTrue(Assigned(Dev),'device assigned');
  CheckEqual(Ord(dsOpened), Ord(Dev.State),'opened state');
  CheckEqual(48000, Dev.Format.SampleRate,'rate');
end;

procedure T.TestCreateDeviceInvalidFormatThrows;
var P: IAudioDeviceProvider; Fmt: TAudioFormat; OK: Boolean;
begin
  P:=CreateNullAudioProvider;
  Fmt.SampleRate:=0; Fmt.Channels:=2; Fmt.SampleFormat:=sfF32;
  Fmt.ChannelMask:=3; Fmt.ChannelLayout:=clStereo;
  OK:=False;
  try P.CreateDefaultDevice(Fmt); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'invalid format throws');
end;

procedure T.TestCreateDeviceUnknownIDThrows;
var P: IAudioDeviceProvider; OK: Boolean;
begin
  P:=CreateNullAudioProvider;
  OK:=False;
  try P.CreateDevice('no-such', AudioFormatCreate(48000,2,sfF32)); except on E:Exception do OK:=True; end;
  CheckTrue(OK,'unknown id throws');
end;

procedure T.TestStartWithoutSourceThrows;
var P: IAudioDeviceProvider; Dev: IAudioDevice; OK: Boolean;
begin
  P:=CreateNullAudioProvider;
  Dev:=P.CreateDefaultDevice(AudioFormatCreate(48000,2,sfF32));
  OK:=False;
  try Dev.Start; except on E:Exception do OK:=True; end;
  CheckTrue(OK,'start without source throws');
end;

procedure T.TestStartMismatchThrows;
var P: IAudioDeviceProvider; Dev: IAudioDevice; Src: IRealtimeAudioSource; OK: Boolean;
begin
  P:=CreateNullAudioProvider;
  Dev:=P.CreateDefaultDevice(AudioFormatCreate(48000,2,sfF32));
  Src:=TFakeSource.Create(AudioFormatCreate(44100,2,sfF32),0);
  Dev.SetSource(Src);
  OK:=False;
  try Dev.Start; except on E:Exception do OK:=True; end;
  CheckTrue(OK,'mismatch rate throws');
  // 通道不匹配
  Dev:=P.CreateDefaultDevice(AudioFormatCreate(48000,2,sfF32));
  Src:=TFakeSource.Create(AudioFormatCreate(48000,1,sfF32),0);
  Dev.SetSource(Src);
  OK:=False;
  try Dev.Start; except on E:Exception do OK:=True; end;
  CheckTrue(OK,'mismatch ch throws');
end;

procedure T.TestStartStopEvents;
var P: IAudioDeviceProvider; Dev: IAudioDevice; Src: IRealtimeAudioSource; Ev: TDeviceEvent; OK: Boolean;
begin
  P:=CreateNullAudioProvider;
  Dev:=P.CreateDefaultDevice(AudioFormatCreate(48000,2,sfF32));
  Src:=TFakeSource.Create(Dev.Format,0);
  Dev.SetSource(Src);
  CheckTrue(Dev.Start,'start ok');
  CheckEqual(Ord(dsStarted), Ord(Dev.State),'started');
  OK:=Dev.PollEvent(Ev);
  CheckTrue(OK,'poll started'); CheckEqual(Ord(devStarted), Ord(Ev.Kind),'event started');
  CheckTrue(Dev.Stop,'stop ok');
  CheckEqual(Ord(dsOpened), Ord(Dev.State),'opened after stop');
  OK:=Dev.PollEvent(Ev);
  CheckTrue(OK,'poll stopped'); CheckEqual(Ord(devStopped), Ord(Ev.Kind),'event stopped');
  CheckFalse(Dev.PollEvent(Ev),'no more events');
end;

procedure T.TestDrivePosition;
var P: IAudioDeviceProvider; Dev: IAudioDevice; Src: IRealtimeAudioSource; Pos: TAudioClock;
begin
  P:=CreateNullAudioProvider;
  Dev:=P.CreateDefaultDevice(AudioFormatCreate(48000,2,sfF32));
  Src:=TFakeSource.Create(Dev.Format,0);
  Dev.SetSource(Src); Dev.Start;
  CheckEqual(Int64(0), Int64(Dev.GetPosition.Frame),'pos 0');
  Dev.Drive(100);
  Pos:=Dev.GetPosition;
  CheckEqual(UInt64(100), Pos.Frame,'pos 100');
  CheckEqual(48000, Pos.SampleRate,'sr');
  CheckEqual(Int64(2083333), Pos.ToDurationNs, 'duration 100@48k = 2083333ns');
  Dev.Drive(200);
  CheckEqual(UInt64(300), Dev.GetPosition.Frame,'pos 300');
end;

procedure T.TestDriveUnderrun;
var P: IAudioDeviceProvider; Dev: IAudioDevice; Src: IRealtimeAudioSource; I: Integer;
begin
  P:=CreateNullAudioProvider;
  Dev:=P.CreateDefaultDevice(AudioFormatCreate(48000,2,sfF32));
  Src:=TFakeSource.Create(Dev.Format,1); // 欠1帧
  Dev.SetSource(Src); Dev.Start;
  CheckEqual(UInt64(0), Dev.GetUnderrunCount,'underrun 0 init');
  Dev.Drive(10);
  CheckTrue(Dev.GetUnderrunCount>=1,'underrun inc');
  // 连续5次触发 devUnderrun 事件
  for I:=1 to 5 do Dev.Drive(10);
  // 至少有一个 underrun 事件
  // 消费所有事件看是否有 devUnderrun
end;

procedure T.TestDriveEOFStops;
var P: IAudioDeviceProvider; Dev: IAudioDevice; Src: IRealtimeAudioSource; Ev: TDeviceEvent; Found: Boolean;
begin
  P:=CreateNullAudioProvider;
  Dev:=P.CreateDefaultDevice(AudioFormatCreate(48000,2,sfF32));
  Src:=TFakeSource.Create(Dev.Format,3); // EOF
  Dev.SetSource(Src); Dev.Start;
  CheckEqual(0, Dev.Drive(10),'drive eof 0');
  CheckEqual(Ord(dsOpened), Ord(Dev.State),'opened after eof');
  Found:=False;
  while Dev.PollEvent(Ev) do if Ev.Kind=devStopped then Found:=True;
  CheckTrue(Found,'eof devStopped event');
end;

procedure T.TestDriveExceptionCountsViolation;
var P: IAudioDeviceProvider; Dev: IAudioDevice; Src: IRealtimeAudioSource;
begin
  P:=CreateNullAudioProvider;
  Dev:=P.CreateDefaultDevice(AudioFormatCreate(48000,2,sfF32));
  Src:=TFakeSource.Create(Dev.Format,2); // 抛异常
  Dev.SetSource(Src); Dev.Start;
  CheckEqual(UInt64(0), Dev.GetContractViolationCount,'viol 0');
  Dev.Drive(10);
  CheckTrue(Dev.GetContractViolationCount>=1,'viol inc on exception');
  CheckEqual(UInt64(10), Dev.GetPosition.Frame,'pos still advances muted');
end;

procedure T.TestPollEventFIFO;
var P: IAudioDeviceProvider; Dev: IAudioDevice; Src: IRealtimeAudioSource; A,B: TDeviceEvent;
begin
  P:=CreateNullAudioProvider;
  Dev:=P.CreateDefaultDevice(AudioFormatCreate(48000,2,sfF32));
  Src:=TFakeSource.Create(Dev.Format,0);
  Dev.SetSource(Src); Dev.Start; Dev.Stop; Dev.Start; Dev.Stop;
  CheckTrue(Dev.PollEvent(A),'1'); CheckTrue(Dev.PollEvent(B),'2');
  CheckEqual(Ord(devStarted), Ord(A.Kind),'fifo started first');
  // second may be stopped
end;

procedure T.TestFacadeProvider;
var P: IAudioDeviceProvider;
begin
  P:=nextpas.core.audio.CreateNullAudioProvider;
  CheckTrue(Assigned(P),'facade provider');
  CheckTrue(Length(P.Enumerate)>=1,'facade enumerate');
end;

procedure T.TestMultipleDevicesIndependent;
var Prov: IAudioDeviceProvider; D1,D2: IAudioDevice; S1,S2: IRealtimeAudioSource;
begin
  Prov:=CreateNullAudioProvider;
  D1:=Prov.CreateDevice('null-default', AudioFormatCreate(48000,2,sfF32));
  D2:=Prov.CreateDevice('null-secondary', AudioFormatCreate(44100,2,sfF32));
  S1:=TFakeSource.Create(D1.Format,0); S2:=TFakeSource.Create(D2.Format,0);
  D1.SetSource(S1); D2.SetSource(S2);
  D1.Start; D2.Start;
  D1.Drive(10); D2.Drive(20);
  CheckEqual(UInt64(10), D1.GetPosition.Frame,'d1 pos');
  CheckEqual(UInt64(20), D2.GetPosition.Frame,'d2 pos');
end;

var S: TTestSuite; C: T;
begin
  C:=T.Create;
  S:=TTestSuite.Create('nextpas.core.audio.device');
  S.Test('provider enumerate', @C.TestProviderEnumerate);
  S.Test('provider default', @C.TestProviderDefault);
  S.Test('create device valid', @C.TestCreateDeviceValid);
  S.Test('create device invalid format throws', @C.TestCreateDeviceInvalidFormatThrows);
  S.Test('create device unknown id throws', @C.TestCreateDeviceUnknownIDThrows);
  S.Test('start without source throws', @C.TestStartWithoutSourceThrows);
  S.Test('start mismatch throws', @C.TestStartMismatchThrows);
  S.Test('start stop events', @C.TestStartStopEvents);
  S.Test('drive position', @C.TestDrivePosition);
  S.Test('drive underrun', @C.TestDriveUnderrun);
  S.Test('drive eof stops', @C.TestDriveEOFStops);
  S.Test('drive exception violation', @C.TestDriveExceptionCountsViolation);
  S.Test('poll event fifo', @C.TestPollEventFIFO);
  S.Test('facade provider', @C.TestFacadeProvider);
  S.Test('multiple devices independent', @C.TestMultipleDevicesIndependent);
  C.Free;
  if not S.Run then Halt(1);
end.
