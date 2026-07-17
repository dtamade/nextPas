{
  Generated from nextpas.core.simd.backend.adapter.map.csv.
  Authoritative declarative mapping list for adapter-managed slots.
  Edit the CSV spec and regenerate; do not hand-edit this file.
  Forward:  TSimdBackendOps -> TSimdDispatchTable (with Assigned guard).
  Backward: TSimdDispatchTable -> TSimdBackendOps.
}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x4.Add) then
    table.CoreVectors.AddF32x4 := ops.ArithmeticF32x4.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x4.Add := table.CoreVectors.AddF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x4.Sub) then
    table.CoreVectors.SubF32x4 := ops.ArithmeticF32x4.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x4.Sub := table.CoreVectors.SubF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x4.Mul) then
    table.CoreVectors.MulF32x4 := ops.ArithmeticF32x4.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x4.Mul := table.CoreVectors.MulF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x4.OpDiv) then
    table.CoreVectors.DivF32x4 := ops.ArithmeticF32x4.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x4.OpDiv := table.CoreVectors.DivF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x8.Add) then
    table.CoreVectors.AddF32x8 := ops.ArithmeticF32x8.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x8.Add := table.CoreVectors.AddF32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x8.Sub) then
    table.CoreVectors.SubF32x8 := ops.ArithmeticF32x8.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x8.Sub := table.CoreVectors.SubF32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x8.Mul) then
    table.CoreVectors.MulF32x8 := ops.ArithmeticF32x8.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x8.Mul := table.CoreVectors.MulF32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x8.OpDiv) then
    table.CoreVectors.DivF32x8 := ops.ArithmeticF32x8.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x8.OpDiv := table.CoreVectors.DivF32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x2.Add) then
    table.CoreVectors.AddF64x2 := ops.ArithmeticF64x2.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x2.Add := table.CoreVectors.AddF64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x2.Sub) then
    table.CoreVectors.SubF64x2 := ops.ArithmeticF64x2.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x2.Sub := table.CoreVectors.SubF64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x2.Mul) then
    table.CoreVectors.MulF64x2 := ops.ArithmeticF64x2.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x2.Mul := table.CoreVectors.MulF64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x2.OpDiv) then
    table.CoreVectors.DivF64x2 := ops.ArithmeticF64x2.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x2.OpDiv := table.CoreVectors.DivF64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x4.Add) then
    table.CoreVectors.AddF64x4 := ops.ArithmeticF64x4.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x4.Add := table.CoreVectors.AddF64x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x4.Sub) then
    table.CoreVectors.SubF64x4 := ops.ArithmeticF64x4.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x4.Sub := table.CoreVectors.SubF64x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x4.Mul) then
    table.CoreVectors.MulF64x4 := ops.ArithmeticF64x4.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x4.Mul := table.CoreVectors.MulF64x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x4.OpDiv) then
    table.CoreVectors.DivF64x4 := ops.ArithmeticF64x4.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x4.OpDiv := table.CoreVectors.DivF64x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x4.Add) then
    table.CoreVectors.AddI32x4 := ops.ArithmeticI32x4.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x4.Add := table.CoreVectors.AddI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x4.Sub) then
    table.CoreVectors.SubI32x4 := ops.ArithmeticI32x4.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x4.Sub := table.CoreVectors.SubI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x4.Mul) then
    table.CoreVectors.MulI32x4 := ops.ArithmeticI32x4.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x4.Mul := table.CoreVectors.MulI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x4.OpAnd) then
    table.CoreVectors.AndI32x4 := ops.BitwiseI32x4.OpAnd;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x4.OpAnd := table.CoreVectors.AndI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x4.OpOr) then
    table.CoreVectors.OrI32x4 := ops.BitwiseI32x4.OpOr;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x4.OpOr := table.CoreVectors.OrI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x4.OpXor) then
    table.CoreVectors.XorI32x4 := ops.BitwiseI32x4.OpXor;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x4.OpXor := table.CoreVectors.XorI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x4.OpNot) then
    table.CoreVectors.NotI32x4 := ops.BitwiseI32x4.OpNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x4.OpNot := table.CoreVectors.NotI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x4.AndNot) then
    table.CoreVectors.AndNotI32x4 := ops.BitwiseI32x4.AndNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x4.AndNot := table.CoreVectors.AndNotI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x4.ShiftLeft) then
    table.CoreVectors.ShiftLeftI32x4 := ops.ShiftI32x4.ShiftLeft;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x4.ShiftLeft := table.CoreVectors.ShiftLeftI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x4.ShiftRight) then
    table.CoreVectors.ShiftRightI32x4 := ops.ShiftI32x4.ShiftRight;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x4.ShiftRight := table.CoreVectors.ShiftRightI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x4.ShiftRightArith) then
    table.CoreVectors.ShiftRightArithI32x4 := ops.ShiftI32x4.ShiftRightArith;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x4.ShiftRightArith := table.CoreVectors.ShiftRightArithI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x4.CmpEq) then
    table.CoreVectors.CmpEqI32x4 := ops.ComparisonI32x4.CmpEq;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x4.CmpEq := table.CoreVectors.CmpEqI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x4.CmpLt) then
    table.CoreVectors.CmpLtI32x4 := ops.ComparisonI32x4.CmpLt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x4.CmpLt := table.CoreVectors.CmpLtI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x4.CmpGt) then
    table.CoreVectors.CmpGtI32x4 := ops.ComparisonI32x4.CmpGt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x4.CmpGt := table.CoreVectors.CmpGtI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x4.Min) then
    table.CoreVectors.MinI32x4 := ops.MinMaxI32x4.Min;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x4.Min := table.CoreVectors.MinI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x4.Max) then
    table.CoreVectors.MaxI32x4 := ops.MinMaxI32x4.Max;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x4.Max := table.CoreVectors.MaxI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI64x2.Add) then
    table.CoreVectors.AddI64x2 := ops.ArithmeticI64x2.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI64x2.Add := table.CoreVectors.AddI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI64x2.Sub) then
    table.CoreVectors.SubI64x2 := ops.ArithmeticI64x2.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI64x2.Sub := table.CoreVectors.SubI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI64x2.OpAnd) then
    table.CoreVectors.AndI64x2 := ops.BitwiseI64x2.OpAnd;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI64x2.OpAnd := table.CoreVectors.AndI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI64x2.OpOr) then
    table.CoreVectors.OrI64x2 := ops.BitwiseI64x2.OpOr;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI64x2.OpOr := table.CoreVectors.OrI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI64x2.OpXor) then
    table.CoreVectors.XorI64x2 := ops.BitwiseI64x2.OpXor;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI64x2.OpXor := table.CoreVectors.XorI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI64x2.OpNot) then
    table.CoreVectors.NotI64x2 := ops.BitwiseI64x2.OpNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI64x2.OpNot := table.CoreVectors.NotI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x8.Add) then
    table.CoreVectors.AddI32x8 := ops.ArithmeticI32x8.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x8.Add := table.CoreVectors.AddI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x8.Sub) then
    table.CoreVectors.SubI32x8 := ops.ArithmeticI32x8.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x8.Sub := table.CoreVectors.SubI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x8.Mul) then
    table.CoreVectors.MulI32x8 := ops.ArithmeticI32x8.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x8.Mul := table.CoreVectors.MulI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x8.OpAnd) then
    table.CoreVectors.AndI32x8 := ops.BitwiseI32x8.OpAnd;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x8.OpAnd := table.CoreVectors.AndI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x8.OpOr) then
    table.CoreVectors.OrI32x8 := ops.BitwiseI32x8.OpOr;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x8.OpOr := table.CoreVectors.OrI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x8.OpXor) then
    table.CoreVectors.XorI32x8 := ops.BitwiseI32x8.OpXor;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x8.OpXor := table.CoreVectors.XorI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x8.OpNot) then
    table.CoreVectors.NotI32x8 := ops.BitwiseI32x8.OpNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x8.OpNot := table.CoreVectors.NotI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x8.AndNot) then
    table.CoreVectors.AndNotI32x8 := ops.BitwiseI32x8.AndNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x8.AndNot := table.CoreVectors.AndNotI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x8.ShiftLeft) then
    table.CoreVectors.ShiftLeftI32x8 := ops.ShiftI32x8.ShiftLeft;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x8.ShiftLeft := table.CoreVectors.ShiftLeftI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x8.ShiftRight) then
    table.CoreVectors.ShiftRightI32x8 := ops.ShiftI32x8.ShiftRight;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x8.ShiftRight := table.CoreVectors.ShiftRightI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x8.ShiftRightArith) then
    table.CoreVectors.ShiftRightArithI32x8 := ops.ShiftI32x8.ShiftRightArith;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x8.ShiftRightArith := table.CoreVectors.ShiftRightArithI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x8.CmpEq) then
    table.CoreVectors.CmpEqI32x8 := ops.ComparisonI32x8.CmpEq;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x8.CmpEq := table.CoreVectors.CmpEqI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x8.CmpLt) then
    table.CoreVectors.CmpLtI32x8 := ops.ComparisonI32x8.CmpLt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x8.CmpLt := table.CoreVectors.CmpLtI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x8.CmpGt) then
    table.CoreVectors.CmpGtI32x8 := ops.ComparisonI32x8.CmpGt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x8.CmpGt := table.CoreVectors.CmpGtI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x8.Min) then
    table.CoreVectors.MinI32x8 := ops.MinMaxI32x8.Min;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x8.Min := table.CoreVectors.MinI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x8.Max) then
    table.CoreVectors.MaxI32x8 := ops.MinMaxI32x8.Max;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x8.Max := table.CoreVectors.MaxI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x16.Add) then
    table.CoreVectors.AddF32x16 := ops.ArithmeticF32x16.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x16.Add := table.CoreVectors.AddF32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x16.Sub) then
    table.CoreVectors.SubF32x16 := ops.ArithmeticF32x16.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x16.Sub := table.CoreVectors.SubF32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x16.Mul) then
    table.CoreVectors.MulF32x16 := ops.ArithmeticF32x16.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x16.Mul := table.CoreVectors.MulF32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x16.OpDiv) then
    table.CoreVectors.DivF32x16 := ops.ArithmeticF32x16.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x16.OpDiv := table.CoreVectors.DivF32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x8.Add) then
    table.CoreVectors.AddF64x8 := ops.ArithmeticF64x8.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x8.Add := table.CoreVectors.AddF64x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x8.Sub) then
    table.CoreVectors.SubF64x8 := ops.ArithmeticF64x8.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x8.Sub := table.CoreVectors.SubF64x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x8.Mul) then
    table.CoreVectors.MulF64x8 := ops.ArithmeticF64x8.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x8.Mul := table.CoreVectors.MulF64x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x8.OpDiv) then
    table.CoreVectors.DivF64x8 := ops.ArithmeticF64x8.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x8.OpDiv := table.CoreVectors.DivF64x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x16.Add) then
    table.CoreVectors.AddI32x16 := ops.ArithmeticI32x16.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x16.Add := table.CoreVectors.AddI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x16.Sub) then
    table.CoreVectors.SubI32x16 := ops.ArithmeticI32x16.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x16.Sub := table.CoreVectors.SubI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x16.Mul) then
    table.CoreVectors.MulI32x16 := ops.ArithmeticI32x16.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x16.Mul := table.CoreVectors.MulI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x16.OpAnd) then
    table.CoreVectors.AndI32x16 := ops.BitwiseI32x16.OpAnd;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x16.OpAnd := table.CoreVectors.AndI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x16.OpOr) then
    table.CoreVectors.OrI32x16 := ops.BitwiseI32x16.OpOr;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x16.OpOr := table.CoreVectors.OrI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x16.OpXor) then
    table.CoreVectors.XorI32x16 := ops.BitwiseI32x16.OpXor;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x16.OpXor := table.CoreVectors.XorI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x16.OpNot) then
    table.CoreVectors.NotI32x16 := ops.BitwiseI32x16.OpNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x16.OpNot := table.CoreVectors.NotI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x16.AndNot) then
    table.CoreVectors.AndNotI32x16 := ops.BitwiseI32x16.AndNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x16.AndNot := table.CoreVectors.AndNotI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x16.ShiftLeft) then
    table.CoreVectors.ShiftLeftI32x16 := ops.ShiftI32x16.ShiftLeft;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x16.ShiftLeft := table.CoreVectors.ShiftLeftI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x16.ShiftRight) then
    table.CoreVectors.ShiftRightI32x16 := ops.ShiftI32x16.ShiftRight;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x16.ShiftRight := table.CoreVectors.ShiftRightI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x16.ShiftRightArith) then
    table.CoreVectors.ShiftRightArithI32x16 := ops.ShiftI32x16.ShiftRightArith;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x16.ShiftRightArith := table.CoreVectors.ShiftRightArithI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x16.CmpEq) then
    table.CoreVectors.CmpEqI32x16 := ops.ComparisonI32x16.CmpEq;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x16.CmpEq := table.CoreVectors.CmpEqI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x16.CmpLt) then
    table.CoreVectors.CmpLtI32x16 := ops.ComparisonI32x16.CmpLt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x16.CmpLt := table.CoreVectors.CmpLtI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x16.CmpGt) then
    table.CoreVectors.CmpGtI32x16 := ops.ComparisonI32x16.CmpGt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x16.CmpGt := table.CoreVectors.CmpGtI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x16.Min) then
    table.CoreVectors.MinI32x16 := ops.MinMaxI32x16.Min;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x16.Min := table.CoreVectors.MinI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x16.Max) then
    table.CoreVectors.MaxI32x16 := ops.MinMaxI32x16.Max;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x16.Max := table.CoreVectors.MaxI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpEq) then
    table.CoreVectors.CmpEqF32x4 := ops.ComparisonF32x4.CmpEq;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpEq := table.CoreVectors.CmpEqF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpLt) then
    table.CoreVectors.CmpLtF32x4 := ops.ComparisonF32x4.CmpLt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpLt := table.CoreVectors.CmpLtF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpLe) then
    table.CoreVectors.CmpLeF32x4 := ops.ComparisonF32x4.CmpLe;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpLe := table.CoreVectors.CmpLeF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpGt) then
    table.CoreVectors.CmpGtF32x4 := ops.ComparisonF32x4.CmpGt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpGt := table.CoreVectors.CmpGtF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpGe) then
    table.CoreVectors.CmpGeF32x4 := ops.ComparisonF32x4.CmpGe;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpGe := table.CoreVectors.CmpGeF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpNe) then
    table.CoreVectors.CmpNeF32x4 := ops.ComparisonF32x4.CmpNe;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpNe := table.CoreVectors.CmpNeF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Abs) then
    table.CoreVectors.AbsF32x4 := ops.MathF32x4.Abs;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Abs := table.CoreVectors.AbsF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Sqrt) then
    table.CoreVectors.SqrtF32x4 := ops.MathF32x4.Sqrt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Sqrt := table.CoreVectors.SqrtF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Min) then
    table.CoreVectors.MinF32x4 := ops.MathF32x4.Min;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Min := table.CoreVectors.MinF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Max) then
    table.CoreVectors.MaxF32x4 := ops.MathF32x4.Max;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Max := table.CoreVectors.MaxF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Fma) then
    table.CoreVectors.FmaF32x4 := ops.MathF32x4.Fma;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Fma := table.CoreVectors.FmaF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Rcp) then
    table.CoreVectors.RcpF32x4 := ops.MathF32x4.Rcp;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Rcp := table.CoreVectors.RcpF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Rsqrt) then
    table.CoreVectors.RsqrtF32x4 := ops.MathF32x4.Rsqrt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Rsqrt := table.CoreVectors.RsqrtF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Floor) then
    table.CoreVectors.FloorF32x4 := ops.MathF32x4.Floor;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Floor := table.CoreVectors.FloorF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Ceil) then
    table.CoreVectors.CeilF32x4 := ops.MathF32x4.Ceil;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Ceil := table.CoreVectors.CeilF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Round) then
    table.CoreVectors.RoundF32x4 := ops.MathF32x4.Round;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Round := table.CoreVectors.RoundF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Trunc) then
    table.CoreVectors.TruncF32x4 := ops.MathF32x4.Trunc;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Trunc := table.CoreVectors.TruncF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Clamp) then
    table.CoreVectors.ClampF32x4 := ops.MathF32x4.Clamp;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Clamp := table.CoreVectors.ClampF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Dot4) then
    table.CoreVectors.DotF32x4 := ops.VectorMathF32x4.Dot4;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Dot4 := table.CoreVectors.DotF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Dot3) then
    table.CoreVectors.DotF32x3 := ops.VectorMathF32x4.Dot3;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Dot3 := table.CoreVectors.DotF32x3;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Cross3) then
    table.CoreVectors.CrossF32x3 := ops.VectorMathF32x4.Cross3;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Cross3 := table.CoreVectors.CrossF32x3;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Length4) then
    table.CoreVectors.LengthF32x4 := ops.VectorMathF32x4.Length4;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Length4 := table.CoreVectors.LengthF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Length3) then
    table.CoreVectors.LengthF32x3 := ops.VectorMathF32x4.Length3;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Length3 := table.CoreVectors.LengthF32x3;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Normalize4) then
    table.CoreVectors.NormalizeF32x4 := ops.VectorMathF32x4.Normalize4;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Normalize4 := table.CoreVectors.NormalizeF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Normalize3) then
    table.CoreVectors.NormalizeF32x3 := ops.VectorMathF32x4.Normalize3;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Normalize3 := table.CoreVectors.NormalizeF32x3;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ReductionF32x4.ReduceAdd) then
    table.CoreVectors.ReduceAddF32x4 := ops.ReductionF32x4.ReduceAdd;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ReductionF32x4.ReduceAdd := table.CoreVectors.ReduceAddF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ReductionF32x4.ReduceMin) then
    table.CoreVectors.ReduceMinF32x4 := ops.ReductionF32x4.ReduceMin;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ReductionF32x4.ReduceMin := table.CoreVectors.ReduceMinF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ReductionF32x4.ReduceMax) then
    table.CoreVectors.ReduceMaxF32x4 := ops.ReductionF32x4.ReduceMax;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ReductionF32x4.ReduceMax := table.CoreVectors.ReduceMaxF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ReductionF32x4.ReduceMul) then
    table.CoreVectors.ReduceMulF32x4 := ops.ReductionF32x4.ReduceMul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ReductionF32x4.ReduceMul := table.CoreVectors.ReduceMulF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Load) then
    table.CoreVectors.LoadF32x4 := ops.MemoryF32x4.Load;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Load := table.CoreVectors.LoadF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.LoadAligned) then
    table.CoreVectors.LoadF32x4Aligned := ops.MemoryF32x4.LoadAligned;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.LoadAligned := table.CoreVectors.LoadF32x4Aligned;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Store) then
    table.CoreVectors.StoreF32x4 := ops.MemoryF32x4.Store;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Store := table.CoreVectors.StoreF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.StoreAligned) then
    table.CoreVectors.StoreF32x4Aligned := ops.MemoryF32x4.StoreAligned;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.StoreAligned := table.CoreVectors.StoreF32x4Aligned;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Splat) then
    table.CoreVectors.SplatF32x4 := ops.MemoryF32x4.Splat;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Splat := table.CoreVectors.SplatF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Zero) then
    table.CoreVectors.ZeroF32x4 := ops.MemoryF32x4.Zero;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Zero := table.CoreVectors.ZeroF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Select) then
    table.CoreVectors.SelectF32x4 := ops.MemoryF32x4.Select;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Select := table.CoreVectors.SelectF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Extract) then
    table.CoreVectors.ExtractF32x4 := ops.MemoryF32x4.Extract;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Extract := table.CoreVectors.ExtractF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Insert) then
    table.CoreVectors.InsertF32x4 := ops.MemoryF32x4.Insert;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Insert := table.CoreVectors.InsertF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemEqual) then
    table.Memory.Equal := ops.Facade.MemEqual;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemEqual := table.Memory.Equal;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemFindByte) then
    table.Memory.FindByte := ops.Facade.MemFindByte;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemFindByte := table.Memory.FindByte;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemDiffRange) then
    table.Memory.DiffRange := ops.Facade.MemDiffRange;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemDiffRange := table.Memory.DiffRange;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemCopy) then
    table.Memory.Copy := ops.Facade.MemCopy;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemCopy := table.Memory.Copy;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemSet) then
    table.Memory.Fill := ops.Facade.MemSet;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemSet := table.Memory.Fill;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemReverse) then
    table.Memory.Reverse := ops.Facade.MemReverse;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemReverse := table.Memory.Reverse;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.SumBytes) then
    table.Memory.SumBytes := ops.Facade.SumBytes;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.SumBytes := table.Memory.SumBytes;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MinMaxBytes) then
    table.Memory.MinMaxBytes := ops.Facade.MinMaxBytes;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MinMaxBytes := table.Memory.MinMaxBytes;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.CountByte) then
    table.Memory.CountByte := ops.Facade.CountByte;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.CountByte := table.Memory.CountByte;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.Utf8Validate) then
    table.Memory.Utf8Validate := ops.Facade.Utf8Validate;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.Utf8Validate := table.Memory.Utf8Validate;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.AsciiIEqual) then
    table.Memory.AsciiIEqual := ops.Facade.AsciiIEqual;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.AsciiIEqual := table.Memory.AsciiIEqual;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.ToLowerAscii) then
    table.Memory.ToLowerAscii := ops.Facade.ToLowerAscii;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.ToLowerAscii := table.Memory.ToLowerAscii;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.ToUpperAscii) then
    table.Memory.ToUpperAscii := ops.Facade.ToUpperAscii;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.ToUpperAscii := table.Memory.ToUpperAscii;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.BytesIndexOf) then
    table.Memory.BytesIndexOf := ops.Facade.BytesIndexOf;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.BytesIndexOf := table.Memory.BytesIndexOf;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.BitsetPopCount) then
    table.Memory.BitsetPopCount := ops.Facade.BitsetPopCount;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.BitsetPopCount := table.Memory.BitsetPopCount;
{$ENDIF}
