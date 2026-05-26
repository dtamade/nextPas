unit nextpas.core.atomic;

{
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│          ______   ______     ______   ______     ______   ______             │
│         /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \            │
│         \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \           │
│          \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\          │
│           \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/          │
│                                                                              │
│                                   Studio                                     │
└──────────────────────────────────────────────────────────────────────────────┘

📦 项目：nextpas.core.atomic - 高性能原子操作实现
────────────────────────────────────────────────────────────────────────────────
📖 概述：
  现代化、跨平台的 FreePascal 原子操作（C++ API 外观）实现。
────────────────────────────────────────────────────────────────────────────────
🔧 特性：
  • 跨平台支持：Windows、Linux、macOS、FreeBSD 等
  • 高性能实现：使用平台原生原子指令优化
  • 无锁设计：避免传统锁的开销和竞争
  • 内存序控制：支持多种内存排序语义
  • 类型安全：泛型封装确保类型一致性
  • CAS 操作：Compare-And-Swap 原语支持
  • 移植友好：支持 Windows、Linux、macOS、FreeBSD 等平台
────────────────────────────────────────────────────────────────────────────────
⚠️ 重要说明：
  原子操作仅保证单个操作的原子性，复合操作仍需要额外的同步机制。
  请根据具体场景选择合适的内存序语义以确保正确性。
────────────────────────────────────────────────────────────────────────────────
🧵 线程安全性：
  所有原子操作都是线程安全的，可以从多个线程同时调用。
────────────────────────────────────────────────────────────────────────────────
📜 声明：
  转发或用于个人/商业项目时，请保留本项目的版权声明。
────────────────────────────────────────────────────────────────────────────────
👤 author  : nextpasStudio
📧 Email   : dtamade@gmail.com
💬 QQGroup : 685403987
💬 QQ      : 179033731

}

{$I nextpas.core.settings.inc}
{$WARN 5024 off} // memory_order params are API-compat placeholders on some backends

interface

uses
  nextpas.core.atomic.core,
  nextpas.core.atomic.types;

type

  memory_order_t = nextpas.core.atomic.core.memory_order_t;
  TMemoryOrder = memory_order_t;
  TAtomicInt32 = nextpas.core.atomic.types.TAtomicInt32;
  TAtomicUInt32 = nextpas.core.atomic.types.TAtomicUInt32;
  {$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
  TAtomicInt64 = nextpas.core.atomic.types.TAtomicInt64;
  TAtomicUInt64 = nextpas.core.atomic.types.TAtomicUInt64;
  {$ENDIF}
  TAtomicBool = nextpas.core.atomic.types.TAtomicBool;
  TAtomicFlag = nextpas.core.atomic.types.TAtomicFlag;
  TAtomicISize = nextpas.core.atomic.types.TAtomicISize;
  TAtomicUSize = nextpas.core.atomic.types.TAtomicUSize;

const
  mo_relaxed = nextpas.core.atomic.core.mo_relaxed;
  mo_consume = nextpas.core.atomic.core.mo_consume;
  mo_acquire = nextpas.core.atomic.core.mo_acquire;
  mo_release = nextpas.core.atomic.core.mo_release;
  mo_acq_rel = nextpas.core.atomic.core.mo_acq_rel;
  mo_seq_cst = nextpas.core.atomic.core.mo_seq_cst;
  moRelaxed = mo_relaxed;
  moConsume = mo_consume;
  moAcquire = mo_acquire;
  moRelease = mo_release;
  moAcqRel = mo_acq_rel;
  moSeqCst = mo_seq_cst;

// cpu_pause: self-spin hint (PAUSE/YIELD/no-op), useful for CAS loops.
procedure cpu_pause;
procedure CpuPause; inline;

function AtomicLoad32(var ATarget: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
procedure AtomicStore32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst); inline;
function AtomicExchange32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicCompareExchange32(var ATarget: Int32; const AExpected, ADesired: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicFetchAdd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicFetchSub32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicFetchAnd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicFetchOr32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicFetchXor32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;

function AtomicLoad64(var ATarget: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64; inline;
procedure AtomicStore64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst); inline;
function AtomicExchange64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64; inline;
function AtomicCompareExchange64(var ATarget: Int64; const AExpected, ADesired: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64; inline;
function AtomicFetchAdd64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64; inline;
function AtomicFetchSub64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64; inline;

function AtomicLoadPtr(var ATarget: Pointer; const AOrder: TMemoryOrder = moSeqCst): Pointer; inline;
procedure AtomicStorePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder = moSeqCst); inline;
function AtomicExchangePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder = moSeqCst): Pointer; inline;
function AtomicCompareExchangePtr(var ATarget: Pointer; const AExpected, ADesired: Pointer; const AOrder: TMemoryOrder = moSeqCst): Pointer; inline;

procedure AtomicThreadFence(const AOrder: TMemoryOrder = moSeqCst); inline;
procedure AtomicSignalFence(const AOrder: TMemoryOrder = moSeqCst); inline;

//┌────────────────────────────────────────────────────────────────────────────┐
//│                            Memory Fences                                   │
//└────────────────────────────────────────────────────────────────────────────┘

{**
 * @desc 线程间内存屏障
 * @details 建立线程间的同步关系，确保屏障前的内存操作对其他线程可见
 *
 * @param aOrder 内存序
 *   - mo_acquire: 获取屏障，确保屏障后的读操作不会被重排到屏障前
 *   - mo_release: 释放屏障，确保屏障前的写操作不会被重排到屏障后
 *   - mo_acq_rel: 获取+释放屏障，结合两者的效果
 *   - mo_seq_cst: 顺序一致性屏障，最强的同步保证
 *   - mo_relaxed: 无效，会触发运行时错误
 *
 * @usage
 *   // 生产者-消费者模式
 *   atomic_store(data, 42, mo_relaxed);
 *   atomic_thread_fence(mo_release);  // 确保 data 写入对消费者可见
 *   atomic_store(flag, 1, mo_relaxed);
 *
 * @thread_safety 线程安全
 * @performance 性能开销取决于内存序和硬件平台
 * @rust_equivalent std::sync::atomic::fence
 * @cpp_equivalent std::atomic_thread_fence
 *}
procedure atomic_thread_fence(aOrder: memory_order_t);

{**
 * @desc 编译器内存屏障（信号处理器屏障）
 * @details 防止编译器重排序，但不影响硬件层面的内存可见性
 *          主要用于信号处理器和当前线程之间的同步
 *
 * @param aOrder 内存序（语义同 atomic_thread_fence）
 *
 * @usage
 *   // 信号处理器中使用
 *   atomic_store(flag, 1, mo_relaxed);
 *   atomic_signal_fence(mo_release);  // 防止编译器重排序
 *
 * @thread_safety 线程安全
 * @performance 零开销（仅编译器指令）
 * @rust_equivalent std::sync::atomic::compiler_fence
 * @cpp_equivalent std::atomic_signal_fence
 *}
procedure atomic_signal_fence(aOrder: memory_order_t);

//┌────────────────────────────────────────────────────────────────────────────┐
//│                                atomic_load                                 │
//└────────────────────────────────────────────────────────────────────────────┘

function atomic_load(var aObj: Int32; aOrder: memory_order_t): Int32; overload; inline;
function atomic_load(var aObj: Int32): Int32; overload; inline;

function atomic_load(var aObj: UInt32; aOrder: memory_order_t): UInt32; overload; inline;
function atomic_load(var aObj: UInt32): UInt32; overload; inline;

{$IFDEF CPU64}
function atomic_load(var aObj: PtrUInt; aOrder: memory_order_t): PtrUInt; overload; inline;
function atomic_load(var aObj: PtrUInt): PtrUInt; overload; inline;

function atomic_load(var aObj: PtrInt; aOrder: memory_order_t): PtrInt; overload; inline;
function atomic_load(var aObj: PtrInt): PtrInt; overload; inline;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_load_64(var aObj: Int64; aOrder: memory_order_t): Int64; overload; inline;
function atomic_load_64(var aObj: Int64): Int64; overload; inline;

function atomic_load_64(var aObj: UInt64; aOrder: memory_order_t): UInt64; overload; inline;
function atomic_load_64(var aObj: UInt64): UInt64; overload; inline;
{$ENDIF}

function atomic_load(var aObj: Pointer; aOrder: memory_order_t): Pointer; overload; inline;
function atomic_load(var aObj: Pointer): Pointer; overload; inline;

//┌────────────────────────────────────────────────────────────────────────────┐
//│                                atomic_store                                │
//└────────────────────────────────────────────────────────────────────────────┘

procedure atomic_store(var aObj: Int32; aDesired: Int32; aOrder: memory_order_t); overload; inline;
procedure atomic_store(var aObj: Int32; aDesired: Int32); overload; inline;

procedure atomic_store(var aObj: UInt32; aDesired: UInt32; aOrder: memory_order_t); overload; inline;
procedure atomic_store(var aObj: UInt32; aDesired: UInt32); overload; inline;

{$IFDEF CPU64}
procedure atomic_store(var aObj: PtrInt; aDesired: PtrInt; aOrder: memory_order_t); overload; inline;
procedure atomic_store(var aObj: PtrInt; aDesired: PtrInt); overload; inline;

procedure atomic_store(var aObj: PtrUInt; aDesired: PtrUInt; aOrder: memory_order_t); overload; inline;
procedure atomic_store(var aObj: PtrUInt; aDesired: PtrUInt); overload; inline;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
procedure atomic_store_64(var aObj: Int64; aDesired: Int64; aOrder: memory_order_t); overload; inline;
procedure atomic_store_64(var aObj: Int64; aDesired: Int64); overload; inline;

procedure atomic_store_64(var aObj: UInt64; aDesired: UInt64; aOrder: memory_order_t); overload; inline;
procedure atomic_store_64(var aObj: UInt64; aDesired: UInt64); overload; inline;
{$ENDIF}

procedure atomic_store(var aObj: Pointer; aDesired: Pointer; aOrder: memory_order_t); overload; inline;
procedure atomic_store(var aObj: Pointer; aDesired: Pointer); overload; inline;

//┌────────────────────────────────────────────────────────────────────────────┐
//│                              atomic_exchange                               │
//└────────────────────────────────────────────────────────────────────────────┘

// ✅ Phase 3: 添加 memory_order 参数版本
function atomic_exchange(var aObj: Int32; aDesired: Int32; aOrder: memory_order_t): Int32; overload; inline;
function atomic_exchange(var aObj: Int32; aDesired: Int32): Int32; overload; inline;
function atomic_exchange(var aObj: UInt32; aDesired: UInt32; aOrder: memory_order_t): UInt32; overload; inline;
function atomic_exchange(var aObj: UInt32; aDesired: UInt32): UInt32; overload; inline;

{$IFDEF CPU64}
function atomic_exchange(var aObj: PtrInt; aDesired: PtrInt; aOrder: memory_order_t): PtrInt; overload; inline;
function atomic_exchange(var aObj: PtrInt; aDesired: PtrInt): PtrInt; overload; inline;
function atomic_exchange(var aObj: PtrUInt; aDesired: PtrUInt; aOrder: memory_order_t): PtrUInt; overload; inline;
function atomic_exchange(var aObj: PtrUInt; aDesired: PtrUInt): PtrUInt; overload; inline;
{$ENDIF}
{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_exchange_64(var aObj: Int64; aDesired: Int64; aOrder: memory_order_t): Int64; overload; inline;
function atomic_exchange_64(var aObj: Int64; aDesired: Int64): Int64; overload; inline;
function atomic_exchange_64(var aObj: UInt64; aDesired: UInt64; aOrder: memory_order_t): UInt64; overload; inline;
function atomic_exchange_64(var aObj: UInt64; aDesired: UInt64): UInt64; overload; inline;
{$ENDIF}
function atomic_exchange(var aObj: Pointer; aDesired: Pointer; aOrder: memory_order_t): Pointer; overload; inline;
function atomic_exchange(var aObj: Pointer; aDesired: Pointer): Pointer; overload; inline;

//┌────────────────────────────────────────────────────────────────────────────┐
//│                          atomic_compare_exchange                           │
//└────────────────────────────────────────────────────────────────────────────┘

function atomic_compare_exchange(var aObj: Int32; var aExpected: Int32; aDesired: Int32): Boolean; overload; inline;
function atomic_compare_exchange(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32): Boolean; overload; inline;

{$IFDEF CPU64}
function atomic_compare_exchange(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt): Boolean; overload; inline;
function atomic_compare_exchange(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt): Boolean; overload; inline;
{$ENDIF}
{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64): Boolean; overload; inline;
function atomic_compare_exchange_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64): Boolean; overload; inline;
{$ENDIF}
function atomic_compare_exchange(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer): Boolean; overload; inline;

function atomic_compare_exchange_strong(var aObj: Int32; var aExpected: Int32; aDesired: Int32): Boolean; overload; inline;
function atomic_compare_exchange_strong(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32): Boolean; overload; inline;
{$IFDEF CPU64}
function atomic_compare_exchange_strong(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt): Boolean; overload; inline;
function atomic_compare_exchange_strong(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt): Boolean; overload; inline;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_strong_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64): Boolean; overload; inline;
function atomic_compare_exchange_strong_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64): Boolean; overload; inline;
{$ENDIF}

