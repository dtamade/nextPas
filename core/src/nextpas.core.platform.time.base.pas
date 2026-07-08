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
  end;

implementation

end.
