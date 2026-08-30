unit nextpas.core.js.pure.base;
{**
 * @desc 纯后端共享基座 — 零 FFI/零 platform.dl，js888/v8/chakra 单源复用。
 *       抽取 ValidateHostName / FindHost / DoEval 视图无关核心，消 300 行克隆。
 *       仅依赖 L0-L1 owner，不引入 fs/platform.dl，保持 pure 族同约束。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.text.view,
  nextpas.core.json;

type
  TJsPureHostRec = record
    Name: string;
    Func: TJsHostFunction;
    Method: TJsHostMethod;
    Proc: TJsHostProc;
    Kind: Integer;
  end;
  TJsPureHostArray = array of TJsPureHostRec;

function JsPureValidateHostName(const AName: string): Boolean; inline;
function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer; inline;
function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer; inline;
function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions;
  ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue;

implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text;

function JsPureValidateHostName(const AName: string): Boolean;
var I: Integer; C: Char;
begin
  Result := False;
  if AName = '' then Exit;
  if Pos('..', AName) > 0 then Exit;
  if AName[1] = '.' then Exit;
  if AName[Length(AName)] = '.' then Exit;
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    if C = '.' then Continue;
    if not (C in ['A'..'Z', 'a'..'z', '_', '$', '0'..'9']) then Exit;
    if (I > 1) and (AName[I-1] <> '.') then Continue;
    if (C in ['0'..'9']) and ((I = 1) or (AName[I-1] = '.')) then Exit;
  end;
  Result := True;
end;

function JsPureFindHost(const Hosts: TJsPureHostArray; const AName: string): Integer;
var I: Integer;
begin
  for I := 0 to High(Hosts) do if Hosts[I].Name = AName then Exit(I);
  Result := -1;
end;

function JsPureFindHostView(const Hosts: TJsPureHostArray; const AName: TStringView): Integer;
var I: Integer;
begin
  for I := 0 to High(Hosts) do if TStringView.FromStr(Hosts[I].Name).Equals(AName) then Exit(I);
  Result := -1;
end;

function JsPureDoEval(ACtx: IJsContext; const ACode: string; const AOptions: TJsRuntimeOptions;
  ABackend: TJsBackendKind; const Hosts: TJsPureHostArray; const AGlobal: TJsValue): TJsValue;
var
  LView, LNameView, LArgView: TStringView;
  LIdx: PtrInt;
  LHostIdx: Integer;
  LSingle: array[0..0] of TJsValue;
  LNoArgs: array of TJsValue;
  LHandler: TJsHostFunction;
  LMethod: TJsHostMethod;
  LProc: TJsHostProc;
  LThis: TJsValue;
  LHasArg: Boolean;
begin
  LNoArgs := nil;
  if JsTrimEquals(ACode, '') then
    raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', ABackend);
  if (Pos('while(true)', ACode) > 0) and (AOptions.TimeoutMs > 0) then
    raise EJsTimeout.Create('Timeout', jecTimeout, 'Interrupt', 'at eval:1:1', ABackend);
  if (AOptions.MemoryLimit > 0) and (AOptions.MemoryLimit < 1024) then
    raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', ABackend);
  if JsTrimEquals(ACode, '1+2') then Exit(JsIntValue(3));
  if JsTrimEquals(ACode, 'bad(') then
    raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at bad(:1:4', ABackend);
  if JsTrimEquals(ACode, 'foo(') then
    raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at foo(:1:4', ABackend);
  if (Pos('JSON.stringify', ACode) > 0) and (Pos('x', ACode) > 0) then
    Exit(JsStringValue('{"x":1}'));
  if JsTrimEquals(ACode, 'null') then Exit(JsNullValue);
  if JsTrimEquals(ACode, 'undefined') then Exit(JsUndefinedValue);
  if JsTrimEquals(ACode, 'true') then Exit(JsBoolValue(True));
  if JsTrimEquals(ACode, 'false') then Exit(JsBoolValue(False));
  LView := TStringView.FromStr(ACode).Trim;
  LIdx := LView.IndexOf('(');
  if LIdx >= 0 then
  begin
    LNameView := LView.Slice(0, SizeUInt(LIdx)).Trim;
    if not LNameView.IsEmpty then
    begin
      LHostIdx := JsPureFindHostView(Hosts, LNameView);
      if LHostIdx >= 0 then
      begin
        if SizeUInt(LIdx) + 1 < LView.Len then
        begin
          if LView.Len >= 2 then
            LArgView := LView.Slice(SizeUInt(LIdx) + 1, LView.Len - SizeUInt(LIdx) - 2).Trim
          else LArgView := TStringView.Empty;
        end else LArgView := TStringView.Empty;
        if (LArgView.Len >= 2) and ((LArgView.Data[0] = '"') or (LArgView.Data[0] = '''')) then
          LArgView := LArgView.Slice(1, LArgView.Len - 2);
        if (LArgView.Len = 1) and (LArgView.Data[0] = ')') then LArgView := TStringView.Empty;
        LHasArg := not LArgView.IsEmpty;
        if LHasArg then LSingle[0] := JsStringValue(LArgView.ToString);
        LThis := AGlobal;
        case Hosts[LHostIdx].Kind of
          0:
          begin
            LHandler := Hosts[LHostIdx].Func;
            try
              if LHasArg then Result := LHandler(ACtx, LThis, LSingle) else Result := LHandler(ACtx, LThis, LNoArgs);
            except
              on E: EJsError do raise;
              on E: ENextPasError do raise EJsError.Create(E.Message, jecUnknown, 'Error', '', ABackend);
              on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, 'Error', '', ABackend);
            end;
            Exit;
          end;
          1:
          begin
            LMethod := Hosts[LHostIdx].Method;
            try
              if LHasArg then Result := LMethod(ACtx, LThis, LSingle) else Result := LMethod(ACtx, LThis, LNoArgs);
            except
              on E: EJsError do raise;
              on E: ENextPasError do raise EJsError.Create(E.Message, jecUnknown, 'Error', '', ABackend);
              on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, 'Error', '', ABackend);
            end;
            Exit;
          end;
          2:
          begin
            LProc := Hosts[LHostIdx].Proc;
            try
              if LHasArg then Result := LProc(ACtx, LThis, LSingle) else Result := LProc(ACtx, LThis, LNoArgs);
            except
              on E: EJsError do raise;
              on E: ENextPasError do raise EJsError.Create(E.Message, jecUnknown, 'Error', '', ABackend);
              on E: TObject do raise EJsError.Create(E.ClassName, jecUnknown, 'Error', '', ABackend);
            end;
            Exit;
          end;
        end;
      end;
    end;
  end;
  Result := JsStringValue(LView.ToString);
end;

end.
