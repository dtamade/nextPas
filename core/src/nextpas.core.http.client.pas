unit nextpas.core.http.client;
{**
 * @desc HTTP/1.1 client with per-host connection pooling and keep-alive.
 *       Supports automatic redirect following.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  THttpClientOptions = nextpas.core.http.base.THttpClientOptions;

  THttpClient = class(TInterfacedObject, IHttpClient)
  private
    FOptions: THttpClientOptions;
    FTransport: IHttpTransport;
    function DoRequest(const AReq: IHttpRequest; ARedirectsLeft: Int32): IHttpResponse;
  public
    constructor Create(const AOptions: THttpClientOptions); overload;
    constructor Create(const ATransport: IHttpTransport;
      const AOptions: THttpClientOptions); overload;
    function Do_(const AReq: IHttpRequest): IHttpResponse;
    function Get(const AUrl: string): IHttpResponse;
    function Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse; overload;
    function Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Delete(const AUrl: string): IHttpResponse;
    function Patch(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Head(const AUrl: string): IHttpResponse;
  end;

function NewHttpClient: IHttpClient; overload;
function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient; overload;
function NewHttpClient(const ATransport: IHttpTransport): IHttpClient; overload;
function NewHttpClient(const ATransport: IHttpTransport;
  const AOptions: THttpClientOptions): IHttpClient; overload;
function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string;
  const ADest: IWriter): Int64;
function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64;
procedure HttpReleaseResponseBody(const AResp: IHttpResponse);
function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes;
function HttpReadResponseBodyString(const AResp: IHttpResponse): string;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.io,
  nextpas.core.io.memory,
  nextpas.core.text.conv,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.registry;

procedure CheckDownloadArgs(const AClient: IHttpClient; const AUrl: string);
begin
  if AClient = nil then
    raise EArgumentError.Create('HTTP download client is nil');
  if AUrl = '' then
    raise EArgumentError.Create('HTTP download URL is empty');
end;

procedure CheckDownloadResponse(const AResp: IHttpResponse; const AUrl: string);
begin
  if AResp = nil then
    raise EHttpError.Create('HTTP download returned no response: ' + AUrl);
  if (AResp.StatusCode < 200) or (AResp.StatusCode >= 300) then
    raise EHttpError.Create('HTTP download failed with status ' +
      IntToStr(Int64(AResp.StatusCode)) + ': ' + AUrl);
end;

procedure ValidateClientOptions(const AOptions: THttpClientOptions);
begin
  if AOptions.Timeout < 0 then
    raise EArgumentError.Create('HTTP client timeout must not be negative');
  if AOptions.MaxRedirects < 0 then
    raise EArgumentError.Create('HTTP client max redirects must not be negative');
end;

function MergeRedirectPath(const ABasePath, ATargetPath: string): string;
var
  LI: SizeInt;
  LSlashPos: SizeInt;
begin
  if ATargetPath = '' then
    Exit(ABasePath);
  if ATargetPath[1] = '/' then
    Exit(ATargetPath);

  LSlashPos := 0;
  for LI := Length(ABasePath) downto 1 do
    if ABasePath[LI] = '/' then
    begin
      LSlashPos := LI;
      Break;
    end;

  if LSlashPos > 0 then
    Result := System.Copy(ABasePath, 1, LSlashPos) + ATargetPath
  else
    Result := '/' + ATargetPath;
end;

function StartsWith(const AValue, APrefix: string): Boolean;
begin
  Result := (Length(AValue) >= Length(APrefix)) and
    (System.Copy(AValue, 1, Length(APrefix)) = APrefix);
end;

function EndsWith(const AValue, ASuffix: string): Boolean;
begin
  Result := (Length(AValue) >= Length(ASuffix)) and
    (System.Copy(AValue, Length(AValue) - Length(ASuffix) + 1,
      Length(ASuffix)) = ASuffix);
end;

function HasRedirectQueryDelimiter(const ALocation: string): Boolean;
var
  LI: SizeInt;
begin
  for LI := 1 to Length(ALocation) do
  begin
    case ALocation[LI] of
      '?':
        Exit(True);
      '#':
        Exit(False);
    end;
  end;
  Result := False;
end;

function RedirectAbsoluteScheme(const ALocation: string): string;
var
  LSchemeEnd: SizeInt;
begin
  LSchemeEnd := Pos('://', ALocation);
  if LSchemeEnd <= 1 then
    Exit('');
  Result := LowerCase(System.Copy(ALocation, 1, LSchemeEnd - 1));
end;

function IsRedirectTrustedHost(const AInitialUrl, ARedirectUrl: TUrl): Boolean;
var
  LInitialHost: string;
  LRedirectHost: string;
begin
  LInitialHost := LowerCase(AInitialUrl.Host);
  LRedirectHost := LowerCase(ARedirectUrl.Host);
  if (LInitialHost = '') or (LRedirectHost = '') then
    Exit(False);
  if LRedirectHost = LInitialHost then
    Exit(True);
  if (Pos(':', LRedirectHost) > 0) or (Pos('%', LRedirectHost) > 0) then
    Exit(False);
  if not EndsWith(LRedirectHost, LInitialHost) then
    Exit(False);
  Result := LRedirectHost[Length(LRedirectHost) - Length(LInitialHost)] = '.';
end;

function DefaultPortForScheme(const AScheme: string): UInt16;
var
  LScheme: string;
begin
  LScheme := LowerCase(AScheme);
  if LScheme = 'http' then
    Result := 80
  else if LScheme = 'https' then
    Result := 443
  else
    Result := 0;
end;

function EffectiveAuthorityPort(const AUrl: TUrl): UInt16;
begin
  if AUrl.Port <> 0 then
    Result := AUrl.Port
  else
    Result := DefaultPortForScheme(AUrl.Scheme);
end;

function IsRedirectSameAuthority(const AInitialUrl, ARedirectUrl: TUrl): Boolean;
begin
  Result := (AInitialUrl.Host <> '') and (ARedirectUrl.Host <> '') and
    (LowerCase(AInitialUrl.Host) = LowerCase(ARedirectUrl.Host)) and
    (EffectiveAuthorityPort(AInitialUrl) = EffectiveAuthorityPort(ARedirectUrl));
end;

function BufferedBodyRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABody: IReader): IHttpRequest;
var
  LHeaders: IHttpHeaders;
  LBody: TBytes;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-type', AContentType);

  if ABody <> nil then
    LBody := nextpas.core.io.ReadAll(ABody)
  else
    LBody := nil;

  Result := NewRequest(AMethod, AUrl, LHeaders, LBody);
