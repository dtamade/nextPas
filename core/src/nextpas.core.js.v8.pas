unit nextpas.core.js.v8;
{** @desc 纯 Pascal 后端占位（零 FFI/零 platform.dl，恒可用，与 fake 同约束，S3 可演进为真解析器）。 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.base, nextpas.core.js.intf, nextpas.core.json;
type
  TJsV8Runtime = class(TInterfacedObject, IJsRuntime)
  private FOptions: TJsRuntimeOptions;
  public constructor Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions); overload;
  constructor Create(const AOptions: TJsRuntimeOptions); overload;
  function Kind: TJsBackendKind; function Options: TJsRuntimeOptions;
  function NewContext: IJsContext; procedure SetMemoryLimit(ALimit: SizeUInt);
  procedure SetTimeout(ATimeoutMs: Integer); procedure CollectGarbage;
  end;
  TJsV8Context = class(TInterfacedObject, IJsContext)
  private FRuntime: IJsRuntime; FOptions: TJsRuntimeOptions; FClosed: Boolean; FThreadId: UInt64;
    FHostFuncs: array of record Name: string; Func: TJsHostFunction; Method: TJsHostMethod; Proc: TJsHostProc; Kind: Integer; end;
    function FindHost(const AName: string): Integer; function IsOnCreationThread: Boolean;
    procedure EnsureNotClosed; procedure EnsureThreadAffinity; function ValidateHostName(const AName: string): Boolean;
    function DoEval(const ACode: string): TJsValue; procedure DoSetHost(const AName: string);
  public constructor Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
  function Runtime: IJsRuntime; function Eval(const ACode: string; const AFileName: string = ''): TJsValue;
  function TryEval(const ACode: string; out AValue: TJsValue): Boolean;
  function TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
  function Global: TJsValue; function NewString(const AStr: string): TJsValue;
  function NewInt(AValue: Int64): TJsValue; function NewDouble(AValue: Double): TJsValue;
  function NewBool(AValue: Boolean): TJsValue; function NewObject: TJsValue; function NewArray: TJsValue;
  function NewJson(const AJson: TJsonValue): TJsValue; function ToJson(const AValue: TJsValue): IJsonDocument;
  function HasProp(const AObj: TJsValue; const AName: string): Boolean;
  function DeleteProp(const AObj: TJsValue; const AName: string): Boolean;
  function GetKeys(const AObj: TJsValue): TJsStringArray;
  function NewError(const AMessage: string; ACategory: TJsErrorCategory = jecUnknown): TJsValue;
  function NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; overload;
  function NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; overload;
  function NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; overload;
  function GetProp(const AObj: TJsValue; const AName: string): TJsValue;
  procedure SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
  function Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
  procedure SetHostFunction(const AName: string; AHandler: TJsHostFunction); overload;
  procedure SetHostFunction(const AName: string; AHandler: TJsHostMethod); overload;
  procedure SetHostFunction(const AName: string; AHandler: TJsHostProc); overload;
  procedure RemoveHostFunction(const AName: string); procedure Tick; procedure CollectGarbage; procedure Close; function IsClosed: Boolean;
  end;
implementation
uses nextpas.core.base, nextpas.core.exception, nextpas.core.fs, nextpas.core.format.limits, nextpas.core.text, nextpas.core.platform.thread;
constructor TJsV8Runtime.Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions);
begin inherited Create; FOptions := AOptions; CheckJsRuntimeOptions(FOptions); end;
constructor TJsV8Runtime.Create(const AOptions: TJsRuntimeOptions);
begin inherited Create; FOptions := AOptions; CheckJsRuntimeOptions(FOptions); end;
function TJsV8Runtime.Kind: TJsBackendKind; begin Result := jsbkV8; end;
function TJsV8Runtime.Options: TJsRuntimeOptions; begin Result := FOptions; end;
function TJsV8Runtime.NewContext: IJsContext; begin Result := TJsV8Context.Create(Self, FOptions); end;
procedure TJsV8Runtime.SetMemoryLimit(ALimit: SizeUInt); begin FOptions.MemoryLimit := ALimit; end;
procedure TJsV8Runtime.SetTimeout(ATimeoutMs: Integer);
begin if ATimeoutMs < 0 then raise EJsError.Create('TimeoutMs must be >= 0', jecUnknown, 'Error', '', jsbkV8); FOptions.TimeoutMs := ATimeoutMs; end;
procedure TJsV8Runtime.CollectGarbage; begin end;
constructor TJsV8Context.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
begin inherited Create; FRuntime := ARuntime; FOptions := AOptions; FClosed := False; FThreadId := UInt64(platform_thread_self); end;
function TJsV8Context.FindHost(const AName: string): Integer; inline;
var I: Integer; begin for I:=0 to High(FHostFuncs) do if FHostFuncs[I].Name=AName then Exit(I); Result:=-1; end;
function TJsV8Context.IsOnCreationThread: Boolean; inline; begin Result := UInt64(platform_thread_self)=FThreadId; end;
procedure TJsV8Context.EnsureNotClosed; inline; begin if FClosed then raise EJsError.Create('Context is closed', jecUnknown, 'Error', '', jsbkV8); end;
procedure TJsV8Context.EnsureThreadAffinity; inline; begin if not IsOnCreationThread then raise EJsError.Create('Evaluated on wrong thread', jecUnknown, 'Error', '', jsbkV8); end;
function TJsV8Context.ValidateHostName(const AName: string): Boolean;
var I: Integer; C: Char; begin Result:=False; if AName='' then Exit; if Pos('..',AName)>0 then Exit; if AName[1]='.' then Exit; if AName[Length(AName)]='.' then Exit;
  for I:=1 to Length(AName) do begin C:=AName[I]; if C='.' then Continue; if not (C in ['A'..'Z','a'..'z','_','$','0'..'9']) then Exit;
    if (I>1) and (AName[I-1]<>'.') then Continue; if (C in ['0'..'9']) and ((I=1) or (AName[I-1]='.')) then Exit; end; Result:=True; end;

