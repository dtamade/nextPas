unit nextpas.core.time.httpdate;

{** @desc HTTP 日期编解码 — RFC 7231 §7.1.1.1 IMF-fixdate / RFC850 / ANSIC 三形态。
  L1 位置：被 http.static 与 vfs.embedded 共同复用，消除跨层重复，使
  Last-Modified 缓存可在 L2 预计算而无需依赖 L3。 }

{$I nextpas.core.settings.inc}

interface

{** @desc Format Unix timestamp as HTTP date (RFC 7231 §7.1.1.1). }
function FormatHttpDate(const AUnixTimestamp: Int64): string;
{** @desc Parse HTTP-date to Unix timestamp; accepts IMF/RFC850/ANSIC, same as Go http.ParseTime. }
function TryParseHttpDate(const ADate: string; out AUnix: Int64): Boolean;

implementation

uses
  nextpas.core.time,
  nextpas.core.time.offsetdatetime,
  nextpas.core.time.datetime,
  nextpas.core.time.date,
  nextpas.core.time.timeofday,
  nextpas.core.time.timezone,
  nextpas.core.text.conv;

const
  DAY_NAMES: array[1..7] of string = (
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  );
  MONTH_NAMES: array[1..12] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  );

function Pad2(AVal: Integer): string; inline;
begin
  if AVal < 10 then
    Result := '0' + Chr(Ord('0') + AVal)
  else
    Result := Chr(Ord('0') + AVal div 10) + Chr(Ord('0') + AVal mod 10);
end;

function FormatHttpDate(const AUnixTimestamp: Int64): string;
var
  LDT: TOffsetDateTime;
  LYear, LMonth, LDay, LHour, LMinute, LSecond: Integer;
  LDayOfWeek: Integer;
begin
  LDT := TOffsetDateTime.FromUnixSeconds(AUnixTimestamp);
  LDT := LDT.ToUtc;
  LYear := LDT.GetYear;
  LMonth := LDT.GetMonth;
  LDay := LDT.GetDay;
  LHour := LDT.GetHour;
  LMinute := LDT.GetMinute;
  LSecond := LDT.GetSecond;
  LDayOfWeek := (LDay + (13 * ((LMonth + 12 * ((14 - LMonth) div 12)) mod 12 + 1)) div 5
    + ((LYear - ((14 - LMonth) div 12)) mod 100)
    + ((LYear - ((14 - LMonth) div 12)) mod 100) div 4
    + ((LYear - ((14 - LMonth) div 12)) div 100) * 5
    + 5) mod 7;
  LDayOfWeek := ((LDayOfWeek + 6) mod 7) + 1;
  Result := DAY_NAMES[LDayOfWeek] + ', '
    + Pad2(LDay) + ' ' + MONTH_NAMES[LMonth] + ' ' + nextpas.core.text.conv.IntToStr(LYear)
    + ' ' + Pad2(LHour) + ':' + Pad2(LMinute) + ':' + Pad2(LSecond)
    + ' GMT';
end;

function ParseHttpDate(const ADate: string): Int64;
var
  LLen, LPos, LMonth, LI: Integer;
  LDay, LYear, LHour, LMinute, LSecond: Integer;
  LMonthStr: string;
  LDT: TOffsetDateTime;
begin
  Result := 0;
  LLen := Length(ADate);
  if LLen < 29 then Exit;
  LPos := 6;
  if LPos + 1 > LLen then Exit;
  if (ADate[LPos] < '0') or (ADate[LPos] > '9') or
    (ADate[LPos + 1] < '0') or (ADate[LPos + 1] > '9') then
    Exit;
  LDay := (Ord(ADate[LPos]) - Ord('0')) * 10 + (Ord(ADate[LPos + 1]) - Ord('0'));
  Inc(LPos, 3);
  if LPos + 2 > LLen then Exit;
  LMonthStr := System.Copy(ADate, LPos, 3);
  LMonth := 0;
  for LI := 1 to 12 do
    if LMonthStr = MONTH_NAMES[LI] then
    begin
      LMonth := LI;
      Break;
    end;
  if LMonth = 0 then Exit;
  Inc(LPos, 4);
  if LPos + 3 > LLen then Exit;
  if (ADate[LPos] < '0') or (ADate[LPos] > '9') then Exit;
  LYear := (Ord(ADate[LPos]) - Ord('0')) * 1000
         + (Ord(ADate[LPos + 1]) - Ord('0')) * 100
         + (Ord(ADate[LPos + 2]) - Ord('0')) * 10
         + (Ord(ADate[LPos + 3]) - Ord('0'));
  Inc(LPos, 5);
  if LPos + 7 > LLen then Exit;
  LHour := (Ord(ADate[LPos]) - Ord('0')) * 10 + (Ord(ADate[LPos + 1]) - Ord('0'));
  LMinute := (Ord(ADate[LPos + 3]) - Ord('0')) * 10 + (Ord(ADate[LPos + 4]) - Ord('0'));
  LSecond := (Ord(ADate[LPos + 6]) - Ord('0')) * 10 + (Ord(ADate[LPos + 7]) - Ord('0'));
  if (LDay < 1) or (LDay > 31) or (LMonth < 1) or (LMonth > 12) or
     (LHour > 23) or (LMinute > 59) or (LSecond > 60) then
    Exit;
  try
    LDT := TOffsetDateTime.Create(
      TNaiveDateTime.Create(LYear, LMonth, LDay, LHour, LMinute, LSecond),
      TUtcOffset.UTC);
    Result := LDT.ToUnixSeconds;
  except
    Result := 0;
  end;
