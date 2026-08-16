unit nextpas.core.http.client.redirect;
{**
 * @desc HTTP client redirect helpers (STRUCT-2 extract from client).
 *       Pure URL/header/body transforms for redirect follow; no RoundTrip loop.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

{ Public helpers used by THttpClient.DoRequest. }
function MethodForGetStyleRedirect(const AMethod: THttpMethod): THttpMethod;
function RedirectHeadersFor(const AReq: IHttpRequest; const AInitialUrl,
  ARedirectUrl: TUrl; const AIncludeBody: Boolean): IHttpHeaders;
function CaptureRedirectBodyPosition(const AReq: IHttpRequest;
  out ABodyStream: IStream; out AStartPosition: Int64): Boolean;
procedure RewindRedirectBody(const AReq: IHttpRequest; const ABodyStream: IStream;
  const AStartPosition: Int64);
function ResolveRedirectUrl(const ABaseUrl: TUrl; const ALocation: string): TUrl;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.http.headers,
  nextpas.core.http.message;

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
  LI: SizeInt;
begin
  LSchemeEnd := 0;
  for LI := 1 to Length(ALocation) do
  begin
    case ALocation[LI] of
      ':':
      begin
        LSchemeEnd := LI;
        Break;
      end;
      '/', '?', '#':
        Break;
    end;
  end;
  if LSchemeEnd <= 1 then
    Exit('');
  Result := LowerCase(System.Copy(ALocation, 1, LSchemeEnd - 1));
end;

function RedirectAuthorityPortIsValid(const ALocation: string): Boolean;
var
  LAuthorityStart: SizeInt;
  LAuthorityEnd: SizeInt;
  LAuthority: string;
  LAtPos: SizeInt;
  LColonPos: SizeInt;
  LBracketPos: SizeInt;
  LPortStr: string;
  LPortValue: Int64;
  LI: SizeInt;
begin
  LPortValue := 0;
  Result := True;
  LAuthorityStart := Pos('://', ALocation);
  if LAuthorityStart = 0 then
    Exit;
  Inc(LAuthorityStart, 3);

  LAuthorityEnd := Length(ALocation) + 1;
  for LI := LAuthorityStart to Length(ALocation) do
    if (ALocation[LI] = '/') or (ALocation[LI] = '?') or
      (ALocation[LI] = '#') then
    begin
      LAuthorityEnd := LI;
      Break;
    end;

  LAuthority := System.Copy(ALocation, LAuthorityStart,
    LAuthorityEnd - LAuthorityStart);
  if LAuthority = '' then
    Exit;

  LAtPos := Pos('@', LAuthority);
  if LAtPos > 0 then
    Delete(LAuthority, 1, LAtPos);
  if LAuthority = '' then
    Exit;

  if LAuthority[1] = '[' then
  begin
    LBracketPos := Pos(']', LAuthority);
    if LBracketPos = 0 then
    begin
      Result := False;
      Exit;
    end;
    if LBracketPos = Length(LAuthority) then
      Exit;
    if LAuthority[LBracketPos + 1] <> ':' then
    begin
      Result := False;
      Exit;
    end;
    LPortStr := System.Copy(LAuthority, LBracketPos + 2,
      Length(LAuthority) - LBracketPos - 1);
  end
  else
  begin
    LColonPos := Pos(':', LAuthority);
    if LColonPos = 0 then
      Exit;
    LPortStr := System.Copy(LAuthority, LColonPos + 1,
      Length(LAuthority) - LColonPos);
  end;

  Result := (LPortStr <> '') and TryStrToInt64(LPortStr, LPortValue) and
    (LPortValue >= 0) and (LPortValue <= 65535);
end;

function ParseRedirectAuthorityUrl(const AUrl, AScheme: string): TUrl;
begin
  Result := TUrl.Parse(AUrl);
  Result.Scheme := AScheme;
  if Result.Host = '' then
    raise EHttpError.CreateOp(hekRedirect, 'redirect',
      'redirect URL host is empty');
  if not RedirectAuthorityPortIsValid(AUrl) then
    raise EHttpError.CreateOp(hekRedirect, 'redirect',
      'redirect URL port is invalid');
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

function IsRedirectSameOrigin(const AInitialUrl, ARedirectUrl: TUrl): Boolean;
begin
  Result := IsRedirectSameAuthority(AInitialUrl, ARedirectUrl) and
    (LowerCase(AInitialUrl.Scheme) = LowerCase(ARedirectUrl.Scheme));
end;

function MethodForGetStyleRedirect(const AMethod: THttpMethod): THttpMethod;
begin
  if AMethod = hmHead then
    Result := hmHead
  else
    Result := hmGet;
end;

function RedirectHeadersFor(const AReq: IHttpRequest; const AInitialUrl,
  ARedirectUrl: TUrl; const AIncludeBody: Boolean): IHttpHeaders;
begin
  if (AReq <> nil) and (AReq.Headers <> nil) then
    Result := AReq.Headers.Clone
  else
    Result := NewHttpHeaders;

  if not IsRedirectSameAuthority(AInitialUrl, ARedirectUrl) then
    Result.Remove('host');
  if not AIncludeBody then
  begin
    Result.Remove('content-length');
    Result.Remove('transfer-encoding');
  end;

  if not IsRedirectSameOrigin(AInitialUrl, ARedirectUrl) then
  begin
    Result.Remove('authorization');
    Result.Remove('proxy-authorization');
    Result.Remove('www-authenticate');
    Result.Remove('cookie');
    Result.Remove('cookie2');
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
    raise EHttpError.CreateOp(hekBody, 'redirect',
      'redirect request body is not replayable');
  ABodyStream.Position := AStartPosition;
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
      raise EHttpError.CreateOp(hekRedirect, 'redirect',
        'unsupported redirect URL scheme: ' + LScheme);
    Exit(ParseRedirectAuthorityUrl(ALocation, LScheme));
  end;
  if (Length(ALocation) >= 2) and (ALocation[1] = '/') and (ALocation[2] = '/') then
  begin
    if ABaseUrl.Scheme = '' then
      raise EHttpError.CreateOp(hekRedirect, 'redirect',
        'network-path redirect requires base URL scheme');
    Exit(ParseRedirectAuthorityUrl(ABaseUrl.Scheme + ':' + ALocation,
      ABaseUrl.Scheme));
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

end.
