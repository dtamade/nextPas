procedure TConfig.SetDefault(const AKey, AValue: string);
begin
  RequireConfigKey(AKey);
  FLock.AcquireWrite;
  try
    if FindIndex(AKey) < 0 then
      SetValueUnlocked(AKey, AValue);
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.DeleteKey(const AKey: string);
begin
  RequireConfigKey(AKey);
  FLock.AcquireWrite;
  try
    DeleteKeyUnlocked(AKey);
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.DeleteSection(const APrefix: string);
begin
  RequireConfigPrefix(APrefix);
  FLock.AcquireWrite;
  try
    DeleteSectionUnlocked(APrefix);
  finally
    FLock.ReleaseWrite;
  end;
end;

procedure TConfig.Clear;
begin
  FLock.AcquireWrite;
  try
    ClearUnlocked;
  finally
    FLock.ReleaseWrite;
  end;
end;
