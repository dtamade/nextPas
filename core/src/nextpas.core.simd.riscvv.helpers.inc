// =============================================================
// Missing Scalar Fallbacks for ASM-only functions
// =============================================================

function RISCVVAddU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarAddU64x2(a, b);
end;

function RISCVVSubU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarSubU64x2(a, b);
end;

function RISCVVAndU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarAndU64x2(a, b);
end;

function RISCVVOrU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarOrU64x2(a, b);
end;

function RISCVVXorU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result := ScalarXorU64x2(a, b);
end;

function RISCVVNotU64x2(const a: TVecU64x2): TVecU64x2;
begin
  Result := ScalarNotU64x2(a);
end;

function RISCVVCmpNeU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := ScalarCmpNeU32x4(a, b);
end;

function RISCVVShiftLeftI64x2(const a: TVecI64x2; shift: Integer): TVecI64x2;
begin
  Result := ScalarShiftLeftI64x2(a, shift);
end;

function RISCVVShiftRightI64x2(const a: TVecI64x2; shift: Integer): TVecI64x2;
begin
  Result := ScalarShiftRightI64x2(a, shift);
end;

function RISCVVShiftRightArithI64x2(const a: TVecI64x2; shift: Integer): TVecI64x2;
begin
  Result := ScalarShiftRightArithI64x2(a, shift);
end;

function RISCVVShiftRightArithI64x4(const a: TVecI64x4; shift: Integer): TVecI64x4;
begin
  Result := ScalarShiftRightArithI64x4(a, shift);
end;
