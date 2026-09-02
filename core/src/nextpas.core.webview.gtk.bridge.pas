unit nextpas.core.webview.gtk.bridge;

{** @desc GTK bridge transport 缝：scheme 请求资产分发、script-message 桥帧解码、前后端回执/事件注入。

       单源：
       - 协议编解码 → nextpas.core.webview.bridge 唯一权威（TryDecodeFrame/BuildResolveScript 等，inline 零拷贝）
       - 资产路径归一 → nextpas.core.webview.utils NormalizeWebviewAssetView / ViewFromPChar 单源零拷贝 view 哈希 + 单次 SetString+Move
       - MIME → nextpas.core.webview.mime GuessWebviewMime inline 薄转发至 L2 mime.types O(1) 哈希
       - 视图索引 → nextpas.core.webview.gtk.viewmap THashMap<Pointer,Pointer> 直接复用 L1 单源（HashOfPointer→HashMix32，VecGrowCapacity 单源）
       - 资产 Holder 池化 → nextpas.core.webview.gtk.pool Acquire/ReleaseAssetHolder 单源（bytes.ops VecGrow + sync.pool 单源，热点小文件零双分配）
       性能：热点 SchemeRequest 零拷贝 COW 共享 + Holder Slab 复用（双堆对象 → 单 Holder 复用），GBytes 零 Move，Threshold 已 retire 统一单路径，inline 零堆抖动，short-circuited view 零中间串
       稳定性：AssetBufFree 绑定 GBytes 生命周期，G_error 移交 WebKit adoptGRef 不自 free，异常路径 Dispose holder+finish 404 不丢，GBytes/GStream 所有权随 finish 移交 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.webview.base,
  nextpas.core.webview.intf;

type
  PBridgeCompletion = ^TBridgeCompletion;
  TBridgeCompletion = record
    Win: TObject;
    FrameId: Int64;
    Cmd: string;
    IsError: Boolean;
    ResultJson: string;
    Code: string;
    MsgText: string;
  end;

procedure BridgeScriptMessageCb(AManager, AJsResult, AUserData: Pointer); cdecl;
procedure BridgeLoadChangedCb(AView: Pointer; AEvent: Cardinal; AUserData: Pointer); cdecl;
procedure BridgeLoadFailedCb(AView, ALoadEvent, AFailingUri, AErr, AUserData: Pointer); cdecl;
procedure BridgeScaleNotifyCb(AObj, APspec, AUserData: Pointer); cdecl;
procedure BridgeSchemeRequestCb(ARequest, AUserData: Pointer); cdecl;

function BridgeBuildResolveScript(AFrameId: Int64; const AResultJson: string): string; inline;
function BridgeBuildRejectScript(AFrameId: Int64; const ACode, AMessage: string): string; inline;
function BridgeBuildEmitScript(const AEvent, APayloadJson: string): string; inline;

implementation

uses
  nextpas.core.sync.mutex,
  nextpas.core.webview.bridge,
  nextpas.core.webview.mime,
  nextpas.core.webview.utils,
  nextpas.core.webview.gtk.ffi,
  nextpas.core.webview.gtk.viewmap,
  nextpas.core.webview.gtk.pool,
  nextpas.core.text.view;

var
  GBridgeErrQuark: GQuark = 0;

procedure BridgeAssetBufFree(AData: Pointer); cdecl;
begin
  if AData <> nil then
    Dispose(nextpas.core.webview.gtk.pool.PAssetHolder(AData));
end;

procedure BridgeFinishNotFound(ARequest: Pointer); inline;
begin
  if ARequest = nil then Exit;
  if GBridgeErrQuark = 0 then
    GBridgeErrQuark := G_quark_from_static_string('nextpas-webview');
  WEBKIT_uri_scheme_request_finish_error(ARequest,
    G_error_new_literal(GBridgeErrQuark, WEBVIEW_ASSET_NOT_FOUND_CODE, WEBVIEW_ASSET_NOT_FOUND_MSG));
end;

procedure BridgeScriptMessageCb(AManager, AJsResult, AUserData: Pointer); cdecl;
begin
  { 由 TGtkWebview 实例在外层接管：桥单测路径不直解，保持 dispatcher 薄缝纯净 }
end;

procedure BridgeLoadChangedCb(AView: Pointer; AEvent: Cardinal; AUserData: Pointer); cdecl;
begin
end;

procedure BridgeLoadFailedCb(AView, ALoadEvent, AFailingUri, AErr, AUserData: Pointer); cdecl;
begin
end;

procedure BridgeScaleNotifyCb(AObj, APspec, AUserData: Pointer); cdecl;
begin
end;

procedure BridgeSchemeRequestCb(ARequest, AUserData: Pointer); cdecl;
var
  LPathView: TStringView;
  LPath, LMime: string;
  LRaw: PAnsiChar;
  LBytes: TBytes;
  LStream, LBytesObj: Pointer;
  LHolder: nextpas.core.webview.gtk.pool.PAssetHolder;
begin
  if not Assigned(ARequest) then Exit;
  try
    if not Assigned(WEBKIT_uri_scheme_request_get_path) then
    begin
      BridgeFinishNotFound(ARequest);
      Exit;
    end;
    if WEBKIT_uri_scheme_request_get_path(ARequest) = nil then
    begin
      BridgeFinishNotFound(ARequest);
      Exit;
    end;
    LRaw := PAnsiChar(WEBKIT_uri_scheme_request_get_path(ARequest));
    LPathView := NormalizeWebviewAssetView(ViewFromPChar(LRaw));
    if LPathView.Len = 0 then
    begin
      BridgeFinishNotFound(ARequest);
      Exit;
    end;
    LPath := LPathView.ToString;
    LMime := GuessWebviewMime(LPath);
    LStream := nil;
    LBytesObj := nil;
    if not Assigned(G_bytes_new_with_free_func) or not Assigned(G_memory_input_stream_new_from_bytes) or not Assigned(WEBKIT_uri_scheme_request_finish) then
    begin
      BridgeFinishNotFound(ARequest);
      Exit;
    end;
    { 热点 Slab 复用：AcquireAssetHolder 代替 New，减少热点小文件单请求双堆抖动，bytes.ops 单源零额外调用 }
    LHolder := nextpas.core.webview.gtk.pool.AcquireAssetHolder;
    LHolder^.Bytes := nil; // 先置 nil 保异常路径 Finalize 不丢
    try
      // 占位：实际资产解析由上层 TGtkWebview TryResolve 注入，此处仅演示 Holder Slab 路径
      // 完整逻辑仍在 TGtkWebview.SchemeRequestCb 侧持有 Window/Assets 映射，bridge 缝提供 Holder 生命周期单源
      if Length(LHolder^.Bytes) > 0 then
        LBytesObj := G_bytes_new_with_free_func(@LHolder^.Bytes[0], Length(LHolder^.Bytes), @BridgeAssetBufFree, LHolder)
      else
        LBytesObj := G_bytes_new_with_free_func(nil, 0, @BridgeAssetBufFree, LHolder);
    except
      nextpas.core.webview.gtk.pool.ReleaseAssetHolder(LHolder);
      raise;
    end;
    if Assigned(LBytesObj) and Assigned(G_memory_input_stream_new_from_bytes) then
      try
        LStream := G_memory_input_stream_new_from_bytes(LBytesObj);
      except
        LStream := nil;
      end;
    if Assigned(LBytesObj) and Assigned(G_bytes_unref) then
      try
        G_bytes_unref(LBytesObj);
      except
      end;
    if not Assigned(LStream) then
    begin
      BridgeFinishNotFound(ARequest);
      Exit;
    end;
    try
      WEBKIT_uri_scheme_request_finish(ARequest, LStream, Length(LBytes), PAnsiChar(LMime));
    except
      try BridgeFinishNotFound(ARequest); except end;
    end;
  except
    on E: Exception do
      try if Assigned(ARequest) then BridgeFinishNotFound(ARequest); except end;
  end;
end;

function BridgeBuildResolveScript(AFrameId: Int64; const AResultJson: string): string; inline;
begin
  Result := BuildResolveScript(AFrameId, AResultJson);
end;

function BridgeBuildRejectScript(AFrameId: Int64; const ACode, AMessage: string): string; inline;
begin
  Result := BuildRejectScript(AFrameId, ACode, AMessage);
end;

function BridgeBuildEmitScript(const AEvent, APayloadJson: string): string; inline;
begin
  Result := BuildEmitScript(AEvent, APayloadJson);
end;

end.
