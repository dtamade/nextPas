unit nextpas.core.mime.types;

{** @desc MIME 扩展名→Content-Type 共享映射（L2 单一事实源）。
  O(1) 开放寻址哈希（128 槽，FNV-1a 小写归一，1-2 探测命中 65 项）；
  零分配切片：Hash 直接哈 PChar 段，CompareBytesIgnoreCase 直比，
  HttpMimeFromPath/GuessWebviewMime 均零 Copy，无堆分配；
  供 L3 http.mime / webview.mime 薄门面 inline 复用，消除 L3 同层依赖。
  单源复用 L0 base.utils HashFNV1aLower/CompareBytesIgnoreCase
  （bytes.ops 同源，零重复）；无句柄/无分配，资源零泄漏。
  性能：LookupBySlice/FromExt/FromPath 全 inline，热路径零额外调用；
  零拷贝：FromPath 在原串上定位 '.' 切片，PChar 段直哈，无 System.Copy。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mime.base,
  nextpas.core.text.view;

const
  MIME_FALLBACK = MEDIA_APPLICATION_OCTET;

function MimeTypeFromExt(const AExt: string): string; inline;
function MimeTypeFromPath(const APath: string): string; inline;
function MimeTypeFromExtView(const AView: TStringView): string; inline;
function MimeTypeFromPathView(const AView: TStringView): string; inline;

implementation

uses
  nextpas.core.base.utils;

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

const
  HASH_SIZE = 128;
  HASH_MASK = HASH_SIZE - 1;
  {$IF (HASH_SIZE and HASH_MASK) <> 0}
    {$FATAL 'HASH_SIZE must be power of two'}
  {$ENDIF}

var
  FMimeHash: array[0..HASH_SIZE - 1] of Integer;

function HashMimeNorm(A: Pointer; ALen: SizeUInt): UInt32; inline;
begin
  if ALen = 0 then
    Exit(2166136261);
  Result := HashFNV1aLower(A, ALen);
end;

function SameSliceVsStr(AP: PChar; ALen: Integer; const B: string): Integer; inline;
var
  PB: Pointer;
begin
  if Length(B) = 0 then PB := nil else PB := @B[1];
  Result := CompareBytesIgnoreCase(AP, PB, SizeUInt(ALen), SizeUInt(Length(B)));
end;

function LookupBySlice(AP: PChar; ALen: Integer): string; inline;
var
  H: UInt32;
  Idx, Probe, Row: Integer;
begin
  if ALen = 0 then
    Exit(MIME_FALLBACK);
  H := HashMimeNorm(AP, SizeUInt(ALen));
  Idx := Integer(H and UInt32(HASH_MASK));
  Probe := 0;
  while Probe < HASH_SIZE do
  begin
    Row := FMimeHash[Idx];
    if Row = -1 then
      Break;
    if SameSliceVsStr(AP, ALen, MIME_TABLE[Row].Ext) = 0 then
      Exit(MIME_TABLE[Row].Mime);
    Idx := (Idx + 1) and HASH_MASK;
    Inc(Probe);
  end;
  Result := MIME_FALLBACK;
end;

procedure BuildMimeHash;
var
  I, Idx, Probe: Integer;
  H: UInt32;
begin
  for I := 0 to HASH_SIZE - 1 do
    FMimeHash[I] := -1;
  for I := 0 to High(MIME_TABLE) do
  begin
    H := HashMimeNorm(Pointer(@MIME_TABLE[I].Ext[1]), SizeUInt(Length(MIME_TABLE[I].Ext)));
    Idx := Integer(H and UInt32(HASH_MASK));
    Probe := 0;
    while (FMimeHash[Idx] <> -1) and (Probe < HASH_SIZE) do
    begin
      Idx := (Idx + 1) and HASH_MASK;
      Inc(Probe);
    end;
    FMimeHash[Idx] := I;
  end;
end;

function MimeTypeFromExt(const AExt: string): string; inline;
begin
  if Length(AExt) = 0 then
    Exit(MIME_FALLBACK);
  Result := LookupBySlice(PChar(@AExt[1]), Length(AExt));
end;

function MimeTypeFromPath(const APath: string): string; inline;
var
  LI: SizeInt;
  DotPos: SizeInt;
begin
  { 零分配：直接在 APath 上定位后缀切片，FNV 哈希不经 System.Copy }
  DotPos := 0;
  for LI := Length(APath) downto 1 do
  begin
    if APath[LI] = '.' then
    begin
      DotPos := LI;
      Break;
    end;
    if APath[LI] = '/' then
      Break;
  end;
  if DotPos = 0 then
    Exit(MIME_FALLBACK);
  Result := LookupBySlice(PChar(@APath[DotPos]), Length(APath) - DotPos + 1);
end;

function MimeTypeFromExtView(const AView: TStringView): string; inline;
begin
  { perf: inline 零拷贝视图直哈，复用 bytes.ops 单源 HashFNV1aLower/CompareBytesIgnoreCase，无堆分配 }
  if AView.Len = 0 then
    Exit(MIME_FALLBACK);
  Result := LookupBySlice(PChar(AView.Data), Integer(AView.Len));
end;

function MimeTypeFromPathView(const AView: TStringView): string; inline;
var
  I: SizeUInt;
  DotPos: SizeInt;
begin
  { perf: inline 零拷贝视图后缀探测，反向扫 '/'/'.' 定位切片后直哈，无 ToString 物化，无 System.Copy }
  if AView.Len = 0 then
    Exit(MIME_FALLBACK);
  DotPos := -1;
  I := AView.Len;
  while I > 0 do
  begin
    Dec(I);
    if AView.Data[I] = '.' then
    begin
      DotPos := SizeInt(I);
      Break;
    end;
    if AView.Data[I] = '/' then
      Break;
  end;
  if DotPos < 0 then
    Exit(MIME_FALLBACK);
  Result := LookupBySlice(PChar(@AView.Data[DotPos]), Integer(AView.Len - SizeUInt(DotPos)));
end;

initialization
  BuildMimeHash;

end.
