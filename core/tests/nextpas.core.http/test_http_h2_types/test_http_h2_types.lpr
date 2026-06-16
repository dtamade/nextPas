program test_http_h2_types;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.http.base,
  nextpas.core.http.impl.h2.types,
  nextpas.core.testing;

procedure TestSettingsDefaultsMatchFrameConstants;
var
  LSettings: TH2Settings;
begin
  LSettings := TH2Settings.Default;
  CheckEqual(Int64(H2_DEFAULT_HEADER_TABLE_SIZE),
    Int64(LSettings.HeaderTableSize), 'default header table size');
  CheckEqual(Int64(H2_DEFAULT_ENABLE_PUSH), Int64(Ord(LSettings.EnablePush)),
    'default enable push');
  CheckEqual(Int64(H2_DEFAULT_MAX_CONCURRENT_STREAMS),
    Int64(LSettings.MaxConcurrentStreams), 'default max concurrent streams');
  CheckEqual(Int64(H2_DEFAULT_INITIAL_WINDOW_SIZE),
    Int64(LSettings.InitialWindowSize), 'default initial window size');
  CheckEqual(Int64(H2_DEFAULT_MAX_FRAME_SIZE), Int64(LSettings.MaxFrameSize),
    'default max frame size');
  CheckEqual(Int64(H2_DEFAULT_MAX_HEADER_LIST_SIZE),
    Int64(LSettings.MaxHeaderListSize), 'default max header list size');
end;

procedure TestServerOptionsDefaults;
var
  LOptions: TH2ServerTransportOptions;
begin
  LOptions := TH2ServerTransportOptions.Default;
  CheckEqual(Int64(100), Int64(LOptions.MaxConcurrentStreams),
    'server default concurrent streams');
  CheckEqual(Int64(H2_DEFAULT_INITIAL_WINDOW_SIZE),
    Int64(LOptions.InitialStreamWindowSize), 'server stream window');
  CheckEqual(Int64(H2_DEFAULT_INITIAL_WINDOW_SIZE),
    Int64(LOptions.InitialConnectionWindowSize), 'server connection window');
  CheckEqual(Int64(H2_DEFAULT_HEADER_TABLE_SIZE),
    Int64(LOptions.HeaderTableSize), 'server header table');
  CheckEqual(Int64(H2_DEFAULT_MAX_FRAME_SIZE),
    Int64(LOptions.MaxFrameSize), 'server max frame size');
  CheckEqual(Int64(0), Int64(LOptions.MaxHeaderListSize),
    'server max header list size');
  CheckEqual(Int64(4194304), Int64(LOptions.MaxBodySize),
    'server max body size');
  CheckEqual(Int64(0), Int64(LOptions.ReadTimeout), 'server read timeout');
  CheckEqual(Int64(0), Int64(LOptions.WriteTimeout), 'server write timeout');
  CheckEqual(Int64(30000), Int64(LOptions.IdleTimeout), 'server idle timeout');
  CheckEqual(Int64(0), Int64(LOptions.ReadIdleTimeout),
    'server read idle timeout');
  CheckEqual(Int64(5000), Int64(LOptions.PingTimeout), 'server ping timeout');
end;

procedure TestClientOptionsDefaults;
var
  LOptions: TH2ClientTransportOptions;
begin
  LOptions := TH2ClientTransportOptions.Default;
  CheckEqual(Int64(30000), Int64(LOptions.Timeout), 'client timeout');
  CheckEqual(Int64(64), Int64(LOptions.MaxPoolSize), 'client max pool');
  CheckEqual(Int64(H2_DEFAULT_HEADER_TABLE_SIZE),
    Int64(LOptions.HeaderTableSize), 'client header table');
  CheckEqual(Int64(Ord(False)), Int64(Ord(LOptions.EnablePush)),
    'client enable push');
  CheckEqual(Int64(H2_DEFAULT_INITIAL_WINDOW_SIZE),
    Int64(LOptions.InitialStreamWindowSize), 'client stream window');
  CheckEqual(Int64(H2_DEFAULT_INITIAL_WINDOW_SIZE),
    Int64(LOptions.InitialConnectionWindowSize), 'client connection window');
  CheckEqual(Int64(H2_DEFAULT_MAX_FRAME_SIZE),
    Int64(LOptions.MaxFrameSize), 'client max frame size');
  CheckEqual(Int64(0), Int64(LOptions.MaxHeaderListSize),
    'client max header list size');
  CheckEqual(Int64(5000), Int64(LOptions.PingTimeout), 'client ping timeout');
end;

