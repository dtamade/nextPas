program bench_bridge;
{** @desc bench: 桥协议热路径基线（bench 框架版）。
       计时前硬校验正确性，暴露解码/回执构造吞吐、gtk.pool Slab 与 scheme
       分发热点及 dispatcher Post 往返延迟；覆盖 CONTRACT §8 dispatcher 基线。
       框架：nextpas.core.bench，禁自定义计时。
       单源：pool 经 bytes.ops VecGrowCapacity/SyncPool 单源 inline 零拷贝，
             scheme 经 prefixrouter Trie + hashmap 单源，dispatcher 经
             fake.dispatcher 环形 FIFO bytes.ops VecRingCopy 单源。 *}

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  SysUtils,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.base,
  nextpas.core.text.view,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.bridge,
  nextpas.core.webview.gtk.pool,
  nextpas.core.webview.fake.dispatcher;

const
  FRAME_JSON = '{"v":1,"id":42,"cmd":"demo.sum","payload":{"a":19,"b":23,"name":"npw"}}';
  RESULT_JSON = '{"sum":42,"items":[1,2,3]}';
  REJECT_CODE = 'npw.demo.bad_payload';
  REJECT_MSG = 'payload must be a JSON object';
  EVENT_NAME = 'demo.event';
  EVENT_PAYLOAD = '{"note":"pushed from Pascal","seq":7}';

type
  TBenchProvider = class(TInterfacedObject, IWebviewAssetProvider)
  public
    function TryResolve(const APath: string; out ABytes: TBytes; out AMimeType: string): Boolean;
    function TryResolveView(const AView: TStringView; out ABytes: TBytes; out AMimeType: string): Boolean;
  end;

