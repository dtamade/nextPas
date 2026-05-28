unit nextpas.core.collections.orderedmap.rb.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {**
   * IRBTreeMap<K,V> - 红黑树有序映射接口
   *
   * @desc 有序映射接口，基于红黑树实现，按键排序
   *}
  generic IRBTreeMap<K, V> = interface
    ['{E5F6A7B8-C9D0-1234-EF01-567890ABCDEF}']
    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function Get(const AKey: K): V;
    function Add(const AKey: K; const AValue: V): Boolean;
    function AddOrAssign(const AKey: K; const AValue: V): Boolean;
    procedure Put(const AKey: K; const AValue: V);
    function TryUpdate(const AKey: K; const AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    function Remove(const AKey: K): Boolean;
    procedure Clear;
    function GetCount: SizeUInt;
    property Count: SizeUInt read GetCount;
  end;

implementation

end.
