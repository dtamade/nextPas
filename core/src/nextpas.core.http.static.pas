unit nextpas.core.http.static;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf,
  nextpas.core.vfs.intf;

{ Serve a single file. Returns handler that reads file and writes it as response.
  Supports range requests (RFC 7233), ETag, Last-Modified, Cache-Control. }
function ServeFile(const APath: string): THttpHandlerFunc; overload;

{ Same as above with an explicit Cache-Control policy value (e.g.
  'public, max-age=31536000, immutable' for content-addressed assets).
  The single-argument overload keeps the conservative revalidate default. }
function ServeFile(const APath, ACacheControl: string): THttpHandlerFunc; overload;

{ Serve files from a directory. Path param 'filepath' or URL path used as relative file path.
  Example: router.Get('/static/*filepath', ServeDir('/var/www'))
  Supports range requests (RFC 7233), ETag, Last-Modified, Cache-Control. }
function ServeDir(const ARoot: string): THttpHandlerFunc; overload;

{ Same as above with an explicit Cache-Control policy value applied to every
  served entry (the single-argument overload keeps the revalidate default). }
function ServeDir(const ARoot, ACacheControl: string): THttpHandlerFunc; overload;

{ Serve files from a read-only virtual filesystem (nextpas.core.vfs IVfs).
  Path param 'filepath' or URL path used as relative VFS path.
  Example: router.Get('/assets/*filepath', ServeVfs(AFs))
  Supports range requests (RFC 7233), ETag, Last-Modified, Cache-Control.
  ETag prefers backend ContentHash ("fnv-hex8"); without a hash falls back to
  size+mtime strong ETag. Entries with unknown ModTime (0) skip Last-Modified
  and If-Modified-Since negotiation. Directories and invalid paths return 404
  (no index serving). }
function ServeVfs(const AFs: IVfs): THttpHandlerFunc; overload;
{ Same as above with an explicit Cache-Control policy value applied to every
  served entry (the single-argument overload keeps the revalidate default). }
function ServeVfs(const AFs: IVfs; const ACacheControl: string): THttpHandlerFunc; overload;

{ Serve a single file with Content-Disposition: attachment for download.
  Supports range requests, ETag, Last-Modified, Cache-Control. }
function ServeFileDownload(const APath: string): THttpHandlerFunc; overload;
function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc; overload;

{** @desc Strong ETag from size + mtime: quoted "hexsize-hexmtime". }
function HttpMakeStrongETag(const ASize, AModTime: Int64): string;
{** @desc If-None-Match match: `*`, exact quoted ETag, or comma-separated list. }
function HttpIfNoneMatchMatches(const AIfNoneMatch, AServerETag: string): Boolean;
{** @desc True when If-Modified-Since parses and resource mtime <= that instant. }
function HttpNotModifiedSince(const AIfModifiedSince: string;
  const AModTimeUnix: Int64): Boolean;
{** @desc RFC 7232 conditional GET helper. Writes 304 when not modified; returns True
   if 304 written (caller must not write a body). If-None-Match takes precedence. }
function HttpTryWriteNotModified(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; const AETag, ALastModified: string;
  const AModTimeUnix: Int64): Boolean;

{** @desc Format Unix timestamp as HTTP date (RFC 7231 §7.1.1.1).
   Example: "Sun, 06 Nov 1994 08:49:37 GMT". }
