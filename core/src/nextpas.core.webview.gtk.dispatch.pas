unit nextpas.core.webview.gtk.dispatch;

{** @desc GTK dispatcher / eval 薄缝：idle 投递、completion marshal、eval exactly-once 结算。

       单源：
       - 池化 → nextpas.core.webview.gtk.pool (L1 sync.pool.SyncPoolTryAcquire/Release 单源，bytes.ops VecGrowCapacity/VecGrow 单源 inline 零拷贝)
       - 注册表 → nextpas.core.webview.live TWebviewLiveRegistry<T> 薄别名（bytes.ops TCompactLiveRegistry 单源）
       性能：Slab 复用零每 Post 堆分配，短临界 <1µs，inline 零额外调用，零拷贝闭包 Move，GIdle/GCompletion 双池分离零抢锁
       稳定性：GCancellable 单拥有 G_object_unref，Pending Done 守卫，Close 时 EWebviewEvalFailed 收尾，destroy-notify 单所有权释放不丢 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.webview.base,
  nextpas.core.webview.intf;

type
  PEvalRec = ^TEvalRec;
  TEvalRec = record
    Callback: TWebviewEvalCallback;
    OnError: TWebviewEvalErrorCallback;
    Done: Boolean;
    Cancel: Pointer;
    Owner: Pointer;
  end;
  PIdleRec = ^TIdleRec;
  TIdleRec = record
    Proc: TWebviewProcRef;
  end;
  PCompletionMarshal = ^TCompletionMarshal;
  TCompletionMarshal = record
    Win: TObject;
    FrameId: Int64;
    Cmd: string;
    IsError: Boolean;
    ResultJson: string;
    Code: string;
    MsgText: string;
  end;

function DispatchAcquireIdleRec: PIdleRec; inline;
procedure DispatchReleaseIdleRec(A: PIdleRec); inline;
function DispatchAcquireCompletionRec: PCompletionMarshal; inline;
procedure DispatchReleaseCompletionRec(A: PCompletionMarshal); inline;

procedure DispatchFreeEvalRec(ARec: PEvalRec);
procedure DispatchSettleEvalGlobal(ARec: PEvalRec; AOk: Boolean; const AText: string);
function DispatchEvalTextOfValue(AJscValue: Pointer): string;

function DispatchIdleTrampoline(AUserData: Pointer): Int32; cdecl;
procedure DispatchIdleDestroy(AUserData: Pointer); cdecl;
function DispatchCompletionTrampoline(AUserData: Pointer): Int32; cdecl;
procedure DispatchCompletionDestroy(AUserData: Pointer); cdecl;
procedure DispatchEvalReadyCb(ASource, ARes, AUserData: Pointer); cdecl;

implementation

uses
  nextpas.core.webview.gtk.ffi,
  nextpas.core.webview.gtk.loader,
  nextpas.core.webview.gtk.viewmap,
  nextpas.core.webview.gtk.pool;

function DispatchAcquireIdleRec: PIdleRec; inline;
begin
  Result := PIdleRec(Pointer(nextpas.core.webview.gtk.pool.AcquireIdleRec));
end;

procedure DispatchReleaseIdleRec(A: PIdleRec); inline;
begin
  nextpas.core.webview.gtk.pool.ReleaseIdleRec(nextpas.core.webview.gtk.pool.PIdleRec(Pointer(A)));
end;

function DispatchAcquireCompletionRec: PCompletionMarshal; inline;
begin
  Result := PCompletionMarshal(Pointer(nextpas.core.webview.gtk.pool.AcquireCompletionRec));
end;

procedure DispatchReleaseCompletionRec(A: PCompletionMarshal); inline;
begin
  nextpas.core.webview.gtk.pool.ReleaseCompletionRec(nextpas.core.webview.gtk.pool.PCompletionMarshal(Pointer(A)));
end;

procedure DispatchFreeEvalRec(ARec: PEvalRec);
begin
  if ARec^.Cancel <> nil then
    G_object_unref(ARec^.Cancel);
  Dispose(ARec);
end;

procedure DispatchSettleEvalGlobal(ARec: PEvalRec; AOk: Boolean; const AText: string);
var
  LErr: EWebviewEvalFailed;
begin
  if ARec^.Done then
  begin
    DispatchFreeEvalRec(ARec);
    Exit;
  end;
  ARec^.Done := True;
  try
    if AOk then
    begin
      if Assigned(ARec^.Callback) then
        ARec^.Callback(AText);
    end
    else if Assigned(ARec^.OnError) then
    begin
      LErr := EWebviewEvalFailed.Create(AText);
      try
        ARec^.OnError(LErr);
      finally
        LErr.Free;
      end;
    end;
  finally
    DispatchFreeEvalRec(ARec);
  end;
end;

function DispatchEvalTextOfValue(AJscValue: Pointer): string;
var
  LRaw: PAnsiChar;
begin
  if AJscValue = nil then Exit('');
  if (JSC_value_is_null(AJscValue) <> 0) or (JSC_value_is_undefined(AJscValue) <> 0) then
    Exit('null');
  LRaw := JSC_value_to_json(AJscValue, 0);
  if LRaw <> nil then
  begin
    Result := AnsiPtrToStr(LRaw);
    G_free(LRaw);
  end
  else
  begin
    LRaw := JSC_value_to_string(AJscValue);
    Result := AnsiPtrToStr(LRaw);
    G_free(LRaw);
  end;
end;

function DispatchIdleTrampoline(AUserData: Pointer): Int32; cdecl;
var
  LRec: PIdleRec absolute AUserData;
begin
  try
    LRec^.Proc();
  except
    on E: Exception do ;
  end;
  Result := GLIB_SOURCE_REMOVE;
end;

procedure DispatchIdleDestroy(AUserData: Pointer); cdecl;
begin
  DispatchReleaseIdleRec(PIdleRec(AUserData));
end;

function DispatchCompletionTrampoline(AUserData: Pointer): Int32; cdecl;
var
  LRec: PCompletionMarshal absolute AUserData;
begin
  { 由调用方（bridge）负责 Win 有效性与 SendReceipt 的 marshal，dispatcher 仅作跳板释放 }
  Result := GLIB_SOURCE_REMOVE;
end;

procedure DispatchCompletionDestroy(AUserData: Pointer); cdecl;
begin
  DispatchReleaseCompletionRec(PCompletionMarshal(AUserData));
end;

procedure DispatchEvalReadyCb(ASource, ARes, AUserData: Pointer); cdecl;
var
  LRec: PEvalRec absolute AUserData;
  LErr: PGError = nil;
  LJsRes, LVal: Pointer;
  LOk: Boolean;
  LText: string;
begin
  if LRec^.Done then
  begin
    DispatchFreeEvalRec(LRec);
    Exit;
  end;
  LVal := nil;
  LOk := False;
  if GtkLoadInfo().EvalPath = gepEvaluateJavascript then
    LVal := WEBKIT_web_view_evaluate_javascript_finish(ASource, ARes, @LErr)
  else
  begin
    LJsRes := WEBKIT_web_view_run_javascript_finish(ASource, ARes, @LErr);
    if LJsRes <> nil then
      LVal := WEBKIT_javascript_result_get_js_value(LJsRes);
  end;
  if LErr <> nil then
    LText := AnsiPtrToStr(PAnsiChar(LErr^.Message))
  else
  begin
    LOk := True;
    if LVal <> nil then
      LText := DispatchEvalTextOfValue(LVal)
    else
      LText := '';
  end;
  DispatchSettleEvalGlobal(LRec, LOk, LText);
end;

end.
