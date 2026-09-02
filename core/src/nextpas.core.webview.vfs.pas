unit nextpas.core.webview.vfs;

{** @desc webview 家族：IVfs → IWebviewAssetProvider 适配器。

       CONTRACT §3.4 推荐的 respack/vfs 集成路径的唯一实现收口——
       同一份前端资源可在 embedded/os 两种 VFS 后端间切换，下游只认
       IWebviewAssetProvider。

       设计要点：
       - 归一：剥离前导 '/'，大小写与分隔符由 VFS 层负责
       - 前缀兼容：bridge 不剥离 mount 前缀（最长前缀匹配后仍透传全路径），
         适配器对 "app/index.html" 这类含首段 mount 名的请求做容错——
         先试全路径，未命中再试剥首段（"index.html"），两试均经
         VFS Exists 轻量二分判定（O(log n) 零重度 Open/Read）再按需单次
         重度 VfsReadAllBytes(View)（命中单次 Open/Read，404 零额外重度），
         单请求至多一次重度 I/O，避免手工路径猜测与跨分配器陷阱；剥段分支
         TStringView 零拷贝 Slice 直通 IVfsView（memtree/embedded 真零拷贝
         视图二分，os 单次物化兜底，无 Copy 临时串、无 MaxInt 扫描），
         TryRead/TryReadView inline 轻量二分先探后重、零拷贝 Move 透传，
         404 热路径零重度放大
       - 二进制安全：VfsReadAllBytes 原样透传，MIME 快表仅 ~10 条常见映射，
         未命中回退 application/octet-stream
       - 零额外依赖：仅 L0-L2（vfs owner）+ webview.intf/base *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.vfs,
  nextpas.core.webview.intf;

{ 包装给定 VFS 为 asset provider；AVfs=nil 抛 EWebviewInvalidState。 }
function CreateVfsAssetProvider(const AVfs: IVfs): IWebviewAssetProvider;

implementation

uses
  nextpas.core.base,
  nextpas.core.text.view,
  nextpas.core.webview.base,
  nextpas.core.webview.utils,
  nextpas.core.mime.types,
  nextpas.core.vfs.util;

type
  TVfsAssetProvider = class(TInterfacedObject, IWebviewAssetProvider)
  private
    FVfs: IVfs;
    function GuessMime(const APath: string): string; inline;
    function GuessMimeView(const AView: TStringView): string; inline;
    function TryRead(const APath: string; out ABytes: TBytes;
      out AMime: string): Boolean; inline;
    function TryReadView(const AView: TStringView; out ABytes: TBytes;
      out AMime: string): Boolean; inline;
  public
    constructor Create(const AVfs: IVfs);
    function TryResolve(const APath: string; out ABytes: TBytes;
      out AMimeType: string): Boolean;
  end;

function CreateVfsAssetProvider(const AVfs: IVfs): IWebviewAssetProvider;
begin
  if AVfs = nil then
    raise EWebviewInvalidState.Create('VFS asset provider requires a non-nil IVfs');
  Result := TVfsAssetProvider.Create(AVfs);
end;

constructor TVfsAssetProvider.Create(const AVfs: IVfs);
begin
  inherited Create;
  FVfs := AVfs;
end;

function TVfsAssetProvider.GuessMime(const APath: string): string; inline;
begin
  { perf: inline 直通 L2 mime.types MimeTypeFromPath O(1) 哈希，无 ToString 物化，热点零分配；复用 bytes.ops HashFNV1aLower 单源 }
  Result := MimeTypeFromPath(APath);
end;

function TVfsAssetProvider.GuessMimeView(const AView: TStringView): string; inline;
begin
  { perf: inline 零拷贝视图直通 L2 mime.types MimeTypeFromPathView 128槽 O(1) 哈希，无 ToString 堆分配，热点零分配；复用 bytes.ops 单源 }
  Result := MimeTypeFromPathView(AView);
end;

{ perf: inline 轻量 Exists 二分先探（O(log n) 零重度 Open）命中再 VfsReadAllBytes 单次重度；
  404 轻量二分收敛零额外二分零重度放大；命中 SetLength+Move 单次分配零拷贝透传；
  稳定性：VfsReadAllBytes 内 S.Close 于 finally 释放，竞态/异常统一 False；
  单源复用：路径比较复用 bytes.ops CompareBytesOrdered 单源 }
function TVfsAssetProvider.TryRead(const APath: string; out ABytes: TBytes;
  out AMime: string): Boolean; inline;
begin
  Result := False;
  ABytes := nil;
  AMime := '';
  if not FVfs.Exists(APath) then
    Exit;
  try
    ABytes := VfsReadAllBytes(FVfs, APath);
  except
    Exit(False);
  end;
  AMime := GuessMime(APath);
  Result := True;
end;

{ perf: inline 轻量 ExistsView 二分先探（memtree/embedded 真零拷贝视图二分、os 单次物化兜底，零重度 Open）
  命中再 VfsReadAllBytesView 单次重度；404 轻量二分收敛零额外二分零重度放大；命中 SetLength+Move 单次分配零拷贝透传；
  稳定性：VfsReadAllBytesView 内 S.Close 于 finally 释放，竞态/异常统一 False；
  单源复用：视图切片复用 nextpas.core.text.view 零拷贝 Slice + bytes.ops CompareBytesOrdered 单源 }
function TVfsAssetProvider.TryReadView(const AView: TStringView; out ABytes: TBytes;
  out AMime: string): Boolean; inline;
begin
  Result := False;
  ABytes := nil;
  AMime := '';
  if not VfsExistsView(FVfs, AView) then
    Exit;
  try
    ABytes := VfsReadAllBytesView(FVfs, AView);
  except
    Exit(False);
  end;
  AMime := GuessMimeView(AView);
  Result := True;
end;

function TVfsAssetProvider.TryResolve(const APath: string; out ABytes: TBytes;
  out AMimeType: string): Boolean;
var
  LNorm: string;
  LView, LLeft, LRight: TStringView;
begin
  ABytes := nil;
  AMimeType := '';
  LNorm := NormalizeWebviewAssetPath(APath);
  if LNorm = '' then
    Exit(False);
  { 先试全路径（mount 前缀保留的形态）；TryRead 轻量 Exists 二分先探，命中再单次重度 VfsReadAllBytes }
  if TryRead(LNorm, ABytes, AMimeType) then
    Exit(True);
  { 回退：剥首段（兼容 mount '' + URL 含 "app/" 前缀的常见形态）。
    例如 "app/index.html" → "index.html"。TStringView 零拷贝 Slice 直通
    IVfsView（memtree/embedded 真零拷贝视图二分，os 单次物化兜底，无 Copy 临时串、无 MaxInt 扫描）；
    单请求至多一次重度 I/O（两试均轻量 Exists 二分先探，404 零重度，命中单次重度 VfsReadAllBytesView）；
    单源复用：路径切片复用 nextpas.core.text.view 零拷贝视图 + bytes.ops CompareBytesOrdered/VfsNameCompareView 单源
    （与 bytes.ops VecGrowCapacity / Span 单源策略同源，避免跨单元重复切片实现）；
    TryReadView inline 轻量先探零额外二分，零拷贝 Move 透传。 }
  LView := TStringView.FromStr(LNorm);
  if LView.SplitFirst('/', LLeft, LRight) and (LRight.Len > 0) then
  begin
    if TryReadView(LRight, ABytes, AMimeType) then
      Exit(True);
  end;
  Result := False;
end;

end.
