unit nextpas.core.collections.hashmap.base;

{$I nextpas.core.settings.inc}

interface

const
  DEFAULT_MAX_LOAD_FACTOR = 0.75;

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

{**
 * HashMix32 / HashOf* integer helpers live here so LruCache and other units
 * do not need to depend on the open-addressing THashMap implementation unit.
 *}
function HashMix32(x: UInt32): UInt32;
function HashOfPointer(p: Pointer): UInt32;
function HashOfUInt32(x: UInt32): UInt32;
function HashOfUInt64(x: QWord): UInt32;

implementation

function HashMix32(x: UInt32): UInt32;
begin
  x := (x xor (x shr 16)) * $7feb352d;
  x := (x xor (x shr 15)) * $846ca68b;
  x := x xor (x shr 16);
  Result := x;
end;

function HashOfPointer(p: Pointer): UInt32;
begin
  Result := HashMix32(UInt32(PtrUInt(p)));
end;

function HashOfUInt32(x: UInt32): UInt32;
begin
  Result := HashMix32(x);
end;

function HashOfUInt64(x: QWord): UInt32;
begin
  { SplitMix64 — better avalanche for integer keys than split+multiply }
  Inc(x, QWord($9E3779B97F4A7C15));
  x := (x xor (x shr 30)) * QWord($BF58476D1CE4E5B9);
  x := (x xor (x shr 27)) * QWord($94D049BB133111EB);
  Result := UInt32(x xor (x shr 32));
end;

end.
