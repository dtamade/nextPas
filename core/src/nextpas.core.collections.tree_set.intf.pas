unit nextpas.core.collections.tree_set.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.intf;

type

  generic ITreeSet<T> = interface(specialize IGenericCollection<T>)
    ['{9F7A8B6C-1D2E-4F3A-8B9C-0D1E2F3A4B5C}']
    function Add(const AValue: T): Boolean;
    function Remove(const AValue: T): Boolean;
    function Contains(const AValue: T): Boolean;

    function LowerBound(const AValue: T; out OutValue: T): Boolean;
    function UpperBound(const AValue: T; out OutValue: T): Boolean;
    function Min(out OutValue: T): Boolean;
    function Max(out OutValue: T): Boolean;

    function Union(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
    function Intersect(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
    function Difference(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
  end;

implementation

end.