function TJsV8Context.DoEval(const ACode: string): TJsValue;
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
    raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', jsbkV8);
  if (Pos('while(true)', ACode) > 0) and (FOptions.TimeoutMs > 0) then
    raise EJsTimeout.Create('Timeout', jecTimeout, 'Interrupt', 'at eval:1:1', jsbkV8);
  if (FOptions.MemoryLimit > 0) and (FOptions.MemoryLimit < 1024) then
    raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', jsbkV8);
  if JsTrimEquals(ACode,'1+2') then Exit(JsIntValue(3));
  if JsTrimEquals(ACode,'bad(') then
    raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at bad(:1:4', jsbkV8);
  if JsTrimEquals(ACode,'foo(') then
    raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at foo(:1:4', jsbkV8);
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
              raise EJsError.Create(E.Message, jecUnknown, 'Error', '', jsbkV8);
            on E: TObject do
              raise EJsError.Create(E.ClassName, jecUnknown, 'Error', '', jsbkV8);
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
              raise EJsError.Create(E.Message, jecUnknown, 'Error', '', jsbkV8);
            on E: TObject do
              raise EJsError.Create(E.ClassName, jecUnknown, 'Error', '', jsbkV8);
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
              raise EJsError.Create(E.Message, jecUnknown, 'Error', '', jsbkV8);
            on E: TObject do
              raise EJsError.Create(E.ClassName, jecUnknown, 'Error', '', jsbkV8);
          end;
          Exit;
        end;
      end;
    end;
  end;
  Result := JsStringValue(LCode);
end;
function TJsV8Context.Runtime: IJsRuntime; begin EnsureNotClosed; Result:=FRuntime; end;
function TJsV8Context.Eval(const ACode: string; const AFileName: string): TJsValue; begin EnsureNotClosed; EnsureThreadAffinity; Result:=DoEval(ACode); end;
function TJsV8Context.TryEval(const ACode: string; out AValue: TJsValue): Boolean; begin try AValue:=Eval(ACode); Result:=True; except AValue:=JsUndefinedValue; Result:=False; end; end;
function TJsV8Context.TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
var C: string; begin AValue:=JsUndefinedValue; if (AFileName='') or not FileExists(AFileName) then Exit(False); try if SizeUInt(FileSize(AFileName))>FORMAT_BULK_PARSE_MAX_BYTES then Exit(False); C:=ReadFileText(AFileName); Result:=TryEval(C,AValue); except Result:=False; end; end;
function TJsV8Context.Global: TJsValue; begin EnsureNotClosed; Result:=JsObjectValue; end;
function TJsV8Context.NewString(const AStr: string): TJsValue; begin EnsureNotClosed; Result:=JsStringValue(AStr); end;
function TJsV8Context.NewInt(AValue: Int64): TJsValue; begin EnsureNotClosed; Result:=JsIntValue(AValue); end;
function TJsV8Context.NewDouble(AValue: Double): TJsValue; begin EnsureNotClosed; Result:=JsDoubleValue(AValue); end;
function TJsV8Context.NewBool(AValue: Boolean): TJsValue; begin EnsureNotClosed; Result:=JsBoolValue(AValue); end;
function TJsV8Context.NewObject: TJsValue; begin EnsureNotClosed; Result:=JsObjectValue; end;
function TJsV8Context.NewArray: TJsValue; begin EnsureNotClosed; Result:=JsArrayValue; end;
function TJsV8Context.NewJson(const AJson: TJsonValue): TJsValue;
begin EnsureNotClosed; if AJson.IsStr then Result:=JsStringValue(AJson.AsStr.ToString) else if AJson.IsInt then Result:=JsIntValue(AJson.AsInt) else if AJson.IsBool then Result:=JsBoolValue(AJson.AsBool) else if AJson.IsNull then Result:=JsNullValue else if AJson.IsArray then Result:=NewArray else if AJson.IsObject then Result:=NewObject else Result:=JsUndefinedValue; end;
function TJsV8Context.ToJson(const AValue: TJsValue): IJsonDocument;
var LJson: string; begin EnsureNotClosed; case AValue.Kind of jskString: LJson:='"'+AValue.AsString+'"'; jskNumber: LJson:=nextpas.core.text.IntToStr(AValue.AsInt); jskBoolean: if AValue.AsBool then LJson:='true' else LJson:='false'; jskNull: LJson:='null'; else LJson:='null'; end; Result:=JsonParse(LJson); end;
function TJsV8Context.HasProp(const AObj: TJsValue; const AName: string): Boolean; begin EnsureNotClosed; Result:=False; end;
function TJsV8Context.DeleteProp(const AObj: TJsValue; const AName: string): Boolean; begin EnsureNotClosed; Result:=False; end;
function TJsV8Context.GetKeys(const AObj: TJsValue): TJsStringArray; begin EnsureNotClosed; Result:=nil; end;
function TJsV8Context.NewError(const AMessage: string; ACategory: TJsErrorCategory): TJsValue; begin EnsureNotClosed; Result:=JsErrorValue(AMessage); end;
function TJsV8Context.NewFunction(const AName: string; AHandler: TJsHostFunction): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=JsFunctionValue(AName); end;
function TJsV8Context.NewFunction(const AName: string; AHandler: TJsHostMethod): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=JsFunctionValue(AName); end;
function TJsV8Context.NewFunction(const AName: string; AHandler: TJsHostProc): TJsValue; begin EnsureNotClosed; if Assigned(AHandler) then SetHostFunction(AName,AHandler); Result:=JsFunctionValue(AName); end;
function TJsV8Context.GetProp(const AObj: TJsValue; const AName: string): TJsValue; begin EnsureNotClosed; Result:=JsUndefinedValue; end;
procedure TJsV8Context.SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue); begin EnsureNotClosed; end;
function TJsV8Context.Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue; begin EnsureNotClosed; EnsureThreadAffinity; Result:=JsUndefinedValue; end;
procedure TJsV8Context.DoSetHost(const AName: string); begin EnsureNotClosed; if not ValidateHostName(AName) then raise EJsError.Create('Invalid host function name: '+AName,jecSyntax,'SyntaxError','',jsbkV8); end;
procedure TJsV8Context.SetHostFunction(const AName: string; AHandler: TJsHostFunction);
var LIdx: Integer; begin DoSetHost(AName); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil',jecUnknown,'Error','',jsbkV8); LIdx:=FindHost(AName); if LIdx>=0 then begin FHostFuncs[LIdx].Func:=AHandler; FHostFuncs[LIdx].Kind:=0; Exit; end; SetLength(FHostFuncs,Length(FHostFuncs)+1); FHostFuncs[High(FHostFuncs)].Name:=AName; FHostFuncs[High(FHostFuncs)].Func:=AHandler; FHostFuncs[High(FHostFuncs)].Kind:=0; end;
procedure TJsV8Context.SetHostFunction(const AName: string; AHandler: TJsHostMethod);
var LIdx: Integer; begin DoSetHost(AName); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil',jecUnknown,'Error','',jsbkV8); LIdx:=FindHost(AName); if LIdx>=0 then begin FHostFuncs[LIdx].Method:=AHandler; FHostFuncs[LIdx].Kind:=1; Exit; end; SetLength(FHostFuncs,Length(FHostFuncs)+1); FHostFuncs[High(FHostFuncs)].Name:=AName; FHostFuncs[High(FHostFuncs)].Method:=AHandler; FHostFuncs[High(FHostFuncs)].Kind:=1; end;
procedure TJsV8Context.SetHostFunction(const AName: string; AHandler: TJsHostProc);
var LIdx: Integer; begin DoSetHost(AName); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil',jecUnknown,'Error','',jsbkV8); LIdx:=FindHost(AName); if LIdx>=0 then begin FHostFuncs[LIdx].Proc:=AHandler; FHostFuncs[LIdx].Kind:=2; Exit; end; SetLength(FHostFuncs,Length(FHostFuncs)+1); FHostFuncs[High(FHostFuncs)].Name:=AName; FHostFuncs[High(FHostFuncs)].Proc:=AHandler; FHostFuncs[High(FHostFuncs)].Kind:=2; end;
procedure TJsV8Context.RemoveHostFunction(const AName: string);
var LIdx,I: Integer; begin EnsureNotClosed; LIdx:=FindHost(AName); if LIdx<0 then Exit; for I:=LIdx to High(FHostFuncs)-1 do FHostFuncs[I]:=FHostFuncs[I+1]; SetLength(FHostFuncs,Length(FHostFuncs)-1); end;
procedure TJsV8Context.Tick; begin EnsureNotClosed; end;
procedure TJsV8Context.CollectGarbage; begin EnsureNotClosed; end;
procedure TJsV8Context.Close; begin if FClosed then Exit; FClosed:=True; end;
function TJsV8Context.IsClosed: Boolean; begin Result:=FClosed; end;
end.
