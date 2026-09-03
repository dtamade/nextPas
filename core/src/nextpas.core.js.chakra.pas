unit nextpas.core.js.chakra;
{** @desc 纯 Pascal 后端占位（零 FFI/零 platform.dl，恒可用，复用 pure 标准门面单源模板 via nextpas.core.js.pure）。 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.base, nextpas.core.js.intf, nextpas.core.js.pure, nextpas.core.json;
type
  TJsChakraRuntime = class(TJsPureRuntime)
  public
    constructor Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions); overload;
    constructor Create(const AOptions: TJsRuntimeOptions); overload;
  end;
  TJsChakraContext = class(TJsPureContext)
  public
    constructor Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions); overload;
  end;
implementation
constructor TJsChakraRuntime.Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions);
begin
  inherited Create(AKind, AOptions);
end;
constructor TJsChakraRuntime.Create(const AOptions: TJsRuntimeOptions);
begin
  inherited Create(jsbkChakra, AOptions);
end;
constructor TJsChakraContext.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
begin
  inherited Create(ARuntime, AOptions, jsbkChakra);
end;
end.
