unit nextpas.core.http.cookie;
{**
 * @desc HTTP Cookie parsing and generation (RFC 6265).
 *       Parse request Cookie header, build Set-Cookie response headers.
 *       Client-side IHttpCookieJar stores Set-Cookie and injects Cookie.
 *
 *       Usage (server-side):
 *         var LCookies: TRequestCookies;
 *         LCookies := ParseCookies(AReq.Headers.Get('cookie'));
 *         LSessionId := LCookies.Get('session_id');
 *
 *         AW.Headers.Add('set-cookie', BuildSetCookie(
 *           MakeCookie('session_id', 'abc123')
 *             .WithHttpOnly(True)
 *             .WithSecure(True)
 *             .WithSameSite(ssLax)
 *             .WithMaxAge(3600)
 *         ));
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  IHttpCookieJar = nextpas.core.http.intf.IHttpCookieJar;

  TSameSite = (ssStrict, ssLax, ssNone);

  { Parsed Cookie header name=value pairs.
    RFC 6265 Section 5.4: cookies are ordered by path length (longest first),
    but most frameworks expose them as an unordered map. We store pairs. }
  TRequestCookies = record
  private
    FPairs: array of record
      Name: string;
      Value: string;
    end;
  public
    { Get cookie value by name. Returns '' if not found. }
    function Get(const AName: string): string;
    { Check if a cookie exists. }
    function Has(const AName: string): Boolean;
    { Number of cookies. }
    function Count: Int32;
    { Get cookie name-value pair by index. }
    procedure GetPair(AIndex: Int32; out AName, AValue: string);
  end;

  { Set-Cookie builder — immutable record with chaining methods.
    Call ToString to produce the Set-Cookie header value. }
  TSetCookie = record
    Name: string;
    Value: string;
    Domain: string;
    Path: string;
    Expires: string;       { RFC 7231 date string, e.g. 'Sun, 06 Jul 2026 12:00:00 GMT' }
    MaxAge: Int64;         { -1 = not set }
    HttpOnly: Boolean;
    Secure: Boolean;
    SameSite: TSameSite;
    HasSameSite: Boolean;
    function WithDomain(const ADomain: string): TSetCookie;
    function WithPath(const APath: string): TSetCookie;
    function WithExpires(const AExpires: string): TSetCookie;
    function WithMaxAge(const ASeconds: Int64): TSetCookie;
    function WithHttpOnly(const AHttpOnly: Boolean): TSetCookie;
    function WithSecure(const ASecure: Boolean): TSetCookie;
    function WithSameSite(const ASameSite: TSameSite): TSetCookie;
    { Produce the Set-Cookie header value string }
    function ToString: string;
  end;

{ Parse the Cookie header value into name-value pairs.
  Input: 'name1=value1; name2=value2'
  Handles whitespace around names/values per RFC 6265 Section 5.4. }
function ParseCookies(const AHeaderValue: string): TRequestCookies;

{ Build a Set-Cookie header value string from a TSetCookie record. }
function BuildSetCookie(const ACookie: TSetCookie): string;

{ Create a TSetCookie with name and value. }
function MakeCookie(const AName, AValue: string): TSetCookie;

{ Parse a single 'name=value' pair (for use outside Cookie header context). }
function ParseSingleCookie(const AStr: string; out AName, AValue: string): Boolean;

{ Minimal RFC 6265 client cookie jar.
   StoreFromResponse absorbs Set-Cookie; CookieHeaderFor builds Cookie for a URL. }
function NewHttpCookieJar: IHttpCookieJar;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.sync;

const
  { Maximum number of cookies to parse from a single Cookie header.
    Prevents memory exhaustion from malicious headers with thousands of pairs. }
  MAX_COOKIE_COUNT = 512;

{ RFC 6265 §4.1.1: Cookie name must be a valid token (no control chars,
  no separators).  Reject names containing characters that could inject
  additional Set-Cookie attributes or split HTTP headers. }
function IsValidCookieName(const S: string): Boolean;
var
  I: SizeInt;
begin
  if Length(S) = 0 then
    Exit(False);
  for I := 1 to Length(S) do
  begin
    if Ord(S[I]) > 126 then
      Exit(False);
    case S[I] of
      #0..#31, #127, ' ', ';', ',', '"', '\', '(', ')', '<', '>',
      '@', ':', '/', '[', ']', '?', '=', '{', '}':
        Exit(False);
    end;
  end;
  Result := True;
end;

{ RFC 6265 §4.1.1: Cookie value (unquoted) must not contain control
  characters, spaces, commas, semicolons, or backslashes. }
function IsValidCookieValue(const S: string): Boolean;
var
  I: SizeInt;
begin
  for I := 1 to Length(S) do
  begin
    if Ord(S[I]) > 126 then
      Exit(False);
    case S[I] of
      #0..#31, #127, ' ', ';', ',', '"', '\':
        Exit(False);
    end;
  end;
  Result := True;
end;

{ RFC 6265 §4.1.1: Set-Cookie attribute values must not contain CTLs
  or semicolons to prevent attribute injection. Spaces are allowed
  since date values (Expires) contain them. }
function IsValidCookieAttrValue(const S: string): Boolean;
var
  I: SizeInt;
begin
  for I := 1 to Length(S) do
  begin
    if Ord(S[I]) > 126 then
      Exit(False);
    case S[I] of
      #0..#31, #127, ';':
        Exit(False);
    end;
  end;
  Result := True;
end;

{ ParseCookies }

function ParseCookies(const AHeaderValue: string): TRequestCookies;
var
  LLen, LI, LStart, LCount, LJ: SizeInt;
  LName, LValue: string;
  LEqPos: SizeInt;
begin
  Result := Default(TRequestCookies);
  LLen := Length(AHeaderValue);
  if LLen = 0 then
  begin
    SetLength(Result.FPairs, 0);
    Exit;
  end;

  { First pass: count pairs (capped to prevent memory exhaustion) }
  LCount := 0;
  LI := 1;
  while LI <= LLen do
  begin
    { Skip whitespace }
    while (LI <= LLen) and (AHeaderValue[LI] = ' ') do
      Inc(LI);
    if LI > LLen then Break;
    Inc(LCount);
    if LCount >= MAX_COOKIE_COUNT then Break;
    { Skip to next ';' }
    while (LI <= LLen) and (AHeaderValue[LI] <> ';') do
      Inc(LI);
    if LI <= LLen then
      Inc(LI); { skip ';' }
  end;

  SetLength(Result.FPairs, LCount);
  if LCount = 0 then Exit;

  { Second pass: extract pairs }
  LCount := 0;
  LI := 1;
  while LI <= LLen do
  begin
    { Skip whitespace }
    while (LI <= LLen) and (AHeaderValue[LI] = ' ') do
      Inc(LI);
    if LI > LLen then Break;

    LStart := LI;
    while (LI <= LLen) and (AHeaderValue[LI] <> ';') do
      Inc(LI);

    { Extract name=value from LStart..LI-1 }
    LEqPos := 0;
    LJ := LStart;
    while LJ < LI do
    begin
      if AHeaderValue[LJ] = '=' then
      begin
        LEqPos := LJ;
        Break;
      end;
      Inc(LJ);
    end;

    if LEqPos > 0 then
    begin
      LName := Trim(Copy(AHeaderValue, LStart, LEqPos - LStart));
      LValue := Trim(Copy(AHeaderValue, LEqPos + 1, LI - LEqPos - 1));
    end
    else
    begin
      LName := Trim(Copy(AHeaderValue, LStart, LI - LStart));
      LValue := '';
    end;

    { Strip surrounding quotes from value }
    if (Length(LValue) >= 2) and (LValue[1] = '"') and (LValue[Length(LValue)] = '"') then
      LValue := Copy(LValue, 2, Length(LValue) - 2);

    if LName <> '' then
    begin
      if LCount >= MAX_COOKIE_COUNT then
        Break;
      Result.FPairs[LCount].Name := LName;
      Result.FPairs[LCount].Value := LValue;
      Inc(LCount);
    end;

    if LI <= LLen then
      Inc(LI); { skip ';' }
  end;

  SetLength(Result.FPairs, LCount);
end;

{ TRequestCookies }

function TRequestCookies.Get(const AName: string): string;
var
  LI: Int32;
begin
  for LI := 0 to High(FPairs) do
    if FPairs[LI].Name = AName then
      Exit(FPairs[LI].Value);
  Result := '';
end;

function TRequestCookies.Has(const AName: string): Boolean;
var
  LI: Int32;
begin
  for LI := 0 to High(FPairs) do
    if FPairs[LI].Name = AName then
      Exit(True);
  Result := False;
end;

function TRequestCookies.Count: Int32;
begin
  Result := Length(FPairs);
end;

procedure TRequestCookies.GetPair(AIndex: Int32; out AName, AValue: string);
begin
  if (AIndex < 0) or (AIndex > High(FPairs)) then
  begin
    AName := '';
    AValue := '';
    Exit;
  end;
  AName := FPairs[AIndex].Name;
  AValue := FPairs[AIndex].Value;
end;

{ TSetCookie }

function TSetCookie.WithDomain(const ADomain: string): TSetCookie;
begin
  Result := Self;
  Result.Domain := ADomain;
end;

function TSetCookie.WithPath(const APath: string): TSetCookie;
begin
  Result := Self;
  Result.Path := APath;
end;

function TSetCookie.WithExpires(const AExpires: string): TSetCookie;
begin
  Result := Self;
  Result.Expires := AExpires;
end;

function TSetCookie.WithMaxAge(const ASeconds: Int64): TSetCookie;
begin
  Result := Self;
  Result.MaxAge := ASeconds;
end;

function TSetCookie.WithHttpOnly(const AHttpOnly: Boolean): TSetCookie;
begin
  Result := Self;
  Result.HttpOnly := AHttpOnly;
end;

function TSetCookie.WithSecure(const ASecure: Boolean): TSetCookie;
begin
  Result := Self;
  Result.Secure := ASecure;
end;

function TSetCookie.WithSameSite(const ASameSite: TSameSite): TSetCookie;
begin
  Result := Self;
  Result.SameSite := ASameSite;
  Result.HasSameSite := True;
end;

function TSetCookie.ToString: string;
begin
  Result := BuildSetCookie(Self);
end;

{ BuildSetCookie }

function BuildSetCookie(const ACookie: TSetCookie): string;
var
  LResult: string;
begin
  { Validate all fields to prevent header injection }
  if not IsValidCookieName(ACookie.Name) then
    raise ECore.Create('Invalid cookie name: contains forbidden characters');
  if not IsValidCookieValue(ACookie.Value) then
    raise ECore.Create('Invalid cookie value: contains forbidden characters');
  if (ACookie.Domain <> '') and (not IsValidCookieAttrValue(ACookie.Domain)) then
    raise ECore.Create('Invalid cookie domain: contains forbidden characters');
  if (ACookie.Path <> '') and (not IsValidCookieAttrValue(ACookie.Path)) then
    raise ECore.Create('Invalid cookie path: contains forbidden characters');
  if (ACookie.Expires <> '') and (not IsValidCookieAttrValue(ACookie.Expires)) then
    raise ECore.Create('Invalid cookie expires: contains forbidden characters');

  LResult := ACookie.Name + '=' + ACookie.Value;

  if ACookie.Domain <> '' then
    LResult := LResult + '; Domain=' + ACookie.Domain;

  if ACookie.Path <> '' then
    LResult := LResult + '; Path=' + ACookie.Path
  else
    LResult := LResult + '; Path=/';

  if ACookie.Expires <> '' then
    LResult := LResult + '; Expires=' + ACookie.Expires;

  if ACookie.MaxAge >= 0 then
    LResult := LResult + '; Max-Age=' + IntToStr(ACookie.MaxAge);

  if ACookie.HasSameSite then
    case ACookie.SameSite of
      ssStrict: LResult := LResult + '; SameSite=Strict';
      ssLax:    LResult := LResult + '; SameSite=Lax';
      ssNone:   LResult := LResult + '; SameSite=None';
    end;

  if ACookie.Secure then
    LResult := LResult + '; Secure';

  if ACookie.HttpOnly then
    LResult := LResult + '; HttpOnly';

  Result := LResult;
end;

{ MakeCookie }

function MakeCookie(const AName, AValue: string): TSetCookie;
begin
  if not IsValidCookieName(AName) then
    raise ECore.Create('Invalid cookie name: contains forbidden characters');
  if not IsValidCookieValue(AValue) then
    raise ECore.Create('Invalid cookie value: contains forbidden characters');
  Result := Default(TSetCookie);
  Result.Name := AName;
  Result.Value := AValue;
  Result.MaxAge := -1;
  Result.Path := '/';
end;

{ ParseSingleCookie }

function ParseSingleCookie(const AStr: string; out AName, AValue: string): Boolean;
var
  LEqPos: SizeInt;
begin
  LEqPos := Pos('=', AStr);
  if LEqPos > 0 then
  begin
    AName := Trim(Copy(AStr, 1, LEqPos - 1));
    AValue := Trim(Copy(AStr, LEqPos + 1, MaxInt));
    Result := AName <> '';
  end
  else
  begin
    AName := Trim(AStr);
    AValue := '';
    Result := AName <> '';
  end;
end;

{ IHttpCookieJar — minimal in-memory jar }

type
  TStoredCookie = record
    Name: string;
    Value: string;
    Domain: string;
    Path: string;
    Secure: Boolean;
    HostOnly: Boolean;
  end;

  THttpCookieJar = class(TInterfacedObject, IHttpCookieJar)
  private
    FLock: IMutex;
    FItems: array of TStoredCookie;
    function DomainMatches(const ACookieDomain, AHost: string;
      const AHostOnly: Boolean): Boolean;
    function PathMatches(const ACookiePath, ARequestPath: string): Boolean;
    procedure Upsert(const AItem: TStoredCookie);
  public
    constructor Create;
    destructor Destroy; override;
    procedure StoreFromResponse(const AUrl: TUrl; const AHeaders: IHttpHeaders);
    function CookieHeaderFor(const AUrl: TUrl): string;
    procedure Clear;
  end;

function LowerAscii(const S: string): string;
var
  LI: SizeInt;
begin
  Result := S;
  for LI := 1 to Length(Result) do
    if (Result[LI] >= 'A') and (Result[LI] <= 'Z') then
      Result[LI] := Char(Ord(Result[LI]) + 32);
end;

function TrimSpaces(const S: string): string;
var
  LStart, LEnd: SizeInt;
begin
  LStart := 1;
  LEnd := Length(S);
  while (LStart <= LEnd) and (S[LStart] = ' ') do
    Inc(LStart);
  while (LEnd >= LStart) and (S[LEnd] = ' ') do
    Dec(LEnd);
  if LEnd < LStart then
    Result := ''
  else
    Result := System.Copy(S, LStart, LEnd - LStart + 1);
end;

function ParseSetCookieLine(const AHeader: string; const ARequestUrl: TUrl;
  out AItem: TStoredCookie): Boolean;
var
  LPos, LStart, LLen, LEq: SizeInt;
  LPart, LAttr, LVal: string;
  LFirst: Boolean;
begin
  Result := False;
  AItem := Default(TStoredCookie);
  LLen := Length(AHeader);
  if LLen = 0 then
    Exit;
  LFirst := True;
  LStart := 1;
  LPos := 1;
  while LPos <= LLen + 1 do
  begin
    if (LPos > LLen) or (AHeader[LPos] = ';') then
    begin
      LPart := TrimSpaces(System.Copy(AHeader, LStart, LPos - LStart));
      if LPart <> '' then
      begin
        if LFirst then
        begin
          LEq := Pos('=', LPart);
          if LEq <= 0 then
            Exit(False);
          AItem.Name := TrimSpaces(System.Copy(LPart, 1, LEq - 1));
          AItem.Value := System.Copy(LPart, LEq + 1, MaxInt);
          if AItem.Name = '' then
            Exit(False);
          LFirst := False;
        end
        else
        begin
          LEq := Pos('=', LPart);
          if LEq > 0 then
          begin
            LAttr := LowerAscii(TrimSpaces(System.Copy(LPart, 1, LEq - 1)));
            LVal := TrimSpaces(System.Copy(LPart, LEq + 1, MaxInt));
          end
          else
          begin
            LAttr := LowerAscii(LPart);
            LVal := '';
          end;
          if LAttr = 'domain' then
          begin
            if (LVal <> '') and (LVal[1] = '.') then
              LVal := System.Copy(LVal, 2, MaxInt);
            AItem.Domain := LowerAscii(LVal);
            AItem.HostOnly := False;
          end
          else if LAttr = 'path' then
            AItem.Path := LVal
          else if LAttr = 'secure' then
            AItem.Secure := True;
        end;
      end;
      if LPos > LLen then
        Break;
      Inc(LPos);
      LStart := LPos;
    end
    else
      Inc(LPos);
  end;
  if AItem.Name = '' then
    Exit(False);
  if AItem.Domain = '' then
  begin
    AItem.Domain := LowerAscii(ARequestUrl.Host);
    AItem.HostOnly := True;
  end;
  if (AItem.Path = '') or (AItem.Path[1] <> '/') then
  begin
    { RFC 6265 §5.1.4 default-path }
    LPart := ARequestUrl.Path;
    if LPart = '' then
      LPart := '/';
    LEq := 0;
    for LPos := Length(LPart) downto 1 do
      if LPart[LPos] = '/' then
      begin
        LEq := LPos;
        Break;
      end;
    if LEq <= 1 then
      AItem.Path := '/'
    else
      AItem.Path := System.Copy(LPart, 1, LEq - 1);
  end;
  Result := True;
end;

constructor THttpCookieJar.Create;
begin
  inherited Create;
  FLock := Mutex;
  SetLength(FItems, 0);
end;

destructor THttpCookieJar.Destroy;
begin
  FLock := nil;
  inherited Destroy;
end;

function THttpCookieJar.DomainMatches(const ACookieDomain, AHost: string;
  const AHostOnly: Boolean): Boolean;
var
  LHost, LDomain: string;
begin
  LHost := LowerAscii(AHost);
  LDomain := LowerAscii(ACookieDomain);
  if LDomain = '' then
    Exit(False);
  if AHostOnly then
    Exit(LHost = LDomain);
  if LHost = LDomain then
    Exit(True);
  if Length(LHost) <= Length(LDomain) then
    Exit(False);
  Result := (System.Copy(LHost, Length(LHost) - Length(LDomain) + 1,
    Length(LDomain)) = LDomain) and
    (LHost[Length(LHost) - Length(LDomain)] = '.');
end;

function THttpCookieJar.PathMatches(const ACookiePath,
  ARequestPath: string): Boolean;
var
  LReq: string;
begin
  LReq := ARequestPath;
  if LReq = '' then
    LReq := '/';
  if ACookiePath = '' then
    Exit(True);
  if System.Copy(LReq, 1, Length(ACookiePath)) <> ACookiePath then
    Exit(False);
  if Length(LReq) = Length(ACookiePath) then
    Exit(True);
  if (ACookiePath[Length(ACookiePath)] = '/') or
     (LReq[Length(ACookiePath) + 1] = '/') then
    Exit(True);
  Result := False;
end;

procedure THttpCookieJar.Upsert(const AItem: TStoredCookie);
var
  LI: SizeInt;
begin
  for LI := 0 to High(FItems) do
    if (FItems[LI].Name = AItem.Name) and
       (LowerAscii(FItems[LI].Domain) = LowerAscii(AItem.Domain)) and
       (FItems[LI].Path = AItem.Path) then
    begin
      FItems[LI] := AItem;
      Exit;
    end;
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := AItem;
end;

procedure THttpCookieJar.StoreFromResponse(const AUrl: TUrl;
  const AHeaders: IHttpHeaders);
var
  LValues: TStringArray;
  LI: SizeInt;
  LItem: TStoredCookie;
begin
  if AHeaders = nil then
    Exit;
  LValues := AHeaders.GetAll('set-cookie');
  if Length(LValues) = 0 then
    Exit;
  FLock.Acquire;
  try
    for LI := Low(LValues) to High(LValues) do
      if ParseSetCookieLine(LValues[LI], AUrl, LItem) then
        Upsert(LItem);
  finally
    FLock.Release;
  end;
end;

function THttpCookieJar.CookieHeaderFor(const AUrl: TUrl): string;
var
  LI: SizeInt;
  LHost, LPath, LScheme: string;
  LSecure: Boolean;
  LFirst: Boolean;
begin
  Result := '';
  LHost := AUrl.Host;
  LPath := AUrl.Path;
  if LPath = '' then
    LPath := '/';
  LScheme := LowerAscii(AUrl.Scheme);
  LSecure := LScheme = 'https';
  LFirst := True;
  FLock.Acquire;
  try
    for LI := 0 to High(FItems) do
    begin
      if FItems[LI].Secure and (not LSecure) then
        Continue;
      if not DomainMatches(FItems[LI].Domain, LHost, FItems[LI].HostOnly) then
        Continue;
      if not PathMatches(FItems[LI].Path, LPath) then
        Continue;
      if LFirst then
        LFirst := False
      else
        Result := Result + '; ';
      Result := Result + FItems[LI].Name + '=' + FItems[LI].Value;
    end;
  finally
    FLock.Release;
  end;
end;

procedure THttpCookieJar.Clear;
begin
  FLock.Acquire;
  try
    SetLength(FItems, 0);
  finally
    FLock.Release;
  end;
end;

function NewHttpCookieJar: IHttpCookieJar;
begin
  Result := THttpCookieJar.Create;
end;

end.
