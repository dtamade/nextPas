unit nextpas.core.time.iso8601;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.date,
  nextpas.core.time.timeofday,
  nextpas.core.time.datetime;

function ParseISO8601Date(const AStr: string): TDate;
function TryParseISO8601Date(const AStr: string; out ADate: TDate): Boolean;

function ParseISO8601Time(const AStr: string): TTimeOfDay;
function TryParseISO8601Time(const AStr: string; out ATime: TTimeOfDay): Boolean;

function ParseISO8601DateTime(const AStr: string): TNaiveDateTime;
function TryParseISO8601DateTime(const AStr: string; out ADT: TNaiveDateTime): Boolean;

implementation

uses
  SysUtils;

function TryParseISO8601Date(const AStr: string; out ADate: TDate): Boolean;
var
  LY, LM, LD: Integer;
begin
  Result := False;
  if Length(AStr) < 10 then Exit;
  if (AStr[5] <> '-') or (AStr[8] <> '-') then Exit;
  if not TryStrToInt(Copy(AStr, 1, 4), LY) then Exit;
  if not TryStrToInt(Copy(AStr, 6, 2), LM) then Exit;
  if not TryStrToInt(Copy(AStr, 9, 2), LD) then Exit;
  Result := TDate.TryCreate(LY, LM, LD, ADate);
end;

function ParseISO8601Date(const AStr: string): TDate;
begin
  if not TryParseISO8601Date(AStr, Result) then
    raise Exception.CreateFmt('Invalid ISO 8601 date: %s', [AStr]);
end;

function TryParseISO8601Time(const AStr: string; out ATime: TTimeOfDay): Boolean;
var
  LH, LMin, LSec, LNano: Integer;
  LFrac: string;
  LFracLen: Integer;
  LDotPos: Integer;
begin
  Result := False;
  if Length(AStr) < 8 then Exit;
  if (AStr[3] <> ':') or (AStr[6] <> ':') then Exit;
  if not TryStrToInt(Copy(AStr, 1, 2), LH) then Exit;
  if not TryStrToInt(Copy(AStr, 4, 2), LMin) then Exit;
  if not TryStrToInt(Copy(AStr, 7, 2), LSec) then Exit;

  LNano := 0;
  if Length(AStr) > 8 then
  begin
    LDotPos := 9;
    if AStr[LDotPos] <> '.' then Exit;
    LFrac := Copy(AStr, LDotPos + 1, Length(AStr) - LDotPos);
    LFracLen := Length(LFrac);
    if (LFracLen < 1) or (LFracLen > 9) then Exit;
    if not TryStrToInt(LFrac, LNano) then Exit;
    while LFracLen < 9 do
    begin
      LNano := LNano * 10;
      Inc(LFracLen);
    end;
  end;

  Result := TTimeOfDay.TryCreate(LH, LMin, LSec, LNano, ATime);
end;

function ParseISO8601Time(const AStr: string): TTimeOfDay;
begin
  if not TryParseISO8601Time(AStr, Result) then
    raise Exception.CreateFmt('Invalid ISO 8601 time: %s', [AStr]);
end;

function TryParseISO8601DateTime(const AStr: string; out ADT: TNaiveDateTime): Boolean;
var
  LTPos: Integer;
  LDateStr, LTimeStr: string;
  LDate: TDate;
  LTime: TTimeOfDay;
begin
  Result := False;
  LTPos := Pos('T', AStr);
  if LTPos = 0 then Exit;

  LDateStr := Copy(AStr, 1, LTPos - 1);
  LTimeStr := Copy(AStr, LTPos + 1, Length(AStr) - LTPos);

  if not TryParseISO8601Date(LDateStr, LDate) then Exit;
  if not TryParseISO8601Time(LTimeStr, LTime) then Exit;

  ADT := TNaiveDateTime.FromDateAndTime(LDate, LTime);
  Result := True;
end;

function ParseISO8601DateTime(const AStr: string): TNaiveDateTime;
begin
  if not TryParseISO8601DateTime(AStr, Result) then
    raise Exception.CreateFmt('Invalid ISO 8601 datetime: %s', [AStr]);
end;

end.
