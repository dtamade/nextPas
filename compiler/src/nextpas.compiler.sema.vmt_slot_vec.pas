unit nextpas.compiler.sema.vmt_slot_vec;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

{ Satellite unit: specialize TVec<TVmtSlot> outside nextpas.compiler.sema.semantic_model so the
  model object file stays under the ELF per-object section limit (~65k with
  -CX function sections). Nested type-meta product tables that would add more
  specialize TVec instances should land here or in similar satellites. }

interface

uses
  nextpas.core.collections.vec;

type
  TVmtSlot = record
    MethodName: string;
    SlotIndex: LongInt;
    FuncQualName: string;
  end;

  { Nested product table owned by type-metadata entry (default heap). }
  TSemanticVmtSlotVec = specialize TVec<TVmtSlot>;

implementation

end.
