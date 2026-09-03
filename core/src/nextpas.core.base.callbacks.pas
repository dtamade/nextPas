unit nextpas.core.base.callbacks;

{** @desc L0 通用回调适配器（method/proc → reference 单源）。

       目的：消除 window / webview / async 等家族对三形态归一包装的重复拷贝。
       单源收敛思想同 bytes.ops / text.view：inline 薄转发、零拷贝闭包，
       reference 闭包由编译器在调用点按需分配，无额外堆分配。

       分层：L0 base 家族实现子模块，仅依赖 base 的泛型回调类型（L0），
       L2 window / L3 webview 单向依赖本单元（L0-L3 单向），不触后端/bridge。

       性能：所有函数 inline，零额外调用，保持 hot path I-Cache 友好；
       闭包捕获仅方法/过程指针，Move 零拷贝，inline 后无残留调用。

       稳定性：纯转发，无所有权接管；Finalize 由编译器管理，资源释放不丢；
       不引入异常路径，失败安全。 *

       可抽模块候选落地：原 webview.callbacks 与 window.intf 同构重复
       已收敛至此 L0 单源（CONTRACT §1.2 callbacks 行），跨家族复用经
       此 Owner 单源审计，守 L0→L1→L2→L3 单向。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ 参零：reference to procedure 单源 }
type
  TCallbackNotifyMethod = procedure of object;
  TCallbackNotifyProc = procedure;
  generic TCallbackEventMethod<T> = procedure(const A: T) of object;
  generic TCallbackEventProc<T> = procedure(const A: T);

function CallbackNotifyMethodToRef(AMethod: TCallbackNotifyMethod): TProc; inline;
function CallbackNotifyProcToRef(AProc: TCallbackNotifyProc): TProc; inline;

{ 参一 const T：事件 record 零拷贝单源（TWindowEvent / TWebviewNavigationEvent 等） }
generic function CallbackEventMethodToRef<T>(AMethod: specialize TCallbackEventMethod<T>): specialize TProc1<T>; inline;
generic function CallbackEventProcToRef<T>(AProc: specialize TCallbackEventProc<T>): specialize TProc1<T>; inline;

{ Double 值参：scale 单源（webview scale 专用，Double 为内建类型，L0 可承载） }
type
  TCallbackScaleHandler = reference to procedure(AValue: Double);
  TCallbackScaleMethod = procedure(AValue: Double) of object;
  TCallbackScaleProc = procedure(AValue: Double);

function CallbackScaleMethodToRef(AMethod: TCallbackScaleMethod): TCallbackScaleHandler; inline;
function CallbackScaleProcToRef(AProc: TCallbackScaleProc): TCallbackScaleHandler; inline;

implementation

function CallbackNotifyMethodToRef(AMethod: TCallbackNotifyMethod): TProc; inline;
begin
  Result := procedure begin AMethod(); end;
end;

function CallbackNotifyProcToRef(AProc: TCallbackNotifyProc): TProc; inline;
begin
  Result := procedure begin AProc(); end;
end;

generic function CallbackEventMethodToRef<T>(AMethod: specialize TCallbackEventMethod<T>): specialize TProc1<T>; inline;
begin
  Result := procedure(const A: T) begin AMethod(A); end;
end;

generic function CallbackEventProcToRef<T>(AProc: specialize TCallbackEventProc<T>): specialize TProc1<T>; inline;
begin
  Result := procedure(const A: T) begin AProc(A); end;
end;

function CallbackScaleMethodToRef(AMethod: TCallbackScaleMethod): TCallbackScaleHandler; inline;
begin
  Result := procedure(AValue: Double) begin AMethod(AValue); end;
end;

function CallbackScaleProcToRef(AProc: TCallbackScaleProc): TCallbackScaleHandler; inline;
begin
  Result := procedure(AValue: Double) begin AProc(AValue); end;
end;

end.