end;

function ParseHttpDateFallback(const ADate: string): Int64;
var
  LDay, LMonth, LYear, LHour, LMinute, LSecond, LI, LPos: Integer;
  LMonthStr: string;
  LDT: TOffsetDateTime;
begin
  Result := 0;
  if Length(ADate) < 16 then
    Exit;
  if (ADate[7] = ',') and (ADate[11] = '-') and (ADate[15] = '-') then
  begin
    LDay := (Ord(ADate[9]) - Ord('0')) * 10 + (Ord(ADate[10]) - Ord('0'));
    LMonthStr := System.Copy(ADate, 12, 3);
    LMonth := 0;
    for LI := 1 to 12 do
      if LMonthStr = MONTH_NAMES[LI] then
      begin
        LMonth := LI;
        Break;
      end;
    if LMonth = 0 then
      Exit;
    LYear := (Ord(ADate[16]) - Ord('0')) * 10 + (Ord(ADate[17]) - Ord('0'));
    if LYear < 69 then
      LYear := 2000 + LYear
    else
      LYear := 1900 + LYear;
    LPos := 19;
  end
  else if ADate[4] = ' ' then
  begin
    LMonthStr := System.Copy(ADate, 5, 3);
    LMonth := 0;
    for LI := 1 to 12 do
      if LMonthStr = MONTH_NAMES[LI] then
      begin
        LMonth := LI;
        Break;
      end;
    if LMonth = 0 then
      Exit;
    LPos := 9;
    if (ADate[LPos] = ' ') then
    begin
      LDay := Ord(ADate[LPos + 1]) - Ord('0');
      Inc(LPos, 3);
    end
    else if (ADate[LPos] in ['0'..'9']) and (ADate[LPos + 1] in ['0'..'9']) then
    begin
      LDay := (Ord(ADate[LPos]) - Ord('0')) * 10 + (Ord(ADate[LPos + 1]) - Ord('0'));
      Inc(LPos, 3);
    end
    else
      Exit;
  end
  else
    Exit;
  if (LPos + 9 > Length(ADate)) then
    Exit;
  if (ADate[LPos + 2] <> ':') or (ADate[LPos + 5] <> ':') then
    Exit;
  LHour := (Ord(ADate[LPos]) - Ord('0')) * 10 + (Ord(ADate[LPos + 1]) - Ord('0'));
  LMinute := (Ord(ADate[LPos + 3]) - Ord('0')) * 10 + (Ord(ADate[LPos + 4]) - Ord('0'));
  LSecond := (Ord(ADate[LPos + 6]) - Ord('0')) * 10 + (Ord(ADate[LPos + 7]) - Ord('0'));
  if (ADate[LPos + 8] = ' ') and (LPos + 12 <= Length(ADate)) and
     (ADate[LPos + 9] in ['0'..'9']) then
  begin
    if ADate[4] = ' ' then
    begin
      LYear := (Ord(ADate[LPos + 9]) - Ord('0')) * 1000
             + (Ord(ADate[LPos + 10]) - Ord('0')) * 100
             + (Ord(ADate[LPos + 11]) - Ord('0')) * 10
             + (Ord(ADate[LPos + 12]) - Ord('0'));
    end;
  end;
  if (LDay < 1) or (LDay > 31) or (LMonth < 1) or (LMonth > 12) or
     (LHour > 23) or (LMinute > 59) or (LSecond > 60) then
    Exit;
  try
    LDT := TOffsetDateTime.Create(
      TNaiveDateTime.Create(LYear, LMonth, LDay, LHour, LMinute, LSecond),
      TUtcOffset.UTC);
    Result := LDT.ToUnixSeconds;
  except
    Result := 0;
  end;
end;

function TryParseHttpDate(const ADate: string; out AUnix: Int64): Boolean;
var
  LV: Int64;
begin
  LV := ParseHttpDate(ADate);
  if LV = 0 then
    LV := ParseHttpDateFallback(ADate);
  if LV = 0 then
    Exit(False);
  AUnix := LV;
  Result := True;
end;

end.
