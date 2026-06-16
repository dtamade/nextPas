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
  Add('AddF32x4',              Pointer(aTbl.AddF32x4));
  Add('SubF32x4',              Pointer(aTbl.SubF32x4));
  Add('MulF32x4',              Pointer(aTbl.MulF32x4));
  Add('DivF32x4',              Pointer(aTbl.DivF32x4));

  // ── F32x8 arithmetic ──
  Add('AddF32x8',              Pointer(aTbl.AddF32x8));
  Add('SubF32x8',              Pointer(aTbl.SubF32x8));
  Add('MulF32x8',              Pointer(aTbl.MulF32x8));
  Add('DivF32x8',              Pointer(aTbl.DivF32x8));

  // ── F64x2 arithmetic ──
  Add('AddF64x2',              Pointer(aTbl.AddF64x2));
  Add('SubF64x2',              Pointer(aTbl.SubF64x2));
  Add('MulF64x2',              Pointer(aTbl.MulF64x2));
  Add('DivF64x2',              Pointer(aTbl.DivF64x2));

  // ── I32x4 ──
  Add('AddI32x4',              Pointer(aTbl.AddI32x4));
  Add('SubI32x4',              Pointer(aTbl.SubI32x4));
  Add('MulI32x4',              Pointer(aTbl.MulI32x4));
  Add('AndI32x4',              Pointer(aTbl.AndI32x4));
  Add('OrI32x4',               Pointer(aTbl.OrI32x4));
  Add('XorI32x4',              Pointer(aTbl.XorI32x4));
  Add('NotI32x4',              Pointer(aTbl.NotI32x4));
  Add('AndNotI32x4',           Pointer(aTbl.AndNotI32x4));
  Add('ShiftLeftI32x4',        Pointer(aTbl.ShiftLeftI32x4));
  Add('ShiftRightI32x4',       Pointer(aTbl.ShiftRightI32x4));
  Add('ShiftRightArithI32x4',  Pointer(aTbl.ShiftRightArithI32x4));
  Add('CmpEqI32x4',            Pointer(aTbl.CmpEqI32x4));
  Add('CmpLtI32x4',            Pointer(aTbl.CmpLtI32x4));
  Add('CmpGtI32x4',            Pointer(aTbl.CmpGtI32x4));
  Add('CmpLeI32x4',            Pointer(aTbl.CmpLeI32x4));
  Add('CmpGeI32x4',            Pointer(aTbl.CmpGeI32x4));
  Add('CmpNeI32x4',            Pointer(aTbl.CmpNeI32x4));
  Add('MinI32x4',              Pointer(aTbl.MinI32x4));
  Add('MaxI32x4',              Pointer(aTbl.MaxI32x4));

  // ── I64x2 ──
  Add('AddI64x2',              Pointer(aTbl.AddI64x2));
  Add('SubI64x2',              Pointer(aTbl.SubI64x2));
  Add('AndI64x2',              Pointer(aTbl.AndI64x2));
  Add('OrI64x2',               Pointer(aTbl.OrI64x2));
  Add('XorI64x2',              Pointer(aTbl.XorI64x2));
  Add('NotI64x2',              Pointer(aTbl.NotI64x2));
  Add('AndNotI64x2',           Pointer(aTbl.AndNotI64x2));
  Add('ShiftLeftI64x2',        Pointer(aTbl.ShiftLeftI64x2));
  Add('ShiftRightI64x2',       Pointer(aTbl.ShiftRightI64x2));
  Add('ShiftRightArithI64x2',  Pointer(aTbl.ShiftRightArithI64x2));
  Add('CmpEqI64x2',            Pointer(aTbl.CmpEqI64x2));
  Add('CmpLtI64x2',            Pointer(aTbl.CmpLtI64x2));
  Add('CmpGtI64x2',            Pointer(aTbl.CmpGtI64x2));
  Add('CmpLeI64x2',            Pointer(aTbl.CmpLeI64x2));
  Add('CmpGeI64x2',            Pointer(aTbl.CmpGeI64x2));
  Add('CmpNeI64x2',            Pointer(aTbl.CmpNeI64x2));
  Add('MinI64x2',              Pointer(aTbl.MinI64x2));
  Add('MaxI64x2',              Pointer(aTbl.MaxI64x2));

  // ── U64x2 ──
  Add('AddU64x2',              Pointer(aTbl.AddU64x2));
  Add('SubU64x2',              Pointer(aTbl.SubU64x2));
  Add('AndU64x2',              Pointer(aTbl.AndU64x2));
  Add('OrU64x2',               Pointer(aTbl.OrU64x2));
  Add('XorU64x2',              Pointer(aTbl.XorU64x2));
  Add('NotU64x2',              Pointer(aTbl.NotU64x2));
  Add('AndNotU64x2',           Pointer(aTbl.AndNotU64x2));
  Add('CmpEqU64x2',            Pointer(aTbl.CmpEqU64x2));
  Add('CmpLtU64x2',            Pointer(aTbl.CmpLtU64x2));
  Add('CmpGtU64x2',            Pointer(aTbl.CmpGtU64x2));
  Add('MinU64x2',              Pointer(aTbl.MinU64x2));
  Add('MaxU64x2',              Pointer(aTbl.MaxU64x2));

  // ── F64x4 ──
  Add('AddF64x4',              Pointer(aTbl.AddF64x4));
  Add('SubF64x4',              Pointer(aTbl.SubF64x4));
  Add('MulF64x4',              Pointer(aTbl.MulF64x4));
  Add('DivF64x4',              Pointer(aTbl.DivF64x4));

  // ── I32x8 ──
  Add('AddI32x8',              Pointer(aTbl.AddI32x8));
  Add('SubI32x8',              Pointer(aTbl.SubI32x8));
  Add('MulI32x8',              Pointer(aTbl.MulI32x8));
  Add('AndI32x8',              Pointer(aTbl.AndI32x8));
  Add('OrI32x8',               Pointer(aTbl.OrI32x8));
  Add('XorI32x8',              Pointer(aTbl.XorI32x8));
  Add('NotI32x8',              Pointer(aTbl.NotI32x8));
  Add('AndNotI32x8',           Pointer(aTbl.AndNotI32x8));
  Add('ShiftLeftI32x8',        Pointer(aTbl.ShiftLeftI32x8));
  Add('ShiftRightI32x8',       Pointer(aTbl.ShiftRightI32x8));
  Add('ShiftRightArithI32x8',  Pointer(aTbl.ShiftRightArithI32x8));
  Add('CmpEqI32x8',            Pointer(aTbl.CmpEqI32x8));
  Add('CmpLtI32x8',            Pointer(aTbl.CmpLtI32x8));
  Add('CmpGtI32x8',            Pointer(aTbl.CmpGtI32x8));
  Add('CmpLeI32x8',            Pointer(aTbl.CmpLeI32x8));
  Add('CmpGeI32x8',            Pointer(aTbl.CmpGeI32x8));
  Add('CmpNeI32x8',            Pointer(aTbl.CmpNeI32x8));
  Add('MinI32x8',              Pointer(aTbl.MinI32x8));
  Add('MaxI32x8',              Pointer(aTbl.MaxI32x8));

  // ── I64x4 ──
  Add('AddI64x4',              Pointer(aTbl.AddI64x4));
  Add('SubI64x4',              Pointer(aTbl.SubI64x4));
  Add('AndI64x4',              Pointer(aTbl.AndI64x4));
  Add('OrI64x4',               Pointer(aTbl.OrI64x4));
  Add('XorI64x4',              Pointer(aTbl.XorI64x4));
  Add('NotI64x4',              Pointer(aTbl.NotI64x4));
  Add('AndNotI64x4',           Pointer(aTbl.AndNotI64x4));
  Add('ShiftLeftI64x4',        Pointer(aTbl.ShiftLeftI64x4));
  Add('ShiftRightI64x4',       Pointer(aTbl.ShiftRightI64x4));
  Add('ShiftRightArithI64x4',  Pointer(aTbl.ShiftRightArithI64x4));
  Add('CmpEqI64x4',            Pointer(aTbl.CmpEqI64x4));
  Add('CmpLtI64x4',            Pointer(aTbl.CmpLtI64x4));
  Add('CmpGtI64x4',            Pointer(aTbl.CmpGtI64x4));
  Add('CmpLeI64x4',            Pointer(aTbl.CmpLeI64x4));
  Add('CmpGeI64x4',            Pointer(aTbl.CmpGeI64x4));
  Add('CmpNeI64x4',            Pointer(aTbl.CmpNeI64x4));
  Add('LoadI64x4',             Pointer(aTbl.LoadI64x4));
  Add('StoreI64x4',            Pointer(aTbl.StoreI64x4));
  Add('SplatI64x4',            Pointer(aTbl.SplatI64x4));
  Add('ZeroI64x4',             Pointer(aTbl.ZeroI64x4));

  // ── U32x8 ──
  Add('AddU32x8',              Pointer(aTbl.AddU32x8));
  Add('SubU32x8',              Pointer(aTbl.SubU32x8));
  Add('MulU32x8',              Pointer(aTbl.MulU32x8));
  Add('AndU32x8',              Pointer(aTbl.AndU32x8));
  Add('OrU32x8',               Pointer(aTbl.OrU32x8));
  Add('XorU32x8',              Pointer(aTbl.XorU32x8));
  Add('NotU32x8',              Pointer(aTbl.NotU32x8));
  Add('AndNotU32x8',           Pointer(aTbl.AndNotU32x8));
  Add('ShiftLeftU32x8',        Pointer(aTbl.ShiftLeftU32x8));
  Add('ShiftRightU32x8',       Pointer(aTbl.ShiftRightU32x8));
  Add('CmpEqU32x8',            Pointer(aTbl.CmpEqU32x8));
  Add('CmpLtU32x8',            Pointer(aTbl.CmpLtU32x8));
  Add('CmpGtU32x8',            Pointer(aTbl.CmpGtU32x8));
  Add('CmpLeU32x8',            Pointer(aTbl.CmpLeU32x8));
  Add('CmpGeU32x8',            Pointer(aTbl.CmpGeU32x8));
  Add('CmpNeU32x8',            Pointer(aTbl.CmpNeU32x8));
  Add('MinU32x8',              Pointer(aTbl.MinU32x8));
  Add('MaxU32x8',              Pointer(aTbl.MaxU32x8));

  // ── U64x4 ──
  Add('AddU64x4',              Pointer(aTbl.AddU64x4));
  Add('SubU64x4',              Pointer(aTbl.SubU64x4));
  Add('AndU64x4',              Pointer(aTbl.AndU64x4));
  Add('OrU64x4',               Pointer(aTbl.OrU64x4));
  Add('XorU64x4',              Pointer(aTbl.XorU64x4));
  Add('NotU64x4',              Pointer(aTbl.NotU64x4));
  Add('ShiftLeftU64x4',        Pointer(aTbl.ShiftLeftU64x4));
  Add('ShiftRightU64x4',       Pointer(aTbl.ShiftRightU64x4));
  Add('CmpEqU64x4',            Pointer(aTbl.CmpEqU64x4));
  Add('CmpLtU64x4',            Pointer(aTbl.CmpLtU64x4));
  Add('CmpGtU64x4',            Pointer(aTbl.CmpGtU64x4));
  Add('CmpLeU64x4',            Pointer(aTbl.CmpLeU64x4));
  Add('CmpGeU64x4',            Pointer(aTbl.CmpGeU64x4));
  Add('CmpNeU64x4',            Pointer(aTbl.CmpNeU64x4));

  // ── RcpF64x4 ──
  Add('RcpF64x4',              Pointer(aTbl.RcpF64x4));

  // ── I32x16 ──
  Add('AddI32x16',             Pointer(aTbl.AddI32x16));
  Add('SubI32x16',             Pointer(aTbl.SubI32x16));
  Add('MulI32x16',             Pointer(aTbl.MulI32x16));
  Add('AndI32x16',             Pointer(aTbl.AndI32x16));
  Add('OrI32x16',              Pointer(aTbl.OrI32x16));
  Add('XorI32x16',             Pointer(aTbl.XorI32x16));
  Add('NotI32x16',             Pointer(aTbl.NotI32x16));
  Add('AndNotI32x16',          Pointer(aTbl.AndNotI32x16));
  Add('ShiftLeftI32x16',       Pointer(aTbl.ShiftLeftI32x16));
  Add('ShiftRightI32x16',      Pointer(aTbl.ShiftRightI32x16));
  Add('ShiftRightArithI32x16', Pointer(aTbl.ShiftRightArithI32x16));
  Add('CmpEqI32x16',           Pointer(aTbl.CmpEqI32x16));
  Add('CmpLtI32x16',           Pointer(aTbl.CmpLtI32x16));
  Add('CmpGtI32x16',           Pointer(aTbl.CmpGtI32x16));
  Add('CmpLeI32x16',           Pointer(aTbl.CmpLeI32x16));
  Add('CmpGeI32x16',           Pointer(aTbl.CmpGeI32x16));
  Add('CmpNeI32x16',           Pointer(aTbl.CmpNeI32x16));
  Add('MinI32x16',             Pointer(aTbl.MinI32x16));
  Add('MaxI32x16',             Pointer(aTbl.MaxI32x16));

  // ── I64x8 ──
  Add('AddI64x8',              Pointer(aTbl.AddI64x8));
  Add('SubI64x8',              Pointer(aTbl.SubI64x8));
  Add('AndI64x8',              Pointer(aTbl.AndI64x8));
  Add('OrI64x8',               Pointer(aTbl.OrI64x8));
  Add('XorI64x8',              Pointer(aTbl.XorI64x8));
  Add('NotI64x8',              Pointer(aTbl.NotI64x8));
  Add('CmpEqI64x8',            Pointer(aTbl.CmpEqI64x8));
  Add('CmpLtI64x8',            Pointer(aTbl.CmpLtI64x8));
  Add('CmpGtI64x8',            Pointer(aTbl.CmpGtI64x8));
  Add('CmpLeI64x8',            Pointer(aTbl.CmpLeI64x8));
  Add('CmpGeI64x8',            Pointer(aTbl.CmpGeI64x8));
  Add('CmpNeI64x8',            Pointer(aTbl.CmpNeI64x8));

  // ── U32x16 ──
  Add('AddU32x16',             Pointer(aTbl.AddU32x16));
  Add('SubU32x16',             Pointer(aTbl.SubU32x16));
  Add('MulU32x16',             Pointer(aTbl.MulU32x16));
  Add('AndU32x16',             Pointer(aTbl.AndU32x16));
  Add('OrU32x16',              Pointer(aTbl.OrU32x16));
  Add('XorU32x16',             Pointer(aTbl.XorU32x16));
  Add('NotU32x16',             Pointer(aTbl.NotU32x16));
  Add('AndNotU32x16',          Pointer(aTbl.AndNotU32x16));
  Add('ShiftLeftU32x16',       Pointer(aTbl.ShiftLeftU32x16));
  Add('ShiftRightU32x16',      Pointer(aTbl.ShiftRightU32x16));
  Add('CmpEqU32x16',           Pointer(aTbl.CmpEqU32x16));
  Add('CmpLtU32x16',           Pointer(aTbl.CmpLtU32x16));
  Add('CmpGtU32x16',           Pointer(aTbl.CmpGtU32x16));
  Add('CmpLeU32x16',           Pointer(aTbl.CmpLeU32x16));
  Add('CmpGeU32x16',           Pointer(aTbl.CmpGeU32x16));
  Add('CmpNeU32x16',           Pointer(aTbl.CmpNeU32x16));
  Add('MinU32x16',             Pointer(aTbl.MinU32x16));
  Add('MaxU32x16',             Pointer(aTbl.MaxU32x16));

  // ── U64x8 ──
  Add('AddU64x8',              Pointer(aTbl.AddU64x8));
  Add('SubU64x8',              Pointer(aTbl.SubU64x8));
  Add('AndU64x8',              Pointer(aTbl.AndU64x8));
  Add('OrU64x8',               Pointer(aTbl.OrU64x8));
  Add('XorU64x8',              Pointer(aTbl.XorU64x8));
  Add('NotU64x8',              Pointer(aTbl.NotU64x8));
  Add('ShiftLeftU64x8',        Pointer(aTbl.ShiftLeftU64x8));
  Add('ShiftRightU64x8',       Pointer(aTbl.ShiftRightU64x8));
  Add('CmpEqU64x8',            Pointer(aTbl.CmpEqU64x8));
  Add('CmpLtU64x8',            Pointer(aTbl.CmpLtU64x8));
  Add('CmpGtU64x8',            Pointer(aTbl.CmpGtU64x8));
  Add('CmpLeU64x8',            Pointer(aTbl.CmpLeU64x8));
  Add('CmpGeU64x8',            Pointer(aTbl.CmpGeU64x8));
  Add('CmpNeU64x8',            Pointer(aTbl.CmpNeU64x8));

  // ── I16x32 ──
  Add('AddI16x32',             Pointer(aTbl.AddI16x32));
  Add('SubI16x32',             Pointer(aTbl.SubI16x32));
  Add('AndI16x32',             Pointer(aTbl.AndI16x32));
  Add('OrI16x32',              Pointer(aTbl.OrI16x32));
  Add('XorI16x32',             Pointer(aTbl.XorI16x32));
  Add('NotI16x32',             Pointer(aTbl.NotI16x32));
  Add('AndNotI16x32',          Pointer(aTbl.AndNotI16x32));
  Add('ShiftLeftI16x32',       Pointer(aTbl.ShiftLeftI16x32));
  Add('ShiftRightI16x32',      Pointer(aTbl.ShiftRightI16x32));
  Add('ShiftRightArithI16x32', Pointer(aTbl.ShiftRightArithI16x32));
  Add('CmpEqI16x32',           Pointer(aTbl.CmpEqI16x32));
  Add('CmpLtI16x32',           Pointer(aTbl.CmpLtI16x32));
  Add('CmpGtI16x32',           Pointer(aTbl.CmpGtI16x32));
  Add('MinI16x32',             Pointer(aTbl.MinI16x32));
  Add('MaxI16x32',             Pointer(aTbl.MaxI16x32));

  // ── I8x64 ──
  Add('AddI8x64',              Pointer(aTbl.AddI8x64));
  Add('SubI8x64',              Pointer(aTbl.SubI8x64));
  Add('AndI8x64',              Pointer(aTbl.AndI8x64));
  Add('OrI8x64',               Pointer(aTbl.OrI8x64));
  Add('XorI8x64',              Pointer(aTbl.XorI8x64));
  Add('NotI8x64',              Pointer(aTbl.NotI8x64));
  Add('AndNotI8x64',           Pointer(aTbl.AndNotI8x64));
  Add('CmpEqI8x64',            Pointer(aTbl.CmpEqI8x64));
  Add('CmpLtI8x64',            Pointer(aTbl.CmpLtI8x64));
  Add('CmpGtI8x64',            Pointer(aTbl.CmpGtI8x64));
  Add('MinI8x64',              Pointer(aTbl.MinI8x64));
  Add('MaxI8x64',              Pointer(aTbl.MaxI8x64));

  // ── U8x64 ──
  Add('AddU8x64',              Pointer(aTbl.AddU8x64));
  Add('SubU8x64',              Pointer(aTbl.SubU8x64));
  Add('AndU8x64',              Pointer(aTbl.AndU8x64));
  Add('OrU8x64',               Pointer(aTbl.OrU8x64));
  Add('XorU8x64',              Pointer(aTbl.XorU8x64));
  Add('NotU8x64',              Pointer(aTbl.NotU8x64));
  Add('CmpEqU8x64',            Pointer(aTbl.CmpEqU8x64));
  Add('CmpLtU8x64',            Pointer(aTbl.CmpLtU8x64));
  Add('CmpGtU8x64',            Pointer(aTbl.CmpGtU8x64));
  Add('MinU8x64',              Pointer(aTbl.MinU8x64));
  Add('MaxU8x64',              Pointer(aTbl.MaxU8x64));

  // ── F32x16 ──
  Add('AddF32x16',             Pointer(aTbl.AddF32x16));
  Add('SubF32x16',             Pointer(aTbl.SubF32x16));
  Add('MulF32x16',             Pointer(aTbl.MulF32x16));
  Add('DivF32x16',             Pointer(aTbl.DivF32x16));

  // ── F64x8 ──
  Add('AddF64x8',              Pointer(aTbl.AddF64x8));
  Add('SubF64x8',              Pointer(aTbl.SubF64x8));
  Add('MulF64x8',              Pointer(aTbl.MulF64x8));
  Add('DivF64x8',              Pointer(aTbl.DivF64x8));

  // ── Comparison operations ──
  Add('CmpEqF32x4',            Pointer(aTbl.CmpEqF32x4));
  Add('CmpLtF32x4',            Pointer(aTbl.CmpLtF32x4));
  Add('CmpLeF32x4',            Pointer(aTbl.CmpLeF32x4));
  Add('CmpGtF32x4',            Pointer(aTbl.CmpGtF32x4));
  Add('CmpGeF32x4',            Pointer(aTbl.CmpGeF32x4));
  Add('CmpNeF32x4',            Pointer(aTbl.CmpNeF32x4));

  Add('CmpEqF64x2',            Pointer(aTbl.CmpEqF64x2));
  Add('CmpLtF64x2',            Pointer(aTbl.CmpLtF64x2));
  Add('CmpLeF64x2',            Pointer(aTbl.CmpLeF64x2));
  Add('CmpGtF64x2',            Pointer(aTbl.CmpGtF64x2));
  Add('CmpGeF64x2',            Pointer(aTbl.CmpGeF64x2));
  Add('CmpNeF64x2',            Pointer(aTbl.CmpNeF64x2));

  Add('CmpEqF32x16',           Pointer(aTbl.CmpEqF32x16));
  Add('CmpLtF32x16',           Pointer(aTbl.CmpLtF32x16));
  Add('CmpLeF32x16',           Pointer(aTbl.CmpLeF32x16));
  Add('CmpGtF32x16',           Pointer(aTbl.CmpGtF32x16));
  Add('CmpGeF32x16',           Pointer(aTbl.CmpGeF32x16));
  Add('CmpNeF32x16',           Pointer(aTbl.CmpNeF32x16));

  Add('CmpEqF64x8',            Pointer(aTbl.CmpEqF64x8));
  Add('CmpLtF64x8',            Pointer(aTbl.CmpLtF64x8));
  Add('CmpLeF64x8',            Pointer(aTbl.CmpLeF64x8));
  Add('CmpGtF64x8',            Pointer(aTbl.CmpGtF64x8));
  Add('CmpGeF64x8',            Pointer(aTbl.CmpGeF64x8));
  Add('CmpNeF64x8',            Pointer(aTbl.CmpNeF64x8));

  Add('CmpEqF32x8',            Pointer(aTbl.CmpEqF32x8));
  Add('CmpLtF32x8',            Pointer(aTbl.CmpLtF32x8));
  Add('CmpLeF32x8',            Pointer(aTbl.CmpLeF32x8));
  Add('CmpGtF32x8',            Pointer(aTbl.CmpGtF32x8));
  Add('CmpGeF32x8',            Pointer(aTbl.CmpGeF32x8));
  Add('CmpNeF32x8',            Pointer(aTbl.CmpNeF32x8));

  Add('CmpEqF64x4',            Pointer(aTbl.CmpEqF64x4));
  Add('CmpLtF64x4',            Pointer(aTbl.CmpLtF64x4));
  Add('CmpLeF64x4',            Pointer(aTbl.CmpLeF64x4));
  Add('CmpGtF64x4',            Pointer(aTbl.CmpGtF64x4));
  Add('CmpGeF64x4',            Pointer(aTbl.CmpGeF64x4));
  Add('CmpNeF64x4',            Pointer(aTbl.CmpNeF64x4));

  // ── Math functions ──
  Add('AbsF32x4',              Pointer(aTbl.AbsF32x4));
  Add('SqrtF32x4',             Pointer(aTbl.SqrtF32x4));
  Add('MinF32x4',              Pointer(aTbl.MinF32x4));
  Add('MaxF32x4',              Pointer(aTbl.MaxF32x4));

  // ── Extended math ──
  Add('FmaF32x4',              Pointer(aTbl.FmaF32x4));
  Add('RcpF32x4',              Pointer(aTbl.RcpF32x4));
  Add('RsqrtF32x4',            Pointer(aTbl.RsqrtF32x4));
  Add('FloorF32x4',            Pointer(aTbl.FloorF32x4));
  Add('CeilF32x4',             Pointer(aTbl.CeilF32x4));
  Add('RoundF32x4',            Pointer(aTbl.RoundF32x4));
  Add('TruncF32x4',            Pointer(aTbl.TruncF32x4));
  Add('ClampF32x4',            Pointer(aTbl.ClampF32x4));

  // ── Wide vector extended math ──
  Add('FmaF64x2',              Pointer(aTbl.FmaF64x2));
  Add('FloorF64x2',            Pointer(aTbl.FloorF64x2));
  Add('CeilF64x2',             Pointer(aTbl.CeilF64x2));
  Add('RoundF64x2',            Pointer(aTbl.RoundF64x2));
  Add('TruncF64x2',            Pointer(aTbl.TruncF64x2));
  Add('AbsF64x2',              Pointer(aTbl.AbsF64x2));
  Add('SqrtF64x2',             Pointer(aTbl.SqrtF64x2));
  Add('MinF64x2',              Pointer(aTbl.MinF64x2));
  Add('MaxF64x2',              Pointer(aTbl.MaxF64x2));
  Add('ClampF64x2',            Pointer(aTbl.ClampF64x2));

  Add('FmaF32x8',              Pointer(aTbl.FmaF32x8));
  Add('FloorF32x8',            Pointer(aTbl.FloorF32x8));
  Add('CeilF32x8',             Pointer(aTbl.CeilF32x8));
  Add('RoundF32x8',            Pointer(aTbl.RoundF32x8));
  Add('TruncF32x8',            Pointer(aTbl.TruncF32x8));
  Add('AbsF32x8',              Pointer(aTbl.AbsF32x8));
  Add('SqrtF32x8',             Pointer(aTbl.SqrtF32x8));
  Add('MinF32x8',              Pointer(aTbl.MinF32x8));
  Add('MaxF32x8',              Pointer(aTbl.MaxF32x8));
  Add('ClampF32x8',            Pointer(aTbl.ClampF32x8));

  Add('FmaF64x4',              Pointer(aTbl.FmaF64x4));
  Add('FloorF64x4',            Pointer(aTbl.FloorF64x4));
  Add('CeilF64x4',             Pointer(aTbl.CeilF64x4));
  Add('RoundF64x4',            Pointer(aTbl.RoundF64x4));
  Add('TruncF64x4',            Pointer(aTbl.TruncF64x4));
  Add('AbsF64x4',              Pointer(aTbl.AbsF64x4));
  Add('SqrtF64x4',             Pointer(aTbl.SqrtF64x4));
  Add('MinF64x4',              Pointer(aTbl.MinF64x4));
  Add('MaxF64x4',              Pointer(aTbl.MaxF64x4));
  Add('ClampF64x4',            Pointer(aTbl.ClampF64x4));

  Add('FmaF32x16',             Pointer(aTbl.FmaF32x16));
  Add('FloorF32x16',           Pointer(aTbl.FloorF32x16));
  Add('CeilF32x16',            Pointer(aTbl.CeilF32x16));
  Add('RoundF32x16',           Pointer(aTbl.RoundF32x16));
  Add('TruncF32x16',           Pointer(aTbl.TruncF32x16));

  Add('FmaF64x8',              Pointer(aTbl.FmaF64x8));
  Add('FloorF64x8',            Pointer(aTbl.FloorF64x8));
  Add('CeilF64x8',             Pointer(aTbl.CeilF64x8));
  Add('RoundF64x8',            Pointer(aTbl.RoundF64x8));
  Add('TruncF64x8',            Pointer(aTbl.TruncF64x8));

  Add('AbsF32x16',             Pointer(aTbl.AbsF32x16));
  Add('SqrtF32x16',            Pointer(aTbl.SqrtF32x16));
  Add('MinF32x16',             Pointer(aTbl.MinF32x16));
  Add('MaxF32x16',             Pointer(aTbl.MaxF32x16));
  Add('ClampF32x16',           Pointer(aTbl.ClampF32x16));

  Add('AbsF64x8',              Pointer(aTbl.AbsF64x8));
  Add('SqrtF64x8',             Pointer(aTbl.SqrtF64x8));
  Add('MinF64x8',              Pointer(aTbl.MinF64x8));
  Add('MaxF64x8',              Pointer(aTbl.MaxF64x8));
  Add('ClampF64x8',            Pointer(aTbl.ClampF64x8));

  // ── 3D/4D Vector math ──
  Add('DotF32x4',              Pointer(aTbl.DotF32x4));
  Add('DotF32x3',              Pointer(aTbl.DotF32x3));
  Add('CrossF32x3',            Pointer(aTbl.CrossF32x3));
  Add('LengthF32x4',           Pointer(aTbl.LengthF32x4));
  Add('LengthF32x3',           Pointer(aTbl.LengthF32x3));
  Add('NormalizeF32x4',        Pointer(aTbl.NormalizeF32x4));
  Add('NormalizeF32x3',        Pointer(aTbl.NormalizeF32x3));

  // ── FMA-optimized Dot ──
  Add('DotF32x8',              Pointer(aTbl.DotF32x8));
  Add('DotF64x2',              Pointer(aTbl.DotF64x2));
  Add('DotF64x4',              Pointer(aTbl.DotF64x4));

  // ── Reduction ──
  Add('ReduceAddF32x4',        Pointer(aTbl.ReduceAddF32x4));
  Add('ReduceMinF32x4',        Pointer(aTbl.ReduceMinF32x4));
  Add('ReduceMaxF32x4',        Pointer(aTbl.ReduceMaxF32x4));
  Add('ReduceMulF32x4',        Pointer(aTbl.ReduceMulF32x4));

  Add('ReduceAddF64x2',        Pointer(aTbl.ReduceAddF64x2));
  Add('ReduceMinF64x2',        Pointer(aTbl.ReduceMinF64x2));
  Add('ReduceMaxF64x2',        Pointer(aTbl.ReduceMaxF64x2));
  Add('ReduceMulF64x2',        Pointer(aTbl.ReduceMulF64x2));

  Add('ReduceAddF32x8',        Pointer(aTbl.ReduceAddF32x8));
  Add('ReduceMinF32x8',        Pointer(aTbl.ReduceMinF32x8));
  Add('ReduceMaxF32x8',        Pointer(aTbl.ReduceMaxF32x8));
  Add('ReduceMulF32x8',        Pointer(aTbl.ReduceMulF32x8));

  Add('ReduceAddF64x4',        Pointer(aTbl.ReduceAddF64x4));
  Add('ReduceMinF64x4',        Pointer(aTbl.ReduceMinF64x4));
  Add('ReduceMaxF64x4',        Pointer(aTbl.ReduceMaxF64x4));
  Add('ReduceMulF64x4',        Pointer(aTbl.ReduceMulF64x4));

  Add('ReduceAddF32x16',       Pointer(aTbl.ReduceAddF32x16));
  Add('ReduceMinF32x16',       Pointer(aTbl.ReduceMinF32x16));
  Add('ReduceMaxF32x16',       Pointer(aTbl.ReduceMaxF32x16));
  Add('ReduceMulF32x16',       Pointer(aTbl.ReduceMulF32x16));

  Add('ReduceAddF64x8',        Pointer(aTbl.ReduceAddF64x8));
  Add('ReduceMinF64x8',        Pointer(aTbl.ReduceMinF64x8));
  Add('ReduceMaxF64x8',        Pointer(aTbl.ReduceMaxF64x8));
  Add('ReduceMulF64x8',        Pointer(aTbl.ReduceMulF64x8));

  // ── Memory ops ──
  Add('LoadF32x4',             Pointer(aTbl.LoadF32x4));
  Add('LoadF32x4Aligned',      Pointer(aTbl.LoadF32x4Aligned));
  Add('StoreF32x4',            Pointer(aTbl.StoreF32x4));
  Add('StoreF32x4Aligned',     Pointer(aTbl.StoreF32x4Aligned));

  // ── Utility ──
  Add('SplatF32x4',            Pointer(aTbl.SplatF32x4));
  Add('ZeroF32x4',             Pointer(aTbl.ZeroF32x4));
  Add('SelectF32x4',           Pointer(aTbl.SelectF32x4));
  Add('ExtractF32x4',          Pointer(aTbl.ExtractF32x4));
  Add('InsertF32x4',           Pointer(aTbl.InsertF32x4));

  // ── Extract/Insert Lane ──
  Add('ExtractF64x2',          Pointer(aTbl.ExtractF64x2));
  Add('InsertF64x2',           Pointer(aTbl.InsertF64x2));
  Add('ExtractI32x4',          Pointer(aTbl.ExtractI32x4));
  Add('InsertI32x4',           Pointer(aTbl.InsertI32x4));
  Add('ExtractI64x2',          Pointer(aTbl.ExtractI64x2));
  Add('InsertI64x2',           Pointer(aTbl.InsertI64x2));
  Add('ExtractF32x8',          Pointer(aTbl.ExtractF32x8));
  Add('InsertF32x8',           Pointer(aTbl.InsertF32x8));
  Add('ExtractF64x4',          Pointer(aTbl.ExtractF64x4));
  Add('InsertF64x4',           Pointer(aTbl.InsertF64x4));
  Add('ExtractI32x8',          Pointer(aTbl.ExtractI32x8));
  Add('InsertI32x8',           Pointer(aTbl.InsertI32x8));
  Add('ExtractI64x4',          Pointer(aTbl.ExtractI64x4));
  Add('InsertI64x4',           Pointer(aTbl.InsertI64x4));
  Add('ExtractF32x16',         Pointer(aTbl.ExtractF32x16));
  Add('InsertF32x16',          Pointer(aTbl.InsertF32x16));
  Add('ExtractI32x16',         Pointer(aTbl.ExtractI32x16));
  Add('InsertI32x16',          Pointer(aTbl.InsertI32x16));

  // ── Wide Load/Store/Splat/Zero ──
  Add('LoadF64x2',             Pointer(aTbl.LoadF64x2));
  Add('StoreF64x2',            Pointer(aTbl.StoreF64x2));
  Add('SplatF64x2',            Pointer(aTbl.SplatF64x2));
  Add('ZeroF64x2',             Pointer(aTbl.ZeroF64x2));
  Add('LoadF32x8',             Pointer(aTbl.LoadF32x8));
  Add('StoreF32x8',            Pointer(aTbl.StoreF32x8));
  Add('SplatF32x8',            Pointer(aTbl.SplatF32x8));
  Add('ZeroF32x8',             Pointer(aTbl.ZeroF32x8));
  Add('LoadF64x4',             Pointer(aTbl.LoadF64x4));
  Add('StoreF64x4',            Pointer(aTbl.StoreF64x4));
  Add('SplatF64x4',            Pointer(aTbl.SplatF64x4));
  Add('ZeroF64x4',             Pointer(aTbl.ZeroF64x4));
  Add('LoadF32x16',            Pointer(aTbl.LoadF32x16));
  Add('StoreF32x16',           Pointer(aTbl.StoreF32x16));
  Add('SplatF32x16',           Pointer(aTbl.SplatF32x16));
  Add('ZeroF32x16',            Pointer(aTbl.ZeroF32x16));
  Add('LoadF64x8',             Pointer(aTbl.LoadF64x8));
  Add('StoreF64x8',            Pointer(aTbl.StoreF64x8));
  Add('SplatF64x8',            Pointer(aTbl.SplatF64x8));
  Add('ZeroF64x8',             Pointer(aTbl.ZeroF64x8));

  // ── Facade (Mem) ──
  Add('MemEqual',              Pointer(aTbl.MemEqual));
  Add('MemFindByte',           Pointer(aTbl.MemFindByte));
  Add('MemDiffRange',          Pointer(aTbl.MemDiffRange));
  Add('MemCopy',               Pointer(aTbl.MemCopy));
  Add('MemSet',                Pointer(aTbl.MemSet));
  Add('MemReverse',            Pointer(aTbl.MemReverse));
  Add('SumBytes',              Pointer(aTbl.SumBytes));
  Add('MinMaxBytes',           Pointer(aTbl.MinMaxBytes));
  Add('CountByte',             Pointer(aTbl.CountByte));
  Add('Utf8Validate',          Pointer(aTbl.Utf8Validate));
  Add('AsciiIEqual',           Pointer(aTbl.AsciiIEqual));
  Add('ToLowerAscii',          Pointer(aTbl.ToLowerAscii));
  Add('ToUpperAscii',          Pointer(aTbl.ToUpperAscii));
  Add('BytesIndexOf',          Pointer(aTbl.BytesIndexOf));
  Add('BitsetPopCount',        Pointer(aTbl.BitsetPopCount));

  // ── Saturating Arithmetic ──
  Add('I8x16SatAdd',           Pointer(aTbl.I8x16SatAdd));
  Add('I8x16SatSub',           Pointer(aTbl.I8x16SatSub));
  Add('I16x8SatAdd',           Pointer(aTbl.I16x8SatAdd));
  Add('I16x8SatSub',           Pointer(aTbl.I16x8SatSub));
  Add('U8x16SatAdd',           Pointer(aTbl.U8x16SatAdd));
  Add('U8x16SatSub',           Pointer(aTbl.U8x16SatSub));
  Add('U16x8SatAdd',           Pointer(aTbl.U16x8SatAdd));
  Add('U16x8SatSub',           Pointer(aTbl.U16x8SatSub));

  // ── I16x8 ──
  Add('AddI16x8',              Pointer(aTbl.AddI16x8));
  Add('SubI16x8',              Pointer(aTbl.SubI16x8));
  Add('MulI16x8',              Pointer(aTbl.MulI16x8));
  Add('AndI16x8',              Pointer(aTbl.AndI16x8));
  Add('OrI16x8',               Pointer(aTbl.OrI16x8));
  Add('XorI16x8',              Pointer(aTbl.XorI16x8));
  Add('NotI16x8',              Pointer(aTbl.NotI16x8));
  Add('AndNotI16x8',           Pointer(aTbl.AndNotI16x8));
  Add('ShiftLeftI16x8',        Pointer(aTbl.ShiftLeftI16x8));
  Add('ShiftRightI16x8',       Pointer(aTbl.ShiftRightI16x8));
  Add('ShiftRightArithI16x8',  Pointer(aTbl.ShiftRightArithI16x8));
  Add('CmpEqI16x8',            Pointer(aTbl.CmpEqI16x8));
  Add('CmpLtI16x8',            Pointer(aTbl.CmpLtI16x8));
  Add('CmpGtI16x8',            Pointer(aTbl.CmpGtI16x8));
  Add('CmpLeI16x8',            Pointer(aTbl.CmpLeI16x8));
  Add('CmpGeI16x8',            Pointer(aTbl.CmpGeI16x8));
  Add('CmpNeI16x8',            Pointer(aTbl.CmpNeI16x8));
  Add('MinI16x8',              Pointer(aTbl.MinI16x8));
  Add('MaxI16x8',              Pointer(aTbl.MaxI16x8));

  // ── I8x16 ──
  Add('AddI8x16',              Pointer(aTbl.AddI8x16));
  Add('SubI8x16',              Pointer(aTbl.SubI8x16));
  Add('AndI8x16',              Pointer(aTbl.AndI8x16));
  Add('OrI8x16',               Pointer(aTbl.OrI8x16));
  Add('XorI8x16',              Pointer(aTbl.XorI8x16));
  Add('NotI8x16',              Pointer(aTbl.NotI8x16));
  Add('CmpEqI8x16',            Pointer(aTbl.CmpEqI8x16));
  Add('CmpLtI8x16',            Pointer(aTbl.CmpLtI8x16));
  Add('CmpGtI8x16',            Pointer(aTbl.CmpGtI8x16));
  Add('CmpLeI8x16',            Pointer(aTbl.CmpLeI8x16));
  Add('CmpGeI8x16',            Pointer(aTbl.CmpGeI8x16));
  Add('CmpNeI8x16',            Pointer(aTbl.CmpNeI8x16));
  Add('MinI8x16',              Pointer(aTbl.MinI8x16));
  Add('MaxI8x16',              Pointer(aTbl.MaxI8x16));

  // ── U32x4 ──
  Add('AddU32x4',              Pointer(aTbl.AddU32x4));
  Add('SubU32x4',              Pointer(aTbl.SubU32x4));
  Add('MulU32x4',              Pointer(aTbl.MulU32x4));
  Add('AndU32x4',              Pointer(aTbl.AndU32x4));
  Add('OrU32x4',               Pointer(aTbl.OrU32x4));
  Add('XorU32x4',              Pointer(aTbl.XorU32x4));
  Add('NotU32x4',              Pointer(aTbl.NotU32x4));
  Add('AndNotU32x4',           Pointer(aTbl.AndNotU32x4));
  Add('ShiftLeftU32x4',        Pointer(aTbl.ShiftLeftU32x4));
  Add('ShiftRightU32x4',       Pointer(aTbl.ShiftRightU32x4));
  Add('CmpEqU32x4',            Pointer(aTbl.CmpEqU32x4));
  Add('CmpLtU32x4',            Pointer(aTbl.CmpLtU32x4));
  Add('CmpGtU32x4',            Pointer(aTbl.CmpGtU32x4));
  Add('CmpLeU32x4',            Pointer(aTbl.CmpLeU32x4));
  Add('CmpGeU32x4',            Pointer(aTbl.CmpGeU32x4));
  Add('MinU32x4',              Pointer(aTbl.MinU32x4));
  Add('MaxU32x4',              Pointer(aTbl.MaxU32x4));

  // ── U16x8 ──
  Add('AddU16x8',              Pointer(aTbl.AddU16x8));
  Add('SubU16x8',              Pointer(aTbl.SubU16x8));
  Add('MulU16x8',              Pointer(aTbl.MulU16x8));
  Add('AndU16x8',              Pointer(aTbl.AndU16x8));
  Add('OrU16x8',               Pointer(aTbl.OrU16x8));
  Add('XorU16x8',              Pointer(aTbl.XorU16x8));
  Add('NotU16x8',              Pointer(aTbl.NotU16x8));
  Add('ShiftLeftU16x8',        Pointer(aTbl.ShiftLeftU16x8));
  Add('ShiftRightU16x8',       Pointer(aTbl.ShiftRightU16x8));
  Add('CmpEqU16x8',            Pointer(aTbl.CmpEqU16x8));
  Add('CmpLtU16x8',            Pointer(aTbl.CmpLtU16x8));
  Add('CmpGtU16x8',            Pointer(aTbl.CmpGtU16x8));
  Add('CmpLeU16x8',            Pointer(aTbl.CmpLeU16x8));
  Add('CmpGeU16x8',            Pointer(aTbl.CmpGeU16x8));
  Add('CmpNeU16x8',            Pointer(aTbl.CmpNeU16x8));
  Add('MinU16x8',              Pointer(aTbl.MinU16x8));
  Add('MaxU16x8',              Pointer(aTbl.MaxU16x8));

  // ── U8x16 ──
  Add('AddU8x16',              Pointer(aTbl.AddU8x16));
  Add('SubU8x16',              Pointer(aTbl.SubU8x16));
  Add('AndU8x16',              Pointer(aTbl.AndU8x16));
  Add('OrU8x16',               Pointer(aTbl.OrU8x16));
  Add('XorU8x16',              Pointer(aTbl.XorU8x16));
  Add('NotU8x16',              Pointer(aTbl.NotU8x16));
  Add('CmpEqU8x16',            Pointer(aTbl.CmpEqU8x16));
  Add('CmpLtU8x16',            Pointer(aTbl.CmpLtU8x16));
  Add('CmpGtU8x16',            Pointer(aTbl.CmpGtU8x16));
  Add('CmpLeU8x16',            Pointer(aTbl.CmpLeU8x16));
  Add('CmpGeU8x16',            Pointer(aTbl.CmpGeU8x16));
  Add('CmpNeU8x16',            Pointer(aTbl.CmpNeU8x16));
  Add('MinU8x16',              Pointer(aTbl.MinU8x16));
  Add('MaxU8x16',              Pointer(aTbl.MaxU8x16));

  // ── Mask ──
  Add('Mask2All',              Pointer(aTbl.Mask2All));
  Add('Mask2Any',              Pointer(aTbl.Mask2Any));
  Add('Mask2None',             Pointer(aTbl.Mask2None));
  Add('Mask2PopCount',         Pointer(aTbl.Mask2PopCount));
  Add('Mask2FirstSet',         Pointer(aTbl.Mask2FirstSet));
  Add('Mask4All',              Pointer(aTbl.Mask4All));
  Add('Mask4Any',              Pointer(aTbl.Mask4Any));
  Add('Mask4None',             Pointer(aTbl.Mask4None));
  Add('Mask4PopCount',         Pointer(aTbl.Mask4PopCount));
  Add('Mask4FirstSet',         Pointer(aTbl.Mask4FirstSet));
  Add('Mask8All',              Pointer(aTbl.Mask8All));
  Add('Mask8Any',              Pointer(aTbl.Mask8Any));
  Add('Mask8None',             Pointer(aTbl.Mask8None));
  Add('Mask8PopCount',         Pointer(aTbl.Mask8PopCount));
  Add('Mask8FirstSet',         Pointer(aTbl.Mask8FirstSet));
  Add('Mask16All',             Pointer(aTbl.Mask16All));
  Add('Mask16Any',             Pointer(aTbl.Mask16Any));
  Add('Mask16None',            Pointer(aTbl.Mask16None));
  Add('Mask16PopCount',        Pointer(aTbl.Mask16PopCount));
  Add('Mask16FirstSet',        Pointer(aTbl.Mask16FirstSet));

  // ── Select ──
  Add('SelectF64x2',           Pointer(aTbl.SelectF64x2));
  Add('SelectF32x16',          Pointer(aTbl.SelectF32x16));
  Add('SelectF64x8',           Pointer(aTbl.SelectF64x8));
  Add('SelectI32x4',           Pointer(aTbl.SelectI32x4));
  Add('SelectF32x8',           Pointer(aTbl.SelectF32x8));
  Add('SelectF64x4',           Pointer(aTbl.SelectF64x4));

  // ── Narrow AndNot ──
  Add('AndNotI8x16',           Pointer(aTbl.AndNotI8x16));
  Add('AndNotU16x8',           Pointer(aTbl.AndNotU16x8));
  Add('AndNotU8x16',           Pointer(aTbl.AndNotU8x16));

  // ── Batch Array F32 ──
  Add('ArrayAddF32',           Pointer(aTbl.ArrayAddF32));
  Add('ArraySubF32',           Pointer(aTbl.ArraySubF32));
  Add('ArrayMulF32',           Pointer(aTbl.ArrayMulF32));
  Add('ArrayDivF32',           Pointer(aTbl.ArrayDivF32));
  Add('ArrayMinF32',           Pointer(aTbl.ArrayMinF32));
  Add('ArrayMaxF32',           Pointer(aTbl.ArrayMaxF32));
  Add('ArrayAbsF32',           Pointer(aTbl.ArrayAbsF32));
  Add('ArrayNegF32',           Pointer(aTbl.ArrayNegF32));
  Add('ArraySqrtF32',          Pointer(aTbl.ArraySqrtF32));
  Add('ArrayRcpF32',           Pointer(aTbl.ArrayRcpF32));
  Add('ArrayRsqrtF32',         Pointer(aTbl.ArrayRsqrtF32));
  Add('ArrayRcpRefineF32',     Pointer(aTbl.ArrayRcpRefineF32));
  Add('ArrayRsqrtRefineF32',   Pointer(aTbl.ArrayRsqrtRefineF32));
  Add('ArrayAddScalarF32',     Pointer(aTbl.ArrayAddScalarF32));
  Add('ArrayMulScalarF32',     Pointer(aTbl.ArrayMulScalarF32));
  Add('ArrayClampF32',         Pointer(aTbl.ArrayClampF32));
  Add('ArrayFmaF32',           Pointer(aTbl.ArrayFmaF32));
  Add('ArrayAxpyF32',          Pointer(aTbl.ArrayAxpyF32));
  Add('ReduceSumF32',          Pointer(aTbl.ReduceSumF32));
  Add('ReduceDotF32',          Pointer(aTbl.ReduceDotF32));
  Add('ReduceMinF32',          Pointer(aTbl.ReduceMinF32));
  Add('ReduceMaxF32',          Pointer(aTbl.ReduceMaxF32));

  // ── Batch Array F64 ──
  Add('ArrayAddF64',           Pointer(aTbl.ArrayAddF64));
  Add('ArraySubF64',           Pointer(aTbl.ArraySubF64));
  Add('ArrayMulF64',           Pointer(aTbl.ArrayMulF64));
  Add('ArrayDivF64',           Pointer(aTbl.ArrayDivF64));
  Add('ReduceSumF64',          Pointer(aTbl.ReduceSumF64));
  Add('ReduceDotF64',          Pointer(aTbl.ReduceDotF64));
  Add('ReduceMinF64',          Pointer(aTbl.ReduceMinF64));
  Add('ReduceMaxF64',          Pointer(aTbl.ReduceMaxF64));
  Add('ArrayAbsF64',           Pointer(aTbl.ArrayAbsF64));
  Add('ArrayNegF64',           Pointer(aTbl.ArrayNegF64));
  Add('ArraySqrtF64',          Pointer(aTbl.ArraySqrtF64));
  Add('ArrayMulScalarF64',     Pointer(aTbl.ArrayMulScalarF64));
  Add('ArrayAddScalarF64',     Pointer(aTbl.ArrayAddScalarF64));
  Add('ArrayClampF64',         Pointer(aTbl.ArrayClampF64));
  Add('ArrayLinearF64',        Pointer(aTbl.ArrayLinearF64));

  // ── Batch Transcendental ──
  Add('ArrayExpF32',           Pointer(aTbl.ArrayExpF32));
  Add('ArrayLogF32',           Pointer(aTbl.ArrayLogF32));
  Add('ArrayPowF32',           Pointer(aTbl.ArrayPowF32));
  Add('ArraySinF32',           Pointer(aTbl.ArraySinF32));
  Add('ArrayCosF32',           Pointer(aTbl.ArrayCosF32));

  // ── Batch Integer ──
  Add('ArrayAddI32',           Pointer(aTbl.ArrayAddI32));
  Add('ArraySubI32',           Pointer(aTbl.ArraySubI32));
  Add('ArrayMulI16',           Pointer(aTbl.ArrayMulI16));
  Add('ArrayPackSatI32toI16',  Pointer(aTbl.ArrayPackSatI32toI16));

  // ── Batch Type Conversion ──
  Add('ArrayF32toI32',         Pointer(aTbl.ArrayF32toI32));
  Add('ArrayI32toF32',         Pointer(aTbl.ArrayI32toF32));

  // ── Batch Bitwise ──
  Add('ArrayAndI32',           Pointer(aTbl.ArrayAndI32));
  Add('ArrayOrI32',            Pointer(aTbl.ArrayOrI32));
  Add('ArrayXorI32',           Pointer(aTbl.ArrayXorI32));
  Add('ArrayShlI32',           Pointer(aTbl.ArrayShlI32));
  Add('ArrayShrI32',           Pointer(aTbl.ArrayShrI32));

  // ── Fused Batch ──
  Add('ArrayLinearF32',        Pointer(aTbl.ArrayLinearF32));
  Add('ArrayAbsDiffF32',       Pointer(aTbl.ArrayAbsDiffF32));
  Add('ArrayReLUF32',          Pointer(aTbl.ArrayReLUF32));
  Add('ArrayNormF32',          Pointer(aTbl.ArrayNormF32));
  Add('ArrayLinearReLUF32',    Pointer(aTbl.ArrayLinearReLUF32));

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
