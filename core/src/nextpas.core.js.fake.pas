unit nextpas.core.js.fake;
{**
 * @desc 假后端（纯 Pascal，零外部依赖，CI 必跑，确定性语义）。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.js.base,
  nextpas.core.js.intf,
  nextpas.core.json;

type
  TJsFakeRuntime = class;
  TJsFakeContext = class;
  TJsFakeValueRef = class(TInterfacedObject, IJsValueRef)
  private
    FValue: TJsValue;
  public
    constructor Create(const AValue: TJsValue);
    function Value: TJsValue;
  end;
  TJsFakeRuntime = class(TInterfacedObject, IJsRuntime)
  private
    FOptions: TJsRuntimeOptions;
    FKind: TJsBackendKind;
  public
    constructor Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions);
    function Kind: TJsBackendKind;
    function Options: TJsRuntimeOptions;
    function NewContext: IJsContext;
    procedure SetMemoryLimit(ALimit: SizeUInt);
    procedure SetTimeout(ATimeoutMs: Integer);
    procedure CollectGarbage;
  end;
  TJsFakeContext = class(TInterfacedObject, IJsContext)
  private
    FRuntime: IJsRuntime;
    FOptions: TJsRuntimeOptions;
    FClosed: Boolean;
    FThreadId: UInt64;
    FHostFuncs: array of record
      Name: string;
      Func: TJsHostFunction;
      Method: TJsHostMethod;
      Proc: TJsHostProc;
      Kind: Integer;
    end;
    function FindHost(const AName: string): Integer;
    function IsOnCreationThread: Boolean;
    procedure EnsureNotClosed;
    procedure EnsureThreadAffinity;
    function ValidateHostName(const AName: string): Boolean;
    function DoEval(const ACode: string): TJsValue;
    procedure DoSetHost(const AName: string);
  public
    constructor Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
    function Runtime: IJsRuntime;
    function Eval(const ACode: string; const AFileName: string = ''): TJsValue;
    function TryEval(const ACode: string; out AValue: TJsValue): Boolean;
    function TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
    function Global: TJsValue;
    function NewString(const AStr: string): TJsValue;
    function NewInt(AValue: Int64): TJsValue;
    function NewDouble(AValue: Double): TJsValue;
    function NewBool(AValue: Boolean): TJsValue;
    function NewObject: TJsValue;
    function NewArray: TJsValue;
    function NewJson(const AJson: TJsonValue): TJsValue;
    function ToJson(const AValue: TJsValue): IJsonDocument;
    function HasProp(const AObj: TJsValue; const AName: string): Boolean;
    function DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
    function GetKeys(const AObj: TJsValue): TJsStringArray;
    function NewError(const AMessage: string; ACategory: TJsErrorCategory = jecUnknown): TJsValue;
    function NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; overload;
    function NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; overload;
    function NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; overload;
    function GetProp(const AObj: TJsValue; const AName: string): TJsValue;
    procedure SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
    function Call(const AFunc: TJsValue; const AThis: TJsValue;
      const AArgs: array of TJsValue): TJsValue;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostFunction); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostMethod); overload;
    procedure SetHostFunction(const AName: string; AHandler: TJsHostProc); overload;
    procedure RemoveHostFunction(const AName: string);
    procedure Tick;
    procedure CollectGarbage; procedure Close; function IsClosed: Boolean;
  end;
implementation
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.text,
  nextpas.core.platform.thread;
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
  inherited Create;
  FKind := AKind;
  FOptions := AOptions;
  CheckJsRuntimeOptions(FOptions);
end;

function TJsFakeRuntime.Kind: TJsBackendKind;
begin
  Result := FKind;
end;

function TJsFakeRuntime.Options: TJsRuntimeOptions;
begin
  Result := FOptions;
end;

function TJsFakeRuntime.NewContext: IJsContext;
begin
  Result := TJsFakeContext.Create(Self, FOptions);
end;

procedure TJsFakeRuntime.SetMemoryLimit(ALimit: SizeUInt);
begin
  FOptions.MemoryLimit := ALimit;
end;

procedure TJsFakeRuntime.SetTimeout(ATimeoutMs: Integer);
begin
  if ATimeoutMs < 0 then
    raise EJsError.Create('TimeoutMs must be >= 0', jecUnknown, 'Error', '', FKind);
  FOptions.TimeoutMs := ATimeoutMs;
end;

procedure TJsFakeRuntime.CollectGarbage;
begin
end;

