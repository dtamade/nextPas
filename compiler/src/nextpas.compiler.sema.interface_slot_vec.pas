unit nextpas.compiler.sema.interface_slot_vec;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

{ Satellite unit: specialize TVec<TInterfaceSlotMeta> outside nextpas.compiler.sema.semantic_model
  so the model object file stays under the ELF per-object section limit (~65k
  with -CX function sections). See also nextpas.compiler.sema.vmt_slot_vec /
  nextpas.compiler.sema.property_meta_vec. }

interface

uses
  nextpas.core.collections.vec;

type
  TInterfaceSlotMeta = record
    InterfaceName: string;
    SlotOffset: LongInt;
  end;

  { Nested product table owned by type-metadata entry (default heap). }
  TSemanticInterfaceSlotMetaVec = specialize TVec<TInterfaceSlotMeta>;

implementation

end.
