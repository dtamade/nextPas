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
  nextpas.core.time,
  nextpas.core.time.datetime,
  nextpas.core.time.offsetdatetime,
  nextpas.core.time.timezone,
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
    { Unix seconds expiry; -1 = session (no expiry eviction). }
    ExpiresAt: Int64;
  end;

  THttpCookieJar = class(TInterfacedObject, IHttpCookieJar)
  private
    FLock: IMutex;
    FItems: array of TStoredCookie;
    function DomainMatches(const ACookieDomain, AHost: string;
      const AHostOnly: Boolean): Boolean;
    function PathMatches(const ACookiePath, ARequestPath: string): Boolean;
    procedure Upsert(const AItem: TStoredCookie);
    procedure EvictExpiredLocked(const ANowUnix: Int64);
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

function CookieNowUnix: Int64;
begin
  Result := DateTimeToUnix(DateTimeUtcNow);
end;

function ParseInt64Digits(const AStr: string; out AValue: Int64): Boolean;
var
  LI: SizeInt;
  LNeg: Boolean;
  LDigit: Int64;
begin
  Result := False;
  AValue := 0;
  if AStr = '' then
    Exit;
  LI := 1;
  LNeg := False;
  if AStr[1] = '-' then
  begin
    LNeg := True;
    LI := 2;
    if Length(AStr) < 2 then
      Exit;
  end;
  while LI <= Length(AStr) do
  begin
    if (AStr[LI] < '0') or (AStr[LI] > '9') then
      Exit;
    LDigit := Ord(AStr[LI]) - Ord('0');
    if AValue > (High(Int64) - LDigit) div 10 then
      Exit;
    AValue := AValue * 10 + LDigit;
    Inc(LI);
  end;
  if LNeg then
    AValue := -AValue;
  Result := True;
end;

function ParseCookieHttpDate(const ADate: string): Int64;
{ Accepts IMF-fix preferred form: "Sun, 06 Nov 1994 08:49:37 GMT". Returns 0 on fail. }
const
  MONTH_NAMES: array[1..12] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
var
  LLen, LPos, LMonth, LI: Integer;
  LDay, LYear, LHour, LMinute, LSecond: Integer;
  LMonthStr: string;
  LDT: TOffsetDateTime;
begin
  Result := 0;
  LLen := Length(ADate);
  if LLen < 29 then
    Exit;
  { IMF-fix preferred: "Sun, 06 Nov 1994 08:49:37 GMT"
    Fixed layout after weekday: SP DD SP Mon SP YYYY SP HH:MM:SS SP GMT }
  LPos := 6; { first digit of DD }
  if (LPos + 1 > LLen) then
    Exit;
  if (ADate[LPos] < '0') or (ADate[LPos] > '9') or
     (ADate[LPos + 1] < '0') or (ADate[LPos + 1] > '9') then
    Exit;
  LDay := (Ord(ADate[LPos]) - Ord('0')) * 10 +
    (Ord(ADate[LPos + 1]) - Ord('0'));
  Inc(LPos, 3); { skip DD and following SP -> Mon }
  if (LPos + 2 > LLen) then
    Exit;
  LMonthStr := System.Copy(ADate, LPos, 3);
  LMonth := 0;
  for LI := 1 to 12 do
    if LMonthStr = MONTH_NAMES[LI] then
    begin
      LMonth := LI;
      Break;
    end;
  if LMonth = 0 then
    Exit;
  Inc(LPos, 4); { Mon + SP -> YYYY }
  if (LPos + 3 > LLen) then
    Exit;
  LYear := (Ord(ADate[LPos]) - Ord('0')) * 1000
    + (Ord(ADate[LPos + 1]) - Ord('0')) * 100
    + (Ord(ADate[LPos + 2]) - Ord('0')) * 10
    + (Ord(ADate[LPos + 3]) - Ord('0'));
  Inc(LPos, 5); { YYYY + SP -> HH }
  if (LPos + 7 > LLen) then
    Exit;
  LHour := (Ord(ADate[LPos]) - Ord('0')) * 10 +
    (Ord(ADate[LPos + 1]) - Ord('0'));
  LMinute := (Ord(ADate[LPos + 3]) - Ord('0')) * 10 +
    (Ord(ADate[LPos + 4]) - Ord('0'));
  LSecond := (Ord(ADate[LPos + 6]) - Ord('0')) * 10 +
    (Ord(ADate[LPos + 7]) - Ord('0'));
  try
    LDT := TOffsetDateTime.Create(
      TNaiveDateTime.Create(LYear, LMonth, LDay, LHour, LMinute, LSecond),
      TUtcOffset.UTC);
    Result := LDT.ToUnixSeconds;
  except
    Result := 0;
  end;