constructor TJsFakeContext.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
begin
  inherited Create;
  FRuntime := ARuntime;
  FOptions := AOptions;
  FClosed := False;
  FThreadId := UInt64(platform_thread_self);
end;

function TJsFakeContext.FindHost(const AName: string): Integer; inline;
var
  I: Integer;
begin
  for I := 0 to High(FHostFuncs) do
    if FHostFuncs[I].Name = AName then
      Exit(I);
  Result := -1;
end;

function TJsFakeContext.IsOnCreationThread: Boolean; inline;
begin
  Result := UInt64(platform_thread_self) = FThreadId;
end;

procedure TJsFakeContext.EnsureNotClosed; inline;
begin
  if FClosed then
    raise EJsError.Create('Context is closed', jecUnknown, 'Error', '', jsbkFake);
end;

procedure TJsFakeContext.EnsureThreadAffinity; inline;
begin
  if not IsOnCreationThread then
    raise EJsError.Create('Evaluated on wrong thread', jecUnknown, 'Error', '', jsbkFake);
end;

function TJsFakeContext.ValidateHostName(const AName: string): Boolean;
var
  I: Integer;
  C: Char;
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


function TJsFakeContext.DoEval(const ACode: string): TJsValue;
var
  LCode: string;
  LIdx, LHostIdx: Integer;
  LName, LArg: string;
  LSingle: array[0..0] of TJsValue;
  LNoArgs: array of TJsValue;
  LHandler: TJsHostFunction;
  LMethod: TJsHostMethod;
  LProc: TJsHostProc;
  LThis: TJsValue;
  LHasArg: Boolean;
