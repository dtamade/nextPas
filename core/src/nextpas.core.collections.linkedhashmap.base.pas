unit nextpas.core.collections.linkedhashmap.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.base;

type

  {**
   * TLinkedNode<K,V>
   *
   * @desc Internal doubly-linked list node for maintaining order
   *       Stores the actual key/value pair for pointer iteration
   *}
  generic TLinkedNode<K,V> = record
    Pair: specialize TPair<K,V>;
    Prev: Pointer;  // Points to previous node
    Next: Pointer;  // Points to next node
  end;

implementation

end.
