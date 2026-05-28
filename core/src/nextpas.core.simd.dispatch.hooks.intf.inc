type
  TSimdDispatchChangedHook = procedure;

procedure AddDispatchChangedHook(hook: TSimdDispatchChangedHook);
procedure RemoveDispatchChangedHook(hook: TSimdDispatchChangedHook);
procedure SetDispatchChangedHook(hook: TSimdDispatchChangedHook);
