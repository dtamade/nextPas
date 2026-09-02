unit nextpas.core.js.quickjs.ffi;
{**
 * @desc QuickJS C ABI 声明（cdecl 函数指针类型，无逻辑）。
 * @note 仅类型与指针，实际装载由 loader 经 platform.dl 完成。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  PJSRuntime = Pointer;
  PJSContext = Pointer;

  { 16B JSValue（QuickJS NaN-boxing，透传不解析） }
  TJSQjsValue = record
    Data: array[0..1] of QWord;
  end;
  PJSQjsValue = ^TJSQjsValue;

  TJSInterruptHandler = function(RT: PJSRuntime; Opaque: Pointer): Integer; cdecl;

  TJS_NewRuntime = function: PJSRuntime; cdecl;
  TJS_FreeRuntime = procedure(RT: PJSRuntime); cdecl;
  TJS_NewContext = function(RT: PJSRuntime): PJSContext; cdecl;
  TJS_FreeContext = procedure(Ctx: PJSContext); cdecl;
  TJS_Eval = function(Ctx: PJSContext; Input: PAnsiChar; Len: SizeUInt; FileName: PAnsiChar; Flags: Integer): TJSQjsValue; cdecl;
  TJS_GetGlobalObject = function(Ctx: PJSContext): TJSQjsValue; cdecl;
  TJS_FreeValue = procedure(Ctx: PJSContext; Val: TJSQjsValue); cdecl;
  TJS_DupValue = function(Ctx: PJSContext; Val: TJSQjsValue): TJSQjsValue; cdecl;
  TJS_ToCString = function(Ctx: PJSContext; Val: TJSQjsValue): PAnsiChar; cdecl;
  TJS_FreeCString = procedure(Ctx: PJSContext; Str: PAnsiChar); cdecl;
  TJS_IsException = function(Val: TJSQjsValue): Integer; cdecl;
  TJS_GetException = function(Ctx: PJSContext): TJSQjsValue; cdecl;
  TJS_NewString = function(Ctx: PJSContext; Str: PAnsiChar): TJSQjsValue; cdecl;
  TJS_NewInt64 = function(Ctx: PJSContext; Val: Int64): TJSQjsValue; cdecl;
  TJS_NewFloat64 = function(Ctx: PJSContext; Val: Double): TJSQjsValue; cdecl;
  TJS_NewBool = function(Ctx: PJSContext; Val: Integer): TJSQjsValue; cdecl;
  TJS_NewObject = function(Ctx: PJSContext): TJSQjsValue; cdecl;
  TJS_NewArray = function(Ctx: PJSContext): TJSQjsValue; cdecl;
  TJS_SetPropertyStr = function(Ctx: PJSContext; This: TJSQjsValue; Prop: PAnsiChar; Val: TJSQjsValue): Integer; cdecl;
  TJS_GetPropertyStr = function(Ctx: PJSContext; This: TJSQjsValue; Prop: PAnsiChar): TJSQjsValue; cdecl;
  TJS_SetMemoryLimit = procedure(RT: PJSRuntime; Limit: SizeUInt); cdecl;
  TJS_SetGCThreshold = procedure(RT: PJSRuntime; Threshold: SizeUInt); cdecl;
  TJS_RunGC = procedure(RT: PJSRuntime); cdecl;
  TJS_SetInterruptHandler = procedure(RT: PJSRuntime; Handler: TJSInterruptHandler; Opaque: Pointer); cdecl;
  TJS_NewCFunction = function(Ctx: PJSContext; Func: Pointer; Name: PAnsiChar; Length: Integer): TJSQjsValue; cdecl;
  TJS_Call = function(Ctx: PJSContext; FuncObj: TJSQjsValue; ThisVal: TJSQjsValue; Argc: Integer; Argv: PJSQjsValue): TJSQjsValue; cdecl;
  TJSPropertyEnum = record atom: UInt32; is_enumerable: Integer; end;
  PJSPropertyEnum = ^TJSPropertyEnum;
  TJS_GetOwnPropertyNames = function(Ctx: PJSContext; plen: PUInt32; obj: TJSQjsValue; flags: Integer): PJSPropertyEnum; cdecl;
  TJS_FreePropertyEnum = procedure(Ctx: PJSContext; tab: PJSPropertyEnum; len: UInt32); cdecl;
  TJS_AtomToString = function(Ctx: PJSContext; atom: UInt32): TJSQjsValue; cdecl;
  TJS_FreeAtom = procedure(Ctx: PJSContext; atom: UInt32); cdecl;

const
  JS_EVAL_TYPE_GLOBAL = 0;
  JS_EVAL_FLAG_STRICT = 1 shl 3;
  JS_GPN_STRING_MASK = 1 shl 0;
  JS_GPN_SYMBOL_MASK = 1 shl 1;
  JS_GPN_PRIVATE_MASK = 1 shl 2;

var
  JS_NewRuntimePtr: TJS_NewRuntime = nil;
  JS_FreeRuntimePtr: TJS_FreeRuntime = nil;
  JS_NewContextPtr: TJS_NewContext = nil;
  JS_FreeContextPtr: TJS_FreeContext = nil;
  JS_EvalPtr: TJS_Eval = nil;
  JS_GetGlobalObjectPtr: TJS_GetGlobalObject = nil;
  JS_FreeValuePtr: TJS_FreeValue = nil;
  JS_DupValuePtr: TJS_DupValue = nil;
  JS_ToCStringPtr: TJS_ToCString = nil;
  JS_FreeCStringPtr: TJS_FreeCString = nil;
  JS_IsExceptionPtr: TJS_IsException = nil;
  JS_GetExceptionPtr: TJS_GetException = nil;
  JS_NewStringPtr: TJS_NewString = nil;
  JS_NewInt64Ptr: TJS_NewInt64 = nil;
  JS_NewFloat64Ptr: TJS_NewFloat64 = nil;
  JS_NewBoolPtr: TJS_NewBool = nil;
  JS_NewObjectPtr: TJS_NewObject = nil;
  JS_NewArrayPtr: TJS_NewArray = nil;
  JS_SetPropertyStrPtr: TJS_SetPropertyStr = nil;
  JS_GetPropertyStrPtr: TJS_GetPropertyStr = nil;
  JS_SetMemoryLimitPtr: TJS_SetMemoryLimit = nil;
  JS_SetGCThresholdPtr: TJS_SetGCThreshold = nil;
  JS_RunGCPtr: TJS_RunGC = nil;
  JS_SetInterruptHandlerPtr: TJS_SetInterruptHandler = nil;
  JS_NewCFunctionPtr: TJS_NewCFunction = nil;
  JS_CallPtr: TJS_Call = nil;
  JS_GetOwnPropertyNamesPtr: TJS_GetOwnPropertyNames = nil;
  JS_FreePropertyEnumPtr: TJS_FreePropertyEnum = nil;
  JS_AtomToStringPtr: TJS_AtomToString = nil;
  JS_FreeAtomPtr: TJS_FreeAtom = nil;

implementation

end.