begin
  LNoArgs:=nil;
  if JsTrimEquals(ACode,'') then
    raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', jsbkFake);
  if (Pos('while(true)', ACode) > 0) and (FOptions.TimeoutMs > 0) then
    raise EJsTimeout.Create('Timeout', jecTimeout, 'Interrupt', 'at eval:1:1', jsbkFake);
  if (FOptions.MemoryLimit > 0) and (FOptions.MemoryLimit < 1024) then
    raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', jsbkFake);
  if JsTrimEquals(ACode,'1+2') then Exit(JsIntValue(3));
  if JsTrimEquals(ACode,'bad(') then
    raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at bad(:1:4', jsbkFake);
  if JsTrimEquals(ACode,'foo(') then
    raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at foo(:1:4', jsbkFake);
  if (Pos('JSON.stringify', ACode) > 0) and (Pos('x', ACode) > 0) then
    Exit(JsStringValue('{"x":1}'));
  if JsTrimEquals(ACode,'null') then Exit(JsNullValue);
  if JsTrimEquals(ACode,'undefined') then Exit(JsUndefinedValue);
  if JsTrimEquals(ACode,'true') then Exit(JsBoolValue(True));
  if JsTrimEquals(ACode,'false') then Exit(JsBoolValue(False));
  LCode := TextTrim(ACode);
  LIdx := Pos('(', LCode);
  if LIdx > 0 then
  begin
    LName := TextTrim(Copy(LCode, 1, LIdx - 1));
    LHostIdx := FindHost(LName);
    if LHostIdx >= 0 then
    begin
      LArg := TextTrim(Copy(LCode, LIdx + 1, Length(LCode) - LIdx - 1));
      if (Length(LArg) >= 2) and ((LArg[1] = '"') or (LArg[1] = '''')) then
        LArg := Copy(LArg, 2, Length(LArg) - 2);
      if LArg = ')' then LArg := '';
      LHasArg := LArg <> '';
      if LHasArg then LSingle[0] := JsStringValue(LArg);
      LThis := Global;
      case FHostFuncs[LHostIdx].Kind of
        0:
        begin
          LHandler := FHostFuncs[LHostIdx].Func;
          try
            if LHasArg then Result := LHandler(Self, LThis, LSingle) else Result := LHandler(Self, LThis, LNoArgs);
          except
            on E: EJsError do raise;
            on E: ENextPasError do
              raise EJsError.Create(E.Message, jecUnknown, 'Error', '', jsbkFake);
            on E: TObject do
              raise EJsError.Create(E.ClassName, jecUnknown, 'Error', '', jsbkFake);
          end;
          Exit;
        end;
        1:
        begin
          LMethod := FHostFuncs[LHostIdx].Method;
          try
            if LHasArg then Result := LMethod(Self, LThis, LSingle) else Result := LMethod(Self, LThis, LNoArgs);
          except
            on E: EJsError do raise;
            on E: ENextPasError do
              raise EJsError.Create(E.Message, jecUnknown, 'Error', '', jsbkFake);
            on E: TObject do
              raise EJsError.Create(E.ClassName, jecUnknown, 'Error', '', jsbkFake);
          end;
          Exit;
        end;
        2:
        begin
          LProc := FHostFuncs[LHostIdx].Proc;
          try
            if LHasArg then Result := LProc(Self, LThis, LSingle) else Result := LProc(Self, LThis, LNoArgs);
          except
            on E: EJsError do raise;
            on E: ENextPasError do
              raise EJsError.Create(E.Message, jecUnknown, 'Error', '', jsbkFake);
            on E: TObject do
              raise EJsError.Create(E.ClassName, jecUnknown, 'Error', '', jsbkFake);
          end;
          Exit;
        end;
      end;
    end;
  end;
  Result := JsStringValue(LCode);
end;

function TJsFakeContext.Runtime: IJsRuntime;
begin
  EnsureNotClosed;
  Result := FRuntime;
end;

function TJsFakeContext.Eval(const ACode: string; const AFileName: string): TJsValue;
begin
  EnsureNotClosed;
  EnsureThreadAffinity;
  Result := DoEval(ACode);
end;

function TJsFakeContext.TryEval(const ACode: string; out AValue: TJsValue): Boolean;
begin
  try
    AValue := Eval(ACode);
    Result := True;
  except
    AValue := JsUndefinedValue;
    Result := False;
  end;
end;

function TJsFakeContext.TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
var
  LContent: string;
begin
  AValue := JsUndefinedValue;
  if (AFileName = '') or not FileExists(AFileName) then
    Exit(False);
  try
    if FileSize(AFileName) > 64 * 1024 * 1024 then
      Exit(False);
    LContent := ReadFileText(AFileName);
    Result := TryEval(LContent, AValue);
  except
    Result := False;
  end;
end;

function TJsFakeContext.Global: TJsValue;
begin
  EnsureNotClosed;
  Result := JsObjectValue;
end;

function TJsFakeContext.NewString(const AStr: string): TJsValue;
begin
  EnsureNotClosed;
  Result := JsStringValue(AStr);
end;

function TJsFakeContext.NewInt(AValue: Int64): TJsValue;
begin
  EnsureNotClosed;
  Result := JsIntValue(AValue);
end;

function TJsFakeContext.NewDouble(AValue: Double): TJsValue;
begin
  EnsureNotClosed;
  Result := JsDoubleValue(AValue);
end;

function TJsFakeContext.NewBool(AValue: Boolean): TJsValue;
begin
  EnsureNotClosed;
  Result := JsBoolValue(AValue);
end;

function TJsFakeContext.NewObject: TJsValue;
begin
  EnsureNotClosed;
  Result := JsObjectValue;
end;

function TJsFakeContext.NewArray: TJsValue;
begin
  EnsureNotClosed;
  Result := JsArrayValue;
end;

function TJsFakeContext.NewJson(const AJson: TJsonValue): TJsValue;
begin
  EnsureNotClosed;
  if AJson.IsStr then
    Result := JsStringValue(AJson.AsStr.ToString)
  else if AJson.IsInt then
    Result := JsIntValue(AJson.AsInt)
  else if AJson.IsBool then
    Result := JsBoolValue(AJson.AsBool)
  else if AJson.IsNull then
    Result := JsNullValue
  else if AJson.IsArray then
    Result := NewArray
  else if AJson.IsObject then
    Result := NewObject
  else
    Result := JsUndefinedValue;
end;

function TJsFakeContext.ToJson(const AValue: TJsValue): IJsonDocument;
var
  LJson: string;
begin
  EnsureNotClosed;
  case AValue.Kind of
    jskString: LJson := '"' + AValue.AsString + '"';
    jskNumber: LJson := nextpas.core.text.IntToStr(AValue.AsInt);
    jskBoolean:
      if AValue.AsBool then LJson := 'true' else LJson := 'false';
    jskNull: LJson := 'null';
  else
    LJson := 'null';
  end;
  Result := JsonParse(LJson);
end;
function TJsFakeContext.HasProp(const AObj: TJsValue; const AName: string): Boolean; begin EnsureNotClosed; Result := False; end;
function TJsFakeContext.DeleteProp(const AObj: TJsValue; const AName: string): Boolean; begin EnsureNotClosed; Result := False; end;
function TJsFakeContext.GetKeys(const AObj: TJsValue): TJsStringArray; begin EnsureNotClosed; Result := nil; end;
function TJsFakeContext.NewError(const AMessage: string; ACategory: TJsErrorCategory): TJsValue; begin EnsureNotClosed; Result := JsErrorValue(AMessage); end;
function TJsFakeContext.NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName, AHandler); Result := JsFunctionValue(AName); end;
function TJsFakeContext.NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName, AHandler); Result := JsFunctionValue(AName); end;
function TJsFakeContext.NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName, AHandler); Result := JsFunctionValue(AName); end;

function TJsFakeContext.GetProp(const AObj: TJsValue; const AName: string): TJsValue;
begin
  EnsureNotClosed;
  Result := JsUndefinedValue;
end;

procedure TJsFakeContext.SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
begin
  EnsureNotClosed;
end;

function TJsFakeContext.Call(const AFunc: TJsValue; const AThis: TJsValue;
  const AArgs: array of TJsValue): TJsValue;
begin
  EnsureNotClosed;
  EnsureThreadAffinity;
  Result := JsUndefinedValue;
end;

procedure TJsFakeContext.DoSetHost(const AName: string);
begin
  EnsureNotClosed;
  if not ValidateHostName(AName) then
    raise EJsError.Create('Invalid host function name: ' + AName, jecSyntax, 'SyntaxError', '', jsbkFake);
end;

procedure TJsFakeContext.SetHostFunction(const AName: string; AHandler: TJsHostFunction);
var
  LIdx: Integer;
begin
  DoSetHost(AName);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', jsbkFake);
  LIdx := FindHost(AName);
  if LIdx >= 0 then
  begin
    FHostFuncs[LIdx].Func := AHandler;
    FHostFuncs[LIdx].Kind := 0;
    Exit;
  end;
  SetLength(FHostFuncs, Length(FHostFuncs) + 1);
  FHostFuncs[High(FHostFuncs)].Name := AName;
  FHostFuncs[High(FHostFuncs)].Func := AHandler;
  FHostFuncs[High(FHostFuncs)].Kind := 0;
end;

procedure TJsFakeContext.SetHostFunction(const AName: string; AHandler: TJsHostMethod);
var
  LIdx: Integer;
begin
  DoSetHost(AName);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', jsbkFake);
  LIdx := FindHost(AName);
  if LIdx >= 0 then
  begin
    FHostFuncs[LIdx].Method := AHandler;
    FHostFuncs[LIdx].Kind := 1;
    Exit;
  end;
  SetLength(FHostFuncs, Length(FHostFuncs) + 1);
  FHostFuncs[High(FHostFuncs)].Name := AName;
  FHostFuncs[High(FHostFuncs)].Method := AHandler;
  FHostFuncs[High(FHostFuncs)].Kind := 1;
end;

procedure TJsFakeContext.SetHostFunction(const AName: string; AHandler: TJsHostProc);
var
  LIdx: Integer;
begin
  DoSetHost(AName);
  if not Assigned(AHandler) then
    raise EJsError.Create('Host handler is nil', jecUnknown, 'Error', '', jsbkFake);
  LIdx := FindHost(AName);
  if LIdx >= 0 then
  begin
    FHostFuncs[LIdx].Proc := AHandler;
    FHostFuncs[LIdx].Kind := 2;
    Exit;
  end;
  SetLength(FHostFuncs, Length(FHostFuncs) + 1);
  FHostFuncs[High(FHostFuncs)].Name := AName;
  FHostFuncs[High(FHostFuncs)].Proc := AHandler;
  FHostFuncs[High(FHostFuncs)].Kind := 2;
end;

procedure TJsFakeContext.RemoveHostFunction(const AName: string);
var
  LIdx, I: Integer;
begin
  EnsureNotClosed;
  LIdx := FindHost(AName);
  if LIdx < 0 then Exit;
  for I := LIdx to High(FHostFuncs) - 1 do
    FHostFuncs[I] := FHostFuncs[I + 1];
  SetLength(FHostFuncs, Length(FHostFuncs) - 1);
end;

procedure TJsFakeContext.Tick;
begin
  EnsureNotClosed;
end;

procedure TJsFakeContext.CollectGarbage;
begin
  EnsureNotClosed;
end;

procedure TJsFakeContext.Close; begin if FClosed then Exit; FClosed:=True; end;
function TJsFakeContext.IsClosed: Boolean;
begin
  Result := FClosed;
end;
end.
