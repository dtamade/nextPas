unit np_semantic_property_meta_vec;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

{ Satellite unit: specialize TVec<TPropertyMeta> outside np_semantic_model so
  the model object file stays under the ELF per-object section limit (~65k with
  -CX function sections). See also np_semantic_vmt_slot_vec. }

interface

uses
  nextpas.core.collections.vec;

type
  TPropertyMeta = record
    Name: string;
    ReadAccessor: string;
    WriteAccessor: string;
  end;

  { Nested product table owned by type-metadata entry (default heap). }
  TSemanticPropertyMetaVec = specialize TVec<TPropertyMeta>;

implementation

end.
