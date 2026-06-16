{
  nextpas.core.math.base.pas
  Shared base types and constants for the math module
}
unit nextpas.core.math.base;

{$I nextpas.core.settings.inc}

interface

type
  TPoint2f = record
    X: Single;
    Y: Single;
  end;

  TPoint3f = record
    X: Single;
    Y: Single;
    Z: Single;
  end;

const
  PI_VALUE: Double = 3.14159265358979323846;
  TWO_PI: Double = 6.28318530717958647692;
  HALF_PI: Double = 1.57079632679489661923;
  QUARTER_PI: Double = 0.78539816339744830962;
  DEG_TO_RAD: Double = 0.01745329251994329577;
  RAD_TO_DEG: Double = 57.2957795130823208768;

implementation

end.
