unit nextpas.core.http.mime;

{** @desc HTTP 静态资源 MIME 猜测薄门面（L3）。
  转发至 L2 nextpas.core.mime.types 单一事实源（65 项零分配 O(1) 哈希），
  本单元仅作 http 兼容别名，消除 L3 同层依赖；实现与 webview.mime 同源，
  零重复表，inline 零额外调用。 *}

{$I nextpas.core.settings.inc}

interface

function HttpMimeFromExt(const AExt: string): string; inline;
function HttpMimeFromPath(const APath: string): string; inline;

implementation

uses
  nextpas.core.mime.types;

function HttpMimeFromExt(const AExt: string): string; inline;
begin
  Result := MimeTypeFromExt(AExt);
end;

function HttpMimeFromPath(const APath: string): string; inline;
begin
  Result := MimeTypeFromPath(APath);
end;

end.
