unit nextpas.core.collections.skiplist.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {**
   * ISkipList<K,V> - 跳表接口
   *
   * @desc 有序映射接口，支持 O(log n) 查找、范围查询
   *}
  generic ISkipList<K, V> = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function TryGetValue(const aKey: K; out aValue: V): Boolean;
    function Get(const aKey: K): V;
    function Add(const aKey: K; const aValue: V): Boolean;
    function AddOrAssign(const aKey: K; const aValue: V): Boolean;
    procedure Put(const aKey: K; const aValue: V);
    function ContainsKey(const aKey: K): Boolean;
    function Remove(const aKey: K): Boolean;
    procedure Clear;
    function Min(out aKey: K; out aValue: V): Boolean;
    function Max(out aKey: K; out aValue: V): Boolean;
    function GetCount: SizeUInt;
    function IsEmpty: Boolean;
    property Count: SizeUInt read GetCount;
  end;

implementation

end.
