unit nextpas.core.collections.priorityqueue.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.intf;

type

  {**
   * IPriorityQueue<T> - 优先队列接口
   *
   * @desc
   *   基于二叉堆实现的优先队列接口，支持 O(log n) 插入和删除，
   *   O(1) 获取最小/最大元素。
   *
   * @type_params
   *   T - 元素类型
   *
   * @threadsafety NOT thread-safe
   *}
  generic IPriorityQueue<T> = interface(specialize IGenericCollection<T>)
  ['{F8E9D7C6-B5A4-4321-9876-543210FEDCBA}']
    {** Push - 插入元素 O(log n) *}
    procedure Push(const aItem: T);

    {** TryPop - 尝试移除并返回优先级最高的元素 O(log n) *}
    function TryPop(out aItem: T): Boolean;

    {** Pop - 移除并返回优先级最高的元素 O(log n)，空队列抛异常 *}
    function Pop: T;

    {** TryPeek - 尝试查看优先级最高的元素（不移除）O(1) *}
    function TryPeek(out aItem: T): Boolean;

    {** Peek - 查看优先级最高的元素（不移除）O(1)，空队列抛异常 *}
    function Peek: T;

    {** GetCapacity - 获取当前容量 *}
    function GetCapacity: SizeUInt;

    {** Reserve - 预留容量 *}
    procedure Reserve(aCapacity: SizeUInt);

    property Capacity: SizeUInt read GetCapacity;
  end;

implementation

end.