function TBenchProvider.TryResolve(const APath: string; out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  Result := TryResolveView(TStringView.FromStr(APath), ABytes, AMimeType);
end;

function TBenchProvider.TryResolveView(const AView: TStringView; out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  if TStringView.FromStr('index.html').Equals(AView) then
  begin
    SetLength(ABytes, 26);
    if Length(ABytes)>0 then Move(PAnsiChar('<html>hello webview</html>')^, ABytes[0], 26);
    AMimeType := 'text/html';
    Exit(True);
  end;
  if TStringView.FromStr('app.js').Equals(AView) then
  begin
    SetLength(ABytes, 18);
    if Length(ABytes)>0 then Move(PAnsiChar('console.log("hi")')^, ABytes[0], 18);
    AMimeType := 'application/javascript';
    Exit(True);
  end;
  ABytes := nil;
  AMimeType := '';
  Result := False;
end;

var
  GFrame: TWebviewFrame;
  GSink: string = '';
  GKeep: Boolean = False;
  // scheme / pool / dispatcher sinks — prevent DCE, zero per-op alloc
  GSinkBytes: SizeUInt = 0;
  GSinkHit: Boolean = False;
  GDisp: TFakeDispatcher = nil;
  GAssets: IWebviewAssets = nil;
  GReg: TWebviewInvokeRegistry = nil;
  GDispCounter: Integer = 0;

procedure CheckSetup;
var
  LScript: string;
  B: TBytes;
  M: string;
  PIdle: PIdleRec;
  PComp: PCompletionMarshal;
  PHolder: PAssetHolder;
  PEval: PEvalRec;
  LHits: Boolean;
begin
  if not TryDecodeFrame(FRAME_JSON, GFrame) then
    raise Exception.Create('setup: decode broken');
  if (GFrame.Id <> 42) or (GFrame.Cmd <> 'demo.sum') then
    raise Exception.Create('setup: decode fields wrong');
  if Pos('"b":23', GFrame.PayloadJson) = 0 then
    raise Exception.Create('setup: payload canonicalization broken');
  LScript := BuildResolveScript(7, RESULT_JSON);
  if Pos('__resolve(7,', LScript) = 0 then
    raise Exception.Create('setup: resolve script wrong');
  LScript := BuildRejectScript(7, REJECT_CODE, REJECT_MSG);
  if Pos('__reject(7,', LScript) = 0 then
    raise Exception.Create('setup: reject script wrong');
  LScript := BuildEmitScript(EVENT_NAME, EVENT_PAYLOAD);
  if Pos('__emit(', LScript) = 0 then
    raise Exception.Create('setup: emit script wrong');
  GSink := LScript;
  // pool slab correctness — Acquire/Release inline thin-forward zero-copy
  PoolInit;
  PIdle := AcquireIdleRec;
  if PIdle = nil then raise Exception.Create('setup: pool idle nil');
  ReleaseIdleRec(PIdle);
  PComp := AcquireCompletionRec;
  if PComp = nil then raise Exception.Create('setup: pool completion nil');
  ReleaseCompletionRec(PComp);
  PHolder := AcquireAssetHolder;
  if PHolder = nil then raise Exception.Create('setup: pool holder nil');
  ReleaseAssetHolder(PHolder);
  PEval := AcquireEvalRec;
  if PEval = nil then raise Exception.Create('setup: pool eval nil');
  ReleaseEvalRec(PEval);
  // scheme dispatch correctness — prefixrouter Trie single source O(m) zero-copy view
  GAssets := TWebviewAssetsImpl.Create(False) as IWebviewAssets;
  GAssets.MountEmbedded('', TBenchProvider.Create as IWebviewAssetProvider);
  GAssets.MountEmbedded('static/', TBenchProvider.Create as IWebviewAssetProvider);
  LHits := GAssets.TryResolveView(TStringView.FromStr('index.html'), B, M);
  if not LHits then raise Exception.Create('setup: scheme hit broken');
  if GAssets.TryResolveView(TStringView.FromStr('missing.txt'), B, M) then
    raise Exception.Create('setup: scheme miss broken');
  GSinkHit := LHits;
  GSinkBytes := Length(B);
  // dispatcher Post→Pump round-trip correctness — bytes.ops VecRingCopy single source, short crit <1µs
  GDisp := TFakeDispatcher.Create;
  GDispCounter := 0;
  GDisp.Post(procedure begin Inc(GDispCounter); end);
  if not GDisp.PumpOnce then raise Exception.Create('setup: dispatcher pump broken');
  if GDispCounter <> 1 then raise Exception.Create('setup: dispatcher counter broken');
  // invoke registry find correctness — hashmap single source inline
  GReg := TWebviewInvokeRegistry.Create;
  GReg.Register('bench.ping', function(const APayloadJson: string): string begin Result := '{"pong":1}'; end);
  // keep refs for bench run; finalization releases without leak
end;

procedure BenchDecode(const ACtx: IBenchContext);
begin
  GKeep := TryDecodeFrame(FRAME_JSON, GFrame);
  GSink := GFrame.Cmd;
end;

procedure BenchResolve(const ACtx: IBenchContext);
begin
  GSink := BuildResolveScript(7, RESULT_JSON);
end;

procedure BenchReject(const ACtx: IBenchContext);
begin
  GSink := BuildRejectScript(7, REJECT_CODE, REJECT_MSG);
end;

procedure BenchEmit(const ACtx: IBenchContext);
begin
  GSink := BuildEmitScript(EVENT_NAME, EVENT_PAYLOAD);
end;

// pool Slab — gtk.pool 薄转发 L1 sync.pool 单源 inline 零拷贝，短临界 <1µs，零每 Post 堆分配，稳定性溢出 Dispose 单所有权不丢
procedure BenchPoolIdle(const ACtx: IBenchContext);
var P: PIdleRec;
begin
  P := AcquireIdleRec;
  ReleaseIdleRec(P);
end;

procedure BenchPoolCompletion(const ACtx: IBenchContext);
var P: PCompletionMarshal;
begin
  P := AcquireCompletionRec;
  ReleaseCompletionRec(P);
end;

procedure BenchPoolAsset(const ACtx: IBenchContext);
var P: PAssetHolder;
begin
  P := AcquireAssetHolder;
  ReleaseAssetHolder(P);
end;

procedure BenchPoolEval(const ACtx: IBenchContext);
var P: PEvalRec;
begin
  P := AcquireEvalRec;
  ReleaseEvalRec(P);
end;

// scheme dispatch — TryResolveView zero-copy TStringView→Trie O(m) + hash probe, bytes.ops single source, no heap per hit/miss
procedure BenchSchemeHit(const ACtx: IBenchContext);
var B: TBytes; M: string;
begin
  GSinkHit := GAssets.TryResolveView(TStringView.FromStr('index.html'), B, M);
  GSinkBytes := GSinkBytes + Length(B) + Length(M);
end;

procedure BenchSchemeMiss(const ACtx: IBenchContext);
var B: TBytes; M: string;
begin
  GSinkHit := GAssets.TryResolveView(TStringView.FromStr('missing.txt'), B, M);
  GSinkBytes := GSinkBytes + Length(M);
end;

procedure BenchSchemePrefixHit(const ACtx: IBenchContext);
var B: TBytes; M: string;
begin
  GSinkHit := GAssets.TryResolveView(TStringView.FromStr('static/app.js'), B, M);
  GSinkBytes := GSinkBytes + Length(B);
end;

// dispatcher Post→Pump round-trip — fake.dispatcher FIFO via bytes.ops VecRingCopy/VecGrowCapacity single source, O(1) per op inline, zero mod/div, Invoke 分发经 hashmap 单源
procedure BenchDispatcherPostPump(const ACtx: IBenchContext);
begin
  GDisp.Post(procedure begin Inc(GDispCounter); end);
  GDisp.PumpOnce;
end;

procedure BenchDispatcherBurst(const ACtx: IBenchContext);
var I: Integer;
begin
  for I := 1 to 16 do
    GDisp.Post(procedure begin Inc(GDispCounter); end);
  for I := 1 to 16 do
    GDisp.PumpOnce;
  ACtx.SetBytes(16 * 64);
end;

procedure BenchInvokeFind(const ACtx: IBenchContext);
var LIsAsync: Boolean; LSync: TWebviewInvokeSyncHandler; LAsync: TWebviewInvokeAsyncHandler;
begin
  GSinkHit := GReg.Find('bench.ping', LIsAsync, LSync, LAsync);
  if GSinkHit and not LIsAsync and Assigned(LSync) then
    GSink := LSync('{}');
end;

var
  LSuite: IBenchSuite;
begin
  CheckSetup;
  LSuite := TBenchSuite.Create('bridge-protocol');
  LSuite.Add('TryDecodeFrame', @BenchDecode);
  LSuite.Add('BuildResolveScript', @BenchResolve);
  LSuite.Add('BuildRejectScript', @BenchReject);
  LSuite.Add('BuildEmitScript', @BenchEmit);
  // gtk.pool Slab 热点 — 四池 inline 零拷贝，稳定性 Release 不丢
  LSuite.Add('Pool/IdleRec', @BenchPoolIdle);
  LSuite.Add('Pool/CompletionRec', @BenchPoolCompletion);
  LSuite.Add('Pool/AssetHolder', @BenchPoolAsset);
  LSuite.Add('Pool/EvalRec', @BenchPoolEval);
  // scheme 分发热点 — 最长前缀 Trie + mount 顺序单源
  LSuite.Add('Scheme/Hit', @BenchSchemeHit);
  LSuite.Add('Scheme/Miss404', @BenchSchemeMiss);
  LSuite.Add('Scheme/PrefixHit', @BenchSchemePrefixHit);
  // dispatcher 往返延迟 — CONTRACT §8 基线，Post→Pump exactly-once
  LSuite.Add('Dispatcher/PostPump', @BenchDispatcherPostPump);
  LSuite.Add('Dispatcher/Burst16', @BenchDispatcherBurst);
  // invoke 分发表 — hashmap 单源 Find
  LSuite.Add('Invoke/FindSync', @BenchInvokeFind);
  WriteLn(LSuite.Run.PrintToConsole);
  WriteLn('sink=', Length(GSink), ' keep=', GKeep, ' sinkBytes=', GSinkBytes, ' hit=', GSinkHit, ' disp=', GDispCounter);
  // 稳定性：资源释放不丢 — DropAll + PoolFinalize 逐槽 Dispose，接口置 nil Finalize
  GDisp.DropAll;
  FreeAndNil(GDisp);
  GAssets := nil;
  FreeAndNil(GReg);
  PoolFinalize;
end.
