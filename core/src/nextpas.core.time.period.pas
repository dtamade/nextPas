unit nextpas.core.time.period;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.time.date,
  nextpas.core.time.datetime;

type
  TPeriod = record
  private
    FYears: Integer;
    FMonths: Integer;
    FDays: Integer;
  public
    class function Zero: TPeriod; static; inline;
    class function Create(AYears, AMonths, ADays: Integer): TPeriod; static;
    class function OfYears(AYears: Integer): TPeriod; static;
    class function OfMonths(AMonths: Integer): TPeriod; static;
    class function OfDays(ADays: Integer): TPeriod; static;

    class function ParseISO8601(const AStr: string): TPeriod; static;
    class function TryParseISO8601(const AStr: string; out APeriod: TPeriod): Boolean; static;

    function GetYears: Integer; inline;
    function GetMonths: Integer; inline;
    function GetDays: Integer; inline;
    function IsZero: Boolean; inline;
    function Negate: TPeriod;

    function AddTo(const ADate: TDate): TDate; overload;
    function AddTo(const ADateTime: TNaiveDateTime): TNaiveDateTime; overload;

    function ToISO8601: string;
    function ToString: string;

    class operator =(const A, B: TPeriod): Boolean; inline;
    class operator +(const A, B: TPeriod): TPeriod;
    class operator -(const A, B: TPeriod): TPeriod;
  end;

implementation

uses
  nextpas.core.text.conv;

{ TPeriod }

class function TPeriod.Zero: TPeriod;
begin
  Result.FYears := 0;
  Result.FMonths := 0;
  Result.FDays := 0;
end;

class function TPeriod.Create(AYears, AMonths, ADays: Integer): TPeriod;
begin
  Result.FYears := AYears;
  Result.FMonths := AMonths;
  Result.FDays := ADays;
end;

class function TPeriod.OfYears(AYears: Integer): TPeriod;
begin
  Result.FYears := AYears;
  Result.FMonths := 0;
  Result.FDays := 0;
end;

class function TPeriod.OfMonths(AMonths: Integer): TPeriod;
begin
  Result.FYears := 0;
  Result.FMonths := AMonths;
  Result.FDays := 0;
end;

class function TPeriod.OfDays(ADays: Integer): TPeriod;
begin
  Result.FYears := 0;
  Result.FMonths := 0;
  Result.FDays := ADays;
end;

class function TPeriod.TryParseISO8601(const AStr: string; out APeriod: TPeriod): Boolean;
var
  LPos, LLen: Integer;
  LYears, LMonths, LDays: Integer;
  LNum: Integer;
  LNeg: Boolean;
  LHasComponent: Boolean;
begin
  Result := False;
  LLen := Length(AStr);
  if (LLen < 2) or (AStr[1] <> 'P') then
    Exit;

  LPos := 2;
  LYears := 0;
  LMonths := 0;
  LDays := 0;
  LHasComponent := False;

  while LPos <= LLen do
  begin
    LNeg := False;
    if (LPos <= LLen) and (AStr[LPos] = '-') then
    begin
      LNeg := True;
      Inc(LPos);
    end;

    if (LPos > LLen) or (AStr[LPos] < '0') or (AStr[LPos] > '9') then
      Exit;

    LNum := 0;
    while (LPos <= LLen) and (AStr[LPos] >= '0') and (AStr[LPos] <= '9') do
    begin
      LNum := LNum * 10 + (Ord(AStr[LPos]) - Ord('0'));
      Inc(LPos);
    end;

    if LNeg then
      LNum := -LNum;

    if LPos > LLen then
      Exit;

    case AStr[LPos] of
      'Y': LYears := LNum;
      'M': LMonths := LNum;
      'D': LDays := LNum;
    else
      Exit;
    end;
    LHasComponent := True;
    Inc(LPos);
  end;

  if not LHasComponent then
    Exit;

  APeriod.FYears := LYears;
  APeriod.FMonths := LMonths;
  APeriod.FDays := LDays;
  Result := True;
end;

class function TPeriod.ParseISO8601(const AStr: string): TPeriod;
begin
  if not TryParseISO8601(AStr, Result) then
    raise Exception.CreateFmt('TPeriod: invalid ISO 8601 period "%s"', [AStr]);
end;

function TPeriod.GetYears: Integer;
begin
  Result := FYears;
end;

function TPeriod.GetMonths: Integer;
begin
  Result := FMonths;
end;

function TPeriod.GetDays: Integer;
begin
  Result := FDays;
end;

function TPeriod.IsZero: Boolean;
begin
  Result := (FYears = 0) and (FMonths = 0) and (FDays = 0);
end;

function TPeriod.Negate: TPeriod;
begin
  Result.FYears := -FYears;
  Result.FMonths := -FMonths;
  Result.FDays := -FDays;
end;

function TPeriod.AddTo(const ADate: TDate): TDate;
begin
  Result := ADate.AddYears(FYears);
  Result := Result.AddMonths(FMonths);
  Result := Result.AddDays(FDays);
end;

function TPeriod.AddTo(const ADateTime: TNaiveDateTime): TNaiveDateTime;
var
  LNewDate: TDate;
begin
  LNewDate := AddTo(ADateTime.GetDate);
  Result := TNaiveDateTime.FromDateAndTime(LNewDate, ADateTime.GetTime);
end;

function TPeriod.ToISO8601: string;
begin
  if IsZero then
  begin
    Result := 'P0D';
    Exit;
  end;
  Result := 'P';
  if FYears <> 0 then
    Result := Result + IntToStr(FYears) + 'Y';
  if FMonths <> 0 then
    Result := Result + IntToStr(FMonths) + 'M';
  if FDays <> 0 then
    Result := Result + IntToStr(FDays) + 'D';
end;

function TPeriod.ToString: string;
var
  LParts: string;

  procedure AppendPart(AValue: Integer; const ASingular, APlural: string);
  begin
    if AValue = 0 then Exit;
    if LParts <> '' then
      LParts := LParts + ', ';
    if (AValue = 1) or (AValue = -1) then
      LParts := LParts + IntToStr(AValue) + ' ' + ASingular
    else
      LParts := LParts + IntToStr(AValue) + ' ' + APlural;
  end;

begin
  if IsZero then
  begin
    Result := '0 days';
    Exit;
  end;
  LParts := '';
  AppendPart(FYears, 'year', 'years');
  AppendPart(FMonths, 'month', 'months');
  AppendPart(FDays, 'day', 'days');
  Result := LParts;
end;

class operator TPeriod.=(const A, B: TPeriod): Boolean;
begin
  Result := (A.FYears = B.FYears) and (A.FMonths = B.FMonths) and (A.FDays = B.FDays);
end;

class operator TPeriod.+(const A, B: TPeriod): TPeriod;
begin
  Result.FYears := A.FYears + B.FYears;
  Result.FMonths := A.FMonths + B.FMonths;
  Result.FDays := A.FDays + B.FDays;
end;

class operator TPeriod.-(const A, B: TPeriod): TPeriod;
begin
  Result.FYears := A.FYears - B.FYears;
  Result.FMonths := A.FMonths - B.FMonths;
  Result.FDays := A.FDays - B.FDays;
end;

end.
