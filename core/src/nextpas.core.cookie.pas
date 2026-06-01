unit nextpas.core.cookie;
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.cookie.base;

type
  TCookieSameSite = nextpas.core.cookie.base.TCookieSameSite;
  TCookie = nextpas.core.cookie.base.TCookie;
  TCookieArray = nextpas.core.cookie.base.TCookieArray;
  TSetCookie = nextpas.core.cookie.base.TSetCookie;

function ParseCookieHeader(const AHeader: string): TCookieArray;
function TryParseCookieHeader(const AHeader: string; out ACookies: TCookieArray): Boolean;
function ParseSetCookieHeader(const AHeader: string): TSetCookie;
function TryParseSetCookieHeader(const AHeader: string; out ACookie: TSetCookie): Boolean;
function BuildCookieHeader(const ACookies: array of TCookie): string;
function BuildSetCookieHeader(const ACookie: TSetCookie): string;
function IsValidCookieName(const AName: string): Boolean;
function IsValidCookieValue(const AValue: string): Boolean;
function CookieOf(const AName, AValue: string): TCookie;
function TryFindCookie(const ACookies: TCookieArray; const AName: string; out AValue: string): Boolean;

implementation

{ Internal helpers }

function TrimStr(const S: string): string;
var
  LStart, LEnd: Integer;
begin
  LStart := 1;
  LEnd := Length(S);
  while (LStart <= LEnd) and (S[LStart] = ' ') do
    Inc(LStart);
  while (LEnd >= LStart) and (S[LEnd] = ' ') do
    Dec(LEnd);
  Result := Copy(S, LStart, LEnd - LStart + 1);
end;

function LowerChar(C: Char): Char; inline;
begin
  if (C >= 'A') and (C <= 'Z') then
    Result := Char(Ord(C) + 32)
  else
    Result := C;
end;

function CaseInsensitiveEqual(const A, B: string): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then
    Exit(False);
  for I := 1 to Length(A) do
    if LowerChar(A[I]) <> LowerChar(B[I]) then
      Exit(False);
  Result := True;
end;

function CookieOf(const AName, AValue: string): TCookie;
begin
  Result.Name := AName;
  Result.Value := AValue;
end;

function ParseCookieHeader(const AHeader: string): TCookieArray;
var
  LPos, LStart, LLen, LEq, LCount, LCap: Integer;
  LNameStart, LNameEnd, LValStart: Integer;
begin
  Result := nil;
  LLen := Length(AHeader);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // Pre-count semicolons to estimate capacity
  LCap := 1;
  for LPos := 1 to LLen - 1 do
    if (AHeader[LPos] = ';') and (LPos < LLen) and (AHeader[LPos + 1] = ' ') then
      Inc(LCap);
  SetLength(Result, LCap);

  LCount := 0;
  LStart := 1;
  LPos := 1;
  while LPos <= LLen + 1 do
  begin
    if (LPos > LLen) or ((LPos < LLen) and (AHeader[LPos] = ';') and (AHeader[LPos + 1] = ' ')) then
    begin
      // Pair is from LStart..LPos-1
      if LPos > LStart then
      begin
        // Trim leading spaces from name
        LNameStart := LStart;
        while (LNameStart < LPos) and (AHeader[LNameStart] = ' ') do
          Inc(LNameStart);

        // Find '='
        LEq := 0;
        for LValStart := LNameStart to LPos - 1 do
          if AHeader[LValStart] = '=' then
          begin
            LEq := LValStart;
            Break;
          end;

        if LEq > 0 then
        begin
          // Trim trailing spaces from name
          LNameEnd := LEq - 1;
          while (LNameEnd >= LNameStart) and (AHeader[LNameEnd] = ' ') do
            Dec(LNameEnd);

          if LNameEnd >= LNameStart then
          begin
            if LCount >= LCap then
            begin
              LCap := LCap * 2;
              SetLength(Result, LCap);
            end;
            Result[LCount].Name := Copy(AHeader, LNameStart, LNameEnd - LNameStart + 1);
            Result[LCount].Value := Copy(AHeader, LEq + 1, LPos - LEq - 1);
            Inc(LCount);
          end;
        end
        else
        begin
          // No '=': entire pair is name
          LNameEnd := LPos - 1;
          while (LNameEnd >= LNameStart) and (AHeader[LNameEnd] = ' ') do
            Dec(LNameEnd);
          if LNameEnd >= LNameStart then
          begin
            if LCount >= LCap then
            begin
              LCap := LCap * 2;
              SetLength(Result, LCap);
            end;
            Result[LCount].Name := Copy(AHeader, LNameStart, LNameEnd - LNameStart + 1);
            Result[LCount].Value := '';
            Inc(LCount);
          end;
        end;
      end;
      if LPos > LLen then
        Break;
      Inc(LPos, 2); { skip '; ' }
      LStart := LPos;
    end
    else
      Inc(LPos);
  end;
  SetLength(Result, LCount);