function FormatHttpDate(const AUnixTimestamp: Int64): string;
{** @desc Parse HTTP-date (RFC 7231 §7.1.1.1) to Unix timestamp seconds.
   Accepts IMF-fixdate ("Sun, 06 Nov 1994 08:49:37 GMT"), RFC 850
   ("Sunday, 06-Nov-94 08:49:37 GMT") and ANSIC ("Sun Nov  6 08:49:37 1994")
   — the same set as Go's http.ParseTime. Returns False on parse failure. }
function TryParseHttpDate(const ADate: string; out AUnix: Int64): Boolean;
{** @desc Ensure headers carry a Date header (RFC 7231 §7.1.1.2 SHOULD).
   Injects current UTC time only when the headers do not already have one. }
procedure HttpEnsureDateHeader(const AHeaders: IHttpHeaders);

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
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.http.base,
  nextpas.core.http.url,
  nextpas.core.http.message,
  nextpas.core.http.mime;

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

{ Returns True if the relative path is safe (no traversal).
  Semantics: VFS canonical ValidPath + HTTP double-encoding guard.
  Reuses VfsValidPath as single source of truth, then rejects '%' and '\'
  which Go ValidPath would accept as normal chars but must be blocked after
  UrlDecode to prevent encoded traversal. }
function IsSafePath(const ARelative: string): Boolean;
begin
  if ARelative = '' then
    Exit(False);
  { After UrlDecode, any remaining '%' indicates double-encoding attempt }
  if Pos('%', ARelative) > 0 then
    Exit(False);
  if Pos('\', ARelative) > 0 then
    Exit(False);
  Result := VfsValidPath(ARelative, False);
end;

{ Extract relative path from request: tries wildcard param 'filepath', falls
  back to URL path with leading slash stripped. Returns False only when
  UrlDecode raises (malformed percent-encoding) — caller should reply 400. }
function TryExtractRequestPath(const AReq: IHttpRequest; out ARelative: string): Boolean;
begin
  ARelative := AReq.PathParam('filepath');
  if ARelative = '' then
  begin
    ARelative := AReq.Path;
    if (Length(ARelative) > 0) and (ARelative[1] = '/') then
      ARelative := System.Copy(ARelative, 2, Length(ARelative) - 1);
  end;
  try
    ARelative := nextpas.core.http.url.UrlDecode(ARelative);
    Result := True;
  except
    Result := False;
  end;
end;

function FormatHttpDate(const AUnixTimestamp: Int64): string;
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

procedure HttpEnsureDateHeader(const AHeaders: IHttpHeaders);
begin
  if AHeaders = nil then
    Exit;
  if AHeaders.Has('date') then
    Exit;
  { RFC 7231 §7.1.1.2: origin servers MUST NOT send a Date header that is
    more than 60s from the message origin time. DateTimeUtcNow() derives from
    platform_realtime_ns, so the value tracks wall-clock closely. }
  AHeaders.SetHeader('date',
    FormatHttpDate(DateTimeToUnix(DateTimeUtcNow)));
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
  { Preferred form: "Sun, 06 Nov 1994 08:49:37 GMT" = 29 chars (1-based). }
  if LLen < 29 then Exit;

  { Day name + ", " occupies indices 1..5; day digits start at 6. }
  LPos := 6;
  if LPos + 1 > LLen then Exit;
  if (ADate[LPos] < '0') or (ADate[LPos] > '9') or
    (ADate[LPos + 1] < '0') or (ADate[LPos + 1] > '9') then
    Exit;
  LDay := (Ord(ADate[LPos]) - Ord('0')) * 10 + (Ord(ADate[LPos + 1]) - Ord('0'));
  Inc(LPos, 3); { day + space → month }

  if LPos + 2 > LLen then Exit;
  LMonthStr := System.Copy(ADate, LPos, 3);
  LMonth := 0;
  for LI := 1 to 12 do
    if LMonthStr = MONTH_NAMES[LI] then
    begin
      LMonth := LI;
      Break;
    end;
  if LMonth = 0 then Exit;
  Inc(LPos, 4); { month + space → year }

  if LPos + 3 > LLen then Exit;
  if (ADate[LPos] < '0') or (ADate[LPos] > '9') then Exit;
  LYear := (Ord(ADate[LPos]) - Ord('0')) * 1000
         + (Ord(ADate[LPos + 1]) - Ord('0')) * 100
         + (Ord(ADate[LPos + 2]) - Ord('0')) * 10
         + (Ord(ADate[LPos + 3]) - Ord('0'));
  Inc(LPos, 5); { year + space → time }

  if LPos + 7 > LLen then Exit;
  LHour := (Ord(ADate[LPos]) - Ord('0')) * 10 + (Ord(ADate[LPos + 1]) - Ord('0'));
  LMinute := (Ord(ADate[LPos + 3]) - Ord('0')) * 10 + (Ord(ADate[LPos + 4]) - Ord('0'));
  LSecond := (Ord(ADate[LPos + 6]) - Ord('0')) * 10 + (Ord(ADate[LPos + 7]) - Ord('0'));

  { 范围校验：非法时/分/秒/日/月拒绝（TOffsetDateTime 会容错回绕，
    如 25:49:37 → 次日 01:49:37——严格解析须显式拒绝）。 }
  if (LDay < 1) or (LDay > 31) or (LMonth < 1) or (LMonth > 12) or
     (LHour > 23) or (LMinute > 59) or (LSecond > 60) then
    Exit;

  try
    LDT := TOffsetDateTime.Create(
      TNaiveDateTime.Create(LYear, LMonth, LDay, LHour, LMinute, LSecond),
      TUtcOffset.UTC);
    Result := LDT.ToUnixSeconds;
  except
    Result := 0;
  end;
end;

{ Parse RFC 850 / ANSIC C date as fallback forms of HTTP-date
  (RFC 7231 §7.1.1.1; Go http.ParseTime accepts both).
  RFC850:  "Sunday, 06-Nov-94 08:49:37 GMT"
  ANSIC:   "Sun Nov  6 08:49:37 1994"   (day space-padded to 2 cols)
  Returns 0 on parse failure; two-digit years expand via 69 → 20xx rule
  (POSIX strptime %y, same as Go time.Parse with "06"). }
function ParseHttpDateFallback(const ADate: string): Int64;
var
  LDay, LMonth, LYear, LHour, LMinute, LSecond, LI, LPos: Integer;
  LMonthStr: string;
  LDT: TOffsetDateTime;
begin
  Result := 0;
  if Length(ADate) < 16 then
    Exit;
  { RFC850: weekday + ", " + DD-Mmm-YY at fixed offsets (1-based).
    "Sunday, 06-Nov-94 ..." → ','@7, day@9-10, '-'@11, month@12-14,
    '-'@15, year@16-17, time@19. }
  if (ADate[7] = ',') and (ADate[11] = '-') and (ADate[15] = '-') then
  begin
    LDay := (Ord(ADate[9]) - Ord('0')) * 10 + (Ord(ADate[10]) - Ord('0'));
    LMonthStr := System.Copy(ADate, 12, 3);
    LMonth := 0;
    for LI := 1 to 12 do
      if LMonthStr = MONTH_NAMES[LI] then
      begin
        LMonth := LI;
        Break;
      end;
    if LMonth = 0 then
      Exit;
    LYear := (Ord(ADate[16]) - Ord('0')) * 10 + (Ord(ADate[17]) - Ord('0'));
    if LYear < 69 then
      LYear := 2000 + LYear
    else
      LYear := 1900 + LYear;
    LPos := 19;   { skip "-YY " → "HH:MM:SS" }
  end
  else if ADate[4] = ' ' then
  begin
    { ANSIC: "Sun Nov  6 08:49:37 1994" — weekday space month, then
      day either " 6" (space-padded) or "16". }
    LMonthStr := System.Copy(ADate, 5, 3);
    LMonth := 0;
    for LI := 1 to 12 do
      if LMonthStr = MONTH_NAMES[LI] then
      begin
        LMonth := LI;
        Break;
      end;
    if LMonth = 0 then
      Exit;
    LPos := 9;
    if (ADate[LPos] = ' ') then
    begin
      LDay := Ord(ADate[LPos + 1]) - Ord('0');
      Inc(LPos, 3);
    end
    else if (ADate[LPos] in ['0'..'9']) and (ADate[LPos + 1] in ['0'..'9']) then
    begin
      LDay := (Ord(ADate[LPos]) - Ord('0')) * 10 + (Ord(ADate[LPos + 1]) - Ord('0'));
      Inc(LPos, 3);
    end
    else
      Exit;
  end
  else
    Exit;
  { LPos points at "HH:MM:SS " for both fallback forms. }
  if (LPos + 9 > Length(ADate)) then
    Exit;
  if (ADate[LPos + 2] <> ':') or (ADate[LPos + 5] <> ':') then
    Exit;
  LHour := (Ord(ADate[LPos]) - Ord('0')) * 10 + (Ord(ADate[LPos + 1]) - Ord('0'));
  LMinute := (Ord(ADate[LPos + 3]) - Ord('0')) * 10 + (Ord(ADate[LPos + 4]) - Ord('0'));
  LSecond := (Ord(ADate[LPos + 6]) - Ord('0')) * 10 + (Ord(ADate[LPos + 7]) - Ord('0'));
  { ANSIC year is trailing: "HH:MM:SS YYYY"; RFC850 is "HH:MM:SS GMT". }
  if (ADate[LPos + 8] = ' ') and (LPos + 12 <= Length(ADate)) and
     (ADate[LPos + 9] in ['0'..'9']) then
  begin
    if ADate[4] = ' ' then
    begin
      LYear := (Ord(ADate[LPos + 9]) - Ord('0')) * 1000
             + (Ord(ADate[LPos + 10]) - Ord('0')) * 100
             + (Ord(ADate[LPos + 11]) - Ord('0')) * 10
             + (Ord(ADate[LPos + 12]) - Ord('0'));
    end;
  end;
  if (LDay < 1) or (LDay > 31) or (LMonth < 1) or (LMonth > 12) or
     (LHour > 23) or (LMinute > 59) or (LSecond > 60) then
    Exit;
  try
    LDT := TOffsetDateTime.Create(
      TNaiveDateTime.Create(LYear, LMonth, LDay, LHour, LMinute, LSecond),
      TUtcOffset.UTC);
    Result := LDT.ToUnixSeconds;
  except
    Result := 0;
  end;
end;

{** @desc Parse HTTP-date (RFC 7231 §7.1.1.1) to Unix timestamp seconds.
   Accepts IMF-fixdate ("Sun, 06 Nov 1994 08:49:37 GMT"), RFC 850
   ("Sunday, 06-Nov-94 08:49:37 GMT") and ANSIC ("Sun Nov  6 08:49:37 1994")
   — the same set as Go's http.ParseTime. Returns False on parse failure. }
function TryParseHttpDate(const ADate: string; out AUnix: Int64): Boolean;
var
  LV: Int64;
begin
  LV := ParseHttpDate(ADate);
  if LV = 0 then
    LV := ParseHttpDateFallback(ADate);
  if LV = 0 then
    Exit(False);
  AUnix := LV;
  Result := True;
end;
function HttpMakeStrongETag(const ASize, AModTime: Int64): string;
begin
  Result := '"' + IntToHex(ASize, 16) + '-' + IntToHex(AModTime, 16) + '"';
end;

{ TFileInfo.ModTime is platform nanoseconds since Unix epoch. }
function FileModTimeToUnixSeconds(const AModTimeNs: Int64): Int64; inline;
begin
  if AModTimeNs < 0 then
    Exit(0);
  Result := AModTimeNs div 1000000000;
end;

{ Generate ETag from file size and modification time.
  Format: "size-mtime" hex pair for strong ETag. }
function GenerateETag(ASize: Int64; AModTime: Int64): string;
begin
  Result := HttpMakeStrongETag(ASize, AModTime);
end;

function HttpIfNoneMatchMatches(const AIfNoneMatch, AServerETag: string): Boolean;
var
  LRest, LToken: string;
  LComma: SizeInt;
begin
  Result := False;
  if (AIfNoneMatch = '') or (AServerETag = '') then
    Exit;
  LRest := Trim(AIfNoneMatch);
  if LRest = '*' then
    Exit(True);
  while LRest <> '' do
  begin
    LComma := Pos(',', LRest);
    if LComma > 0 then
    begin
      LToken := Trim(System.Copy(LRest, 1, LComma - 1));
      LRest := Trim(System.Copy(LRest, LComma + 1, Length(LRest) - LComma));
    end
    else
    begin
      LToken := Trim(LRest);
      LRest := '';
    end;
    if LToken = AServerETag then
      Exit(True);
  end;
end;

function HttpNotModifiedSince(const AIfModifiedSince: string;
  const AModTimeUnix: Int64): Boolean;
var
  LSince: Int64;
begin
  Result := False;
  if AIfModifiedSince = '' then
    Exit;
  if not TryParseHttpDate(AIfModifiedSince, LSince) then
    Exit;
  Result := AModTimeUnix <= LSince;
end;

function HttpTryWriteNotModified(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; const AETag, ALastModified: string;
  const AModTimeUnix: Int64): Boolean;
var
  LIfNoneMatch: string;
  LIfModifiedSince: string;
begin
  Result := False;
  if (AReq = nil) or (AW = nil) then
    Exit;

  LIfNoneMatch := AReq.GetHeaders.Get('if-none-match');
  if LIfNoneMatch <> '' then
  begin
    if HttpIfNoneMatchMatches(LIfNoneMatch, AETag) then
    begin
      AW.GetHeaders.SetHeader('etag', AETag);
      if ALastModified <> '' then
        AW.GetHeaders.SetHeader('last-modified', ALastModified);
      AW.GetHeaders.SetHeader('content-length', '0');
      AW.WriteHeader(HTTP_STATUS_NOT_MODIFIED);
      Exit(True);
    end;
    { RFC 7232: when If-None-Match is present, ignore If-Modified-Since. }
    Exit(False);
  end;

  LIfModifiedSince := AReq.GetHeaders.Get('if-modified-since');
  if HttpNotModifiedSince(LIfModifiedSince, AModTimeUnix) then
  begin
    if AETag <> '' then
      AW.GetHeaders.SetHeader('etag', AETag);
    if ALastModified <> '' then
      AW.GetHeaders.SetHeader('last-modified', ALastModified);
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_NOT_MODIFIED);
    Exit(True);
  end;
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

{ Copy ACount bytes from AInput starting at AStart to writer.
  Accepts any IStream (fs IFile and IVfs.OpenRead streams both qualify). }
procedure CopyRange(const AInput: IStream; const AWriter: IWriter;
  AStart, ACount: Int64);
var
  LBuf: array[0..8191] of Byte;
  LRemaining: Int64;
  LToRead: SizeUInt;
  LN: SizeUInt;
begin
  { Seek to start position }
  AInput.Seek(AStart, soBeginning);
  LRemaining := ACount;
  while LRemaining > 0 do
  begin
    if LRemaining > SizeOf(LBuf) then
      LToRead := SizeOf(LBuf)
    else
      LToRead := SizeUInt(LRemaining);
    LN := AInput.Read(LBuf[0], LToRead);
    if LN = 0 then
      Break;
    AWriter.Write(LBuf[0], LN);
    Dec(LRemaining, LN);
  end;
end;

{ Unified static content serving: handles conditional GET (304), common headers,
  and single-range (206/416) vs full (200) streaming. AFactory is invoked
  lazily after Range parsing so we never open the underlying stream for 304/416. }
type
  TStaticStreamFactory = reference to function: IStream;

procedure HttpServeStaticStream(
  const AReq: IHttpRequest; const AW: IHttpResponseWriter;
  const ASize: Int64; const AETag, ALastModified, AMime, ACacheControl: string;
  const AModTimeUnix: Int64; const AFactory: TStaticStreamFactory;
  const ADownloadName: string = '');
var
  LRangeHeader: string;
  LStart, LEnd: Int64;
  LStream: IStream;
  LWriter: IWriter;
  LEscapedName: string;
  LIfNoneMatch: string;
begin
  if AReq <> nil then
    LIfNoneMatch := AReq.GetHeaders.Get('if-none-match')
  else
    LIfNoneMatch := '';
  if (AModTimeUnix > 0) or (LIfNoneMatch <> '') then
    if HttpTryWriteNotModified(AReq, AW, AETag, ALastModified, AModTimeUnix) then
      Exit;
  AW.GetHeaders.SetHeader('content-type', AMime);
  AW.GetHeaders.SetHeader('etag', AETag);
  if ALastModified <> '' then
    AW.GetHeaders.SetHeader('last-modified', ALastModified);
  AW.GetHeaders.SetHeader('cache-control', ACacheControl);
  AW.GetHeaders.SetHeader('accept-ranges', 'bytes');
  AW.GetHeaders.SetHeader('x-content-type-options', 'nosniff');
  if ADownloadName <> '' then
  begin
    LEscapedName := ADownloadName;
    LEscapedName := nextpas.core.text.conv.StringReplace(LEscapedName, '\', '\\', True);
    LEscapedName := nextpas.core.text.conv.StringReplace(LEscapedName, '"', '\"', True);
    AW.GetHeaders.SetHeader('content-disposition',
      'attachment; filename="' + LEscapedName + '"');
  end;
  if AReq <> nil then
    LRangeHeader := AReq.GetHeaders.Get('range')
  else
    LRangeHeader := '';
  if LRangeHeader <> '' then
  begin
    if not ParseRangeHeader(LRangeHeader, ASize, LStart, LEnd) then
    begin
      SendRangeNotSatisfiable(ASize, AW);
      Exit;
    end;
    LStream := AFactory();
    AW.GetHeaders.SetHeader('content-range',
      'bytes ' + IntToStr(LStart) + '-' + IntToStr(LEnd) + '/' + IntToStr(ASize));
    AW.GetHeaders.SetHeader('content-length', IntToStr(LEnd - LStart + 1));
    AW.WriteHeader(HTTP_STATUS_PARTIAL_CONTENT);
    LWriter := TResponseWriterAdapter.Create(AW);
    CopyRange(LStream, LWriter, LStart, LEnd - LStart + 1);
  end
  else
  begin
    LStream := AFactory();
    AW.GetHeaders.SetHeader('content-length', IntToStr(ASize));
    AW.WriteHeader(HTTP_STATUS_OK);
    LWriter := TResponseWriterAdapter.Create(AW);
    nextpas.core.io.Copy(LWriter, LStream);
  end;
end;

{ Serve file content with optional range support, ETag, Last-Modified, Cache-Control.
  ADownloadName: if non-empty, set Content-Disposition: attachment with given filename.
  ACacheControl: verbatim Cache-Control policy header value. }
procedure ServeFileContentEx(const AFilePath: string;
  const AReq: IHttpRequest; const AW: IHttpResponseWriter;
  const ADownloadName, ACacheControl: string);
var
  LInfo: TFileInfo;
  LMime, LETag, LLastModified: string;
  LFileSize: Int64;
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
    LMime := HttpMimeFromPath(AFilePath);
    LETag := GenerateETag(LFileSize, LInfo.ModTime);
    LLastModified := FormatHttpDate(FileModTimeToUnixSeconds(LInfo.ModTime));
    HttpServeStaticStream(AReq, AW, LFileSize, LETag, LLastModified, LMime, ACacheControl,
      FileModTimeToUnixSeconds(LInfo.ModTime),
      function: IStream
      begin
        Result := nextpas.core.fs.Open(AFilePath, [fmRead]);
      end, ADownloadName);
  except
    HttpWriteErrorInternal(AW, 'Internal Server Error');
  end;
end;

{ ===== Public API ===== }

function ServeFile(const APath: string): THttpHandlerFunc;
begin
  Result := ServeFile(APath, 'public, max-age=0, must-revalidate');
end;

function ServeFile(const APath, ACacheControl: string): THttpHandlerFunc;
begin
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    ServeFileContentEx(APath, AReq, AW, '', ACacheControl);
  end;
end;

function ServeDir(const ARoot: string): THttpHandlerFunc;
begin
  Result := ServeDir(ARoot, 'public, max-age=0, must-revalidate');
end;

function ServeDir(const ARoot, ACacheControl: string): THttpHandlerFunc;
begin
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LRelative: string;
    LFullPath: string;
    LNormalizedRoot: string;
    LNormalizedFull: string;
  begin
    if not TryExtractRequestPath(AReq, LRelative) then
    begin
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
    { Ensure root ends with path separator for exact prefix match }
    if (LNormalizedRoot <> '') and (LNormalizedRoot[Length(LNormalizedRoot)] <> '/') then
      LNormalizedRoot := LNormalizedRoot + '/';
    if not (Length(LNormalizedFull) >= Length(LNormalizedRoot)) or
       (System.Copy(LNormalizedFull, 1, Length(LNormalizedRoot)) <> LNormalizedRoot) then
    begin
      AW.GetHeaders.SetHeader('content-length', '9');
      AW.WriteHeader(HTTP_STATUS_FORBIDDEN);
      AW.Write(PAnsiChar('Forbidden')^, 9);
      Exit;
    end;
    ServeFileContentEx(LFullPath, AReq, AW, '', ACacheControl);
  end;
end;

{ Serve one VFS entry with the same response semantics as ServeFileContentEx.
  Exists/IsDir gate up front; an EVfsNotFound escaping the late gates maps to
  404, any other failure maps to 500. ContentHash-backed ETag keeps identity
  stable for embedded trees whose entries carry no wall-clock mtime. }
procedure ServeVfsContentEx(const AFs: IVfs; const AVfsPath: string;
  const AReq: IHttpRequest; const AW: IHttpResponseWriter;
  const ACacheControl: string);
var
  LInfo: TStatInfo;
  LMime, LETag, LLastModified: string;
  LModTimeUnix: Int64;
begin
  try
    try
      LInfo := AFs.Stat(AVfsPath);
    except
      on EVfsNotFound do
      begin
        HttpWriteErrorNotFound(AW, 'File not found');
        Exit;
      end;
      on EVfsInvalidPath do
      begin
        HttpWriteErrorNotFound(AW, 'File not found');
        Exit;
      end;
    end;
    if LInfo.Info.IsDir then
    begin
      HttpWriteErrorNotFound(AW, 'File not found');
      Exit;
    end;
    LModTimeUnix := LInfo.Info.ModTime;
    if LModTimeUnix < 0 then
      LModTimeUnix := 0;
    if LInfo.ContentHash <> 0 then
      LETag := '"fnv-' + IntToHex(LInfo.ContentHash, 8) + '"'
    else
      LETag := GenerateETag(LInfo.Info.Size, LModTimeUnix);
    if LModTimeUnix > 0 then
      LLastModified := FormatHttpDate(LModTimeUnix)
    else
      LLastModified := '';
    LMime := HttpMimeFromPath(AVfsPath);
    HttpServeStaticStream(AReq, AW, LInfo.Info.Size, LETag, LLastModified, LMime, ACacheControl, LModTimeUnix,
      function: IStream
      begin
        Result := AFs.OpenRead(AVfsPath);
      end);
  except
    on EVfsNotFound do
      HttpWriteErrorNotFound(AW, 'File not found');
    else
      HttpWriteErrorInternal(AW, 'Internal Server Error');
  end;
end;

function ServeVfs(const AFs: IVfs): THttpHandlerFunc;
begin
  Result := ServeVfs(AFs, 'public, max-age=0, must-revalidate');
end;

function ServeVfs(const AFs: IVfs; const ACacheControl: string): THttpHandlerFunc;
begin
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LRelative: string;
  begin
    if not TryExtractRequestPath(AReq, LRelative) then
    begin
      AW.GetHeaders.SetHeader('content-length', '11');
      AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      AW.Write(PAnsiChar('Bad Request')^, 11);
      Exit;
    end;
    { The VFS namespace is canonical: empty/rooted/traversal forms are plain
      misses (404), indistinguishable from nonexistent entries. }
    if (LRelative = '') or not VfsValidPath(LRelative, False) then
    begin
      HttpWriteErrorNotFound(AW, 'File not found');
      Exit;
    end;
    ServeVfsContentEx(AFs, LRelative, AReq, AW, ACacheControl);
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
    ServeFileContentEx(APath, AReq, AW, LFileName,
      'public, max-age=0, must-revalidate');
  end;
end;

function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc;
begin
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    ServeFileContentEx(APath, AReq, AW, ADownloadName,
      'public, max-age=0, must-revalidate');
  end;
end;

end.
