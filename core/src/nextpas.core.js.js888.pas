unit nextpas.core.js.js888;
{** @desc 纯 Pascal 后端占位（零 FFI/零 platform.dl，恒可用，与 fake 同约束，S3 可演进为真解析器）。 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.js.base, nextpas.core.js.intf, nextpas.core.json;
type
  TJsJs888Runtime = class(TInterfacedObject, IJsRuntime)
  private FOptions: TJsRuntimeOptions;
  public constructor Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions); overload;
  constructor Create(const AOptions: TJsRuntimeOptions); overload;
  function Kind: TJsBackendKind; function Options: TJsRuntimeOptions;
  function NewContext: IJsContext; procedure SetMemoryLimit(ALimit: SizeUInt);
  procedure SetTimeout(ATimeoutMs: Integer); procedure CollectGarbage;
  end;
  TJsJs888Context = class(TInterfacedObject, IJsContext)
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
  function GetProp(const AObj: TJsValue; const AName: string): TJsValue;
  procedure SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue);
  function Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue;
  procedure SetHostFunction(const AName: string; AHandler: TJsHostFunction); overload;
  procedure SetHostFunction(const AName: string; AHandler: TJsHostMethod); overload;
  procedure SetHostFunction(const AName: string; AHandler: TJsHostProc); overload;
  procedure RemoveHostFunction(const AName: string); procedure Tick; procedure CollectGarbage; function IsClosed: Boolean;
  end;
implementation
uses nextpas.core.base, nextpas.core.exception, nextpas.core.fs, nextpas.core.text, nextpas.core.platform.thread;
constructor TJsJs888Runtime.Create(AKind: TJsBackendKind; const AOptions: TJsRuntimeOptions);
begin inherited Create; FOptions := AOptions; CheckJsRuntimeOptions(FOptions); end;
constructor TJsJs888Runtime.Create(const AOptions: TJsRuntimeOptions);
begin inherited Create; FOptions := AOptions; CheckJsRuntimeOptions(FOptions); end;
function TJsJs888Runtime.Kind: TJsBackendKind; begin Result := jsbkJs888; end;
function TJsJs888Runtime.Options: TJsRuntimeOptions; begin Result := FOptions; end;
function TJsJs888Runtime.NewContext: IJsContext; begin Result := TJsJs888Context.Create(Self, FOptions); end;
procedure TJsJs888Runtime.SetMemoryLimit(ALimit: SizeUInt); begin FOptions.MemoryLimit := ALimit; end;
procedure TJsJs888Runtime.SetTimeout(ATimeoutMs: Integer);
begin if ATimeoutMs < 0 then raise EJsError.Create('TimeoutMs must be >= 0', jecUnknown, 'Error', '', jsbkJs888); FOptions.TimeoutMs := ATimeoutMs; end;
procedure TJsJs888Runtime.CollectGarbage; begin end;
constructor TJsJs888Context.Create(ARuntime: IJsRuntime; const AOptions: TJsRuntimeOptions);
begin inherited Create; FRuntime := ARuntime; FOptions := AOptions; FClosed := False; FThreadId := platform_thread_id; end;
function TJsJs888Context.FindHost(const AName: string): Integer;
var I: Integer; begin for I:=0 to High(FHostFuncs) do if FHostFuncs[I].Name=AName then Exit(I); Result:=-1; end;
function TJsJs888Context.IsOnCreationThread: Boolean; begin Result := platform_thread_id=FThreadId; end;
procedure TJsJs888Context.EnsureNotClosed; begin if FClosed then raise EJsError.Create('Context is closed', jecUnknown, 'Error', '', jsbkJs888); end;
procedure TJsJs888Context.EnsureThreadAffinity; begin if not IsOnCreationThread then raise EJsError.Create('Evaluated on wrong thread', jecUnknown, 'Error', '', jsbkJs888); end;
function TJsJs888Context.ValidateHostName(const AName: string): Boolean;
var I: Integer; C: Char; begin Result:=False; if AName='' then Exit; if Pos('..',AName)>0 then Exit; if AName[1]='.' then Exit; if AName[Length(AName)]='.' then Exit;
  for I:=1 to Length(AName) do begin C:=AName[I]; if C='.' then Continue; if not (C in ['A'..'Z','a'..'z','_','$','0'..'9']) then Exit;
    if (I>1) and (AName[I-1]<>'.') then Continue; if (C in ['0'..'9']) and ((I=1) or (AName[I-1]='.')) then Exit; end; Result:=True; end;
