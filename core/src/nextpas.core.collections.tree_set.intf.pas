unit nextpas.core.collections.tree_set.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.intf;

type

  // TreeSet 公共接口 - 基于红黑树实现的有序集合
  generic ITreeSet<T> = interface(specialize IGenericCollection<T>)
    ['{9F7A8B6C-1D2E-4F3A-8B9C-0D1E2F3A4B5C}']
    function Add(const AValue: T): Boolean;
    function Remove(const AValue: T): Boolean;

    // Set operations
    function Union(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
    function Intersect(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
    function Difference(const Other: specialize ITreeSet<T>): specialize ITreeSet<T>;
  end;

implementation

end.
