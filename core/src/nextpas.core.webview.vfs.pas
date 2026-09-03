unit nextpas.core.webview.vfs;

{** @desc webview 家族：IVfs → IWebviewAssetProvider 适配器。

       CONTRACT §3.4 推荐的 respack/vfs 集成路径的唯一实现收口——
       同一份前端资源可在 embedded/os 两种 VFS 后端间切换，下游只认
       IWebviewAssetProvider。

       设计要点：
       - 归一：剥离前导 '/'，大小写与分隔符由 VFS 层负责
       - 前缀兼容：bridge 不剥离 mount 前缀（最长前缀匹配后仍透传全路径），
         适配器对 "app/index.html" 这类含首段 mount 名的请求做容错——
         先试全路径，未命中再试剥首段（"index.html"），每试单次
         VfsReadAllBytes(View) 探读合一（O(log n) 单次二分直达 + 单次
         Open/Read，命中单次重度，404 单次轻量二分收敛零额外二分零重度），
         单请求至多一次重度 I/O，避免手工路径猜测与跨分配器陷阱；剥段分支
         TStringView 零拷贝 Slice 直通 IVfsView（memtree/embedded 真零拷贝
         视图二分，os 单次物化兜底，无 Copy 临时串、无 MaxInt 扫描），
         TryRead/TryReadView inline 单次探读合一、零拷贝 Move 透传，
         热命中零双探放大
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
    function TryResolveView(const AView: TStringView; out ABytes: TBytes;
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

{ perf: inline 单次探读合一（O(log n) 单次二分直达 + 单次重度 VfsReadAllBytes，命中单次 Open/Read，404 单次轻量二分收敛零额外二分零重度放大）；
  热命中零双探：消除 Exists+OpenRead 双次 O(log n) 放大，单次二分直达；命中 SetLength+Move 单次分配零拷贝透传；
  稳定性：VfsReadAllBytes 内 S.Close 于 finally 释放，EVfsNotFound/EVfsIsADirectory/竞态异常统一 False 不丢；
  单源复用：路径比较复用 bytes.ops CompareBytesOrdered 单源 }
function TVfsAssetProvider.TryRead(const APath: string; out ABytes: TBytes;
  out AMime: string): Boolean; inline;
begin
  Result := False;
  ABytes := nil;
  AMime := '';
  try
    ABytes := VfsReadAllBytes(FVfs, APath);
  except
    Exit(False);
  end;
  AMime := GuessMime(APath);
  Result := True;
end;

{ perf: inline 单次探读合一（memtree/embedded 真零拷贝视图二分直达 + 单次重度 VfsReadAllBytesView，os 单次物化兜底，仅单次二分；
  命中单次重度，404 单次轻量二分收敛零额外二分零重度放大）；热命中零双探：消除 VfsExistsView+OpenReadView 双次放大，单次视图二分直达；
  命中 SetLength+Move 单次分配零拷贝透传；稳定性：VfsReadAllBytesView 内 S.Close 于 finally 释放，竞态/异常统一 False；
  单源复用：视图切片复用 nextpas.core.text.view 零拷贝 Slice + bytes.ops CompareBytesOrdered 单源 }
function TVfsAssetProvider.TryReadView(const AView: TStringView; out ABytes: TBytes;
  out AMime: string): Boolean; inline;
begin
  Result := False;
  ABytes := nil;
  AMime := '';
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
  LView: TStringView;
begin
  LView := TStringView.FromStr(APath);
  Result := TryResolveView(LView, ABytes, AMimeType);
end;

function TVfsAssetProvider.TryResolveView(const AView: TStringView; out ABytes: TBytes;
  out AMimeType: string): Boolean;
var
  LNorm: TStringView;
  LLeft, LRight: TStringView;
begin
  ABytes := nil;
  AMimeType := '';
  LNorm := NormalizeWebviewAssetView(AView);
  if LNorm.Len = 0 then
    Exit(False);
  if TryReadView(LNorm, ABytes, AMimeType) then
    Exit(True);
  if LNorm.SplitFirst('/', LLeft, LRight) and (LRight.Len > 0) then
    if TryReadView(LRight, ABytes, AMimeType) then
      Exit(True);
  Result := False;
end;

end.
