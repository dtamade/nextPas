program bench_bridge;
{** @desc bench: 桥协议热路径基线（bench 框架版）。
       计时前硬校验正确性，暴露解码/回执构造吞吐、gtk.pool Slab 与 scheme
       分发热点、dispatcher Post 往返延迟及 IsOversizedExpanded 膨胀水位与
       1MiB 边界拒绝脚本吞吐分片；覆盖 CONTRACT §8 dispatcher 基线与
       BRIDGE_PROTOCOL §6 1MiB Hard Limit 阈值/膨胀水位可观测闭环。
       框架：nextpas.core.bench，禁自定义计时。
       单源：pool 经 bytes.ops VecGrowCapacity/SyncPool 单源 inline 零拷贝，
             scheme 经 prefixrouter Trie + hashmap 单源，dispatcher 经
             fake.dispatcher 环形 FIFO bytes.ops VecRingCopy 单源，
             阈值/膨胀经 metrics Owner METRICS_MAX_FRAME_BYTES + MetricsExpandedSize/IsOversizedExpanded* 单源 inline 零拷贝视图，拒绝脚本经 TryBuildOversizedReject 薄转发零重复。 *}

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
  nextpas.core.metrics.base,
  nextpas.core.metrics,
  nextpas.core.webview.metrics,
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
  // IsOversizedExpanded 膨胀水位与 1MiB 边界分片 sinks — prevent DCE, zero per-op alloc, inline 零拷贝视图
  GHitJson: string = '';
  GHitView: TStringView;
  GBoundaryJson: string = '';
  GBoundaryView: TStringView;
  GMissJson: string = '';
  GMissView: TStringView;
  GLargeRawStr: string = '';
  GLargeRawView: TStringView;
  GSmallRawStr: string = '';
  GSmallRawView: TStringView;
  GLargePayloadStr: string = '';
  GLargePayloadView: TStringView;
  GSmallPayloadStr: string = '';
  GSmallPayloadView: TStringView;
  GExpandedFrameJson: string = '';
  GExpandedFrameView: TStringView;
  GOverFrame: TWebviewFrame;
  GExpandedSizeSink: SizeUInt = 0;
  GRejectHitSink: string = '';
  GRejectMissSink: string = '';
  GRejectBoundarySink: string = '';
  GOversizedHitFlag: Boolean = False;

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
  LPrefix, LSuffix, LPrefix2, LSuffix2: string;
  LTarget, LPad, LTarget2, LPad2: Integer;
  LTmp: string;
  LOk: Boolean;
