unit nextpas.core.webview.mime;

{** @desc webview 家族：共享 MIME 快表——12 项常见类型二分查找，
       供 vfs 适配器与未来 asset provider 复用（CONTRACT §3.4）。
       单一事实源，避免每 provider 各养一份表。 *}

{$I nextpas.core.settings.inc}

interface

function GuessWebviewMime(const APath: string): string;

implementation

uses
  SysUtils;

type
  TMimeRow = record Ext, Mime: string; end;

const
  MIME_TABLE: array[0..11] of TMimeRow = (
    (Ext: '.css';  Mime: 'text/css; charset=utf-8'),
    (Ext: '.htm';  Mime: 'text/html; charset=utf-8'),
    (Ext: '.html'; Mime: 'text/html; charset=utf-8'),
    (Ext: '.jpeg'; Mime: 'image/jpeg'),
    (Ext: '.jpg';  Mime: 'image/jpeg'),
    (Ext: '.js';   Mime: 'application/javascript; charset=utf-8'),
    (Ext: '.json'; Mime: 'application/json; charset=utf-8'),
    (Ext: '.mjs';  Mime: 'application/javascript; charset=utf-8'),
    (Ext: '.png';  Mime: 'image/png'),
    (Ext: '.svg';  Mime: 'image/svg+xml'),
    (Ext: '.txt';  Mime: 'text/plain; charset=utf-8'),
    (Ext: '.wasm'; Mime: 'application/wasm')
  );

function GuessWebviewMime(const APath: string): string;
var
  LExt: string;
  L, R, M, C: Integer;
begin
  LExt := LowerCase(ExtractFileExt(APath));
  L := Low(MIME_TABLE);
  R := High(MIME_TABLE);
  while L <= R do
  begin
    M := (L + R) shr 1;
    C := CompareStr(LExt, MIME_TABLE[M].Ext);
    if C = 0 then
      Exit(MIME_TABLE[M].Mime);
    if C < 0 then
      R := M - 1
    else
      L := M + 1;
  end;
  Result := 'application/octet-stream';
end;

end.
