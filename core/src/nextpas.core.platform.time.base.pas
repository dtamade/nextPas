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

end.
