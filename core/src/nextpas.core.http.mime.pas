unit nextpas.core.http.mime;

{** @desc HTTP 静态资源 MIME 猜测：扩展名 → Content-Type 快表。
  零分配大小写不敏感二分查找（6 次比较内命中 63 项）；单一事实源供
  ServeFile/ServeDir/ServeVfs 复用，避免各处自养对照表。 }

{$I nextpas.core.settings.inc}

interface

function HttpMimeFromExt(const AExt: string): string;
function HttpMimeFromPath(const APath: string): string;

implementation

type
  TMimeRow = record Ext, Mime: string; end;

const
  MIME_TABLE: array[0..64] of TMimeRow = (
    (Ext: '.7z';       Mime: 'application/x-7z-compressed'),
    (Ext: '.aac';      Mime: 'audio/aac'),
    (Ext: '.apng';     Mime: 'image/apng'),
    (Ext: '.avi';      Mime: 'video/x-msvideo'),
    (Ext: '.avif';     Mime: 'image/avif'),
    (Ext: '.bmp';      Mime: 'image/bmp'),
    (Ext: '.bz2';      Mime: 'application/x-bzip2'),
    (Ext: '.css';      Mime: 'text/css; charset=utf-8'),
    (Ext: '.csv';      Mime: 'text/csv; charset=utf-8'),
    (Ext: '.doc';      Mime: 'application/msword'),
    (Ext: '.docx';     Mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
    (Ext: '.eot';      Mime: 'application/vnd.ms-fontobject'),
    (Ext: '.flac';     Mime: 'audio/flac'),
    (Ext: '.geojson';  Mime: 'application/geo+json'),
    (Ext: '.gif';      Mime: 'image/gif'),
    (Ext: '.gz';       Mime: 'application/gzip'),
    (Ext: '.heic';     Mime: 'image/heic'),
    (Ext: '.heif';     Mime: 'image/heif'),
    (Ext: '.htm';      Mime: 'text/html; charset=utf-8'),
    (Ext: '.html';     Mime: 'text/html; charset=utf-8'),
    (Ext: '.ico';      Mime: 'image/x-icon'),
    (Ext: '.jpeg';     Mime: 'image/jpeg'),
    (Ext: '.jpg';      Mime: 'image/jpeg'),
    (Ext: '.js';       Mime: 'application/javascript; charset=utf-8'),
    (Ext: '.json';     Mime: 'application/json; charset=utf-8'),
    (Ext: '.jsonld';   Mime: 'application/ld+json'),
    (Ext: '.m3u8';     Mime: 'application/vnd.apple.mpegurl'),
    (Ext: '.md';       Mime: 'text/markdown; charset=utf-8'),
    (Ext: '.mjs';      Mime: 'application/javascript; charset=utf-8'),
    (Ext: '.mkv';      Mime: 'video/x-matroska'),
    (Ext: '.mov';      Mime: 'video/quicktime'),
    (Ext: '.mp3';      Mime: 'audio/mpeg'),
    (Ext: '.mp4';      Mime: 'video/mp4'),
    (Ext: '.mpd';      Mime: 'application/dash+xml'),
    (Ext: '.ogg';      Mime: 'audio/ogg'),
    (Ext: '.ogv';      Mime: 'video/ogg'),
    (Ext: '.opus';     Mime: 'audio/opus'),
    (Ext: '.otf';      Mime: 'font/otf'),
    (Ext: '.pdf';      Mime: 'application/pdf'),
    (Ext: '.png';      Mime: 'image/png'),
    (Ext: '.ppt';      Mime: 'application/vnd.ms-powerpoint'),
    (Ext: '.pptx';     Mime: 'application/vnd.openxmlformats-officedocument.presentationml.presentation'),
    (Ext: '.rar';      Mime: 'application/vnd.rar'),
    (Ext: '.svg';      Mime: 'image/svg+xml'),
    (Ext: '.tar';      Mime: 'application/x-tar'),
    (Ext: '.tif';      Mime: 'image/tiff'),
    (Ext: '.tiff';     Mime: 'image/tiff'),
    (Ext: '.toml';     Mime: 'application/toml'),
    (Ext: '.ts';       Mime: 'video/mp2t'),
    (Ext: '.ttf';      Mime: 'font/ttf'),
    (Ext: '.txt';      Mime: 'text/plain; charset=utf-8'),
    (Ext: '.wasm';     Mime: 'application/wasm'),
    (Ext: '.wav';      Mime: 'audio/wav'),
    (Ext: '.webapp';   Mime: 'application/x-web-app-manifest+json'),
    (Ext: '.webm';     Mime: 'video/webm'),
    (Ext: '.webmanifest'; Mime: 'application/manifest+json'),
    (Ext: '.webp';     Mime: 'image/webp'),
    (Ext: '.woff';     Mime: 'font/woff'),
    (Ext: '.woff2';    Mime: 'font/woff2'),
    (Ext: '.xls';      Mime: 'application/vnd.ms-excel'),
    (Ext: '.xlsx';     Mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
    (Ext: '.xml';      Mime: 'application/xml'),
    (Ext: '.yaml';     Mime: 'application/yaml'),
    (Ext: '.yml';      Mime: 'application/yaml'),
    (Ext: '.zip';      Mime: 'application/zip')
  );

function SameExt(const AA, AB: string): Integer;
var
  I, N: Integer;
  CA, CB: Char;
begin
  N := Length(AA);
  if Length(AB) < N then N := Length(AB);
  for I := 1 to N do
  begin
    CA := AA[I];
    CB := AB[I];
    if (CA >= 'A') and (CA <= 'Z') then CA := Chr(Ord(CA) or $20);
    if (CB >= 'A') and (CB <= 'Z') then CB := Chr(Ord(CB) or $20);
    if CA < CB then Exit(-1);
    if CA > CB then Exit(1);
  end;
  if Length(AA) < Length(AB) then Exit(-1);
  if Length(AA) > Length(AB) then Exit(1);
  Result := 0;
end;

function HttpMimeFromExt(const AExt: string): string;
var
  Lo, Hi, Mid, C: Integer;
begin
  Lo := Low(MIME_TABLE);
  Hi := High(MIME_TABLE);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) shr 1;
    C := SameExt(AExt, MIME_TABLE[Mid].Ext);
    if C = 0 then
      Exit(MIME_TABLE[Mid].Mime);
    if C < 0 then
      Hi := Mid - 1
    else
      Lo := Mid + 1;
  end;
  Result := 'application/octet-stream';
end;

function HttpMimeFromPath(const APath: string): string;
var
  LI: SizeInt;
  LExt: string;
begin
  LExt := '';
  for LI := Length(APath) downto 1 do
  begin
    if APath[LI] = '.' then
    begin
      LExt := System.Copy(APath, LI, Length(APath) - LI + 1);
      Break;
    end;
    if APath[LI] = '/' then
      Break;
  end;
  Result := HttpMimeFromExt(LExt);
end;

end.
