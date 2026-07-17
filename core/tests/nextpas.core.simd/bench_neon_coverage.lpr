program bench_neon_coverage;

{$mode objfpc}{$H+}

{**
  G21: NEON Dispatch Table Coverage Benchmark
  列出 dispatch table 所有操作槽位，报告 NEON 后端覆盖度。
  Reports how many function-pointer slots in the NEON dispatch table
  are wired (non-nil) vs still falling back to scalar.
*}

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.cpuinfo;

type
  TSlotCheck = record
    Name: PAnsiChar;
    Ptr: Pointer;
  end;

{**
  CountPointerFields
  Iterates over the dispatch table's function-pointer fields and
  reports coverage statistics.  FreePascal has no reflection, so
  we enumerate the slot-sized fields explicitly using a flat array
  of record-of-pointer descriptors.
*}
procedure CountPointerFields(const aTbl: TSimdDispatchTable;
  const aName: PAnsiChar);
var
  i: Integer;
  total, covered: Integer;
  slots: array[0..511] of TSlotCheck;  // large enough for the table
  n: Integer;

  procedure Add(const aSlotName: PAnsiChar; const aPtr: Pointer);
  begin
    if n >= High(slots) then Exit;
    slots[n].Name := aSlotName;
    slots[n].Ptr := aPtr;
    Inc(n);
  end;

