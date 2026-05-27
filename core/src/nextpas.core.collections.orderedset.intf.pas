unit nextpas.core.collections.orderedset.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {**
   * IOrderedSet<T> - 有序集合接口（保持插入顺序）
   *
   * @desc 集合接口，元素不重复，保持插入顺序
   *}
  generic IOrderedSet<T> = interface
    ['{D4E5F6A7-B8C9-0123-DEF0-456789ABCDEF}']
    function Add(const aElement: T): Boolean;
    function Remove(const aElement: T): Boolean;
    function Contains(const aElement: T): Boolean;
    procedure Clear;
    function First: T;
    function Last: T;
    function TryGetFirst(var aElement: T): Boolean;
    function TryGetLast(var aElement: T): Boolean;
    function IsEmpty: Boolean;
    function GetCount: SizeUInt;
    property Count: SizeUInt read GetCount;
  end;

implementation

end.
