unit nextpas.core.js.pure.runtime;
{**
 * @desc 纯族 Runtime 单职责子模块（四职责拆分 Runtime 侧，门面纯 re-export 见 pure.impl）。
 *       仅含 Factory→Runtime→NewContext 生命周期，零 Host/Value/IO 聚合，
 *       薄转发 inline + bytes.ops 单源（经 text.view 复用），资源幂等不丢。
 *       守 L0-L3（仅依赖 js.base/js.intf + pure.context via implementation 单向），wc -l ~45 <800。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf;
type
  { TJsPureRuntime — Runtime lifecycle (Factory→Runtime→NewContext), 单职责 <50 行, inline 零拷贝 via bytes.ops 单源 }
  TJsPureRuntime = class(TInterfacedObject, IJsRuntime)
  private
    FKind: TJsBackendKind;
    FOptions: TJsRuntimeOptions;
  public
    constructor Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions); overload;
    function Kind: TJsBackendKind; inline;
    function Options: TJsRuntimeOptions; inline;
    function NewContext: IJsContext;
    procedure SetMemoryLimit(ALimit: SizeUInt);
    procedure SetTimeout(ATimeoutMs: Integer);
    procedure SetInterruptSampleInterval(AInterval: Cardinal);
    procedure CollectGarbage;
  end;

implementation
uses
  nextpas.core.js.pure.context;

constructor TJsPureRuntime.Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions);
begin
  inherited Create;
  FKind := AKind;
  FOptions := AOptions;
  FOptions.InterruptSampleInterval := JsInterruptSampleIntervalNormalized(FOptions.InterruptSampleInterval);
  CheckJsRuntimeOptions(FOptions, AKind);
end;

function TJsPureRuntime.Kind: TJsBackendKind; inline;
begin
  Result := FKind;
end;

function TJsPureRuntime.Options: TJsRuntimeOptions; inline;
begin
  Result := FOptions;
end;

function TJsPureRuntime.NewContext: IJsContext;
begin
  Result := TJsPureContext.Create(Self, FOptions, FKind);
end;

procedure TJsPureRuntime.SetMemoryLimit(ALimit: SizeUInt);
begin
  FOptions.MemoryLimit := ALimit;
end;

procedure TJsPureRuntime.SetTimeout(ATimeoutMs: Integer);
begin
  if ATimeoutMs < 0 then
    raise EJsError.Create('TimeoutMs must be >= 0', jecUnknown, 'Error', '', FKind);
  FOptions.TimeoutMs := ATimeoutMs;
end;

procedure TJsPureRuntime.SetInterruptSampleInterval(AInterval: Cardinal);
begin
  // perf: inline normalized via base single source, zero alloc, 1逐次↔65536稀疏, 1024默认惰性, timely vs overhead tunable, owner base
  FOptions.InterruptSampleInterval := JsInterruptSampleIntervalNormalized(AInterval);
end;

procedure TJsPureRuntime.CollectGarbage;
begin
end;

end.