begin
  n := 0;
  total := 0;
  covered := 0;

  // ── F32x4 arithmetic ──
  Add('AddF32x4',              Pointer(aTbl.CoreVectors.AddF32x4));
  Add('SubF32x4',              Pointer(aTbl.CoreVectors.SubF32x4));
  Add('MulF32x4',              Pointer(aTbl.CoreVectors.MulF32x4));
  Add('DivF32x4',              Pointer(aTbl.CoreVectors.DivF32x4));

  // ── F32x8 arithmetic ──
  Add('AddF32x8',              Pointer(aTbl.CoreVectors.AddF32x8));
  Add('SubF32x8',              Pointer(aTbl.CoreVectors.SubF32x8));
  Add('MulF32x8',              Pointer(aTbl.CoreVectors.MulF32x8));
  Add('DivF32x8',              Pointer(aTbl.CoreVectors.DivF32x8));

  // ── F64x2 arithmetic ──
  Add('AddF64x2',              Pointer(aTbl.CoreVectors.AddF64x2));
  Add('SubF64x2',              Pointer(aTbl.CoreVectors.SubF64x2));
  Add('MulF64x2',              Pointer(aTbl.CoreVectors.MulF64x2));
  Add('DivF64x2',              Pointer(aTbl.CoreVectors.DivF64x2));

  // ── I32x4 ──
  Add('AddI32x4',              Pointer(aTbl.CoreVectors.AddI32x4));
  Add('SubI32x4',              Pointer(aTbl.CoreVectors.SubI32x4));
  Add('MulI32x4',              Pointer(aTbl.CoreVectors.MulI32x4));
  Add('AndI32x4',              Pointer(aTbl.CoreVectors.AndI32x4));
  Add('OrI32x4',               Pointer(aTbl.CoreVectors.OrI32x4));
  Add('XorI32x4',              Pointer(aTbl.CoreVectors.XorI32x4));
  Add('NotI32x4',              Pointer(aTbl.CoreVectors.NotI32x4));
  Add('AndNotI32x4',           Pointer(aTbl.CoreVectors.AndNotI32x4));
  Add('ShiftLeftI32x4',        Pointer(aTbl.CoreVectors.ShiftLeftI32x4));
  Add('ShiftRightI32x4',       Pointer(aTbl.CoreVectors.ShiftRightI32x4));
  Add('ShiftRightArithI32x4',  Pointer(aTbl.CoreVectors.ShiftRightArithI32x4));
  Add('CmpEqI32x4',            Pointer(aTbl.CoreVectors.CmpEqI32x4));
  Add('CmpLtI32x4',            Pointer(aTbl.CoreVectors.CmpLtI32x4));
  Add('CmpGtI32x4',            Pointer(aTbl.CoreVectors.CmpGtI32x4));
  Add('CmpLeI32x4',            Pointer(aTbl.CoreVectors.CmpLeI32x4));
  Add('CmpGeI32x4',            Pointer(aTbl.CoreVectors.CmpGeI32x4));
  Add('CmpNeI32x4',            Pointer(aTbl.CoreVectors.CmpNeI32x4));
  Add('MinI32x4',              Pointer(aTbl.CoreVectors.MinI32x4));
  Add('MaxI32x4',              Pointer(aTbl.CoreVectors.MaxI32x4));

  // ── I64x2 ──
  Add('AddI64x2',              Pointer(aTbl.CoreVectors.AddI64x2));
  Add('SubI64x2',              Pointer(aTbl.CoreVectors.SubI64x2));
  Add('AndI64x2',              Pointer(aTbl.CoreVectors.AndI64x2));
  Add('OrI64x2',               Pointer(aTbl.CoreVectors.OrI64x2));
  Add('XorI64x2',              Pointer(aTbl.CoreVectors.XorI64x2));
  Add('NotI64x2',              Pointer(aTbl.CoreVectors.NotI64x2));
  Add('AndNotI64x2',           Pointer(aTbl.CoreVectors.AndNotI64x2));
  Add('ShiftLeftI64x2',        Pointer(aTbl.CoreVectors.ShiftLeftI64x2));
  Add('ShiftRightI64x2',       Pointer(aTbl.CoreVectors.ShiftRightI64x2));
  Add('ShiftRightArithI64x2',  Pointer(aTbl.CoreVectors.ShiftRightArithI64x2));
  Add('CmpEqI64x2',            Pointer(aTbl.CoreVectors.CmpEqI64x2));
  Add('CmpLtI64x2',            Pointer(aTbl.CoreVectors.CmpLtI64x2));
  Add('CmpGtI64x2',            Pointer(aTbl.CoreVectors.CmpGtI64x2));
  Add('CmpLeI64x2',            Pointer(aTbl.CoreVectors.CmpLeI64x2));
  Add('CmpGeI64x2',            Pointer(aTbl.CoreVectors.CmpGeI64x2));
  Add('CmpNeI64x2',            Pointer(aTbl.CoreVectors.CmpNeI64x2));
  Add('MinI64x2',              Pointer(aTbl.CoreVectors.MinI64x2));
  Add('MaxI64x2',              Pointer(aTbl.CoreVectors.MaxI64x2));

  // ── U64x2 ──
  Add('AddU64x2',              Pointer(aTbl.CoreVectors.AddU64x2));
  Add('SubU64x2',              Pointer(aTbl.CoreVectors.SubU64x2));
  Add('AndU64x2',              Pointer(aTbl.CoreVectors.AndU64x2));
  Add('OrU64x2',               Pointer(aTbl.CoreVectors.OrU64x2));
  Add('XorU64x2',              Pointer(aTbl.CoreVectors.XorU64x2));
  Add('NotU64x2',              Pointer(aTbl.CoreVectors.NotU64x2));
  Add('AndNotU64x2',           Pointer(aTbl.CoreVectors.AndNotU64x2));
  Add('CmpEqU64x2',            Pointer(aTbl.CoreVectors.CmpEqU64x2));
  Add('CmpLtU64x2',            Pointer(aTbl.CoreVectors.CmpLtU64x2));
  Add('CmpGtU64x2',            Pointer(aTbl.CoreVectors.CmpGtU64x2));
  Add('MinU64x2',              Pointer(aTbl.CoreVectors.MinU64x2));
  Add('MaxU64x2',              Pointer(aTbl.CoreVectors.MaxU64x2));

  // ── F64x4 ──
  Add('AddF64x4',              Pointer(aTbl.CoreVectors.AddF64x4));
  Add('SubF64x4',              Pointer(aTbl.CoreVectors.SubF64x4));
  Add('MulF64x4',              Pointer(aTbl.CoreVectors.MulF64x4));
  Add('DivF64x4',              Pointer(aTbl.CoreVectors.DivF64x4));

  // ── I32x8 ──
  Add('AddI32x8',              Pointer(aTbl.CoreVectors.AddI32x8));
  Add('SubI32x8',              Pointer(aTbl.CoreVectors.SubI32x8));
  Add('MulI32x8',              Pointer(aTbl.CoreVectors.MulI32x8));
  Add('AndI32x8',              Pointer(aTbl.CoreVectors.AndI32x8));
  Add('OrI32x8',               Pointer(aTbl.CoreVectors.OrI32x8));
  Add('XorI32x8',              Pointer(aTbl.CoreVectors.XorI32x8));
  Add('NotI32x8',              Pointer(aTbl.CoreVectors.NotI32x8));
  Add('AndNotI32x8',           Pointer(aTbl.CoreVectors.AndNotI32x8));
  Add('ShiftLeftI32x8',        Pointer(aTbl.CoreVectors.ShiftLeftI32x8));
  Add('ShiftRightI32x8',       Pointer(aTbl.CoreVectors.ShiftRightI32x8));
  Add('ShiftRightArithI32x8',  Pointer(aTbl.CoreVectors.ShiftRightArithI32x8));
  Add('CmpEqI32x8',            Pointer(aTbl.CoreVectors.CmpEqI32x8));
  Add('CmpLtI32x8',            Pointer(aTbl.CoreVectors.CmpLtI32x8));
  Add('CmpGtI32x8',            Pointer(aTbl.CoreVectors.CmpGtI32x8));
  Add('CmpLeI32x8',            Pointer(aTbl.CoreVectors.CmpLeI32x8));
  Add('CmpGeI32x8',            Pointer(aTbl.CoreVectors.CmpGeI32x8));
  Add('CmpNeI32x8',            Pointer(aTbl.CoreVectors.CmpNeI32x8));
  Add('MinI32x8',              Pointer(aTbl.CoreVectors.MinI32x8));
  Add('MaxI32x8',              Pointer(aTbl.CoreVectors.MaxI32x8));

  // ── I64x4 ──
  Add('AddI64x4',              Pointer(aTbl.CoreVectors.AddI64x4));
  Add('SubI64x4',              Pointer(aTbl.CoreVectors.SubI64x4));
  Add('AndI64x4',              Pointer(aTbl.CoreVectors.AndI64x4));
  Add('OrI64x4',               Pointer(aTbl.CoreVectors.OrI64x4));
  Add('XorI64x4',              Pointer(aTbl.CoreVectors.XorI64x4));
  Add('NotI64x4',              Pointer(aTbl.CoreVectors.NotI64x4));
  Add('AndNotI64x4',           Pointer(aTbl.CoreVectors.AndNotI64x4));
  Add('ShiftLeftI64x4',        Pointer(aTbl.CoreVectors.ShiftLeftI64x4));
  Add('ShiftRightI64x4',       Pointer(aTbl.CoreVectors.ShiftRightI64x4));
  Add('ShiftRightArithI64x4',  Pointer(aTbl.CoreVectors.ShiftRightArithI64x4));
  Add('CmpEqI64x4',            Pointer(aTbl.CoreVectors.CmpEqI64x4));
  Add('CmpLtI64x4',            Pointer(aTbl.CoreVectors.CmpLtI64x4));
  Add('CmpGtI64x4',            Pointer(aTbl.CoreVectors.CmpGtI64x4));
  Add('CmpLeI64x4',            Pointer(aTbl.CoreVectors.CmpLeI64x4));
  Add('CmpGeI64x4',            Pointer(aTbl.CoreVectors.CmpGeI64x4));
  Add('CmpNeI64x4',            Pointer(aTbl.CoreVectors.CmpNeI64x4));
  Add('LoadI64x4',             Pointer(aTbl.CoreVectors.LoadI64x4));
  Add('StoreI64x4',            Pointer(aTbl.CoreVectors.StoreI64x4));
  Add('SplatI64x4',            Pointer(aTbl.CoreVectors.SplatI64x4));
  Add('ZeroI64x4',             Pointer(aTbl.CoreVectors.ZeroI64x4));

  // ── U32x8 ──
  Add('AddU32x8',              Pointer(aTbl.CoreVectors.AddU32x8));
  Add('SubU32x8',              Pointer(aTbl.CoreVectors.SubU32x8));
  Add('MulU32x8',              Pointer(aTbl.CoreVectors.MulU32x8));
  Add('AndU32x8',              Pointer(aTbl.CoreVectors.AndU32x8));
  Add('OrU32x8',               Pointer(aTbl.CoreVectors.OrU32x8));
  Add('XorU32x8',              Pointer(aTbl.CoreVectors.XorU32x8));
  Add('NotU32x8',              Pointer(aTbl.CoreVectors.NotU32x8));
  Add('AndNotU32x8',           Pointer(aTbl.CoreVectors.AndNotU32x8));
  Add('ShiftLeftU32x8',        Pointer(aTbl.CoreVectors.ShiftLeftU32x8));
  Add('ShiftRightU32x8',       Pointer(aTbl.CoreVectors.ShiftRightU32x8));
  Add('CmpEqU32x8',            Pointer(aTbl.CoreVectors.CmpEqU32x8));
  Add('CmpLtU32x8',            Pointer(aTbl.CoreVectors.CmpLtU32x8));
  Add('CmpGtU32x8',            Pointer(aTbl.CoreVectors.CmpGtU32x8));
  Add('CmpLeU32x8',            Pointer(aTbl.CoreVectors.CmpLeU32x8));
  Add('CmpGeU32x8',            Pointer(aTbl.CoreVectors.CmpGeU32x8));
  Add('CmpNeU32x8',            Pointer(aTbl.CoreVectors.CmpNeU32x8));
  Add('MinU32x8',              Pointer(aTbl.CoreVectors.MinU32x8));
  Add('MaxU32x8',              Pointer(aTbl.CoreVectors.MaxU32x8));

  // ── U64x4 ──
  Add('AddU64x4',              Pointer(aTbl.CoreVectors.AddU64x4));
  Add('SubU64x4',              Pointer(aTbl.CoreVectors.SubU64x4));
  Add('AndU64x4',              Pointer(aTbl.CoreVectors.AndU64x4));
  Add('OrU64x4',               Pointer(aTbl.CoreVectors.OrU64x4));
  Add('XorU64x4',              Pointer(aTbl.CoreVectors.XorU64x4));
  Add('NotU64x4',              Pointer(aTbl.CoreVectors.NotU64x4));
  Add('ShiftLeftU64x4',        Pointer(aTbl.CoreVectors.ShiftLeftU64x4));
  Add('ShiftRightU64x4',       Pointer(aTbl.CoreVectors.ShiftRightU64x4));
  Add('CmpEqU64x4',            Pointer(aTbl.CoreVectors.CmpEqU64x4));
  Add('CmpLtU64x4',            Pointer(aTbl.CoreVectors.CmpLtU64x4));
  Add('CmpGtU64x4',            Pointer(aTbl.CoreVectors.CmpGtU64x4));
  Add('CmpLeU64x4',            Pointer(aTbl.CoreVectors.CmpLeU64x4));
  Add('CmpGeU64x4',            Pointer(aTbl.CoreVectors.CmpGeU64x4));
  Add('CmpNeU64x4',            Pointer(aTbl.CoreVectors.CmpNeU64x4));

  // ── RcpF64x4 ──
  Add('RcpF64x4',              Pointer(aTbl.CoreVectors.RcpF64x4));

  // ── I32x16 ──
  Add('AddI32x16',             Pointer(aTbl.CoreVectors.AddI32x16));
  Add('SubI32x16',             Pointer(aTbl.CoreVectors.SubI32x16));
  Add('MulI32x16',             Pointer(aTbl.CoreVectors.MulI32x16));
  Add('AndI32x16',             Pointer(aTbl.CoreVectors.AndI32x16));
  Add('OrI32x16',              Pointer(aTbl.CoreVectors.OrI32x16));
  Add('XorI32x16',             Pointer(aTbl.CoreVectors.XorI32x16));
  Add('NotI32x16',             Pointer(aTbl.CoreVectors.NotI32x16));
  Add('AndNotI32x16',          Pointer(aTbl.CoreVectors.AndNotI32x16));
  Add('ShiftLeftI32x16',       Pointer(aTbl.CoreVectors.ShiftLeftI32x16));
  Add('ShiftRightI32x16',      Pointer(aTbl.CoreVectors.ShiftRightI32x16));
  Add('ShiftRightArithI32x16', Pointer(aTbl.CoreVectors.ShiftRightArithI32x16));
  Add('CmpEqI32x16',           Pointer(aTbl.CoreVectors.CmpEqI32x16));
  Add('CmpLtI32x16',           Pointer(aTbl.CoreVectors.CmpLtI32x16));
  Add('CmpGtI32x16',           Pointer(aTbl.CoreVectors.CmpGtI32x16));
  Add('CmpLeI32x16',           Pointer(aTbl.CoreVectors.CmpLeI32x16));
  Add('CmpGeI32x16',           Pointer(aTbl.CoreVectors.CmpGeI32x16));
  Add('CmpNeI32x16',           Pointer(aTbl.CoreVectors.CmpNeI32x16));
  Add('MinI32x16',             Pointer(aTbl.CoreVectors.MinI32x16));
  Add('MaxI32x16',             Pointer(aTbl.CoreVectors.MaxI32x16));

  // ── I64x8 ──
  Add('AddI64x8',              Pointer(aTbl.CoreVectors.AddI64x8));
  Add('SubI64x8',              Pointer(aTbl.CoreVectors.SubI64x8));
  Add('AndI64x8',              Pointer(aTbl.CoreVectors.AndI64x8));
  Add('OrI64x8',               Pointer(aTbl.CoreVectors.OrI64x8));
  Add('XorI64x8',              Pointer(aTbl.CoreVectors.XorI64x8));
  Add('NotI64x8',              Pointer(aTbl.CoreVectors.NotI64x8));
  Add('CmpEqI64x8',            Pointer(aTbl.CoreVectors.CmpEqI64x8));
  Add('CmpLtI64x8',            Pointer(aTbl.CoreVectors.CmpLtI64x8));
  Add('CmpGtI64x8',            Pointer(aTbl.CoreVectors.CmpGtI64x8));
  Add('CmpLeI64x8',            Pointer(aTbl.CoreVectors.CmpLeI64x8));
  Add('CmpGeI64x8',            Pointer(aTbl.CoreVectors.CmpGeI64x8));
  Add('CmpNeI64x8',            Pointer(aTbl.CoreVectors.CmpNeI64x8));

  // ── U32x16 ──
  Add('AddU32x16',             Pointer(aTbl.CoreVectors.AddU32x16));
  Add('SubU32x16',             Pointer(aTbl.CoreVectors.SubU32x16));
  Add('MulU32x16',             Pointer(aTbl.CoreVectors.MulU32x16));
  Add('AndU32x16',             Pointer(aTbl.CoreVectors.AndU32x16));
  Add('OrU32x16',              Pointer(aTbl.CoreVectors.OrU32x16));
  Add('XorU32x16',             Pointer(aTbl.CoreVectors.XorU32x16));
  Add('NotU32x16',             Pointer(aTbl.CoreVectors.NotU32x16));
  Add('AndNotU32x16',          Pointer(aTbl.CoreVectors.AndNotU32x16));
  Add('ShiftLeftU32x16',       Pointer(aTbl.CoreVectors.ShiftLeftU32x16));
  Add('ShiftRightU32x16',      Pointer(aTbl.CoreVectors.ShiftRightU32x16));
  Add('CmpEqU32x16',           Pointer(aTbl.CoreVectors.CmpEqU32x16));
  Add('CmpLtU32x16',           Pointer(aTbl.CoreVectors.CmpLtU32x16));
  Add('CmpGtU32x16',           Pointer(aTbl.CoreVectors.CmpGtU32x16));
  Add('CmpLeU32x16',           Pointer(aTbl.CoreVectors.CmpLeU32x16));
  Add('CmpGeU32x16',           Pointer(aTbl.CoreVectors.CmpGeU32x16));
  Add('CmpNeU32x16',           Pointer(aTbl.CoreVectors.CmpNeU32x16));
  Add('MinU32x16',             Pointer(aTbl.CoreVectors.MinU32x16));
  Add('MaxU32x16',             Pointer(aTbl.CoreVectors.MaxU32x16));

  // ── U64x8 ──
  Add('AddU64x8',              Pointer(aTbl.CoreVectors.AddU64x8));
  Add('SubU64x8',              Pointer(aTbl.CoreVectors.SubU64x8));
  Add('AndU64x8',              Pointer(aTbl.CoreVectors.AndU64x8));
  Add('OrU64x8',               Pointer(aTbl.CoreVectors.OrU64x8));
  Add('XorU64x8',              Pointer(aTbl.CoreVectors.XorU64x8));
  Add('NotU64x8',              Pointer(aTbl.CoreVectors.NotU64x8));
  Add('ShiftLeftU64x8',        Pointer(aTbl.CoreVectors.ShiftLeftU64x8));
  Add('ShiftRightU64x8',       Pointer(aTbl.CoreVectors.ShiftRightU64x8));
  Add('CmpEqU64x8',            Pointer(aTbl.CoreVectors.CmpEqU64x8));
  Add('CmpLtU64x8',            Pointer(aTbl.CoreVectors.CmpLtU64x8));
  Add('CmpGtU64x8',            Pointer(aTbl.CoreVectors.CmpGtU64x8));
  Add('CmpLeU64x8',            Pointer(aTbl.CoreVectors.CmpLeU64x8));
  Add('CmpGeU64x8',            Pointer(aTbl.CoreVectors.CmpGeU64x8));
  Add('CmpNeU64x8',            Pointer(aTbl.CoreVectors.CmpNeU64x8));

  // ── I16x32 ──
  Add('AddI16x32',             Pointer(aTbl.CoreVectors.AddI16x32));
  Add('SubI16x32',             Pointer(aTbl.CoreVectors.SubI16x32));
  Add('AndI16x32',             Pointer(aTbl.CoreVectors.AndI16x32));
  Add('OrI16x32',              Pointer(aTbl.CoreVectors.OrI16x32));
  Add('XorI16x32',             Pointer(aTbl.CoreVectors.XorI16x32));
  Add('NotI16x32',             Pointer(aTbl.CoreVectors.NotI16x32));
  Add('AndNotI16x32',          Pointer(aTbl.CoreVectors.AndNotI16x32));
  Add('ShiftLeftI16x32',       Pointer(aTbl.CoreVectors.ShiftLeftI16x32));
  Add('ShiftRightI16x32',      Pointer(aTbl.CoreVectors.ShiftRightI16x32));
  Add('ShiftRightArithI16x32', Pointer(aTbl.CoreVectors.ShiftRightArithI16x32));
  Add('CmpEqI16x32',           Pointer(aTbl.CoreVectors.CmpEqI16x32));
  Add('CmpLtI16x32',           Pointer(aTbl.CoreVectors.CmpLtI16x32));
  Add('CmpGtI16x32',           Pointer(aTbl.CoreVectors.CmpGtI16x32));
  Add('MinI16x32',             Pointer(aTbl.CoreVectors.MinI16x32));
  Add('MaxI16x32',             Pointer(aTbl.CoreVectors.MaxI16x32));

  // ── I8x64 ──
  Add('AddI8x64',              Pointer(aTbl.CoreVectors.AddI8x64));
  Add('SubI8x64',              Pointer(aTbl.CoreVectors.SubI8x64));
  Add('AndI8x64',              Pointer(aTbl.CoreVectors.AndI8x64));
  Add('OrI8x64',               Pointer(aTbl.CoreVectors.OrI8x64));
  Add('XorI8x64',              Pointer(aTbl.CoreVectors.XorI8x64));
  Add('NotI8x64',              Pointer(aTbl.CoreVectors.NotI8x64));
  Add('AndNotI8x64',           Pointer(aTbl.CoreVectors.AndNotI8x64));
  Add('CmpEqI8x64',            Pointer(aTbl.CoreVectors.CmpEqI8x64));
  Add('CmpLtI8x64',            Pointer(aTbl.CoreVectors.CmpLtI8x64));
  Add('CmpGtI8x64',            Pointer(aTbl.CoreVectors.CmpGtI8x64));
  Add('MinI8x64',              Pointer(aTbl.CoreVectors.MinI8x64));
  Add('MaxI8x64',              Pointer(aTbl.CoreVectors.MaxI8x64));

  // ── U8x64 ──
  Add('AddU8x64',              Pointer(aTbl.CoreVectors.AddU8x64));
  Add('SubU8x64',              Pointer(aTbl.CoreVectors.SubU8x64));
  Add('AndU8x64',              Pointer(aTbl.CoreVectors.AndU8x64));
  Add('OrU8x64',               Pointer(aTbl.CoreVectors.OrU8x64));
  Add('XorU8x64',              Pointer(aTbl.CoreVectors.XorU8x64));
  Add('NotU8x64',              Pointer(aTbl.CoreVectors.NotU8x64));
  Add('CmpEqU8x64',            Pointer(aTbl.CoreVectors.CmpEqU8x64));
  Add('CmpLtU8x64',            Pointer(aTbl.CoreVectors.CmpLtU8x64));
  Add('CmpGtU8x64',            Pointer(aTbl.CoreVectors.CmpGtU8x64));
  Add('MinU8x64',              Pointer(aTbl.CoreVectors.MinU8x64));
  Add('MaxU8x64',              Pointer(aTbl.CoreVectors.MaxU8x64));

  // ── F32x16 ──
  Add('AddF32x16',             Pointer(aTbl.CoreVectors.AddF32x16));
  Add('SubF32x16',             Pointer(aTbl.CoreVectors.SubF32x16));
  Add('MulF32x16',             Pointer(aTbl.CoreVectors.MulF32x16));
  Add('DivF32x16',             Pointer(aTbl.CoreVectors.DivF32x16));

  // ── F64x8 ──
  Add('AddF64x8',              Pointer(aTbl.CoreVectors.AddF64x8));
  Add('SubF64x8',              Pointer(aTbl.CoreVectors.SubF64x8));
  Add('MulF64x8',              Pointer(aTbl.CoreVectors.MulF64x8));
  Add('DivF64x8',              Pointer(aTbl.CoreVectors.DivF64x8));

  // ── Comparison operations ──
  Add('CmpEqF32x4',            Pointer(aTbl.CoreVectors.CmpEqF32x4));
  Add('CmpLtF32x4',            Pointer(aTbl.CoreVectors.CmpLtF32x4));
  Add('CmpLeF32x4',            Pointer(aTbl.CoreVectors.CmpLeF32x4));
  Add('CmpGtF32x4',            Pointer(aTbl.CoreVectors.CmpGtF32x4));
  Add('CmpGeF32x4',            Pointer(aTbl.CoreVectors.CmpGeF32x4));
  Add('CmpNeF32x4',            Pointer(aTbl.CoreVectors.CmpNeF32x4));

  Add('CmpEqF64x2',            Pointer(aTbl.CoreVectors.CmpEqF64x2));
  Add('CmpLtF64x2',            Pointer(aTbl.CoreVectors.CmpLtF64x2));
  Add('CmpLeF64x2',            Pointer(aTbl.CoreVectors.CmpLeF64x2));
  Add('CmpGtF64x2',            Pointer(aTbl.CoreVectors.CmpGtF64x2));
  Add('CmpGeF64x2',            Pointer(aTbl.CoreVectors.CmpGeF64x2));
  Add('CmpNeF64x2',            Pointer(aTbl.CoreVectors.CmpNeF64x2));

  Add('CmpEqF32x16',           Pointer(aTbl.CoreVectors.CmpEqF32x16));
  Add('CmpLtF32x16',           Pointer(aTbl.CoreVectors.CmpLtF32x16));
  Add('CmpLeF32x16',           Pointer(aTbl.CoreVectors.CmpLeF32x16));
  Add('CmpGtF32x16',           Pointer(aTbl.CoreVectors.CmpGtF32x16));
  Add('CmpGeF32x16',           Pointer(aTbl.CoreVectors.CmpGeF32x16));
  Add('CmpNeF32x16',           Pointer(aTbl.CoreVectors.CmpNeF32x16));

  Add('CmpEqF64x8',            Pointer(aTbl.CoreVectors.CmpEqF64x8));
  Add('CmpLtF64x8',            Pointer(aTbl.CoreVectors.CmpLtF64x8));
  Add('CmpLeF64x8',            Pointer(aTbl.CoreVectors.CmpLeF64x8));
  Add('CmpGtF64x8',            Pointer(aTbl.CoreVectors.CmpGtF64x8));
  Add('CmpGeF64x8',            Pointer(aTbl.CoreVectors.CmpGeF64x8));
  Add('CmpNeF64x8',            Pointer(aTbl.CoreVectors.CmpNeF64x8));

  Add('CmpEqF32x8',            Pointer(aTbl.CoreVectors.CmpEqF32x8));
  Add('CmpLtF32x8',            Pointer(aTbl.CoreVectors.CmpLtF32x8));
  Add('CmpLeF32x8',            Pointer(aTbl.CoreVectors.CmpLeF32x8));
  Add('CmpGtF32x8',            Pointer(aTbl.CoreVectors.CmpGtF32x8));
  Add('CmpGeF32x8',            Pointer(aTbl.CoreVectors.CmpGeF32x8));
  Add('CmpNeF32x8',            Pointer(aTbl.CoreVectors.CmpNeF32x8));

  Add('CmpEqF64x4',            Pointer(aTbl.CoreVectors.CmpEqF64x4));
  Add('CmpLtF64x4',            Pointer(aTbl.CoreVectors.CmpLtF64x4));
  Add('CmpLeF64x4',            Pointer(aTbl.CoreVectors.CmpLeF64x4));
  Add('CmpGtF64x4',            Pointer(aTbl.CoreVectors.CmpGtF64x4));
  Add('CmpGeF64x4',            Pointer(aTbl.CoreVectors.CmpGeF64x4));
  Add('CmpNeF64x4',            Pointer(aTbl.CoreVectors.CmpNeF64x4));

  // ── Math functions ──
  Add('AbsF32x4',              Pointer(aTbl.CoreVectors.AbsF32x4));
  Add('SqrtF32x4',             Pointer(aTbl.CoreVectors.SqrtF32x4));
  Add('MinF32x4',              Pointer(aTbl.CoreVectors.MinF32x4));
  Add('MaxF32x4',              Pointer(aTbl.CoreVectors.MaxF32x4));

  // ── Extended math ──
  Add('FmaF32x4',              Pointer(aTbl.CoreVectors.FmaF32x4));
  Add('RcpF32x4',              Pointer(aTbl.CoreVectors.RcpF32x4));
  Add('RsqrtF32x4',            Pointer(aTbl.CoreVectors.RsqrtF32x4));
  Add('FloorF32x4',            Pointer(aTbl.CoreVectors.FloorF32x4));
  Add('CeilF32x4',             Pointer(aTbl.CoreVectors.CeilF32x4));
  Add('RoundF32x4',            Pointer(aTbl.CoreVectors.RoundF32x4));
  Add('TruncF32x4',            Pointer(aTbl.CoreVectors.TruncF32x4));
  Add('ClampF32x4',            Pointer(aTbl.CoreVectors.ClampF32x4));

  // ── Wide vector extended math ──
  Add('FmaF64x2',              Pointer(aTbl.CoreVectors.FmaF64x2));
  Add('FloorF64x2',            Pointer(aTbl.CoreVectors.FloorF64x2));
  Add('CeilF64x2',             Pointer(aTbl.CoreVectors.CeilF64x2));
  Add('RoundF64x2',            Pointer(aTbl.CoreVectors.RoundF64x2));
  Add('TruncF64x2',            Pointer(aTbl.CoreVectors.TruncF64x2));
  Add('AbsF64x2',              Pointer(aTbl.CoreVectors.AbsF64x2));
  Add('SqrtF64x2',             Pointer(aTbl.CoreVectors.SqrtF64x2));
  Add('MinF64x2',              Pointer(aTbl.CoreVectors.MinF64x2));
  Add('MaxF64x2',              Pointer(aTbl.CoreVectors.MaxF64x2));
  Add('ClampF64x2',            Pointer(aTbl.CoreVectors.ClampF64x2));

  Add('FmaF32x8',              Pointer(aTbl.CoreVectors.FmaF32x8));
  Add('FloorF32x8',            Pointer(aTbl.CoreVectors.FloorF32x8));
  Add('CeilF32x8',             Pointer(aTbl.CoreVectors.CeilF32x8));
  Add('RoundF32x8',            Pointer(aTbl.CoreVectors.RoundF32x8));
  Add('TruncF32x8',            Pointer(aTbl.CoreVectors.TruncF32x8));
  Add('AbsF32x8',              Pointer(aTbl.CoreVectors.AbsF32x8));
  Add('SqrtF32x8',             Pointer(aTbl.CoreVectors.SqrtF32x8));
  Add('MinF32x8',              Pointer(aTbl.CoreVectors.MinF32x8));
  Add('MaxF32x8',              Pointer(aTbl.CoreVectors.MaxF32x8));
  Add('ClampF32x8',            Pointer(aTbl.CoreVectors.ClampF32x8));

  Add('FmaF64x4',              Pointer(aTbl.CoreVectors.FmaF64x4));
  Add('FloorF64x4',            Pointer(aTbl.CoreVectors.FloorF64x4));
  Add('CeilF64x4',             Pointer(aTbl.CoreVectors.CeilF64x4));
  Add('RoundF64x4',            Pointer(aTbl.CoreVectors.RoundF64x4));
  Add('TruncF64x4',            Pointer(aTbl.CoreVectors.TruncF64x4));
  Add('AbsF64x4',              Pointer(aTbl.CoreVectors.AbsF64x4));
  Add('SqrtF64x4',             Pointer(aTbl.CoreVectors.SqrtF64x4));
  Add('MinF64x4',              Pointer(aTbl.CoreVectors.MinF64x4));
  Add('MaxF64x4',              Pointer(aTbl.CoreVectors.MaxF64x4));
  Add('ClampF64x4',            Pointer(aTbl.CoreVectors.ClampF64x4));

  Add('FmaF32x16',             Pointer(aTbl.CoreVectors.FmaF32x16));
  Add('FloorF32x16',           Pointer(aTbl.CoreVectors.FloorF32x16));
  Add('CeilF32x16',            Pointer(aTbl.CoreVectors.CeilF32x16));
  Add('RoundF32x16',           Pointer(aTbl.CoreVectors.RoundF32x16));
  Add('TruncF32x16',           Pointer(aTbl.CoreVectors.TruncF32x16));

  Add('FmaF64x8',              Pointer(aTbl.CoreVectors.FmaF64x8));
  Add('FloorF64x8',            Pointer(aTbl.CoreVectors.FloorF64x8));
  Add('CeilF64x8',             Pointer(aTbl.CoreVectors.CeilF64x8));
  Add('RoundF64x8',            Pointer(aTbl.CoreVectors.RoundF64x8));
  Add('TruncF64x8',            Pointer(aTbl.CoreVectors.TruncF64x8));

  Add('AbsF32x16',             Pointer(aTbl.CoreVectors.AbsF32x16));
  Add('SqrtF32x16',            Pointer(aTbl.CoreVectors.SqrtF32x16));
  Add('MinF32x16',             Pointer(aTbl.CoreVectors.MinF32x16));
  Add('MaxF32x16',             Pointer(aTbl.CoreVectors.MaxF32x16));
  Add('ClampF32x16',           Pointer(aTbl.CoreVectors.ClampF32x16));

  Add('AbsF64x8',              Pointer(aTbl.CoreVectors.AbsF64x8));
  Add('SqrtF64x8',             Pointer(aTbl.CoreVectors.SqrtF64x8));
  Add('MinF64x8',              Pointer(aTbl.CoreVectors.MinF64x8));
  Add('MaxF64x8',              Pointer(aTbl.CoreVectors.MaxF64x8));
  Add('ClampF64x8',            Pointer(aTbl.CoreVectors.ClampF64x8));

  // ── 3D/4D Vector math ──
  Add('DotF32x4',              Pointer(aTbl.CoreVectors.DotF32x4));
  Add('DotF32x3',              Pointer(aTbl.CoreVectors.DotF32x3));
  Add('CrossF32x3',            Pointer(aTbl.CoreVectors.CrossF32x3));
  Add('LengthF32x4',           Pointer(aTbl.CoreVectors.LengthF32x4));
  Add('LengthF32x3',           Pointer(aTbl.CoreVectors.LengthF32x3));
  Add('NormalizeF32x4',        Pointer(aTbl.CoreVectors.NormalizeF32x4));
  Add('NormalizeF32x3',        Pointer(aTbl.CoreVectors.NormalizeF32x3));

  // ── FMA-optimized Dot ──
  Add('DotF32x8',              Pointer(aTbl.CoreVectors.DotF32x8));
  Add('DotF64x2',              Pointer(aTbl.CoreVectors.DotF64x2));
  Add('DotF64x4',              Pointer(aTbl.CoreVectors.DotF64x4));

  // ── Reduction ──
  Add('ReduceAddF32x4',        Pointer(aTbl.CoreVectors.ReduceAddF32x4));
  Add('ReduceMinF32x4',        Pointer(aTbl.CoreVectors.ReduceMinF32x4));
  Add('ReduceMaxF32x4',        Pointer(aTbl.CoreVectors.ReduceMaxF32x4));
  Add('ReduceMulF32x4',        Pointer(aTbl.CoreVectors.ReduceMulF32x4));

  Add('ReduceAddF64x2',        Pointer(aTbl.CoreVectors.ReduceAddF64x2));
  Add('ReduceMinF64x2',        Pointer(aTbl.CoreVectors.ReduceMinF64x2));
  Add('ReduceMaxF64x2',        Pointer(aTbl.CoreVectors.ReduceMaxF64x2));
  Add('ReduceMulF64x2',        Pointer(aTbl.CoreVectors.ReduceMulF64x2));

  Add('ReduceAddF32x8',        Pointer(aTbl.CoreVectors.ReduceAddF32x8));
  Add('ReduceMinF32x8',        Pointer(aTbl.CoreVectors.ReduceMinF32x8));
  Add('ReduceMaxF32x8',        Pointer(aTbl.CoreVectors.ReduceMaxF32x8));
  Add('ReduceMulF32x8',        Pointer(aTbl.CoreVectors.ReduceMulF32x8));

  Add('ReduceAddF64x4',        Pointer(aTbl.CoreVectors.ReduceAddF64x4));
  Add('ReduceMinF64x4',        Pointer(aTbl.CoreVectors.ReduceMinF64x4));
  Add('ReduceMaxF64x4',        Pointer(aTbl.CoreVectors.ReduceMaxF64x4));
  Add('ReduceMulF64x4',        Pointer(aTbl.CoreVectors.ReduceMulF64x4));

  Add('ReduceAddF32x16',       Pointer(aTbl.CoreVectors.ReduceAddF32x16));
  Add('ReduceMinF32x16',       Pointer(aTbl.CoreVectors.ReduceMinF32x16));
  Add('ReduceMaxF32x16',       Pointer(aTbl.CoreVectors.ReduceMaxF32x16));
  Add('ReduceMulF32x16',       Pointer(aTbl.CoreVectors.ReduceMulF32x16));

  Add('ReduceAddF64x8',        Pointer(aTbl.CoreVectors.ReduceAddF64x8));
  Add('ReduceMinF64x8',        Pointer(aTbl.CoreVectors.ReduceMinF64x8));
  Add('ReduceMaxF64x8',        Pointer(aTbl.CoreVectors.ReduceMaxF64x8));
  Add('ReduceMulF64x8',        Pointer(aTbl.CoreVectors.ReduceMulF64x8));

  // ── Memory ops ──
  Add('LoadF32x4',             Pointer(aTbl.CoreVectors.LoadF32x4));
  Add('LoadF32x4Aligned',      Pointer(aTbl.CoreVectors.LoadF32x4Aligned));
  Add('StoreF32x4',            Pointer(aTbl.CoreVectors.StoreF32x4));
  Add('StoreF32x4Aligned',     Pointer(aTbl.CoreVectors.StoreF32x4Aligned));

  // ── Utility ──
  Add('SplatF32x4',            Pointer(aTbl.CoreVectors.SplatF32x4));
  Add('ZeroF32x4',             Pointer(aTbl.CoreVectors.ZeroF32x4));
  Add('SelectF32x4',           Pointer(aTbl.CoreVectors.SelectF32x4));
  Add('ExtractF32x4',          Pointer(aTbl.CoreVectors.ExtractF32x4));
  Add('InsertF32x4',           Pointer(aTbl.CoreVectors.InsertF32x4));

  // ── Extract/Insert Lane ──
  Add('ExtractF64x2',          Pointer(aTbl.CoreVectors.ExtractF64x2));
  Add('InsertF64x2',           Pointer(aTbl.CoreVectors.InsertF64x2));
  Add('ExtractI32x4',          Pointer(aTbl.CoreVectors.ExtractI32x4));
  Add('InsertI32x4',           Pointer(aTbl.CoreVectors.InsertI32x4));
  Add('ExtractI64x2',          Pointer(aTbl.CoreVectors.ExtractI64x2));
  Add('InsertI64x2',           Pointer(aTbl.CoreVectors.InsertI64x2));
  Add('ExtractF32x8',          Pointer(aTbl.CoreVectors.ExtractF32x8));
  Add('InsertF32x8',           Pointer(aTbl.CoreVectors.InsertF32x8));
  Add('ExtractF64x4',          Pointer(aTbl.CoreVectors.ExtractF64x4));
  Add('InsertF64x4',           Pointer(aTbl.CoreVectors.InsertF64x4));
  Add('ExtractI32x8',          Pointer(aTbl.CoreVectors.ExtractI32x8));
  Add('InsertI32x8',           Pointer(aTbl.CoreVectors.InsertI32x8));
  Add('ExtractI64x4',          Pointer(aTbl.CoreVectors.ExtractI64x4));
  Add('InsertI64x4',           Pointer(aTbl.CoreVectors.InsertI64x4));
  Add('ExtractF32x16',         Pointer(aTbl.CoreVectors.ExtractF32x16));
  Add('InsertF32x16',          Pointer(aTbl.CoreVectors.InsertF32x16));
  Add('ExtractI32x16',         Pointer(aTbl.CoreVectors.ExtractI32x16));
  Add('InsertI32x16',          Pointer(aTbl.CoreVectors.InsertI32x16));

  // ── Wide Load/Store/Splat/Zero ──
  Add('LoadF64x2',             Pointer(aTbl.CoreVectors.LoadF64x2));
  Add('StoreF64x2',            Pointer(aTbl.CoreVectors.StoreF64x2));
  Add('SplatF64x2',            Pointer(aTbl.CoreVectors.SplatF64x2));
  Add('ZeroF64x2',             Pointer(aTbl.CoreVectors.ZeroF64x2));
  Add('LoadF32x8',             Pointer(aTbl.CoreVectors.LoadF32x8));
  Add('StoreF32x8',            Pointer(aTbl.CoreVectors.StoreF32x8));
  Add('SplatF32x8',            Pointer(aTbl.CoreVectors.SplatF32x8));
  Add('ZeroF32x8',             Pointer(aTbl.CoreVectors.ZeroF32x8));
  Add('LoadF64x4',             Pointer(aTbl.CoreVectors.LoadF64x4));
  Add('StoreF64x4',            Pointer(aTbl.CoreVectors.StoreF64x4));
  Add('SplatF64x4',            Pointer(aTbl.CoreVectors.SplatF64x4));
  Add('ZeroF64x4',             Pointer(aTbl.CoreVectors.ZeroF64x4));
  Add('LoadF32x16',            Pointer(aTbl.CoreVectors.LoadF32x16));
  Add('StoreF32x16',           Pointer(aTbl.CoreVectors.StoreF32x16));
  Add('SplatF32x16',           Pointer(aTbl.CoreVectors.SplatF32x16));
  Add('ZeroF32x16',            Pointer(aTbl.CoreVectors.ZeroF32x16));
  Add('LoadF64x8',             Pointer(aTbl.CoreVectors.LoadF64x8));
  Add('StoreF64x8',            Pointer(aTbl.CoreVectors.StoreF64x8));
  Add('SplatF64x8',            Pointer(aTbl.CoreVectors.SplatF64x8));
  Add('ZeroF64x8',             Pointer(aTbl.CoreVectors.ZeroF64x8));

  // ── Facade (Mem) ──
  Add('MemEqual',              Pointer(aTbl.Memory.Equal));
  Add('MemFindByte',           Pointer(aTbl.Memory.FindByte));
  Add('MemDiffRange',          Pointer(aTbl.Memory.DiffRange));
  Add('MemCopy',               Pointer(aTbl.Memory.Copy));
  Add('MemSet',                Pointer(aTbl.Memory.Fill));
  Add('MemReverse',            Pointer(aTbl.Memory.Reverse));
  Add('SumBytes',              Pointer(aTbl.Memory.SumBytes));
  Add('MinMaxBytes',           Pointer(aTbl.Memory.MinMaxBytes));
  Add('CountByte',             Pointer(aTbl.Memory.CountByte));
  Add('Utf8Validate',          Pointer(aTbl.Memory.Utf8Validate));
  Add('AsciiIEqual',           Pointer(aTbl.Memory.AsciiIEqual));
  Add('ToLowerAscii',          Pointer(aTbl.Memory.ToLowerAscii));
  Add('ToUpperAscii',          Pointer(aTbl.Memory.ToUpperAscii));
  Add('BytesIndexOf',          Pointer(aTbl.Memory.BytesIndexOf));
  Add('BitsetPopCount',        Pointer(aTbl.Memory.BitsetPopCount));

  // ── Saturating Arithmetic ──
  Add('I8x16SatAdd',           Pointer(aTbl.CoreVectors.I8x16SatAdd));
  Add('I8x16SatSub',           Pointer(aTbl.CoreVectors.I8x16SatSub));
  Add('I16x8SatAdd',           Pointer(aTbl.CoreVectors.I16x8SatAdd));
  Add('I16x8SatSub',           Pointer(aTbl.CoreVectors.I16x8SatSub));
  Add('U8x16SatAdd',           Pointer(aTbl.CoreVectors.U8x16SatAdd));
  Add('U8x16SatSub',           Pointer(aTbl.CoreVectors.U8x16SatSub));
  Add('U16x8SatAdd',           Pointer(aTbl.CoreVectors.U16x8SatAdd));
  Add('U16x8SatSub',           Pointer(aTbl.CoreVectors.U16x8SatSub));

  // ── I16x8 ──
  Add('AddI16x8',              Pointer(aTbl.CoreVectors.AddI16x8));
  Add('SubI16x8',              Pointer(aTbl.CoreVectors.SubI16x8));
  Add('MulI16x8',              Pointer(aTbl.CoreVectors.MulI16x8));
  Add('AndI16x8',              Pointer(aTbl.CoreVectors.AndI16x8));
  Add('OrI16x8',               Pointer(aTbl.CoreVectors.OrI16x8));
  Add('XorI16x8',              Pointer(aTbl.CoreVectors.XorI16x8));
  Add('NotI16x8',              Pointer(aTbl.CoreVectors.NotI16x8));
  Add('AndNotI16x8',           Pointer(aTbl.CoreVectors.AndNotI16x8));
  Add('ShiftLeftI16x8',        Pointer(aTbl.CoreVectors.ShiftLeftI16x8));
  Add('ShiftRightI16x8',       Pointer(aTbl.CoreVectors.ShiftRightI16x8));
  Add('ShiftRightArithI16x8',  Pointer(aTbl.CoreVectors.ShiftRightArithI16x8));
  Add('CmpEqI16x8',            Pointer(aTbl.CoreVectors.CmpEqI16x8));
  Add('CmpLtI16x8',            Pointer(aTbl.CoreVectors.CmpLtI16x8));
  Add('CmpGtI16x8',            Pointer(aTbl.CoreVectors.CmpGtI16x8));
  Add('CmpLeI16x8',            Pointer(aTbl.CoreVectors.CmpLeI16x8));
  Add('CmpGeI16x8',            Pointer(aTbl.CoreVectors.CmpGeI16x8));
  Add('CmpNeI16x8',            Pointer(aTbl.CoreVectors.CmpNeI16x8));
  Add('MinI16x8',              Pointer(aTbl.CoreVectors.MinI16x8));
  Add('MaxI16x8',              Pointer(aTbl.CoreVectors.MaxI16x8));

  // ── I8x16 ──
  Add('AddI8x16',              Pointer(aTbl.CoreVectors.AddI8x16));
  Add('SubI8x16',              Pointer(aTbl.CoreVectors.SubI8x16));
  Add('AndI8x16',              Pointer(aTbl.CoreVectors.AndI8x16));
  Add('OrI8x16',               Pointer(aTbl.CoreVectors.OrI8x16));
  Add('XorI8x16',              Pointer(aTbl.CoreVectors.XorI8x16));
  Add('NotI8x16',              Pointer(aTbl.CoreVectors.NotI8x16));
  Add('CmpEqI8x16',            Pointer(aTbl.CoreVectors.CmpEqI8x16));
  Add('CmpLtI8x16',            Pointer(aTbl.CoreVectors.CmpLtI8x16));
  Add('CmpGtI8x16',            Pointer(aTbl.CoreVectors.CmpGtI8x16));
  Add('CmpLeI8x16',            Pointer(aTbl.CoreVectors.CmpLeI8x16));
  Add('CmpGeI8x16',            Pointer(aTbl.CoreVectors.CmpGeI8x16));
  Add('CmpNeI8x16',            Pointer(aTbl.CoreVectors.CmpNeI8x16));
  Add('MinI8x16',              Pointer(aTbl.CoreVectors.MinI8x16));
  Add('MaxI8x16',              Pointer(aTbl.CoreVectors.MaxI8x16));

  // ── U32x4 ──
  Add('AddU32x4',              Pointer(aTbl.CoreVectors.AddU32x4));
  Add('SubU32x4',              Pointer(aTbl.CoreVectors.SubU32x4));
  Add('MulU32x4',              Pointer(aTbl.CoreVectors.MulU32x4));
  Add('AndU32x4',              Pointer(aTbl.CoreVectors.AndU32x4));
  Add('OrU32x4',               Pointer(aTbl.CoreVectors.OrU32x4));
  Add('XorU32x4',              Pointer(aTbl.CoreVectors.XorU32x4));
  Add('NotU32x4',              Pointer(aTbl.CoreVectors.NotU32x4));
  Add('AndNotU32x4',           Pointer(aTbl.CoreVectors.AndNotU32x4));
  Add('ShiftLeftU32x4',        Pointer(aTbl.CoreVectors.ShiftLeftU32x4));
  Add('ShiftRightU32x4',       Pointer(aTbl.CoreVectors.ShiftRightU32x4));
  Add('CmpEqU32x4',            Pointer(aTbl.CoreVectors.CmpEqU32x4));
  Add('CmpLtU32x4',            Pointer(aTbl.CoreVectors.CmpLtU32x4));
  Add('CmpGtU32x4',            Pointer(aTbl.CoreVectors.CmpGtU32x4));
  Add('CmpLeU32x4',            Pointer(aTbl.CoreVectors.CmpLeU32x4));
  Add('CmpGeU32x4',            Pointer(aTbl.CoreVectors.CmpGeU32x4));
  Add('MinU32x4',              Pointer(aTbl.CoreVectors.MinU32x4));
  Add('MaxU32x4',              Pointer(aTbl.CoreVectors.MaxU32x4));

  // ── U16x8 ──
  Add('AddU16x8',              Pointer(aTbl.CoreVectors.AddU16x8));
  Add('SubU16x8',              Pointer(aTbl.CoreVectors.SubU16x8));
  Add('MulU16x8',              Pointer(aTbl.CoreVectors.MulU16x8));
  Add('AndU16x8',              Pointer(aTbl.CoreVectors.AndU16x8));
  Add('OrU16x8',               Pointer(aTbl.CoreVectors.OrU16x8));
  Add('XorU16x8',              Pointer(aTbl.CoreVectors.XorU16x8));
  Add('NotU16x8',              Pointer(aTbl.CoreVectors.NotU16x8));
  Add('ShiftLeftU16x8',        Pointer(aTbl.CoreVectors.ShiftLeftU16x8));
  Add('ShiftRightU16x8',       Pointer(aTbl.CoreVectors.ShiftRightU16x8));
  Add('CmpEqU16x8',            Pointer(aTbl.CoreVectors.CmpEqU16x8));
  Add('CmpLtU16x8',            Pointer(aTbl.CoreVectors.CmpLtU16x8));
  Add('CmpGtU16x8',            Pointer(aTbl.CoreVectors.CmpGtU16x8));
  Add('CmpLeU16x8',            Pointer(aTbl.CoreVectors.CmpLeU16x8));
  Add('CmpGeU16x8',            Pointer(aTbl.CoreVectors.CmpGeU16x8));
  Add('CmpNeU16x8',            Pointer(aTbl.CoreVectors.CmpNeU16x8));
  Add('MinU16x8',              Pointer(aTbl.CoreVectors.MinU16x8));
  Add('MaxU16x8',              Pointer(aTbl.CoreVectors.MaxU16x8));

  // ── U8x16 ──
  Add('AddU8x16',              Pointer(aTbl.CoreVectors.AddU8x16));
  Add('SubU8x16',              Pointer(aTbl.CoreVectors.SubU8x16));
  Add('AndU8x16',              Pointer(aTbl.CoreVectors.AndU8x16));
  Add('OrU8x16',               Pointer(aTbl.CoreVectors.OrU8x16));
  Add('XorU8x16',              Pointer(aTbl.CoreVectors.XorU8x16));
  Add('NotU8x16',              Pointer(aTbl.CoreVectors.NotU8x16));
  Add('CmpEqU8x16',            Pointer(aTbl.CoreVectors.CmpEqU8x16));
  Add('CmpLtU8x16',            Pointer(aTbl.CoreVectors.CmpLtU8x16));
  Add('CmpGtU8x16',            Pointer(aTbl.CoreVectors.CmpGtU8x16));
  Add('CmpLeU8x16',            Pointer(aTbl.CoreVectors.CmpLeU8x16));
  Add('CmpGeU8x16',            Pointer(aTbl.CoreVectors.CmpGeU8x16));
  Add('CmpNeU8x16',            Pointer(aTbl.CoreVectors.CmpNeU8x16));
  Add('MinU8x16',              Pointer(aTbl.CoreVectors.MinU8x16));
  Add('MaxU8x16',              Pointer(aTbl.CoreVectors.MaxU8x16));

  // ── Mask ──
  Add('Mask2All',              Pointer(aTbl.Mask.Mask2All));
  Add('Mask2Any',              Pointer(aTbl.Mask.Mask2Any));
  Add('Mask2None',             Pointer(aTbl.Mask.Mask2None));
  Add('Mask2PopCount',         Pointer(aTbl.Mask.Mask2PopCount));
  Add('Mask2FirstSet',         Pointer(aTbl.Mask.Mask2FirstSet));
  Add('Mask4All',              Pointer(aTbl.Mask.Mask4All));
  Add('Mask4Any',              Pointer(aTbl.Mask.Mask4Any));
  Add('Mask4None',             Pointer(aTbl.Mask.Mask4None));
  Add('Mask4PopCount',         Pointer(aTbl.Mask.Mask4PopCount));
  Add('Mask4FirstSet',         Pointer(aTbl.Mask.Mask4FirstSet));
  Add('Mask8All',              Pointer(aTbl.Mask.Mask8All));
  Add('Mask8Any',              Pointer(aTbl.Mask.Mask8Any));
  Add('Mask8None',             Pointer(aTbl.Mask.Mask8None));
  Add('Mask8PopCount',         Pointer(aTbl.Mask.Mask8PopCount));
  Add('Mask8FirstSet',         Pointer(aTbl.Mask.Mask8FirstSet));
  Add('Mask16All',             Pointer(aTbl.Mask.Mask16All));
  Add('Mask16Any',             Pointer(aTbl.Mask.Mask16Any));
  Add('Mask16None',            Pointer(aTbl.Mask.Mask16None));
  Add('Mask16PopCount',        Pointer(aTbl.Mask.Mask16PopCount));
  Add('Mask16FirstSet',        Pointer(aTbl.Mask.Mask16FirstSet));

  // ── Select ──
  Add('SelectF64x2',           Pointer(aTbl.CoreVectors.SelectF64x2));
  Add('SelectF32x16',          Pointer(aTbl.CoreVectors.SelectF32x16));
  Add('SelectF64x8',           Pointer(aTbl.CoreVectors.SelectF64x8));
  Add('SelectI32x4',           Pointer(aTbl.CoreVectors.SelectI32x4));
  Add('SelectF32x8',           Pointer(aTbl.CoreVectors.SelectF32x8));
  Add('SelectF64x4',           Pointer(aTbl.CoreVectors.SelectF64x4));

  // ── Narrow AndNot ──
  Add('AndNotI8x16',           Pointer(aTbl.CoreVectors.AndNotI8x16));
  Add('AndNotU16x8',           Pointer(aTbl.CoreVectors.AndNotU16x8));
  Add('AndNotU8x16',           Pointer(aTbl.CoreVectors.AndNotU8x16));

  // ── Batch Array F32 ──
  Add('ArrayAddF32',           Pointer(aTbl.BatchF32.ArrayAdd));
  Add('ArraySubF32',           Pointer(aTbl.BatchF32.ArraySub));
  Add('ArrayMulF32',           Pointer(aTbl.BatchF32.ArrayMul));
  Add('ArrayDivF32',           Pointer(aTbl.BatchF32.ArrayDiv));
  Add('ArrayMinF32',           Pointer(aTbl.BatchF32.ArrayMin));
  Add('ArrayMaxF32',           Pointer(aTbl.BatchF32.ArrayMax));
  Add('ArrayAbsF32',           Pointer(aTbl.BatchF32.ArrayAbs));
  Add('ArrayNegF32',           Pointer(aTbl.BatchF32.ArrayNeg));
  Add('ArraySqrtF32',          Pointer(aTbl.BatchF32.ArraySqrt));
  Add('ArrayRcpF32',           Pointer(aTbl.BatchF32.ArrayRcp));
  Add('ArrayRsqrtF32',         Pointer(aTbl.BatchF32.ArrayRsqrt));
  Add('ArrayRcpRefineF32',     Pointer(aTbl.BatchF32.ArrayRcpRefine));
  Add('ArrayRsqrtRefineF32',   Pointer(aTbl.BatchF32.ArrayRsqrtRefine));
  Add('ArrayAddScalarF32',     Pointer(aTbl.BatchF32.ArrayAddScalar));
  Add('ArrayMulScalarF32',     Pointer(aTbl.BatchF32.ArrayMulScalar));
  Add('ArrayClampF32',         Pointer(aTbl.BatchF32.ArrayClamp));
  Add('ArrayFmaF32',           Pointer(aTbl.BatchF32.ArrayFma));
  Add('ArrayAxpyF32',          Pointer(aTbl.BatchF32.ArrayAxpy));
  Add('ReduceSumF32',          Pointer(aTbl.BatchF32.ReduceSum));
  Add('ReduceDotF32',          Pointer(aTbl.BatchF32.ReduceDot));
  Add('ReduceMinF32',          Pointer(aTbl.BatchF32.ReduceMin));
  Add('ReduceMaxF32',          Pointer(aTbl.BatchF32.ReduceMax));

  // ── Batch Array F64 ──
  Add('ArrayAddF64',           Pointer(aTbl.BatchF64.ArrayAdd));
  Add('ArraySubF64',           Pointer(aTbl.BatchF64.ArraySub));
  Add('ArrayMulF64',           Pointer(aTbl.BatchF64.ArrayMul));
  Add('ArrayDivF64',           Pointer(aTbl.BatchF64.ArrayDiv));
  Add('ReduceSumF64',          Pointer(aTbl.BatchF64.ReduceSum));
  Add('ReduceDotF64',          Pointer(aTbl.BatchF64.ReduceDot));
  Add('ReduceMinF64',          Pointer(aTbl.BatchF64.ReduceMin));
  Add('ReduceMaxF64',          Pointer(aTbl.BatchF64.ReduceMax));
  Add('ArrayAbsF64',           Pointer(aTbl.BatchF64.ArrayAbs));
  Add('ArrayNegF64',           Pointer(aTbl.BatchF64.ArrayNeg));
  Add('ArraySqrtF64',          Pointer(aTbl.BatchF64.ArraySqrt));
  Add('ArrayMulScalarF64',     Pointer(aTbl.BatchF64.ArrayMulScalar));
  Add('ArrayAddScalarF64',     Pointer(aTbl.BatchF64.ArrayAddScalar));
  Add('ArrayClampF64',         Pointer(aTbl.BatchF64.ArrayClamp));
  Add('ArrayLinearF64',        Pointer(aTbl.BatchF64.ArrayLinear));

  // ── Batch Transcendental ──
  Add('ArrayExpF32',           Pointer(aTbl.BatchF32.ArrayExp));
  Add('ArrayLogF32',           Pointer(aTbl.BatchF32.ArrayLog));
  Add('ArrayPowF32',           Pointer(aTbl.BatchF32.ArrayPow));
  Add('ArraySinF32',           Pointer(aTbl.BatchF32.ArraySin));
  Add('ArrayCosF32',           Pointer(aTbl.BatchF32.ArrayCos));

  // ── Batch Integer ──
  Add('ArrayAddI32',           Pointer(aTbl.BatchInteger.ArrayAddI32));
  Add('ArraySubI32',           Pointer(aTbl.BatchInteger.ArraySubI32));
  Add('ArrayMulI16',           Pointer(aTbl.BatchInteger.ArrayMulI16));
  Add('ArrayPackSatI32toI16',  Pointer(aTbl.BatchInteger.ArrayPackSatI32toI16));

  // ── Batch Type Conversion ──
  Add('ArrayF32toI32',         Pointer(aTbl.BatchInteger.ArrayF32toI32));
  Add('ArrayI32toF32',         Pointer(aTbl.BatchInteger.ArrayI32toF32));

  // ── Batch Bitwise ──
  Add('ArrayAndI32',           Pointer(aTbl.BatchInteger.ArrayAndI32));
  Add('ArrayOrI32',            Pointer(aTbl.BatchInteger.ArrayOrI32));
  Add('ArrayXorI32',           Pointer(aTbl.BatchInteger.ArrayXorI32));
  Add('ArrayShlI32',           Pointer(aTbl.BatchInteger.ArrayShlI32));
  Add('ArrayShrI32',           Pointer(aTbl.BatchInteger.ArrayShrI32));

  // ── Fused Batch ──
  Add('ArrayLinearF32',        Pointer(aTbl.BatchF32.ArrayLinear));
  Add('ArrayAbsDiffF32',       Pointer(aTbl.BatchF32.ArrayAbsDiff));
  Add('ArrayReLUF32',          Pointer(aTbl.BatchF32.ArrayReLU));
  Add('ArrayNormF32',          Pointer(aTbl.BatchF32.ArrayNorm));
  Add('ArrayLinearReLUF32',    Pointer(aTbl.BatchF32.ArrayLinearReLU));

  // ── Statistics ──
  total := n;
  for i := 0 to n - 1 do
    if slots[i].Ptr <> nil then
      Inc(covered);

  WriteLn('========================================');
  WriteLn('  NEON Dispatch Table Coverage Report');
  WriteLn('  Backend: ', aName);
  WriteLn('========================================');
  WriteLn;
  WriteLn('Total slots:     ', total);
  WriteLn('Covered (non-nil): ', covered);
  WriteLn('Missing (nil):   ', total - covered);
  Write('Coverage:        ');
  if total > 0 then
    WriteLn((covered * 100.0 / total):0:1, '%')
  else
    WriteLn('N/A');
  WriteLn;

  // ── Print missing slots ──
  if covered < total then
  begin
    WriteLn('=== MISSING SLOTS (nil function pointers) ===');
    for i := 0 to n - 1 do
      if slots[i].Ptr = nil then
        WriteLn('  [ ] ', slots[i].Name);
    WriteLn;
  end;

  // ── Print covered slots ──
  WriteLn('=== COVERED SLOTS ===');
  for i := 0 to n - 1 do
    if slots[i].Ptr <> nil then
      WriteLn('  [x] ', slots[i].Name);
end;

var
  tbl: TSimdDispatchTable;
  name: PAnsiChar;
begin
  // Get NEON dispatch table if registered
  if TryGetRegisteredBackendDispatchTable(sbNEON, tbl) then
    name := GetBackendNameTextPtr(sbNEON)
  else
  begin
    WriteLn('NEON backend is NOT registered on this system.');
    WriteLn('The NEON dispatch table may not be available on x86_64.');
    WriteLn('This benchmark is intended to run on ARM64/aarch64 hardware.');
    WriteLn;
    WriteLn('Backend info for NEON:');
    WriteLn('  Available: ', GetBackendInfo(sbNEON).Available);
    WriteLn('  Name:      ', GetBackendNameTextPtr(sbNEON));
    WriteLn('  Desc:      ', GetBackendDescriptionTextPtr(sbNEON));
    Halt(0);
  end;

  CountPointerFields(tbl, name);
end.
