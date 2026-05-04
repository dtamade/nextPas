unit target_config;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  ETargetConfigError = class(Exception);

  TToolchainBindingConfig = record
    BindingPath: string;
    BindingId: string;
    HostId: string;
    TargetId: string;
    BackendFamily: string;
    HostCompilerExecutable: string;
    HostCompilerProfileId: string;
    AssemblerProfileId: string;
    LinkerProfileId: string;
    ArchiverProfileId: string;
    ResourceToolProfileId: string;
    SysrootMode: string;
    RuntimeSdkId: string;
    AllowHostFallback: Boolean;
    HasAllowHostFallback: Boolean;
    ToolRootKind: string;
    RuntimeRootKind: string;
    ResponseFilePolicy: string;
    LinkScriptPolicy: string;
    LlvmEnabled: Boolean;
    HasLlvmEnabled: Boolean;
    LlvmExecutableSetId: string;
  end;

  TTargetConfig = record
    ConfigPath: string;
    TargetId: string;
    HostId: string;
    HostOS: string;
    HostCPU: string;
    CompilerExecutable: string;
    UnitsDir: string;
    DistributionBinDir: string;
    DistributionLibDir: string;
    DistributionShareDir: string;
    ObjectFormat: string;
    AssemblerFlavor: string;
    LinkerFlavor: string;
    RuntimeLayoutKey: string;
    CSymbolPrefix: string;
    HasCSymbolPrefix: Boolean;
    CLibraryNaming: string;
    LlvmTriple: string;
    LlvmDataLayout: string;
    ToolchainBindingPath: string;
    ToolchainBindingId: string;
    HostCompilerProfileId: string;
    BackendFamily: string;
    AssemblerProfileId: string;
    LinkerProfileId: string;
    ArchiverProfileId: string;
    ResourceToolProfileId: string;
    SysrootMode: string;
    RuntimeSdkId: string;
    AllowHostFallback: Boolean;
    ToolRootKind: string;
    RuntimeRootKind: string;
    ResponseFilePolicy: string;
    LinkScriptPolicy: string;
    LlvmEnabled: Boolean;
    LlvmExecutableSetId: string;
  end;

function LoadTargetConfig(
  const TargetName: string;
  const ExecutablePath: string;
  const ToolchainBindingOverride: string = ''
): TTargetConfig;

implementation

function TrimQuotes(const Value: string): string;
begin
  Result := Trim(Value);
  if (Length(Result) >= 2) and (Result[1] = '"') and
    (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function ResolveConfigPath(
  const TargetName: string;
  const ExecutablePath: string
): string;
var
  CandidatePath: string;
  ExecutableDir: string;
  ParentDir: string;
  RepoRoot: string;
begin
  RepoRoot := GetEnvironmentVariable('NEXTPAS_REPO_ROOT');
  if RepoRoot <> '' then
  begin
    CandidatePath := ExpandFileName(
      IncludeTrailingPathDelimiter(RepoRoot) + 'build' + DirectorySeparator +
      'targets' + DirectorySeparator + TargetName + '.toml'
    );
    if FileExists(CandidatePath) then
      Exit(CandidatePath);
  end;

  ExecutableDir := ExtractFileDir(ExpandFileName(ExecutablePath));
  RepoRoot := ExecutableDir;
  while RepoRoot <> '' do
  begin
    CandidatePath := ExpandFileName(
      IncludeTrailingPathDelimiter(RepoRoot) + 'build' + DirectorySeparator +
      'targets' + DirectorySeparator + TargetName + '.toml'
    );
    if FileExists(CandidatePath) then
      Exit(CandidatePath);

    ParentDir := ExpandFileName(
      IncludeTrailingPathDelimiter(RepoRoot) + '..'
    );
    if ParentDir = RepoRoot then
      Break;
    RepoRoot := ParentDir;
  end;

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ExecutableDir) + '..' + DirectorySeparator + '..' +
    DirectorySeparator + 'build' + DirectorySeparator + 'targets' +
    DirectorySeparator + TargetName + '.toml'
  );