end;

function BufferedBodyRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType, ABody: string): IHttpRequest; overload;
var
  LHeaders: IHttpHeaders;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-type', AContentType);
  Result := NewRequest(AMethod, AUrl, LHeaders, ABody);
end;

function BufferedBodyRequest(const AMethod: THttpMethod; const AUrl,
  AContentType: string; const ABody: TBytes): IHttpRequest; overload;
var
  LHeaders: IHttpHeaders;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-type', AContentType);
  Result := NewRequest(AMethod, AUrl, LHeaders, ABody);
end;

function RedirectHeadersFor(const AReq: IHttpRequest; const AInitialUrl,
  ARedirectUrl: TUrl; const AIncludeBody: Boolean): IHttpHeaders;
begin
  if (AReq <> nil) and (AReq.Headers <> nil) then
    Result := AReq.Headers.Clone
  else
    Result := NewHttpHeaders;

  if not IsRedirectSameAuthority(AInitialUrl, ARedirectUrl) then
    Result.Del('host');
  if not AIncludeBody then
  begin
    Result.Del('content-length');
    Result.Del('transfer-encoding');
  end;

  if not IsRedirectTrustedHost(AInitialUrl, ARedirectUrl) then
  begin
    Result.Del('authorization');
    Result.Del('www-authenticate');
    Result.Del('cookie');
    Result.Del('cookie2');
  end;
end;

function CaptureRedirectBodyPosition(const AReq: IHttpRequest;
  out ABodyStream: IStream; out AStartPosition: Int64): Boolean;
begin
  ABodyStream := nil;
  AStartPosition := 0;
  if (AReq = nil) or (AReq.Body = nil) then
    Exit(False);
  Result := Supports(AReq.Body, IStream, ABodyStream);
  if Result then
    AStartPosition := ABodyStream.Position;
end;

procedure RewindRedirectBody(const AReq: IHttpRequest; const ABodyStream: IStream;
  const AStartPosition: Int64);
