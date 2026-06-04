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
    function FindFirst(const AName: string): Int32;
    class function NeedsNormalize(const AName: string): Boolean; static;
    class function Normalize(const AName: string): string; static;
    class procedure ValidateName(const AName: string); static;
    class procedure ValidateValue(const AValue: string); static;
  public
    procedure Set_(const AName, AValue: string);
    procedure Add(const AName, AValue: string);
    function Get(const AName: string): string;
    function GetAll(const AName: string): TStringArray;
    function Has(const AName: string): Boolean;
    procedure Del(const AName: string);
    function Count: Int32;
    procedure ForEach(const ACallback: THeaderIterator);
    function Clone: IHttpHeaders;
  end;

function NewHttpHeaders: IHttpHeaders;

implementation

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

class function THttpHeaders.NeedsNormalize(const AName: string): Boolean;
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

class procedure THttpHeaders.ValidateName(const AName: string);
var
  LI: SizeInt;
begin
  if AName = '' then
    raise EHttpError.Create('empty header name');
  for LI := 1 to Length(AName) do
    if (Ord(AName[LI]) < 33) or (Ord(AName[LI]) > 126) or (AName[LI] = ':') then
      raise EHttpError.Create('invalid header name character');
end;

class procedure THttpHeaders.ValidateValue(const AValue: string);
var
  LI: SizeInt;
begin
  for LI := 1 to Length(AValue) do
    if (AValue[LI] = #13) or (AValue[LI] = #10) or (AValue[LI] = #0) then
      raise EHttpError.Create('invalid header value: contains CR/LF/NUL');
end;

function THttpHeaders.FindFirst(const AName: string): Int32;
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

procedure THttpHeaders.Set_(const AName, AValue: string);
var
  LNorm: string;
  LI, LDst: Int32;
  LFound: Boolean;
begin
  ValidateName(AName);
  ValidateValue(AValue);
  LNorm := Normalize(AName);
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
begin
  ValidateName(AName);
  ValidateValue(AValue);
  EnsureCapacity(FCount + 1);
  FEntries[FCount].Name := Normalize(AName);
  FEntries[FCount].Value := AValue;
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

procedure THttpHeaders.Del(const AName: string);
var
  LNorm: string;
  LI, LDst: Int32;
begin
  LNorm := Normalize(AName);
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

function THttpHeaders.Count: Int32;
begin
  Result := FCount;
end;

procedure THttpHeaders.ForEach(const ACallback: THeaderIterator);
var
  LI: Int32;
begin
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

end.
