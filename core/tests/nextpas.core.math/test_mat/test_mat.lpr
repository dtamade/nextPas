program test_mat;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math.mat.base,
  nextpas.core.math.mat;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  PASS: ', AName); end
  else begin Inc(GFail); WriteLn('  FAIL: ', AName); end;
end;

procedure CheckFloat(const AName: string; AExpected, AActual, AEps: Double);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0 then LDelta := -LDelta;
  Check(AName, LDelta < AEps);
end;

procedure TestMat3fCreateAndIdentity;
var
  M: TMat3f;
begin
  WriteLn('--- Mat3f Create and Identity ---');
  M := Mat3f(1, 2, 3, 4, 5, 6, 7, 8, 9);
  Check('Mat3f Create [0,0]', M[0,0] = 1.0);
  Check('Mat3f Create [1,1]', M[1,1] = 5.0);
  Check('Mat3f Create [2,2]', M[2,2] = 9.0);

  M := Mat3fIdentity;
  Check('Mat3f Identity [0,0]', M[0,0] = 1.0);
  Check('Mat3f Identity [1,1]', M[1,1] = 1.0);
  Check('Mat3f Identity [2,2]', M[2,2] = 1.0);
  Check('Mat3f Identity [0,1]', M[0,1] = 0.0);
end;

procedure TestMat3fDeterminant;
var
  M: TMat3f;
begin
  WriteLn('--- Mat3f Determinant ---');
  M := Mat3f(1, 2, 3, 4, 5, 6, 7, 8, 9);
  CheckFloat('Mat3f Det(1,2,3;4,5,6;7,8,9)', 0.0, M.Determinant, 1e-10);

  M := Mat3f(1, 0, 0, 0, 1, 0, 0, 0, 1);
  CheckFloat('Mat3f Det(Identity)', 1.0, M.Determinant, 1e-10);
end;

procedure TestMat3fTranspose;
var
  M: TMat3f;
begin
  WriteLn('--- Mat3f Transpose ---');
  M := Mat3f(1, 2, 3, 4, 5, 6, 7, 8, 9);
  M := M.Transpose;
  Check('Mat3f Transpose [0,1]', M[0,1] = 4.0);
  Check('Mat3f Transpose [1,0]', M[1,0] = 2.0);
  Check('Mat3f Transpose [2,2]', M[2,2] = 9.0);
end;

procedure TestMat3fInverse;
var
  M, MInv: TMat3f;
begin
  WriteLn('--- Mat3f Inverse ---');
  M := Mat3f(1, 2, 3, 0, 1, 4, 5, 6, 0);
  MInv := M.Inverse;
  CheckFloat('Mat3f Inverse [0,0]', -24.0, MInv[0,0], 1e-6);
  CheckFloat('Mat3f Inverse [0,1]', 18.0, MInv[0,1], 1e-6);
  CheckFloat('Mat3f Inverse [0,2]', 5.0, MInv[0,2], 1e-6);
end;

procedure TestMat4fCreateAndIdentity;
var
  M: TMat4f;
begin
  WriteLn('--- Mat4f Create and Identity ---');
  M := Mat4fIdentity;
  Check('Mat4f Identity [0,0]', M[0,0] = 1.0);
  Check('Mat4f Identity [3,3]', M[3,3] = 1.0);
  Check('Mat4f Identity [1,2]', M[1,2] = 0.0);
end;

procedure TestMat4fDeterminant;
var
  M: TMat4f;
begin
  WriteLn('--- Mat4f Determinant ---');
  M := Mat4fIdentity;
  CheckFloat('Mat4f Det(Identity)', 1.0, M.Determinant, 1e-10);
end;

procedure TestMat4fTranspose;
var
  M: TMat4f;
begin
  WriteLn('--- Mat4f Transpose ---');
  M := Mat4f(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  M := M.Transpose;
  Check('Mat4f Transpose [0,1]', M[0,1] = 5.0);
  Check('Mat4f Transpose [1,0]', M[1,0] = 2.0);
  Check('Mat4f Transpose [3,3]', M[3,3] = 16.0);
end;

procedure TestMat4fInverse;
var
  M, MInv: TMat4f;
begin
  WriteLn('--- Mat4f Inverse ---');
  M := Mat4fIdentity;
  MInv := M.Inverse;
  Check('Mat4f Inverse Identity [0,0]', MInv[0,0] = 1.0);
  Check('Mat4f Inverse Identity [3,3]', MInv[3,3] = 1.0);
end;

procedure TestMat3dCreateAndIdentity;
var
  M: TMat3d;
begin
  WriteLn('--- Mat3d Create and Identity ---');
  M := Mat3d(1, 2, 3, 4, 5, 6, 7, 8, 9);
  Check('Mat3d Create [0,0]', M[0,0] = 1.0);
  Check('Mat3d Create [2,2]', M[2,2] = 9.0);

  M := Mat3dIdentity;
  Check('Mat3d Identity [0,0]', M[0,0] = 1.0);
  Check('Mat3d Identity [1,1]', M[1,1] = 1.0);
end;

procedure TestMat4dCreateAndIdentity;
var
  M: TMat4d;
begin
  WriteLn('--- Mat4d Create and Identity ---');
  M := Mat4dIdentity;
  Check('Mat4d Identity [0,0]', M[0,0] = 1.0);
  Check('Mat4d Identity [3,3]', M[3,3] = 1.0);
  Check('Mat4d Identity [1,2]', M[1,2] = 0.0);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== nextpas.core.math.mat tests ===');
  WriteLn;

  TestMat3fCreateAndIdentity;
  TestMat3fDeterminant;
  TestMat3fTranspose;
  TestMat3fInverse;
  TestMat4fCreateAndIdentity;
  TestMat4fDeterminant;
  TestMat4fTranspose;
  TestMat4fInverse;
  TestMat3dCreateAndIdentity;
  TestMat4dCreateAndIdentity;

  WriteLn;
  WriteLn('=== Results: ', GPass, ' passed, ', GFail, ' failed ===');
  if GFail > 0 then Halt(1);
end.