function atomic_compare_exchange_strong(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer): Boolean; overload; inline;

function atomic_compare_exchange_weak(var aObj: Int32; var aExpected: Int32; aDesired: Int32): Boolean; overload; inline;
function atomic_compare_exchange_weak(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32): Boolean; overload; inline;

{$IFDEF CPU64}
function atomic_compare_exchange_weak(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt): Boolean; overload; inline;
function atomic_compare_exchange_weak(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt): Boolean; overload; inline;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_weak_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64): Boolean; overload; inline;
function atomic_compare_exchange_weak_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64): Boolean; overload; inline;
{$ENDIF}
function atomic_compare_exchange_weak(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer): Boolean; overload; inline;

// ✅ Phase 3: CAS 带双内存序参数 (success_order, failure_order) - 对齐 C++11/Rust API
function atomic_compare_exchange_strong(var aObj: Int32; var aExpected: Int32; aDesired: Int32;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_strong(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
{$IFDEF CPU64}
function atomic_compare_exchange_strong(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_strong(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
{$ENDIF}
{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_strong_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_strong_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
{$ENDIF}
function atomic_compare_exchange_strong(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;

function atomic_compare_exchange_weak(var aObj: Int32; var aExpected: Int32; aDesired: Int32;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_weak(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
{$IFDEF CPU64}
function atomic_compare_exchange_weak(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_weak(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
{$ENDIF}
{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_weak_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_weak_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
{$ENDIF}
function atomic_compare_exchange_weak(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;

// ✅ P1-002: CAS 带单内存序参数 (aOrder) - 简化常见用法（成功和失败使用相同内存序）
{**
 * @desc 原子比较并交换操作（单内存序版本）
 * @details 简化版本，成功和失败情况使用相同的内存序
 *
 * @memory_order_usage
 * 此版本适用于不需要区分成功和失败内存序的常见场景：
 * - 使用 mo_seq_cst：最安全，适合大多数场景
 * - 使用 mo_acq_rel：获取-释放语义，适合同步场景
 * - 使用 mo_acquire：仅需要获取语义
 * - 使用 mo_release：仅需要释放语义（较少使用）
 * - 使用 mo_relaxed：仅保证原子性，无同步（高级用法）
 *
 * @when_to_use
 * - 当成功和失败都需要相同的内存序时
 * - 当不确定如何选择不同的内存序时
 * - 当代码简洁性比性能优化更重要时
 *
 * @performance
 * 性能与双内存序版本相同，但代码更简洁易读。
 *
 * @example
 *   var counter: Int32 := 0;
 *   var expected: Int32 := 0;
 *   // 使用 seq_cst 保证顺序一致性
 *   if atomic_compare_exchange_strong(counter, expected, 1, mo_seq_cst) then
 *     WriteLn('CAS succeeded');
 *
 *   // 使用 acq_rel 进行同步
 *   if atomic_compare_exchange_strong(counter, expected, 2, mo_acq_rel) then
 *     WriteLn('CAS succeeded with acquire-release semantics');
 *
 * @cpp_equivalent
 *   std::atomic<T>::compare_exchange_strong(expected, desired, order)
 *   std::atomic<T>::compare_exchange_weak(expected, desired, order)
 *
 * @rust_equivalent
 *   AtomicT::compare_exchange(expected, desired, order, order)
 *   AtomicT::compare_exchange_weak(expected, desired, order, order)
 *}
function atomic_compare_exchange_strong(var aObj: Int32; var aExpected: Int32; aDesired: Int32;
  aOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_strong(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32;
  aOrder: memory_order_t): Boolean; overload; inline;
{$IFDEF CPU64}
function atomic_compare_exchange_strong(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt;
  aOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_strong(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt;
  aOrder: memory_order_t): Boolean; overload; inline;
{$ENDIF}
{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_strong_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64;
  aOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_strong_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64;
  aOrder: memory_order_t): Boolean; overload; inline;
{$ENDIF}
function atomic_compare_exchange_strong(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer;
  aOrder: memory_order_t): Boolean; overload; inline;

function atomic_compare_exchange_weak(var aObj: Int32; var aExpected: Int32; aDesired: Int32;
  aOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_weak(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32;
  aOrder: memory_order_t): Boolean; overload; inline;
{$IFDEF CPU64}
function atomic_compare_exchange_weak(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt;
  aOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_weak(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt;
  aOrder: memory_order_t): Boolean; overload; inline;
{$ENDIF}
{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_weak_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64;
  aOrder: memory_order_t): Boolean; overload; inline;
function atomic_compare_exchange_weak_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64;
  aOrder: memory_order_t): Boolean; overload; inline;
{$ENDIF}
function atomic_compare_exchange_weak(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer;
  aOrder: memory_order_t): Boolean; overload; inline;

//┌────────────────────────────────────────────────────────────────────────────┐
//│                              atomic_increment                              │
//└────────────────────────────────────────────────────────────────────────────┘

function atomic_increment(var aObj: Int32): Int32; overload; inline;
function atomic_increment(var aObj: UInt32): UInt32; overload; inline;
{$IFDEF CPU64}
function atomic_increment(var aObj: PtrInt): PtrInt; overload; inline;
function atomic_increment(var aObj: PtrUInt): PtrUInt; overload; inline;
{$ENDIF}
{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_increment_64(var aObj: Int64): Int64; overload; inline;
function atomic_increment_64(var aObj: UInt64): UInt64; overload; inline;
{$ENDIF}

//┌────────────────────────────────────────────────────────────────────────────┐
//│                              atomic_decrement                              │
//└────────────────────────────────────────────────────────────────────────────┘

function atomic_decrement(var aObj: Int32): Int32; overload; inline;
function atomic_decrement(var aObj: UInt32): UInt32; overload; inline;
{$IFDEF CPU64}
function atomic_decrement(var aObj: PtrInt): PtrInt; overload; inline;
function atomic_decrement(var aObj: PtrUInt): PtrUInt; overload; inline;
{$ENDIF}
{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_decrement_64(var aObj: Int64): Int64; overload; inline;
function atomic_decrement_64(var aObj: UInt64): UInt64; overload; inline;
{$ENDIF}

//┌────────────────────────────────────────────────────────────────────────────┐
//│                              atomic_fetch_add                              │
//└────────────────────────────────────────────────────────────────────────────┘

// ✅ Phase 3: 添加 memory_order 参数版本
function atomic_fetch_add(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32; overload; inline;
function atomic_fetch_add(var aObj: Int32; aArg: Int32): Int32; overload; inline;
function atomic_fetch_add(var aObj: UInt32; aArg: UInt32; aOrder: memory_order_t): UInt32; overload; inline;
function atomic_fetch_add(var aObj: UInt32; aArg: UInt32): UInt32; overload; inline;
{$IFDEF CPU64}
function atomic_fetch_add(var aObj: PtrInt; aArg: PtrInt; aOrder: memory_order_t): PtrInt; overload; inline;
function atomic_fetch_add(var aObj: PtrInt; aArg: PtrInt): PtrInt; overload; inline;
function atomic_fetch_add(var aObj: PtrUInt; aArg: PtrUInt; aOrder: memory_order_t): PtrUInt; overload; inline;
function atomic_fetch_add(var aObj: PtrUInt; aArg: PtrUInt): PtrUInt; overload; inline;
{$ENDIF}
function atomic_fetch_add(var aObj: Pointer; aOffset: PtrInt): Pointer; overload; inline;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_add_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64; overload; inline;
function atomic_fetch_add_64(var aObj: Int64; aArg: Int64): Int64; overload; inline;
function atomic_fetch_add_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64; overload; inline;
function atomic_fetch_add_64(var aObj: UInt64; aArg: UInt64): UInt64; overload; inline;
{$ENDIF}

//┌────────────────────────────────────────────────────────────────────────────┐
//│                              atomic_fetch_sub                              │
//└────────────────────────────────────────────────────────────────────────────┘

// ✅ Phase 3: 添加 memory_order 参数版本
function atomic_fetch_sub(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32; overload; inline;
function atomic_fetch_sub(var aObj: Int32; aArg: Int32): Int32; overload; inline;
function atomic_fetch_sub(var aObj: UInt32; aArg: UInt32; aOrder: memory_order_t): UInt32; overload; inline;
function atomic_fetch_sub(var aObj: UInt32; aArg: UInt32): UInt32; overload; inline;
{$IFDEF CPU64}
function atomic_fetch_sub(var aObj: PtrInt; aArg: PtrInt; aOrder: memory_order_t): PtrInt; overload; inline;
function atomic_fetch_sub(var aObj: PtrInt; aArg: PtrInt): PtrInt; overload; inline;
function atomic_fetch_sub(var aObj: PtrUInt; aArg: PtrUInt; aOrder: memory_order_t): PtrUInt; overload; inline;
function atomic_fetch_sub(var aObj: PtrUInt; aArg: PtrUInt): PtrUInt; overload; inline;
{$ENDIF}
function atomic_fetch_sub(var aObj: Pointer; aOffset: PtrInt): Pointer; overload; inline;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_sub_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64; overload; inline;
function atomic_fetch_sub_64(var aObj: Int64; aArg: Int64): Int64; overload; inline;
function atomic_fetch_sub_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64; overload; inline;
function atomic_fetch_sub_64(var aObj: UInt64; aArg: UInt64): UInt64; overload; inline;
{$ENDIF}

//┌────────────────────────────────────────────────────────────────────────────┐
//│                              atomic_fetch_and                              │
//└────────────────────────────────────────────────────────────────────────────┘

// ✅ Phase 3: 添加 memory_order 参数版本
function atomic_fetch_and(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32; overload; inline;
function atomic_fetch_and(var aObj: Int32; aArg: Int32): Int32; overload; inline;
function atomic_fetch_and(var aObj: UInt32; aArg: UInt32; aOrder: memory_order_t): UInt32; overload; inline;
function atomic_fetch_and(var aObj: UInt32; aArg: UInt32): UInt32; overload; inline;
{$IFDEF CPU64}
function atomic_fetch_and(var aObj: PtrInt; aArg: PtrInt; aOrder: memory_order_t): PtrInt; overload; inline;
function atomic_fetch_and(var aObj: PtrInt; aArg: PtrInt): PtrInt; overload; inline;
function atomic_fetch_and(var aObj: PtrUInt; aArg: PtrUInt; aOrder: memory_order_t): PtrUInt; overload; inline;
function atomic_fetch_and(var aObj: PtrUInt; aArg: PtrUInt): PtrUInt; overload; inline;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_and_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64; overload; inline;
function atomic_fetch_and_64(var aObj: Int64; aArg: Int64): Int64; overload; inline;
function atomic_fetch_and_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64; overload; inline;
function atomic_fetch_and_64(var aObj: UInt64; aArg: UInt64): UInt64; overload; inline;
{$ENDIF}

//┌────────────────────────────────────────────────────────────────────────────┐
//│                              atomic_fetch_or                               │
//└────────────────────────────────────────────────────────────────────────────┘

// ✅ Phase 3: 添加 memory_order 参数版本
function atomic_fetch_or(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32; overload; inline;
function atomic_fetch_or(var aObj: Int32; aArg: Int32): Int32; overload; inline;
function atomic_fetch_or(var aObj: UInt32; aArg: UInt32; aOrder: memory_order_t): UInt32; overload; inline;
function atomic_fetch_or(var aObj: UInt32; aArg: UInt32): UInt32; overload; inline;
{$IFDEF CPU64}
function atomic_fetch_or(var aObj: PtrInt; aArg: PtrInt; aOrder: memory_order_t): PtrInt; overload; inline;
function atomic_fetch_or(var aObj: PtrInt; aArg: PtrInt): PtrInt; overload; inline;
function atomic_fetch_or(var aObj: PtrUInt; aArg: PtrUInt; aOrder: memory_order_t): PtrUInt; overload; inline;
function atomic_fetch_or(var aObj: PtrUInt; aArg: PtrUInt): PtrUInt; overload; inline;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_or_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64; overload; inline;
function atomic_fetch_or_64(var aObj: Int64; aArg: Int64): Int64; overload; inline;
function atomic_fetch_or_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64; overload; inline;
function atomic_fetch_or_64(var aObj: UInt64; aArg: UInt64): UInt64; overload; inline;
{$ENDIF}

//┌────────────────────────────────────────────────────────────────────────────┐
//│                              atomic_fetch_xor                              │
//└────────────────────────────────────────────────────────────────────────────┘

// ✅ Phase 3: 添加 memory_order 参数版本
function atomic_fetch_xor(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32; overload; inline;
function atomic_fetch_xor(var aObj: Int32; aArg: Int32): Int32; overload; inline;
function atomic_fetch_xor(var aObj: UInt32; aArg: UInt32; aOrder: memory_order_t): UInt32; overload; inline;
function atomic_fetch_xor(var aObj: UInt32; aArg: UInt32): UInt32; overload; inline;
{$IFDEF CPU64}
function atomic_fetch_xor(var aObj: PtrInt; aArg: PtrInt; aOrder: memory_order_t): PtrInt; overload; inline;
function atomic_fetch_xor(var aObj: PtrInt; aArg: PtrInt): PtrInt; overload; inline;
function atomic_fetch_xor(var aObj: PtrUInt; aArg: PtrUInt; aOrder: memory_order_t): PtrUInt; overload; inline;
function atomic_fetch_xor(var aObj: PtrUInt; aArg: PtrUInt): PtrUInt; overload; inline;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_xor_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64; overload; inline;
function atomic_fetch_xor_64(var aObj: Int64; aArg: Int64): Int64; overload; inline;
function atomic_fetch_xor_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64; overload; inline;
function atomic_fetch_xor_64(var aObj: UInt64; aArg: UInt64): UInt64; overload; inline;
{$ENDIF}

//┌────────────────────────────────────────────────────────────────────────────┐
//│                    atomic_fetch_max / min / nand (Phase 3)                 │
//└────────────────────────────────────────────────────────────────────────────┘

// ✅ Phase 3: 新增 fetch_max/min/nand 操作
function atomic_fetch_max(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32; overload; inline;
function atomic_fetch_max(var aObj: Int32; aArg: Int32): Int32; overload; inline;
function atomic_fetch_min(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32; overload; inline;
function atomic_fetch_min(var aObj: Int32; aArg: Int32): Int32; overload; inline;
function atomic_fetch_nand(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32; overload; inline;
function atomic_fetch_nand(var aObj: Int32; aArg: Int32): Int32; overload; inline;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_max_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64; overload; inline;
function atomic_fetch_max_64(var aObj: Int64; aArg: Int64): Int64; overload; inline;
function atomic_fetch_min_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64; overload; inline;
function atomic_fetch_min_64(var aObj: Int64; aArg: Int64): Int64; overload; inline;
function atomic_fetch_nand_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64; overload; inline;
function atomic_fetch_nand_64(var aObj: Int64; aArg: Int64): Int64; overload; inline;
{$ENDIF}

//┌────────────────────────────────────────────────────────────────────────────┐
//│                               atomic_flag                                  │
//└────────────────────────────────────────────────────────────────────────────┘

type

  atomic_flag_t = type Int32;

function atomic_flag_test_and_set(var aFlag: atomic_flag_t): Boolean; inline;
function atomic_flag_test(var aFlag: atomic_flag_t): Boolean; inline;
procedure atomic_flag_clear(var aFlag: atomic_flag_t); inline;

//┌────────────────────────────────────────────────────────────────────────────┐
//│                            atomic_is_lock_free                             │
//└────────────────────────────────────────────────────────────────────────────┘

function atomic_is_lock_free_32: Boolean; inline;
{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_is_lock_free_64: Boolean; inline;
{$ENDIF}
function atomic_is_lock_free_ptr: Boolean; inline;

//┌────────────────────────────────────────────────────────────────────────────┐
//│                             atomic_tagged_ptr                              │
//└────────────────────────────────────────────────────────────────────────────┘

type
  atomic_tagged_ptr_t = nextpas.core.atomic.core.atomic_tagged_ptr_t;

function  atomic_tagged_ptr(aPtr: Pointer; aTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}): atomic_tagged_ptr_t; inline;
function  atomic_tagged_ptr_get_ptr(const aTaggedPtr: atomic_tagged_ptr_t): Pointer; inline;
function  atomic_tagged_ptr_get_tag(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}; inline;

function  atomic_tagged_ptr_load(var aObj: atomic_tagged_ptr_t; aOrder: memory_order_t): atomic_tagged_ptr_t; overload; inline;
function  atomic_tagged_ptr_load(var aObj: atomic_tagged_ptr_t): atomic_tagged_ptr_t; overload; inline;
procedure atomic_tagged_ptr_store(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t; aOrder: memory_order_t); overload; inline;
procedure atomic_tagged_ptr_store(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t); overload; inline;
function  atomic_tagged_ptr_exchange(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t; aOrder: memory_order_t): atomic_tagged_ptr_t; overload; inline;
function  atomic_tagged_ptr_exchange(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t): atomic_tagged_ptr_t; overload; inline;
function  atomic_tagged_ptr_compare_exchange_strong(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t; aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
function  atomic_tagged_ptr_compare_exchange_strong(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t): Boolean; overload; inline;
function  atomic_tagged_ptr_compare_exchange_weak(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t; aSuccessOrder, aFailureOrder: memory_order_t): Boolean; overload; inline;
function  atomic_tagged_ptr_compare_exchange_weak(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t): Boolean; overload; inline;

function  atomic_tagged_ptr_next(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}; inline;
procedure atomic_tagged_ptr_update(var aObj: atomic_tagged_ptr_t; aPtr: Pointer); inline;
procedure atomic_tagged_ptr_update_tag(var aObj: atomic_tagged_ptr_t; aTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}); inline;

implementation

{$WARN 5024 off} // keep implementation hint-clean on platforms where order params are intentionally ignored

//┌────────────────────────────────────────────────────────────────────────────┐
//│              Phase 4: cpu_pause - 减少自旋等待开销                          │
//└────────────────────────────────────────────────────────────────────────────┘

procedure cpu_pause;
begin
  nextpas.core.atomic.core.cpu_pause;
end;

// A lightweight compiler barrier.
// - For x86/x86_64, acquire/release for plain load/store doesn't require a CPU fence (TSO),
//   but we still want to prevent compiler reordering.
// NOTE: FPC does not inline routines containing inline assembler, so keep this as a tiny
// out-of-line stub: the *call* itself is the compiler barrier (and there's no CPU fence).
{$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
procedure _compiler_barrier; assembler; nostackframe;
asm
  nop
end;
{$ELSE}
procedure _compiler_barrier; inline;
begin
  // Safe fallback if ever used on other platforms.
  ReadBarrier;
end;
{$ENDIF}

procedure _consume_memory_order(const aOrder: memory_order_t); inline;
begin
  // Keep builds hint-clean on platforms where memory_order is intentionally ignored.
  if aOrder = mo_relaxed then ;
end;

procedure _consume_memory_orders(const aSuccessOrder, aFailureOrder: memory_order_t); inline;
begin
  _consume_memory_order(aSuccessOrder);
  _consume_memory_order(aFailureOrder);
end;

//┌────────────────────────────────────────────────────────────────────────────┐
//│       Phase 1: 32 位 x86 上的 64 位原子操作底层实现                      │
//└────────────────────────────────────────────────────────────────────────────┘

{$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
// 32 位 x86 上使用 CMPXCHG8B 实现 64 位原子操作
// CMPXCHG8B 指令：比较 EDX:EAX 与 [mem]，相等则将 ECX:EBX 存入 [mem]
// 注意：FPC i386 使用寄存器调用约定，eax/edx/ecx 传递前三个参数

var
  // 32-bit x86: CMPXCHG8B may not exist on very old CPUs; provide runtime detection and fallback.
  gAtomic64HasCmpxchg8b: Boolean = True;
  gAtomic64FallbackLock: Int32 = 0;

procedure _atomic64_fallback_lock; inline;
begin
  // NOTE: Prefer XCHG-based acquire so the fallback doesn't implicitly require CMPXCHG.
  // This matters on very old 32-bit x86 where CMPXCHG8B/CPUID may be missing.
  while InterlockedExchange(gAtomic64FallbackLock, 1) <> 0 do
    cpu_pause;
end;

procedure _atomic64_fallback_unlock; inline;
begin
  InterlockedExchange(gAtomic64FallbackLock, 0);
end;

function _x86_has_cpuid: Boolean; inline;
var
  LCan: Byte;
begin
  LCan := 0;
  asm
    pushfd
    pop eax
    mov ecx, eax
    xor eax, $200000
    push eax
    popfd
    pushfd
    pop eax
    xor eax, ecx
    and eax, $200000
    setnz al
    mov LCan, al
    push ecx
    popfd
  end;
  Result := LCan <> 0;
end;

function _x86_has_cmpxchg8b: Boolean; inline;
var
  LEdx: UInt32;
begin
  if not _x86_has_cpuid then
    Exit(False);

  LEdx := 0;
  asm
    push ebx
    mov eax, 1
    cpuid
    mov LEdx, edx
    pop ebx
  end;

  Result := (LEdx and (UInt32(1) shl 8)) <> 0;
end;

function _atomic_load_64_x86(var aObj: Int64): Int64;
var
  LPtr: PInt64;
  LLo, LHi: UInt32;
begin
  if not gAtomic64HasCmpxchg8b then
  begin
    _atomic64_fallback_lock;
    Result := aObj;
    _atomic64_fallback_unlock;
    Exit;
  end;

  LPtr := @aObj;
  asm
    push ebx
    push edi
    mov edi, LPtr
    xor eax, eax
    xor edx, edx
    xor ebx, ebx
    xor ecx, ecx
    lock cmpxchg8b [edi]
    mov LLo, eax
    mov LHi, edx
    pop edi
    pop ebx
  end;
  Result := Int64(LHi) shl 32 or LLo;
end;

procedure _atomic_store_64_x86(var aObj: Int64; aDesired: Int64);
var
  LPtr: PInt64;
  LDesLo, LDesHi: UInt32;
begin
  if not gAtomic64HasCmpxchg8b then
  begin
    _atomic64_fallback_lock;
    aObj := aDesired;
    _atomic64_fallback_unlock;
    Exit;
  end;

  LPtr := @aObj;
  LDesLo := UInt32(aDesired);
  LDesHi := UInt32(aDesired shr 32);
  asm
    push ebx
    push edi
    mov edi, LPtr
    mov ebx, LDesLo
    mov ecx, LDesHi
    mov eax, [edi]
    mov edx, [edi + 4]
  @retry:
    lock cmpxchg8b [edi]
    jnz @retry
    pop edi
    pop ebx
  end;
end;

function _atomic_exchange_64_x86(var aObj: Int64; aDesired: Int64): Int64;
var
  LPtr: PInt64;
  LDesLo, LDesHi, LResLo, LResHi: UInt32;
begin
  if not gAtomic64HasCmpxchg8b then
  begin
    _atomic64_fallback_lock;
    Result := aObj;
    aObj := aDesired;
    _atomic64_fallback_unlock;
    Exit;
  end;

  LPtr := @aObj;
  LDesLo := UInt32(aDesired);
  LDesHi := UInt32(aDesired shr 32);
  asm
    push ebx
    push edi
    mov edi, LPtr
    mov ebx, LDesLo
    mov ecx, LDesHi
    mov eax, [edi]
    mov edx, [edi + 4]
  @retry:
    lock cmpxchg8b [edi]
    jnz @retry
    mov LResLo, eax
    mov LResHi, edx
    pop edi
    pop ebx
  end;
  Result := Int64(LResHi) shl 32 or LResLo;
end;

function _atomic_cmpxchg_64_x86(var aObj: Int64; var aExpected: Int64; aDesired: Int64): Boolean;
var
  LPtr: PInt64;
  LExpLo, LExpHi, LDesLo, LDesHi, LResLo, LResHi: UInt32;
  LSuccess: Boolean;
begin
  if not gAtomic64HasCmpxchg8b then
  begin
    _atomic64_fallback_lock;
    if aObj = aExpected then
    begin
      aObj := aDesired;
      Result := True;
    end
    else
    begin
      aExpected := aObj;
      Result := False;
    end;
    _atomic64_fallback_unlock;
    Exit;
  end;

  LPtr := @aObj;
  LExpLo := UInt32(aExpected);
  LExpHi := UInt32(aExpected shr 32);
  LDesLo := UInt32(aDesired);
  LDesHi := UInt32(aDesired shr 32);
  LSuccess := False;
  asm
    push ebx
    push edi
    mov edi, LPtr
    mov eax, LExpLo
    mov edx, LExpHi
    mov ebx, LDesLo
    mov ecx, LDesHi
    lock cmpxchg8b [edi]
    mov LResLo, eax
    mov LResHi, edx
    setz al
    mov LSuccess, al
    pop edi
    pop ebx
  end;
  if not LSuccess then
    aExpected := Int64(LResHi) shl 32 or LResLo;
  Result := LSuccess;
end;

function _atomic_fetch_add_64_x86(var aObj: Int64; aArg: Int64): Int64;
var
  LPtr: PInt64;
  LArgLo, LArgHi, LOldLo, LOldHi: UInt32;
begin
  if not gAtomic64HasCmpxchg8b then
  begin
    _atomic64_fallback_lock;
    Result := aObj;
    aObj := aObj + aArg;
    _atomic64_fallback_unlock;
    Exit;
  end;

  LPtr := @aObj;
  LArgLo := UInt32(aArg);
  LArgHi := UInt32(aArg shr 32);
  asm
    push ebx
    push edi
    mov edi, LPtr
    mov eax, [edi]
    mov edx, [edi + 4]
  @retry:
    mov LOldLo, eax
    mov LOldHi, edx
    // 计算新值
    mov ebx, eax
    add ebx, LArgLo
    mov ecx, edx
    adc ecx, LArgHi
    lock cmpxchg8b [edi]
    jnz @retry
    pop edi
    pop ebx
  end;
  Result := Int64(LOldHi) shl 32 or LOldLo;
end;
{$ENDIF}

function atomic_load(var aObj: Int32; aOrder: memory_order_t): Int32;
begin
  Result := aObj;
  case aOrder of
    mo_relaxed:
      Result := aObj;

    mo_consume, mo_acquire, mo_acq_rel:
      begin
        Result := aObj;
        {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
          _compiler_barrier;    // Acquire load on x86: compiler barrier is enough
        {$ELSE}
          ReadBarrier;          // Acquire load on weakly-ordered CPUs
        {$ENDIF}
      end;

    mo_release:
      begin
        // 对 load 没意义，直接当 relaxed
        Result := aObj;
      end;

    mo_seq_cst:
      begin
        // On weakly-ordered CPUs (e.g. AArch64), make seq_cst loads fully ordered.
        // On x86/x86_64, a plain load is already strongly ordered at the CPU level;
        // use only a compiler barrier to prevent reordering.
        {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
          Result := aObj;
          _compiler_barrier;
        {$ELSE}
          ReadWriteBarrier;
          Result := aObj;
          ReadWriteBarrier;
        {$ENDIF}
      end;
  end;
end;

function atomic_load(var aObj: Int32): Int32;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
    Result := atomic_load(aObj, mo_relaxed);
  {$ELSE}
    Result := atomic_load(aObj, mo_acquire);
  {$ENDIF}
end;

function atomic_load(var aObj: UInt32; aOrder: memory_order_t): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF} // Conversion between ordinals and pointers is not portable
  Result := UInt32(atomic_load(PInt32(@aObj)^, aOrder));
  {$POP}
end;

function atomic_load(var aObj: UInt32): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_load(PInt32(@aObj)^));
  {$POP}
end;


{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_load_64(var aObj: Int64; aOrder: memory_order_t): Int64;
begin
  Result := aObj;
  {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
  // 32-bit x86: use CMPXCHG8B-based atomic load
  Result := _atomic_load_64_x86(aObj);
  case aOrder of
    mo_consume, mo_acquire, mo_acq_rel, mo_seq_cst:
      _compiler_barrier;
  else
    ; // mo_relaxed, mo_release
  end;
  {$ELSE}
  // 64-bit: simple load is atomic
  case aOrder of
    mo_relaxed:
      Result := aObj;

    mo_consume, mo_acquire, mo_acq_rel:
      begin
        Result := aObj;
        {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
          _compiler_barrier;
        {$ELSE}
          ReadBarrier;
        {$ENDIF}
      end;

    mo_release:
      Result := aObj;

    mo_seq_cst:
      begin
        {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
          Result := aObj;
          _compiler_barrier;
        {$ELSE}
          ReadWriteBarrier;
          Result := aObj;
          ReadWriteBarrier;
        {$ENDIF}
      end;
  end;
  {$ENDIF}
end;

function atomic_load_64(var aObj: Int64): Int64;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
    Result := atomic_load_64(aObj, mo_relaxed);
  {$ELSE}
    Result := atomic_load_64(aObj, mo_acquire);
  {$ENDIF}
end;

function atomic_load_64(var aObj: UInt64; aOrder: memory_order_t): UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_load_64(PInt64(@aObj)^, aOrder));
  {$POP}
end;

function atomic_load_64(var aObj: UInt64):UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_load_64(PInt64(@aObj)^));
  {$POP}
end;

{$ENDIF}

function atomic_load(var aObj: Pointer; aOrder: memory_order_t): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF sizeof(Pointer) = 4}
    Result := Pointer(atomic_load(PInt32(@aObj)^, aOrder));
  {$ELSE}
    Result := Pointer(atomic_load_64(PInt64(@aObj)^, aOrder));
  {$ENDIF}
  {$POP}
end;

function atomic_load(var aObj: Pointer): Pointer;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
    Result := atomic_load(aObj, mo_relaxed);
  {$ELSE}
    Result := atomic_load(aObj, mo_acquire);
  {$ENDIF}
end;

{$IFDEF CPU64}
function atomic_load(var aObj: PtrInt; aOrder: memory_order_t): PtrInt;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF sizeof(PtrInt) = 4}
    Result := PtrInt(atomic_load(PInt32(@aObj)^, aOrder));
  {$ELSE}
    Result := PtrInt(atomic_load_64(PInt64(@aObj)^, aOrder));
  {$ENDIF}
  {$POP}
end;

function atomic_load(var aObj: PtrInt): PtrInt;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
    Result := atomic_load(aObj, mo_relaxed);
  {$ELSE}
    Result := atomic_load(aObj, mo_acquire);
  {$ENDIF}
end;


function atomic_load(var aObj: PtrUInt; aOrder: memory_order_t): PtrUInt;
begin
  Result:= PtrUInt(atomic_load(PPtrInt(@aObj)^, aOrder));
end;

function atomic_load(var aObj: PtrUInt): PtrUInt;
begin
  Result:= PtrUInt(atomic_load(PPtrInt(@aObj)^));
end;
{$ENDIF}

procedure atomic_store(var aObj: Int32; aDesired: Int32; aOrder: memory_order_t);
begin
  case aOrder of
    mo_relaxed, mo_consume, mo_acquire:
      aObj := aDesired;  // store 不需要 acquire/consume

    mo_release, mo_acq_rel:
      begin
        {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
          _compiler_barrier; // Release store on x86: compiler barrier is enough
        {$ELSE}
          WriteBarrier;      // Release store on weakly-ordered CPUs
        {$ENDIF}
        aObj := aDesired;
      end;

    mo_seq_cst:
      // ✅ P0-2 修复: seq_cst store 需要使用 XCHG (隐含 full barrier)
      // 原实现错误地在 store 之前放置屏障，正确做法是使用 InterlockedExchange
      InterlockedExchange(aObj, aDesired);
  end;
end;

procedure atomic_store(var aObj: Int32; aDesired: Int32);
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
    atomic_store(aObj, aDesired, mo_relaxed);
  {$ELSE}
    atomic_store(aObj, aDesired, mo_release);
  {$ENDIF}
end;

procedure atomic_store(var aObj: UInt32; aDesired: UInt32; aOrder: memory_order_t);
begin
  {$PUSH}
  {$WARN 4055 OFF}
  atomic_store(PInt32(@aObj)^, PInt32(@aDesired)^, aOrder);
  {$POP}
end;

procedure atomic_store(var aObj: UInt32; aDesired: UInt32);
begin
  {$PUSH}
  {$WARN 4055 OFF}
  atomic_store(PInt32(@aObj)^, PInt32(@aDesired)^);
  {$POP}
end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
procedure atomic_store_64(var aObj: Int64; aDesired: Int64; aOrder: memory_order_t);
begin
  {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
  // 32-bit x86: use CMPXCHG8B-based atomic store (LOCK CMPXCHG8B is already a full fence)
  case aOrder of
    mo_release, mo_acq_rel, mo_seq_cst:
      _compiler_barrier;
  else
    ; // mo_relaxed, mo_consume, mo_acquire
  end;
  _atomic_store_64_x86(aObj, aDesired);
  {$ELSE}
  // 64-bit: simple store is atomic
  case aOrder of
    mo_relaxed, mo_consume, mo_acquire:
      aObj := aDesired;

    mo_release, mo_acq_rel:
      begin
        {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
          _compiler_barrier;
        {$ELSE}
          WriteBarrier;
        {$ENDIF}
        aObj := aDesired;
      end;

    mo_seq_cst:
      // ✅ P0-2 修复: seq_cst store 需要使用 XCHG (隐含 full barrier)
      InterlockedExchange64(aObj, aDesired);
  end;
  {$ENDIF}
end;

procedure atomic_store_64(var aObj: Int64; aDesired: Int64);
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
    atomic_store_64(aObj, aDesired, mo_relaxed);
  {$ELSE}
    atomic_store_64(aObj, aDesired, mo_release);
  {$ENDIF}
end;

procedure atomic_store_64(var aObj: UInt64; aDesired: UInt64; aOrder: memory_order_t);
begin
  {$PUSH}
  {$WARN 4055 OFF}
  atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder);
  {$POP}
end;

procedure atomic_store_64(var aObj: UInt64; aDesired: UInt64);
begin
  {$PUSH}
  {$WARN 4055 OFF}
  atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^);
  {$POP}
end;
{$ENDIF}

procedure atomic_store(var aObj: Pointer; aDesired: Pointer; aOrder: memory_order_t);
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF sizeof(Pointer) = 4}
    atomic_store(PInt32(@aObj)^, PInt32(@aDesired)^, aOrder);
  {$ELSE}
    atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder);
  {$ENDIF}
  {$POP}
end;

procedure atomic_store(var aObj: Pointer; aDesired: Pointer);
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
    atomic_store(aObj, aDesired, mo_relaxed);
  {$ELSE}
    atomic_store(aObj, aDesired, mo_release);
  {$ENDIF}
end;


{$IFDEF CPU64}
procedure atomic_store(var aObj: PtrInt; aDesired: PtrInt; aOrder: memory_order_t);
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF sizeof(PtrInt) = 4}
    atomic_store(PInt32(@aObj)^, PInt32(@aDesired)^, aOrder);
  {$ELSE}
    atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder);
  {$ENDIF}
  {$POP}
end;

procedure atomic_store(var aObj: PtrInt; aDesired: PtrInt);
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
    atomic_store(aObj, aDesired, mo_relaxed);
  {$ELSE}
    atomic_store(aObj, aDesired, mo_release);
  {$ENDIF}
end;

procedure atomic_store(var aObj: PtrUInt; aDesired: PtrUInt; aOrder: memory_order_t);
begin
  atomic_store(PPtrInt(@aObj)^, PPtrInt(@aDesired)^, aOrder);
end;

procedure atomic_store(var aObj: PtrUInt; aDesired: PtrUInt);
begin
  atomic_store(PPtrInt(@aObj)^, PPtrInt(@aDesired)^);
end;
{$ENDIF}


// ✅ Phase 3: atomic_exchange 带 memory_order 参数实现
function atomic_exchange(var aObj: Int32; aDesired: Int32; aOrder: memory_order_t): Int32;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  // Exchange is a RMW.
  // On x86/x86_64, InterlockedExchange is implemented via XCHG/LOCK and already provides a full fence.
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  else
    ;
  end;
  {$ENDIF}

  Result := InterlockedExchange(aObj, aDesired);

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  else
    ; // mo_relaxed, mo_release
  end;
  {$ENDIF}
end;

function atomic_exchange(var aObj: Int32; aDesired: Int32): Int32;
begin
  // Default is seq_cst.
  Result := atomic_exchange(aObj, aDesired, mo_seq_cst);
end;

function atomic_exchange(var aObj: UInt32; aDesired: UInt32; aOrder: memory_order_t): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_exchange(PInt32(@aObj)^, PInt32(@aDesired)^, aOrder));
  {$POP}
end;

function atomic_exchange(var aObj: UInt32; aDesired: UInt32): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_exchange(PInt32(@aObj)^, PInt32(@aDesired)^));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_exchange(var aObj: PtrInt; aDesired: PtrInt; aOrder: memory_order_t): PtrInt;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF sizeof(PtrInt) = 4}
    Result := PtrInt(atomic_exchange(PInt32(@aObj)^, PInt32(@aDesired)^, aOrder));
  {$ELSE}
    Result := PtrInt(atomic_exchange_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder));
  {$ENDIF}
  {$POP}
end;

function atomic_exchange(var aObj: PtrInt; aDesired: PtrInt): PtrInt;
begin
  // Default is seq_cst.
  Result := atomic_exchange(aObj, aDesired, mo_seq_cst);
end;

function atomic_exchange(var aObj: PtrUInt; aDesired: PtrUInt; aOrder: memory_order_t): PtrUInt;
begin
  Result := PtrUInt(atomic_exchange(PPtrInt(@aObj)^, PPtrInt(@aDesired)^, aOrder));
end;

function atomic_exchange(var aObj: PtrUInt; aDesired: PtrUInt): PtrUInt;
begin
  Result := PtrUInt(atomic_exchange(PPtrInt(@aObj)^, PPtrInt(@aDesired)^));
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_exchange_64(var aObj: Int64; aDesired: Int64; aOrder: memory_order_t): Int64;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  // Exchange is a RMW.
  // On x86/x86_64, the underlying locked RMW already provides a full fence.
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  else
    ;
  end;
  {$ENDIF}

  {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
  // 32-bit x86: use CMPXCHG8B-based atomic exchange
  Result := _atomic_exchange_64_x86(aObj, aDesired);
  {$ELSE}
  Result := InterlockedExchange64(aObj, aDesired);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  else
    ; // mo_relaxed, mo_release
  end;
  {$ENDIF}
end;

function atomic_exchange_64(var aObj: Int64; aDesired: Int64): Int64;
begin
  // Default is seq_cst.
  Result := atomic_exchange_64(aObj, aDesired, mo_seq_cst);
end;

function atomic_exchange_64(var aObj: UInt64; aDesired: UInt64; aOrder: memory_order_t): UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_exchange_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder));
  {$POP}
end;

function atomic_exchange_64(var aObj: UInt64; aDesired: UInt64): UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_exchange_64(PInt64(@aObj)^, PInt64(@aDesired)^));
  {$POP}
end;
{$ENDIF}

function atomic_exchange(var aObj: Pointer; aDesired: Pointer; aOrder: memory_order_t): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF sizeof(Pointer) = 4}
    Result := Pointer(atomic_exchange(PInt32(@aObj)^, PInt32(@aDesired)^, aOrder));
  {$ELSE}
    Result := Pointer(atomic_exchange_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder));
  {$ENDIF}
  {$POP}
end;

function atomic_exchange(var aObj: Pointer; aDesired: Pointer): Pointer;
begin
  // Default is seq_cst.
  Result := atomic_exchange(aObj, aDesired, mo_seq_cst);
end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64): Boolean;
begin
  // Default is seq_cst.
  Result := atomic_compare_exchange_strong_64(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
end;

function atomic_compare_exchange_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64): Boolean;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := atomic_compare_exchange_strong_64(PInt64(@aObj)^, PInt64(@aExpected)^, PInt64(@aDesired)^, mo_seq_cst, mo_seq_cst);
  {$POP}
end;
{$ENDIF}

function atomic_compare_exchange(var aObj: Int32; var aExpected: Int32; aDesired: Int32): Boolean;
begin
  // Default is seq_cst.
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
end;

function atomic_compare_exchange(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32): Boolean;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := atomic_compare_exchange_strong(PInt32(@aObj)^, PInt32(@aExpected)^, PInt32(@aDesired)^, mo_seq_cst, mo_seq_cst);
  {$POP}
end;

{$IFDEF CPU64}
function atomic_compare_exchange(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt): Boolean;
begin
  // Default is seq_cst.
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
end;

function atomic_compare_exchange(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt): Boolean;
begin
  // Default is seq_cst.
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
end;
{$ENDIF}

function atomic_compare_exchange(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer): Boolean;
begin
  // Default is seq_cst.
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
end;

function atomic_compare_exchange_strong(var aObj: Int32; var aExpected: Int32; aDesired: Int32): Boolean;
begin
  Result := atomic_compare_exchange(aObj, aExpected, aDesired);
end;

function atomic_compare_exchange_strong(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32): Boolean;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := atomic_compare_exchange(PInt32(@aObj)^, PInt32(@aExpected)^, PInt32(@aDesired)^);
  {$POP}
end;

{$IFDEF CPU64}
function atomic_compare_exchange_strong(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt): Boolean;
begin
  Result := atomic_compare_exchange(aObj, aExpected, aDesired);
end;

function atomic_compare_exchange_strong(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt): Boolean;
begin
  Result := atomic_compare_exchange(PPtrInt(@aObj)^, PPtrInt(@aExpected)^, PPtrInt(@aDesired)^);
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_strong_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64): Boolean;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := atomic_compare_exchange_64(PInt64(@aObj)^, PInt64(@aExpected)^, PInt64(@aDesired)^);
  {$POP}
end;

function atomic_compare_exchange_strong_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64): Boolean;
begin
  Result := atomic_compare_exchange_64(aObj, aExpected, aDesired);
end;
{$ENDIF}

function atomic_compare_exchange_strong(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer): Boolean;
begin
  Result := atomic_compare_exchange(aObj, aExpected, aDesired);
end;

function atomic_compare_exchange_weak(var aObj: Int32; var aExpected: Int32; aDesired: Int32): Boolean;
begin
  Result := atomic_compare_exchange(aObj, aExpected, aDesired);
end;

function atomic_compare_exchange_weak(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32): Boolean;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := atomic_compare_exchange(PInt32(@aObj)^, PInt32(@aExpected)^, PInt32(@aDesired)^);
  {$POP}
end;

{$IFDEF CPU64}
function atomic_compare_exchange_weak(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt): Boolean;
begin
  Result := atomic_compare_exchange(aObj, aExpected, aDesired);
end;

function atomic_compare_exchange_weak(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt): Boolean;
begin
  Result := atomic_compare_exchange(PPtrInt(@aObj)^, PPtrInt(@aExpected)^, PPtrInt(@aDesired)^);
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_weak_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64): Boolean;
begin
  Result := atomic_compare_exchange_64(aObj, aExpected, aDesired);
end;

function atomic_compare_exchange_weak_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64): Boolean;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := atomic_compare_exchange_64(PInt64(@aObj)^, PInt64(@aExpected)^, PInt64(@aDesired)^);
  {$POP}
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_increment_64(var aObj: Int64): Int64;
begin
  // Convenience API: seq_cst.
  Result := atomic_fetch_add_64(aObj, 1, mo_seq_cst) + 1;
end;

function atomic_increment_64(var aObj: UInt64): UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_increment_64(PInt64(@aObj)^));
  {$POP}
end;
{$ENDIF}

function atomic_compare_exchange_weak(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer): Boolean;
begin
  Result := atomic_compare_exchange(aObj, aExpected, aDesired);
end;

// ✅ Phase 3: CAS 带双内存序参数实现
  // 说明: success_order 用于 CAS 成功时的内存序，failure_order 用于 CAS 失败时的内存序
  // x86/x86_64: LOCK CMPXCHG 是全屏障；这里在非 x86 平台才需要用显式屏障补语义。

function atomic_compare_exchange_strong(var aObj: Int32; var aExpected: Int32; aDesired: Int32;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
var
  LOld: Int32;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_orders(aSuccessOrder, aFailureOrder);
  {$ENDIF}

  // CAS is a locked RMW on x86/x86_64 and already provides a full fence.
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  // 成功路径的 release 屏障
  case aSuccessOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  else
    ; // mo_relaxed, mo_consume, mo_acquire 不需要写屏障
  end;
  {$ENDIF}

  LOld := InterlockedCompareExchange(aObj, aDesired, aExpected);
  Result := (LOld = aExpected);

  if Result then
  begin
    {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
    // 成功路径的 acquire 屏障
    case aSuccessOrder of
      mo_seq_cst:
        ReadWriteBarrier;
      mo_consume, mo_acquire, mo_acq_rel:
        ReadBarrier;
    else
      ; // mo_relaxed, mo_release 不需要读屏障
    end;
    {$ENDIF}
  end
  else
  begin
    aExpected := LOld;
    {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
    // 失败路径的 acquire 屏障
    case aFailureOrder of
      mo_seq_cst:
        ReadWriteBarrier;
      mo_consume, mo_acquire, mo_acq_rel:
        ReadBarrier;
    else
      ; // mo_relaxed, mo_release 不需要读屏障
    end;
    {$ENDIF}
  end;
end;

function atomic_compare_exchange_strong(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := atomic_compare_exchange_strong(PInt32(@aObj)^, PInt32(@aExpected)^, PInt32(@aDesired)^,
    aSuccessOrder, aFailureOrder);
  {$POP}
end;

{$IFDEF CPU64}
function atomic_compare_exchange_strong(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
var
  LOld: Int64;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_orders(aSuccessOrder, aFailureOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aSuccessOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  else
    ;
  end;
  {$ENDIF}

  // Use an explicit Int64 view to avoid var-parameter type mismatches on non-x86_64 64-bit targets.
  LOld := InterlockedCompareExchange64(PInt64(@aObj)^, Int64(aDesired), Int64(aExpected));
  Result := (LOld = Int64(aExpected));

  if Result then
  begin
    {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
    case aSuccessOrder of
      mo_seq_cst:
        ReadWriteBarrier;
      mo_consume, mo_acquire, mo_acq_rel:
        ReadBarrier;
    else
      ;
    end;
    {$ENDIF}
  end
  else
  begin
    aExpected := PtrInt(LOld);
    {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
    case aFailureOrder of
      mo_seq_cst:
        ReadWriteBarrier;
      mo_consume, mo_acquire, mo_acq_rel:
        ReadBarrier;
    else
      ;
    end;
    {$ENDIF}
  end;
end;

function atomic_compare_exchange_strong(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := atomic_compare_exchange_strong(PPtrInt(@aObj)^, PPtrInt(@aExpected)^, PPtrInt(@aDesired)^,
    aSuccessOrder, aFailureOrder);
  {$POP}
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_strong_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
{$IF NOT (DEFINED(CPUX86) AND NOT DEFINED(CPU64))}
var
  LOld: Int64;
{$ENDIF}
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_orders(aSuccessOrder, aFailureOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aSuccessOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  else
    ;
  end;
  {$ENDIF}

  {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
  if not _atomic_cmpxchg_64_x86(aObj, aExpected, aDesired) then
  begin
    Result := False;
    {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
    case aFailureOrder of
      mo_seq_cst:
        ReadWriteBarrier;
      mo_consume, mo_acquire, mo_acq_rel:
        ReadBarrier;
    else
      ;
    end;
    {$ENDIF}
    Exit;
  end;
  Result := True;
  {$ELSE}
  LOld := InterlockedCompareExchange64(aObj, aDesired, aExpected);
  Result := (LOld = aExpected);

  if not Result then
  begin
    aExpected := LOld;
    {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
    case aFailureOrder of
      mo_seq_cst:
        ReadWriteBarrier;
      mo_consume, mo_acquire, mo_acq_rel:
        ReadBarrier;
    else
      ;
    end;
    {$ENDIF}
    Exit;
  end;
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aSuccessOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  else
    ;
  end;
  {$ENDIF}
end;

function atomic_compare_exchange_strong_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := atomic_compare_exchange_strong_64(PInt64(@aObj)^, PInt64(@aExpected)^, PInt64(@aDesired)^,
    aSuccessOrder, aFailureOrder);
  {$POP}
end;
{$ENDIF}

function atomic_compare_exchange_strong(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF SIZEOF(Pointer) = 4}
  Result := atomic_compare_exchange_strong(PInt32(@aObj)^, PInt32(@aExpected)^, PInt32(@aDesired)^,
    aSuccessOrder, aFailureOrder);
  {$ELSE}
  Result := atomic_compare_exchange_strong_64(PInt64(@aObj)^, PInt64(@aExpected)^, PInt64(@aDesired)^,
    aSuccessOrder, aFailureOrder);
  {$ENDIF}
  {$POP}
end;

// weak 版本 - 在 x86 上与 strong 相同，但语义上允许虚假失败
function atomic_compare_exchange_weak(var aObj: Int32; var aExpected: Int32; aDesired: Int32;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
end;

function atomic_compare_exchange_weak(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
end;

{$IFDEF CPU64}
function atomic_compare_exchange_weak(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
end;

function atomic_compare_exchange_weak(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_weak_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong_64(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
end;

function atomic_compare_exchange_weak_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong_64(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
end;
{$ENDIF}

function atomic_compare_exchange_weak(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aSuccessOrder, aFailureOrder);
end;

// ✅ P1-002: CAS 单内存序版本实现 - 简化常见用法（成功和失败使用相同内存序）
// 说明: 这些函数调用双内存序版本，将相同的内存序用于成功和失败情况

function atomic_compare_exchange_strong(var aObj: Int32; var aExpected: Int32; aDesired: Int32;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aOrder, aOrder);
end;

function atomic_compare_exchange_strong(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aOrder, aOrder);
end;

{$IFDEF CPU64}
function atomic_compare_exchange_strong(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aOrder, aOrder);
end;

function atomic_compare_exchange_strong(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aOrder, aOrder);
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_strong_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong_64(aObj, aExpected, aDesired, aOrder, aOrder);
end;

function atomic_compare_exchange_strong_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong_64(aObj, aExpected, aDesired, aOrder, aOrder);
end;
{$ENDIF}

function atomic_compare_exchange_strong(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired, aOrder, aOrder);
end;

// weak 版本 - 单内存序
function atomic_compare_exchange_weak(var aObj: Int32; var aExpected: Int32; aDesired: Int32;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_weak(aObj, aExpected, aDesired, aOrder, aOrder);
end;

function atomic_compare_exchange_weak(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_weak(aObj, aExpected, aDesired, aOrder, aOrder);
end;

{$IFDEF CPU64}
function atomic_compare_exchange_weak(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_weak(aObj, aExpected, aDesired, aOrder, aOrder);
end;

function atomic_compare_exchange_weak(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_weak(aObj, aExpected, aDesired, aOrder, aOrder);
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_compare_exchange_weak_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_weak_64(aObj, aExpected, aDesired, aOrder, aOrder);
end;

function atomic_compare_exchange_weak_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_weak_64(aObj, aExpected, aDesired, aOrder, aOrder);
end;
{$ENDIF}

function atomic_compare_exchange_weak(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer;
  aOrder: memory_order_t): Boolean;
begin
  Result := atomic_compare_exchange_weak(aObj, aExpected, aDesired, aOrder, aOrder);
end;

function atomic_increment(var aObj: Int32): Int32;
begin
  // Convenience API: seq_cst.
  Result := atomic_fetch_add(aObj, 1, mo_seq_cst) + 1;
end;

function atomic_increment(var aObj: UInt32): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_increment(PInt32(@aObj)^));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_increment(var aObj: PtrInt): PtrInt;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_increment(PInt32(@aObj)^));
  {$ELSE}
    Result := PtrInt(atomic_increment_64(PInt64(@aObj)^));
  {$ENDIF}
  {$POP}
end;

function atomic_increment(var aObj: PtrUInt): PtrUInt;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrUInt(atomic_increment(PInt32(@aObj)^));
  {$ELSE}
    Result := PtrUInt(atomic_increment_64(PInt64(@aObj)^));
  {$ENDIF}
  {$POP}
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_decrement_64(var aObj: Int64): Int64;
begin
  // Convenience API: seq_cst.
  Result := atomic_fetch_add_64(aObj, -1, mo_seq_cst) - 1;
end;

function atomic_decrement_64(var aObj: UInt64): UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_decrement_64(PInt64(@aObj)^));
  {$POP}
end;
{$ENDIF}

function atomic_decrement(var aObj: Int32): Int32;
begin
  // Convenience API: seq_cst.
  Result := atomic_fetch_add(aObj, -1, mo_seq_cst) - 1;
end;

function atomic_decrement(var aObj: UInt32): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_decrement(PInt32(@aObj)^));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_decrement(var aObj: PtrInt): PtrInt;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_decrement(PInt32(@aObj)^));
  {$ELSE}
    Result := PtrInt(atomic_decrement_64(PInt64(@aObj)^));
  {$ENDIF}
  {$POP}
end;

function atomic_decrement(var aObj: PtrUInt): PtrUInt;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := PtrUInt(atomic_decrement(PPtrInt(@aObj)^));
  {$POP}
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_add_64(var aObj: Int64; aArg: Int64): Int64;
begin
  // Default is seq_cst.
  Result := atomic_fetch_add_64(aObj, aArg, mo_seq_cst);
end;

function atomic_fetch_add_64(var aObj: UInt64; aArg: UInt64): UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aArg)^, mo_seq_cst));
  {$POP}
end;
{$ENDIF}

function atomic_fetch_add(var aObj: Int32; aArg: Int32): Int32;
begin
  // Default is seq_cst.
  Result := atomic_fetch_add(aObj, aArg, mo_seq_cst);
end;

function atomic_fetch_add(var aObj: UInt32; aArg: UInt32): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_fetch_add(PInt32(@aObj)^, PInt32(@aArg)^, mo_seq_cst));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_fetch_add(var aObj: PtrInt; aArg: PtrInt): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_fetch_add(PInt32(@aObj)^, PInt32(@aArg)^, mo_seq_cst));
  {$ELSE}
    Result := PtrInt(atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aArg)^, mo_seq_cst));
  {$ENDIF}
end;

function atomic_fetch_add(var aObj: PtrUInt; aArg: PtrUInt): PtrUInt;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := PtrUInt(atomic_fetch_add(PPtrInt(@aObj)^, PPtrInt(@aArg)^, mo_seq_cst));
  {$POP}
end;
{$ENDIF}

function atomic_fetch_add(var aObj: Pointer; aOffset: PtrInt): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF} // Conversion between ordinals and pointers is not portable
  {$IF SIZEOF(Pointer) = 4}
    Result := Pointer(atomic_fetch_add(PInt32(@aObj)^, PInt32(@aOffset)^));
  {$ELSE}
    Result := Pointer(atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aOffset)^));
  {$ENDIF}
  {$POP}
end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_sub_64(var aObj: Int64; aArg: Int64): Int64;
begin
  Result := atomic_fetch_add_64(aObj, -aArg);
end;

function atomic_fetch_sub_64(var aObj: UInt64; aArg: UInt64): UInt64;
begin
  Result := UInt64(atomic_fetch_sub_64(PInt64(@aObj)^, PInt64(@aArg)^));
end;
{$ENDIF}

function atomic_fetch_sub(var aObj: Int32; aArg: Int32): Int32;
begin
  Result := atomic_fetch_add(aObj, -aArg);
end;

function atomic_fetch_sub(var aObj: UInt32; aArg: UInt32): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_fetch_sub(PInt32(@aObj)^, PInt32(@aArg)^));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_fetch_sub(var aObj: PtrInt; aArg: PtrInt): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_fetch_sub(PInt32(@aObj)^, PInt32(@aArg)^));
  {$ELSE}
    Result := PtrInt(atomic_fetch_sub_64(PInt64(@aObj)^, PInt64(@aArg)^));
  {$ENDIF}
end;

function atomic_fetch_sub(var aObj: PtrUInt; aArg: PtrUInt): PtrUInt;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := PtrUInt(atomic_fetch_sub(PPtrInt(@aObj)^, PPtrInt(@aArg)^));
  {$POP}
end;
{$ENDIF}

function atomic_fetch_sub(var aObj: Pointer; aOffset: PtrInt): Pointer;
begin
  Result := atomic_fetch_add(aObj, -aOffset);
end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_and_64(var aObj: Int64; aArg: Int64): Int64;
begin
  // Default is seq_cst.
  Result := atomic_fetch_and_64(aObj, aArg, mo_seq_cst);
end;

function atomic_fetch_and_64(var aObj: UInt64; aArg: UInt64): UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_fetch_and_64(PInt64(@aObj)^, PInt64(@aArg)^, mo_seq_cst));
  {$POP}
end;
{$ENDIF}

function atomic_fetch_and(var aObj: Int32; aArg: Int32): Int32;
begin
  // Keep the legacy no-order API, but route through the order-aware implementation
  // so we get consistent backoff (cpu_pause) behavior.
  Result := atomic_fetch_and(aObj, aArg, mo_seq_cst);
end;

function atomic_fetch_and(var aObj: UInt32; aArg: UInt32): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_fetch_and(PInt32(@aObj)^, PInt32(@aArg)^));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_fetch_and(var aObj: PtrInt; aArg: PtrInt): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_fetch_and(PInt32(@aObj)^, PInt32(@aArg)^));
  {$ELSE}
    Result := PtrInt(atomic_fetch_and_64(PInt64(@aObj)^, PInt64(@aArg)^));
  {$ENDIF}
end;

function atomic_fetch_and(var aObj: PtrUInt; aArg: PtrUInt): PtrUInt;
begin
  Result := PtrUInt(atomic_fetch_and(PPtrInt(@aObj)^, PtrInt(aArg)));
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_or_64(var aObj: Int64; aArg: Int64): Int64;
begin
  // Default is seq_cst.
  Result := atomic_fetch_or_64(aObj, aArg, mo_seq_cst);
end;

function atomic_fetch_or_64(var aObj: UInt64; aArg: UInt64): UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_fetch_or_64(PInt64(@aObj)^, PInt64(@aArg)^, mo_seq_cst));
  {$POP}
end;
{$ENDIF}

function atomic_fetch_or(var aObj: Int32; aArg: Int32): Int32;
begin
  Result := atomic_fetch_or(aObj, aArg, mo_seq_cst);
end;

function atomic_fetch_or(var aObj: UInt32; aArg: UInt32): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_fetch_or(PInt32(@aObj)^, PInt32(@aArg)^));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_fetch_or(var aObj: PtrInt; aArg: PtrInt): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_fetch_or(PInt32(@aObj)^, PInt32(@aArg)^));
  {$ELSE}
    Result := PtrInt(atomic_fetch_or_64(PInt64(@aObj)^, PInt64(@aArg)^));
  {$ENDIF}
end;

function atomic_fetch_or(var aObj: PtrUInt; aArg: PtrUInt): PtrUInt;
begin
  Result := PtrUInt(atomic_fetch_or(PPtrInt(@aObj)^, PtrInt(aArg)));
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_xor_64(var aObj: Int64; aArg: Int64): Int64;
begin
  // Default is seq_cst.
  Result := atomic_fetch_xor_64(aObj, aArg, mo_seq_cst);
end;

function atomic_fetch_xor_64(var aObj: UInt64; aArg: UInt64): UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_fetch_xor_64(PInt64(@aObj)^, PInt64(@aArg)^, mo_seq_cst));
  {$POP}
end;
{$ENDIF}

function atomic_fetch_xor(var aObj: Int32; aArg: Int32): Int32;
begin
  Result := atomic_fetch_xor(aObj, aArg, mo_seq_cst);
end;

function atomic_fetch_xor(var aObj: UInt32; aArg: UInt32): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_fetch_xor(PInt32(@aObj)^, PInt32(@aArg)^));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_fetch_xor(var aObj: PtrInt; aArg: PtrInt): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_fetch_xor(PInt32(@aObj)^, PInt32(@aArg)^));
  {$ELSE}
    Result := PtrInt(atomic_fetch_xor_64(PInt64(@aObj)^, PInt64(@aArg)^));
  {$ENDIF}
end;

function atomic_fetch_xor(var aObj: PtrUInt; aArg: PtrUInt): PtrUInt;
begin
  Result := PtrUInt(atomic_fetch_xor(PPtrInt(@aObj)^, PtrInt(aArg)));
end;
{$ENDIF}

//┌────────────────────────────────────────────────────────────────────────────┐
//│              Phase 3: atomic_fetch_* 带 memory_order 参数实现              │
//└────────────────────────────────────────────────────────────────────────────┘

// ✅ Phase 3: atomic_fetch_add 带 memory_order 参数
function atomic_fetch_add(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  // x86/x86_64: InterlockedExchangeAdd uses LOCK XADD and already provides a full fence.
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  else
    ;
  end;
  {$ENDIF}

  Result := InterlockedExchangeAdd(aObj, aArg);

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  else
    ;
  end;
  {$ENDIF}
end;

function atomic_fetch_add(var aObj: UInt32; aArg: UInt32; aOrder: memory_order_t): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_fetch_add(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_fetch_add(var aObj: PtrInt; aArg: PtrInt; aOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_fetch_add(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
  {$ELSE}
    Result := PtrInt(atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
  {$ENDIF}
end;

function atomic_fetch_add(var aObj: PtrUInt; aArg: PtrUInt; aOrder: memory_order_t): PtrUInt;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := PtrUInt(atomic_fetch_add(PPtrInt(@aObj)^, PPtrInt(@aArg)^, aOrder));
  {$POP}
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_add_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  // x86/x86_64: locked RMW already provides a full fence.
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  else
    ;
  end;
  {$ENDIF}

  {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
  Result := _atomic_fetch_add_64_x86(aObj, aArg);
  {$ELSE}
  Result := InterlockedExchangeAdd64(aObj, aArg);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  else
    ;
  end;
  {$ENDIF}
end;

function atomic_fetch_add_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
  {$POP}
end;
{$ENDIF}

// ✅ Phase 3: atomic_fetch_sub 带 memory_order 参数
function atomic_fetch_sub(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32;
begin
  Result := atomic_fetch_add(aObj, -aArg, aOrder);
end;

function atomic_fetch_sub(var aObj: UInt32; aArg: UInt32; aOrder: memory_order_t): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_fetch_sub(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_fetch_sub(var aObj: PtrInt; aArg: PtrInt; aOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_fetch_sub(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
  {$ELSE}
    Result := PtrInt(atomic_fetch_sub_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
  {$ENDIF}
end;

function atomic_fetch_sub(var aObj: PtrUInt; aArg: PtrUInt; aOrder: memory_order_t): PtrUInt;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := PtrUInt(atomic_fetch_sub(PPtrInt(@aObj)^, PPtrInt(@aArg)^, aOrder));
  {$POP}
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_fetch_sub_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;
begin
  Result := atomic_fetch_add_64(aObj, -aArg, aOrder);
end;

function atomic_fetch_sub_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt64(atomic_fetch_sub_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
  {$POP}
end;
{$ENDIF}

// ✅ Phase 3: atomic_fetch_and 带 memory_order 参数
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障，无需额外 barrier
function atomic_fetch_and(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32;
var
  LOld, LNew: Int32;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  else
    ;
  end;
  {$ENDIF}
  repeat
    LOld := aObj;
    LNew := LOld and aArg;
    if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
      Break;
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  else
    ;
  end;
  {$ENDIF}
end;

function atomic_fetch_and(var aObj: UInt32; aArg: UInt32; aOrder: memory_order_t): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_fetch_and(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_fetch_and(var aObj: PtrInt; aArg: PtrInt; aOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_fetch_and(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
  {$ELSE}
    Result := PtrInt(atomic_fetch_and_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
  {$ENDIF}
end;

function atomic_fetch_and(var aObj: PtrUInt; aArg: PtrUInt; aOrder: memory_order_t): PtrUInt;
begin
  Result := PtrUInt(atomic_fetch_and(PPtrInt(@aObj)^, PtrInt(aArg), aOrder));
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障
function atomic_fetch_and_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;
var
  LOld, LNew: Int64;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  end;
  {$ENDIF}
  repeat
    LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
    LNew := LOld and aArg;
    {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
    if _atomic_cmpxchg_64_x86(aObj, LOld, LNew) then
      Break;
    {$ELSE}
    if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
      Break;
    {$ENDIF}
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  end;
  {$ENDIF}
end;

function atomic_fetch_and_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64;
begin
  Result := UInt64(atomic_fetch_and_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
end;
{$ENDIF}

// ✅ Phase 3: atomic_fetch_or 带 memory_order 参数
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障
function atomic_fetch_or(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32;
var
  LOld, LNew: Int32;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  end;
  {$ENDIF}
  repeat
    LOld := aObj;
    LNew := LOld or aArg;
    if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
      Break;
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  end;
  {$ENDIF}
end;

function atomic_fetch_or(var aObj: UInt32; aArg: UInt32; aOrder: memory_order_t): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_fetch_or(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_fetch_or(var aObj: PtrInt; aArg: PtrInt; aOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_fetch_or(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
  {$ELSE}
    Result := PtrInt(atomic_fetch_or_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
  {$ENDIF}
end;

function atomic_fetch_or(var aObj: PtrUInt; aArg: PtrUInt; aOrder: memory_order_t): PtrUInt;
begin
  Result := PtrUInt(atomic_fetch_or(PPtrInt(@aObj)^, PtrInt(aArg), aOrder));
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障
function atomic_fetch_or_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;
var
  LOld, LNew: Int64;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  end;
  {$ENDIF}
  repeat
    LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
    LNew := LOld or aArg;
    {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
    if _atomic_cmpxchg_64_x86(aObj, LOld, LNew) then
      Break;
    {$ELSE}
    if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
      Break;
    {$ENDIF}
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  end;
  {$ENDIF}
end;

function atomic_fetch_or_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64;
begin
  Result := UInt64(atomic_fetch_or_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
end;
{$ENDIF}

// ✅ Phase 3: atomic_fetch_xor 带 memory_order 参数
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障
function atomic_fetch_xor(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32;
var
  LOld, LNew: Int32;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  end;
  {$ENDIF}
  repeat
    LOld := aObj;
    LNew := LOld xor aArg;
    if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
      Break;
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  end;
  {$ENDIF}
end;

function atomic_fetch_xor(var aObj: UInt32; aArg: UInt32; aOrder: memory_order_t): UInt32;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  Result := UInt32(atomic_fetch_xor(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
  {$POP}
end;

{$IFDEF CPU64}
function atomic_fetch_xor(var aObj: PtrInt; aArg: PtrInt; aOrder: memory_order_t): PtrInt;
begin
  {$IF SIZEOF(PtrInt) = 4}
    Result := PtrInt(atomic_fetch_xor(PInt32(@aObj)^, PInt32(@aArg)^, aOrder));
  {$ELSE}
    Result := PtrInt(atomic_fetch_xor_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
  {$ENDIF}
end;

function atomic_fetch_xor(var aObj: PtrUInt; aArg: PtrUInt; aOrder: memory_order_t): PtrUInt;
begin
  Result := PtrUInt(atomic_fetch_xor(PPtrInt(@aObj)^, PtrInt(aArg), aOrder));
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障
function atomic_fetch_xor_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;
var
  LOld, LNew: Int64;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  end;
  {$ENDIF}
  repeat
    LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
    LNew := LOld xor aArg;
    {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
    if _atomic_cmpxchg_64_x86(aObj, LOld, LNew) then
      Break;
    {$ELSE}
    if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
      Break;
    {$ENDIF}
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  end;
  {$ENDIF}
end;

function atomic_fetch_xor_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64;
begin
  Result := UInt64(atomic_fetch_xor_64(PInt64(@aObj)^, PInt64(@aArg)^, aOrder));
end;
{$ENDIF}

//┌────────────────────────────────────────────────────────────────────────────┐
//│              Phase 3: atomic_fetch_max / min / nand 新增操作               │
//└────────────────────────────────────────────────────────────────────────────┘

// ✅ Phase 3: atomic_fetch_max - 返回旧值，存储 max(old, arg)
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障
function atomic_fetch_max(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32;
var
  LOld, LNew: Int32;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  end;
  {$ENDIF}
  repeat
    LOld := aObj;
    if aArg > LOld then
      LNew := aArg
    else
      LNew := LOld;
    if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
      Break;
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  end;
  {$ENDIF}
end;

function atomic_fetch_max(var aObj: Int32; aArg: Int32): Int32;
begin
  Result := atomic_fetch_max(aObj, aArg, mo_seq_cst);
end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障
function atomic_fetch_max_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;
var
  LOld, LNew: Int64;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  end;
  {$ENDIF}
  repeat
    LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
    if aArg > LOld then
      LNew := aArg
    else
      LNew := LOld;
    {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
    if _atomic_cmpxchg_64_x86(aObj, LOld, LNew) then
      Break;
    {$ELSE}
    if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
      Break;
    {$ENDIF}
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  end;
  {$ENDIF}
end;

function atomic_fetch_max_64(var aObj: Int64; aArg: Int64): Int64;
begin
  Result := atomic_fetch_max_64(aObj, aArg, mo_seq_cst);
end;
{$ENDIF}

// ✅ Phase 3: atomic_fetch_min - 返回旧值，存储 min(old, arg)
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障
function atomic_fetch_min(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32;
var
  LOld, LNew: Int32;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  end;
  {$ENDIF}
  repeat
    LOld := aObj;
    if aArg < LOld then
      LNew := aArg
    else
      LNew := LOld;
    if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
      Break;
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  end;
  {$ENDIF}
end;

function atomic_fetch_min(var aObj: Int32; aArg: Int32): Int32;
begin
  Result := atomic_fetch_min(aObj, aArg, mo_seq_cst);
end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障
function atomic_fetch_min_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;
var
  LOld, LNew: Int64;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  end;
  {$ENDIF}
  repeat
    LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
    if aArg < LOld then
      LNew := aArg
    else
      LNew := LOld;
    {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
    if _atomic_cmpxchg_64_x86(aObj, LOld, LNew) then
      Break;
    {$ELSE}
    if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
      Break;
    {$ENDIF}
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  end;
  {$ENDIF}
end;

function atomic_fetch_min_64(var aObj: Int64; aArg: Int64): Int64;
begin
  Result := atomic_fetch_min_64(aObj, aArg, mo_seq_cst);
end;
{$ENDIF}

// ✅ Phase 3: atomic_fetch_nand - 返回旧值，存储 NOT(old AND arg)
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障
function atomic_fetch_nand(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32;
var
  LOld, LNew: Int32;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  end;
  {$ENDIF}
  repeat
    LOld := aObj;
    LNew := not (LOld and aArg);
    if InterlockedCompareExchange(aObj, LNew, LOld) = LOld then
      Break;
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  end;
  {$ENDIF}
end;

function atomic_fetch_nand(var aObj: Int32; aArg: Int32): Int32;
begin
  Result := atomic_fetch_nand(aObj, aArg, mo_seq_cst);
end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
// ✅ Phase 3 优化: x86 LOCK CMPXCHG 隐含全屏障
function atomic_fetch_nand_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;
var
  LOld, LNew: Int64;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  _consume_memory_order(aOrder);
  {$ENDIF}

  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_release, mo_acq_rel:
      WriteBarrier;
  end;
  {$ENDIF}
  repeat
    LOld := {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}_atomic_load_64_x86(aObj){$ELSE}aObj{$ENDIF};
    LNew := not (LOld and aArg);
    {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
    if _atomic_cmpxchg_64_x86(aObj, LOld, LNew) then
      Break;
    {$ELSE}
    if InterlockedCompareExchange64(aObj, LNew, LOld) = LOld then
      Break;
    {$ENDIF}
    cpu_pause;
  until False;
  Result := LOld;
  {$IF NOT (DEFINED(CPUX86_64) OR DEFINED(CPUX86))}
  case aOrder of
    mo_seq_cst:
      ReadWriteBarrier;
    mo_consume, mo_acquire, mo_acq_rel:
      ReadBarrier;
  end;
  {$ENDIF}
end;

function atomic_fetch_nand_64(var aObj: Int64; aArg: Int64): Int64;
begin
  Result := atomic_fetch_nand_64(aObj, aArg, mo_seq_cst);
end;
{$ENDIF}

function atomic_flag_test_and_set(var aFlag: atomic_flag_t): Boolean;
begin
  // C11 atomic_flag_test_and_set has seq_cst semantics by default.
  Result := (atomic_exchange(PInt32(@aFlag)^, 1, mo_seq_cst) <> 0);
end;

function atomic_flag_test(var aFlag: atomic_flag_t): Boolean;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUI386)}
    Result := atomic_load(PInt32(@aFlag)^, mo_relaxed) <> 0;
  {$ELSE} // ARM / ARM64 / PPC / RISC-V
    Result := atomic_load(PInt32(@aFlag)^, mo_acquire) <> 0;
  {$ENDIF}
end;

procedure atomic_flag_clear(var aFlag: atomic_flag_t);
begin
  // C11 atomic_flag_clear has seq_cst semantics by default.
  atomic_store(PInt32(@aFlag)^, 0, mo_seq_cst);
end;

function atomic_is_lock_free_32: Boolean;
begin
  {$IF DEFINED(CPUI386) OR DEFINED(CPUX86_64)
     OR DEFINED(CPUARM) OR DEFINED(CPUAARCH64)
     OR DEFINED(CPUMIPS) OR DEFINED(CPUMIPSEL)
     OR DEFINED(CPUMIPS64) OR DEFINED(CPUMIPS64EL)
     OR DEFINED(CPURISCV32) OR DEFINED(CPURISCV64)
     OR DEFINED(CPUPPC) OR DEFINED(CPUPPC64)}
    Result := True;
  {$ELSE}
    Result := False;
  {$ENDIF}

end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_is_lock_free_64: Boolean;
begin
  {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
    Result := gAtomic64HasCmpxchg8b;
  {$ELSEIF DEFINED(CPUX86_64) OR DEFINED(CPUAARCH64)
     OR DEFINED(CPUMIPS64) OR DEFINED(CPUMIPS64EL)
     OR DEFINED(CPURISCV64) OR DEFINED(CPUPPC64)}
    Result := True;
  {$ELSE}
    Result := False;
  {$ENDIF}
end;
{$ENDIF}

function atomic_is_lock_free_ptr: Boolean;
begin
  {$IF SIZEOF(Pointer) = 4}
    Result := atomic_is_lock_free_32;
  {$ELSE}
    Result := atomic_is_lock_free_64;
  {$ENDIF}
end;

function atomic_tagged_ptr(aPtr: Pointer; aTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}): atomic_tagged_ptr_t;
begin
  Result := nextpas.core.atomic.core.atomic_tagged_ptr(aPtr, aTag);
end;

function atomic_tagged_ptr_get_ptr(const aTaggedPtr: atomic_tagged_ptr_t): Pointer;
begin
  Result := nextpas.core.atomic.core.atomic_tagged_ptr_get_ptr(aTaggedPtr);
end;

function atomic_tagged_ptr_get_tag(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF};
begin
  Result := nextpas.core.atomic.core.atomic_tagged_ptr_get_tag(aTaggedPtr);
end;

function atomic_tagged_ptr_load(var aObj: atomic_tagged_ptr_t; aOrder: memory_order_t): atomic_tagged_ptr_t;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF SIZEOF(Pointer) = 4}
    PInt32(@Result)^ := atomic_load(PInt32(@aObj)^, aOrder);
  {$ELSE}
    PInt64(@Result)^ := atomic_load_64(PInt64(@aObj)^, aOrder);
  {$ENDIF}
  {$POP}
end;

function atomic_tagged_ptr_load(var aObj: atomic_tagged_ptr_t): atomic_tagged_ptr_t;
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
    Result := atomic_tagged_ptr_load(aObj, mo_relaxed);
  {$ELSE}
    Result := atomic_tagged_ptr_load(aObj, mo_acquire);
  {$ENDIF}
end;

procedure atomic_tagged_ptr_store(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t; aOrder: memory_order_t);
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF SIZEOF(Pointer) = 4}
    atomic_store(PInt32(@aObj)^, PInt32(@aDesired)^, aOrder);
  {$ELSE}
    atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder);
  {$ENDIF}
  {$POP}
end;

procedure atomic_tagged_ptr_store(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t);
begin
  {$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
    atomic_tagged_ptr_store(aObj, aDesired, mo_relaxed);
  {$ELSE}
    atomic_tagged_ptr_store(aObj, aDesired, mo_release);
  {$ENDIF}
end;

function atomic_tagged_ptr_exchange(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t; aOrder: memory_order_t): atomic_tagged_ptr_t;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF SIZEOF(Pointer) = 4}
    PInt32(@Result)^ := atomic_exchange(PInt32(@aObj)^, PInt32(@aDesired)^, aOrder);
  {$ELSE}
    PInt64(@Result)^ := atomic_exchange_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder);
  {$ENDIF}
  {$POP}
end;

function atomic_tagged_ptr_exchange(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t): atomic_tagged_ptr_t;
begin
  // Default is seq_cst.
  Result := atomic_tagged_ptr_exchange(aObj, aDesired, mo_seq_cst);
end;

function atomic_tagged_ptr_compare_exchange_strong(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
var
  {$IF SIZEOF(Pointer) = 4}
  LExpected32: Int32;
  {$ELSE}
  LExpected64: Int64;
  {$ENDIF}
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF SIZEOF(Pointer) = 4}
    LExpected32 := PInt32(@aExpected)^;
    Result := atomic_compare_exchange_strong(PInt32(@aObj)^, LExpected32, PInt32(@aDesired)^, aSuccessOrder, aFailureOrder);
    PInt32(@aExpected)^ := LExpected32;
  {$ELSE}
    LExpected64 := PInt64(@aExpected)^;
    Result := atomic_compare_exchange_strong_64(PInt64(@aObj)^, LExpected64, PInt64(@aDesired)^, aSuccessOrder, aFailureOrder);
    PInt64(@aExpected)^ := LExpected64;
  {$ENDIF}
  {$POP}
end;

function atomic_tagged_ptr_compare_exchange_strong(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t): Boolean;
begin
  // Default is seq_cst.
  Result := atomic_tagged_ptr_compare_exchange_strong(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
end;

function atomic_tagged_ptr_compare_exchange_weak(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t;
  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;
var
  {$IF SIZEOF(Pointer) = 4}
  LExpected32: Int32;
  {$ELSE}
  LExpected64: Int64;
  {$ENDIF}
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF SIZEOF(Pointer) = 4}
    LExpected32 := PInt32(@aExpected)^;
    Result := atomic_compare_exchange_weak(PInt32(@aObj)^, LExpected32, PInt32(@aDesired)^, aSuccessOrder, aFailureOrder);
    PInt32(@aExpected)^ := LExpected32;
  {$ELSE}
    LExpected64 := PInt64(@aExpected)^;
    Result := atomic_compare_exchange_weak_64(PInt64(@aObj)^, LExpected64, PInt64(@aDesired)^, aSuccessOrder, aFailureOrder);
    PInt64(@aExpected)^ := LExpected64;
  {$ENDIF}
  {$POP}
end;

function atomic_tagged_ptr_compare_exchange_weak(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t): Boolean;
begin
  // Default is seq_cst.
  Result := atomic_tagged_ptr_compare_exchange_weak(aObj, aExpected, aDesired, mo_seq_cst, mo_seq_cst);
end;

procedure atomic_thread_fence(aOrder: memory_order_t);
begin
  nextpas.core.atomic.core.atomic_thread_fence(aOrder);
end;

procedure atomic_signal_fence(aOrder: memory_order_t);
begin
  nextpas.core.atomic.core.atomic_signal_fence(aOrder);
end;

function atomic_tagged_ptr_next(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF};
begin
  Result := nextpas.core.atomic.core.atomic_tagged_ptr_next(aTaggedPtr);
end;

procedure atomic_tagged_ptr_update(var aObj: atomic_tagged_ptr_t; aPtr: Pointer); inline;
var
  LOld, LNewV: atomic_tagged_ptr_t;
begin
  repeat
    LOld  := atomic_tagged_ptr_load(aObj);
    LNewV := atomic_tagged_ptr(aPtr, atomic_tagged_ptr_next(LOld));
    if atomic_tagged_ptr_compare_exchange_weak(aObj, LOld, LNewV) then
      Break;
    cpu_pause;
  until False;
end;

procedure atomic_tagged_ptr_update_tag(var aObj: atomic_tagged_ptr_t; aTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}); inline;
var
  LOldTagged: atomic_tagged_ptr_t;
  LNewTagged: atomic_tagged_ptr_t;
  LOldPtr: Pointer;
begin
  repeat
    LOldTagged := atomic_tagged_ptr_load(aObj);
    LOldPtr    := atomic_tagged_ptr_get_ptr(LOldTagged);
    LNewTagged := atomic_tagged_ptr(LOldPtr, aTag);
    if atomic_tagged_ptr_compare_exchange_strong(aObj, LOldTagged, LNewTagged) then
      Break;
    cpu_pause;
  until False;
end;

function AtomicCompatFailureOrder(const AOrder: TMemoryOrder): TMemoryOrder; inline;
begin
  case AOrder of
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

procedure CpuPause;
begin
  cpu_pause;
end;

function AtomicLoad32(var ATarget: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := atomic_load(ATarget, AOrder);
end;

procedure AtomicStore32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder);
begin
  atomic_store(ATarget, AValue, AOrder);
end;

function AtomicExchange32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := atomic_exchange(ATarget, AValue, AOrder);
end;

function AtomicCompareExchange32(var ATarget: Int32; const AExpected, ADesired: Int32; const AOrder: TMemoryOrder): Int32;
var
  LExpected: Int32;
begin
  LExpected := AExpected;
  atomic_compare_exchange_strong(ATarget, LExpected, ADesired, AOrder, AtomicCompatFailureOrder(AOrder));
  Result := LExpected;
end;

function AtomicFetchAdd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := atomic_fetch_add(ATarget, AValue, AOrder);
end;

function AtomicFetchSub32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := atomic_fetch_sub(ATarget, AValue, AOrder);
end;

function AtomicFetchAnd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := atomic_fetch_and(ATarget, AValue, AOrder);
end;

function AtomicFetchOr32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := atomic_fetch_or(ATarget, AValue, AOrder);
end;

function AtomicFetchXor32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := atomic_fetch_xor(ATarget, AValue, AOrder);
end;

function AtomicLoad64(var ATarget: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := atomic_load_64(ATarget, AOrder);
end;

procedure AtomicStore64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder);
begin
  atomic_store_64(ATarget, AValue, AOrder);
end;

function AtomicExchange64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := atomic_exchange_64(ATarget, AValue, AOrder);
end;

function AtomicCompareExchange64(var ATarget: Int64; const AExpected, ADesired: Int64; const AOrder: TMemoryOrder): Int64;
var
  LExpected: Int64;
begin
  LExpected := AExpected;
  atomic_compare_exchange_strong_64(ATarget, LExpected, ADesired, AOrder, AtomicCompatFailureOrder(AOrder));
  Result := LExpected;
end;

function AtomicFetchAdd64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := atomic_fetch_add_64(ATarget, AValue, AOrder);
end;

function AtomicFetchSub64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := atomic_fetch_sub_64(ATarget, AValue, AOrder);
end;

function AtomicLoadPtr(var ATarget: Pointer; const AOrder: TMemoryOrder): Pointer;
begin
  Result := atomic_load(ATarget, AOrder);
end;

procedure AtomicStorePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder);
begin
  atomic_store(ATarget, AValue, AOrder);
end;

function AtomicExchangePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder): Pointer;
begin
  Result := atomic_exchange(ATarget, AValue, AOrder);
end;

function AtomicCompareExchangePtr(var ATarget: Pointer; const AExpected, ADesired: Pointer; const AOrder: TMemoryOrder): Pointer;
var
  LExpected: Pointer;
begin
  LExpected := AExpected;
  atomic_compare_exchange_strong(ATarget, LExpected, ADesired, AOrder, AtomicCompatFailureOrder(AOrder));
  Result := LExpected;
end;

procedure AtomicThreadFence(const AOrder: TMemoryOrder);
begin
  atomic_thread_fence(AOrder);
end;

procedure AtomicSignalFence(const AOrder: TMemoryOrder);
begin
  atomic_signal_fence(AOrder);
end;

{$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}
initialization
  {$IFDEF NEXTPAS_ATOMIC_FORCE_NO_CMPXCHG8B}
  gAtomic64HasCmpxchg8b := False;
  {$ELSE}
  gAtomic64HasCmpxchg8b := _x86_has_cmpxchg8b;
  {$ENDIF}
{$ENDIF}

end.
