unit nextpas.core.collections;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.collections.base,
  nextpas.core.collections.vec;

type
  generic IVec<T> = specialize nextpas.core.collections.vec.IVec<T>;
  generic TVec<T> = specialize nextpas.core.collections.vec.TVec<T>;

implementation

end.
