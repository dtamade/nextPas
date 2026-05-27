unit nextpas.core.collections.skiplist.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  SKIPLIST_MAX_LEVEL = 32;
  SKIPLIST_P = 0.25; // 概率因子



type

  {**
   * TSkipListEntry<K,V>
   *
   * @desc 跳表条目
   *}
  generic TSkipListEntry<K, V> = record
    Key: K;
    Value: V;
  end;

implementation

end.
