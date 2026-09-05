unit nextpas.core.http.headers;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  THttpHeaders = class(TInterfacedObject, IHttpHeaders)
  private
    type
      THeaderEntry = record
        Name: string;   // stored in canonical form (lowercase)
        Value: string;
      end;
    var
      FEntries: array of THeaderEntry;
      FCount: Int32;
    procedure ClearEntries(const AFrom, AToExclusive: Int32);
    procedure EnsureCapacity(const ARequired: Int32);
    function FindFirst(const AName: string): Int32; inline;
    function FindFirstNormalized(const ANorm: string): Int32; inline;
    { AQuery may be mixed-case; stored names are canonical lowercase. No alloc. }
    function FindFirstEqualFold(const AQuery: string): Int32; inline;
    class function NeedsNormalize(const AName: string): Boolean; static; inline;
    class function Normalize(const AName: string): string; static;
    class function NormalizeIfNeeded(const AName: string): string; static; inline;
    class function NormalizeParsedName(const AName: string): string; static;
    class function NormalizeParsedNameSpan(const AName: PAnsiChar;
      const ANameLen: SizeUInt): string; static;
    class function ValidateNameAndNeedsNormalize(const AName: string): Boolean; static;
    { Single pass: token-char validate + case-fold. Lowercase names share AName
      (no alloc); mixed/upper builds canonical form while validating. }
    class procedure ValidateAndNormalizeName(const AName: string;
      out ANorm: string); static;
    class procedure ValidateValue(const AValue: string); static;
  public
    procedure SetHeader(const AName, AValue: string);
    procedure Add(const AName, AValue: string);
    // Trusted parser path: name/value syntax has already been validated.
    procedure AddParsed(const AName, AValue: string);
    procedure AddParsedSpans(const AName: PAnsiChar; const ANameLen: SizeUInt;
      const AValue: PAnsiChar; const AValueLen: SizeUInt);
    function Get(const AName: string): string;
    function GetAll(const AName: string): TStringArray;
    function Has(const AName: string): Boolean;
    procedure Remove(const AName: string);
    procedure Clear;
    function Count: Int32;
    procedure ForEach(const ACallback: THeaderIterator);
    function Clone: IHttpHeaders;
  end;

function NewHttpHeaders: IHttpHeaders;
function IsHttpHeaderNameChar(const AChar: AnsiChar): Boolean;
procedure SetBasicAuth(const AHeaders: IHttpHeaders;
  const AUsername, APassword: string);
procedure SetBearerAuth(const AHeaders: IHttpHeaders; const AToken: string);
{** @desc Parse server-side Authorization header ('Bearer <token>', case-insensitive
   scheme, surrounding whitespace tolerated). True + AToken on success;
   False + '' on empty/malformed input. }
function TryParseBearerToken(const AAuthHeader: string;
  out AToken: string): Boolean;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.encoding,
  nextpas.core.text.conv;

