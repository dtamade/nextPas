unit nextpas.core.http.client;
{**
 * @desc HTTP/1.1 client with per-host connection pooling and keep-alive.
 *       Supports automatic redirect following.
 *}

{$I nextpas.core.settings.inc}

interface

uses
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
    function Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
    function Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
    function Delete(const AUrl: string): IHttpResponse;
    function Patch(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
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
function HttpReadResponseBodyString(const AResp: IHttpResponse): string;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.io,
  nextpas.core.io.memory,
  nextpas.core.text.conv,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.registry;

function StrToBytes(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

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
begin
  if (Pos('http://', ALocation) = 1) or (Pos('https://', ALocation) = 1) then
    Exit(TUrl.Parse(ALocation));
  if (Length(ALocation) >= 2) and (ALocation[1] = '/') and (ALocation[2] = '/') then
  begin
    if ABaseUrl.Scheme = '' then
      raise EHttpError.Create('network-path redirect requires base URL scheme');
    Exit(TUrl.Parse(ABaseUrl.Scheme + ':' + ALocation));
  end;

  Result := ABaseUrl;
  LTarget := TUrl.ParseRequestTarget(ALocation);
  if LTarget.Path <> '' then
    Result.Path := NormalizeRedirectPath(MergeRedirectPath(Result.Path, LTarget.Path));
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
begin
  LUrl := AReq.Url;
  LResp := FTransport.RoundTrip(AReq);

  // Handle redirects
  if FOptions.FollowRedirects and
     ((LResp.StatusCode = HTTP_STATUS_MOVED_PERMANENTLY) or
      (LResp.StatusCode = HTTP_STATUS_FOUND) or
      (LResp.StatusCode = HTTP_STATUS_SEE_OTHER) or
      (LResp.StatusCode = 307) or (LResp.StatusCode = 308)) then
  begin
    if ARedirectsLeft <= 0 then
      raise EHttpError.Create('too many redirects');

    LLocation := LResp.Headers.Get('location');
    if LLocation = '' then
      raise EHttpError.Create('redirect with no Location header');

    LNewUrl := ResolveRedirectUrl(LUrl, LLocation);

    // Go-style 301/302/303 redirects replay as GET and drop the body.
    if (LResp.StatusCode = HTTP_STATUS_MOVED_PERMANENTLY) or
       (LResp.StatusCode = HTTP_STATUS_FOUND) or
       (LResp.StatusCode = HTTP_STATUS_SEE_OTHER) then
      LNewReq := THttpRequest.Create(hmGet, LNewUrl, hvHttp11, NewHttpHeaders, nil, 0)
    else
      LNewReq := THttpRequest.Create(AReq.Method, LNewUrl, hvHttp11, NewHttpHeaders, AReq.Body, AReq.ContentLength);

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
  LHeaders: IHttpHeaders;
  LBodyBuf: string;
  LTmp: array[0..4095] of Byte;
  LN: SizeUInt;
  LBodyStream: IStream;
begin
  LUrl := TUrl.Parse(AUrl);
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-type', AContentType);

  // Read all body into buffer to determine content-length
  LBodyBuf := '';
  if ABody <> nil then
  begin
    repeat
      LN := ABody.Read(LTmp[0], 4096);
      if LN > 0 then
      begin
        SetLength(LBodyBuf, Length(LBodyBuf) + Int32(LN));
        Move(LTmp[0], LBodyBuf[Length(LBodyBuf) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  end;

  LHeaders.Set_('content-length', IntToStr(Int64(Length(LBodyBuf))));

  if LBodyBuf <> '' then
  begin
    LBodyStream := CreateBytesStreamFrom(StrToBytes(LBodyBuf));
    LReq := THttpRequest.Create(hmPost, LUrl, hvHttp11, LHeaders, LBodyStream as IReader, Int64(Length(LBodyBuf)));
  end
  else
    LReq := THttpRequest.Create(hmPost, LUrl, hvHttp11, LHeaders, nil, 0);

  Result := Do_(LReq);
end;

function THttpClient.Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
  LBodyBuf: string;
  LTmp: array[0..4095] of Byte;
  LN: SizeUInt;
  LBodyStream: IStream;
begin
  LUrl := TUrl.Parse(AUrl);
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-type', AContentType);

  LBodyBuf := '';
  if ABody <> nil then
  begin
    repeat
      LN := ABody.Read(LTmp[0], 4096);
      if LN > 0 then
      begin
        SetLength(LBodyBuf, Length(LBodyBuf) + Int32(LN));
        Move(LTmp[0], LBodyBuf[Length(LBodyBuf) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  end;

  LHeaders.Set_('content-length', IntToStr(Int64(Length(LBodyBuf))));

  if LBodyBuf <> '' then
  begin
    LBodyStream := CreateBytesStreamFrom(StrToBytes(LBodyBuf));
    LReq := THttpRequest.Create(hmPut, LUrl, hvHttp11, LHeaders, LBodyStream as IReader, Int64(Length(LBodyBuf)));
  end
  else
    LReq := THttpRequest.Create(hmPut, LUrl, hvHttp11, LHeaders, nil, 0);

  Result := Do_(LReq);
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
  LHeaders: IHttpHeaders;
  LBodyBuf: string;
  LTmp: array[0..4095] of Byte;
  LN: SizeUInt;
  LBodyStream: IStream;
begin
  LUrl := TUrl.Parse(AUrl);
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-type', AContentType);

  LBodyBuf := '';
  if ABody <> nil then
  begin
    repeat
      LN := ABody.Read(LTmp[0], 4096);
      if LN > 0 then
      begin
        SetLength(LBodyBuf, Length(LBodyBuf) + Int32(LN));
        Move(LTmp[0], LBodyBuf[Length(LBodyBuf) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  end;

  LHeaders.Set_('content-length', IntToStr(Int64(Length(LBodyBuf))));

  if LBodyBuf <> '' then
  begin
    LBodyStream := CreateBytesStreamFrom(StrToBytes(LBodyBuf));
    LReq := THttpRequest.Create(hmPatch, LUrl, hvHttp11, LHeaders, LBodyStream as IReader, Int64(Length(LBodyBuf)));
  end
  else
    LReq := THttpRequest.Create(hmPatch, LUrl, hvHttp11, LHeaders, nil, 0);

  Result := Do_(LReq);
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
  CheckDownloadResponse(LResp, AUrl);
  if LResp.Body = nil then
    Exit(0);
  Result := nextpas.core.io.Copy(ADest, LResp.Body);
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
end;

function HttpReadResponseBodyString(const AResp: IHttpResponse): string;
var
  LBody: IReader;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LOldLen: SizeInt;
begin
  if AResp = nil then
    raise EArgumentError.Create('HTTP response is nil');

  LBody := AResp.Body;
  Result := '';
  if LBody = nil then
    Exit;

  repeat
    LN := LBody.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    if LN > 0 then
    begin
      LOldLen := Length(Result);
      SetLength(Result, LOldLen + SizeInt(LN));
      Move(LBuf[0], Result[LOldLen + 1], LN);
    end;
  until LN = 0;
end;

end.
