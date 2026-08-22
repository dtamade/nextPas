unit nextpas.core.http.middleware.compression;
{**
 * @desc Response compression middleware. Compresses response bodies using
 *       gzip or deflate based on the client's Accept-Encoding header.
 *       Only compresses text-based content types (JSON, HTML, CSS, JS, XML, text).
 *       Skips small responses (< MIN_COMPRESS_SIZE bytes) and already-compressed
 *       content types (images, video, audio, application/zip, etc).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{** @desc Create compression middleware with default settings.
   Compresses responses >= 1024 bytes using gzip or deflate. }
function CompressionMiddleware: IHttpMiddleware;

{** @desc Create compression middleware with custom minimum size.
   AMinSize: minimum body size in bytes to trigger compression (0 = always compress). }
function CompressionMiddlewareWith(AMinSize: SizeUInt): IHttpMiddleware;

implementation

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.compress,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.message,
  nextpas.core.text.strings;

const
  DEFAULT_MIN_COMPRESS_SIZE = 1024;
  { Maximum buffer size for compression middleware to prevent memory DoS }
  MAX_COMPRESS_BUFFER_SIZE: SizeUInt = 64 * 1024 * 1024; { 64 MB }

type
  { Buffered response writer that captures body in memory.
    Forwards header operations to the real writer, but buffers Write calls.
    On Flush, writes the (optionally compressed) body to the real writer. }
  TBufferedResponseWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FReal: IHttpResponseWriter;
    FBody: TBytes;
    FBodyLen: SizeUInt;
    FStatus: THttpStatus;
    FHeadersWritten: Boolean;
    procedure EnsureCapacity(AExtra: SizeUInt);
  public
    constructor Create(const AReal: IHttpResponseWriter);
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    { Write buffered body to real writer, optionally compressed }
    procedure FlushToReal(const AEncoding: string; const ASuppressBody: Boolean);
    property BodyLen: SizeUInt read FBodyLen;
    function GetBody: TBytes;
  end;

function IsCompressible(const AContentType: string): Boolean;
var
  LLower: string;
begin
  LLower := LowerCase(AContentType);
  { Text-based types that benefit from compression }
  if Pos('json', LLower) > 0 then Exit(True);
  if Pos('html', LLower) > 0 then Exit(True);
  if Pos('css', LLower) > 0 then Exit(True);
  if Pos('javascript', LLower) > 0 then Exit(True);
  if Pos('xml', LLower) > 0 then Exit(True);
  if Pos('text/', LLower) > 0 then Exit(True);
  if Pos('svg', LLower) > 0 then Exit(True);
  if Pos('font/woff', LLower) > 0 then Exit(True);
  if Pos('application/x-font', LLower) > 0 then Exit(True);
  { Already compressed types — skip }
  Result := False;
end;

function TryParseQuality(const AValue: string; out AQuality: Int32): Boolean;
var
  LValue: string;
  LI, LScale: SizeInt;
begin
  Result := False;
  AQuality := 0;
  LValue := Trim(AValue);
  if (LValue = '0') or (LValue = '0.') then
    Exit(True);
  if (LValue = '1') or (LValue = '1.') then
  begin
    AQuality := 1000;
    Exit(True);
  end;
  if (Length(LValue) < 3) or (Length(LValue) > 5) or
     (LValue[2] <> '.') or not (LValue[1] in ['0', '1']) then
    Exit;

  AQuality := 0;
  LScale := 100;
  for LI := 3 to Length(LValue) do
  begin
    if not (LValue[LI] in ['0'..'9']) then
      Exit(False);
    if (LValue[1] = '1') and (LValue[LI] <> '0') then
      Exit(False);
    Inc(AQuality, (Ord(LValue[LI]) - Ord('0')) * LScale);
    LScale := LScale div 10;
  end;
  if LValue[1] = '1' then
    AQuality := 1000;
  Result := True;
end;

function ParseAcceptEncoding(const AAcceptEncoding: string): string;
var
  LItems, LParts: TStringArray;
  LCoding, LParam, LParamName, LParamValue: string;
  LI, LJ, LEqPos: SizeInt;
  LQuality, LGzipQuality, LDeflateQuality, LWildcardQuality: Int32;
  LGzipSeen, LDeflateSeen: Boolean;
begin
  Result := '';
  if Trim(AAcceptEncoding) = '' then
    Exit;

  LGzipQuality := 0;
  LDeflateQuality := 0;
  LWildcardQuality := -1;
  LGzipSeen := False;
  LDeflateSeen := False;
  LItems := StringsSplit(AAcceptEncoding, ',');
  for LI := 0 to High(LItems) do
  begin
    LParts := StringsSplit(LItems[LI], ';');
    if Length(LParts) = 0 then
      Continue;
    LCoding := LowerCase(Trim(LParts[0]));
    if LCoding = '' then
      Continue;
    LQuality := 1000;
    for LJ := 1 to High(LParts) do
    begin
      LParam := Trim(LParts[LJ]);
      LEqPos := Pos('=', LParam);
      if LEqPos <= 1 then
        Continue;
      LParamName := LowerCase(Trim(Copy(LParam, 1, LEqPos - 1)));
      if LParamName <> 'q' then
        Continue;
      LParamValue := Copy(LParam, LEqPos + 1, MaxInt);
      if not TryParseQuality(LParamValue, LQuality) then
        LQuality := 0;
      Break;
    end;

    if LCoding = 'gzip' then
    begin
      LGzipSeen := True;
      LGzipQuality := LQuality;
    end
    else if LCoding = 'deflate' then
    begin
      LDeflateSeen := True;
      LDeflateQuality := LQuality;
    end
    else if LCoding = '*' then
      LWildcardQuality := LQuality;
  end;

  if not LGzipSeen and (LWildcardQuality >= 0) then
    LGzipQuality := LWildcardQuality;
  if not LDeflateSeen and (LWildcardQuality >= 0) then
    LDeflateQuality := LWildcardQuality;

  if (LGzipQuality <= 0) and (LDeflateQuality <= 0) then
    Exit;
  if LGzipQuality >= LDeflateQuality then
    Result := 'gzip'
  else
    Result := 'deflate';
end;

procedure AppendVaryToken(const AHeaders: IHttpHeaders; const AToken: string);
var
  LCurrent: string;
  LTokens: TStringArray;
  LI: SizeInt;
begin
  LCurrent := AHeaders.Get('vary');
  if Trim(LCurrent) = '*' then
    Exit;
  LTokens := StringsSplit(LCurrent, ',');
  for LI := 0 to High(LTokens) do
    if LowerCase(Trim(LTokens[LI])) = LowerCase(AToken) then
      Exit;
  if Trim(LCurrent) = '' then
    AHeaders.SetHeader('vary', AToken)
  else
    AHeaders.SetHeader('vary', LCurrent + ', ' + AToken);
end;

procedure WriteAllResponse(const AWriter: IHttpResponseWriter; const ABuf;
  const ACount: SizeUInt);
var
  LBuffer: PByte;
  LWritten, LTotal, LRemaining: SizeUInt;
begin
  LBuffer := @ABuf;
  LTotal := 0;
  while LTotal < ACount do
  begin
    LRemaining := ACount - LTotal;
    LWritten := AWriter.Write(LBuffer[LTotal], LRemaining);
    if LWritten = 0 then
      raise EIOError.Create('compression middleware: response writer made zero progress');
    if LWritten > LRemaining then
      raise EIOError.Create('compression middleware: response writer over-reported progress');
    Inc(LTotal, LWritten);
  end;
end;

{ TBufferedResponseWriter }

constructor TBufferedResponseWriter.Create(const AReal: IHttpResponseWriter);
begin
  inherited Create;
  FReal := AReal;
  FBody := nil;
  FBodyLen := 0;
  FStatus := HTTP_STATUS_OK;
  FHeadersWritten := False;
end;

procedure TBufferedResponseWriter.EnsureCapacity(AExtra: SizeUInt);
var
  LNewCap: SizeUInt;
begin
  { Prevent memory DoS from unbounded buffering }
  if (AExtra > MAX_COMPRESS_BUFFER_SIZE) or
     (FBodyLen > MAX_COMPRESS_BUFFER_SIZE - AExtra) then
    raise EHttpError.Create(hekBody, 'Response body too large for compression buffering');
  if AExtra > High(SizeUInt) - FBodyLen then
    raise EHttpError.Create(hekBody, 'Response body size overflow');
  if FBodyLen + AExtra > SizeUInt(Length(FBody)) then
  begin
    LNewCap := SizeUInt(Length(FBody)) * 2;
    if LNewCap < 4096 then
      LNewCap := 4096;
    while LNewCap < FBodyLen + AExtra do
    begin
      if LNewCap > MAX_COMPRESS_BUFFER_SIZE div 2 then
      begin
        LNewCap := MAX_COMPRESS_BUFFER_SIZE;
        Break;
      end;
      LNewCap := LNewCap * 2;
    end;
    SetLength(FBody, LNewCap);
  end;
end;

procedure TBufferedResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
  FHeadersWritten := True;
end;

function TBufferedResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TBufferedResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FReal.GetHeaders;
end;

function TBufferedResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  EnsureCapacity(ACount);
  Move(ABuf, FBody[FBodyLen], ACount);
  Inc(FBodyLen, ACount);
  Result := ACount;
end;

procedure TBufferedResponseWriter.Flush;
begin
  { No-op — we flush everything in FlushToReal }
end;

procedure TBufferedResponseWriter.FlushToReal(const AEncoding: string;
  const ASuppressBody: Boolean);
var
  LCompressed: TBytes;
  LBodyBytes: TBytes;
  LUseCompressed: Boolean;
begin
  if HttpStatusIsInformational(FStatus) or
     (FStatus = HTTP_STATUS_NO_CONTENT) or
     (FStatus = HTTP_STATUS_NOT_MODIFIED) then
  begin
    FReal.GetHeaders.Remove('content-length');
    FReal.GetHeaders.Remove('transfer-encoding');
    FReal.WriteHeader(FStatus);
    Exit;
  end;

  if FBodyLen = 0 then
  begin
    FReal.GetHeaders.SetHeader('content-length', '0');
    FReal.WriteHeader(FStatus);
    Exit;
  end;

  LUseCompressed := False;
  if AEncoding <> '' then
  begin
    LBodyBytes := Copy(FBody, 0, FBodyLen);
    try
      if AEncoding = 'gzip' then
        LCompressed := GzipCompress(LBodyBytes)
      else
        LCompressed := DeflateCompress(LBodyBytes);
      LUseCompressed := SizeUInt(Length(LCompressed)) < FBodyLen;
    except
      LUseCompressed := False;
    end;
  end;

  if LUseCompressed then
  begin
    FReal.GetHeaders.SetHeader('content-encoding', AEncoding);
    FReal.GetHeaders.SetHeader('content-length', IntToStr(Length(LCompressed)));
    AppendVaryToken(FReal.GetHeaders, 'Accept-Encoding');
    FReal.WriteHeader(FStatus);
    if not ASuppressBody then
      WriteAllResponse(FReal, LCompressed[0], SizeUInt(Length(LCompressed)));
  end
  else
  begin
    FReal.GetHeaders.SetHeader('content-length', IntToStr(FBodyLen));
    FReal.WriteHeader(FStatus);
    if not ASuppressBody then
      WriteAllResponse(FReal, FBody[0], FBodyLen);
  end;
end;

function TBufferedResponseWriter.GetBody: TBytes;
begin
  Result := nil;
  SetLength(Result, FBodyLen);
  if FBodyLen > 0 then
    Move(FBody[0], Result[0], FBodyLen);
end;

{ CompressionMiddleware }

function CompressionMiddleware: IHttpMiddleware;
begin
  Result := CompressionMiddlewareWith(DEFAULT_MIN_COMPRESS_SIZE);
end;

function CompressionMiddlewareWith(AMinSize: SizeUInt): IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBuf: TBufferedResponseWriter;
      LAcceptEncoding, LEncoding: string;
      LContentType: string;
      LUseCompression: Boolean;
      LBufWriter: IHttpResponseWriter;
    begin
      LAcceptEncoding := AReq.GetHeaders.Get('accept-encoding');
      LEncoding := ParseAcceptEncoding(LAcceptEncoding);

      { Create buffered writer — always buffer to check content type and size }
      LBuf := TBufferedResponseWriter.Create(AW);
      LBufWriter := LBuf;
      ANext.ServeHTTP(AReq, LBufWriter);

      { Decide whether to compress }
      LUseCompression := False;
      if (LEncoding <> '') and
         (not AW.GetHeaders.Has('content-encoding')) then
      begin
        if LBuf.BodyLen >= AMinSize then
        begin
          LContentType := AW.GetHeaders.Get('content-type');
          if IsCompressible(LContentType) then
            LUseCompression := True;
        end;
      end;

      if LUseCompression then
        LBuf.FlushToReal(LEncoding, AReq.Method = hmHead)
      else
        LBuf.FlushToReal('', AReq.Method = hmHead);
    end);
  end);
end;

end.