end;

function TryParseCookieHeader(const AHeader: string; out ACookies: TCookieArray): Boolean;
begin
  ACookies := ParseCookieHeader(AHeader);
  Result := Length(ACookies) > 0;
end;

function ParseSetCookieHeader(const AHeader: string): TSetCookie;
var
  LPos, LStart, LLen, LEq: Integer;
  LPart, LAttrName, LAttrVal: string;
  LFirst: Boolean;
  LIntVal: Int64;
begin
  Result := Default(TSetCookie);
  LLen := Length(AHeader);
  if LLen = 0 then
    Exit;
  LFirst := True;
  LStart := 1;
  LPos := 1;
  while LPos <= LLen + 1 do
  begin
    if (LPos > LLen) or ((LPos < LLen) and (AHeader[LPos] = ';') and (AHeader[LPos + 1] = ' ')) or
       ((LPos = LLen) and (AHeader[LPos] = ';')) then
    begin
      if (LPos > LLen) then
        LPart := Copy(AHeader, LStart, LPos - LStart)
      else
        LPart := Copy(AHeader, LStart, LPos - LStart);
      if LFirst then
      begin
        LEq := Pos('=', LPart);
        if LEq > 0 then
        begin
          Result.Name := TrimStr(Copy(LPart, 1, LEq - 1));
          Result.Value := Copy(LPart, LEq + 1, Length(LPart) - LEq);
        end
        else
        begin
          Result.Name := TrimStr(LPart);
          Result.Value := '';
        end;
        LFirst := False;
      end
      else
      begin
        LEq := Pos('=', LPart);
        if LEq > 0 then
        begin
          LAttrName := TrimStr(Copy(LPart, 1, LEq - 1));
          LAttrVal := TrimStr(Copy(LPart, LEq + 1, Length(LPart) - LEq));
        end
        else
        begin
          LAttrName := TrimStr(LPart);
          LAttrVal := '';
        end;
        if CaseInsensitiveEqual(LAttrName, 'Domain') then
          Result.Domain := LAttrVal
        else if CaseInsensitiveEqual(LAttrName, 'Path') then
          Result.Path := LAttrVal
        else if CaseInsensitiveEqual(LAttrName, 'Max-Age') then
        begin
          Val(LAttrVal, LIntVal, LEq);
          if LEq = 0 then
          begin
            Result.MaxAge := LIntVal;
            Result.HasMaxAge := True;
          end;
        end
        else if CaseInsensitiveEqual(LAttrName, 'Secure') then
          Result.Secure := True
        else if CaseInsensitiveEqual(LAttrName, 'HttpOnly') then
          Result.HttpOnly := True
        else if CaseInsensitiveEqual(LAttrName, 'SameSite') then
        begin
          if CaseInsensitiveEqual(LAttrVal, 'None') then
            Result.SameSite := cssNone
          else if CaseInsensitiveEqual(LAttrVal, 'Lax') then
            Result.SameSite := cssLax
          else if CaseInsensitiveEqual(LAttrVal, 'Strict') then
            Result.SameSite := cssStrict;
        end;
      end;
      if LPos > LLen then
        Break;
      if AHeader[LPos + 1] = ' ' then
        Inc(LPos, 2)
      else
        Inc(LPos, 1);
      LStart := LPos;
    end
    else
      Inc(LPos);
  end;