begin
  if not TryDecodeFrame(FRAME_JSON, GFrame) then
    raise Exception.Create('setup: decode broken');
  if (GFrame.Id <> 42) or (GFrame.Cmd <> 'demo.sum') then
    raise Exception.Create('setup: decode fields wrong');
  if Pos('"b":23', GFrame.Payload.ToString) = 0 then
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
  // IsOversized/膨胀水位与 1MiB 边界分片准备 — 一次性分配、bench 零每迭代堆分配，复用 metrics 单源阈值常量零魔法数漂移
  GMissJson := '{"v":1,"id":42,"cmd":"bench.ping","payload":{"a":1}}';
  GMissView := TStringView.FromStr(GMissJson);
  // 1MiB Hard Limit 单源常量 METRICS_MAX_FRAME_BYTES 薄转发零双写；Hit: 1MiB+1 valid JSON with extractable id → TryBuildOversizedReject 全路径
  LPrefix := '{"v":1,"id":99,"cmd":"a","payload":"';
  LSuffix := '"}';
  LTarget := Integer(METRICS_MAX_FRAME_BYTES) + 1;
  LPad := LTarget - Length(LPrefix) - Length(LSuffix);
  if LPad < 0 then LPad := 0;
  GHitJson := LPrefix + StringOfChar('x', LPad) + LSuffix;
  GHitView := TStringView.FromStr(GHitJson);
  // Boundary: exactly 1MiB → IsOversized false, TryBuildOversizedReject miss 零解析分片
  LTarget := Integer(METRICS_MAX_FRAME_BYTES);
  LPad := LTarget - Length(LPrefix) - Length(LSuffix);
  if LPad < 0 then LPad := 0;
  GBoundaryJson := LPrefix + StringOfChar('x', LPad) + LSuffix;
  GBoundaryView := TStringView.FromStr(GBoundaryJson);
  // 膨胀水位分片 — raw+payload+arena 零拷贝视图 Len 判定，复用 metrics ExpandedSize 单源 inline 零额外调用
  GSmallRawStr := StringOfChar('r', 4*1024);
  GSmallRawView := TStringView.FromStr(GSmallRawStr);
  GLargeRawStr := StringOfChar('r', 700*1024);
  GLargeRawView := TStringView.FromStr(GLargeRawStr);
  GSmallPayloadStr := StringOfChar('p', 100);
  GSmallPayloadView := TStringView.FromStr(GSmallPayloadStr);
  GLargePayloadStr := StringOfChar('p', 300*1024);
  GLargePayloadView := TStringView.FromStr(GLargePayloadStr);
  // 解码 ExpandedGuard 分片 — raw 800KiB (<1MiB) 但 expanded >1MiB → TryDecodeFrame 解析后二次校验拒绝
  LPrefix2 := '{"v":1,"id":55,"cmd":"bench.test","payload":"';
  LSuffix2 := '"}';
  LTarget2 := 800*1024;
  LPad2 := LTarget2 - Length(LPrefix2) - Length(LSuffix2);
  if LPad2 < 0 then LPad2 := 0;
  GExpandedFrameJson := LPrefix2 + StringOfChar('y', LPad2) + LSuffix2;
  GExpandedFrameView := TStringView.FromStr(GExpandedFrameJson);
  // correctness hard gates for new shards — before timing, zero per-op alloc
  if not IsWebviewFrameOversizedView(GHitView) then
    raise Exception.Create('setup: IsOversized hit broken');
  if IsWebviewFrameOversizedView(GMissView) then
    raise Exception.Create('setup: IsOversized miss broken');
  if IsWebviewFrameOversizedView(GBoundaryView) then
    raise Exception.Create('setup: IsOversized boundary broken');
  if MetricsExpandedSize(GSmallRawView, GSmallPayloadView.Len) <> (GSmallRawView.Len + GSmallPayloadView.Len + (GSmallRawView.Len shr 1) + 1024) then
    raise Exception.Create('setup: ExpandedSize broken');
  if not IsWebviewFrameOversizedExpandedLen(GLargeRawView, GLargePayloadView.Len) then
    raise Exception.Create('setup: IsOversizedExpanded hit broken');
  if IsWebviewFrameOversizedExpandedLen(GSmallRawView, GSmallPayloadView.Len) then
    raise Exception.Create('setup: IsOversizedExpanded miss broken');
  if IsWebviewFrameOversizedExpanded(GLargeRawView, GLargePayloadView) <> IsWebviewFrameOversizedExpandedLen(GLargeRawView, GLargePayloadView.Len) then
    raise Exception.Create('setup: expanded view/len diverge');
  // TryBuildOversizedReject 分片硬校验 — hit 产 reject 脚本，miss/boundary 空
  LOk := TryBuildOversizedReject(GMissView, LTmp);
  if LOk then raise Exception.Create('setup: reject miss should be false');
  LOk := TryBuildOversizedReject(GBoundaryView, LTmp);
  if LOk then raise Exception.Create('setup: reject boundary should be false');
  LOk := TryBuildOversizedReject(GHitView, LTmp);
  if not LOk then raise Exception.Create('setup: reject hit should be true');
  if Pos('__reject(99,', LTmp) = 0 then raise Exception.Create('setup: reject hit script broken');
  GRejectHitSink := LTmp;
  // expanded guard decode hard gate — oversized raw 快径拒绝
  if TryDecodeFrame(GHitView, GOverFrame) then raise Exception.Create('setup: decode oversized guard broken');
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

// IsOversized 单源阈值 — inline 零拷贝 TStringView.Len > METRICS_MAX_FRAME_BYTES，L2 metrics Owner 单源零额外调用
procedure BenchIsOversizedMiss(const ACtx: IBenchContext);
begin
  GSinkHit := IsWebviewFrameOversizedView(GMissView);
end;

procedure BenchIsOversizedHit(const ACtx: IBenchContext);
begin
  GSinkHit := IsWebviewFrameOversizedView(GHitView);
end;

procedure BenchIsOversizedBoundary(const ACtx: IBenchContext);
begin
  GSinkHit := IsWebviewFrameOversizedView(GBoundaryView);
end;

// 膨胀水位 — raw+payload+arena 水位 ExpandedSize + IsOversizedExpanded* 零拷贝视图，bytes.ops 单源思想 inline 零额外调用，零堆分配
procedure BenchExpandedSize(const ACtx: IBenchContext);
begin
  GExpandedSizeSink := MetricsExpandedSize(GLargeRawView, GLargePayloadView.Len);
  GSinkBytes := GSinkBytes + GExpandedSizeSink;
end;

procedure BenchIsOversizedExpandedMiss(const ACtx: IBenchContext);
begin
  GSinkHit := IsWebviewFrameOversizedExpandedLen(GSmallRawView, GSmallPayloadView.Len);
end;

procedure BenchIsOversizedExpandedHit(const ACtx: IBenchContext);
begin
  GSinkHit := IsWebviewFrameOversizedExpandedLen(GLargeRawView, GLargePayloadView.Len);
end;

procedure BenchIsOversizedExpandedViewHit(const ACtx: IBenchContext);
begin
  GSinkHit := IsWebviewFrameOversizedExpanded(GLargeRawView, GLargePayloadView);
end;