procedure TestServerOptionsProjectToSettings;
var
  LOptions: TH2ServerTransportOptions;
  LSettings: TH2Settings;
begin
  LOptions := TH2ServerTransportOptions.Default;
  LOptions.MaxConcurrentStreams := 321;
  LOptions.InitialStreamWindowSize := 131072;
  LOptions.HeaderTableSize := 8192;
  LOptions.MaxFrameSize := 32768;
  LOptions.MaxHeaderListSize := 65536;
  LSettings := LOptions.ToSettings;
  CheckEqual(Int64(8192), Int64(LSettings.HeaderTableSize),
    'server settings header table');
  CheckEqual(Int64(Ord(False)), Int64(Ord(LSettings.EnablePush)),
    'server settings disable push');
  CheckEqual(Int64(321), Int64(LSettings.MaxConcurrentStreams),
    'server settings concurrent streams');
  CheckEqual(Int64(131072), Int64(LSettings.InitialWindowSize),
    'server settings initial window');
  CheckEqual(Int64(32768), Int64(LSettings.MaxFrameSize),
    'server settings max frame size');
  CheckEqual(Int64(65536), Int64(LSettings.MaxHeaderListSize),
    'server settings max header list');
end;

procedure TestClientOptionsProjectToSettings;
var
  LOptions: TH2ClientTransportOptions;
  LSettings: TH2Settings;
begin
  LOptions := TH2ClientTransportOptions.Default;
  LOptions.EnablePush := False;
  LOptions.HeaderTableSize := 1024;
  LOptions.InitialStreamWindowSize := 98304;
  LOptions.MaxFrameSize := 65535;
  LOptions.MaxHeaderListSize := 2048;
  LSettings := LOptions.ToSettings;
  CheckEqual(Int64(1024), Int64(LSettings.HeaderTableSize),
    'client settings header table');
  CheckEqual(Int64(Ord(False)), Int64(Ord(LSettings.EnablePush)),
    'client settings enable push');
  CheckEqual(Int64(0), Int64(LSettings.MaxConcurrentStreams),
    'client leaves max concurrent streams unlimited');
  CheckEqual(Int64(98304), Int64(LSettings.InitialWindowSize),
    'client settings initial window');
  CheckEqual(Int64(65535), Int64(LSettings.MaxFrameSize),
    'client settings max frame size');
  CheckEqual(Int64(2048), Int64(LSettings.MaxHeaderListSize),
    'client settings max header list');
end;

procedure TestApplyPeerSettingsUpdatesRuntimeView;
var
  LSettings: TH2Settings;
  LPeer: TH2Settings;
begin
  LSettings := TH2Settings.Default;
  LPeer := TH2Settings.Default;
  LPeer.HeaderTableSize := 2048;
  LPeer.EnablePush := False;
  LPeer.MaxConcurrentStreams := 17;
  LPeer.InitialWindowSize := 70000;
  LPeer.MaxFrameSize := 32768;
  LPeer.MaxHeaderListSize := 9000;
  LSettings.ApplyPeerSettings(LPeer);
  CheckEqual(Int64(2048), Int64(LSettings.HeaderTableSize),
    'apply peer header table');
  CheckEqual(Int64(Ord(False)), Int64(Ord(LSettings.EnablePush)),
    'apply peer enable push');
  CheckEqual(Int64(17), Int64(LSettings.MaxConcurrentStreams),
    'apply peer concurrent streams');
  CheckEqual(Int64(70000), Int64(LSettings.InitialWindowSize),
    'apply peer initial window');
  CheckEqual(Int64(32768), Int64(LSettings.MaxFrameSize),
    'apply peer max frame size');
  CheckEqual(Int64(9000), Int64(LSettings.MaxHeaderListSize),
    'apply peer max header list');
end;

procedure TestFlowInitAndWindowAccounting;
var
  LFlow: TH2FlowState;
begin
  LFlow.Init(1024);
  CheckEqual(Int64(1024), Int64(LFlow.InitialWindowSize),
    'flow initial window');
  CheckEqual(Int64(1024), Int64(LFlow.AvailableWindow),
    'flow available window');
  CheckEqual(Int64(0), Int64(LFlow.ReservedBytes), 'flow reserved bytes');
  CheckEqual(Int64(0), Int64(LFlow.InFlightBytes), 'flow inflight bytes');
  Check(LFlow.TryReserve(256), 'reserve within available window');
  CheckEqual(Int64(768), Int64(LFlow.AvailableWindow),
    'reserve decreases available');
  CheckEqual(Int64(256), Int64(LFlow.ReservedBytes),
    'reserve increases reserved');
  LFlow.CommitSend(128);
  CheckEqual(Int64(128), Int64(LFlow.ReservedBytes),
    'commit send decreases reserved');
  CheckEqual(Int64(128), Int64(LFlow.InFlightBytes),
    'commit send increases inflight');
  LFlow.OnDataConsumed(64);
  CheckEqual(Int64(832), Int64(LFlow.AvailableWindow),
    'consume returns credit');
  CheckEqual(Int64(64), Int64(LFlow.InFlightBytes),
    'consume decreases inflight');