function HeaderBytes(const AValue: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if AValue <> '' then
    Move(AValue[1], Result[0], Length(AValue));
end;

function IsHttpHeaderNameChar(const AChar: AnsiChar): Boolean;
begin
  Result :=
    ((AChar >= 'A') and (AChar <= 'Z')) or
    ((AChar >= 'a') and (AChar <= 'z')) or
    ((AChar >= '0') and (AChar <= '9')) or
    (AChar in ['!', '#', '$', '%', '&', '''', '*', '+', '-', '.', '^',
      '_', '`', '|', '~']);
end;

procedure RequireHeaders(const AHeaders: IHttpHeaders);
begin
  if AHeaders = nil then
    raise EHttpError.Create(hekArgument, 'HTTP headers are nil');
end;

{ THttpHeaders }

procedure THttpHeaders.ClearEntries(const AFrom, AToExclusive: Int32);
var
  LI: Int32;
begin
  for LI := AFrom to AToExclusive - 1 do
  begin
    FEntries[LI].Name := '';
    FEntries[LI].Value := '';
  end;
end;

procedure THttpHeaders.EnsureCapacity(const ARequired: Int32);
var
  LNewCapacity: Int32;
begin
  if Length(FEntries) >= ARequired then
    Exit;

  LNewCapacity := Length(FEntries);
  if LNewCapacity < 8 then
    LNewCapacity := 8;
  while LNewCapacity < ARequired do
    LNewCapacity := LNewCapacity * 2;
  SetLength(FEntries, LNewCapacity);
end;

class function THttpHeaders.NeedsNormalize(const AName: string): Boolean; inline;
var
  LI: Int32;
begin
  for LI := 1 to Length(AName) do
    if (AName[LI] >= 'A') and (AName[LI] <= 'Z') then
      Exit(True);
  Result := False;
end;

class function THttpHeaders.Normalize(const AName: string): string;
var
  LI: Int32;
begin
  Result := AName;
  for LI := 1 to Length(Result) do
    if (Result[LI] >= 'A') and (Result[LI] <= 'Z') then
      Result[LI] := Chr(Ord(Result[LI]) + 32);
end;

class function THttpHeaders.NormalizeIfNeeded(const AName: string): string; inline;
begin
  if NeedsNormalize(AName) then
    Result := Normalize(AName)
  else
    Result := AName;
end;

class function THttpHeaders.NormalizeParsedName(const AName: string): string;
var
  LI: Int32;
begin
  Result := AName;
  for LI := 1 to Length(Result) do
    if (Result[LI] >= 'A') and (Result[LI] <= 'Z') then
      Result[LI] := Chr(Ord(Result[LI]) + 32);
end;

class function THttpHeaders.NormalizeParsedNameSpan(const AName: PAnsiChar;
  const ANameLen: SizeUInt): string;
var
  LI: SizeUInt;
  LCh: AnsiChar;
begin
  SetLength(Result, SizeInt(ANameLen));
  if ANameLen = 0 then
    Exit;
  for LI := 0 to ANameLen - 1 do
  begin
    LCh := AName[LI];
    if (LCh >= 'A') and (LCh <= 'Z') then
      Result[SizeInt(LI) + 1] := Chr(Ord(LCh) + 32)
    else
      Result[SizeInt(LI) + 1] := LCh;
  end;
end;

class function THttpHeaders.ValidateNameAndNeedsNormalize(
  const AName: string): Boolean;
var
  LI: SizeInt;
begin
  if AName = '' then
    raise EHttpError.Create(hekParse, 'empty header name');
  Result := False;
  for LI := 1 to Length(AName) do
  begin
    if not IsHttpHeaderNameChar(AnsiChar(AName[LI])) then
      raise EHttpError.Create(hekParse, 'invalid header name character');
    if (AName[LI] >= 'A') and (AName[LI] <= 'Z') then
      Result := True;
  end;
end;

class procedure THttpHeaders.ValidateAndNormalizeName(const AName: string;
  out ANorm: string);
var
  LI, LLen: SizeInt;
  LCh: AnsiChar;
begin
  LLen := Length(AName);
  if LLen = 0 then
    raise EHttpError.Create(hekParse, 'empty header name');
  LI := 1;
  while LI <= LLen do
  begin
    LCh := AnsiChar(AName[LI]);
    if not IsHttpHeaderNameChar(LCh) then
      raise EHttpError.Create(hekParse, 'invalid header name character');
    if (LCh >= 'A') and (LCh <= 'Z') then
    begin
      { First uppercase: allocate canonical form, copy validated prefix, fold
        this char, then finish the name in the same pass. }
      SetLength(ANorm, LLen);
      if LI > 1 then
        Move(AName[1], ANorm[1], SizeUInt(LI - 1));
      ANorm[LI] := Chr(Ord(LCh) + 32);
      Inc(LI);
      while LI <= LLen do
      begin
        LCh := AnsiChar(AName[LI]);
        if not IsHttpHeaderNameChar(LCh) then
          raise EHttpError.Create(hekParse, 'invalid header name character');
        if (LCh >= 'A') and (LCh <= 'Z') then
          ANorm[LI] := Chr(Ord(LCh) + 32)
        else
          ANorm[LI] := Char(LCh);
        Inc(LI);
      end;
      Exit;
    end;
    Inc(LI);
  end;
  ANorm := AName;
end;

{ RFC 9110 §5.5: Field value components MUST NOT include CR or LF
  except when used within a quoted-string. HTAB (#9) is allowed.
  This implementation rejects all control chars < #32 except HTAB,
  and DEL (#127). }
class procedure THttpHeaders.ValidateValue(const AValue: string);
var
  LI: SizeInt;
begin
  for LI := 1 to Length(AValue) do
    if (((AValue[LI] < #32) and (AValue[LI] <> #9)) or
        (AValue[LI] = #127)) then
      raise EHttpError.Create(hekParse, 'invalid header value character');
end;

function THttpHeaders.FindFirst(const AName: string): Int32; inline;
var
  LNorm: string;
  LI: Int32;
begin
  { Prefer ValidateNameAndNeedsNormalize at the public boundary so name syntax
    and case-fold happen in one pass; FindFirst still normalizes for callers
    that already validated (Has/Get use the fused path below). }
  if NeedsNormalize(AName) then
    LNorm := Normalize(AName)
  else
    LNorm := AName;
  for LI := 0 to FCount - 1 do
    if FEntries[LI].Name = LNorm then
      Exit(LI);
  Result := -1;
end;

function THttpHeaders.FindFirstNormalized(const ANorm: string): Int32; inline;
var
  LI: Int32;
begin
  for LI := 0 to FCount - 1 do
    if FEntries[LI].Name = ANorm then
      Exit(LI);
  Result := -1;
end;

function THttpHeaders.FindFirstEqualFold(const AQuery: string): Int32; inline;
var
  LI, LJ, LLen: SizeInt;
  LStored: string;
  LCh: Char;
begin
  LLen := Length(AQuery);
  for LI := 0 to FCount - 1 do
  begin
    LStored := FEntries[LI].Name;
    if Length(LStored) <> LLen then
      Continue;
    LJ := 1;
    while LJ <= LLen do
    begin
      LCh := AQuery[LJ];
      if (LCh >= 'A') and (LCh <= 'Z') then
        LCh := Chr(Ord(LCh) + 32);
      if LStored[LJ] <> LCh then
        Break;
      Inc(LJ);
    end;
    if LJ > LLen then
      Exit(Int32(LI));
  end;
  Result := -1;
end;

procedure THttpHeaders.SetHeader(const AName, AValue: string);
var
  LNorm: string;
  LI, LDst: Int32;
  LFound: Boolean;
begin
  ValidateAndNormalizeName(AName, LNorm);
  ValidateValue(AValue);
  LFound := False;
  LDst := 0;
  for LI := 0 to FCount - 1 do
  begin
    if FEntries[LI].Name = LNorm then
    begin
      if not LFound then
      begin
        FEntries[LDst].Name := LNorm;
        FEntries[LDst].Value := AValue;
        Inc(LDst);
        LFound := True;
      end;
      // skip duplicates
    end
    else
    begin
      if LDst <> LI then
        FEntries[LDst] := FEntries[LI];
      Inc(LDst);
    end;
  end;
  if LFound then
  begin
    ClearEntries(LDst, FCount);
    FCount := LDst;
  end
  else
  begin
    EnsureCapacity(FCount + 1);
    FEntries[FCount].Name := LNorm;
    FEntries[FCount].Value := AValue;
    Inc(FCount);
  end;
end;

procedure THttpHeaders.Add(const AName, AValue: string);
var
  LNorm: string;
begin
  ValidateAndNormalizeName(AName, LNorm);
  ValidateValue(AValue);
  EnsureCapacity(FCount + 1);
  FEntries[FCount].Name := LNorm;
  FEntries[FCount].Value := AValue;
  Inc(FCount);
end;

procedure THttpHeaders.AddParsed(const AName, AValue: string);
var
  LLen: SizeInt;
begin
  EnsureCapacity(FCount + 1);
  FEntries[FCount].Name := NormalizeParsedName(AName);
  // Trim trailing OWS (SP/HTAB) per RFC 9110 Section 5.5
  LLen := Length(AValue);
  while (LLen > 0) and (AValue[LLen] in [' ', #9]) do
    Dec(LLen);
  if LLen = Length(AValue) then
    FEntries[FCount].Value := AValue
  else if LLen = 0 then
    FEntries[FCount].Value := ''
  else
    FEntries[FCount].Value := Copy(AValue, 1, LLen);
  Inc(FCount);
end;

procedure THttpHeaders.AddParsedSpans(const AName: PAnsiChar;
  const ANameLen: SizeUInt; const AValue: PAnsiChar; const AValueLen: SizeUInt);
var
  LTrimmedLen: SizeUInt;
begin
  EnsureCapacity(FCount + 1);
  FEntries[FCount].Name := NormalizeParsedNameSpan(AName, ANameLen);
  if AValueLen = 0 then
    FEntries[FCount].Value := ''
  else
  begin
    // Trim trailing OWS (SP/HTAB) per RFC 9110 Section 5.5
    LTrimmedLen := AValueLen;
    while (LTrimmedLen > 0) and (AValue[LTrimmedLen - 1] in [' ', #9]) do
      Dec(LTrimmedLen);
    if LTrimmedLen = 0 then
      FEntries[FCount].Value := ''
    else
      SetString(FEntries[FCount].Value, AValue, LTrimmedLen);
  end;
  Inc(FCount);
end;

function THttpHeaders.Get(const AName: string): string;
var
  LIdx: Int32;
begin
  { Lowercase path: validate once + exact match (no alloc). Mixed/upper path:
    validate once + equal-fold scan (no Normalize heap string). }
  if ValidateNameAndNeedsNormalize(AName) then
    LIdx := FindFirstEqualFold(AName)
  else
    LIdx := FindFirstNormalized(AName);
  if LIdx >= 0 then
    Result := FEntries[LIdx].Value
  else
    Result := '';
end;

function THttpHeaders.GetAll(const AName: string): TStringArray;
var
  LNorm: string;
  LI, LCount: Int32;
begin
  Result := nil;
  { Multi-value fill needs a stable canonical key; one validate+fold pass. }
  ValidateAndNormalizeName(AName, LNorm);

  LCount := 0;
  for LI := 0 to FCount - 1 do
    if FEntries[LI].Name = LNorm then
      Inc(LCount);

  if LCount = 0 then
    Exit(nil);

  SetLength(Result, LCount);
  LCount := 0;
  for LI := 0 to FCount - 1 do
    if FEntries[LI].Name = LNorm then
    begin
      Result[LCount] := FEntries[LI].Value;
      Inc(LCount);
    end;
end;

function THttpHeaders.Has(const AName: string): Boolean;
begin
  if ValidateNameAndNeedsNormalize(AName) then
    Result := FindFirstEqualFold(AName) >= 0
  else
    Result := FindFirstNormalized(AName) >= 0;
end;

procedure THttpHeaders.Remove(const AName: string);
var
  LNorm: string;
  LI, LDst: Int32;
begin
  ValidateAndNormalizeName(AName, LNorm);
  LDst := 0;
  for LI := 0 to FCount - 1 do
  begin
    if FEntries[LI].Name <> LNorm then
    begin
      if LDst <> LI then
        FEntries[LDst] := FEntries[LI];
      Inc(LDst);
    end;
  end;
  ClearEntries(LDst, FCount);
  FCount := LDst;
end;

procedure THttpHeaders.Clear;
begin
  ClearEntries(0, FCount);
  FCount := 0;
end;

function THttpHeaders.Count: Int32;
begin
  Result := FCount;
end;

procedure THttpHeaders.ForEach(const ACallback: THeaderIterator);
var
  LI: Int32;
begin
  if ACallback = nil then
    raise EHttpError.Create(hekArgument, 'HTTP header iterator is nil');

  for LI := 0 to FCount - 1 do
    ACallback(FEntries[LI].Name, FEntries[LI].Value);
end;

function THttpHeaders.Clone: IHttpHeaders;
var
  LNew: THttpHeaders;
  LI: Int32;
begin
  LNew := THttpHeaders.Create;
  SetLength(LNew.FEntries, FCount);
  LNew.FCount := FCount;
  for LI := 0 to FCount - 1 do
    LNew.FEntries[LI] := FEntries[LI];
  Result := LNew;
end;

{ Factory }

function NewHttpHeaders: IHttpHeaders;
begin
  Result := THttpHeaders.Create;
end;

procedure SetBasicAuth(const AHeaders: IHttpHeaders;
  const AUsername, APassword: string);
begin
  RequireHeaders(AHeaders);
  AHeaders.SetHeader('authorization', 'Basic ' +
    Base64Encode(HeaderBytes(AUsername + ':' + APassword)));
end;

procedure SetBearerAuth(const AHeaders: IHttpHeaders; const AToken: string);
begin
  RequireHeaders(AHeaders);
  AHeaders.SetHeader('authorization', 'Bearer ' + AToken);
end;

function TryParseBearerToken(const AAuthHeader: string;
  out AToken: string): Boolean;
var
  LAuth: string;
  LToken: string;
  LPos: SizeInt;
begin
  AToken := '';
  LAuth := Trim(AAuthHeader);
  LPos := Pos(' ', LAuth);
  if LPos <= 0 then
    Exit(False);
  if not SameText(Copy(LAuth, 1, LPos - 1), 'Bearer') then
    Exit(False);
  LToken := Trim(Copy(LAuth, LPos + 1, Length(LAuth) - LPos));
  if LToken = '' then
    Exit(False);
  AToken := LToken;
  Result := True;
end;

end.
