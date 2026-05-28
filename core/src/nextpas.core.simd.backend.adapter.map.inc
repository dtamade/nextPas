{
  Generated from nextpas.core.simd.backend.adapter.map.csv.
  Authoritative declarative mapping list for adapter-managed slots.
  Edit the CSV spec and regenerate; do not hand-edit this file.
  Forward:  TSimdBackendOps -> TSimdDispatchTable (with Assigned guard).
  Backward: TSimdDispatchTable -> TSimdBackendOps.
}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x4.Add) then
    table.AddF32x4 := ops.ArithmeticF32x4.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x4.Add := table.AddF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x4.Sub) then
    table.SubF32x4 := ops.ArithmeticF32x4.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x4.Sub := table.SubF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x4.Mul) then
    table.MulF32x4 := ops.ArithmeticF32x4.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x4.Mul := table.MulF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x4.OpDiv) then
    table.DivF32x4 := ops.ArithmeticF32x4.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x4.OpDiv := table.DivF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x8.Add) then
    table.AddF32x8 := ops.ArithmeticF32x8.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x8.Add := table.AddF32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x8.Sub) then
    table.SubF32x8 := ops.ArithmeticF32x8.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x8.Sub := table.SubF32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x8.Mul) then
    table.MulF32x8 := ops.ArithmeticF32x8.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x8.Mul := table.MulF32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x8.OpDiv) then
    table.DivF32x8 := ops.ArithmeticF32x8.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x8.OpDiv := table.DivF32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x2.Add) then
    table.AddF64x2 := ops.ArithmeticF64x2.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x2.Add := table.AddF64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x2.Sub) then
    table.SubF64x2 := ops.ArithmeticF64x2.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x2.Sub := table.SubF64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x2.Mul) then
    table.MulF64x2 := ops.ArithmeticF64x2.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x2.Mul := table.MulF64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x2.OpDiv) then
    table.DivF64x2 := ops.ArithmeticF64x2.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x2.OpDiv := table.DivF64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x4.Add) then
    table.AddF64x4 := ops.ArithmeticF64x4.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x4.Add := table.AddF64x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x4.Sub) then
    table.SubF64x4 := ops.ArithmeticF64x4.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x4.Sub := table.SubF64x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x4.Mul) then
    table.MulF64x4 := ops.ArithmeticF64x4.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x4.Mul := table.MulF64x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x4.OpDiv) then
    table.DivF64x4 := ops.ArithmeticF64x4.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x4.OpDiv := table.DivF64x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x4.Add) then
    table.AddI32x4 := ops.ArithmeticI32x4.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x4.Add := table.AddI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x4.Sub) then
    table.SubI32x4 := ops.ArithmeticI32x4.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x4.Sub := table.SubI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x4.Mul) then
    table.MulI32x4 := ops.ArithmeticI32x4.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x4.Mul := table.MulI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x4.OpAnd) then
    table.AndI32x4 := ops.BitwiseI32x4.OpAnd;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x4.OpAnd := table.AndI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x4.OpOr) then
    table.OrI32x4 := ops.BitwiseI32x4.OpOr;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x4.OpOr := table.OrI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x4.OpXor) then
    table.XorI32x4 := ops.BitwiseI32x4.OpXor;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x4.OpXor := table.XorI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x4.OpNot) then
    table.NotI32x4 := ops.BitwiseI32x4.OpNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x4.OpNot := table.NotI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x4.AndNot) then
    table.AndNotI32x4 := ops.BitwiseI32x4.AndNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x4.AndNot := table.AndNotI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x4.ShiftLeft) then
    table.ShiftLeftI32x4 := ops.ShiftI32x4.ShiftLeft;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x4.ShiftLeft := table.ShiftLeftI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x4.ShiftRight) then
    table.ShiftRightI32x4 := ops.ShiftI32x4.ShiftRight;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x4.ShiftRight := table.ShiftRightI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x4.ShiftRightArith) then
    table.ShiftRightArithI32x4 := ops.ShiftI32x4.ShiftRightArith;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x4.ShiftRightArith := table.ShiftRightArithI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x4.CmpEq) then
    table.CmpEqI32x4 := ops.ComparisonI32x4.CmpEq;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x4.CmpEq := table.CmpEqI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x4.CmpLt) then
    table.CmpLtI32x4 := ops.ComparisonI32x4.CmpLt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x4.CmpLt := table.CmpLtI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x4.CmpGt) then
    table.CmpGtI32x4 := ops.ComparisonI32x4.CmpGt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x4.CmpGt := table.CmpGtI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x4.Min) then
    table.MinI32x4 := ops.MinMaxI32x4.Min;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x4.Min := table.MinI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x4.Max) then
    table.MaxI32x4 := ops.MinMaxI32x4.Max;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x4.Max := table.MaxI32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI64x2.Add) then
    table.AddI64x2 := ops.ArithmeticI64x2.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI64x2.Add := table.AddI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI64x2.Sub) then
    table.SubI64x2 := ops.ArithmeticI64x2.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI64x2.Sub := table.SubI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI64x2.OpAnd) then
    table.AndI64x2 := ops.BitwiseI64x2.OpAnd;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI64x2.OpAnd := table.AndI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI64x2.OpOr) then
    table.OrI64x2 := ops.BitwiseI64x2.OpOr;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI64x2.OpOr := table.OrI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI64x2.OpXor) then
    table.XorI64x2 := ops.BitwiseI64x2.OpXor;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI64x2.OpXor := table.XorI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI64x2.OpNot) then
    table.NotI64x2 := ops.BitwiseI64x2.OpNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI64x2.OpNot := table.NotI64x2;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x8.Add) then
    table.AddI32x8 := ops.ArithmeticI32x8.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x8.Add := table.AddI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x8.Sub) then
    table.SubI32x8 := ops.ArithmeticI32x8.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x8.Sub := table.SubI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x8.Mul) then
    table.MulI32x8 := ops.ArithmeticI32x8.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x8.Mul := table.MulI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x8.OpAnd) then
    table.AndI32x8 := ops.BitwiseI32x8.OpAnd;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x8.OpAnd := table.AndI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x8.OpOr) then
    table.OrI32x8 := ops.BitwiseI32x8.OpOr;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x8.OpOr := table.OrI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x8.OpXor) then
    table.XorI32x8 := ops.BitwiseI32x8.OpXor;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x8.OpXor := table.XorI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x8.OpNot) then
    table.NotI32x8 := ops.BitwiseI32x8.OpNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x8.OpNot := table.NotI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x8.AndNot) then
    table.AndNotI32x8 := ops.BitwiseI32x8.AndNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x8.AndNot := table.AndNotI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x8.ShiftLeft) then
    table.ShiftLeftI32x8 := ops.ShiftI32x8.ShiftLeft;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x8.ShiftLeft := table.ShiftLeftI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x8.ShiftRight) then
    table.ShiftRightI32x8 := ops.ShiftI32x8.ShiftRight;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x8.ShiftRight := table.ShiftRightI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x8.ShiftRightArith) then
    table.ShiftRightArithI32x8 := ops.ShiftI32x8.ShiftRightArith;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x8.ShiftRightArith := table.ShiftRightArithI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x8.CmpEq) then
    table.CmpEqI32x8 := ops.ComparisonI32x8.CmpEq;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x8.CmpEq := table.CmpEqI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x8.CmpLt) then
    table.CmpLtI32x8 := ops.ComparisonI32x8.CmpLt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x8.CmpLt := table.CmpLtI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x8.CmpGt) then
    table.CmpGtI32x8 := ops.ComparisonI32x8.CmpGt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x8.CmpGt := table.CmpGtI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x8.Min) then
    table.MinI32x8 := ops.MinMaxI32x8.Min;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x8.Min := table.MinI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x8.Max) then
    table.MaxI32x8 := ops.MinMaxI32x8.Max;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x8.Max := table.MaxI32x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x16.Add) then
    table.AddF32x16 := ops.ArithmeticF32x16.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x16.Add := table.AddF32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x16.Sub) then
    table.SubF32x16 := ops.ArithmeticF32x16.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x16.Sub := table.SubF32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x16.Mul) then
    table.MulF32x16 := ops.ArithmeticF32x16.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x16.Mul := table.MulF32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF32x16.OpDiv) then
    table.DivF32x16 := ops.ArithmeticF32x16.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF32x16.OpDiv := table.DivF32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x8.Add) then
    table.AddF64x8 := ops.ArithmeticF64x8.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x8.Add := table.AddF64x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x8.Sub) then
    table.SubF64x8 := ops.ArithmeticF64x8.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x8.Sub := table.SubF64x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x8.Mul) then
    table.MulF64x8 := ops.ArithmeticF64x8.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x8.Mul := table.MulF64x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticF64x8.OpDiv) then
    table.DivF64x8 := ops.ArithmeticF64x8.OpDiv;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticF64x8.OpDiv := table.DivF64x8;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x16.Add) then
    table.AddI32x16 := ops.ArithmeticI32x16.Add;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x16.Add := table.AddI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x16.Sub) then
    table.SubI32x16 := ops.ArithmeticI32x16.Sub;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x16.Sub := table.SubI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ArithmeticI32x16.Mul) then
    table.MulI32x16 := ops.ArithmeticI32x16.Mul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ArithmeticI32x16.Mul := table.MulI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x16.OpAnd) then
    table.AndI32x16 := ops.BitwiseI32x16.OpAnd;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x16.OpAnd := table.AndI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x16.OpOr) then
    table.OrI32x16 := ops.BitwiseI32x16.OpOr;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x16.OpOr := table.OrI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x16.OpXor) then
    table.XorI32x16 := ops.BitwiseI32x16.OpXor;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x16.OpXor := table.XorI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x16.OpNot) then
    table.NotI32x16 := ops.BitwiseI32x16.OpNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x16.OpNot := table.NotI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.BitwiseI32x16.AndNot) then
    table.AndNotI32x16 := ops.BitwiseI32x16.AndNot;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.BitwiseI32x16.AndNot := table.AndNotI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x16.ShiftLeft) then
    table.ShiftLeftI32x16 := ops.ShiftI32x16.ShiftLeft;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x16.ShiftLeft := table.ShiftLeftI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x16.ShiftRight) then
    table.ShiftRightI32x16 := ops.ShiftI32x16.ShiftRight;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x16.ShiftRight := table.ShiftRightI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ShiftI32x16.ShiftRightArith) then
    table.ShiftRightArithI32x16 := ops.ShiftI32x16.ShiftRightArith;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ShiftI32x16.ShiftRightArith := table.ShiftRightArithI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x16.CmpEq) then
    table.CmpEqI32x16 := ops.ComparisonI32x16.CmpEq;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x16.CmpEq := table.CmpEqI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x16.CmpLt) then
    table.CmpLtI32x16 := ops.ComparisonI32x16.CmpLt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x16.CmpLt := table.CmpLtI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonI32x16.CmpGt) then
    table.CmpGtI32x16 := ops.ComparisonI32x16.CmpGt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonI32x16.CmpGt := table.CmpGtI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x16.Min) then
    table.MinI32x16 := ops.MinMaxI32x16.Min;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x16.Min := table.MinI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MinMaxI32x16.Max) then
    table.MaxI32x16 := ops.MinMaxI32x16.Max;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MinMaxI32x16.Max := table.MaxI32x16;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpEq) then
    table.CmpEqF32x4 := ops.ComparisonF32x4.CmpEq;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpEq := table.CmpEqF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpLt) then
    table.CmpLtF32x4 := ops.ComparisonF32x4.CmpLt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpLt := table.CmpLtF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpLe) then
    table.CmpLeF32x4 := ops.ComparisonF32x4.CmpLe;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpLe := table.CmpLeF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpGt) then
    table.CmpGtF32x4 := ops.ComparisonF32x4.CmpGt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpGt := table.CmpGtF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpGe) then
    table.CmpGeF32x4 := ops.ComparisonF32x4.CmpGe;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpGe := table.CmpGeF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ComparisonF32x4.CmpNe) then
    table.CmpNeF32x4 := ops.ComparisonF32x4.CmpNe;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ComparisonF32x4.CmpNe := table.CmpNeF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Abs) then
    table.AbsF32x4 := ops.MathF32x4.Abs;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Abs := table.AbsF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Sqrt) then
    table.SqrtF32x4 := ops.MathF32x4.Sqrt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Sqrt := table.SqrtF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Min) then
    table.MinF32x4 := ops.MathF32x4.Min;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Min := table.MinF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Max) then
    table.MaxF32x4 := ops.MathF32x4.Max;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Max := table.MaxF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Fma) then
    table.FmaF32x4 := ops.MathF32x4.Fma;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Fma := table.FmaF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Rcp) then
    table.RcpF32x4 := ops.MathF32x4.Rcp;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Rcp := table.RcpF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Rsqrt) then
    table.RsqrtF32x4 := ops.MathF32x4.Rsqrt;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Rsqrt := table.RsqrtF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Floor) then
    table.FloorF32x4 := ops.MathF32x4.Floor;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Floor := table.FloorF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Ceil) then
    table.CeilF32x4 := ops.MathF32x4.Ceil;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Ceil := table.CeilF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Round) then
    table.RoundF32x4 := ops.MathF32x4.Round;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Round := table.RoundF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Trunc) then
    table.TruncF32x4 := ops.MathF32x4.Trunc;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Trunc := table.TruncF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MathF32x4.Clamp) then
    table.ClampF32x4 := ops.MathF32x4.Clamp;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MathF32x4.Clamp := table.ClampF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Dot4) then
    table.DotF32x4 := ops.VectorMathF32x4.Dot4;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Dot4 := table.DotF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Dot3) then
    table.DotF32x3 := ops.VectorMathF32x4.Dot3;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Dot3 := table.DotF32x3;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Cross3) then
    table.CrossF32x3 := ops.VectorMathF32x4.Cross3;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Cross3 := table.CrossF32x3;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Length4) then
    table.LengthF32x4 := ops.VectorMathF32x4.Length4;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Length4 := table.LengthF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Length3) then
    table.LengthF32x3 := ops.VectorMathF32x4.Length3;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Length3 := table.LengthF32x3;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Normalize4) then
    table.NormalizeF32x4 := ops.VectorMathF32x4.Normalize4;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Normalize4 := table.NormalizeF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.VectorMathF32x4.Normalize3) then
    table.NormalizeF32x3 := ops.VectorMathF32x4.Normalize3;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.VectorMathF32x4.Normalize3 := table.NormalizeF32x3;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ReductionF32x4.ReduceAdd) then
    table.ReduceAddF32x4 := ops.ReductionF32x4.ReduceAdd;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ReductionF32x4.ReduceAdd := table.ReduceAddF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ReductionF32x4.ReduceMin) then
    table.ReduceMinF32x4 := ops.ReductionF32x4.ReduceMin;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ReductionF32x4.ReduceMin := table.ReduceMinF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ReductionF32x4.ReduceMax) then
    table.ReduceMaxF32x4 := ops.ReductionF32x4.ReduceMax;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ReductionF32x4.ReduceMax := table.ReduceMaxF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.ReductionF32x4.ReduceMul) then
    table.ReduceMulF32x4 := ops.ReductionF32x4.ReduceMul;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.ReductionF32x4.ReduceMul := table.ReduceMulF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Load) then
    table.LoadF32x4 := ops.MemoryF32x4.Load;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Load := table.LoadF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.LoadAligned) then
    table.LoadF32x4Aligned := ops.MemoryF32x4.LoadAligned;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.LoadAligned := table.LoadF32x4Aligned;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Store) then
    table.StoreF32x4 := ops.MemoryF32x4.Store;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Store := table.StoreF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.StoreAligned) then
    table.StoreF32x4Aligned := ops.MemoryF32x4.StoreAligned;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.StoreAligned := table.StoreF32x4Aligned;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Splat) then
    table.SplatF32x4 := ops.MemoryF32x4.Splat;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Splat := table.SplatF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Zero) then
    table.ZeroF32x4 := ops.MemoryF32x4.Zero;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Zero := table.ZeroF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Select) then
    table.SelectF32x4 := ops.MemoryF32x4.Select;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Select := table.SelectF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Extract) then
    table.ExtractF32x4 := ops.MemoryF32x4.Extract;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Extract := table.ExtractF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.MemoryF32x4.Insert) then
    table.InsertF32x4 := ops.MemoryF32x4.Insert;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.MemoryF32x4.Insert := table.InsertF32x4;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemEqual) then
    table.MemEqual := ops.Facade.MemEqual;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemEqual := table.MemEqual;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemFindByte) then
    table.MemFindByte := ops.Facade.MemFindByte;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemFindByte := table.MemFindByte;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemDiffRange) then
    table.MemDiffRange := ops.Facade.MemDiffRange;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemDiffRange := table.MemDiffRange;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemCopy) then
    table.MemCopy := ops.Facade.MemCopy;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemCopy := table.MemCopy;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemSet) then
    table.MemSet := ops.Facade.MemSet;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemSet := table.MemSet;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MemReverse) then
    table.MemReverse := ops.Facade.MemReverse;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MemReverse := table.MemReverse;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.SumBytes) then
    table.SumBytes := ops.Facade.SumBytes;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.SumBytes := table.SumBytes;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.MinMaxBytes) then
    table.MinMaxBytes := ops.Facade.MinMaxBytes;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.MinMaxBytes := table.MinMaxBytes;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.CountByte) then
    table.CountByte := ops.Facade.CountByte;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.CountByte := table.CountByte;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.Utf8Validate) then
    table.Utf8Validate := ops.Facade.Utf8Validate;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.Utf8Validate := table.Utf8Validate;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.AsciiIEqual) then
    table.AsciiIEqual := ops.Facade.AsciiIEqual;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.AsciiIEqual := table.AsciiIEqual;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.ToLowerAscii) then
    table.ToLowerAscii := ops.Facade.ToLowerAscii;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.ToLowerAscii := table.ToLowerAscii;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.ToUpperAscii) then
    table.ToUpperAscii := ops.Facade.ToUpperAscii;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.ToUpperAscii := table.ToUpperAscii;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.BytesIndexOf) then
    table.BytesIndexOf := ops.Facade.BytesIndexOf;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.BytesIndexOf := table.BytesIndexOf;
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  if Assigned(ops.Facade.BitsetPopCount) then
    table.BitsetPopCount := ops.Facade.BitsetPopCount;
{$ENDIF}
{$IFDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  ops.Facade.BitsetPopCount := table.BitsetPopCount;
{$ENDIF}
