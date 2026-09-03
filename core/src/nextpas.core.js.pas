unit nextpas.core.js;
{** @desc JS 门面：纯 re-export。 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.factory;
type
  TJsBackendKind = nextpas.core.js.base.TJsBackendKind;
  TJsValueKind = nextpas.core.js.base.TJsValueKind;
  TJsErrorCategory = nextpas.core.js.base.TJsErrorCategory;
  TJsRuntimeOptions = nextpas.core.js.base.TJsRuntimeOptions;
  TJsValue = nextpas.core.js.intf.TJsValue;
  IJsRuntime = nextpas.core.js.intf.IJsRuntime;
  IJsContext = nextpas.core.js.intf.IJsContext;
  IJsValueRef = nextpas.core.js.intf.IJsValueRef;
  TJsHostFunction = nextpas.core.js.intf.TJsHostFunction;
  TJsHostMethod = nextpas.core.js.intf.TJsHostMethod;
  TJsHostProc = nextpas.core.js.intf.TJsHostProc;
  EJsError = nextpas.core.js.base.EJsError;
  EJsBackendUnavailable = nextpas.core.js.base.EJsBackendUnavailable;
  EJsTimeout = nextpas.core.js.base.EJsTimeout;
  EJsMemoryLimit = nextpas.core.js.base.EJsMemoryLimit;
function CreateJsRuntime(AKind: TJsBackendKind = jsbkFake): IJsRuntime; overload; inline;
function CreateJsRuntime(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime; overload; inline;
function JsBackendAvailable(AKind: TJsBackendKind): Boolean; inline;
function DefaultJsRuntimeOptions: TJsRuntimeOptions; inline;
const
  jsbkQuickJs = nextpas.core.js.base.jsbkQuickJs;
  jsbkFake = nextpas.core.js.base.jsbkFake;
  jsbkJs888 = nextpas.core.js.base.jsbkJs888;
  jsbkV8 = nextpas.core.js.base.jsbkV8;
  jsbkChakra = nextpas.core.js.base.jsbkChakra;
implementation
function CreateJsRuntime(AKind: TJsBackendKind): IJsRuntime; inline;
begin
  Result := nextpas.core.js.factory.CreateJsRuntime(AKind);
end;
function CreateJsRuntime(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime; inline;
begin
  Result := nextpas.core.js.factory.CreateJsRuntime(AKind, AOptions);
end;
function JsBackendAvailable(AKind: TJsBackendKind): Boolean; inline;
begin
  Result := nextpas.core.js.factory.JsBackendAvailable(AKind);
end;
function DefaultJsRuntimeOptions: TJsRuntimeOptions; inline;
begin
  Result := nextpas.core.js.factory.DefaultJsRuntimeOptions;
end;
end.
