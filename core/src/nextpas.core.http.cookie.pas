unit nextpas.core.http.cookie;
{**
 * @desc HTTP Cookie parsing and generation (RFC 6265).
 *       Parse request Cookie header, build Set-Cookie response headers.
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
  nextpas.core.base;

type
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

implementation

uses
  nextpas.core.text.conv;

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

end.
