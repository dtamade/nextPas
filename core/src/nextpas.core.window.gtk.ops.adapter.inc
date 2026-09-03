{ nextpas.core.window.gtk.ops.adapter.inc — TGtkOpsAdapter 薄转发单源（显式 include 零重复）

  由 nextpas.core.window.gtk.impl 显式 include，单源驱动 via fields.inc 字段表，复用 bytes.ops 单源思想，守四件套与 L0-L3。
  性能：外联单源（非 inline）避 140+ 点 I-Cache 复制（7后端调用点×20方法≈140展开点），仅 1行 accessor（WindowGtkTotalLiveCount/WindowGtkLiveAdjust/GtkOpsWrap）保留 inline 零额外调用，Assigned 折叠 nil 守卫，单次字段间接零虚表零额外堆分配。
  稳定性：nil 守卫不丢释放，队列 Clear 逐条 nil 释放由 TWindowQueue 单源托管，DropAll 原子摘除+ g_source_remove try-finally 不丢。 }

function TGtkOpsAdapter.TryLoad(out ALoaded: Boolean): Boolean;
begin
  if Assigned(FRec.TryLoad) then Result := FRec.TryLoad(ALoaded) else begin ALoaded := False; Result := False; end;
end;

function TGtkOpsAdapter.IdleAddFull(APriority: gint; AFunc: TGtkIdleFunc; AUserData: Pointer; ANotify: TGDestroyNotify): guint;
begin
  if Assigned(FRec.IdleAddFull) then Result := FRec.IdleAddFull(APriority, AFunc, AUserData, ANotify) else Result := 0;
end;

function TGtkOpsAdapter.SourceRemove(ATag: guint): gboolean;
begin
  if Assigned(FRec.SourceRemove) then Result := FRec.SourceRemove(ATag) else Result := 0;
end;

function TGtkOpsAdapter.SignalConnectData(AInstance: Pointer; ADetailedSignal: PAnsiChar; AHandler: Pointer; AData: Pointer; ADestroyData: TGDestroyNotify; AConnectFlags: guint): gulong;
begin
  if Assigned(FRec.SignalConnectData) then Result := FRec.SignalConnectData(AInstance, ADetailedSignal, AHandler, AData, ADestroyData, AConnectFlags) else Result := 0;
end;

procedure TGtkOpsAdapter.SignalHandlerDisconnect(AInstance: Pointer; AHandlerId: gulong);
begin
  if Assigned(FRec.SignalHandlerDisconnect) then FRec.SignalHandlerDisconnect(AInstance, AHandlerId);
end;

function TGtkOpsAdapter.InitCheck(AArgc: PInt32; AArgv: PPAnsiChar): gboolean;
begin
  if Assigned(FRec.InitCheck) then Result := FRec.InitCheck(AArgc, AArgv) else Result := 0;
end;

function TGtkOpsAdapter.WindowNew(AType: gint): Pointer;
begin
  if Assigned(FRec.WindowNew) then Result := FRec.WindowNew(AType) else Result := nil;
end;

procedure TGtkOpsAdapter.WindowSetTitle(AWindow: Pointer; ATitle: PAnsiChar);
begin
  if Assigned(FRec.WindowSetTitle) then FRec.WindowSetTitle(AWindow, ATitle);
end;

function TGtkOpsAdapter.WindowGetTitle(AWindow: Pointer): PAnsiChar;
begin
  if Assigned(FRec.WindowGetTitle) then Result := FRec.WindowGetTitle(AWindow) else Result := nil;
end;

procedure TGtkOpsAdapter.WindowSetDefaultSize(AWindow: Pointer; AWidth, AHeight: gint);
begin
  if Assigned(FRec.WindowSetDefaultSize) then FRec.WindowSetDefaultSize(AWindow, AWidth, AHeight);
end;

procedure TGtkOpsAdapter.WindowSetResizable(AWindow: Pointer; AResizable: gboolean);
begin
  if Assigned(FRec.WindowSetResizable) then FRec.WindowSetResizable(AWindow, AResizable);
end;

procedure TGtkOpsAdapter.WindowResize(AWindow: Pointer; AWidth, AHeight: gint);
begin
  if Assigned(FRec.WindowResize) then FRec.WindowResize(AWindow, AWidth, AHeight);