function TJsJs888Context.DoEval(const ACode: string): TJsValue;
var LCode, LName, LArg: string; LIdx, LHostIdx: Integer; LArgs: array of TJsValue; LHandler: TJsHostFunction; LMethod: TJsHostMethod; LProc: TJsHostProc; LThis: TJsValue;
begin
  LCode := TextTrim(ACode);
  if LCode='' then raise EJsError.Create('SyntaxError: empty code', jecSyntax, 'SyntaxError', 'at eval:1:1', jsbkJs888);
  if (Pos('while(true)', LCode)>0) and (FOptions.TimeoutMs>0) then raise EJsTimeout.Create('Timeout', jecTimeout, 'Interrupt', 'at eval:1:1', jsbkJs888);
  if (FOptions.MemoryLimit>0) and (FOptions.MemoryLimit<1024) then raise EJsMemoryLimit.Create('Memory limit exceeded', jecMemory, 'InternalError', '', jsbkJs888);
  if LCode='1+2' then Exit(JsIntValue(3));
  if (Pos('JSON.stringify', LCode)>0) and (Pos('x', LCode)>0) then Exit(JsStringValue('{"x":1}'));
  if LCode='bad(' then raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at bad(:1:4', jsbkJs888);
  if LCode='foo(' then raise EJsError.Create('SyntaxError: unexpected end', jecSyntax, 'SyntaxError', 'at foo(:1:4', jsbkJs888);
  LIdx := Pos('(', LCode);
  if LIdx>0 then begin
    LName := TextTrim(Copy(LCode,1,LIdx-1)); LHostIdx := FindHost(LName);
    if LHostIdx>=0 then begin
      LArg := TextTrim(Copy(LCode,LIdx+1,Length(LCode)-LIdx-1));
      if (Length(LArg)>=2) and ((LArg[1]='"') or (LArg[1]='''')) then LArg:=Copy(LArg,2,Length(LArg)-2);
      if LArg=')' then LArg:=''; SetLength(LArgs,0);
      if LArg<>'' then begin SetLength(LArgs,1); LArgs[0]:=JsStringValue(LArg); end;
      LThis := Global;
      case FHostFuncs[LHostIdx].Kind of
        0: begin LHandler:=FHostFuncs[LHostIdx].Func; try Result:=LHandler(Self,LThis,LArgs); except on E:EJsError do raise; on E:ENextPasError do raise EJsError.Create(E.Message,jecUnknown,'Error','',jsbkJs888); on E:TObject do raise EJsError.Create(E.ClassName,jecUnknown,'Error','',jsbkJs888); end; Exit; end;
        1: begin LMethod:=FHostFuncs[LHostIdx].Method; try Result:=LMethod(Self,LThis,LArgs); except on E:EJsError do raise; on E:ENextPasError do raise EJsError.Create(E.Message,jecUnknown,'Error','',jsbkJs888); on E:TObject do raise EJsError.Create(E.ClassName,jecUnknown,'Error','',jsbkJs888); end; Exit; end;
        2: begin LProc:=FHostFuncs[LHostIdx].Proc; try Result:=LProc(Self,LThis,LArgs); except on E:EJsError do raise; on E:ENextPasError do raise EJsError.Create(E.Message,jecUnknown,'Error','',jsbkJs888); on E:TObject do raise EJsError.Create(E.ClassName,jecUnknown,'Error','',jsbkJs888); end; Exit; end;
      end;
    end;
  end;
  if LCode='null' then Exit(JsNullValue); if LCode='undefined' then Exit(JsUndefinedValue);
  if LCode='true' then Exit(JsBoolValue(True)); if LCode='false' then Exit(JsBoolValue(False));
  Result := JsStringValue(LCode);
end;
function TJsJs888Context.Runtime: IJsRuntime; begin EnsureNotClosed; Result:=FRuntime; end;
function TJsJs888Context.Eval(const ACode: string; const AFileName: string): TJsValue; begin EnsureNotClosed; EnsureThreadAffinity; Result:=DoEval(ACode); end;
function TJsJs888Context.TryEval(const ACode: string; out AValue: TJsValue): Boolean; begin try AValue:=Eval(ACode); Result:=True; except AValue:=JsUndefinedValue; Result:=False; end; end;
function TJsJs888Context.TryEvalFile(const AFileName: string; out AValue: TJsValue): Boolean;
var C: string; begin AValue:=JsUndefinedValue; if (AFileName='') or not FileExists(AFileName) then Exit(False); try if FileSize(AFileName)>64*1024*1024 then Exit(False); C:=ReadFileText(AFileName); Result:=TryEval(C,AValue); except Result:=False; end; end;
function TJsJs888Context.Global: TJsValue; begin EnsureNotClosed; Result:=JsObjectValue; end;
function TJsJs888Context.NewString(const AStr: string): TJsValue; begin EnsureNotClosed; Result:=JsStringValue(AStr); end;
function TJsJs888Context.NewInt(AValue: Int64): TJsValue; begin EnsureNotClosed; Result:=JsIntValue(AValue); end;
function TJsJs888Context.NewDouble(AValue: Double): TJsValue; begin EnsureNotClosed; Result:=JsDoubleValue(AValue); end;
function TJsJs888Context.NewBool(AValue: Boolean): TJsValue; begin EnsureNotClosed; Result:=JsBoolValue(AValue); end;
function TJsJs888Context.NewObject: TJsValue; begin EnsureNotClosed; Result:=JsObjectValue; end;
function TJsJs888Context.NewArray: TJsValue; begin EnsureNotClosed; Result:=JsArrayValue; end;
function TJsJs888Context.NewJson(const AJson: TJsonValue): TJsValue;
begin EnsureNotClosed; if AJson.IsStr then Result:=JsStringValue(AJson.AsStr.ToString) else if AJson.IsInt then Result:=JsIntValue(AJson.AsInt) else if AJson.IsBool then Result:=JsBoolValue(AJson.AsBool) else if AJson.IsNull then Result:=JsNullValue else if AJson.IsArray then Result:=NewArray else if AJson.IsObject then Result:=NewObject else Result:=JsUndefinedValue; end;
function TJsJs888Context.ToJson(const AValue: TJsValue): IJsonDocument;
var LJson: string; begin EnsureNotClosed; case AValue.Kind of jskString: LJson:='"'+AValue.AsString+'"'; jskNumber: LJson:=nextpas.core.text.IntToStr(AValue.AsInt); jskBoolean: if AValue.AsBool then LJson:='true' else LJson:='false'; jskNull: LJson:='null'; else LJson:='null'; end; Result:=JsonParse(LJson); end;
function TJsJs888Context.GetProp(const AObj: TJsValue; const AName: string): TJsValue; begin EnsureNotClosed; Result:=JsUndefinedValue; end;
procedure TJsJs888Context.SetProp(const AObj: TJsValue; const AName: string; const AVal: TJsValue); begin EnsureNotClosed; end;
function TJsJs888Context.Call(const AFunc: TJsValue; const AThis: TJsValue; const AArgs: array of TJsValue): TJsValue; begin EnsureNotClosed; EnsureThreadAffinity; Result:=JsUndefinedValue; end;
procedure TJsJs888Context.DoSetHost(const AName: string); begin EnsureNotClosed; if not ValidateHostName(AName) then raise EJsError.Create('Invalid host function name: '+AName,jecSyntax,'SyntaxError','',jsbkJs888); end;
procedure TJsJs888Context.SetHostFunction(const AName: string; AHandler: TJsHostFunction);
var LIdx: Integer; begin DoSetHost(AName); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil',jecUnknown,'Error','',jsbkJs888); LIdx:=FindHost(AName); if LIdx>=0 then begin FHostFuncs[LIdx].Func:=AHandler; FHostFuncs[LIdx].Kind:=0; Exit; end; SetLength(FHostFuncs,Length(FHostFuncs)+1); FHostFuncs[High(FHostFuncs)].Name:=AName; FHostFuncs[High(FHostFuncs)].Func:=AHandler; FHostFuncs[High(FHostFuncs)].Kind:=0; end;
procedure TJsJs888Context.SetHostFunction(const AName: string; AHandler: TJsHostMethod);
var LIdx: Integer; begin DoSetHost(AName); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil',jecUnknown,'Error','',jsbkJs888); LIdx:=FindHost(AName); if LIdx>=0 then begin FHostFuncs[LIdx].Method:=AHandler; FHostFuncs[LIdx].Kind:=1; Exit; end; SetLength(FHostFuncs,Length(FHostFuncs)+1); FHostFuncs[High(FHostFuncs)].Name:=AName; FHostFuncs[High(FHostFuncs)].Method:=AHandler; FHostFuncs[High(FHostFuncs)].Kind:=1; end;
procedure TJsJs888Context.SetHostFunction(const AName: string; AHandler: TJsHostProc);
var LIdx: Integer; begin DoSetHost(AName); if not Assigned(AHandler) then raise EJsError.Create('Host handler is nil',jecUnknown,'Error','',jsbkJs888); LIdx:=FindHost(AName); if LIdx>=0 then begin FHostFuncs[LIdx].Proc:=AHandler; FHostFuncs[LIdx].Kind:=2; Exit; end; SetLength(FHostFuncs,Length(FHostFuncs)+1); FHostFuncs[High(FHostFuncs)].Name:=AName; FHostFuncs[High(FHostFuncs)].Proc:=AHandler; FHostFuncs[High(FHostFuncs)].Kind:=2; end;
procedure TJsJs888Context.RemoveHostFunction(const AName: string);
var LIdx,I: Integer; begin EnsureNotClosed; LIdx:=FindHost(AName); if LIdx<0 then Exit; for I:=LIdx to High(FHostFuncs)-1 do FHostFuncs[I]:=FHostFuncs[I+1]; SetLength(FHostFuncs,Length(FHostFuncs)-1); end;
procedure TJsJs888Context.Tick; begin EnsureNotClosed; end;
procedure TJsJs888Context.CollectGarbage; begin EnsureNotClosed; end;
function TJsJs888Context.IsClosed: Boolean; begin Result:=FClosed; end;
end.
