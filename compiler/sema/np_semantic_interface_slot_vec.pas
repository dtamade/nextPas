unit np_semantic_interface_slot_vec;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

{ Satellite unit: specialize TVec<TInterfaceSlotMeta> outside np_semantic_model
  so the model object file stays under the ELF per-object section limit (~65k
  with -CX function sections). See also np_semantic_vmt_slot_vec /
  np_semantic_property_meta_vec. }

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