begin
  if (AReq.Body = nil) or (AReq.ContentLength = 0) then
    Exit;
  if ABodyStream = nil then
    raise EHttpError.Create('redirect request body is not replayable');
  ABodyStream.Position := AStartPosition;
end;

procedure ReleaseResponseBody(const AResp: IHttpResponse);
var
  LBody: IReader;
  LReadCloser: IReadCloser;
  LCloser: ICloser;
  LStream: IStream;
  LBuf: array[0..4095] of Byte;
begin
  if (AResp = nil) or (AResp.Body = nil) then
    Exit;
  LBody := AResp.Body;

  if Supports(LBody, IReadCloser, LReadCloser) then
  begin
    LReadCloser.Close;
    Exit;
  end;
  if Supports(LBody, ICloser, LCloser) then
  begin
    LCloser.Close;
    Exit;
  end;
  if Supports(LBody, IStream, LStream) then
  begin
    LStream.Close;
    Exit;
  end;

  while LBody.Read(LBuf[0], SizeUInt(Length(LBuf))) > 0 do
    ;
end;

procedure RemoveLastPathSegment(var AOutput: string);
var
  LI: SizeInt;
begin
  for LI := Length(AOutput) downto 1 do
    if AOutput[LI] = '/' then
    begin
      SetLength(AOutput, LI - 1);
      Exit;
    end;
  AOutput := '';
end;

procedure MoveFirstPathSegment(var AInput, AOutput: string);
var
  LI: SizeInt;
  LSegmentLen: SizeInt;
begin
  if AInput = '' then
    Exit;

  LSegmentLen := Length(AInput);
  if AInput[1] = '/' then
  begin
    for LI := 2 to Length(AInput) do
      if AInput[LI] = '/' then
      begin
        LSegmentLen := LI - 1;
        Break;
      end;
  end
  else
  begin
    for LI := 1 to Length(AInput) do
      if AInput[LI] = '/' then
      begin
        LSegmentLen := LI - 1;
        Break;
      end;
  end;

  AOutput := AOutput + System.Copy(AInput, 1, LSegmentLen);
  Delete(AInput, 1, LSegmentLen);
end;

function NormalizeRedirectPath(const APath: string): string;
var
  LInput: string;
begin
  LInput := APath;
  Result := '';
  while LInput <> '' do
  begin
    if StartsWith(LInput, '../') then
      Delete(LInput, 1, 3)
    else if StartsWith(LInput, './') then
      Delete(LInput, 1, 2)
    else if StartsWith(LInput, '/./') then
      Delete(LInput, 2, 2)
    else if LInput = '/.' then
      LInput := '/'
    else if StartsWith(LInput, '/../') then
    begin
      Delete(LInput, 2, 3);
      RemoveLastPathSegment(Result);
    end
    else if LInput = '/..' then
    begin
      LInput := '/';
      RemoveLastPathSegment(Result);
    end
    else if (LInput = '.') or (LInput = '..') then
      LInput := ''
    else
      MoveFirstPathSegment(LInput, Result);
  end;
end;

function ResolveRedirectUrl(const ABaseUrl: TUrl; const ALocation: string): TUrl;
var
  LTarget: TUrl;
  LHasQueryDelimiter: Boolean;
  LScheme: string;
begin
  LScheme := RedirectAbsoluteScheme(ALocation);
  if LScheme <> '' then
  begin
    if (LScheme <> 'http') and (LScheme <> 'https') then
      raise EHttpError.Create('unsupported redirect URL scheme: ' + LScheme);
    Result := TUrl.Parse(ALocation);
    Result.Scheme := LScheme;
    Exit;
  end;
  if (Length(ALocation) >= 2) and (ALocation[1] = '/') and (ALocation[2] = '/') then
  begin
    if ABaseUrl.Scheme = '' then
      raise EHttpError.Create('network-path redirect requires base URL scheme');
    Exit(TUrl.Parse(ABaseUrl.Scheme + ':' + ALocation));
  end;

  Result := ABaseUrl;
  LHasQueryDelimiter := HasRedirectQueryDelimiter(ALocation);
  LTarget := TUrl.ParseRequestTarget(ALocation);
  if LTarget.Path <> '' then
  begin
    Result.Path := NormalizeRedirectPath(MergeRedirectPath(Result.Path, LTarget.Path));
    Result.RawQuery := LTarget.RawQuery;
  end
  else if LHasQueryDelimiter then
    Result.RawQuery := LTarget.RawQuery;
  Result.Fragment := LTarget.Fragment;
