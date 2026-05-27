unit nextpas.core.collections.stack.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type

  {**
   * IStack<T>
   *
   * @desc 泛型栈接口 - LIFO (后进先出) 语义
   * @param T 元素类型
   * @note
   *   - Push: 压栈 O(1)
   *   - Pop: 弹栈 O(1)
   *   - Peek: 查看栈顶 O(1)
   *   - 不继承 IGenericCollection，保持最小接口
   *}
  generic IStack<T> = interface
  ['{b2d0130d-760b-4369-86c8-4ccd5ddac18c}']
    { 基本压栈（同名重载） }
    procedure Push(const aElement: T); overload;
    procedure Push(const aSrc: array of T); overload;
    procedure Push(const aSrc: Pointer; aElementCount: SizeUInt); overload;

    { 弹栈（Try 语义与异常语义） }
    function  Pop(out aElement: T): Boolean; overload; // 空返回 False
    function  Pop: T; overload;                        // 空抛异常

    { 预览（不弹出） }
    function  TryPeek(out aElement: T): Boolean; overload; // 空返回 False（快照语义）
    function  Peek: T; overload;                            // 空抛异常

    { 状态与维护 }
    function  IsEmpty: Boolean;
    procedure Clear;                 // 最佳努力；并发下允许竞态
    function  Count: SizeUInt;       // 精确或最佳努力计数
  end;

implementation

end.