end;

procedure TestFlowWindowShrinkCanGoNegativeUntilConsumed;
var
  LFlow: TH2FlowState;
begin
  LFlow.Init(65535);
  LFlow.OnPeerInitialWindowSizeChanged(32768);
  CheckEqual(Int64(32768), Int64(LFlow.InitialWindowSize),
    'window shrink updates initial window');
  CheckEqual(Int64(32768), Int64(LFlow.AvailableWindow),
    'window shrink updates available');
  Check(LFlow.TryReserve(32768), 'reserve to zero');
  LFlow.CommitSend(32768);
  LFlow.OnPeerInitialWindowSizeChanged(1024);
  CheckEqual(Int64(1024), Int64(LFlow.InitialWindowSize),
    'second shrink initial window');
  CheckEqual(Int64(-31744), Int64(LFlow.AvailableWindow),
    'window can go negative after shrink');
  Check(not LFlow.HasSendCapacity, 'negative window has no capacity');
end;

procedure TestConnectionAndStreamFlowCarryIdentity;
var
  LConn: TH2ConnectionFlowControl;
  LStream: TH2StreamFlowControl;
begin
  LConn.Init(4096);
  LStream.Init(11, 2048);
  CheckEqual(Int64(4096), Int64(LConn.SendWindow.AvailableWindow),
    'connection send flow available');
  CheckEqual(Int64(4096), Int64(LConn.RecvWindow.AvailableWindow),
    'connection recv flow available');
  CheckEqual(Int64(11), Int64(LStream.StreamID), 'stream flow id');
  CheckEqual(Int64(2048), Int64(LStream.SendWindow.AvailableWindow),
    'stream send flow available');
  CheckEqual(Int64(2048), Int64(LStream.RecvWindow.AvailableWindow),
    'stream recv flow available');
end;

{ -- Flow control overflow and error path tests -- }

procedure TestFlowOnDataReceivedExceedsCapacity;
var
  LFlow: TH2FlowState;
  LCaptured: Boolean;
begin
  LCaptured := False;
  try
    LFlow.Init(8);
    LFlow.OnDataReceived(9);
  except
    on E: EHttpError do
      LCaptured := True;
  end;
  Check(LCaptured, 'OnDataReceived exceeding capacity raises');
end;

procedure TestFlowOnDataConsumedReturnsWindow;
var
  LFlow: TH2FlowState;
begin
  LFlow.Init(100);
  LFlow.OnDataReceived(50);
  CheckEqual(Int64(50), LFlow.AvailableWindow, 'recv depletes window');
  CheckEqual(Int64(50), LFlow.InFlightBytes, 'recv tracks inflight');
  LFlow.OnDataConsumed(30);
  CheckEqual(Int64(80), LFlow.AvailableWindow, 'consume returns credit');
  CheckEqual(Int64(20), LFlow.InFlightBytes, 'consume reduces inflight');
end;

procedure TestFlowOnDataConsumedExceedsInflight;
var
  LFlow: TH2FlowState;
  LCaptured: Boolean;
begin
  LCaptured := False;
  try
    LFlow.Init(100);
    LFlow.OnDataReceived(30);
    LFlow.OnDataConsumed(50);
  except
    on E: EHttpError do
      LCaptured := True;
  end;
  Check(LCaptured, 'OnDataConsumed exceeding inflight raises');
end;

procedure TestFlowReleaseReservedBasic;
var
  LFlow: TH2FlowState;
begin
  LFlow.Init(100);
  Check(LFlow.TryReserve(60), 'reserve 60');
  LFlow.ReleaseReserved(20);
  CheckEqual(Int64(60), LFlow.AvailableWindow, 'release restores available');
  CheckEqual(Int64(40), LFlow.ReservedBytes, 'release reduces reserved');
end;

procedure TestFlowReleaseReservedExceedsReserved;
var
  LFlow: TH2FlowState;
  LCaptured: Boolean;
