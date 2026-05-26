unit nextpas.core.collections.stack;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.vecdeque;

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

  {**
   * TArrayStack<T>
   *
   * @desc 基于数组的栈实现
   * @param T 元素类型
   * @note
   *   - 内部使用 TVecDeque 作为底层容器
   *   - 支持接口引用计数
   *   - 使用 MakeArrayStack<T>() 工厂函数创建
   *
   *   示例:
   *     var Stack: specialize IStack<Integer>;
   *     Stack := specialize MakeArrayStack<Integer>();
   *     Stack.Push(1);
   *     Stack.Push(2);
   *     WriteLn(Stack.Pop); // 2 (LIFO)
   *}
  generic TArrayStack<T> = class(TInterfacedObject, specialize IStack<T>)
  type
    PElement = ^T;
    TInternalVecDeque = specialize TVecDeque<T>;
  private
    FStack: TInternalVecDeque;
    FAllocator: IAllocator;

  public
    constructor Create(const aAllocator: IAllocator = nil);
    destructor Destroy; override;

    { IStack 接口实现 }
    procedure Push(const aElement: T); overload;
    procedure Push(const aSrc: array of T); overload;
    procedure Push(const aSrc: Pointer; aElementCount: SizeUInt); overload;

    function Pop(out aElement: T): Boolean; overload;
    function Pop: T; overload;

    function TryPeek(out aElement: T): Boolean; overload;
    function Peek: T; overload;

    function IsEmpty: Boolean;
    procedure Clear;
    function Count: SizeUInt;
  end;

  { TLinkedStack 基于链表的栈实现 - 使用 TVecDeque 作为底层容器 }
  generic TLinkedStack<T> = class(TInterfacedObject, specialize IStack<T>)
  type
    PElement = ^T;
    TInternalVecDeque = specialize TVecDeque<T>;
  private
    FStack: TInternalVecDeque;
    FAllocator: IAllocator;

  public
    constructor Create(const aAllocator: IAllocator = nil);
    destructor Destroy; override;

    { IStack 接口实现 }
    procedure Push(const aElement: T); overload;
    procedure Push(const aSrc: array of T); overload;
    procedure Push(const aSrc: Pointer; aElementCount: SizeUInt); overload;

    function Pop(out aElement: T): Boolean; overload;
    function Pop: T; overload;

    function TryPeek(out aElement: T): Boolean; overload;
    function Peek: T; overload;

    function IsEmpty: Boolean;
    procedure Clear;
    function Count: SizeUInt;
  end;

  { 数组栈工厂函数 - 简化为3个最常用重载 }

  generic function MakeArrayStack<T>: specialize IStack<T>;
  generic function MakeArrayStack<T>(const aSrc: array of T): specialize IStack<T>;
  generic function MakeArrayStack<T>(const aAllocator: IAllocator): specialize IStack<T>;

  { 链表栈工厂函数 - 简化为3个最常用重载 }

  generic function MakeLinkedStack<T>: specialize IStack<T>;
  generic function MakeLinkedStack<T>(const aSrc: array of T): specialize IStack<T>;
  generic function MakeLinkedStack<T>(const aAllocator: IAllocator): specialize IStack<T>;

implementation

{ TArrayStack<T> }

constructor TArrayStack.Create(const aAllocator: IAllocator = nil);
begin
  inherited Create;
  if aAllocator <> nil then
    FAllocator := aAllocator
  else
    FAllocator := GetRtlAllocator;
  FStack := TInternalVecDeque.Create(FAllocator);
end;

destructor TArrayStack.Destroy;
begin
  FStack.Free;
  inherited Destroy;
end;

procedure TArrayStack.Push(const aElement: T);
begin
  FStack.PushBack(aElement);
end;

procedure TArrayStack.Push(const aSrc: array of T);
var
  I: SizeUInt;
begin
  for I := 0 to High(aSrc) do
    FStack.PushBack(aSrc[I]);
end;

procedure TArrayStack.Push(const aSrc: Pointer; aElementCount: SizeUInt);
var
  I: SizeUInt;
  LElement: T;
begin
  for I := 0 to aElementCount - 1 do
  begin
    LElement := PElement(aSrc)[I];
    FStack.PushBack(LElement);
  end;
end;

function TArrayStack.Pop(out aElement: T): Boolean;
begin
  if FStack.IsEmpty then
    Exit(False);
  aElement := FStack.PopBack;
  Result := True;
end;

function TArrayStack.Pop: T;
begin
  if FStack.IsEmpty then
    raise EEmptyCollection.Create('TArrayStack.Pop: collection is empty');
  Result := FStack.PopBack;
end;

