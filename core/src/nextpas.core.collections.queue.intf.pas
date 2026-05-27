unit nextpas.core.collections.queue.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  {**
   * IQueue<T>
   *
   * @desc 泛型队列接口 - FIFO (先进先出) 语义
   * @param T 元素类型
   * @note
   *   - Push: 入队 O(1)
   *   - Pop: 出队 O(1)
   *   - Peek: 查看队首 O(1)
   *   - 不继承 IGenericCollection，保持最小接口
   *}
  generic IQueue<T> = interface
  ['{8D2A4A2F-3C7C-4E94-A763-6E2E7D6C5D37}']
    { 入队（同名重载） }
    procedure Push(const aElement: T); overload;              // 失败抛异常（如有容量上限）
    procedure Push(const aSrc: array of T); overload;         // 全部入队，遇满抛异常
    procedure Push(const aSrc: Pointer; aElementCount: SizeUInt); overload; // 指针批量

    { 出队（Try 语义与异常语义） }
    function  Pop(out aElement: T): Boolean; overload;        // 空返回 False
    function  Pop: T; overload;                               // 空抛异常

    { 预览（不移除）— 若实现不支持可返回 False/抛异常 }
    function  TryPeek(out aElement: T): Boolean; overload;    // 空或不支持返回 False
    function  Peek: T; overload;                              // 空或不支持抛异常

    { 状态与维护（最佳努力） }
    function  IsEmpty: Boolean;                               // 并发下允许竞态
    procedure Clear;                                          // 最佳努力清空
    function  Count: SizeUInt;                                // 精确或最佳努力计数（不支持可返回 0）
  end;

implementation

end.
