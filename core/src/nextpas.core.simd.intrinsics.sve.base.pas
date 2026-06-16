unit nextpas.core.simd.intrinsics.sve.base;
// Disposition: Experimental Support — shared SVE/SVE2 type records only


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{
  SVE/SVE2 shared type leaf.
  This unit carries predicate/vector record shapes for isolated SVE/SVE2
  intrinsics experiments. It has no runtime primitives and is not a stable public backend.
}

interface

uses
  nextpas.core.simd.intrinsics.base;

{$IFDEF CPUAARCH64}

type
  TSVEVector = record
    case Integer of
      0: (sve_u32: array[0..15] of UInt32);
      1: (sve_i32: array[0..15] of LongInt);
      2: (sve_f32: array[0..15] of Single);
      3: (sve_u64: array[0..7] of UInt64);
      4: (sve_i64: array[0..7] of Int64);
      5: (sve_f64: array[0..7] of Double);
  end;
  PSVEVector = ^TSVEVector;

  TSVEPredicate = record
    pred_mask: array[0..15] of Boolean;
  end;
  PSVEPredicate = ^TSVEPredicate;

{$ENDIF}

implementation

end.
