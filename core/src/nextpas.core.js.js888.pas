unit nextpas.core.js.js888;
{** @desc 纯 Pascal 后端占位（零 FFI/零 platform.dl，恒可用，复用 pure.impl 单源模板）。 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.base, nextpas.core.js.intf, nextpas.core.js.pure.impl, nextpas.core.json;
type
  TJsJs888Runtime = class(TJsPureRuntime)
  public
    constructor Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions); overload;
    constructor Create(const AOptions: TJsRuntimeOptions); overload;
  end;
  TJsJs888Context = class(TJsPureContext)
  public
    constructor Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions); overload;
  end;
implementation
constructor TJsJs888Runtime.Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions);
begin
  inherited Create(AKind, AOptions);
end;
constructor TJsJs888Runtime.Create(const AOptions: TJsRuntimeOptions);
begin
  inherited Create(jsbkJs888, AOptions);
end;
constructor TJsJs888Context.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
begin
  inherited Create(ARuntime, AOptions, jsbkJs888);
end;
end.
