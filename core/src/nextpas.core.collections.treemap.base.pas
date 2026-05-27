unit nextpas.core.collections.treemap.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.base;

type

  {** TKeyValueCallback - Callback for key-value pairs }
  generic TKeyValueCallback<K, V> = procedure(const aEntry: specialize TMapEntry<K, V>; aData: Pointer);

  { Entry API 回调类型 }
  generic TTreeValueSupplierFunc<V> = function: V;
  generic TTreeValueModifierProc<V> = procedure(var Value: V);

implementation

end.
