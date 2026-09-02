unit nextpas.core.webview.gtk.bridge;

{** @desc GTK bridge transport 缝：scheme 请求资产分发、script-message 桥帧解码、前后端回执/事件注入。

       单源：
       - 协议编解码 → nextpas.core.webview.bridge 唯一权威（TryDecodeFrame/BuildResolveScript 等，inline 零拷贝）
       - 资产路径归一 → nextpas.core.webview.utils NormalizeWebviewAssetView / ViewFromPChar 单源零拷贝 view 哈希 + 单次 SetString+Move
       - MIME → nextpas.core.mime.types MimeTypeFromPath L2 单一事实源 O(1) 哈希（bytes.ops HashFNV1aLower 单源，零转发）
       - 视图索引 → nextpas.core.webview.gtk.viewmap THashMap<Pointer,Pointer> 直接复用 L1 单源（HashOfPointer→HashMix32，VecGrowCapacity 单源）
       - 资产 Holder 池化 → nextpas.core.webview.gtk.pool Acquire/ReleaseAssetHolder 单源（bytes.ops VecGrow + sync.pool 单源，热点小文件零双分配）
       性能：热点 SchemeRequest 零拷贝 COW 共享 + Holder Slab 复用（单 Holder+Stream 零 GBytes 中间对象，G_memory_input_stream_new_from_data 零拷贝切片直通），Threshold 已 retire 统一单路径，inline 零堆抖动，short-circuited view 零中间串
       稳定性：AssetBufFree 绑定 Stream 生命周期经 Holder 回池，G_error 移交 WebKit adoptGRef 不自 free，异常路径 Release holder+finish 404 不丢，Stream 所有权随 finish 移交 *}

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
  nextpas.core.base.utils,
  nextpas.core.exception,
  nextpas.core.sync.mutex,
  nextpas.core.webview.bridge,
  nextpas.core.mime.types,
  nextpas.core.webview.utils,
  nextpas.core.webview.gtk.ffi,
  nextpas.core.webview.gtk.viewmap,
  nextpas.core.webview.gtk.pool,
  nextpas.core.webview.gtk.shell,
  nextpas.core.text.view;

var
  GBridgeErrQuark: GQuark = 0;

procedure BridgeAssetBufFree(AData: Pointer); cdecl; inline;
begin
  // stability: Holder 回池释放 Bytes ref，单所有权不丢；绑定 stream 生命周期，零 GBytes 中间对象
  if AData <> nil then
    nextpas.core.webview.gtk.pool.ReleaseAssetHolder(nextpas.core.webview.gtk.pool.PAssetHolder(AData));
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
  LStream: Pointer;
  LHolder: nextpas.core.webview.gtk.pool.PAssetHolder;
  LView, LWinPtr: Pointer;
  LWin: IWebviewWindow;
  LAssets: IWebviewAssets;
  LData: Pointer;
  LLen: gssize;
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
    // 资产解析接线：CONTRACT §3.4/§5 最长前缀 + 视图硬隔离，单源 via viewmap/shell + IWebviewAssets.TryResolve
    LAssets := nil;
    if Assigned(WEBKIT_uri_scheme_request_get_web_view) then
      LView := WEBKIT_uri_scheme_request_get_web_view(ARequest)
    else
      LView := nil;
    if LView <> nil then
    begin
      LWinPtr := ViewMapFind(LView);
      if (LWinPtr <> nil) and Supports(TObject(LWinPtr), IWebviewWindow, LWin) then
        LAssets := LWin.GetAssets;
    end;
    if LAssets = nil then
    begin
      LWinPtr := ShellLatestLiveWindow;
      if (LWinPtr <> nil) and Supports(TObject(LWinPtr), IWebviewWindow, LWin) then
        LAssets := LWin.GetAssets;
    end;
    if LAssets = nil then
    begin
      BridgeFinishNotFound(ARequest);
      Exit;
    end;
    try
      if not LAssets.TryResolve(LPath, LBytes, LMime) then
      begin
        BridgeFinishNotFound(ARequest);
        Exit;
      end;
    except
      on E: Exception do
      begin
        BridgeFinishNotFound(ARequest);
        Exit;
      end;
    end;
    if LMime = '' then
      LMime := MimeTypeFromPath(LPath);
    LStream := nil;
    if not Assigned(G_memory_input_stream_new_from_data) or not Assigned(WEBKIT_uri_scheme_request_finish) then
    begin
      BridgeFinishNotFound(ARequest);
      Exit;
    end;
    // 热点零拷贝切片：单 Holder Slab 复用 + G_memory_input_stream_new_from_data 直通，零 GBytes 中间对象，Threshold retired 统一单路径，bytes.ops 单源
    LHolder := nextpas.core.webview.gtk.pool.AcquireAssetHolder;
    LHolder^.Bytes := LBytes; // COW 零拷贝共享，bytes.ops 单源，热点小文件零 Move
    try
      if Length(LHolder^.Bytes) > 0 then
      begin
        LData := @LHolder^.Bytes[0];
        LLen := Length(LHolder^.Bytes);
      end
      else
      begin
        LData := nil;
        LLen := 0;
      end;
      LStream := G_memory_input_stream_new_from_data(LData, LLen, @BridgeAssetBufFree, LHolder);
      if not Assigned(LStream) then
      begin
        nextpas.core.webview.gtk.pool.ReleaseAssetHolder(LHolder);
        BridgeFinishNotFound(ARequest);
        Exit;
      end;
    except
      nextpas.core.webview.gtk.pool.ReleaseAssetHolder(LHolder);
      raise;
    end;
    // 稳定性：LStream 所有权随 finish 移交 WebKit，Holder 随 stream destroy 回池，GError adopt 不自 free
    try
      WEBKIT_uri_scheme_request_finish(ARequest, LStream, LLen, PAnsiChar(LMime));
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
