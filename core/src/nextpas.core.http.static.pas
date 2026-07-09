unit nextpas.core.http.static;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{ Serve a single file. Returns handler that reads file and writes it as response.
  Supports range requests (RFC 7233), ETag, Last-Modified, Cache-Control. }
function ServeFile(const APath: string): THttpHandlerFunc;

{ Serve files from a directory. Path param 'filepath' or URL path used as relative file path.
  Example: router.Get('/static/*filepath', ServeDir('/var/www'))
  Supports range requests (RFC 7233), ETag, Last-Modified, Cache-Control. }
function ServeDir(const ARoot: string): THttpHandlerFunc;

{ Serve a single file with Content-Disposition: attachment for download.
  Supports range requests, ETag, Last-Modified, Cache-Control. }
function ServeFileDownload(const APath: string): THttpHandlerFunc; overload;
function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc; overload;

implementation

uses
  nextpas.core.base,
  nextpas.core.fs.base,
  nextpas.core.fs.path,
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.time.format,
  nextpas.core.time.date,
  nextpas.core.time.timeofday,
  nextpas.core.time.offsetdatetime,
  nextpas.core.time.datetime,
  nextpas.core.time.timezone,
  nextpas.core.io.base,
  nextpas.core.fs,
  nextpas.core.io,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.url,
  nextpas.core.http.message;

type
  TResponseWriterAdapter = class(TInterfacedObject, IWriter)
  private
    FWriter: IHttpResponseWriter;
  public
    constructor Create(const AWriter: IHttpResponseWriter);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

{ ===== Implementation ===== }

constructor TResponseWriterAdapter.Create(const AWriter: IHttpResponseWriter);
begin
  inherited Create;
  FWriter := AWriter;
end;

function TResponseWriterAdapter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FWriter.Write(ABuf, ACount);
end;

{ ===== Helpers ===== }

const
  DAY_NAMES: array[1..7] of string = (
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  );
  MONTH_NAMES: array[1..12] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  );

function Pad2(AVal: Integer): string; inline;
begin
  if AVal < 10 then
    Result := '0' + Chr(Ord('0') + AVal)
  else
    Result := Chr(Ord('0') + AVal div 10) + Chr(Ord('0') + AVal mod 10);
end;

function ExtractExt(const APath: string): string;
var
  LI: SizeInt;
begin
  for LI := Length(APath) downto 1 do
  begin
    if APath[LI] = '.' then
      Exit(System.Copy(APath, LI, Length(APath) - LI + 1));
    if APath[LI] = '/' then
      Exit('');
  end;
  Result := '';
end;

function MimeTypeFromExt(const AExt: string): string;
var
  LExt: string;
