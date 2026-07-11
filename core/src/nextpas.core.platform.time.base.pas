unit nextpas.core.platform.time.base;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc 纳秒级时间戳（单调时钟） *}
  TPlatformTimeNanoseconds = UInt64;

  {** @desc 性能计数器值 *}
  TPlatformCounterValue = UInt64;

  {** @desc 性能计数器频率（Hz） *}
  TPlatformCounterFrequency = UInt64;

  {** @desc UTC 时间分解结构 *}
  TPlatformTimeBreakdown = record
    Year: Int32;
    Month: Int32;
    Day: Int32;
    Hour: Int32;
    Minute: Int32;
    Second: Int32;
    Millisecond: Int32;
    {** @desc 检查时间是否有效（基本范围检查）
        @return True 如果时间有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查时间是否为空（全零）
        @return True 如果时间为空 *}
    function IsEmpty: Boolean; inline;
    {** @desc 比较两个时间（返回 -1/0/1）
        @param AOther 另一个时间
        @return -1 早于，0 相同，1 晚于 *}
    function Compare(const AOther: TPlatformTimeBreakdown): Int32;
    {** @desc 计算星期几（0=周日, 1=周一, ..., 6=周六）
        @return 星期几 *}
    function DayOfWeek: Int32;
    {** @desc 检查是否为闰年
        @return True 如果是闰年 *}
    function IsLeapYear: Boolean; inline;
  end;

implementation

function TPlatformTimeBreakdown.IsValid: Boolean;
begin
  Result := (Year >= 1970) and (Month >= 1) and (Month <= 12) and
            (Day >= 1) and (Day <= 31) and
            (Hour >= 0) and (Hour <= 23) and
            (Minute >= 0) and (Minute <= 59) and
            (Second >= 0) and (Second <= 59) and
            (Millisecond >= 0) and (Millisecond <= 999);
end;

function TPlatformTimeBreakdown.IsEmpty: Boolean;
begin
  Result := (Year = 0) and (Month = 0) and (Day = 0) and
            (Hour = 0) and (Minute = 0) and (Second = 0) and
            (Millisecond = 0);
end;

function TPlatformTimeBreakdown.Compare(const AOther: TPlatformTimeBreakdown): Int32;
begin
  if Year < AOther.Year then Exit(-1);
  if Year > AOther.Year then Exit(1);
  if Month < AOther.Month then Exit(-1);
  if Month > AOther.Month then Exit(1);
  if Day < AOther.Day then Exit(-1);
  if Day > AOther.Day then Exit(1);
  if Hour < AOther.Hour then Exit(-1);
  if Hour > AOther.Hour then Exit(1);
  if Minute < AOther.Minute then Exit(-1);
  if Minute > AOther.Minute then Exit(1);
  if Second < AOther.Second then Exit(-1);
  if Second > AOther.Second then Exit(1);
  if Millisecond < AOther.Millisecond then Exit(-1);
  if Millisecond > AOther.Millisecond then Exit(1);
  Result := 0;
end;

function TPlatformTimeBreakdown.DayOfWeek: Int32;
var
  Y, M, D: Int32;
begin
  { Zeller's congruence (Gregorian calendar) }
  Y := Year;
  M := Month;
  D := Day;
  if M < 3 then
  begin
    Inc(M, 12);
    Dec(Y);
  end;
  Result := (D + (13 * (M + 1)) div 5 + Y + Y div 4 - Y div 100 + Y div 400) mod 7;
  { Convert from Zeller's (0=Sat) to standard (0=Sun) }
  Result := (Result + 6) mod 7;
end;

function TPlatformTimeBreakdown.IsLeapYear: Boolean;
begin
  Result := ((Year mod 4 = 0) and (Year mod 100 <> 0)) or (Year mod 400 = 0);
end;

end.
