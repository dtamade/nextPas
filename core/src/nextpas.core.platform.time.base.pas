unit nextpas.core.platform.time.base;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformTimeNanoseconds = UInt64;
  TPlatformCounterValue = UInt64;
  TPlatformCounterFrequency = UInt64;

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
