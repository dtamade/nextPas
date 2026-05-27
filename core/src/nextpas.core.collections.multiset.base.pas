unit nextpas.core.collections.multiset.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {**
   * TMultiSetEntry<T>
   *
   * @desc 多重集合条目，包含元素和计数
   *}
  generic TMultiSetEntry<T> = record
    Element: T;
    Count: SizeUInt;
  end;

implementation

end.
