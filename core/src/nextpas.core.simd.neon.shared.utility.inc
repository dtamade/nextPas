// Shared helper subset that must exist in both scalar-only and asm-enabled NEON
// builds. The always-on autowrap layer depends on these helpers even when the
// main backend body is running with AArch64 inline asm enabled.

function NEONCmpEqU64x2(const a, b: TVecU64x2): TMask2;
begin
  Result := 0;
  if a.u[0] = b.u[0] then
    Result := Result or 1;
  if a.u[1] = b.u[1] then
    Result := Result or 2;
end;

function NEONCmpLtU64x2(const a, b: TVecU64x2): TMask2;
const
  SIGN_MASK: QWord = QWord($8000000000000000);
var
  LAdjustedA: TVecI64x2;
  LAdjustedB: TVecI64x2;
begin
  LAdjustedA.i[0] := Int64(a.u[0] xor SIGN_MASK);
  LAdjustedA.i[1] := Int64(a.u[1] xor SIGN_MASK);
  LAdjustedB.i[0] := Int64(b.u[0] xor SIGN_MASK);
  LAdjustedB.i[1] := Int64(b.u[1] xor SIGN_MASK);
  Result := NEONCmpLtI64x2(LAdjustedA, LAdjustedB);
end;

function NEONCmpGtU64x2(const a, b: TVecU64x2): TMask2;
const
  SIGN_MASK: QWord = QWord($8000000000000000);
var
  LAdjustedA: TVecI64x2;
  LAdjustedB: TVecI64x2;
begin
  LAdjustedA.i[0] := Int64(a.u[0] xor SIGN_MASK);
  LAdjustedA.i[1] := Int64(a.u[1] xor SIGN_MASK);
  LAdjustedB.i[0] := Int64(b.u[0] xor SIGN_MASK);
  LAdjustedB.i[1] := Int64(b.u[1] xor SIGN_MASK);
  Result := NEONCmpGtI64x2(LAdjustedA, LAdjustedB);
end;
