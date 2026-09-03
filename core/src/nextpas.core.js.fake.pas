unit nextpas.core.js.fake;
{**
 * @desc 假后端（纯 Pascal，零外部依赖，CI 必跑，确定性语义）。
 *       复用 pure 纯族门面单源模板（与 js888/v8/chakra 同源，经 nextpas.core.js.pure 标准门面），仅 BackendKind 注入为 jsbkFake，
 *       薄壳继承，零字段/零方法克隆，上下文能力单源（pure:runtime/context 薄聚合，Host→pure.host/Value→pure.value 解耦），
 *       转发 inline + TStringView 零拷贝 + bytes.ops 单源（经 text.view / pure.base）。
 *       资源释放幂等：Close → JsPureClose 统一清 Hosts/Heap/Global + ContextId 失效（pure.base 单源）。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.pure.base,
  nextpas.core.js.pure,
  nextpas.core.text.view,
  nextpas.core.json;

type
  TJsFakeValueRef = class(TInterfacedObject, IJsValueRef)
  private
    FValue: TJsValue;
  public
    constructor Create(const AValue: TJsValue);
    function Value: TJsValue;
  end;
  TJsFakeRuntime = class(TJsPureRuntime)
  public
    constructor Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions); overload;
    constructor Create(const AOptions: TJsRuntimeOptions); overload;
  end;
  TJsFakeContext = class(TJsPureContext)
  public
    constructor Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions); overload;
  end;

implementation

constructor TJsFakeValueRef.Create(const AValue: TJsValue);
begin
  inherited Create;
  FValue := AValue;
end;

function TJsFakeValueRef.Value: TJsValue;
begin
  Result := FValue;
end;

constructor TJsFakeRuntime.Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions);
begin
  inherited Create(AKind, AOptions);
end;

constructor TJsFakeRuntime.Create(const AOptions: TJsRuntimeOptions);
begin
  inherited Create(jsbkFake, AOptions);
end;

constructor TJsFakeContext.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
begin
  inherited Create(ARuntime, AOptions, jsbkFake);
end;

end.