end;

function ResolveConfigRelativePath(
  const AConfigPath: string;
  const AValue: string
): string;
begin
  if AValue = '' then
    Exit('');

  if ExtractFileDrive(AValue) <> '' then
    Exit(ExpandFileName(AValue));

  if (Length(AValue) > 0) and (AValue[1] = DirectorySeparator) then
    Exit(ExpandFileName(AValue));

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(AConfigPath)) + '..' +
    DirectorySeparator + '..' + DirectorySeparator + AValue
  );
end;

function ResolveToolchainBindingPath(
  const AConfigPath: string;
  const AValue: string
): string;
begin
  if AValue = '' then
    Exit('');

  if ExtractFileDrive(AValue) <> '' then
    Exit(ExpandFileName(AValue));

  if (Length(AValue) > 0) and (AValue[1] = DirectorySeparator) then
    Exit(ExpandFileName(AValue));

  if (Pos(DirectorySeparator, AValue) > 0) or
    SameText(ExtractFileExt(AValue), '.toml') then
    Exit(ResolveConfigRelativePath(AConfigPath, AValue));

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(AConfigPath)) + '..' +
    DirectorySeparator + 'toolchains' + DirectorySeparator + AValue + '.toml'
  );
end;

function BuildHostId(const AHostOS: string; const AHostCPU: string): string;
begin
  if (Trim(AHostOS) = '') or (Trim(AHostCPU) = '') then
    Exit('');

  Result := Trim(AHostOS) + '-' + Trim(AHostCPU);
end;

function ParseBooleanLiteral(
  const Value: string;
  const FieldName: string
): Boolean;
var
  NormalizedValue: string;
begin
  NormalizedValue := LowerCase(Trim(Value));
  if NormalizedValue = 'true' then
    Exit(True);
  if NormalizedValue = 'false' then
    Exit(False);

  raise ETargetConfigError.Create(
    'target-config-invalid-boolean: ' + FieldName + '=' + Value
  );
end;

procedure AssignConfigField(
  var Config: TTargetConfig;
  const Key: string;
  const Value: string
);
begin
  if Key = 'target' then
    Config.TargetId := Value
  else if Key = 'host_os' then
    Config.HostOS := Value
  else if Key = 'host_cpu' then
    Config.HostCPU := Value
  else if Key = 'compiler' then
    Config.CompilerExecutable := Value
  else if Key = 'units_dir' then
    Config.UnitsDir := Value
  else if Key = 'distribution_bin_dir' then
    Config.DistributionBinDir := Value
  else if Key = 'distribution_lib_dir' then
    Config.DistributionLibDir := Value
  else if Key = 'distribution_share_dir' then
    Config.DistributionShareDir := Value
  else if Key = 'object_format' then
    Config.ObjectFormat := Value
  else if Key = 'assembler_flavor' then
    Config.AssemblerFlavor := Value
  else if Key = 'linker_flavor' then
    Config.LinkerFlavor := Value
  else if Key = 'runtime_layout_key' then
    Config.RuntimeLayoutKey := Value
  else if Key = 'c_symbol_prefix' then
  begin
    Config.CSymbolPrefix := Value;
    Config.HasCSymbolPrefix := True;
  end
  else if Key = 'c_library_naming' then
    Config.CLibraryNaming := Value
  else if Key = 'llvm_triple' then
    Config.LlvmTriple := Value
  else if Key = 'llvm_data_layout' then
    Config.LlvmDataLayout := Value
  else if Key = 'toolchain_binding' then
    Config.ToolchainBindingPath := Value;
end;

procedure ParseConfigLine(
  var Config: TTargetConfig;
  const Line: string
);
var
  SeparatorIndex: SizeInt;
  Key: string;
  TrimmedLine: string;
  Value: string;