function TArrayStack.TryPeek(out aElement: T): Boolean;
begin
  if FStack.IsEmpty then
    Exit(False);
  aElement := FStack.Back;
  Result := True;
end;

function TArrayStack.Peek: T;
begin
  if FStack.IsEmpty then
    raise EEmptyCollection.Create('TArrayStack.Peek: collection is empty');
  Result := FStack.Back;
end;

function TArrayStack.IsEmpty: Boolean;
begin
  Result := FStack.IsEmpty;
end;

procedure TArrayStack.Clear;
begin
  FStack.Clear;
end;

function TArrayStack.Count: SizeUInt;
begin
  Result := FStack.Count;
end;

{ TLinkedStack<T> }

constructor TLinkedStack.Create(const aAllocator: IAllocator = nil);
begin
  inherited Create;
  if aAllocator <> nil then
    FAllocator := aAllocator
  else
    FAllocator := GetRtlAllocator;
  FStack := TInternalVecDeque.Create(FAllocator);
end;

destructor TLinkedStack.Destroy;
begin
  FStack.Free;
  inherited Destroy;
end;

procedure TLinkedStack.Push(const aElement: T);
begin
  FStack.PushBack(aElement);
end;

procedure TLinkedStack.Push(const aSrc: array of T);
var
  I: SizeUInt;
begin
  for I := 0 to High(aSrc) do
    FStack.PushBack(aSrc[I]);
end;

procedure TLinkedStack.Push(const aSrc: Pointer; aElementCount: SizeUInt);
var
  I: SizeUInt;
  LElement: T;
begin
  for I := 0 to aElementCount - 1 do
  begin
    LElement := PElement(aSrc)[I];
    FStack.PushBack(LElement);
  end;
end;

function TLinkedStack.Pop(out aElement: T): Boolean;
begin
  if FStack.IsEmpty then
    Exit(False);
  aElement := FStack.PopBack;
  Result := True;
end;

function TLinkedStack.Pop: T;
begin
  if FStack.IsEmpty then
    raise EEmptyCollection.Create('TLinkedStack.Pop: collection is empty');
  Result := FStack.PopBack;
end;

function TLinkedStack.TryPeek(out aElement: T): Boolean;
begin
  if FStack.IsEmpty then
    Exit(False);
  aElement := FStack.Back;
  Result := True;
end;

function TLinkedStack.Peek: T;
begin
  if FStack.IsEmpty then
    raise EEmptyCollection.Create('TLinkedStack.Peek: collection is empty');
  Result := FStack.Back;
end;

function TLinkedStack.IsEmpty: Boolean;
begin
  Result := FStack.IsEmpty;
end;

procedure TLinkedStack.Clear;
begin
  FStack.Clear;
end;

function TLinkedStack.Count: SizeUInt;
begin
  Result := FStack.Count;
end;

{ MakeArrayStack 实现 }

generic function MakeArrayStack<T>: specialize IStack<T>;
type
  TStackImpl = specialize TArrayStack<T>;
var
  LStack: TStackImpl;
begin
  LStack := TStackImpl.Create;
  Result := LStack;
end;

generic function MakeArrayStack<T>(aAllocator: IAllocator): specialize IStack<T>;
type
  TStackImpl = specialize TArrayStack<T>;
var
  LStack: TStackImpl;
begin
  LStack := TStackImpl.Create(aAllocator);
  Result := LStack;
end;


generic function MakeArrayStack<T>(const aSrc: array of T): specialize IStack<T>;
type
  TStackImpl = specialize TArrayStack<T>;
var
  LStack: TStackImpl;
begin
  LStack := TStackImpl.Create;
  try
    LStack.Push(aSrc);
    Result := LStack;
  except
    LStack.Free;
    raise;
  end;
end;

generic function MakeLinkedStack<T>: specialize IStack<T>;
type
  TStackImpl = specialize TLinkedStack<T>;
var
  LStack: TStackImpl;
begin
  LStack := TStackImpl.Create;
  Result := LStack;
end;

generic function MakeLinkedStack<T>(const aSrc: array of T): specialize IStack<T>;
type
  TStackImpl = specialize TLinkedStack<T>;
var
  LStack: TStackImpl;
begin
  LStack := TStackImpl.Create;
  try
    LStack.Push(aSrc);
    Result := LStack;
  except
    LStack.Free;
    raise;
  end;
end;

generic function MakeLinkedStack<T>(const aAllocator: IAllocator): specialize IStack<T>;
type
  TStackImpl = specialize TLinkedStack<T>;
var
  LStack: TStackImpl;
begin
  LStack := TStackImpl.Create(aAllocator);
  Result := LStack;
end;

end.
