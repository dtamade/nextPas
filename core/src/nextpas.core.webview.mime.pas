unit nextpas.core.webview.mime;

{** @desc webview 家族：MIME 猜测薄门面 — 复用 nextpas.core.http.mime 单一事实源
       （65 项零分配二分表），本单元仅作兼容转发，消除 12 项重复表。 *}

{$I nextpas.core.settings.inc}

interface

function GuessWebviewMime(const APath: string): string;

implementation

uses
  nextpas.core.http.mime;

function GuessWebviewMime(const APath: string): string;
begin
  Result := HttpMimeFromPath(APath);
end;

end.
