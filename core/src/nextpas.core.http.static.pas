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
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.time.format,
  nextpas.core.time.date,
  nextpas.core.time.timeofday,
  nextpas.core.time.offsetdatetime,
  nextpas.core.io.base,
  nextpas.core.fs,
  nextpas.core.io,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.url;

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
  if LExt = '.html' then Result := 'text/html'
  else if LExt = '.htm' then Result := 'text/html'
  else if LExt = '.css' then Result := 'text/css'
  else if LExt = '.js' then Result := 'application/javascript'
  else if LExt = '.json' then Result := 'application/json'
  else if LExt = '.png' then Result := 'image/png'
  else if LExt = '.jpg' then Result := 'image/jpeg'
  else if LExt = '.jpeg' then Result := 'image/jpeg'
  else if LExt = '.gif' then Result := 'image/gif'
  else if LExt = '.svg' then Result := 'image/svg+xml'
  else if LExt = '.txt' then Result := 'text/plain'
  else if LExt = '.xml' then Result := 'application/xml'
  else if LExt = '.pdf' then Result := 'application/pdf'
  else if LExt = '.wasm' then Result := 'application/wasm'
  else if LExt = '.ico' then Result := 'image/x-icon'
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
    if ARelative[LI] = '\' then
      Exit(False);
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
  AW.GetHeaders.SetHeader('content-type', 'text/plain; charset=utf-8');
  AW.GetHeaders.SetHeader('content-length', '16');
  AW.WriteHeader(HTTP_STATUS_RANGE_NOT_SATISFIABLE);
  AW.Write(PAnsiChar('Range Not Satisf')^, 16);
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
begin
  try
    if not nextpas.core.fs.Exists(AFilePath) then
    begin
      AW.GetHeaders.SetHeader('content-type', 'text/plain; charset=utf-8');
      AW.GetHeaders.SetHeader('content-length', '9');
      AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
      AW.Write(PAnsiChar('Not Found')^, 9);
      Exit;
    end;
    LInfo := nextpas.core.fs.Stat(AFilePath);
    if LInfo.FileType <> ftRegular then
    begin
      AW.GetHeaders.SetHeader('content-type', 'text/plain; charset=utf-8');
      AW.GetHeaders.SetHeader('content-length', '9');
      AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
      AW.Write(PAnsiChar('Not Found')^, 9);
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
        { Simplified: if header matches Last-Modified, return 304 }
        if LIfModifiedSince = LLastModified then
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
    if ADownloadName <> '' then
      AW.GetHeaders.SetHeader('content-disposition',
        'attachment; filename="' + ADownloadName + '"');

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
    AW.GetHeaders.SetHeader('content-type', 'text/plain');
    AW.GetHeaders.SetHeader('content-length', '21');
    AW.WriteHeader(HTTP_STATUS_INTERNAL_SERVER_ERROR);
    AW.Write(PAnsiChar('Internal Server Error')^, 21);
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