end;

procedure TGtkOpsAdapter.WindowMaximize(AWindow: Pointer);
begin
  if Assigned(FRec.WindowMaximize) then FRec.WindowMaximize(AWindow);
end;

procedure TGtkOpsAdapter.WindowUnmaximize(AWindow: Pointer);
begin
  if Assigned(FRec.WindowUnmaximize) then FRec.WindowUnmaximize(AWindow);
end;

procedure TGtkOpsAdapter.WindowIconify(AWindow: Pointer);
begin
  if Assigned(FRec.WindowIconify) then FRec.WindowIconify(AWindow);
end;

procedure TGtkOpsAdapter.WindowDeiconify(AWindow: Pointer);
begin
  if Assigned(FRec.WindowDeiconify) then FRec.WindowDeiconify(AWindow);
end;

function TGtkOpsAdapter.WindowIsMaximized(AWindow: Pointer): gboolean;
begin
  if Assigned(FRec.WindowIsMaximized) then Result := FRec.WindowIsMaximized(AWindow) else Result := 0;
end;

procedure TGtkOpsAdapter.WidgetShowAll(AWidget: Pointer);
begin
  if Assigned(FRec.WidgetShowAll) then FRec.WidgetShowAll(AWidget);
end;

procedure TGtkOpsAdapter.WidgetHide(AWidget: Pointer);
begin
  if Assigned(FRec.WidgetHide) then FRec.WidgetHide(AWidget);
end;

function TGtkOpsAdapter.WidgetGetVisible(AWidget: Pointer): gboolean;
begin
  if Assigned(FRec.WidgetGetVisible) then Result := FRec.WidgetGetVisible(AWidget) else Result := 0;
end;

function TGtkOpsAdapter.WidgetGetScaleFactor(AWidget: Pointer): gint;
begin
  if Assigned(FRec.WidgetGetScaleFactor) then Result := FRec.WidgetGetScaleFactor(AWidget) else Result := 1;
end;

procedure TGtkOpsAdapter.WidgetGrabFocus(AWidget: Pointer);
begin
  if Assigned(FRec.WidgetGrabFocus) then FRec.WidgetGrabFocus(AWidget);
end;

function TGtkOpsAdapter.WidgetGetWindow(AWidget: Pointer): Pointer;
begin
  if Assigned(FRec.WidgetGetWindow) then Result := FRec.WidgetGetWindow(AWidget) else Result := nil;
end;

procedure TGtkOpsAdapter.WidgetDestroy(AWidget: Pointer);
begin
  if Assigned(FRec.WidgetDestroy) then FRec.WidgetDestroy(AWidget);
end;

function TGtkOpsAdapter.WidgetGetAllocatedWidth(AWidget: Pointer): gint;
begin
  if Assigned(FRec.WidgetGetAllocatedWidth) then Result := FRec.WidgetGetAllocatedWidth(AWidget) else Result := 0;
end;

function TGtkOpsAdapter.WidgetGetAllocatedHeight(AWidget: Pointer): gint;
begin
  if Assigned(FRec.WidgetGetAllocatedHeight) then Result := FRec.WidgetGetAllocatedHeight(AWidget) else Result := 0;
end;

function TGtkOpsAdapter.GdkWindowGetState(AWindow: Pointer): guint;
begin
  if Assigned(FRec.GdkWindowGetState) then Result := FRec.GdkWindowGetState(AWindow) else Result := 0;
end;

procedure TGtkOpsAdapter.Main;
begin
  if Assigned(FRec.Main) then FRec.Main();
end;

procedure TGtkOpsAdapter.MainQuit;
begin
  if Assigned(FRec.MainQuit) then FRec.MainQuit();
end;

function TGtkOpsAdapter.MainIterationDo(ABlocking: gboolean): gboolean;
begin
  if Assigned(FRec.MainIterationDo) then Result := FRec.MainIterationDo(ABlocking) else Result := 0;
end;

function TGtkOpsAdapter.EventsPending: gboolean;
begin
  if Assigned(FRec.EventsPending) then Result := FRec.EventsPending() else Result := 0;
end;