end;

{ THttpClient }

constructor THttpClient.Create(const AOptions: THttpClientOptions);
begin
  Create(nil, AOptions);
end;

constructor THttpClient.Create(const ATransport: IHttpTransport;
  const AOptions: THttpClientOptions);
begin
  inherited Create;
  ValidateClientOptions(AOptions);
  FOptions := AOptions;
  if ATransport <> nil then
    FTransport := ATransport
  else
    FTransport := ResolveDefaultClientTransport(AOptions);
end;

function THttpClient.DoRequest(const AReq: IHttpRequest; ARedirectsLeft: Int32): IHttpResponse;
var
  LUrl: TUrl;
  LResp: IHttpResponse;
  LLocation: string;
  LNewUrl: TUrl;
  LNewReq: IHttpRequest;
  LNewHeaders: IHttpHeaders;
  LBodyStream: IStream;
  LBodyStartPosition: Int64;
begin
  LUrl := AReq.Url;
  CaptureRedirectBodyPosition(AReq, LBodyStream, LBodyStartPosition);
  LResp := FTransport.RoundTrip(AReq);
  if LResp = nil then
    raise EHttpError.Create('HTTP transport returned no response');

  // Handle redirects
  if FOptions.FollowRedirects and
     ((LResp.StatusCode = HTTP_STATUS_MOVED_PERMANENTLY) or
      (LResp.StatusCode = HTTP_STATUS_FOUND) or
      (LResp.StatusCode = HTTP_STATUS_SEE_OTHER) or
      (LResp.StatusCode = 307) or (LResp.StatusCode = 308)) then
  begin
    if ARedirectsLeft <= 0 then
    begin
      ReleaseResponseBody(LResp);
      raise EHttpError.Create('too many redirects');
    end;

    LLocation := LResp.Headers.Get('location');
    if LLocation = '' then
    begin
      ReleaseResponseBody(LResp);
      raise EHttpError.Create('redirect with no Location header');
    end;

    ReleaseResponseBody(LResp);
    LNewUrl := ResolveRedirectUrl(LUrl, LLocation);

    // Go-style 301/302/303 redirects replay as GET and drop the body.
    if (LResp.StatusCode = HTTP_STATUS_MOVED_PERMANENTLY) or
       (LResp.StatusCode = HTTP_STATUS_FOUND) or
       (LResp.StatusCode = HTTP_STATUS_SEE_OTHER) then
    begin
      LNewHeaders := RedirectHeadersFor(AReq, LUrl, LNewUrl, False);
      LNewReq := THttpRequest.Create(hmGet, LNewUrl, hvHttp11, LNewHeaders,
        nil, 0);
    end
    else
    begin
      RewindRedirectBody(AReq, LBodyStream, LBodyStartPosition);
      LNewHeaders := RedirectHeadersFor(AReq, LUrl, LNewUrl, True);
      LNewReq := THttpRequest.Create(AReq.Method, LNewUrl, hvHttp11,
        LNewHeaders, AReq.Body, AReq.ContentLength);
    end;

    Result := DoRequest(LNewReq, ARedirectsLeft - 1);
  end
  else
    Result := LResp;
end;

function THttpClient.Do_(const AReq: IHttpRequest): IHttpResponse;
begin
  if AReq = nil then
    raise EArgumentError.Create('HTTP request is nil');
  Result := DoRequest(AReq, FOptions.MaxRedirects);
end;

