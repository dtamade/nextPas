unit nextpas.core.collections.lrucache.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {** THashFunc - 泛型哈希函数类型 }
  generic THashFunc<T> = function (const aValue: T; aData: Pointer): UInt64;

  {** TEqualsFunc - 泛型相等比较函数类型 }
  generic TEqualsFunc<T> = function (const aLeft, aRight: T; aData: Pointer): Boolean;

  { TLruNode<K,V> LRU 缓存节点 }
  generic TLruNode<K, V> = record
    Key: K;
    Value: V;
    Prev: Pointer;
    Next: Pointer;
  end;

implementation

end.
