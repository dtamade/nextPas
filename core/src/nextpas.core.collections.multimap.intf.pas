unit nextpas.core.collections.multimap.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {**
   * IMultiMap<K,V> - 一对多映射接口
   *
   * @desc 允许一个键对应多个值的映射接口
   *}
  generic IMultiMap<K, V> = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-345678901234}']
    procedure Add(const aKey: K; const aValue: V);
    function Remove(const aKey: K; const aValue: V): Boolean;
    function RemoveAll(const aKey: K): SizeUInt;
    function Contains(const aKey: K): Boolean;
    function ContainsValue(const aKey: K; const aValue: V): Boolean;
    function GetValueCount(const aKey: K): SizeUInt;
    procedure Clear;
    function IsEmpty: Boolean;
    function KeyCount: SizeUInt;
    function TotalCount: SizeUInt;
  end;

implementation

end.
