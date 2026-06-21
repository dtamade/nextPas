unit Math;

{$mode objfpc}{$H+}

interface

function IsNan(const AValue: Double): Boolean;
function IsInfinite(const AValue: Double): Boolean;

implementation

function IsNan(const AValue: Double): Boolean;
var
  LBytes: array[0..7] of Byte absolute AValue;
begin
  Result := ((LBytes[7] and $7F) = $7F) and
            (((LBytes[6] and $F0) <> $F0) or
             ((LBytes[0] or LBytes[1] or LBytes[2] or LBytes[3] or
               LBytes[4] or LBytes[5] or (LBytes[6] and $0F)) <> 0));
end;

function IsInfinite(const AValue: Double): Boolean;
var
  LBytes: array[0..7] of Byte absolute AValue;
begin
  Result := ((LBytes[7] and $7F) = $7F) and
            ((LBytes[6] and $F0) = $F0) and
            ((LBytes[6] and $0F) = 0) and
            (LBytes[0] = 0) and (LBytes[1] = 0) and
            (LBytes[2] = 0) and (LBytes[3] = 0) and
            (LBytes[4] = 0) and (LBytes[5] = 0);
end;

end.
