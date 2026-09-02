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
    jskObject, jskArray, jskFunction, jskError, jskPromise, jskSymbol, jskBigInt);
  TJsErrorCategory = (jecSyntax, jecReference, jecType, jecRange, jecMemory,
    jecTimeout, jecNotSupported, jecUnknown);

  TJsRuntimeOptions = record
  private
    FMemoryLimit: SizeUInt;
    FTimeoutMs: Integer;
  public
    property MemoryLimit: SizeUInt read FMemoryLimit write FMemoryLimit;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
    class function Default: TJsRuntimeOptions; static; inline;
    class function WithMemoryLimit(ALimit: SizeUInt): TJsRuntimeOptions; static; inline;
    class function WithTimeout(ATimeoutMs: Integer): TJsRuntimeOptions; static; inline;
  end;

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
procedure CheckJsRuntimeOptions(const AOptions: TJsRuntimeOptions);

implementation

class function TJsRuntimeOptions.Default: TJsRuntimeOptions;
begin
  Result.FMemoryLimit := 0;
  Result.FTimeoutMs := 0;
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
  end;
end;

function JsTrimEquals(const S, Lit: string): Boolean;
var
  L, R, LTrimLen, LLitLen, I: SizeInt;
begin
  // L0 purity: no text.view (L1) dependency, CONTRACT §1 js.base only exception/errors/base; perf: zero-copy single-scan trim+compare, no heap alloc, loop not inline per red-line 2
  L := 1;
  R := Length(S);
  while (L <= R) and (S[L] in [#9, #10, #13, ' ']) do
    Inc(L);
  while (R >= L) and (S[R] in [#9, #10, #13, ' ']) do
    Dec(R);
  if L > R then
    LTrimLen := 0
  else
    LTrimLen := R - L + 1;
  LLitLen := Length(Lit);
  if LTrimLen <> LLitLen then
    Exit(False);
  if LTrimLen = 0 then
    Exit(True);
  for I := 0 to LTrimLen - 1 do
    if S[L + I] <> Lit[1 + I] then
      Exit(False);
  Result := True;
end;

procedure CheckJsRuntimeOptions(const AOptions: TJsRuntimeOptions);
begin
  if AOptions.TimeoutMs < 0 then
    raise EJsError.Create('TimeoutMs must be >= 0', jecUnknown, 'Error', '', jsbkFake);
end;

end.