begin
  LExt := LowerCase(AExt);
  { Text / markup }
  if LExt = '.html' then Result := 'text/html; charset=utf-8'
  else if LExt = '.htm' then Result := 'text/html; charset=utf-8'
  else if LExt = '.css' then Result := 'text/css; charset=utf-8'
  else if LExt = '.txt' then Result := 'text/plain; charset=utf-8'
  else if LExt = '.csv' then Result := 'text/csv; charset=utf-8'
  else if LExt = '.md' then Result := 'text/markdown; charset=utf-8'
  else if LExt = '.xml' then Result := 'application/xml'
  else if LExt = '.svg' then Result := 'image/svg+xml'
  { JavaScript / JSON / WebAssembly }
  else if LExt = '.js' then Result := 'application/javascript; charset=utf-8'
  else if LExt = '.mjs' then Result := 'application/javascript; charset=utf-8'
  else if LExt = '.json' then Result := 'application/json; charset=utf-8'
  else if LExt = '.jsonld' then Result := 'application/ld+json'
  else if LExt = '.wasm' then Result := 'application/wasm'
  { Images }
  else if LExt = '.png' then Result := 'image/png'
  else if LExt = '.jpg' then Result := 'image/jpeg'
  else if LExt = '.jpeg' then Result := 'image/jpeg'
  else if LExt = '.gif' then Result := 'image/gif'
  else if LExt = '.webp' then Result := 'image/webp'
  else if LExt = '.avif' then Result := 'image/avif'
  else if LExt = '.ico' then Result := 'image/x-icon'
  else if LExt = '.bmp' then Result := 'image/bmp'
  else if LExt = '.tiff' then Result := 'image/tiff'
  else if LExt = '.tif' then Result := 'image/tiff'
  else if LExt = '.heic' then Result := 'image/heic'
  else if LExt = '.heif' then Result := 'image/heif'
  else if LExt = '.apng' then Result := 'image/apng'
  { Fonts }
  else if LExt = '.woff' then Result := 'font/woff'
  else if LExt = '.woff2' then Result := 'font/woff2'
  else if LExt = '.ttf' then Result := 'font/ttf'
  else if LExt = '.otf' then Result := 'font/otf'
  else if LExt = '.eot' then Result := 'application/vnd.ms-fontobject'
  { Audio / Video }
  else if LExt = '.mp3' then Result := 'audio/mpeg'
  else if LExt = '.ogg' then Result := 'audio/ogg'
  else if LExt = '.opus' then Result := 'audio/opus'
  else if LExt = '.wav' then Result := 'audio/wav'
  else if LExt = '.flac' then Result := 'audio/flac'
  else if LExt = '.aac' then Result := 'audio/aac'
  else if LExt = '.mp4' then Result := 'video/mp4'
  else if LExt = '.webm' then Result := 'video/webm'
  else if LExt = '.ogv' then Result := 'video/ogg'
  else if LExt = '.avi' then Result := 'video/x-msvideo'
  else if LExt = '.mov' then Result := 'video/quicktime'
  else if LExt = '.mkv' then Result := 'video/x-matroska'
  { Documents }
  else if LExt = '.pdf' then Result := 'application/pdf'
  else if LExt = '.doc' then Result := 'application/msword'
  else if LExt = '.docx' then Result := 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  else if LExt = '.xls' then Result := 'application/vnd.ms-excel'
  else if LExt = '.xlsx' then Result := 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  else if LExt = '.ppt' then Result := 'application/vnd.ms-powerpoint'
  else if LExt = '.pptx' then Result := 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  { Archives }
  else if LExt = '.zip' then Result := 'application/zip'
  else if LExt = '.gz' then Result := 'application/gzip'
  else if LExt = '.tar' then Result := 'application/x-tar'
  else if LExt = '.bz2' then Result := 'application/x-bzip2'
  else if LExt = '.7z' then Result := 'application/x-7z-compressed'
  else if LExt = '.rar' then Result := 'application/vnd.rar'
  { Streaming / manifest }
  else if LExt = '.m3u8' then Result := 'application/vnd.apple.mpegurl'
  else if LExt = '.mpd' then Result := 'application/dash+xml'
  else if LExt = '.ts' then Result := 'video/mp2t'
  { Data interchange }
  else if LExt = '.yaml' then Result := 'application/yaml'
  else if LExt = '.yml' then Result := 'application/yaml'
  else if LExt = '.toml' then Result := 'application/toml'
  else if LExt = '.geojson' then Result := 'application/geo+json'
  { Web manifests }
  else if LExt = '.webmanifest' then Result := 'application/manifest+json'
  else if LExt = '.webapp' then Result := 'application/x-web-app-manifest+json'
  { Fallback }
  else Result := 'application/octet-stream';
end;

{ Returns True if the relative path is safe (no traversal). }
function IsSafePath(const ARelative: string): Boolean;
var
  LI, LLen: SizeInt;
