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
    class function NeedsNormalize(const AName: string): Boolean; static; inline;
    class function Normalize(const AName: string): string; static;
    class function NormalizeIfNeeded(const AName: string): string; static; inline;
    class function NormalizeParsedName(const AName: string): string; static;
    class function NormalizeParsedNameSpan(const AName: PAnsiChar;
      const ANameLen: SizeUInt): string; static;
    class function ValidateNameAndNeedsNormalize(const AName: string): Boolean; static;
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

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.encoding;

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
    raise EArgumentError.Create('HTTP headers are nil');
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
    raise EHttpError.Create('empty header name');
  Result := False;
  for LI := 1 to Length(AName) do
  begin
    if not IsHttpHeaderNameChar(AnsiChar(AName[LI])) then
      raise EHttpError.Create('invalid header name character');
    if (AName[LI] >= 'A') and (AName[LI] <= 'Z') then
      Result := True;
  end;
end;

class procedure THttpHeaders.ValidateValue(const AValue: string);
var
  LI: SizeInt;
begin
  for LI := 1 to Length(AValue) do
    if (AValue[LI] = #13) or (AValue[LI] = #10) or (AValue[LI] = #0) then
      raise EHttpError.Create('invalid header value: contains CR/LF/NUL');
end;

function THttpHeaders.FindFirst(const AName: string): Int32; inline;
var
  LNorm: string;
  LI: Int32;
begin
  for LI := 0 to FCount - 1 do
    if FEntries[LI].Name = AName then
      Exit(LI);

  if not NeedsNormalize(AName) then
    Exit(-1);

  LNorm := Normalize(AName);
  for LI := 0 to FCount - 1 do
    if FEntries[LI].Name = LNorm then
      Exit(LI);
  Result := -1;
end;

procedure THttpHeaders.SetHeader(const AName, AValue: string);
var
  LNorm: string;
  LI, LDst: Int32;
  LFound: Boolean;
begin
  if ValidateNameAndNeedsNormalize(AName) then
    LNorm := Normalize(AName)
  else
    LNorm := AName;
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
  if ValidateNameAndNeedsNormalize(AName) then
    LNorm := Normalize(AName)
  else
    LNorm := AName;
  ValidateValue(AValue);
  EnsureCapacity(FCount + 1);
  FEntries[FCount].Name := LNorm;
  FEntries[FCount].Value := AValue;
  Inc(FCount);
end;

procedure THttpHeaders.AddParsed(const AName, AValue: string);
begin
  EnsureCapacity(FCount + 1);
  FEntries[FCount].Name := NormalizeParsedName(AName);
  FEntries[FCount].Value := AValue;
  Inc(FCount);
end;

procedure THttpHeaders.AddParsedSpans(const AName: PAnsiChar;
  const ANameLen: SizeUInt; const AValue: PAnsiChar; const AValueLen: SizeUInt);
begin
  EnsureCapacity(FCount + 1);
  FEntries[FCount].Name := NormalizeParsedNameSpan(AName, ANameLen);
  if AValueLen = 0 then
    FEntries[FCount].Value := ''
  else
    SetString(FEntries[FCount].Value, AValue, AValueLen);
  Inc(FCount);
end;

function THttpHeaders.Get(const AName: string): string;
var
  LIdx: Int32;
begin
  LIdx := FindFirst(AName);
  if LIdx >= 0 then
    Result := FEntries[LIdx].Value
  else
    Result := '';
end;

function THttpHeaders.GetAll(const AName: string): TStringArray;
var
  LNorm: string;
  LI, LCount: Int32;
  LUseNormalized: Boolean;
begin
  Result := nil;
  LCount := 0;
  LUseNormalized := False;

  for LI := 0 to FCount - 1 do
    if FEntries[LI].Name = AName then
      Inc(LCount);

  if (LCount = 0) and NeedsNormalize(AName) then
  begin
    LNorm := Normalize(AName);
    LUseNormalized := True;
    for LI := 0 to FCount - 1 do
      if FEntries[LI].Name = LNorm then
        Inc(LCount);
  end;

  if LCount = 0 then
    Exit(nil);

  SetLength(Result, LCount);
  LCount := 0;
  for LI := 0 to FCount - 1 do
  begin
    if (not LUseNormalized) and (FEntries[LI].Name = AName) then
    begin
      Result[LCount] := FEntries[LI].Value;
      Inc(LCount);
    end;
    if LUseNormalized and (FEntries[LI].Name = LNorm) then
    begin
      Result[LCount] := FEntries[LI].Value;
      Inc(LCount);
    end;
  end;
end;

function THttpHeaders.Has(const AName: string): Boolean;
begin
  Result := FindFirst(AName) >= 0;
end;

procedure THttpHeaders.Remove(const AName: string);
var
  LNorm: string;
  LI, LDst: Int32;
begin
  LNorm := NormalizeIfNeeded(AName);
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
    raise EArgumentError.Create('HTTP header iterator is nil');

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

end.
