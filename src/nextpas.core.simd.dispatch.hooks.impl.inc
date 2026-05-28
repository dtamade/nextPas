function HasDispatchChangedHook(hook: TSimdDispatchChangedHook): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  if not Assigned(hook) then
    Exit;

  for LIndex := 0 to High(g_DispatchChangedHooks) do
    if g_DispatchChangedHooks[LIndex] = hook then
      Exit(True);
end;

procedure NotifyDispatchChangedHooks;
var
  LHooks: array of TSimdDispatchChangedHook;
  LHook: TSimdDispatchChangedHook;
begin
  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_DispatchHooksLock);
  try
    LHooks := Copy(g_DispatchChangedHooks);
  finally
    LeaveCriticalSection(g_DispatchHooksLock);
  end;

  for LHook in LHooks do
    if Assigned(LHook) then
      LHook;
end;

procedure SetDispatchChangedHook(hook: TSimdDispatchChangedHook);
begin
  AddDispatchChangedHook(hook);
end;

procedure AddDispatchChangedHook(hook: TSimdDispatchChangedHook);
begin
  if not Assigned(hook) then
    Exit;

  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_DispatchHooksLock);
  try
    if HasDispatchChangedHook(hook) then
      Exit;
    SetLength(g_DispatchChangedHooks, Length(g_DispatchChangedHooks) + 1);
    g_DispatchChangedHooks[High(g_DispatchChangedHooks)] := hook;
  finally
    LeaveCriticalSection(g_DispatchHooksLock);
  end;

  if g_DispatchState = 2 then
    hook;
end;

procedure RemoveDispatchChangedHook(hook: TSimdDispatchChangedHook);
var
  LIndex: Integer;
  LTailIndex: Integer;
begin
  if not Assigned(hook) then
    Exit;

  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_DispatchHooksLock);
  try
    for LIndex := 0 to High(g_DispatchChangedHooks) do
    begin
      if g_DispatchChangedHooks[LIndex] <> hook then
        Continue;

      for LTailIndex := LIndex to High(g_DispatchChangedHooks) - 1 do
        g_DispatchChangedHooks[LTailIndex] := g_DispatchChangedHooks[LTailIndex + 1];
      SetLength(g_DispatchChangedHooks, Length(g_DispatchChangedHooks) - 1);
      Break;
    end;
  finally
    LeaveCriticalSection(g_DispatchHooksLock);
  end;
end;
