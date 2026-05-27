unit nextpas.core.collections.rbset.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {**
   * IRBTreeSet<T> - 红黑树有序集合接口
   *
   * @desc 有序集合接口，基于红黑树实现，按元素排序
   *}
  generic IRBTreeSet<T> = interface
    ['{F6A7B8C9-D0E1-2345-F012-678901ABCDEF}']
    function Insert(const AValue: T): Boolean;
    function Delete(const AValue: T): Boolean;
    function ContainsKey(const AValue: T): Boolean;
    procedure Clear;
    function GetCount: SizeUInt;
    property Count: SizeUInt read GetCount;
  end;

implementation

end.