begin
  LLen := Length(ARelative);
  if LLen = 0 then Exit(False);
  { Reject absolute paths }
  if ARelative[1] = '/' then Exit(False);
  { Reject Windows path separators before file lookup. }
  for LI := 1 to LLen do
  begin
    if ARelative[LI] = '\' then
      Exit(False);
    { Reject percent-encoded characters after URL decode — prevents double encoding attacks }
    if ARelative[LI] = '%' then
      Exit(False);
  end;
  { Reject any '..' component }
  LI := 1;
  while LI <= LLen do
  begin
    if (ARelative[LI] = '.') and (LI + 1 <= LLen) and (ARelative[LI + 1] = '.') then
    begin
      { Check it's a full component: at start or after '/', and at end or before '/' }
      if ((LI = 1) or (ARelative[LI - 1] = '/')) and
         ((LI + 2 > LLen) or (ARelative[LI + 2] = '/')) then
        Exit(False);
    end;
    Inc(LI);
  end;
  Result := True;
end;

{ Format Unix timestamp as HTTP date (RFC 7231 §7.1.1.1).
  Example: "Sun, 06 Nov 1994 08:49:37 GMT" }
function FormatHttpDate(AUnixTimestamp: Int64): string;
var
  LDT: TOffsetDateTime;
  LYear, LMonth, LDay, LHour, LMinute, LSecond: Integer;
  LDayOfWeek: Integer;
begin
  LDT := TOffsetDateTime.FromUnixSeconds(AUnixTimestamp);
  LDT := LDT.ToUtc;
  LYear := LDT.GetYear;
  LMonth := LDT.GetMonth;
  LDay := LDT.GetDay;
  LHour := LDT.GetHour;
  LMinute := LDT.GetMinute;
  LSecond := LDT.GetSecond;
  { Zeller's congruence for day of week }
  LDayOfWeek := (LDay + (13 * ((LMonth + 12 * ((14 - LMonth) div 12)) mod 12 + 1)) div 5
    + ((LYear - ((14 - LMonth) div 12)) mod 100)
    + ((LYear - ((14 - LMonth) div 12)) mod 100) div 4
    + ((LYear - ((14 - LMonth) div 12)) div 100) * 5
    + 5) mod 7;
  { Zeller: 0=Sat, 1=Sun, ..., 6=Fri → map to 1=Sun, ..., 7=Sat }
  LDayOfWeek := ((LDayOfWeek + 6) mod 7) + 1;
  Result := DAY_NAMES[LDayOfWeek] + ', '
    + Pad2(LDay) + ' ' + MONTH_NAMES[LMonth] + ' ' + IntToStr(LYear)
    + ' ' + Pad2(LHour) + ':' + Pad2(LMinute) + ':' + Pad2(LSecond)
    + ' GMT';
end;

{ Parse HTTP date string (RFC 7231 §7.1.1.1) to Unix timestamp.
  Accepts: "Sun, 06 Nov 1994 08:49:37 GMT" (preferred)
  Returns 0 on parse failure. }
function ParseHttpDate(const ADate: string): Int64;
var
  LLen, LPos, LMonth, LI: Integer;
  LDay, LYear, LHour, LMinute, LSecond: Integer;
  LMonthStr: string;
  LDT: TOffsetDateTime;
begin
  Result := 0;
  LLen := Length(ADate);
  { Minimum: "Sun, 06 Nov 1994 08:49:37 GMT" = 29 chars }
  if LLen < 29 then Exit;

  { Skip day-name and comma+space: "Sun, " = 5 chars }
  LPos := 5;

  { Parse day (2 digits) }
  if (LPos + 2 > LLen) then Exit;
  LDay := (Ord(ADate[LPos + 1]) - Ord('0')) * 10 + (Ord(ADate[LPos + 2]) - Ord('0'));
  Inc(LPos, 3); { skip day + space }

  { Parse month (3 chars) }
  if (LPos + 3 > LLen) then Exit;
  LMonthStr := System.Copy(ADate, LPos, 3);
  LMonth := 0;
  for LI := 1 to 12 do
    if LMonthStr = MONTH_NAMES[LI] then
    begin
      LMonth := LI;
      Break;
    end;
  if LMonth = 0 then Exit;
  Inc(LPos, 4); { skip month + space }

  { Parse year (4 digits) }
  if (LPos + 4 > LLen) then Exit;
  LYear := (Ord(ADate[LPos]) - Ord('0')) * 1000
         + (Ord(ADate[LPos + 1]) - Ord('0')) * 100
         + (Ord(ADate[LPos + 2]) - Ord('0')) * 10
         + (Ord(ADate[LPos + 3]) - Ord('0'));
  Inc(LPos, 5); { skip year + space }

  { Parse hour:minute:second }
  if (LPos + 8 > LLen) then Exit;
  LHour := (Ord(ADate[LPos]) - Ord('0')) * 10 + (Ord(ADate[LPos + 1]) - Ord('0'));
  LMinute := (Ord(ADate[LPos + 3]) - Ord('0')) * 10 + (Ord(ADate[LPos + 4]) - Ord('0'));
  LSecond := (Ord(ADate[LPos + 6]) - Ord('0')) * 10 + (Ord(ADate[LPos + 7]) - Ord('0'));

  try
    LDT := TOffsetDateTime.Create(
      TNaiveDateTime.Create(LYear, LMonth, LDay, LHour, LMinute, LSecond),
      TUtcOffset.UTC);
    Result := LDT.ToUnixSeconds;
  except
    Result := 0;
  end;
end;

{ Generate ETag from file size and modification time.
  Format: "size-mtime" hex pair for strong ETag. }
function GenerateETag(ASize: Int64; AModTime: Int64): string;
begin
  Result := '"' + IntToHex(ASize, 16) + '-' + IntToHex(AModTime, 16) + '"';
end;

{ Parse Range header value. Returns True if valid single range.
  Format: "bytes=start-end" or "bytes=start-" or "bytes=-suffix" }
function ParseRangeHeader(const ARange: string; AFileSize: Int64;
  out AStart, AEnd: Int64): Boolean;
var
  LPrefix: string;
  LDashPos: SizeInt;
  LStartStr, LEndStr: string;
  LStart, LEnd: Int64;
begin
  Result := False;
  AStart := 0;
  AEnd := 0;
  LPrefix := 'bytes=';
  if Length(ARange) < Length(LPrefix) + 1 then
    Exit;
  if System.Copy(ARange, 1, Length(LPrefix)) <> LPrefix then
    Exit;

  LDashPos := Pos('-', ARange);
  if LDashPos = 0 then
    Exit;

  LStartStr := System.Copy(ARange, Length(LPrefix) + 1, LDashPos - Length(LPrefix) - 1);
  LEndStr := System.Copy(ARange, LDashPos + 1, Length(ARange) - LDashPos);

  if LStartStr = '' then
  begin
    { Suffix range: "bytes=-500" means last 500 bytes }
    if not TryStrToInt64(LEndStr, LEnd) then
      Exit;
    if LEnd <= 0 then
      Exit;
    if LEnd > AFileSize then
      LEnd := AFileSize;
    AStart := AFileSize - LEnd;
    AEnd := AFileSize - 1;
  end
  else
  begin
    if not TryStrToInt64(LStartStr, LStart) then
      Exit;
    if LStart < 0 then
      Exit;
    if LStart >= AFileSize then
      Exit;
    AStart := LStart;
    if LEndStr = '' then
    begin
      { Open-ended: "bytes=500-" means from 500 to end }
      AEnd := AFileSize - 1;
    end
    else
    begin
      if not TryStrToInt64(LEndStr, LEnd) then
        Exit;
      if LEnd < LStart then
        Exit;
      if LEnd >= AFileSize then
        LEnd := AFileSize - 1;
      AEnd := LEnd;
    end;
  end;
  Result := True;
end;

{ Send 416 Range Not Satisfiable response }
procedure SendRangeNotSatisfiable(AFileSize: Int64;
  const AW: IHttpResponseWriter);
begin
  AW.GetHeaders.SetHeader('content-range', 'bytes */' + IntToStr(AFileSize));
  HttpWriteErrorResponse(AW, HTTP_STATUS_RANGE_NOT_SATISFIABLE,
    'range_not_satisfiable', 'Range not satisfiable');
end;

{ Copy file range to writer }
procedure CopyFileRange(const AFile: IFile; const AWriter: IWriter;
  AStart, ACount: Int64);
var
  LBuf: array[0..8191] of Byte;
  LRemaining: Int64;
  LToRead: SizeUInt;
  LN: SizeUInt;
begin
  { Seek to start position }
  AFile.Seek(AStart, soBeginning);
  LRemaining := ACount;
  while LRemaining > 0 do
  begin
    if LRemaining > SizeOf(LBuf) then
      LToRead := SizeOf(LBuf)
    else
      LToRead := SizeUInt(LRemaining);
    LN := AFile.Read(LBuf[0], LToRead);
    if LN = 0 then
      Break;
    AWriter.Write(LBuf[0], LN);
    Dec(LRemaining, LN);
  end;
end;

{ Serve file content with optional range support, ETag, Last-Modified, Cache-Control.
  ADownloadName: if non-empty, set Content-Disposition: attachment with given filename. }
procedure ServeFileContentEx(const AFilePath: string;
  const AReq: IHttpRequest; const AW: IHttpResponseWriter;
  const ADownloadName: string);
var
  LFile: IFile;
  LInfo: TFileInfo;
  LWriter: IWriter;
  LExt: string;
  LMime: string;
  LETag: string;
  LLastModified: string;
  LRangeHeader: string;
  LIfNoneMatch: string;
  LIfModifiedSince: string;
  LStart, LEnd: Int64;
  LFileSize: Int64;
  LEscapedName: string;
begin
  try
    if not nextpas.core.fs.Exists(AFilePath) then
    begin
      HttpWriteErrorNotFound(AW, 'File not found');
      Exit;
    end;
    LInfo := nextpas.core.fs.Stat(AFilePath);
    if LInfo.FileType <> ftRegular then
    begin
      HttpWriteErrorNotFound(AW, 'File not found');
      Exit;
    end;

    LFileSize := LInfo.Size;
    LExt := ExtractExt(AFilePath);
    LMime := MimeTypeFromExt(LExt);
    LETag := GenerateETag(LFileSize, LInfo.ModTime);
    LLastModified := FormatHttpDate(LInfo.ModTime);

    { Conditional request: If-None-Match }
    if AReq <> nil then
    begin
      LIfNoneMatch := AReq.GetHeaders.Get('if-none-match');
      if (LIfNoneMatch <> '') and (LIfNoneMatch = LETag) then
      begin
        AW.GetHeaders.SetHeader('etag', LETag);
        AW.GetHeaders.SetHeader('last-modified', LLastModified);
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.WriteHeader(HTTP_STATUS_NOT_MODIFIED);
        Exit;
      end;

      { Conditional request: If-Modified-Since }
      LIfModifiedSince := AReq.GetHeaders.Get('if-modified-since');
      if (LIfNoneMatch = '') and (LIfModifiedSince <> '') then
      begin
        { RFC 7232 §3.3: parse date and compare timestamps.
          Return 304 if the resource has not been modified since the given date. }
        if LInfo.ModTime <= ParseHttpDate(LIfModifiedSince) then
        begin
          AW.GetHeaders.SetHeader('etag', LETag);
          AW.GetHeaders.SetHeader('last-modified', LLastModified);
          AW.GetHeaders.SetHeader('content-length', '0');
          AW.WriteHeader(HTTP_STATUS_NOT_MODIFIED);
          Exit;
        end;
      end;
    end;

    { Set common headers }
    AW.GetHeaders.SetHeader('content-type', LMime);
    AW.GetHeaders.SetHeader('etag', LETag);
    AW.GetHeaders.SetHeader('last-modified', LLastModified);
    AW.GetHeaders.SetHeader('cache-control', 'public, max-age=0, must-revalidate');
    AW.GetHeaders.SetHeader('x-content-type-options', 'nosniff');
    if ADownloadName <> '' then
    begin
      { RFC 6266: Content-Disposition filename needs quoted-string escaping.
        Escape backslashes and double quotes to prevent header injection. }
      LEscapedName := ADownloadName;
      LEscapedName := nextpas.core.text.conv.StringReplace(LEscapedName, '\', '\\', True);
      LEscapedName := nextpas.core.text.conv.StringReplace(LEscapedName, '"', '\"', True);
      AW.GetHeaders.SetHeader('content-disposition',
        'attachment; filename="' + LEscapedName + '"');
    end;

    { Range request support }
    if AReq <> nil then
      LRangeHeader := AReq.GetHeaders.Get('range')
    else
      LRangeHeader := '';

    if LRangeHeader <> '' then
    begin
      if not ParseRangeHeader(LRangeHeader, LFileSize, LStart, LEnd) then
      begin
        SendRangeNotSatisfiable(LFileSize, AW);
        Exit;
      end;
      LFile := nextpas.core.fs.Open(AFilePath, [fmRead]);
      AW.GetHeaders.SetHeader('content-range',
        'bytes ' + IntToStr(LStart) + '-' + IntToStr(LEnd) + '/' + IntToStr(LFileSize));
      AW.GetHeaders.SetHeader('content-length', IntToStr(LEnd - LStart + 1));
      AW.WriteHeader(HTTP_STATUS_PARTIAL_CONTENT);
      LWriter := TResponseWriterAdapter.Create(AW);
      CopyFileRange(LFile, LWriter, LStart, LEnd - LStart + 1);
    end
    else
    begin
      LFile := nextpas.core.fs.Open(AFilePath, [fmRead]);
      AW.GetHeaders.SetHeader('content-length', IntToStr(LFileSize));
      AW.WriteHeader(HTTP_STATUS_OK);
      LWriter := TResponseWriterAdapter.Create(AW);
      nextpas.core.io.Copy(LWriter, LFile);
    end;
  except
    HttpWriteErrorInternal(AW, 'Internal Server Error');
  end;
end;

{ ===== Public API ===== }

function ServeFile(const APath: string): THttpHandlerFunc;
begin
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    ServeFileContentEx(APath, AReq, AW, '');
  end;
end;

function ServeDir(const ARoot: string): THttpHandlerFunc;
begin
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LRelative: string;
    LFullPath: string;
    LNormalizedRoot: string;
    LNormalizedFull: string;
  begin
    { Try wildcard param first, fall back to URL path }
    LRelative := AReq.PathParam('filepath');
    if LRelative = '' then
    begin
      LRelative := AReq.Path;
      { Strip leading slash }
      if (Length(LRelative) > 0) and (LRelative[1] = '/') then
        LRelative := System.Copy(LRelative, 2, Length(LRelative) - 1);
    end;
    try
      LRelative := nextpas.core.http.url.UrlDecode(LRelative);
    except
      AW.GetHeaders.SetHeader('content-length', '11');
      AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      AW.Write(PAnsiChar('Bad Request')^, 11);
      Exit;
    end;
    { Security: reject traversal attempts }
    if not IsSafePath(LRelative) then
    begin
      AW.GetHeaders.SetHeader('content-length', '11');
      AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      AW.Write(PAnsiChar('Bad Request')^, 11);
      Exit;
    end;
    { Build full path }
    LFullPath := ARoot + '/' + LRelative;
    { Security: verify resolved path stays within root directory.
      This prevents symlink-based directory traversal attacks. }
    LNormalizedRoot := FsPathClean(FsPathAbs(ARoot));
    LNormalizedFull := FsPathClean(FsPathAbs(LFullPath));
    if not (Length(LNormalizedFull) >= Length(LNormalizedRoot)) or
       (System.Copy(LNormalizedFull, 1, Length(LNormalizedRoot)) <> LNormalizedRoot) then
    begin
      AW.GetHeaders.SetHeader('content-length', '9');
      AW.WriteHeader(HTTP_STATUS_FORBIDDEN);
      AW.Write(PAnsiChar('Forbidden')^, 9);
      Exit;
    end;
    ServeFileContentEx(LFullPath, AReq, AW, '');
  end;
end;

function ServeFileDownload(const APath: string): THttpHandlerFunc;
var
  LFileName: string;
  LSlashPos: SizeInt;
begin
  { Extract filename from path }
  LFileName := '';
  for LSlashPos := Length(APath) downto 1 do
    if APath[LSlashPos] = '/' then
    begin
      LFileName := System.Copy(APath, LSlashPos + 1, Length(APath) - LSlashPos);
      Break;
    end;
  if LFileName = '' then
    LFileName := APath;
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    ServeFileContentEx(APath, AReq, AW, LFileName);
  end;
end;

function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc;
begin
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    ServeFileContentEx(APath, AReq, AW, ADownloadName);
  end;
end;

end.
