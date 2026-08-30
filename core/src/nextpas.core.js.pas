unit nextpas.core.js;
{** @desc JS 门面：re-export + 工厂（零摩擦可插拔）。 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.base, nextpas.core.js.intf, nextpas.core.js.fake, nextpas.core.js.js888,
  nextpas.core.json, nextpas.core.js.quickjs.loader, nextpas.core.js.quickjs;
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
function CreateJsRuntime(AKind: TJsBackendKind = jsbkFake): IJsRuntime; overload;
function CreateJsRuntime(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime; overload;
function JsBackendAvailable(AKind: TJsBackendKind): Boolean;
function DefaultJsRuntimeOptions: TJsRuntimeOptions; inline;
const jsbkQuickJs = nextpas.core.js.base.jsbkQuickJs;
  jsbkFake = nextpas.core.js.base.jsbkFake;
  jsbkJs888 = nextpas.core.js.base.jsbkJs888;
  jsbkV8 = nextpas.core.js.base.jsbkV8;
  jsbkChakra = nextpas.core.js.base.jsbkChakra;
implementation
function DefaultJsRuntimeOptions: TJsRuntimeOptions; begin Result := TJsRuntimeOptions.Default; end;
function JsBackendAvailable(AKind: TJsBackendKind): Boolean;
begin case AKind of jsbkFake, jsbkJs888: Result := True; jsbkQuickJs: Result := JsQuickJsIsAvailable; jsbkV8, jsbkChakra: Result := False; else Result := False; end; end;
function CreateJsRuntime(AKind: TJsBackendKind): IJsRuntime;
begin Result := CreateJsRuntime(AKind, DefaultJsRuntimeOptions); end;
function CreateJsRuntime(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime;
begin
  CheckJsRuntimeOptions(AOptions);
  case AKind of
    jsbkFake: Result := TJsFakeRuntime.Create(jsbkFake, AOptions);
    jsbkJs888: Result := TJsJs888Runtime.Create(AOptions);
    jsbkQuickJs:
      begin
        if not JsQuickJsIsAvailable then
          raise EJsBackendUnavailable.Create('QuickJS not available (probe: '+JsQuickJsProbeNames+')', jecUnknown, 'Error', '', jsbkQuickJs);
        if not JsQuickJsLoad then
          raise EJsBackendUnavailable.Create('QuickJS load failed', jecUnknown, 'Error', '', jsbkQuickJs);
        Result := TJsQuickJsRuntime.Create(AOptions);
      end;
  else raise EJsError.Create('Unsupported backend', jecNotSupported, 'Error', '', AKind); end;
end;
end.