function THttpClient.Get(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Do_(LReq);
end;

function THttpClient.Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := BufferedBodyRequest(hmPost, LUrl, AContentType, ABody);
  Result := Do_(LReq);
end;

function THttpClient.Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := Do_(BufferedBodyRequest(hmPost, AUrl, AContentType, ABody));
end;

function THttpClient.Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := Do_(BufferedBodyRequest(hmPost, AUrl, AContentType, ABody));
end;

function THttpClient.Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := BufferedBodyRequest(hmPut, LUrl, AContentType, ABody);
  Result := Do_(LReq);
end;

function THttpClient.Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := Do_(BufferedBodyRequest(hmPut, AUrl, AContentType, ABody));
end;

function THttpClient.Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := Do_(BufferedBodyRequest(hmPut, AUrl, AContentType, ABody));
end;

function THttpClient.Delete(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmDelete, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Do_(LReq);
end;

function THttpClient.Patch(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := BufferedBodyRequest(hmPatch, LUrl, AContentType, ABody);
  Result := Do_(LReq);
end;

function THttpClient.Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := Do_(BufferedBodyRequest(hmPatch, AUrl, AContentType, ABody));
end;

function THttpClient.Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := Do_(BufferedBodyRequest(hmPatch, AUrl, AContentType, ABody));
end;

function THttpClient.Head(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmHead, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Do_(LReq);
end;

{ Factory functions }

function NewHttpClient: IHttpClient;
begin
  Result := THttpClient.Create(THttpClientOptions.Default);
end;

function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := THttpClient.Create(AOptions);
end;

function NewHttpClient(const ATransport: IHttpTransport): IHttpClient;
begin
  Result := THttpClient.Create(ATransport, THttpClientOptions.Default);
end;

function NewHttpClient(const ATransport: IHttpTransport;
  const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := THttpClient.Create(ATransport, AOptions);
end;

function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string;
  const ADest: IWriter): Int64;
var
  LResp: IHttpResponse;
begin
  CheckDownloadArgs(AClient, AUrl);
  if ADest = nil then
    raise EArgumentError.Create('HTTP download destination writer is nil');

  LResp := AClient.Get(AUrl);
  try
    CheckDownloadResponse(LResp, AUrl);
    if LResp.Body = nil then
      Exit(0);
    Result := nextpas.core.io.Copy(ADest, LResp.Body);
  finally
    ReleaseResponseBody(LResp);
  end;
end;

function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64;
var
  LResp: IHttpResponse;
  LDestDir: string;
  LTempPath: string;
  LTempFile: IFile;
  LCommitted: Boolean;
begin
  CheckDownloadArgs(AClient, AUrl);
  if ADestPath = '' then
    raise EArgumentError.Create('HTTP download destination path is empty');

  LResp := AClient.Get(AUrl);
  try
    CheckDownloadResponse(LResp, AUrl);

    LDestDir := nextpas.core.fs.PathDir(ADestPath);
    if not nextpas.core.fs.MkdirAll(LDestDir) then
      raise EHttpError.Create('HTTP download could not create directory: ' + LDestDir);

    LTempFile := nextpas.core.fs.TempFile(LDestDir,
      '.' + nextpas.core.fs.PathBase(ADestPath) + '.tmp.');
    LTempPath := LTempFile.Name;
    LCommitted := False;
    try
      if LResp.Body <> nil then
        Result := nextpas.core.io.Copy(LTempFile as IWriter, LResp.Body)
      else
        Result := 0;
      LTempFile.Sync;
      LTempFile.Close;
      LTempFile := nil;

      if not nextpas.core.fs.Rename(LTempPath, ADestPath) then
        raise EHttpError.Create('HTTP download could not publish file: ' + ADestPath);
      LCommitted := True;
    finally
      if LTempFile <> nil then
      begin
        try
          LTempFile.Close;
        except
          on E: Exception do ;
        end;
      end;
      if (not LCommitted) and (LTempPath <> '') then
        nextpas.core.fs.Remove(LTempPath);
    end;
  finally
    ReleaseResponseBody(LResp);
  end;
end;

procedure HttpReleaseResponseBody(const AResp: IHttpResponse);
begin
  if AResp = nil then
    raise EArgumentError.Create('HTTP response is nil');
  ReleaseResponseBody(AResp);
end;

function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes;
var
  LBody: IReader;
begin
  if AResp = nil then
    raise EArgumentError.Create('HTTP response is nil');

  LBody := AResp.Body;
  if LBody = nil then
    Exit;

  Result := nextpas.core.io.ReadAll(LBody);
end;

function HttpReadResponseBodyString(const AResp: IHttpResponse): string;
var
  LBody: TBytes;
begin
  LBody := HttpReadResponseBodyBytes(AResp);
  Result := '';
  SetLength(Result, Length(LBody));
  if Length(LBody) > 0 then
    Move(LBody[0], Result[1], Length(LBody));
end;

end.