// 1MiB 边界拒绝脚本吞吐 — TryBuildOversizedReject 薄转发 L2 阈值单源，hit 路径池化 Doc 复用+BuildRejectScript 转义零每迭代堆分配，miss 零解析零分配 inline 零拷贝视图
procedure BenchTryBuildOversizedRejectMiss(const ACtx: IBenchContext);
var LScript: string; LOk: Boolean;
begin
  LOk := TryBuildOversizedReject(GMissView, LScript);
  GOversizedHitFlag := LOk;
  GRejectMissSink := LScript;
end;

procedure BenchTryBuildOversizedRejectHit(const ACtx: IBenchContext);
var LScript: string; LOk: Boolean;
begin
  LOk := TryBuildOversizedReject(GHitView, LScript);
  GOversizedHitFlag := LOk;
  GRejectHitSink := LScript;
end;

procedure BenchTryBuildOversizedRejectBoundary(const ACtx: IBenchContext);
var LScript: string; LOk: Boolean;
begin
  LOk := TryBuildOversizedReject(GBoundaryView, LScript);
  GOversizedHitFlag := LOk;
  GRejectBoundarySink := LScript;
end;

// 解码分片守卫 — TryDecodeFrame 解析前 IsOversized 快径 + 解析后 IsOversizedExpanded 水位二次校验，池化 Doc 复用零每帧堆分配，TStringView.RawSlice 零拷贝
procedure BenchDecodeOversizedGuard(const ACtx: IBenchContext);
var LOk: Boolean; LFrame: TWebviewFrame;
begin
  LOk := TryDecodeFrame(GHitView, LFrame);
  GSinkHit := LOk;
  GSink := LFrame.Cmd;
end;

procedure BenchDecodeExpandedGuard(const ACtx: IBenchContext);
var LOk: Boolean; LFrame: TWebviewFrame;
begin
  LOk := TryDecodeFrame(GExpandedFrameView, LFrame);
  GOversizedHitFlag := LOk;
  GSink := LFrame.Cmd;
  GExpandedSizeSink := LFrame.Payload.Len;
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
  // IsOversized 单源阈值 — 1MiB Hard Limit 常量即契约，metrics Owner 单源 inline 零拷贝视图
  LSuite.Add('IsOversized/Miss', @BenchIsOversizedMiss);
  LSuite.Add('IsOversized/Hit1MiB+1', @BenchIsOversizedHit);
  LSuite.Add('IsOversized/Boundary1MiB', @BenchIsOversizedBoundary);
  // 膨胀水位 — raw+payload+arena 零拷贝视图，bytes.ops 单源思想 inline 零额外调用
  LSuite.Add('Expanded/Size', @BenchExpandedSize);
  LSuite.Add('IsOversizedExpanded/Miss', @BenchIsOversizedExpandedMiss);
  LSuite.Add('IsOversizedExpanded/Hit', @BenchIsOversizedExpandedHit);
  LSuite.Add('IsOversizedExpanded/ViewHit', @BenchIsOversizedExpandedViewHit);
  // 1MiB 边界拒绝脚本吞吐 — TryBuildOversizedReject 薄转发零重复，分片覆盖 miss/boundary/hit 三档
  LSuite.Add('OversizedReject/Miss', @BenchTryBuildOversizedRejectMiss);
  LSuite.Add('OversizedReject/Hit1MiB+1', @BenchTryBuildOversizedRejectHit);
  LSuite.Add('OversizedReject/Boundary1MiB', @BenchTryBuildOversizedRejectBoundary);
  // 解码分片守卫 — TryDecodeFrame 解析前 IsOversized 快径 + 解析后 Expanded 水位二次校验，池化 Doc 零每帧堆分配
  LSuite.Add('Decode/OversizedGuard', @BenchDecodeOversizedGuard);
  LSuite.Add('Decode/ExpandedGuard', @BenchDecodeExpandedGuard);
  WriteLn(LSuite.Run.PrintToConsole);
  WriteLn('sink=', Length(GSink), ' keep=', GKeep, ' sinkBytes=', GSinkBytes, ' hit=', GSinkHit, ' disp=', GDispCounter, ' expanded=', GExpandedSizeSink, ' rejectHitLen=', Length(GRejectHitSink), ' oversizedHit=', GOversizedHitFlag);
  // 稳定性：资源释放不丢 — DropAll + PoolFinalize 逐槽 Dispose，接口置 nil Finalize，串视图随字符串生命周期释放不丢
  GDisp.DropAll;
  FreeAndNil(GDisp);
  GAssets := nil;
  FreeAndNil(GReg);
  // 分片大串随管理字符串析构释放不丢，视图零独立句柄
  GHitJson := '';
  GBoundaryJson := '';
  GMissJson := '';
  GLargeRawStr := '';
  GSmallRawStr := '';
  GLargePayloadStr := '';
  GSmallPayloadStr := '';
  GExpandedFrameJson := '';
  PoolFinalize;
end.
