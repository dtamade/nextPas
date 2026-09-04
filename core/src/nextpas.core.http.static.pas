unit nextpas.core.http.static;
{**
 * @desc Static + Range serving (ServeFile/ServeDir/ServeVfs). Perf: inline zero-alloc probes
 *       `HttpRangeHasBytesPrefix`/`HttpWeakETagEquals` via `bytes.ops:CompareMem` single source,
 *       `CopyRange(32K, STATIC_COPY_BUF_SIZE)` 32K aligned `io.base:IO_COPY_BUF_SIZE` single
 *       source + `io.Copy` via `IFile:IWriterTo` fast path (L0 `platform.sendfile` file→file
 *       真零拷贝已落地，Linux `sendfile`；file→socket 内核零拷贝已兑现 via `ISendfileSocketHandle`
 *       fd 缝 (`IFileHandle`+`ISendfileSocketHandle`, `PLATFORM_SENDFILE_CHUNK` 32K 单源)，回退 honest 32K
 *       用户态缓冲)，VFS embedded `TEmbeddedSlice`/`ByteSpan` 零拷贝 retained；
 *       stability `try/finally`/`Close`/`FreeAndNil` 不丢，source-contract 锁 `IFile`+`io.Copy` 禁 `ReadAll`，
 *       per-domain `heaptrc 0`；bench_static `≥0.80× Go` 已冻结。CONTRACT truth，缺能力先反哺 owner
 *       (`bytes.ops`/`io`/`fs`/`platform.sendfile` L0 已落地)。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf,
  nextpas.core.vfs.intf,
  nextpas.core.platform.socket.base,
  nextpas.core.platform.sendfile.base;

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
function HttpMakeStrongETag(const ASize, AModTime: Int64): string; inline;
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

{** @desc 零分配判定 Range 头是否以 "bytes=" 开头（避免 System.Copy 临时串）。 }
function HttpRangeHasBytesPrefix(const ARange: string): Boolean; inline;

{** @desc 弱 ETag 比较（RFC7232 §3.3）：剥离可选 W/ 前缀后字节级精确匹配，零分配。 }
function HttpWeakETagEquals(const A, B: string): Boolean; inline;

implementation

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.fs.base,
  nextpas.core.fs.path,
  nextpas.core.text.conv,
  nextpas.core.text.view,
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
  nextpas.core.http.mime,
  nextpas.core.time.httpdate,
  nextpas.core.platform.sendfile,
  nextpas.core.platform.files.base;

type
  TResponseWriterAdapter = class(TInterfacedObject, IWriter, nextpas.core.platform.sendfile.base.ISendfileSocketHandle)
  private
    FWriter: IHttpResponseWriter;
  public
    constructor Create(const AWriter: IHttpResponseWriter);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function GetSocketHandle: TPlatformSocket;
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

function TResponseWriterAdapter.GetSocketHandle: TPlatformSocket;
var
  LSock: nextpas.core.platform.sendfile.base.ISendfileSocketHandle;
begin
  Result := PLATFORM_INVALID_SOCKET;
  if FWriter = nil then
    Exit;
  if Supports(FWriter, nextpas.core.platform.sendfile.base.ISendfileSocketHandle, LSock) then
    Result := LSock.GetSocketHandle;
end;

const
  CACHE_REVALIDATE = 'public, max-age=0, must-revalidate';
  STATIC_COPY_BUF_SIZE = 32768; { 32K=8*4K 对齐 `io.base:IO_COPY_BUF_SIZE` 单源 (`platform.sendfile.base:PLATFORM_SENDFILE_CHUNK` 同源，`Move` 单源 `bytes.ops`)；VFS 嵌入 `TEmbeddedSlice`/`Move` 零拷贝已兑现，`IFile:IWriterTo`→`io.Copy` 快路径（L0 `platform.sendfile` file→file/file→socket 真零拷贝已兑现 via `ISendfileSocketHandle` fd 缝，`PLATFORM_SENDFILE_CHUNK` 32K 单源，`Move` 单源 `bytes.ops`，回退 honest 32K 缓冲）；`io.Copy`/`CopyRange` 流式禁 `ReadAll`，`heaptrc 0` }

{ ===== Helpers ===== }

function EscapeDispositionFilename(const S: string): string; inline;
var
  I, Extra, J: Integer;
begin
  Extra := 0;
  for I := 1 to Length(S) do
    if (S[I] = '\') or (S[I] = '"') then
      Inc(Extra);
  if Extra = 0 then
    Exit(S);
  SetLength(Result, Length(S) + Extra);
  J := 1;
  for I := 1 to Length(S) do
  begin
    if S[I] = '\' then
    begin
      Result[J] := '\';
      Result[J + 1] := '\';
      Inc(J, 2);
    end
    else if S[I] = '"' then
    begin
      Result[J] := '\';
      Result[J + 1] := '"';
      Inc(J, 2);
    end
    else
    begin
      Result[J] := S[I];
      Inc(J);
    end;
  end;
end;

function IsHeadReq(const AReq: IHttpRequest): Boolean; inline;
begin
  Result := (AReq <> nil) and (AReq.Method = hmHead);
end;

procedure WriteErrorHeadAware(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; const AStatus: THttpStatus;
  const ACode, AMsg: string);
begin
  if IsHeadReq(AReq) then
  begin
    { HEAD MUST NOT include body — same status/headers, content-length 0. }
    AW.GetHeaders.SetHeader('content-type', 'application/problem+json');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(AStatus);
  end
  else
    HttpWriteErrorResponse(AW, AStatus, ACode, AMsg);
end;

{ Returns True if the relative path is safe (no traversal).
  Semantics: VFS canonical ValidPath + HTTP double-encoding guard.
  Reuses VfsValidPath as single source of truth, then rejects '%' and '\'
  which Go ValidPath would accept as normal chars but must be blocked after
  UrlDecode to prevent encoded traversal. Single-pass scan replaces double Pos. }
function IsSafePath(const ARelative: string): Boolean; inline;
var
  I: Integer;
begin
  if ARelative = '' then
    Exit(False);
  { Single-pass: any '%' (double-encoding) or '\' (Windows sep) is unsafe }
  for I := 1 to Length(ARelative) do
    if (ARelative[I] = '%') or (ARelative[I] = '\') then
      Exit(False);
  Result := VfsValidPath(ARelative, False);
end;

{ Extract relative path from request: tries wildcard param 'filepath', falls
  back to URL path with leading slash stripped. Returns False only when
  UrlDecode raises (malformed percent-encoding) — caller should reply 400. }
function TryExtractRequestPath(const AReq: IHttpRequest; out ARelative: string): Boolean; inline;
begin
  ARelative := AReq.PathParam('filepath');
  if ARelative = '' then
  begin
    ARelative := AReq.Path;
    if (Length(ARelative) > 0) and (ARelative[1] = '/') then
      System.Delete(ARelative, 1, 1);
  end;
  try
    ARelative := nextpas.core.http.url.UrlDecode(ARelative);
    Result := True;
  except
    Result := False;
  end;
end;

function FormatHttpDate(const AUnixTimestamp: Int64): string;
begin
  Result := nextpas.core.time.httpdate.FormatHttpDate(AUnixTimestamp);
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

function TryParseHttpDate(const ADate: string; out AUnix: Int64): Boolean;
begin
  Result := nextpas.core.time.httpdate.TryParseHttpDate(ADate, AUnix);
end;
function HttpMakeStrongETag(const ASize, AModTime: Int64): string; inline;
begin
  Result := VfsETagStrong(ASize, AModTime);
end;

function HttpMakeFnvETag(const AHash: UInt32): string; inline;
begin
  Result := VfsETagFNV(AHash);
end;

{ TFileInfo.ModTime is platform nanoseconds since Unix epoch. }
function FileModTimeToUnixSeconds(const AModTimeNs: Int64): Int64; inline;
begin
  if AModTimeNs < 0 then
    Exit(0);
  Result := AModTimeNs div 1000000000;
end;

function StripWeakETagView(const S: string): TStringView; inline;
begin
  // perf: inline zero-copy view via TStringView.FromStr+Slice single source (bytes.ops TryClampSlice → TByteSpan, no Move) avoids System.Copy heap alloc; caller compares via SpanEqual/CompareMem single source
  if (Length(S) >= 2) and (S[1] = 'W') and (S[2] = '/') then
    Result := TStringView.FromStr(S).Slice(2, SizeUInt(Length(S) - 2))
  else
    Result := TStringView.FromStr(S);
end;

function StripWeakETag(const S: string): string; inline;
begin
  // perf: inline thin-forward via StripWeakETagView (TStringView single source, bytes.ops TryClampSlice zero-copy extent, no System.Copy); ToString single alloc only when W/ present, hot path HttpWeakETagEquals already zero-alloc via offsets+CompareMem
  Result := StripWeakETagView(S).ToString;
end;

function HttpIfNoneMatchMatches(const AIfNoneMatch, AServerETag: string): Boolean;
var
  S: string;
  Server: string;
  SStart, SLen: SizeInt;
  ServerStart, ServerLen: SizeInt;
  RestStart, RestLen: SizeInt;
  CommaPos: SizeInt;
  TokenStart, TokenLen: SizeInt;
  TStart, TLen: SizeInt;
  VStart, VLen: SizeInt;
  I: SizeInt;
begin
  Result := False;
  if (AIfNoneMatch = '') or (AServerETag = '') then
    Exit;
  S := AIfNoneMatch;
  SStart := 1; SLen := Length(S);
  while (SLen > 0) and (S[SStart] <= ' ') do begin Inc(SStart); Dec(SLen); end;
  while (SLen > 0) and (S[SStart + SLen - 1] <= ' ') do Dec(SLen);
  if SLen = 0 then Exit;
  if (SLen = 1) and (S[SStart] = '*') then Exit(True);
  RestStart := SStart; RestLen := SLen;
  Server := AServerETag;
  ServerStart := 1; ServerLen := Length(Server);
  while (ServerLen > 0) and (Server[ServerStart] <= ' ') do begin Inc(ServerStart); Dec(ServerLen); end;
  while (ServerLen > 0) and (Server[ServerStart + ServerLen - 1] <= ' ') do Dec(ServerLen);
  while RestLen > 0 do
  begin
    CommaPos := 0;
    for I := 1 to RestLen do
      if S[RestStart + I - 1] = ',' then begin CommaPos := I; Break; end;
    if CommaPos > 0 then
      TokenLen := CommaPos - 1
    else
      TokenLen := RestLen;
    TokenStart := RestStart;
    while (TokenLen > 0) and (S[TokenStart] <= ' ') do begin Inc(TokenStart); Dec(TokenLen); end;
    while (TokenLen > 0) and (S[TokenStart + TokenLen - 1] <= ' ') do Dec(TokenLen);
    if TokenLen > 0 then
    begin
      TStart := TokenStart; TLen := TokenLen;
      VStart := ServerStart; VLen := ServerLen;
      if (TLen >= 2) and (S[TStart] = 'W') and (S[TStart + 1] = '/') then begin Inc(TStart, 2); Dec(TLen, 2); end;
      if (VLen >= 2) and (Server[VStart] = 'W') and (Server[VStart + 1] = '/') then begin Inc(VStart, 2); Dec(VLen, 2); end;
      if TLen = VLen then
      begin
        if TLen = 0 then Exit(True);
        if CompareMem(@S[TStart], @Server[VStart], SizeUInt(TLen)) then Exit(True);
      end;
    end;
    if CommaPos = 0 then Break;
    RestStart := RestStart + CommaPos;
    RestLen := RestLen - CommaPos;
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

function HttpRangeHasBytesPrefix(const ARange: string): Boolean;
const
  BYTES_PREFIX = 'bytes=';
  BYTES_PREFIX_LEN = 6;
begin
  if Length(ARange) < BYTES_PREFIX_LEN then Exit(False);
  Result := CompareMem(@ARange[1], @BYTES_PREFIX[1], BYTES_PREFIX_LEN);
end;

function HttpWeakETagEquals(const A, B: string): Boolean;
var
  AO, BO: SizeInt;
  AL, BL: SizeInt;
begin
  AO := 1; AL := Length(A);
  if (AL >= 2) and (A[1] = 'W') and (A[2] = '/') then begin Inc(AO,2); Dec(AL,2); end;
  BO := 1; BL := Length(B);
  if (BL >= 2) and (B[1] = 'W') and (B[2] = '/') then begin Inc(BO,2); Dec(BL,2); end;
  if AL <> BL then Exit(False);
  if AL = 0 then Exit(True);
  Result := CompareMem(@A[AO], @B[BO], SizeUInt(AL));
end;

{ Parse Range header value. Returns True if valid single range.
  Format: "bytes=start-end" or "bytes=start-" or "bytes=-suffix" }
function ParseRangeHeader(const ARange: string; AFileSize: Int64;
  out AStart, AEnd: Int64): Boolean;
const
  BYTES_PREFIX = 'bytes=';
  BYTES_PREFIX_LEN = 6;

  function TryParseSlice(const S: string; APos, ALen: Integer; out V: Int64): Boolean; inline;
  var
    I, E: Integer;
    C: Char;
    Neg: Boolean;
    U: UInt64;
  begin
    Result := False; V := 0;
    if ALen <= 0 then Exit;
    I := APos; E := APos + ALen;
    Neg := False;
    if S[I] = '-' then begin Neg := True; Inc(I); if I >= E then Exit; end
    else if S[I] = '+' then begin Inc(I); if I >= E then Exit; end;
    U := 0;
    while I < E do
    begin
      C := S[I];
      if (C < '0') or (C > '9') then Exit;
      if U > High(UInt64) div 10 then Exit;
      U := U * 10 + UInt64(Ord(C) - 48);
      Inc(I);
    end;
    if Neg then
    begin
      if U > UInt64(High(Int64)) + 1 then Exit;
      V := -Int64(U);
    end else
    begin
      if U > UInt64(High(Int64)) then Exit;
      V := Int64(U);
    end;
    Result := True;
  end;

var
  LDashPos: SizeInt;
  LStart, LEnd: Int64;
  LStartLen, LEndLen: Integer;
begin
  Result := False;
  AStart := 0;
  AEnd := 0;
  if Length(ARange) < BYTES_PREFIX_LEN + 1 then
    Exit;
  if not HttpRangeHasBytesPrefix(ARange) then
    Exit;

  LDashPos := Pos('-', ARange);
  if LDashPos = 0 then
    Exit;

  LStartLen := LDashPos - BYTES_PREFIX_LEN - 1;
  LEndLen := Length(ARange) - LDashPos;

  if LStartLen = 0 then
  begin
    { Suffix range: "bytes=-500" means last 500 bytes }
    if not TryParseSlice(ARange, LDashPos + 1, LEndLen, LEnd) then
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
    if not TryParseSlice(ARange, BYTES_PREFIX_LEN + 1, LStartLen, LStart) then
      Exit;
    if LStart < 0 then
      Exit;
    if LStart >= AFileSize then
      Exit;
    AStart := LStart;
    if LEndLen = 0 then
    begin
      { Open-ended: "bytes=500-" means from 500 to end }
      AEnd := AFileSize - 1;
    end
    else
    begin
      if not TryParseSlice(ARange, LDashPos + 1, LEndLen, LEnd) then
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
  Accepts any IStream (fs IFile and IVfs.OpenRead streams both qualify).
  Perf: 32K buffer aligned `io.base:IO_COPY_BUF_SIZE` single source (L0
  `platform.sendfile.base:PLATFORM_SENDFILE_CHUNK` 同源，`Move` 单源 `bytes.ops`，
  `IFile:IWriterTo`→`io.Copy` 快路径 + file→socket/file→file 真零拷贝已兑现 via
  `ISendfileSocketHandle` fd 缝，`PLATFORM_SENDFILE_CHUNK` 32K 单源 chunk，回退 honest 32K 缓冲)；
  loop body not inline per `bytes.ops` 红线 2 (I-Cache)。 }
procedure CopyRange(const AInput: IStream; const AWriter: IWriter;
  AStart, ACount: Int64);
var
  LBuf: array[0..STATIC_COPY_BUF_SIZE - 1] of Byte;
  LRemaining: Int64;
  LToRead: SizeUInt;
  LN: SizeUInt;
  LFileHandle: ISendfileFileHandle;
  LSocketHandle: ISendfileSocketHandle;
  LFile: TPlatformFileHandle;
  LSocket: TPlatformSocket;
  LSent, LChunk: Int64;
  LOffset: Int64;
begin
  if (AInput = nil) or (AWriter = nil) then
    Exit;
  if ACount <= 0 then
    Exit;
  if Supports(AInput, ISendfileFileHandle, LFileHandle) and
     Supports(AWriter, ISendfileSocketHandle, LSocketHandle) then
  begin
    LFile := LFileHandle.GetFileHandle;
    LSocket := LSocketHandle.GetSocketHandle;
    if not LFile.IsInvalid and not LSocket.IsInvalid then
    begin
      LOffset := AStart;
      LRemaining := ACount;
      LSent := 0;
      while LRemaining > 0 do
      begin
        if LRemaining > PLATFORM_SENDFILE_CHUNK then
          LChunk := PLATFORM_SENDFILE_CHUNK
        else
          LChunk := LRemaining;
        LSent := platform_sendfile_socket(LSocket, LFile, @LOffset, LChunk);
        if LSent = PLATFORM_SENDFILE_UNSUPPORTED then
          Break;
        if LSent <= 0 then
          Break;
        Dec(LRemaining, LSent);
      end;
      if LRemaining = 0 then
        Exit;
      { fallback to buffered copy on unsupported/partial }
    end;
  end;
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
  LIsHead: Boolean;
  LIfRangeHeader: string;
  LIfRangeDate: Int64;
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
    LEscapedName := EscapeDispositionFilename(ADownloadName);
    AW.GetHeaders.SetHeader('content-disposition',
      'attachment; filename="' + LEscapedName + '"');
  end;
  LIsHead := IsHeadReq(AReq);
  if AReq <> nil then
    LRangeHeader := AReq.GetHeaders.Get('range')
  else
    LRangeHeader := '';
  { RFC 7233 §3.2 If-Range: when present, Range is honored only if the
    validator matches the current representation; otherwise fall back to
    full 200. ETag form is strong exact match (quoted), date form uses
    TryParseHttpDate over the three HTTP-date grammars. }
  if (LRangeHeader <> '') and (AReq <> nil) then
  begin
    LIfRangeHeader := Trim(AReq.GetHeaders.Get('if-range'));
    if LIfRangeHeader <> '' then
    begin
      if TryParseHttpDate(LIfRangeHeader, LIfRangeDate) then
      begin
        { Date validator: stale when resource mtime is unknown or newer. }
        if (AModTimeUnix = 0) or (AModTimeUnix > LIfRangeDate) then
          LRangeHeader := '';
      end
      else
      begin
        { ETag validator: strong comparison. Weak "W/" never matches. }
        if LIfRangeHeader <> AETag then
          LRangeHeader := '';
      end;
    end;
  end;
  if LRangeHeader <> '' then
  begin
    if not ParseRangeHeader(LRangeHeader, ASize, LStart, LEnd) then
    begin
      if IsHeadReq(AReq) then
      begin
        AW.GetHeaders.SetHeader('content-range', 'bytes */' + IntToStr(ASize));
        AW.GetHeaders.SetHeader('content-length', '0');
        AW.GetHeaders.SetHeader('content-type', 'application/problem+json');
        AW.WriteHeader(HTTP_STATUS_RANGE_NOT_SATISFIABLE);
        Exit;
      end;
      SendRangeNotSatisfiable(ASize, AW);
      Exit;
    end;
    AW.GetHeaders.SetHeader('content-range',
      'bytes ' + IntToStr(LStart) + '-' + IntToStr(LEnd) + '/' + IntToStr(ASize));
    AW.GetHeaders.SetHeader('content-length', IntToStr(LEnd - LStart + 1));
    AW.WriteHeader(HTTP_STATUS_PARTIAL_CONTENT);
    if LIsHead then
      Exit;
    try AW.Flush; except end;
    LStream := AFactory();
    try
      LWriter := TResponseWriterAdapter.Create(AW);
      CopyRange(LStream, LWriter, LStart, LEnd - LStart + 1);
    finally
      if LStream <> nil then
        try LStream.Close; except end;
    end;
  end
  else
  begin
    AW.GetHeaders.SetHeader('content-length', IntToStr(ASize));
    AW.WriteHeader(HTTP_STATUS_OK);
    if LIsHead then
      Exit;
    try AW.Flush; except end;
    LStream := AFactory();
    try
      LWriter := TResponseWriterAdapter.Create(AW);
      nextpas.core.io.Copy(LWriter, LStream);
    finally
      if LStream <> nil then
        try LStream.Close; except end;
    end;
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
      WriteErrorHeadAware(AReq, AW, HTTP_STATUS_NOT_FOUND, 'not_found', 'File not found');
      Exit;
    end;
    LInfo := nextpas.core.fs.Stat(AFilePath);
    if LInfo.FileType <> nextpas.core.fs.base.ftRegular then
    begin
      WriteErrorHeadAware(AReq, AW, HTTP_STATUS_NOT_FOUND, 'not_found', 'File not found');
      Exit;
    end;
    LFileSize := LInfo.Size;
    LMime := HttpMimeFromPath(AFilePath);
    LETag := HttpMakeStrongETag(LFileSize, LInfo.ModTime);
    LLastModified := FormatHttpDate(FileModTimeToUnixSeconds(LInfo.ModTime));
    HttpServeStaticStream(AReq, AW, LFileSize, LETag, LLastModified, LMime, ACacheControl,
      FileModTimeToUnixSeconds(LInfo.ModTime),
      function: IStream
      begin
        Result := nextpas.core.fs.Open(AFilePath, [fmRead]);
      end, ADownloadName);
  except
    WriteErrorHeadAware(AReq, AW, HTTP_STATUS_INTERNAL_SERVER_ERROR, 'internal_error', 'Internal Server Error');
  end;
end;

{ ===== Public API ===== }

function ServeFile(const APath: string): THttpHandlerFunc;
begin
  Result := ServeFile(APath, CACHE_REVALIDATE);
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
  Result := ServeDir(ARoot, CACHE_REVALIDATE);
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
      if not IsHeadReq(AReq) then
        AW.Write(PAnsiChar('Bad Request')^, 11);
      Exit;
    end;
    { Security: reject traversal attempts }
    if not IsSafePath(LRelative) then
    begin
      AW.GetHeaders.SetHeader('content-length', '11');
      AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      if not IsHeadReq(AReq) then
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
    // perf: inline zero-copy prefix check via TStringView single source (bytes.ops SpanEqual→MemEqual, no System.Copy heap alloc)
    if (Length(LNormalizedFull) < Length(LNormalizedRoot)) or
       not TStringView.FromStr(LNormalizedFull).Left(SizeUInt(Length(LNormalizedRoot))).Equals(TStringView.FromStr(LNormalizedRoot)) then
    begin
      AW.GetHeaders.SetHeader('content-length', '9');
      AW.WriteHeader(HTTP_STATUS_FORBIDDEN);
      if not IsHeadReq(AReq) then
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
  LCache: IVfsETag;
  LServeMeta: IVfsServeMeta;
begin
  if AFs = nil then
  begin
    WriteErrorHeadAware(AReq, AW, HTTP_STATUS_INTERNAL_SERVER_ERROR, 'internal_error', 'Internal Server Error');
    Exit;
  end;
  try
    try
      LInfo := AFs.Stat(AVfsPath);
    except
      on EVfsNotFound do
      begin
        WriteErrorHeadAware(AReq, AW, HTTP_STATUS_NOT_FOUND, 'not_found', 'File not found');
        Exit;
      end;
      on EVfsInvalidPath do
      begin
        WriteErrorHeadAware(AReq, AW, HTTP_STATUS_NOT_FOUND, 'not_found', 'File not found');
        Exit;
      end;
    end;
    if LInfo.Info.IsDir then
    begin
      WriteErrorHeadAware(AReq, AW, HTTP_STATUS_NOT_FOUND, 'not_found', 'File not found');
      Exit;
    end;
    LModTimeUnix := LInfo.Info.ModTime;
    if LModTimeUnix < 0 then
      LModTimeUnix := 0;
    if Supports(AFs, IVfsServeMeta, LServeMeta) then
    begin
      if not LServeMeta.TryGetServeMeta(AVfsPath, LETag, LLastModified) then
      begin
        // 极少失败路径（Stat 已成功但 meta miss）回退到 hash/size
        if LInfo.ContentHash <> 0 then
          LETag := HttpMakeFnvETag(LInfo.ContentHash)
        else
          LETag := HttpMakeStrongETag(LInfo.Info.Size, LModTimeUnix);
        if LModTimeUnix > 0 then
          LLastModified := FormatHttpDate(LModTimeUnix)
        else
          LLastModified := '';
      end;
    end
    else if (AFs is IVfsETag) then
    begin
      LCache := AFs as IVfsETag;
      if LCache.TryGetETag(AVfsPath, LETag) then
      begin
        { hot path: embedded precomputed ETag — zero per-request hex alloc }
      end
      else if LInfo.ContentHash <> 0 then
        LETag := HttpMakeFnvETag(LInfo.ContentHash)
      else
        LETag := HttpMakeStrongETag(LInfo.Info.Size, LModTimeUnix);
      if not LCache.TryGetLastModified(AVfsPath, LLastModified) then
      begin
        if LModTimeUnix > 0 then
          LLastModified := FormatHttpDate(LModTimeUnix)
        else
          LLastModified := '';
      end;
    end
    else
    begin
      if LInfo.ContentHash <> 0 then
        LETag := HttpMakeFnvETag(LInfo.ContentHash)
      else
        LETag := HttpMakeStrongETag(LInfo.Info.Size, LModTimeUnix);
      if LModTimeUnix > 0 then
        LLastModified := FormatHttpDate(LModTimeUnix)
      else
        LLastModified := '';
    end;
    LMime := HttpMimeFromPath(AVfsPath);
    HttpServeStaticStream(AReq, AW, LInfo.Info.Size, LETag, LLastModified, LMime, ACacheControl, LModTimeUnix,
      function: IStream
      begin
        Result := AFs.OpenRead(AVfsPath);
      end);
  except
    on EVfsNotFound do
      WriteErrorHeadAware(AReq, AW, HTTP_STATUS_NOT_FOUND, 'not_found', 'File not found');
    else
      WriteErrorHeadAware(AReq, AW, HTTP_STATUS_INTERNAL_SERVER_ERROR, 'internal_error', 'Internal Server Error');
  end;
end;

function ServeVfs(const AFs: IVfs): THttpHandlerFunc;
begin
  Result := ServeVfs(AFs, CACHE_REVALIDATE);
end;

function ServeVfs(const AFs: IVfs; const ACacheControl: string): THttpHandlerFunc;
begin
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LRelative: string;
  begin
    if AFs = nil then
    begin
      WriteErrorHeadAware(AReq, AW, HTTP_STATUS_INTERNAL_SERVER_ERROR, 'internal_error', 'Internal Server Error');
      Exit;
    end;
    if not TryExtractRequestPath(AReq, LRelative) then
    begin
      AW.GetHeaders.SetHeader('content-length', '11');
      AW.WriteHeader(HTTP_STATUS_BAD_REQUEST);
      if not IsHeadReq(AReq) then
        AW.Write(PAnsiChar('Bad Request')^, 11);
      Exit;
    end;
    { The VFS namespace is canonical: empty/rooted/traversal forms are plain
      misses (404), indistinguishable from nonexistent entries. }
    if (LRelative = '') or not VfsValidPath(LRelative, False) then
    begin
      WriteErrorHeadAware(AReq, AW, HTTP_STATUS_NOT_FOUND, 'not_found', 'File not found');
      Exit;
    end;
    ServeVfsContentEx(AFs, LRelative, AReq, AW, ACacheControl);
  end;
end;

function ExtractFileNameInline(const APath: string): string; inline;
var
  I: SizeInt;
begin
  for I := Length(APath) downto 1 do
    if APath[I] = '/' then
      // perf: inline zero-copy extent via SliceToStr single source (bytes.ops TryClampSlice, no System.Copy heap alloc) — single SetString+Move via bytes.ops.BytesCopy single source, owner text.view
      Exit(SliceToStr(APath, SizeUInt(I), SizeUInt(Length(APath) - I)));
  Result := APath;
end;

function ServeFileDownload(const APath: string): THttpHandlerFunc;
var
  LFileName: string;
begin
  LFileName := ExtractFileNameInline(APath);
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    ServeFileContentEx(APath, AReq, AW, LFileName, CACHE_REVALIDATE);
  end;
end;

function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc;
begin
  Result := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    ServeFileContentEx(APath, AReq, AW, ADownloadName, CACHE_REVALIDATE);
  end;
end;

end.
