unit nextpas.core.collections.linkedhashmap.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.collections.base,
  nextpas.core.collections.hashmap.intf;

type

  {**
   * ILinkedHashMap<K,V>
   *
   * @desc Hash map that maintains insertion order
   * @param K Key type
   * @param V Value type
   * @note Combines O(1) hash lookups with predictable iteration order
   *}
  generic ILinkedHashMap<K,V> = interface(specialize IHashMap<K,V>)
  ['{8F9A2B3C-4D5E-6F7A-8B9C-0D1E2F3A4B5C}']
    {**
     * First
     *
     * @desc Returns the first inserted key-value pair
     * @return TPair<K,V> The first pair
     * @raises Exception if map is empty
     *}
    function First: specialize TPair<K,V>;

    {**
     * Last
     *
     * @desc Returns the last inserted key-value pair
     * @return TPair<K,V> The last pair
     * @raises Exception if map is empty
     *}
    function Last: specialize TPair<K,V>;

    {**
     * TryGetFirst
     *
     * @desc Safely attempts to get the first pair
     * @param aPair Output parameter for the first pair
     * @return Boolean True if map is not empty
     *}
    function TryGetFirst(out aPair: specialize TPair<K,V>): Boolean;

    {**
     * TryGetLast
     *
     * @desc Safely attempts to get the last pair
     * @param aPair Output parameter for the last pair
     * @return Boolean True if map is not empty
     *}
    function TryGetLast(out aPair: specialize TPair<K,V>): Boolean;
  end;

implementation

end.
