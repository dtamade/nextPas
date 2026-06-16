unit nextpas.core.math.mat;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.mat.base;

function Mat3f(const A00, A01, A02, A10, A11, A12, A20, A21, A22: Single): TMat3f; inline;
function Mat3d(const A00, A01, A02, A10, A11, A12, A20, A21, A22: Double): TMat3d; inline;
function Mat4f(const A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33: Single): TMat4f; inline;
function Mat4d(const A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33: Double): TMat4d; inline;

implementation

function Mat3f(const A00, A01, A02, A10, A11, A12, A20, A21, A22: Single): TMat3f;
begin
  Result := TMat3f.Create(A00, A01, A02, A10, A11, A12, A20, A21, A22);
end;

function Mat3d(const A00, A01, A02, A10, A11, A12, A20, A21, A22: Double): TMat3d;
begin
  Result := TMat3d.Create(A00, A01, A02, A10, A11, A12, A20, A21, A22);
end;

function Mat4f(const A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33: Single): TMat4f;
begin
  Result := TMat4f.Create(A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33);
end;

function Mat4d(const A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33: Double): TMat4d;
begin
  Result := TMat4d.Create(A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33);
end;

end.