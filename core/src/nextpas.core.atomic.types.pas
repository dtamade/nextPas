{
  nextpas.core.atomic.base - 原子操作类型安全封装

  提供类似 Rust std::sync::atomic 的类型安全原子类型：
  - TAtomicInt32 / TAtomicUInt32
  - TAtomicInt64 / TAtomicUInt64
  - TAtomicBool
  - TAtomicPtr<T>

  所有类型都是 record，支持值语义和栈分配。
}
unit nextpas.core.atomic.types;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic.core;

type
  { TAtomicInt32 - 32位有符号原子整数 }
  TAtomicInt32 = record
  private
    FValue: Int32;
  public
    class function Create(AValue: Int32): TAtomicInt32; static; inline;

    {**
     * is_lock_free - 查询原子操作是否无锁
     *
     * @return True 如果原子操作使用无锁 CPU 指令实现
     *
     * @cpp_equivalent std::atomic<int32_t>::is_lock_free()
     *}
    class function is_lock_free: Boolean; static; inline;

    // 基础操作
    function Load(AOrder: memory_order_t = mo_seq_cst): Int32; inline;
    procedure Store(AValue: Int32; AOrder: memory_order_t = mo_seq_cst); inline;
    function Exchange(AValue: Int32; AOrder: memory_order_t = mo_seq_cst): Int32; inline;

    // CAS 操作
    function CompareExchangeStrong(var AExpected: Int32; ADesired: Int32;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    function CompareExchangeWeak(var AExpected: Int32; ADesired: Int32;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;

    // RMW 操作 - 返回旧值
    function FetchAdd(ADelta: Int32; AOrder: memory_order_t = mo_seq_cst): Int32; inline;
    function FetchSub(ADelta: Int32; AOrder: memory_order_t = mo_seq_cst): Int32; inline;
    function FetchAnd(AMask: Int32; AOrder: memory_order_t = mo_seq_cst): Int32; inline;
    function FetchOr(AMask: Int32; AOrder: memory_order_t = mo_seq_cst): Int32; inline;
    function FetchXor(AMask: Int32; AOrder: memory_order_t = mo_seq_cst): Int32; inline;

    // 便利方法 - 返回新值
    function Increment(AOrder: memory_order_t = mo_seq_cst): Int32; inline;
    function Decrement(AOrder: memory_order_t = mo_seq_cst): Int32; inline;

    // 独占访问（非原子，仅在确保无并发时使用）
    function GetMut: PInt32; inline;
    function IntoInner: Int32; inline;
  end;

  { TAtomicUInt32 - 32位无符号原子整数 }
  TAtomicUInt32 = record
  private
    FValue: UInt32;
  public
    class function Create(AValue: UInt32): TAtomicUInt32; static; inline;

    {**
     * is_lock_free - 查询原子操作是否无锁
     *
     * @return True 如果原子操作使用无锁 CPU 指令实现
     *
     * @cpp_equivalent std::atomic<uint32_t>::is_lock_free()
     *}
    class function is_lock_free: Boolean; static; inline;

    function Load(AOrder: memory_order_t = mo_seq_cst): UInt32; inline;
    procedure Store(AValue: UInt32; AOrder: memory_order_t = mo_seq_cst); inline;
    function Exchange(AValue: UInt32; AOrder: memory_order_t = mo_seq_cst): UInt32; inline;

    function CompareExchangeStrong(var AExpected: UInt32; ADesired: UInt32;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    function CompareExchangeWeak(var AExpected: UInt32; ADesired: UInt32;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;

    function FetchAdd(ADelta: UInt32; AOrder: memory_order_t = mo_seq_cst): UInt32; inline;
    function FetchSub(ADelta: UInt32; AOrder: memory_order_t = mo_seq_cst): UInt32; inline;
    function FetchAnd(AMask: UInt32; AOrder: memory_order_t = mo_seq_cst): UInt32; inline;
    function FetchOr(AMask: UInt32; AOrder: memory_order_t = mo_seq_cst): UInt32; inline;
    function FetchXor(AMask: UInt32; AOrder: memory_order_t = mo_seq_cst): UInt32; inline;

    function Increment(AOrder: memory_order_t = mo_seq_cst): UInt32; inline;
    function Decrement(AOrder: memory_order_t = mo_seq_cst): UInt32; inline;

    function GetMut: PUInt32; inline;
    function IntoInner: UInt32; inline;
  end;

  {$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
  { TAtomicInt64 - 64位有符号原子整数 }
  TAtomicInt64 = record
  private
    FValue: Int64;
  public
    class function Create(AValue: Int64): TAtomicInt64; static; inline;

    {**
     * is_lock_free - 查询原子操作是否无锁
     *
     * @return True 如果原子操作使用无锁 CPU 指令实现
     *
     * @note 64位操作在64位平台通常无锁，在32位平台可能需要锁
     *
     * @cpp_equivalent std::atomic<int64_t>::is_lock_free()
     *}
    class function is_lock_free: Boolean; static; inline;

    function Load(AOrder: memory_order_t = mo_seq_cst): Int64; inline;
    procedure Store(AValue: Int64; AOrder: memory_order_t = mo_seq_cst); inline;
    function Exchange(AValue: Int64; AOrder: memory_order_t = mo_seq_cst): Int64; inline;

    function CompareExchangeStrong(var AExpected: Int64; ADesired: Int64;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    function CompareExchangeWeak(var AExpected: Int64; ADesired: Int64;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;

    function FetchAdd(ADelta: Int64; AOrder: memory_order_t = mo_seq_cst): Int64; inline;
    function FetchSub(ADelta: Int64; AOrder: memory_order_t = mo_seq_cst): Int64; inline;
    function FetchAnd(AMask: Int64; AOrder: memory_order_t = mo_seq_cst): Int64; inline;
    function FetchOr(AMask: Int64; AOrder: memory_order_t = mo_seq_cst): Int64; inline;
    function FetchXor(AMask: Int64; AOrder: memory_order_t = mo_seq_cst): Int64; inline;

    function Increment(AOrder: memory_order_t = mo_seq_cst): Int64; inline;
    function Decrement(AOrder: memory_order_t = mo_seq_cst): Int64; inline;

    function GetMut: PInt64; inline;
    function IntoInner: Int64; inline;
  end;

  { TAtomicUInt64 - 64位无符号原子整数 }
  TAtomicUInt64 = record
  private
    FValue: UInt64;
  public
    class function Create(AValue: UInt64): TAtomicUInt64; static; inline;

    {**
     * is_lock_free - 查询原子操作是否无锁
     *
     * @return True 如果原子操作使用无锁 CPU 指令实现
     *
     * @note 64位操作在64位平台通常无锁，在32位平台可能需要锁
     *
     * @cpp_equivalent std::atomic<uint64_t>::is_lock_free()
     *}
    class function is_lock_free: Boolean; static; inline;

    function Load(AOrder: memory_order_t = mo_seq_cst): UInt64; inline;
    procedure Store(AValue: UInt64; AOrder: memory_order_t = mo_seq_cst); inline;
    function Exchange(AValue: UInt64; AOrder: memory_order_t = mo_seq_cst): UInt64; inline;

    function CompareExchangeStrong(var AExpected: UInt64; ADesired: UInt64;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    function CompareExchangeWeak(var AExpected: UInt64; ADesired: UInt64;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;

    function FetchAdd(ADelta: UInt64; AOrder: memory_order_t = mo_seq_cst): UInt64; inline;
    function FetchSub(ADelta: UInt64; AOrder: memory_order_t = mo_seq_cst): UInt64; inline;
    function FetchAnd(AMask: UInt64; AOrder: memory_order_t = mo_seq_cst): UInt64; inline;
    function FetchOr(AMask: UInt64; AOrder: memory_order_t = mo_seq_cst): UInt64; inline;
    function FetchXor(AMask: UInt64; AOrder: memory_order_t = mo_seq_cst): UInt64; inline;

    function Increment(AOrder: memory_order_t = mo_seq_cst): UInt64; inline;
    function Decrement(AOrder: memory_order_t = mo_seq_cst): UInt64; inline;

    function GetMut: PUInt64; inline;
    function IntoInner: UInt64; inline;
  end;
  {$ENDIF}

  { TAtomicBool - 原子布尔值 }
  TAtomicBool = record
  private
    FValue: Int32;  // 使用 Int32 存储，0=False, 1=True
  public
    class function Create(AValue: Boolean): TAtomicBool; static; inline;

    {**
     * is_lock_free - 查询原子操作是否无锁
     *
     * @return True 如果原子操作使用无锁 CPU 指令实现
     *
     * @cpp_equivalent std::atomic<bool>::is_lock_free()
     *}
    class function is_lock_free: Boolean; static; inline;

    function Load(AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    procedure Store(AValue: Boolean; AOrder: memory_order_t = mo_seq_cst); inline;
    function Exchange(AValue: Boolean; AOrder: memory_order_t = mo_seq_cst): Boolean; inline;

    function CompareExchangeStrong(var AExpected: Boolean; ADesired: Boolean;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    function CompareExchangeWeak(var AExpected: Boolean; ADesired: Boolean;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;

    // 位操作
    function FetchAnd(AValue: Boolean; AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    function FetchOr(AValue: Boolean; AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    function FetchXor(AValue: Boolean; AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    function FetchNand(AValue: Boolean; AOrder: memory_order_t = mo_seq_cst): Boolean; inline;

    function GetMut: PInt32; inline;
    function IntoInner: Boolean; inline;
  end;

  {**
   * TAtomicFlag - 原子标志（最简单的原子类型）
   *
   * @desc
   *   最简单的原子类型，保证无锁。只有两个操作：test_and_set 和 clear。
   *   常用于实现自旋锁和简单的同步标志。
   *
   * @cpp_equivalent std::atomic_flag
   *
   * @example
   *   var flag: TAtomicFlag;
   *   flag := TAtomicFlag.Create(False);
   *   if not flag.test_and_set() then
   *     WriteLn('First thread acquired the flag');
   *}
  TAtomicFlag = record
  private
    FValue: Int32;  // 使用 Int32 存储，0=clear, 1=set
  public
    {**
     * Create - 创建原子标志
     *
     * @param AInitialValue 初始值（True=set, False=clear）
     *
     * @note C++ std::atomic_flag 必须用 ATOMIC_FLAG_INIT 初始化为 clear 状态，
     *       但我们提供更灵活的初始化方式
     *}
    class function Create(AInitialValue: Boolean = False): TAtomicFlag; static; inline;

    {**
     * is_lock_free - 查询原子操作是否无锁
     *
     * @return 始终返回 True（atomic_flag 保证无锁）
     *
     * @cpp_equivalent std::atomic_flag::is_lock_free() (always true)
     *}
    class function is_lock_free: Boolean; static; inline;

    {**
     * test_and_set - 原子地设置标志并返回旧值
     *
     * @param AOrder 内存序（默认 seq_cst）
     * @return 旧值（True 表示之前已设置，False 表示之前未设置）
     *
     * @cpp_equivalent std::atomic_flag::test_and_set()
     *
     * @example
     *   if not flag.test_and_set() then
     *     // 成功获取锁
     *}
    function test_and_set(AOrder: memory_order_t = mo_seq_cst): Boolean; inline;

    {**
     * clear - 原子地清除标志
     *
     * @param AOrder 内存序（默认 seq_cst）
     *
     * @cpp_equivalent std::atomic_flag::clear()
     *
     * @example
     *   flag.clear();  // 释放锁
     *}
    procedure clear(AOrder: memory_order_t = mo_seq_cst); inline;

    {**
     * test - 原子地读取标志值（不修改）
     *
     * @param AOrder 内存序（默认 seq_cst）
     * @return 当前值（True=set, False=clear）
     *
     * @note C++20 新增的 test() 方法，用于非破坏性读取
     *
     * @cpp_equivalent std::atomic_flag::test() (C++20)
     *}
    function test(AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
  end;

  { TAtomicISize - 指针大小有符号原子整数 (PtrInt) }
  TAtomicISize = record
  private
    FValue: PtrInt;
  public
    class function Create(AValue: PtrInt): TAtomicISize; static; inline;

    {**
     * is_lock_free - 查询原子操作是否无锁
     *
     * @return True 如果原子操作使用无锁 CPU 指令实现
     *
     * @cpp_equivalent std::atomic<intptr_t>::is_lock_free()
     *}
    class function is_lock_free: Boolean; static; inline;

    function Load(AOrder: memory_order_t = mo_seq_cst): PtrInt; inline;
    procedure Store(AValue: PtrInt; AOrder: memory_order_t = mo_seq_cst); inline;
    function Exchange(AValue: PtrInt; AOrder: memory_order_t = mo_seq_cst): PtrInt; inline;

    function CompareExchangeStrong(var AExpected: PtrInt; ADesired: PtrInt;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    function CompareExchangeWeak(var AExpected: PtrInt; ADesired: PtrInt;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;

    function FetchAdd(ADelta: PtrInt; AOrder: memory_order_t = mo_seq_cst): PtrInt; inline;
    function FetchSub(ADelta: PtrInt; AOrder: memory_order_t = mo_seq_cst): PtrInt; inline;
    function FetchAnd(AMask: PtrInt; AOrder: memory_order_t = mo_seq_cst): PtrInt; inline;
    function FetchOr(AMask: PtrInt; AOrder: memory_order_t = mo_seq_cst): PtrInt; inline;
    function FetchXor(AMask: PtrInt; AOrder: memory_order_t = mo_seq_cst): PtrInt; inline;

    function Increment(AOrder: memory_order_t = mo_seq_cst): PtrInt; inline;
    function Decrement(AOrder: memory_order_t = mo_seq_cst): PtrInt; inline;

    function GetMut: PPtrInt; inline;
    function IntoInner: PtrInt; inline;
  end;

  { TAtomicUSize - 指针大小无符号原子整数 (PtrUInt) }
  TAtomicUSize = record
  private
    FValue: PtrUInt;
  public
    class function Create(AValue: PtrUInt): TAtomicUSize; static; inline;

    {**
     * is_lock_free - 查询原子操作是否无锁
     *
     * @return True 如果原子操作使用无锁 CPU 指令实现
     *
     * @cpp_equivalent std::atomic<uintptr_t>::is_lock_free()
     *}
    class function is_lock_free: Boolean; static; inline;

    function Load(AOrder: memory_order_t = mo_seq_cst): PtrUInt; inline;
    procedure Store(AValue: PtrUInt; AOrder: memory_order_t = mo_seq_cst); inline;
    function Exchange(AValue: PtrUInt; AOrder: memory_order_t = mo_seq_cst): PtrUInt; inline;

    function CompareExchangeStrong(var AExpected: PtrUInt; ADesired: PtrUInt;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    function CompareExchangeWeak(var AExpected: PtrUInt; ADesired: PtrUInt;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;

    function FetchAdd(ADelta: PtrUInt; AOrder: memory_order_t = mo_seq_cst): PtrUInt; inline;
    function FetchSub(ADelta: PtrUInt; AOrder: memory_order_t = mo_seq_cst): PtrUInt; inline;
    function FetchAnd(AMask: PtrUInt; AOrder: memory_order_t = mo_seq_cst): PtrUInt; inline;
    function FetchOr(AMask: PtrUInt; AOrder: memory_order_t = mo_seq_cst): PtrUInt; inline;
    function FetchXor(AMask: PtrUInt; AOrder: memory_order_t = mo_seq_cst): PtrUInt; inline;

    function Increment(AOrder: memory_order_t = mo_seq_cst): PtrUInt; inline;
    function Decrement(AOrder: memory_order_t = mo_seq_cst): PtrUInt; inline;

    function GetMut: PPtrUInt; inline;
    function IntoInner: PtrUInt; inline;
  end;

  { TAtomicPtr - 泛型原子指针 }
  generic TAtomicPtr<T> = record
  public type
    PT = ^T;
  private
    FValue: PT;
  public
    class function Create(AValue: PT): TAtomicPtr; static; inline;

    {**
     * is_lock_free - 查询原子操作是否无锁
     *
     * @return True 如果原子操作使用无锁 CPU 指令实现
     *
     * @cpp_equivalent std::atomic<T*>::is_lock_free()
     *}
    class function is_lock_free: Boolean; static; inline;

    function Load(AOrder: memory_order_t = mo_seq_cst): PT; inline;
    procedure Store(AValue: PT; AOrder: memory_order_t = mo_seq_cst); inline;
    function Exchange(AValue: PT; AOrder: memory_order_t = mo_seq_cst): PT; inline;

    function CompareExchangeStrong(var AExpected: PT; ADesired: PT;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;
    function CompareExchangeWeak(var AExpected: PT; ADesired: PT;
      AOrder: memory_order_t = mo_seq_cst): Boolean; inline;

    function GetMut: Pointer; inline;  // 返回 @FValue
    function IntoInner: PT; inline;
  end;

implementation

uses
  nextpas.core.atomic;

function _cas_success_order(const AOrder: memory_order_t): memory_order_t; inline;
begin
  // Treat consume as acquire for CAS/RMW in the high-level wrappers.
  // (Most real-world implementations also treat consume as acquire.)
  if AOrder = mo_consume then
    Result := mo_acquire
  else
    Result := AOrder;
end;

function _cas_failure_order(const ASuccessOrder: memory_order_t): memory_order_t; inline;
begin
  // Failure order may not include release/acq_rel.
  case ASuccessOrder of
    mo_relaxed:
      Result := mo_relaxed;
    mo_acquire:
      Result := mo_acquire;
    mo_release:
      Result := mo_relaxed;
    mo_acq_rel:
      Result := mo_acquire;
    mo_seq_cst:
      Result := mo_seq_cst;
  else
    Result := mo_relaxed;
  end;
end;

{ TAtomicInt32 }

class function TAtomicInt32.Create(AValue: Int32): TAtomicInt32;
begin
  Result.FValue := AValue;
end;

class function TAtomicInt32.is_lock_free: Boolean;
begin
  // 32-bit atomic operations are always lock-free on modern platforms
  Result := True;
end;

function TAtomicInt32.Load(AOrder: memory_order_t): Int32;
begin
  Result := atomic_load(FValue, AOrder);
end;

procedure TAtomicInt32.Store(AValue: Int32; AOrder: memory_order_t);
begin
  atomic_store(FValue, AValue, AOrder);
end;

function TAtomicInt32.Exchange(AValue: Int32; AOrder: memory_order_t): Int32;
begin
  Result := atomic_exchange(FValue, AValue, AOrder);
end;

function TAtomicInt32.CompareExchangeStrong(var AExpected: Int32; ADesired: Int32;
  AOrder: memory_order_t): Boolean;
var
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_strong(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
end;

function TAtomicInt32.CompareExchangeWeak(var AExpected: Int32; ADesired: Int32;
  AOrder: memory_order_t): Boolean;
var
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_weak(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
end;

function TAtomicInt32.FetchAdd(ADelta: Int32; AOrder: memory_order_t): Int32;
begin
  Result := atomic_fetch_add(FValue, ADelta, AOrder);
end;

function TAtomicInt32.FetchSub(ADelta: Int32; AOrder: memory_order_t): Int32;
begin
  Result := atomic_fetch_sub(FValue, ADelta, AOrder);
end;

function TAtomicInt32.FetchAnd(AMask: Int32; AOrder: memory_order_t): Int32;
begin
  Result := atomic_fetch_and(FValue, AMask, AOrder);
end;

function TAtomicInt32.FetchOr(AMask: Int32; AOrder: memory_order_t): Int32;
begin
  Result := atomic_fetch_or(FValue, AMask, AOrder);
end;

function TAtomicInt32.FetchXor(AMask: Int32; AOrder: memory_order_t): Int32;
begin
  Result := atomic_fetch_xor(FValue, AMask, AOrder);
end;

function TAtomicInt32.Increment(AOrder: memory_order_t): Int32;
begin
  Result := FetchAdd(1, AOrder) + 1;
end;

function TAtomicInt32.Decrement(AOrder: memory_order_t): Int32;
begin
  Result := FetchSub(1, AOrder) - 1;
end;

function TAtomicInt32.GetMut: PInt32;
begin
  Result := @FValue;
end;

function TAtomicInt32.IntoInner: Int32;
begin
  Result := FValue;
end;

{ TAtomicUInt32 }

class function TAtomicUInt32.Create(AValue: UInt32): TAtomicUInt32;
begin
  Result.FValue := AValue;
end;

class function TAtomicUInt32.is_lock_free: Boolean;
begin
  // 32-bit atomic operations are always lock-free on modern platforms
  Result := True;
end;

function TAtomicUInt32.Load(AOrder: memory_order_t): UInt32;
begin
  Result := atomic_load(FValue, AOrder);
end;

procedure TAtomicUInt32.Store(AValue: UInt32; AOrder: memory_order_t);
begin
  atomic_store(FValue, AValue, AOrder);
end;

function TAtomicUInt32.Exchange(AValue: UInt32; AOrder: memory_order_t): UInt32;
begin
  Result := atomic_exchange(FValue, AValue, AOrder);
end;

function TAtomicUInt32.CompareExchangeStrong(var AExpected: UInt32; ADesired: UInt32;
  AOrder: memory_order_t): Boolean;
var
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_strong(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
end;

function TAtomicUInt32.CompareExchangeWeak(var AExpected: UInt32; ADesired: UInt32;
  AOrder: memory_order_t): Boolean;
var
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_weak(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
end;

function TAtomicUInt32.FetchAdd(ADelta: UInt32; AOrder: memory_order_t): UInt32;
begin
  Result := atomic_fetch_add(FValue, ADelta, AOrder);
end;

function TAtomicUInt32.FetchSub(ADelta: UInt32; AOrder: memory_order_t): UInt32;
begin
  Result := atomic_fetch_sub(FValue, ADelta, AOrder);
end;

function TAtomicUInt32.FetchAnd(AMask: UInt32; AOrder: memory_order_t): UInt32;
begin
  Result := atomic_fetch_and(FValue, AMask, AOrder);
end;

function TAtomicUInt32.FetchOr(AMask: UInt32; AOrder: memory_order_t): UInt32;
begin
  Result := atomic_fetch_or(FValue, AMask, AOrder);
end;

function TAtomicUInt32.FetchXor(AMask: UInt32; AOrder: memory_order_t): UInt32;
begin
  Result := atomic_fetch_xor(FValue, AMask, AOrder);
end;

function TAtomicUInt32.Increment(AOrder: memory_order_t): UInt32;
begin
  Result := FetchAdd(1, AOrder) + 1;
end;

function TAtomicUInt32.Decrement(AOrder: memory_order_t): UInt32;
begin
  Result := FetchSub(1, AOrder) - 1;
end;

function TAtomicUInt32.GetMut: PUInt32;
begin
  Result := @FValue;
end;

function TAtomicUInt32.IntoInner: UInt32;
begin
  Result := FValue;
end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
{ TAtomicInt64 }

class function TAtomicInt64.Create(AValue: Int64): TAtomicInt64;
begin
  Result.FValue := AValue;
end;

class function TAtomicInt64.is_lock_free: Boolean;
begin
  // 64-bit atomic operations are lock-free on 64-bit platforms
  // On x86/x64, CMPXCHG8B provides lock-free 64-bit atomics even in 32-bit mode
  {$IFDEF CPU64}
  Result := True;
  {$ELSE}
  Result := True;  // x86 with CMPXCHG8B instruction
  {$ENDIF}
end;

function TAtomicInt64.Load(AOrder: memory_order_t): Int64;
begin
  Result := atomic_load_64(FValue, AOrder);
end;

procedure TAtomicInt64.Store(AValue: Int64; AOrder: memory_order_t);
begin
  atomic_store_64(FValue, AValue, AOrder);
end;

function TAtomicInt64.Exchange(AValue: Int64; AOrder: memory_order_t): Int64;
begin
  Result := atomic_exchange_64(FValue, AValue, AOrder);
end;

function TAtomicInt64.CompareExchangeStrong(var AExpected: Int64; ADesired: Int64;
  AOrder: memory_order_t): Boolean;
var
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_strong_64(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
end;

function TAtomicInt64.CompareExchangeWeak(var AExpected: Int64; ADesired: Int64;
  AOrder: memory_order_t): Boolean;
var
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_weak_64(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
end;

function TAtomicInt64.FetchAdd(ADelta: Int64; AOrder: memory_order_t): Int64;
begin
  Result := atomic_fetch_add_64(FValue, ADelta, AOrder);
end;

function TAtomicInt64.FetchSub(ADelta: Int64; AOrder: memory_order_t): Int64;
begin
  Result := atomic_fetch_sub_64(FValue, ADelta, AOrder);
end;

function TAtomicInt64.FetchAnd(AMask: Int64; AOrder: memory_order_t): Int64;
begin
  Result := atomic_fetch_and_64(FValue, AMask, AOrder);
end;

function TAtomicInt64.FetchOr(AMask: Int64; AOrder: memory_order_t): Int64;
begin
  Result := atomic_fetch_or_64(FValue, AMask, AOrder);
end;

function TAtomicInt64.FetchXor(AMask: Int64; AOrder: memory_order_t): Int64;
begin
  Result := atomic_fetch_xor_64(FValue, AMask, AOrder);
end;

function TAtomicInt64.Increment(AOrder: memory_order_t): Int64;
begin
  Result := FetchAdd(1, AOrder) + 1;
end;

function TAtomicInt64.Decrement(AOrder: memory_order_t): Int64;
begin
  Result := FetchSub(1, AOrder) - 1;
end;

function TAtomicInt64.GetMut: PInt64;
begin
  Result := @FValue;
end;

function TAtomicInt64.IntoInner: Int64;
begin
  Result := FValue;
end;

{ TAtomicUInt64 }

class function TAtomicUInt64.Create(AValue: UInt64): TAtomicUInt64;
begin
  Result.FValue := AValue;
end;

class function TAtomicUInt64.is_lock_free: Boolean;
begin
  // 64-bit atomic operations are lock-free on 64-bit platforms
  // On x86/x64, CMPXCHG8B provides lock-free 64-bit atomics even in 32-bit mode
  {$IFDEF CPU64}
  Result := True;
  {$ELSE}
  Result := True;  // x86 with CMPXCHG8B instruction
  {$ENDIF}
end;

function TAtomicUInt64.Load(AOrder: memory_order_t): UInt64;
begin
  Result := atomic_load_64(FValue, AOrder);
end;

procedure TAtomicUInt64.Store(AValue: UInt64; AOrder: memory_order_t);
begin
  atomic_store_64(FValue, AValue, AOrder);
end;

function TAtomicUInt64.Exchange(AValue: UInt64; AOrder: memory_order_t): UInt64;
begin
  Result := atomic_exchange_64(FValue, AValue, AOrder);
end;

function TAtomicUInt64.CompareExchangeStrong(var AExpected: UInt64; ADesired: UInt64;
  AOrder: memory_order_t): Boolean;
var
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_strong_64(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
end;

function TAtomicUInt64.CompareExchangeWeak(var AExpected: UInt64; ADesired: UInt64;
  AOrder: memory_order_t): Boolean;
var
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_weak_64(FValue, AExpected, ADesired, LSuccessOrder, LFailureOrder);
end;

function TAtomicUInt64.FetchAdd(ADelta: UInt64; AOrder: memory_order_t): UInt64;
begin
  Result := atomic_fetch_add_64(FValue, ADelta, AOrder);
end;

function TAtomicUInt64.FetchSub(ADelta: UInt64; AOrder: memory_order_t): UInt64;
begin
  Result := atomic_fetch_sub_64(FValue, ADelta, AOrder);
end;

function TAtomicUInt64.FetchAnd(AMask: UInt64; AOrder: memory_order_t): UInt64;
begin
  Result := atomic_fetch_and_64(FValue, AMask, AOrder);
end;

function TAtomicUInt64.FetchOr(AMask: UInt64; AOrder: memory_order_t): UInt64;
begin
  Result := atomic_fetch_or_64(FValue, AMask, AOrder);
end;

function TAtomicUInt64.FetchXor(AMask: UInt64; AOrder: memory_order_t): UInt64;
begin
  Result := atomic_fetch_xor_64(FValue, AMask, AOrder);
end;

function TAtomicUInt64.Increment(AOrder: memory_order_t): UInt64;
begin
  Result := FetchAdd(1, AOrder) + 1;
end;

function TAtomicUInt64.Decrement(AOrder: memory_order_t): UInt64;
begin
  Result := FetchSub(1, AOrder) - 1;
end;

function TAtomicUInt64.GetMut: PUInt64;
begin
  Result := @FValue;
end;

function TAtomicUInt64.IntoInner: UInt64;
begin
  Result := FValue;
end;
{$ENDIF}

{ TAtomicBool }

class function TAtomicBool.Create(AValue: Boolean): TAtomicBool;
begin
  if AValue then
    Result.FValue := 1
  else
    Result.FValue := 0;
end;

class function TAtomicBool.is_lock_free: Boolean;
begin
  // Boolean is stored as Int32, which is always lock-free
  Result := True;
end;

function TAtomicBool.Load(AOrder: memory_order_t): Boolean;
begin
  Result := atomic_load(FValue, AOrder) <> 0;
end;

procedure TAtomicBool.Store(AValue: Boolean; AOrder: memory_order_t);
begin
  if AValue then
    atomic_store(FValue, 1, AOrder)
  else
    atomic_store(FValue, 0, AOrder);
end;

function TAtomicBool.Exchange(AValue: Boolean; AOrder: memory_order_t): Boolean;
var
  LNew: Int32;
begin
  if AValue then LNew := 1 else LNew := 0;
  Result := atomic_exchange(FValue, LNew, AOrder) <> 0;
end;

function TAtomicBool.CompareExchangeStrong(var AExpected: Boolean; ADesired: Boolean;
  AOrder: memory_order_t): Boolean;
var
  LExp, LDes: Int32;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  if AExpected then LExp := 1 else LExp := 0;
  if ADesired then LDes := 1 else LDes := 0;

  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);

  Result := atomic_compare_exchange_strong(FValue, LExp, LDes, LSuccessOrder, LFailureOrder);
  AExpected := LExp <> 0;
end;

function TAtomicBool.CompareExchangeWeak(var AExpected: Boolean; ADesired: Boolean;
  AOrder: memory_order_t): Boolean;
var
  LExp, LDes: Int32;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  if AExpected then LExp := 1 else LExp := 0;
  if ADesired then LDes := 1 else LDes := 0;

  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);

  Result := atomic_compare_exchange_weak(FValue, LExp, LDes, LSuccessOrder, LFailureOrder);
  AExpected := LExp <> 0;
end;

function TAtomicBool.FetchAnd(AValue: Boolean; AOrder: memory_order_t): Boolean;
var
  LMask: Int32;
begin
  if AValue then LMask := 1 else LMask := 0;
  Result := atomic_fetch_and(FValue, LMask, AOrder) <> 0;
end;

function TAtomicBool.FetchOr(AValue: Boolean; AOrder: memory_order_t): Boolean;
var
  LMask: Int32;
begin
  if AValue then LMask := 1 else LMask := 0;
  Result := atomic_fetch_or(FValue, LMask, AOrder) <> 0;
end;

function TAtomicBool.FetchXor(AValue: Boolean; AOrder: memory_order_t): Boolean;
var
  LMask: Int32;
begin
  if AValue then LMask := 1 else LMask := 0;
  Result := atomic_fetch_xor(FValue, LMask, AOrder) <> 0;
end;

function TAtomicBool.FetchNand(AValue: Boolean; AOrder: memory_order_t): Boolean;
var
  LOld, LNew, LMask: Int32;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  if AValue then LMask := 1 else LMask := 0;

  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);

  LOld := atomic_load(FValue, mo_relaxed);
  repeat
    LNew := not (LOld and LMask) and 1;  // NAND 并限制为 0/1
    if atomic_compare_exchange_weak(FValue, LOld, LNew, LSuccessOrder, LFailureOrder) then
      Break;
    cpu_pause;
  until False;

  Result := LOld <> 0;
end;

function TAtomicBool.GetMut: PInt32;
begin
  Result := @FValue;
end;

function TAtomicBool.IntoInner: Boolean;
begin
  Result := FValue <> 0;
end;

{ TAtomicFlag }

class function TAtomicFlag.Create(AInitialValue: Boolean): TAtomicFlag;
begin
  if AInitialValue then
    Result.FValue := 1
  else
    Result.FValue := 0;
end;

class function TAtomicFlag.is_lock_free: Boolean;
begin
  // atomic_flag is guaranteed to be lock-free
  Result := True;
end;

function TAtomicFlag.test_and_set(AOrder: memory_order_t): Boolean;
begin
  // Atomically set to 1 and return old value
  Result := atomic_exchange(FValue, 1, AOrder) <> 0;
end;

procedure TAtomicFlag.clear(AOrder: memory_order_t);
begin
  // Atomically set to 0
  atomic_store(FValue, 0, AOrder);
end;

function TAtomicFlag.test(AOrder: memory_order_t): Boolean;
begin
  // Atomically read without modifying
  Result := atomic_load(FValue, AOrder) <> 0;
end;

{ TAtomicISize }

class function TAtomicISize.Create(AValue: PtrInt): TAtomicISize;
begin
  Result.FValue := AValue;
end;

class function TAtomicISize.is_lock_free: Boolean;
begin
  // Pointer-sized atomic operations are always lock-free on modern platforms
  Result := True;
end;

function TAtomicISize.Load(AOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
  Result := PtrInt(atomic_load(PInt32(@FValue)^, AOrder));
  {$ELSE}
  Result := PtrInt(atomic_load_64(PInt64(@FValue)^, AOrder));
  {$ENDIF}
end;

procedure TAtomicISize.Store(AValue: PtrInt; AOrder: memory_order_t);
begin
  {$IF SIZEOF(PtrInt) = 4}
  atomic_store(PInt32(@FValue)^, Int32(AValue), AOrder);
  {$ELSE}
  atomic_store_64(PInt64(@FValue)^, Int64(AValue), AOrder);
  {$ENDIF}
end;

function TAtomicISize.Exchange(AValue: PtrInt; AOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
  Result := PtrInt(atomic_exchange(PInt32(@FValue)^, Int32(AValue), AOrder));
  {$ELSE}
  Result := PtrInt(atomic_exchange_64(PInt64(@FValue)^, Int64(AValue), AOrder));
  {$ENDIF}
end;

function TAtomicISize.CompareExchangeStrong(var AExpected: PtrInt; ADesired: PtrInt;
  AOrder: memory_order_t): Boolean;
{$IF SIZEOF(PtrInt) = 4}
var
  LExp: Int32;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LExp := Int32(AExpected);
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_strong(PInt32(@FValue)^, LExp, Int32(ADesired), LSuccessOrder, LFailureOrder);
  AExpected := PtrInt(LExp);
end;
{$ELSE}
var
  LExp: Int64;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LExp := Int64(AExpected);
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_strong_64(PInt64(@FValue)^, LExp, Int64(ADesired), LSuccessOrder, LFailureOrder);
  AExpected := PtrInt(LExp);
end;
{$ENDIF}

function TAtomicISize.CompareExchangeWeak(var AExpected: PtrInt; ADesired: PtrInt;
  AOrder: memory_order_t): Boolean;
{$IF SIZEOF(PtrInt) = 4}
var
  LExp: Int32;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LExp := Int32(AExpected);
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_weak(PInt32(@FValue)^, LExp, Int32(ADesired), LSuccessOrder, LFailureOrder);
  AExpected := PtrInt(LExp);
end;
{$ELSE}
var
  LExp: Int64;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LExp := Int64(AExpected);
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_weak_64(PInt64(@FValue)^, LExp, Int64(ADesired), LSuccessOrder, LFailureOrder);
  AExpected := PtrInt(LExp);
end;
{$ENDIF}

function TAtomicISize.FetchAdd(ADelta: PtrInt; AOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
  Result := PtrInt(atomic_fetch_add(PInt32(@FValue)^, Int32(ADelta), AOrder));
  {$ELSE}
  Result := PtrInt(atomic_fetch_add_64(PInt64(@FValue)^, Int64(ADelta), AOrder));
  {$ENDIF}
end;

function TAtomicISize.FetchSub(ADelta: PtrInt; AOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
  Result := PtrInt(atomic_fetch_sub(PInt32(@FValue)^, Int32(ADelta), AOrder));
  {$ELSE}
  Result := PtrInt(atomic_fetch_sub_64(PInt64(@FValue)^, Int64(ADelta), AOrder));
  {$ENDIF}
end;

function TAtomicISize.FetchAnd(AMask: PtrInt; AOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
  Result := PtrInt(atomic_fetch_and(PInt32(@FValue)^, Int32(AMask), AOrder));
  {$ELSE}
  Result := PtrInt(atomic_fetch_and_64(PInt64(@FValue)^, Int64(AMask), AOrder));
  {$ENDIF}
end;

function TAtomicISize.FetchOr(AMask: PtrInt; AOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
  Result := PtrInt(atomic_fetch_or(PInt32(@FValue)^, Int32(AMask), AOrder));
  {$ELSE}
  Result := PtrInt(atomic_fetch_or_64(PInt64(@FValue)^, Int64(AMask), AOrder));
  {$ENDIF}
end;

function TAtomicISize.FetchXor(AMask: PtrInt; AOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
  Result := PtrInt(atomic_fetch_xor(PInt32(@FValue)^, Int32(AMask), AOrder));
  {$ELSE}
  Result := PtrInt(atomic_fetch_xor_64(PInt64(@FValue)^, Int64(AMask), AOrder));
  {$ENDIF}
end;

function TAtomicISize.Increment(AOrder: memory_order_t): PtrInt;
begin
  Result := FetchAdd(1, AOrder) + 1;
end;

function TAtomicISize.Decrement(AOrder: memory_order_t): PtrInt;
begin
  Result := FetchSub(1, AOrder) - 1;
end;

function TAtomicISize.GetMut: PPtrInt;
begin
  Result := @FValue;
end;

function TAtomicISize.IntoInner: PtrInt;
begin
  Result := FValue;
end;

{ TAtomicUSize }

class function TAtomicUSize.Create(AValue: PtrUInt): TAtomicUSize;
begin
  Result.FValue := AValue;
end;

class function TAtomicUSize.is_lock_free: Boolean;
begin
  // Pointer-sized atomic operations are always lock-free on modern platforms
  Result := True;
end;

function TAtomicUSize.Load(AOrder: memory_order_t): PtrUInt;
begin
  {$IF SIZEOF(PtrUInt) = 4}
  Result := PtrUInt(atomic_load(PUInt32(@FValue)^, AOrder));
  {$ELSE}
  Result := PtrUInt(atomic_load_64(PUInt64(@FValue)^, AOrder));
  {$ENDIF}
end;

procedure TAtomicUSize.Store(AValue: PtrUInt; AOrder: memory_order_t);
begin
  {$IF SIZEOF(PtrUInt) = 4}
  atomic_store(PUInt32(@FValue)^, UInt32(AValue), AOrder);
  {$ELSE}
  atomic_store_64(PUInt64(@FValue)^, UInt64(AValue), AOrder);
  {$ENDIF}
end;

function TAtomicUSize.Exchange(AValue: PtrUInt; AOrder: memory_order_t): PtrUInt;
begin
  {$IF SIZEOF(PtrUInt) = 4}
  Result := PtrUInt(atomic_exchange(PUInt32(@FValue)^, UInt32(AValue), AOrder));
  {$ELSE}
  Result := PtrUInt(atomic_exchange_64(PUInt64(@FValue)^, UInt64(AValue), AOrder));
  {$ENDIF}
end;

function TAtomicUSize.CompareExchangeStrong(var AExpected: PtrUInt; ADesired: PtrUInt;
  AOrder: memory_order_t): Boolean;
{$IF SIZEOF(PtrUInt) = 4}
var
  LExp: UInt32;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LExp := UInt32(AExpected);
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_strong(PUInt32(@FValue)^, LExp, UInt32(ADesired), LSuccessOrder, LFailureOrder);
  AExpected := PtrUInt(LExp);
end;
{$ELSE}
var
  LExp: UInt64;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LExp := UInt64(AExpected);
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_strong_64(PUInt64(@FValue)^, LExp, UInt64(ADesired), LSuccessOrder, LFailureOrder);
  AExpected := PtrUInt(LExp);
end;
{$ENDIF}

function TAtomicUSize.CompareExchangeWeak(var AExpected: PtrUInt; ADesired: PtrUInt;
  AOrder: memory_order_t): Boolean;
{$IF SIZEOF(PtrUInt) = 4}
var
  LExp: UInt32;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LExp := UInt32(AExpected);
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_weak(PUInt32(@FValue)^, LExp, UInt32(ADesired), LSuccessOrder, LFailureOrder);
  AExpected := PtrUInt(LExp);
end;
{$ELSE}
var
  LExp: UInt64;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LExp := UInt64(AExpected);
  LSuccessOrder := _cas_success_order(AOrder);
  LFailureOrder := _cas_failure_order(LSuccessOrder);
  Result := atomic_compare_exchange_weak_64(PUInt64(@FValue)^, LExp, UInt64(ADesired), LSuccessOrder, LFailureOrder);
  AExpected := PtrUInt(LExp);
end;
{$ENDIF}

function TAtomicUSize.FetchAdd(ADelta: PtrUInt; AOrder: memory_order_t): PtrUInt;
begin
  {$IF SIZEOF(PtrUInt) = 4}
  Result := PtrUInt(atomic_fetch_add(PUInt32(@FValue)^, UInt32(ADelta), AOrder));
  {$ELSE}
  Result := PtrUInt(atomic_fetch_add_64(PUInt64(@FValue)^, UInt64(ADelta), AOrder));
  {$ENDIF}
end;

function TAtomicUSize.FetchSub(ADelta: PtrUInt; AOrder: memory_order_t): PtrUInt;
begin
  {$IF SIZEOF(PtrUInt) = 4}
  Result := PtrUInt(atomic_fetch_sub(PUInt32(@FValue)^, UInt32(ADelta), AOrder));
  {$ELSE}
  Result := PtrUInt(atomic_fetch_sub_64(PUInt64(@FValue)^, UInt64(ADelta), AOrder));
  {$ENDIF}
end;

function TAtomicUSize.FetchAnd(AMask: PtrUInt; AOrder: memory_order_t): PtrUInt;
begin
  {$IF SIZEOF(PtrUInt) = 4}
  Result := PtrUInt(atomic_fetch_and(PUInt32(@FValue)^, UInt32(AMask), AOrder));
  {$ELSE}
  Result := PtrUInt(atomic_fetch_and_64(PUInt64(@FValue)^, UInt64(AMask), AOrder));
  {$ENDIF}
end;

function TAtomicUSize.FetchOr(AMask: PtrUInt; AOrder: memory_order_t): PtrUInt;
begin
  {$IF SIZEOF(PtrUInt) = 4}
  Result := PtrUInt(atomic_fetch_or(PUInt32(@FValue)^, UInt32(AMask), AOrder));
  {$ELSE}
  Result := PtrUInt(atomic_fetch_or_64(PUInt64(@FValue)^, UInt64(AMask), AOrder));
  {$ENDIF}
end;

function TAtomicUSize.FetchXor(AMask: PtrUInt; AOrder: memory_order_t): PtrUInt;
begin
  {$IF SIZEOF(PtrUInt) = 4}
  Result := PtrUInt(atomic_fetch_xor(PUInt32(@FValue)^, UInt32(AMask), AOrder));
  {$ELSE}
  Result := PtrUInt(atomic_fetch_xor_64(PUInt64(@FValue)^, UInt64(AMask), AOrder));
  {$ENDIF}
end;

function TAtomicUSize.Increment(AOrder: memory_order_t): PtrUInt;
begin
  Result := FetchAdd(1, AOrder) + 1;
end;

function TAtomicUSize.Decrement(AOrder: memory_order_t): PtrUInt;
begin
  Result := FetchSub(1, AOrder) - 1;
end;

function TAtomicUSize.GetMut: PPtrUInt;
begin
  Result := @FValue;
end;

function TAtomicUSize.IntoInner: PtrUInt;
begin
  Result := FValue;
end;

{ TAtomicPtr }

class function TAtomicPtr.Create(AValue: PT): TAtomicPtr;
begin
  Result.FValue := AValue;
end;

class function TAtomicPtr.is_lock_free: Boolean;
begin
  // Pointer atomic operations are always lock-free on modern platforms
  Result := True;
end;

function TAtomicPtr.Load(AOrder: memory_order_t): PT;
begin
  Result := PT(atomic_load(PPointer(@FValue)^, AOrder));
end;

procedure TAtomicPtr.Store(AValue: PT; AOrder: memory_order_t);
begin
  atomic_store(PPointer(@FValue)^, Pointer(AValue), AOrder);
end;

function TAtomicPtr.Exchange(AValue: PT; AOrder: memory_order_t): PT;
begin
  Result := PT(atomic_exchange(PPointer(@FValue)^, Pointer(AValue), AOrder));
end;

function TAtomicPtr.CompareExchangeStrong(var AExpected: PT; ADesired: PT;
  AOrder: memory_order_t): Boolean;
var
  LExp: Pointer;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LExp := Pointer(AExpected);

  // NOTE: This is a generic template; avoid referencing implementation-only helpers.
  if AOrder = mo_consume then
    LSuccessOrder := mo_acquire
  else
    LSuccessOrder := AOrder;

  case LSuccessOrder of
    mo_relaxed: LFailureOrder := mo_relaxed;
    mo_acquire: LFailureOrder := mo_acquire;
    mo_release: LFailureOrder := mo_relaxed;
    mo_acq_rel: LFailureOrder := mo_acquire;
    mo_seq_cst: LFailureOrder := mo_seq_cst;
  else
    LFailureOrder := mo_relaxed;
  end;

  Result := atomic_compare_exchange_strong(PPointer(@FValue)^, LExp, Pointer(ADesired), LSuccessOrder, LFailureOrder);
  AExpected := PT(LExp);
end;

function TAtomicPtr.CompareExchangeWeak(var AExpected: PT; ADesired: PT;
  AOrder: memory_order_t): Boolean;
var
  LExp: Pointer;
  LSuccessOrder: memory_order_t;
  LFailureOrder: memory_order_t;
begin
  LExp := Pointer(AExpected);

  // NOTE: This is a generic template; avoid referencing implementation-only helpers.
  if AOrder = mo_consume then
    LSuccessOrder := mo_acquire
  else
    LSuccessOrder := AOrder;

  case LSuccessOrder of
    mo_relaxed: LFailureOrder := mo_relaxed;
    mo_acquire: LFailureOrder := mo_acquire;
    mo_release: LFailureOrder := mo_relaxed;
    mo_acq_rel: LFailureOrder := mo_acquire;
    mo_seq_cst: LFailureOrder := mo_seq_cst;
  else
    LFailureOrder := mo_relaxed;
  end;

  Result := atomic_compare_exchange_weak(PPointer(@FValue)^, LExp, Pointer(ADesired), LSuccessOrder, LFailureOrder);
  AExpected := PT(LExp);
end;

function TAtomicPtr.GetMut: Pointer;
begin
  Result := @FValue;
end;

function TAtomicPtr.IntoInner: PT;
begin
  Result := FValue;
end;

end.
