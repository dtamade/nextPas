unit np_semantic_field_meta_vec;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

{ Satellite unit: specialize TVec<TFieldMeta> outside np_semantic_model so the
  model object file stays under the ELF per-object section limit (~65k with
  -CX function sections). See also np_semantic_vmt_slot_vec /
  np_semantic_property_meta_vec / np_semantic_interface_slot_vec. }

interface

uses
  nextpas.core.collections.vec;

type
  TFieldMeta = record
    Name: string;
    Index: LongInt;
    IsString: Boolean;
    IsPointer: Boolean;
    IsDynArray: Boolean;
    IsRecord: Boolean;
    TypeId: LongInt;
  end;

  { Nested product table owned by type-metadata entry (default heap). }
  TSemanticFieldMetaVec = specialize TVec<TFieldMeta>;

implementation

end.
