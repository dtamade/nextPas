unit nextpas.core.js.factory;
{** @desc JS 工厂：分支与探测（门面零逻辑，薄转发豁免收敛）。
     承载 CreateJsRuntime / JsBackendAvailable / DefaultJsRuntimeOptions 分支与探测抛异常，
     门面仅 inline 薄转发，守四件套 base←intf←实现←门面 与 L0-L3。
     复用 bytes.ops 单源（经 js.pure.base/pure.impl 几何扩容与 text.view 零拷贝），
     热点薄转发 inline + Move 零拷贝（门面侧），资源释放不丢（pure.base JsPureClose / quickjs Free 不丢，构造失败 exactly-once 抛 EJsBackendUnavailable）。 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf;
function CreateJsRuntime(AKind: TJsBackendKind = jsbkFake): IJsRuntime; overload;
function CreateJsRuntime(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime; overload;
function JsBackendAvailable(AKind: TJsBackendKind): Boolean;
function DefaultJsRuntimeOptions: TJsRuntimeOptions; inline;
implementation
uses
  nextpas.core.js.fake,
  nextpas.core.js.js888,
  nextpas.core.js.v8,
  nextpas.core.js.chakra,
  nextpas.core.js.quickjs.loader,
  nextpas.core.js.quickjs;
function DefaultJsRuntimeOptions: TJsRuntimeOptions; inline;
begin
  // perf: inline thin-forward to TJsRuntimeOptions.Default, zero-copy record return, no heap alloc
  Result := TJsRuntimeOptions.Default;
end;
function JsBackendAvailable(AKind: TJsBackendKind): Boolean;
begin
  // L2→L2 单缝 json 仅经 intf types, 本单元零 json 直接依赖；探测幂等缓存（loader 单源）
  case AKind of
    jsbkFake, jsbkJs888, jsbkV8, jsbkChakra: Result := True;
    jsbkQuickJs: Result := JsQuickJsIsAvailable;
  else
    Result := False;
  end;
end;
function CreateJsRuntime(AKind: TJsBackendKind): IJsRuntime;
begin
  // perf: thin-forward via factory single source, inline at facade, no extra alloc
  Result := CreateJsRuntime(AKind, DefaultJsRuntimeOptions);
end;
function CreateJsRuntime(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions): IJsRuntime;
begin
  // stability: CheckJsRuntimeOptions 先验负 Timeout, 失败抛 EJsError fail-closed, 无资源泄漏
  CheckJsRuntimeOptions(AOptions);
  case AKind of
    jsbkFake: Result := TJsFakeRuntime.Create(jsbkFake, AOptions);
    jsbkJs888: Result := TJsJs888Runtime.Create(AOptions);
    jsbkV8: Result := TJsV8Runtime.Create(AOptions);
    jsbkChakra: Result := TJsChakraRuntime.Create(AOptions);
    jsbkQuickJs:
      begin
        // 探测抛异常单源：先 probenames 透传，再 load，双重 exactly-once，不丢探测名表
        if not JsQuickJsIsAvailable then
          raise EJsBackendUnavailable.Create('QuickJS not available (probe: ' + JsQuickJsProbeNames + ')', jecUnknown, 'Error', '', jsbkQuickJs);
        if not JsQuickJsLoad then
          raise EJsBackendUnavailable.Create('QuickJS load failed', jecUnknown, 'Error', '', jsbkQuickJs);
        Result := TJsQuickJsRuntime.Create(AOptions);
      end;
  else
    raise EJsError.Create('Unsupported backend', jecNotSupported, 'Error', '', AKind);
  end;
end;
end.