begin
  TrimmedLine := Trim(Line);
  if TrimmedLine = '' then
    Exit;

  if TrimmedLine[1] = '#' then
    Exit;

  SeparatorIndex := Pos('=', TrimmedLine);
  if SeparatorIndex = 0 then
    Exit;

  Key := Trim(Copy(TrimmedLine, 1, SeparatorIndex - 1));
  Value := TrimQuotes(Copy(TrimmedLine, SeparatorIndex + 1, MaxInt));
  AssignConfigField(Config, Key, Value);
end;

procedure RequireField(const Value: string; const FieldName: string);
begin
  if Value = '' then
    raise ETargetConfigError.Create('target-config-missing-field: ' + FieldName);
end;

procedure RequireFlag(const AssignedValue: Boolean; const FieldName: string);
begin
  if not AssignedValue then
    raise ETargetConfigError.Create('target-config-missing-field: ' + FieldName);
end;

procedure AssignToolchainField(
  var Binding: TToolchainBindingConfig;
  const SectionName: string;
  const Key: string;
  const Value: string
);
begin
  if (SectionName = '') or (SectionName = 'binding') then
  begin
    if (Key = 'binding_id') or ((SectionName = 'binding') and (Key = 'id')) then
      Binding.BindingId := Value
    else if Key = 'host' then
      Binding.HostId := Value
    else if Key = 'target' then
      Binding.TargetId := Value
    else if Key = 'backend_family' then
      Binding.BackendFamily := Value
    else if Key = 'host_compiler' then
      Binding.HostCompilerExecutable := Value
    else if Key = 'host_compiler_profile' then
      Binding.HostCompilerProfileId := Value
    else if Key = 'sysroot_mode' then
      Binding.SysrootMode := Value
    else if Key = 'runtime_sdk' then
      Binding.RuntimeSdkId := Value
    else if Key = 'allow_host_fallback' then
    begin
      Binding.AllowHostFallback := ParseBooleanLiteral(Value, Key);
      Binding.HasAllowHostFallback := True;
    end;
  end
  else if SectionName = 'profiles' then
  begin
    if Key = 'assembler' then
      Binding.AssemblerProfileId := Value
    else if Key = 'linker' then
      Binding.LinkerProfileId := Value
    else if Key = 'archiver' then
      Binding.ArchiverProfileId := Value
    else if Key = 'resource' then
      Binding.ResourceToolProfileId := Value;
  end
  else if SectionName = 'sysroot' then
  begin
    if Key = 'mode' then
      Binding.SysrootMode := Value
    else if Key = 'runtime_sdk' then
      Binding.RuntimeSdkId := Value
    else if Key = 'allow_host_fallback' then
    begin
      Binding.AllowHostFallback := ParseBooleanLiteral(Value, Key);
      Binding.HasAllowHostFallback := True;
    end;
  end
  else if SectionName = 'llvm' then
  begin
    if Key = 'enabled' then
    begin
      Binding.LlvmEnabled := ParseBooleanLiteral(Value, Key);
      Binding.HasLlvmEnabled := True;
    end
    else if Key = 'executable_set' then
      Binding.LlvmExecutableSetId := Value;
  end
  else if SectionName = 'resolution' then
  begin
    if Key = 'tool_root_kind' then
      Binding.ToolRootKind := Value
    else if Key = 'runtime_root_kind' then
      Binding.RuntimeRootKind := Value
    else if Key = 'response_files' then
      Binding.ResponseFilePolicy := Value
    else if Key = 'link_scripts' then
      Binding.LinkScriptPolicy := Value;
  end;
end;

procedure ParseToolchainLine(
  var Binding: TToolchainBindingConfig;
  var CurrentSection: string;
  const Line: string
);
var
  SeparatorIndex: SizeInt;
  Key: string;
  TrimmedLine: string;
  Value: string;
