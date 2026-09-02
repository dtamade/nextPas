program test_js_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.js.quickjs.loader,
  nextpas.core.js,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestBackendKindToString;
begin
  CheckEqual('jsbkFake', JsBackendKindToString(jsbkFake), 'fake');
  CheckEqual('jsbkQuickJs', JsBackendKindToString(jsbkQuickJs), 'quickjs');
  CheckEqual('jsbkJs888', JsBackendKindToString(jsbkJs888), 'js888');
  CheckEqual('jsbkV8', JsBackendKindToString(jsbkV8), 'v8');
  CheckEqual('jsbkChakra', JsBackendKindToString(jsbkChakra), 'chakra');
end;

procedure TestValueKindToString;
begin
  CheckEqual('jskUndefined', JsValueKindToString(jskUndefined), 'undef');
  CheckEqual('jskString', JsValueKindToString(jskString), 'str');
  CheckEqual('jskNumber', JsValueKindToString(jskNumber), 'num');
  CheckEqual('jskSymbol', JsValueKindToString(jskSymbol), 'sym');
  CheckEqual('jskBigInt', JsValueKindToString(jskBigInt), 'bigint');
end;

procedure TestErrorCategoryToString;
begin
  CheckEqual('jecSyntax', JsErrorCategoryToString(jecSyntax), 'syntax');
  CheckEqual('jecTimeout', JsErrorCategoryToString(jecTimeout), 'timeout');
  CheckEqual('jecUnknown', JsErrorCategoryToString(jecUnknown), 'unknown');
end;

procedure TestRuntimeOptionsDefault;
var
  O: TJsRuntimeOptions;
begin
  O := TJsRuntimeOptions.Default;
  CheckEqual(Int64(0), Int64(O.MemoryLimit), 'mem0');
  CheckEqual(Int64(0), Int64(O.TimeoutMs), 'timeout0');
end;

procedure TestRuntimeOptionsWithMemory;
var
  O: TJsRuntimeOptions;
begin
  O := TJsRuntimeOptions.WithMemoryLimit(1024);
  CheckEqual(Int64(1024), Int64(O.MemoryLimit), 'mem1024');
  CheckEqual(Int64(0), Int64(O.TimeoutMs), 'timeout0');
end;

procedure TestRuntimeOptionsWithTimeout;
var
  O: TJsRuntimeOptions;
begin
  O := TJsRuntimeOptions.WithTimeout(500);
  CheckEqual(Int64(500), Int64(O.TimeoutMs), '500');
  CheckEqual(Int64(0), Int64(O.MemoryLimit), 'mem0');
end;

procedure TestCheckOptionsValid;
var
  O: TJsRuntimeOptions;
begin
  O := TJsRuntimeOptions.Default;
  O.TimeoutMs := 0;
  CheckJsRuntimeOptions(O);
  Check(True, 'valid 0');
  O.TimeoutMs := 100;
  CheckJsRuntimeOptions(O);
  Check(True, 'valid 100');
end;

procedure TestCheckOptionsInvalid;
var
  O: TJsRuntimeOptions;
  Raised: Boolean;
begin
  O := TJsRuntimeOptions.Default;
  O.TimeoutMs := -1;
  Raised := False;
  try
    CheckJsRuntimeOptions(O);
  except
    on E: EJsError do Raised := True;
  end;
  Check(Raised, 'negative timeout raises');
end;

procedure TestEJsErrorHierarchy;
var
  E: EJsError;
  ET: EJsTimeout;
  EM: EJsMemoryLimit;
  EB: EJsBackendUnavailable;
begin
  E := EJsError.Create('msg', jecSyntax, 'SyntaxError', 'at:1', jsbkFake);
  try
    CheckEqual('msg', E.Message, 'msg');
    Check(E.Category = jecSyntax, 'cat');
    CheckEqual('SyntaxError', E.Species, 'species');
    CheckEqual('at:1', E.JsStack, 'stack');
    Check(E.Backend = jsbkFake, 'backend');
  finally
    E.Free;
  end;
  ET := EJsTimeout.Create('t', jecTimeout, 'Interrupt', '', jsbkFake);
  try
    Check(ET is EJsError, 'timeout is EJsError');
  finally
    ET.Free;
  end;
  EM := EJsMemoryLimit.Create('m', jecMemory, 'InternalError', '', jsbkFake);
  try
    Check(EM is EJsError, 'mem is EJsError');
  finally
    EM.Free;
  end;
  EB := EJsBackendUnavailable.Create('b', jecUnknown, 'Error', '', jsbkQuickJs);
  try
    Check(EB is EJsError, 'unavailable is EJsError');
  finally
    EB.Free;
  end;
end;

procedure TestJSProbeNames;
var P: string;
begin
  P := JsQuickJsProbeNames;
  Check(Pos('libquickjs.so.1', P) > 0, 'probe so.1');
  Check(Pos('libquickjs.so.0', P) > 0, 'probe so.0');
  Check(Pos('libquickjs.so', P) > 0, 'probe so');
  Check(Pos('libquickjs.dylib', P) > 0, 'probe dylib');
  Check(Pos('libquickjs.1.dylib', P) > 0, 'probe 1.dylib');
  Check(Pos('quickjs.dll', P) > 0, 'probe dll');
  Check(Pos('libquickjs.dll', P) > 0, 'probe lib dll');
  Check(Pos('quickjs', P) > 0, 'probe quickjs');
end;

procedure TestSymbolBigInt;
var V: TJsValue;
begin
  V := JsSymbolValue('sym');
  Check(V.IsSymbol, 'symbol');
  CheckEqual('jskSymbol', JsValueKindToString(V.Kind), 'sym kind');
  V := JsBigIntValue(123);
  Check(V.IsBigInt, 'bigint');
  CheckEqual('jskBigInt', JsValueKindToString(V.Kind), 'bigint kind');
  CheckEqual(Int64(123), V.AsInt, 'bigint int');
end;

procedure TestBackendExt;
begin
  Check(JsBackendAvailable(jsbkV8), 'v8 avail');
  Check(JsBackendAvailable(jsbkChakra), 'chakra avail');
end;

begin
  T := TTestSuite.Create('nextpas.core.js.base');
  T.Test('JsBackendKindToString', @TestBackendKindToString);
  T.Test('JsValueKindToString', @TestValueKindToString);
  T.Test('JsErrorCategoryToString', @TestErrorCategoryToString);
  T.Test('RuntimeOptions Default', @TestRuntimeOptionsDefault);
  T.Test('RuntimeOptions WithMemory', @TestRuntimeOptionsWithMemory);
  T.Test('RuntimeOptions WithTimeout', @TestRuntimeOptionsWithTimeout);
  T.Test('CheckOptions valid', @TestCheckOptionsValid);
  T.Test('CheckOptions invalid', @TestCheckOptionsInvalid);
  T.Test('EJsError hierarchy', @TestEJsErrorHierarchy);
  T.Test('probe names', @TestJSProbeNames);
  T.Test('symbol bigint', @TestSymbolBigInt);
  T.Test('backend ext', @TestBackendExt);
  if not T.Run then Halt(1);
end.
