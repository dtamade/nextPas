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
         VFS Exists 判定，避免手工路径猜测与跨分配器陷阱
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
  SysUtils,
  nextpas.core.webview.base,
  nextpas.core.vfs.util;

type
  TVfsAssetProvider = class(TInterfacedObject, IWebviewAssetProvider)
  private
    FVfs: IVfs;
    function GuessMime(const APath: string): string;
    function TryRead(const APath: string; out ABytes: TBytes;
      out AMime: string): Boolean;
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

function TVfsAssetProvider.GuessMime(const APath: string): string;
var
  LExt: string;
begin
  LExt := LowerCase(ExtractFileExt(APath));
  if LExt = '.html' then Exit('text/html; charset=utf-8');
  if LExt = '.htm' then Exit('text/html; charset=utf-8');
  if LExt = '.js' then Exit('application/javascript; charset=utf-8');
  if LExt = '.mjs' then Exit('application/javascript; charset=utf-8');
  if LExt = '.css' then Exit('text/css; charset=utf-8');
  if LExt = '.json' then Exit('application/json; charset=utf-8');
  if LExt = '.png' then Exit('image/png');
  if LExt = '.jpg' then Exit('image/jpeg');
  if LExt = '.jpeg' then Exit('image/jpeg');
  if LExt = '.svg' then Exit('image/svg+xml');
  if LExt = '.txt' then Exit('text/plain; charset=utf-8');
  if LExt = '.wasm' then Exit('application/wasm');
  Result := 'application/octet-stream';
end;

function TVfsAssetProvider.TryRead(const APath: string; out ABytes: TBytes;
  out AMime: string): Boolean;
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

function TVfsAssetProvider.TryResolve(const APath: string; out ABytes: TBytes;
  out AMimeType: string): Boolean;
var
  LNorm, LStripped: string;
  LSlash: Integer;
begin
  ABytes := nil;
  AMimeType := '';
  LNorm := APath;
  while (Length(LNorm) > 0) and (LNorm[1] = '/') do
    Delete(LNorm, 1, 1);
  if LNorm = '' then
    Exit(False);
  { 先试全路径（mount 前缀保留的形态） }
  if TryRead(LNorm, ABytes, AMimeType) then
    Exit(True);
  { 回退：剥首段（兼容 mount '' + URL 含 "app/" 前缀的常见形态）。
    例如 "app/index.html" → "index.html"。 }
  LSlash := Pos('/', LNorm);
  if LSlash > 0 then
  begin
    LStripped := Copy(LNorm, LSlash + 1, MaxInt);
    if (LStripped <> '') and TryRead(LStripped, ABytes, AMimeType) then
      Exit(True);
  end;
  Result := False;
end;

end.
