unit nextpas.core.math.quat;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.quat.base;

{ Quaternion constructors }

{** Create a single-precision quaternion from x, y, z, w components }
function Quatf(const AX, AY, AZ, AW: Single): TQuatf; inline;
{** Create a double-precision quaternion from x, y, z, w components }
function Quatd(const AX, AY, AZ, AW: Double): TQuatd; inline;

implementation

function Quatf(const AX, AY, AZ, AW: Single): TQuatf;
begin
  Result := TQuatf.Create(AX, AY, AZ, AW);
end;

function Quatd(const AX, AY, AZ, AW: Double): TQuatd;
begin
  Result := TQuatd.Create(AX, AY, AZ, AW);
end;

end.