end;

function ParseSetCookieLine(const AHeader: string; const ARequestUrl: TUrl;
  out AItem: TStoredCookie): Boolean;
var
  LPos, LStart, LLen, LEq: SizeInt;
  LPart, LAttr, LVal: string;
  LFirst: Boolean;
  LMaxAge: Int64;
  LExpiresAt: Int64;
  LHasMaxAge: Boolean;
  LHasExpires: Boolean;
  LNow: Int64;
begin
  Result := False;
  AItem := Default(TStoredCookie);
  AItem.ExpiresAt := -1;
  LHasMaxAge := False;
  LHasExpires := False;
  LExpiresAt := 0;
  LMaxAge := 0;
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
            AItem.Secure := True
          else if LAttr = 'max-age' then
          begin
            if ParseInt64Digits(LVal, LMaxAge) then
              LHasMaxAge := True;
          end
          else if LAttr = 'expires' then
          begin
            LExpiresAt := ParseCookieHttpDate(LVal);
            if LExpiresAt > 0 then
              LHasExpires := True;
          end;
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
  { RFC 6265: Max-Age preferred over Expires. Max-Age <= 0 → expire immediately. }
  LNow := CookieNowUnix;
  if LHasMaxAge then
  begin
    if LMaxAge <= 0 then
      AItem.ExpiresAt := LNow - 1
    else
      AItem.ExpiresAt := LNow + LMaxAge;
  end
  else if LHasExpires then
    AItem.ExpiresAt := LExpiresAt;
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

procedure THttpCookieJar.EvictExpiredLocked(const ANowUnix: Int64);
var
  LI, LWrite: SizeInt;
begin
  LWrite := 0;
  for LI := 0 to High(FItems) do
  begin
    if (FItems[LI].ExpiresAt >= 0) and (FItems[LI].ExpiresAt <= ANowUnix) then
      Continue;
    if LWrite <> LI then
      FItems[LWrite] := FItems[LI];
    Inc(LWrite);
  end;
  if LWrite <> Length(FItems) then
    SetLength(FItems, LWrite);
end;

procedure THttpCookieJar.Upsert(const AItem: TStoredCookie);
var
  LI: SizeInt;
  LNow: Int64;
begin
  LNow := CookieNowUnix;
  { Expired / Max-Age=0 cookies delete any existing match. }
  if (AItem.ExpiresAt >= 0) and (AItem.ExpiresAt <= LNow) then
  begin
    for LI := High(FItems) downto 0 do
      if (FItems[LI].Name = AItem.Name) and
         (LowerAscii(FItems[LI].Domain) = LowerAscii(AItem.Domain)) and
         (FItems[LI].Path = AItem.Path) then
      begin
        if LI < High(FItems) then
          FItems[LI] := FItems[High(FItems)];
        SetLength(FItems, Length(FItems) - 1);
      end;
    Exit;
  end;
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
    EvictExpiredLocked(CookieNowUnix);
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
  LNow: Int64;
begin
  Result := '';
  LHost := AUrl.Host;
  LPath := AUrl.Path;
  if LPath = '' then
    LPath := '/';
  LScheme := LowerAscii(AUrl.Scheme);
  LSecure := LScheme = 'https';
  LFirst := True;
  LNow := CookieNowUnix;
  FLock.Acquire;
  try
    EvictExpiredLocked(LNow);
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