end;

function TryParseSetCookieHeader(const AHeader: string; out ACookie: TSetCookie): Boolean;
begin
  ACookie := ParseSetCookieHeader(AHeader);
  Result := ACookie.Name <> '';
end;

function IsValidCookieName(const AName: string): Boolean;
var
  I: Integer;
  C: Byte;
begin
  if AName = '' then
    Exit(False);
  for I := 1 to Length(AName) do
  begin
    C := Byte(AName[I]);
    if (C < 32) or (C = 127) or (C = Ord(' ')) or (C = Ord(#9)) or
       (C = Ord('(')) or (C = Ord(')')) or (C = Ord('<')) or (C = Ord('>')) or
       (C = Ord('@')) or (C = Ord(',')) or (C = Ord(';')) or (C = Ord(':')) or
       (C = Ord('\')) or (C = Ord('"')) or (C = Ord('/')) or (C = Ord('[')) or
       (C = Ord(']')) or (C = Ord('?')) or (C = Ord('=')) or (C = Ord('{')) or
       (C = Ord('}')) then
      Exit(False);
  end;
  Result := True;
end;

function IsValidCookieValue(const AValue: string): Boolean;
var
  I: Integer;
  C: Byte;
begin
  for I := 1 to Length(AValue) do
  begin
    C := Byte(AValue[I]);
    if (C < 32) or (C = 127) or (C = Ord(';')) or (C = Ord('\')) or
       (C = Ord('"')) or (C = Ord(',')) or (C = Ord(' ')) then
      Exit(False);
  end;
  Result := True;
end;

function BuildCookieHeader(const ACookies: array of TCookie): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ACookies) do
  begin
    if not IsValidCookieName(ACookies[I].Name) then
      raise Exception.Create('Invalid cookie name: ' + ACookies[I].Name);
    if not IsValidCookieValue(ACookies[I].Value) then
      raise Exception.Create('Invalid cookie value for: ' + ACookies[I].Name);
    if I > 0 then
      Result := Result + '; ';
    Result := Result + ACookies[I].Name + '=' + ACookies[I].Value;
  end;
end;

function BuildSetCookieHeader(const ACookie: TSetCookie): string;
var
  LAge: string;
begin
  if not IsValidCookieName(ACookie.Name) then
    raise Exception.Create('Invalid cookie name: ' + ACookie.Name);
  if not IsValidCookieValue(ACookie.Value) then
    raise Exception.Create('Invalid cookie value for: ' + ACookie.Name);
  Result := ACookie.Name + '=' + ACookie.Value;
  if ACookie.Path <> '' then
    Result := Result + '; Path=' + ACookie.Path;
  if ACookie.Domain <> '' then
    Result := Result + '; Domain=' + ACookie.Domain;
  if ACookie.HasMaxAge then
  begin
    Str(ACookie.MaxAge, LAge);
    Result := Result + '; Max-Age=' + LAge;
  end;
  if ACookie.Secure then
    Result := Result + '; Secure';
  if ACookie.HttpOnly then
    Result := Result + '; HttpOnly';
  case ACookie.SameSite of
    cssNone: Result := Result + '; SameSite=None';
    cssLax: Result := Result + '; SameSite=Lax';
    cssStrict: Result := Result + '; SameSite=Strict';
    otherwise { cssUnspecified: no attribute emitted }
  end;
end;

function TryFindCookie(const ACookies: TCookieArray; const AName: string; out AValue: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(ACookies) do
    if ACookies[I].Name = AName then
    begin
      AValue := ACookies[I].Value;
      Exit(True);
    end;
  AValue := '';
  Result := False;
end;

end.
