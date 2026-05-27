unit nextpas.core.collections.vecdeque.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.collections.queue.intf;

type
  {**
   * IVecDeque<T>
   *
   * @desc 向量双端队列接口 - 基于环形缓冲区的高性能双端队列
   *
   * @param T 元素类型
   *
   * @note 核心操作复杂度：
   *   - PushFront/PushBack: O(1) 摊销
   *   - PopFront/PopBack: O(1)
   *   - Front/Back: O(1)
   *   - Get/Put: O(1) 随机访问
   *   - Insert/RemoveAt: O(n)
   *
   * @threadsafety 非线程安全
   * @see TVecDeque 具体实现
   * @see IQueue 父接口
   *}
  generic IVecDeque<T> = interface(specialize IQueue<T>)
  ['{12345678-1234-1234-1234-123456789ABC}']
    {** @desc 获取队首元素（空队列抛出 EEmptyCollection） *}
    function Front: T; overload;
    {** @desc 尝试获取队首元素 @return 成功返回 True *}
    function Front(var aElement: T): Boolean; overload;
    {** @desc 获取队尾元素（空队列抛出 EEmptyCollection） *}
    function Back: T; overload;
    {** @desc 尝试获取队尾元素 @return 成功返回 True *}
    function Back(var aElement: T): Boolean; overload;

    {** @desc 在队首插入元素 @param aElement 要插入的元素 *}
    procedure PushFront(const aElement: T); overload;
    {** @desc 在队首批量插入元素 @param aElements 元素数组 *}
    procedure PushFront(const aElements: array of T); overload;
    {** @desc 在队首批量插入元素（指针版本） *}
    procedure PushFront(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    {** @desc 在队尾插入元素 @param aElement 要插入的元素 *}
    procedure PushBack(const aElement: T); overload;
    {** @desc 在队尾批量插入元素 @param aElements 元素数组 *}
    procedure PushBack(const aElements: array of T); overload;
    {** @desc 在队尾批量插入元素（指针版本） *}
    procedure PushBack(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    {** @desc 弹出队首元素（空队列抛出 EEmptyCollection） @return 被移除的元素 *}
    function PopFront: T; overload;
    {** @desc 尝试弹出队首元素 @return 成功返回 True *}
    function PopFront(var aElement: T): Boolean; overload;
    {** @desc 弹出队尾元素（空队列抛出 EEmptyCollection） @return 被移除的元素 *}
    function PopBack: T; overload;
    {** @desc 尝试弹出队尾元素 @return 成功返回 True *}
    function PopBack(var aElement: T): Boolean; overload;

    // 随机访问与修改
    procedure Swap(aIndex1, aIndex2: SizeUInt);
    function Get(aIndex: SizeUInt): T;
    function TryGet(aIndex: SizeUInt; var aElement: T): Boolean;
    procedure Insert(aIndex: SizeUInt; const aElement: T);
    function RemoveAt(aIndex: SizeUInt): T;
    function TryRemoveAt(aIndex: SizeUInt; var aElement: T): Boolean;

    // 容量与尺寸管理
    procedure Reserve(aAdditional: SizeUInt);
    procedure ReserveExact(aAdditional: SizeUInt);
    procedure ShrinkToFit;
    procedure ShrinkTo(aMinCapacity: SizeUInt);
    procedure Truncate(aLen: SizeUInt);
    procedure Resize(aNewSize: SizeUInt; const aValue: T);

    // 批量与结构操作
    procedure Append(const aOther: specialize IQueue<T>);
    function SplitOff(aAt: SizeUInt): specialize IQueue<T>;

    // 批量操作接口 - 性能优化
    procedure LoadFromPointer(aSrc: Pointer; aCount: SizeUInt);
    procedure LoadFromArray(const aSrc: array of T);

    { AppendFrom: 从指定位置追加数据到容器末尾 }
    procedure AppendFrom(const aSrc: specialize IVecDeque<T>; aSrcIndex: SizeUInt; aCount: SizeUInt);

    { InsertFrom: 从指定位置插入批量数据 }
    procedure InsertFrom(aIndex: SizeUInt; aSrc: Pointer; aCount: SizeUInt);
    procedure InsertFrom(aIndex: SizeUInt; const aSrc: array of T);
  end;

implementation

end.
