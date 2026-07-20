function TConfig.ToJson: string;
var
  LEntries: TConfigEntryArray;
  LCount: Integer;
begin
  SnapshotConfigEntries(Self, LEntries, LCount);
  Result := ConfigEntriesToJson(LEntries, LCount);
end;

function TConfig.ToIni: string;
var
  LEntries: TConfigEntryArray;
  LCount: Integer;
begin
  SnapshotConfigEntries(Self, LEntries, LCount);
  Result := ConfigEntriesToIni(LEntries, LCount);
end;

procedure TConfig.SaveToIni(const APath: string);
begin
  ConfigWriteAtomicText(APath, ToIni);
end;

procedure TConfig.SaveToJson(const APath: string);
begin
  ConfigWriteAtomicText(APath, ToJson);
end;

function TConfig.ToYaml: string;
var
  LEntries: TConfigEntryArray;
  LCount: Integer;
begin
  SnapshotConfigEntries(Self, LEntries, LCount);
  Result := ConfigEntriesToYaml(LEntries, LCount);
end;

procedure TConfig.SaveToYaml(const APath: string);
begin
  ConfigWriteAtomicText(APath, ToYaml);
end;

function TConfig.ToToml: string;
var
  LEntries: TConfigEntryArray;
  LCount: Integer;
begin
  SnapshotConfigEntries(Self, LEntries, LCount);
  Result := ConfigEntriesToToml(LEntries, LCount);
end;

procedure TConfig.SaveToToml(const APath: string);
begin
  ConfigWriteAtomicText(APath, ToToml);
end;

