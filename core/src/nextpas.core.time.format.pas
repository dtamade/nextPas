unit nextpas.core.time.format;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.date,
  nextpas.core.time.timeofday,
  nextpas.core.time.timezone,
  nextpas.core.time.offsetdatetime;

function FormatDateTime(const APattern: string; const ADT: TOffsetDateTime): string;
function FormatDate(const APattern: string; const ADate: TDate): string;
function FormatTime(const APattern: string; const ATime: TTimeOfDay): string;

implementation

const
  DAY_NAMES_SHORT: array[1..7] of string = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
  DAY_NAMES_LONG: array[1..7] of string = ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');
  MONTH_NAMES_SHORT: array[1..12] of string = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');

function Pad2(AVal: Integer): string; inline;
begin
  if AVal < 10 then
    Result := '0' + Chr(Ord('0') + AVal)
  else
    Result := Chr(Ord('0') + AVal div 10) + Chr(Ord('0') + AVal mod 10);
end;

function Pad4(AVal: Integer): string;
begin
  Result := Chr(Ord('0') + (AVal div 1000) mod 10)
    + Chr(Ord('0') + (AVal div 100) mod 10)
    + Chr(Ord('0') + (AVal div 10) mod 10)
    + Chr(Ord('0') + AVal mod 10);
end;

function Pad9(AVal: Integer): string;
var
  LI: Integer;
  LBuf: string;
begin
  SetLength(LBuf, 9);
  for LI := 9 downto 1 do
  begin
    LBuf[LI] := Chr(Ord('0') + AVal mod 10);
    AVal := AVal div 10;
  end;
  Result := LBuf;
end;

function DoFormat(const APattern: string; AYear, AMonth, ADay, AHour, AMinute, ASecond, ANano: Integer;
  ADow: Integer; const AOffset: string): string;
var
  LI, LLen: Integer;
  LC: Char;
begin
  Result := '';
  LLen := Length(APattern);
  LI := 1;
  while LI <= LLen do
  begin
    LC := APattern[LI];
    if LC = '%' then
    begin
      Inc(LI);
      if LI > LLen then
        Break;
      LC := APattern[LI];
      case LC of
        'Y': Result := Result + Pad4(AYear);
        'm': Result := Result + Pad2(AMonth);
        'd': Result := Result + Pad2(ADay);
        'H': Result := Result + Pad2(AHour);
        'M': Result := Result + Pad2(AMinute);
        'S': Result := Result + Pad2(ASecond);
        'f': Result := Result + Pad9(ANano);
        'z': Result := Result + AOffset;
        'a': if (ADow >= 1) and (ADow <= 7) then
               Result := Result + DAY_NAMES_SHORT[ADow];
        'A': if (ADow >= 1) and (ADow <= 7) then
               Result := Result + DAY_NAMES_LONG[ADow];
        'b': if (AMonth >= 1) and (AMonth <= 12) then
               Result := Result + MONTH_NAMES_SHORT[AMonth];
        '%': Result := Result + '%';
      else
        Result := Result + '%' + LC;
      end;
    end
    else
      Result := Result + LC;
    Inc(LI);
  end;
end;

function FormatDateTime(const APattern: string; const ADT: TOffsetDateTime): string;
begin
  Result := DoFormat(APattern,
    ADT.GetYear, ADT.GetMonth, ADT.GetDay,
    ADT.GetHour, ADT.GetMinute, ADT.GetSecond, ADT.GetNanosecond,
    Ord(ADT.GetDate.GetDayOfWeek),
    ADT.GetOffset.ToString);
end;

function FormatDate(const APattern: string; const ADate: TDate): string;
begin
  Result := DoFormat(APattern,
    ADate.GetYear, ADate.GetMonth, ADate.GetDay,
    0, 0, 0, 0,
    Ord(ADate.GetDayOfWeek), '');
end;

function FormatTime(const APattern: string; const ATime: TTimeOfDay): string;
begin
  Result := DoFormat(APattern,
    0, 0, 0,
    ATime.GetHour, ATime.GetMinute, ATime.GetSecond, ATime.GetSubsecondNanos,
    0, '');
end;

end.
