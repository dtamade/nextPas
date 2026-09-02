unit nextpas.core.webview.mime;

{** @desc webview 家族：MIME 猜测薄门面 — 复用 L2 nextpas.core.mime.types 单一事实源
       （65 项零分配 O(1) 哈希 128 槽，1-2 探测），本单元仅作 webview 兼容转发，
       与 L3 http.mime 同源，消除 L3 同层依赖；inline 零额外调用，
       GuessWebviewMime/View 均零拷贝切片（View 零 ToString 物化）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

function GuessWebviewMime(const APath: string): string; inline;
function GuessWebviewMimeView(const AView: TStringView): string; inline;

implementation

uses
  nextpas.core.mime.types;

function GuessWebviewMime(const APath: string): string; inline;
begin
  Result := MimeTypeFromPath(APath);
end;

function GuessWebviewMimeView(const AView: TStringView): string; inline;
begin
  { perf: inline 零拷贝视图直通 L2 mime.types O(1) 哈希，无 ToString 堆分配，热点零分配 }
  Result := MimeTypeFromPathView(AView);
end;

end.
