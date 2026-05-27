unit nextpas.core.collections.orderedset.rb.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {**
   * IRBOrderedSet<T> - 红黑树有序集合接口（扩展版）
   *
   * @desc 有序集合接口，基于红黑树实现，支持范围查询和极值操作
   *}
  generic IRBOrderedSet<T> = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF0123456789}']
    function Insert(const AValue: T): Boolean;
    function Remove(const AValue: T): Boolean;
    function ContainsKey(const AValue: T): Boolean;
    function LowerBound(const AValue: T; out OutValue: T): Boolean;
    function UpperBound(const AValue: T; out OutValue: T): Boolean;
    function Min(out OutValue: T): Boolean;
    function Max(out OutValue: T): Boolean;
    procedure Clear;
    function GetCount: SizeUInt;
    property Count: SizeUInt read GetCount;
  end;

implementation

end.
