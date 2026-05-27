unit nextpas.core.collections.circularbuffer.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.intf;

type

  {**
   * ICircularBuffer<T> - 环形缓冲区接口
   *
   * @desc 固定容量的FIFO缓冲区接口
   *}
  generic ICircularBuffer<T> = interface(specialize IGenericCollection<T>)
    ['{E1F2A3B4-C5D6-4E7F-8A9B-0C1D2E3F4A5B}']
    function Push(const aElement: T): Boolean;
    function Pop: T;
    function TryPop(var aElement: T): Boolean;
    function Peek: T;
    function TryPeek(var aElement: T): Boolean;
    function IsFull: Boolean;
    function Capacity: SizeUInt;
    function RemainingCapacity: SizeUInt;
    function GetOverwriteOldest: Boolean;
    procedure SetOverwriteOldest(aValue: Boolean);
    property OverwriteOldest: Boolean read GetOverwriteOldest write SetOverwriteOldest;
  end;

implementation

end.