begin
  LCaptured := False;
  try
    LFlow.Init(100);
    LFlow.TryReserve(30);
    LFlow.ReleaseReserved(50);
  except
    on E: EHttpError do
      LCaptured := True;
  end;
  Check(LCaptured, 'ReleaseReserved exceeding reserved raises');
end;

procedure TestFlowOnWindowUpdateZero;
var
  LFlow: TH2FlowState;
  LCaptured: Boolean;
begin
  LCaptured := False;
  try
    LFlow.Init(100);
    LFlow.OnWindowUpdate(0);
  except
    on E: EHttpError do
      LCaptured := True;
  end;
  Check(LCaptured, 'OnWindowUpdate with zero increment raises');
end;

procedure TestFlowOnWindowUpdateOverflow;
var
  LFlow: TH2FlowState;
  LCaptured: Boolean;
begin
  LCaptured := False;
  try
    LFlow.Init(H2_MAX_WINDOW_SIZE - 1);
    LFlow.OnWindowUpdate(100);
  except
    on E: EHttpError do
      LCaptured := True;
  end;
  Check(LCaptured, 'OnWindowUpdate exceeding H2_MAX_WINDOW_SIZE raises');
end;

procedure TestFlowCanReserveBoundaries;
var
  LFlow: TH2FlowState;
begin
  LFlow.Init(0);
  Check(not LFlow.CanReserve(1), 'zero window cannot reserve');
  Check(LFlow.CanReserve(0), 'zero window can reserve zero');

  LFlow.Init(100);
  Check(LFlow.CanReserve(100), 'can reserve entire window');
  Check(not LFlow.CanReserve(101), 'cannot reserve beyond window');
end;

procedure TestFlowHasSendAndReceiveCapacity;
var
  LFlow: TH2FlowState;
begin
  LFlow.Init(0);
  Check(not LFlow.HasSendCapacity, 'zero window has no send capacity');
  Check(not LFlow.HasReceiveCapacity, 'zero window has no recv capacity');

  LFlow.Init(10);
  Check(LFlow.HasSendCapacity, 'positive window has send capacity');
  Check(LFlow.HasReceiveCapacity, 'positive window has recv capacity');

  LFlow.OnDataReceived(10);
  Check(not LFlow.HasReceiveCapacity, 'depleted recv window has no recv capacity');
end;

{ -- Options validation tests -- }

procedure TestClientOptionsValidation;
var
  LOptions: TH2ClientTransportOptions;
  LCaptured: Boolean;
begin
  LOptions := TH2ClientTransportOptions.Default;
  LOptions.MaxPoolSize := 0;
  LCaptured := False;
  try LOptions.Validate; except on E: EHttpError do LCaptured := True; end;
  Check(LCaptured, 'client MaxPoolSize=0 raises');

  LOptions := TH2ClientTransportOptions.Default;
  LOptions.InitialStreamWindowSize := 2147483648; { > H2_MAX_WINDOW_SIZE }
  LCaptured := False;
  try LOptions.Validate; except on E: EHttpError do LCaptured := True; end;
  Check(LCaptured, 'client stream window too large raises');

  LOptions := TH2ClientTransportOptions.Default;
  LOptions.MaxFrameSize := 100;
  LCaptured := False;
  try LOptions.Validate; except on E: EHttpError do LCaptured := True; end;
  Check(LCaptured, 'client MaxFrameSize too small raises');

  LOptions := TH2ClientTransportOptions.Default;
  LOptions.Timeout := -1;
  LCaptured := False;
  try LOptions.Validate; except on E: EHttpError do LCaptured := True; end;
  Check(LCaptured, 'client negative timeout raises');
end;

procedure TestServerOptionsValidation;
var
  LOptions: TH2ServerTransportOptions;
  LCaptured: Boolean;
begin
  LOptions := TH2ServerTransportOptions.Default;
  LOptions.InitialStreamWindowSize := 2147483648;
  LCaptured := False;
  try LOptions.Validate; except on E: EHttpError do LCaptured := True; end;
  Check(LCaptured, 'server stream window too large raises');

  LOptions := TH2ServerTransportOptions.Default;
  LOptions.ReadTimeout := -5;
  LCaptured := False;
  try LOptions.Validate; except on E: EHttpError do LCaptured := True; end;
  Check(LCaptured, 'server negative read timeout raises');

  LOptions := TH2ServerTransportOptions.Default;
  LOptions.MaxBodySize := High(Int32) + 1;
  LCaptured := False;
  try LOptions.Validate; except on E: EHttpError do LCaptured := True; end;
  Check(LCaptured, 'server MaxBodySize too large raises');
