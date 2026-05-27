unit nextpas.core.collections.orderedmap.rb.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {** TRBMapEntry<K,V> - 红黑树映射条目 }
  generic TRBMapEntry<K,V> = record
    Key: K;
    Value: V;
  end;

implementation

end.