begin
  TrimmedLine := Trim(Line);
  if TrimmedLine = '' then
    Exit;

  if TrimmedLine[1] = '#' then
    Exit;

  if (TrimmedLine[1] = '[') and (TrimmedLine[Length(TrimmedLine)] = ']') then
  begin
    CurrentSection := LowerCase(
      Trim(Copy(TrimmedLine, 2, Length(TrimmedLine) - 2))
    );
    Exit;
  end;

  SeparatorIndex := Pos('=', TrimmedLine);
  if SeparatorIndex = 0 then
    Exit;

  Key := LowerCase(Trim(Copy(TrimmedLine, 1, SeparatorIndex - 1)));
  Value := TrimQuotes(Copy(TrimmedLine, SeparatorIndex + 1, MaxInt));
  AssignToolchainField(Binding, CurrentSection, Key, Value);
end;

function LoadToolchainBinding(
  const ABindingPath: string;
  const AHostId: string;
  const ATargetId: string;
  const ACompilerExecutable: string
): TToolchainBindingConfig;
var
  CurrentSection: string;
  Lines: TStringList;
  Index: Integer;
begin
  Result.BindingPath := ABindingPath;
  if not FileExists(Result.BindingPath) then
    raise ETargetConfigError.Create(
      'missing-toolchain-binding: ' + Result.BindingPath
    );

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Result.BindingPath);
    CurrentSection := '';
    for Index := 0 to Lines.Count - 1 do
      ParseToolchainLine(Result, CurrentSection, Lines[Index]);
  finally
    Lines.Free;
  end;

  RequireField(Result.BindingId, 'binding_id');
  RequireField(Result.HostId, 'host');
  RequireField(Result.TargetId, 'target');
  RequireField(Result.BackendFamily, 'backend_family');
  RequireField(Result.HostCompilerExecutable, 'host_compiler');
  RequireField(Result.HostCompilerProfileId, 'host_compiler_profile');
  RequireField(Result.AssemblerProfileId, 'profiles.assembler');
  RequireField(Result.LinkerProfileId, 'profiles.linker');
  RequireField(Result.ArchiverProfileId, 'profiles.archiver');
  RequireField(Result.ResourceToolProfileId, 'profiles.resource');
  RequireField(Result.SysrootMode, 'sysroot_mode');
  RequireField(Result.RuntimeSdkId, 'runtime_sdk');
  RequireFlag(Result.HasAllowHostFallback, 'allow_host_fallback');
  RequireField(Result.ToolRootKind, 'resolution.tool_root_kind');
  RequireField(Result.RuntimeRootKind, 'resolution.runtime_root_kind');
  RequireField(Result.ResponseFilePolicy, 'resolution.response_files');
  RequireField(Result.LinkScriptPolicy, 'resolution.link_scripts');
  RequireFlag(Result.HasLlvmEnabled, 'llvm.enabled');
  RequireField(Result.LlvmExecutableSetId, 'llvm.executable_set');

  if Result.HostId <> AHostId then
    raise ETargetConfigError.Create(
      'toolchain-binding-host-mismatch: ' + Result.HostId + ' <> ' + AHostId
    );

  if Result.TargetId <> ATargetId then
    raise ETargetConfigError.Create(
      'toolchain-binding-target-mismatch: ' + Result.TargetId + ' <> ' + ATargetId
    );

  if Result.HostCompilerExecutable <> ACompilerExecutable then
    raise ETargetConfigError.Create(
      'toolchain-binding-compiler-mismatch: ' + Result.HostCompilerExecutable +
      ' <> ' + ACompilerExecutable
    );
end;

function LoadTargetConfig(
  const TargetName: string;
  const ExecutablePath: string;
  const ToolchainBindingOverride: string
): TTargetConfig;
var
  Binding: TToolchainBindingConfig;
  HostId: string;
  Lines: TStringList;
  Index: Integer;
