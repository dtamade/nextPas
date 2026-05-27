unit nextpas.core.collections.hashmap.base;

{$I nextpas.core.settings.inc}

interface

const
  DEFAULT_MAX_LOAD_FACTOR = 0.86;

type
  {**
   * TKeyHashFunc<K>
   *
   * @desc Hash function for key type K
   * @param AKey The key to hash
   * @return UInt32 hash value
   *}
  generic TKeyHashFunc<K> = function(const AKey: K): UInt32;

  {**
   * TKeyEqualsFunc<K>
   *
   * @desc Equality comparison function for key type K
   * @param L Left operand
   * @param R Right operand
   * @return Boolean True if L equals R
   *}
  generic TKeyEqualsFunc<K> = function(const L, R: K): Boolean;

  { Entry API 回调类型 }
  generic TValueSupplierFunc<V> = function: V;
  generic TValueModifierProc<V> = procedure(var Value: V);

implementation

end.
