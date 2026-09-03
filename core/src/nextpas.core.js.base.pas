unit nextpas.core.js.base;
{**
 * @desc JS 基础类型与错误族（L2 base，后端无关）。
 * @note S1 仅 jsbkQuickJs/jsbkFake，后续尾部追加 jsbkJs888/jsbkV8。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception;

type
  TJsBackendKind = (jsbkQuickJs, jsbkFake, jsbkJs888, jsbkV8, jsbkChakra);
  TJsValueKind = (jskUndefined, jskNull, jskBoolean, jskNumber, jskString,
    jskObject, jskArray, jskFunction, jskError, jskPromise, jskSymbol, jskBigInt, jskInteger);
  TJsErrorCategory = (jecSyntax, jecReference, jecType, jecRange, jecMemory,
    jecTimeout, jecNotSupported, jecUnknown);

const
  JS_INTERRUPT_SAMPLE_DEFAULT = 1024; // 2^10, 684ns 基线 15-30%→惰性, 可配权衡及时性/开销
  JS_INTERRUPT_SAMPLE_MIN = 1;
  JS_INTERRUPT_SAMPLE_MAX = 65536;

type
  TJsRuntimeOptions = record
  private
    FMemoryLimit: SizeUInt;
    FTimeoutMs: Integer;
    FInterruptSampleInterval: Cardinal;
  public
    property MemoryLimit: SizeUInt read FMemoryLimit write FMemoryLimit;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
    property InterruptSampleInterval: Cardinal read FInterruptSampleInterval write FInterruptSampleInterval;
    class function Default: TJsRuntimeOptions; static; inline;
    class function WithMemoryLimit(ALimit: SizeUInt): TJsRuntimeOptions; static; inline;
    class function WithTimeout(ATimeoutMs: Integer): TJsRuntimeOptions; static; inline;
    class function WithInterruptSampleInterval(AInterval: Cardinal): TJsRuntimeOptions; static; inline;
  end;

function JsInterruptSampleIntervalNormalized(AInterval: Cardinal): Cardinal; inline;

type
  EJsError = class(ENextPasError)
  private
    FJsCategory: TJsErrorCategory;
    FSpecies: string;
    FJsStack: string;
    FBackend: TJsBackendKind;
  public
    constructor Create(const AMessage: string; ACategory: TJsErrorCategory;
      const ASpecies, AStack: string; ABackend: TJsBackendKind); overload;
    property Category: TJsErrorCategory read FJsCategory;
    property Species: string read FSpecies;
    property JsStack: string read FJsStack;
    property Backend: TJsBackendKind read FBackend;
  end;

  EJsBackendUnavailable = class(EJsError);
  EJsTimeout = class(EJsError);
  EJsMemoryLimit = class(EJsError);

function JsBackendKindToString(AKind: TJsBackendKind): string; inline;
function JsErrorCategoryToString(ACat: TJsErrorCategory): string; inline;
function JsValueKindToString(AKind: TJsValueKind): string; inline;
function JsTrimEquals(const S, Lit: string): Boolean;
procedure CheckJsRuntimeOptions(const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind);

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.mem.base;

class function TJsRuntimeOptions.Default: TJsRuntimeOptions;
begin
  Result.FMemoryLimit := 0;
  Result.FTimeoutMs := 0;
  Result.FInterruptSampleInterval := JS_INTERRUPT_SAMPLE_DEFAULT;
end;

class function TJsRuntimeOptions.WithMemoryLimit(ALimit: SizeUInt): TJsRuntimeOptions;
begin
  Result := Default;
  Result.FMemoryLimit := ALimit;
end;

class function TJsRuntimeOptions.WithTimeout(ATimeoutMs: Integer): TJsRuntimeOptions;
begin
  Result := Default;
  Result.FTimeoutMs := ATimeoutMs;
end;

class function TJsRuntimeOptions.WithInterruptSampleInterval(AInterval: Cardinal): TJsRuntimeOptions; inline;
begin
  Result := Default;
  Result.FInterruptSampleInterval := JsInterruptSampleIntervalNormalized(AInterval);
end;

function JsInterruptSampleIntervalNormalized(AInterval: Cardinal): Cardinal; inline;
var LNext: SizeUInt;
begin
  // perf: inline branch + pow2 roundup via mem.base single source IsPowerOfTwo/NextPowerOfTwo, zero alloc, bytes.ops single source, always pow2 for and-mask fast path, inline zero-copy
  if AInterval = 0 then Exit(JS_INTERRUPT_SAMPLE_DEFAULT);
  if AInterval < JS_INTERRUPT_SAMPLE_MIN then Exit(JS_INTERRUPT_SAMPLE_MIN);
  if AInterval > JS_INTERRUPT_SAMPLE_MAX then Exit(JS_INTERRUPT_SAMPLE_MAX);
  Result := AInterval;
  if not IsPowerOfTwo(Result) then
  begin
    LNext := NextPowerOfTwo(Result);
    if (LNext = 0) or (LNext > JS_INTERRUPT_SAMPLE_MAX) then
      Result := JS_INTERRUPT_SAMPLE_MAX
    else
      Result := Cardinal(LNext);
  end;
end;

constructor EJsError.Create(const AMessage: string; ACategory: TJsErrorCategory;
  const ASpecies, AStack: string; ABackend: TJsBackendKind);
begin
  inherited Create(AMessage);
  FJsCategory := ACategory;
  FSpecies := ASpecies;
  FJsStack := AStack;
  FBackend := ABackend;
end;

function JsBackendKindToString(AKind: TJsBackendKind): string;
begin
  Result := 'unknown';
  case AKind of
    jsbkQuickJs: Result := 'jsbkQuickJs';
    jsbkFake: Result := 'jsbkFake';
    jsbkJs888: Result := 'jsbkJs888';
    jsbkV8: Result := 'jsbkV8';
    jsbkChakra: Result := 'jsbkChakra';
  end;
end;

function JsErrorCategoryToString(ACat: TJsErrorCategory): string;
begin
  Result := 'jecUnknown';
  case ACat of
    jecSyntax: Result := 'jecSyntax';
    jecReference: Result := 'jecReference';
    jecType: Result := 'jecType';
    jecRange: Result := 'jecRange';
    jecMemory: Result := 'jecMemory';
    jecTimeout: Result := 'jecTimeout';
    jecNotSupported: Result := 'jecNotSupported';
    jecUnknown: Result := 'jecUnknown';
  end;
end;

function JsValueKindToString(AKind: TJsValueKind): string;
begin
  Result := 'unknown';
  case AKind of
    jskUndefined: Result := 'jskUndefined';
    jskNull: Result := 'jskNull';
    jskBoolean: Result := 'jskBoolean';
    jskNumber: Result := 'jskNumber';
    jskString: Result := 'jskString';
    jskObject: Result := 'jskObject';
    jskArray: Result := 'jskArray';
    jskFunction: Result := 'jskFunction';
    jskError: Result := 'jskError';
    jskPromise: Result := 'jskPromise';
    jskSymbol: Result := 'jskSymbol';
    jskBigInt: Result := 'jskBigInt';
    jskInteger: Result := 'jskInteger';
  end;
end;

function JsTrimEquals(const S, Lit: string): Boolean;
begin
  // single source: bytes.ops.StringTrimEquals — zero-copy TByteSpan view via SpanTrim (owner bytes.ops) + SpanEqual SIMD, no heap alloc; perf: thin-forward via owner, loop not inline per design-conventions §2 red-line 2, zero-copy view no alloc, O(n) single pass
  Result := StringTrimEquals(S, Lit);
end;

procedure CheckJsRuntimeOptions(const AOptions: TJsRuntimeOptions; ABackend: TJsBackendKind);
begin
  // perf: thin check, zero alloc, single branch; stability: backend attribution via ABackend (no default, caller must pass real jsbkQuickJs/jsbkV8/jsbkFake explicitly to preserve diagnostic ownership), fail-closed without resource
  if AOptions.TimeoutMs < 0 then
    raise EJsError.Create('TimeoutMs must be >= 0', jecUnknown, 'Error', '', ABackend);
  if AOptions.InterruptSampleInterval > JS_INTERRUPT_SAMPLE_MAX then
    raise EJsError.Create('InterruptSampleInterval must be <= 65536', jecUnknown, 'Error', '', ABackend);
end;

end.
