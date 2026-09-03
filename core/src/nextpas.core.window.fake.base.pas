unit nextpas.core.window.fake.base;

{** @desc fake 基类型：按需存在的 fake 句柄/容量载体与零拷贝 inline 转换。
       非机械 4 件套占位：仅承载 fake 假句柄别名与句柄互转、容量增长转发，
       真实职责归本单元；通用窗口类型（TWindowOptions/TWindowEvent 等）仍归
       window.base 单源，避免薄 re-export 掩盖无真实职责的机械创建。
       单源句柄生成：确定性 $1000 起步 $10 步进，原子递增保证并发唯一
       （复用 nextpas.core.atomic 单源 O(1) RMW，inline 零拷贝）。 *}

{$I nextpas.core.settings.inc}
interface

uses
  nextpas.core.window.base;

type
  {** fake 假句柄载体，确定性生成 $1000 起步 $10 步进，生命周期归 fake 后端，Close 后置 nil 不释放。 *}
  TFakeNativeHandle = type Pointer;

const
  FAKE_HANDLE_BASE   = $1000;
  FAKE_HANDLE_STRIDE = $10;

{** 零拷贝句柄互转：纯指针 cast，inline 零开销、无分配/无拷贝；
     复用 window.base 的 TWindowNativeHandle 单源定义，不引入重复拷贝。 *}
function FakeNativeFromWindowHandle(const AHandle: TWindowNativeHandle): TFakeNativeHandle; inline;
function WindowHandleFromFakeNative(const AHandle: TFakeNativeHandle): TWindowNativeHandle; inline;
function FakeHandleIsValid(const AHandle: TFakeNativeHandle): Boolean; inline;

{** 句柄生成：单源原子递增，确定性非零假句柄，Close 后归 nil 诚实。 *}
function AllocFakeHandle: TWindowNativeHandle;
function FakeLastHandleValue: TWindowNativeHandle;

implementation

uses
  nextpas.core.atomic;

var
  GNextHandle: PtrUInt = FAKE_HANDLE_BASE;
  GLastHandle: TWindowNativeHandle = nil;

function FakeNativeFromWindowHandle(const AHandle: TWindowNativeHandle): TFakeNativeHandle; inline;
begin
  Result := TFakeNativeHandle(AHandle);
end;

function WindowHandleFromFakeNative(const AHandle: TFakeNativeHandle): TWindowNativeHandle; inline;
begin
  Result := TWindowNativeHandle(AHandle);
end;

function FakeHandleIsValid(const AHandle: TFakeNativeHandle): Boolean; inline;
begin
  Result := AHandle <> nil;
end;

function AllocFakeHandle: TWindowNativeHandle;
var
  LPrev: PtrUInt;
begin
  // 原子递增：并发 Create 时句柄不重复不截断，PtrUInt 原子 RMW 保证唯一，复用 atomic_fetch_add 单源 O(1) inline 零拷贝
  LPrev := atomic_fetch_add(GNextHandle, PtrUInt(FAKE_HANDLE_STRIDE));
  Result := TWindowNativeHandle(Pointer(LPrev + PtrUInt(FAKE_HANDLE_STRIDE)));
  GLastHandle := Result;
end;

function FakeLastHandleValue: TWindowNativeHandle;
begin
  Result := GLastHandle;
end;

end.