end;

{ -- Connection/Stream flow control edge cases -- }

procedure TestConnectionFlowReset;
var
  LConn: TH2ConnectionFlowControl;
begin
  LConn.Init(100, 200);
  LConn.SendWindow.TryReserve(80);
  LConn.SendWindow.CommitSend(80);
  LConn.RecvWindow.OnDataReceived(150);

  LConn.SendWindow.Reset(200);
  LConn.RecvWindow.Reset(300);

  CheckEqual(Int64(200), LConn.SendWindow.AvailableWindow, 'send reset restores window');
  CheckEqual(Int64(0), LConn.SendWindow.InFlightBytes, 'send reset clears inflight');
  CheckEqual(Int64(300), LConn.RecvWindow.AvailableWindow, 'recv reset restores window');
end;

procedure TestStreamFlowApplyWindows;
var
  LStream: TH2StreamFlowControl;
begin
  LStream.Init(1, 10000, 20000);
  CheckEqual(Int64(10000), LStream.SendWindow.AvailableWindow, 'stream send init');
  CheckEqual(Int64(20000), LStream.RecvWindow.AvailableWindow, 'stream recv init');

  LStream.ApplyPeerInitialWindowSize(32768);
  Check(LStream.SendWindow.AvailableWindow > 10000,
    'peer initial window increase expands send window');

  LStream.ApplyLocalInitialWindowSize(65535);
  Check(LStream.RecvWindow.AvailableWindow > 20000,
    'local initial window increase expands recv window');
end;

{ -- TH2Settings validation -- }

procedure TestSettingsValidation;
var
  LSettings: TH2Settings;
  LCaptured: Boolean;
begin
  LSettings := TH2Settings.Default;
  LSettings.MaxFrameSize := 100;
  LCaptured := False;
  try LSettings.Validate; except on E: EHttpError do LCaptured := True; end;
  Check(LCaptured, 'settings MaxFrameSize too small raises');

  LSettings := TH2Settings.Default;
  LSettings.InitialWindowSize := 2147483648;
  LCaptured := False;
  try LSettings.Validate; except on E: EHttpError do LCaptured := True; end;
  Check(LCaptured, 'settings InitialWindowSize too large raises');
end;

begin
  with TTestRunner.Create('nextpas.core.http.impl.h2.types') do
  begin
    Run('Settings defaults match frame constants',
      @TestSettingsDefaultsMatchFrameConstants);
    Run('Server options defaults', @TestServerOptionsDefaults);
    Run('Client options defaults', @TestClientOptionsDefaults);
    Run('Server options project to settings', @TestServerOptionsProjectToSettings);
    Run('Client options project to settings', @TestClientOptionsProjectToSettings);
    Run('Apply peer settings updates runtime view',
      @TestApplyPeerSettingsUpdatesRuntimeView);
    Run('Flow init and window accounting', @TestFlowInitAndWindowAccounting);
    Run('Flow window shrink can go negative until consumed',
      @TestFlowWindowShrinkCanGoNegativeUntilConsumed);
    Run('Connection and stream flow carry identity',
      @TestConnectionAndStreamFlowCarryIdentity);
    Run('OnDataReceived exceeding capacity raises',
      @TestFlowOnDataReceivedExceedsCapacity);
    Run('OnDataConsumed returns credit',
      @TestFlowOnDataConsumedReturnsWindow);
    Run('OnDataConsumed exceeding inflight raises',
      @TestFlowOnDataConsumedExceedsInflight);
    Run('ReleaseReserved basic',
      @TestFlowReleaseReservedBasic);
    Run('ReleaseReserved exceeding reserved raises',
      @TestFlowReleaseReservedExceedsReserved);
    Run('OnWindowUpdate zero raises',
      @TestFlowOnWindowUpdateZero);
    Run('OnWindowUpdate overflow raises',
      @TestFlowOnWindowUpdateOverflow);
    Run('CanReserve boundary conditions',
      @TestFlowCanReserveBoundaries);
    Run('HasSendCapacity and HasReceiveCapacity',
      @TestFlowHasSendAndReceiveCapacity);
    Run('Client options validation rejects invalid',
      @TestClientOptionsValidation);
    Run('Server options validation rejects invalid',
      @TestServerOptionsValidation);
    Run('Connection flow reset',
      @TestConnectionFlowReset);
    Run('Stream flow apply windows',
      @TestStreamFlowApplyWindows);
    Run('Settings validation rejects invalid',
      @TestSettingsValidation);
    Summary;
  end;
end.
