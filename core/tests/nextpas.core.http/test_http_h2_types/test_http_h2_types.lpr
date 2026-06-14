program test_http_h2_types;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
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
    Summary;
  end;
end.
