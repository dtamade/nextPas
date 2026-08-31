unit nextpas.compiler.sema.field_meta_vec;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

{ Satellite unit: specialize TVec<TFieldMeta> outside nextpas.compiler.sema.semantic_model so the
  model object file stays under the ELF per-object section limit (~65k with
  -CX function sections). See also nextpas.compiler.sema.vmt_slot_vec /
  nextpas.compiler.sema.property_meta_vec / nextpas.compiler.sema.interface_slot_vec. }

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