begin
  Result.ConfigPath := ResolveConfigPath(TargetName, ExecutablePath);

  if not FileExists(Result.ConfigPath) then
    raise ETargetConfigError.Create('unsupported target: ' + TargetName);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Result.ConfigPath);
    for Index := 0 to Lines.Count - 1 do
      ParseConfigLine(Result, Lines[Index]);
  finally
    Lines.Free;
  end;

  RequireField(Result.TargetId, 'target');
  RequireField(Result.HostOS, 'host_os');
  RequireField(Result.HostCPU, 'host_cpu');
  RequireField(Result.CompilerExecutable, 'compiler');
  RequireField(Result.UnitsDir, 'units_dir');
  RequireField(Result.DistributionBinDir, 'distribution_bin_dir');
  RequireField(Result.DistributionLibDir, 'distribution_lib_dir');
  RequireField(Result.DistributionShareDir, 'distribution_share_dir');
  RequireField(Result.ObjectFormat, 'object_format');
  RequireField(Result.AssemblerFlavor, 'assembler_flavor');
  RequireField(Result.LinkerFlavor, 'linker_flavor');
  RequireField(Result.RuntimeLayoutKey, 'runtime_layout_key');
  RequireFlag(Result.HasCSymbolPrefix, 'c_symbol_prefix');
  RequireField(Result.CLibraryNaming, 'c_library_naming');
  RequireField(Result.LlvmTriple, 'llvm_triple');
  RequireField(Result.LlvmDataLayout, 'llvm_data_layout');
  RequireField(Result.ToolchainBindingPath, 'toolchain_binding');

  if Result.TargetId <> TargetName then
    raise ETargetConfigError.Create(
      'target-config-mismatch: ' + Result.TargetId + ' <> ' + TargetName
    );

  Result.UnitsDir := ResolveConfigRelativePath(Result.ConfigPath, Result.UnitsDir);
  Result.DistributionBinDir := ResolveConfigRelativePath(
    Result.ConfigPath,
    Result.DistributionBinDir
  );
  Result.DistributionLibDir := ResolveConfigRelativePath(
    Result.ConfigPath,
    Result.DistributionLibDir
  );
  Result.DistributionShareDir := ResolveConfigRelativePath(
    Result.ConfigPath,
    Result.DistributionShareDir
  );
  Result.ToolchainBindingPath := ResolveConfigRelativePath(
    Result.ConfigPath,
    Result.ToolchainBindingPath
  );
  if ToolchainBindingOverride <> '' then
    Result.ToolchainBindingPath := ResolveToolchainBindingPath(
      Result.ConfigPath,
      ToolchainBindingOverride
    );

  HostId := BuildHostId(Result.HostOS, Result.HostCPU);
  Binding := LoadToolchainBinding(
    Result.ToolchainBindingPath,
    HostId,
    Result.TargetId,
    Result.CompilerExecutable
  );
  Result.HostId := Binding.HostId;
  Result.ToolchainBindingId := Binding.BindingId;
  Result.HostCompilerProfileId := Binding.HostCompilerProfileId;
  Result.BackendFamily := Binding.BackendFamily;
  Result.AssemblerProfileId := Binding.AssemblerProfileId;
  Result.LinkerProfileId := Binding.LinkerProfileId;
  Result.ArchiverProfileId := Binding.ArchiverProfileId;
  Result.ResourceToolProfileId := Binding.ResourceToolProfileId;
  Result.SysrootMode := Binding.SysrootMode;
  Result.RuntimeSdkId := Binding.RuntimeSdkId;
  Result.AllowHostFallback := Binding.AllowHostFallback;
  Result.ToolRootKind := Binding.ToolRootKind;
  Result.RuntimeRootKind := Binding.RuntimeRootKind;
  Result.ResponseFilePolicy := Binding.ResponseFilePolicy;
  Result.LinkScriptPolicy := Binding.LinkScriptPolicy;
  Result.LlvmEnabled := Binding.LlvmEnabled;
  Result.LlvmExecutableSetId := Binding.LlvmExecutableSetId;
end;

end.
