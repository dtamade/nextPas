unit np_toolchain_profiles;

{$mode objfpc}{$H+}

interface

uses
  Classes, nextpas.core.text, nextpas.core.text.conv, nextpas.core.path,
  nextpas.core.fs.util, nextpas.core.exception;

type
  EToolProfileError = class(Exception)
  end;

  THostCompilerProfile = record
    Id: string;
    ToolFlavor: string;
    DriverCandidates: TStringArray;
    CommandTemplateKind: string;
    SourceInputKind: string;
    OutputKind: string;
    UnitsFlag: string;
    ResponseFileMode: string;
  end;

  TAssemblerProfile = record
    Id: string;
    ToolFlavor: string;
    DriverCandidates: TStringArray;
    InputKind: string;
    OutputKind: string;
    CommandTemplateKind: string;
    ResponseFileMode: string;
    TargetSelectorMode: string;
    LlvmToolchainMember: Boolean;
    HasLlvmToolchainMember: Boolean;
    SmartlinkSectionSupport: string;
  end;

  TLinkerProfile = record
    Id: string;
    ToolFlavor: string;
    DriverKind: string;
    DriverCandidates: TStringArray;
    ExecutableKinds: TStringArray;
    CommandTemplateKind: string;
    ResponseFileMode: string;
    ScriptAssetKind: string;
    DynamicLinkerPolicy: string;
    LibrarySearchFlag: string;
    SharedFlag: string;
    MapFileSupport: string;
    OrderedSymbolsSupport: string;
  end;

  TArchiverProfile = record
    Id: string;
    ToolFlavor: string;
    DriverCandidates: TStringArray;
    AddFileMode: string;
    CreateMode: string;
    FinishMode: string;
    ScriptMode: string;
    ArchiveFormat: string;
    IndexPolicy: string;
  end;

  TResourceToolProfile = record
    Id: string;
    PipelineKind: string;
    RcDriverCandidates: TStringArray;
    ResDriverCandidates: TStringArray;
    RcCommandTemplateKind: string;
    ResCommandTemplateKind: string;
    InputSuffixes: TStringArray;
    OutputSuffixes: TStringArray;
    IntermediateAssetKind: string;
    SingleStageFallback: string;
    ArchParameterMode: string;
  end;

  TLlvmExecutableSet = record
    Id: string;
    ToolRootKind: string;
    ClangDriver: string;
    Llc: string;
    Opt: string;
    Lld: string;
    LlvmAr: string;
    SuffixPolicy: string;
    VersionContract: string;
  end;

function ResolveToolProfileRoot(const AConfigPath: string): string;
function FirstStringOrDefault(
  const AValues: TStringArray;
  const ADefault: string
): string;
function LoadHostCompilerProfile(
  const ARootPath: string;
  const AProfileId: string
): THostCompilerProfile;
function LoadAssemblerProfile(
  const ARootPath: string;
  const AProfileId: string
): TAssemblerProfile;
function LoadLinkerProfile(
  const ARootPath: string;
  const AProfileId: string
): TLinkerProfile;
function LoadArchiverProfile(
  const ARootPath: string;
  const AProfileId: string
): TArchiverProfile;
function LoadResourceToolProfile(
  const ARootPath: string;
  const AProfileId: string
): TResourceToolProfile;
function LoadLlvmExecutableSet(
  const ARootPath: string;
  const ASetId: string
): TLlvmExecutableSet;

implementation

function TrimQuotes(const Value: string): string;
begin
  Result := Trim(Value);
  if (Length(Result) >= 2) and (Result[1] = '"') and
    (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
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

  raise EToolProfileError.Create(
    'tool-profile-invalid-boolean: ' + FieldName + '=' + Value
  );
end;

function ParseStringArrayLiteral(const Value: string): TStringArray;
var
  Buffer: string;
  Index: SizeInt;
  InQuotes: Boolean;
  InnerValue: string;
  NextIndex: SizeInt;
begin
  SetLength(Result, 0);
  InnerValue := Trim(Value);
  if (InnerValue = '[]') or (InnerValue = '') then
    Exit;

  if (InnerValue[1] <> '[') or (InnerValue[Length(InnerValue)] <> ']') then
    raise EToolProfileError.Create('tool-profile-invalid-array: ' + Value);

  InnerValue := Copy(InnerValue, 2, Length(InnerValue) - 2);
  Buffer := '';
  InQuotes := False;
  for Index := 1 to Length(InnerValue) do
  begin
    if InnerValue[Index] = '"' then
    begin
      InQuotes := not InQuotes;
      Buffer := Buffer + InnerValue[Index];
      Continue;
    end;

    if (InnerValue[Index] = ',') and not InQuotes then
    begin
      NextIndex := Length(Result);
      SetLength(Result, NextIndex + 1);
      Result[NextIndex] := TrimQuotes(Buffer);
      Buffer := '';
      Continue;
    end;

    Buffer := Buffer + InnerValue[Index];
  end;

  if Trim(Buffer) <> '' then
  begin
    NextIndex := Length(Result);
    SetLength(Result, NextIndex + 1);
    Result[NextIndex] := TrimQuotes(Buffer);
  end;
end;

function ResolveToolProfileRoot(const AConfigPath: string): string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(AConfigPath)) + '..' +
    DirectorySeparator + 'tool-profiles'
  );
end;

function FirstStringOrDefault(
  const AValues: TStringArray;
  const ADefault: string
): string;
begin
  if Length(AValues) = 0 then
    Exit(ADefault);

  Result := AValues[0];
end;

procedure RequireField(const Value: string; const FieldName: string);
begin
  if Trim(Value) = '' then
    raise EToolProfileError.Create('tool-profile-missing-field: ' + FieldName);
end;

procedure RequireFlag(const AssignedValue: Boolean; const FieldName: string);
begin
  if not AssignedValue then
    raise EToolProfileError.Create('tool-profile-missing-field: ' + FieldName);
end;

function ProfilePath(
  const ARootPath: string;
  const ACategory: string;
  const AProfileId: string
): string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ARootPath) + ACategory + DirectorySeparator +
    AProfileId + '.toml'
  );
end;

procedure NextKeyValue(
  const ALine: string;
  var ASection: string;
  out AKey: string;
  out AValue: string
);
var
  SeparatorIndex: SizeInt;
  TrimmedLine: string;
begin
  AKey := '';
  AValue := '';
  TrimmedLine := Trim(ALine);
  if TrimmedLine = '' then
    Exit;
  if TrimmedLine[1] = '#' then
    Exit;

  if (TrimmedLine[1] = '[') and (TrimmedLine[Length(TrimmedLine)] = ']') then
  begin
    ASection := LowerCase(
      Trim(Copy(TrimmedLine, 2, Length(TrimmedLine) - 2))
    );
    Exit;
  end;

  SeparatorIndex := Pos('=', TrimmedLine);
  if SeparatorIndex = 0 then
    Exit;

  AKey := LowerCase(Trim(Copy(TrimmedLine, 1, SeparatorIndex - 1)));
  AValue := Trim(Copy(TrimmedLine, SeparatorIndex + 1, MaxInt));
end;

function LoadHostCompilerProfile(
  const ARootPath: string;
  const AProfileId: string
): THostCompilerProfile;
var
  CurrentSection: string;
  Key: string;
  Lines: TStringList;
  Path: string;
  Value: string;
  Index: Integer;
begin
  Path := ProfilePath(ARootPath, 'host-compilers', AProfileId);
  if not FsExists(Path) then
    raise EToolProfileError.Create('missing-tool-profile: ' + Path);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Path);
    CurrentSection := '';
    for Index := 0 to Lines.Count - 1 do
    begin
      NextKeyValue(Lines[Index], CurrentSection, Key, Value);
      if (CurrentSection <> 'host_compiler_profile') or (Key = '') then
        Continue;

      if Key = 'id' then
        Result.Id := TrimQuotes(Value)
      else if Key = 'tool_flavor' then
        Result.ToolFlavor := TrimQuotes(Value)
      else if Key = 'driver_candidates' then
        Result.DriverCandidates := ParseStringArrayLiteral(Value)
      else if Key = 'command_template_kind' then
        Result.CommandTemplateKind := TrimQuotes(Value)
      else if Key = 'source_input_kind' then
        Result.SourceInputKind := TrimQuotes(Value)
      else if Key = 'output_kind' then
        Result.OutputKind := TrimQuotes(Value)
      else if Key = 'units_flag' then
        Result.UnitsFlag := TrimQuotes(Value)
      else if Key = 'response_file_mode' then
        Result.ResponseFileMode := TrimQuotes(Value);
    end;
  finally
    Lines.Free;
  end;

  RequireField(Result.Id, 'host_compiler_profile.id');
  RequireField(Result.ToolFlavor, 'host_compiler_profile.tool_flavor');
  RequireField(Result.CommandTemplateKind, 'host_compiler_profile.command_template_kind');
  RequireField(Result.SourceInputKind, 'host_compiler_profile.source_input_kind');
  RequireField(Result.OutputKind, 'host_compiler_profile.output_kind');
  RequireField(Result.UnitsFlag, 'host_compiler_profile.units_flag');
  RequireField(Result.ResponseFileMode, 'host_compiler_profile.response_file_mode');
end;

function LoadAssemblerProfile(
  const ARootPath: string;
  const AProfileId: string
): TAssemblerProfile;
var
  CurrentSection: string;
  Key: string;
  Lines: TStringList;
  Path: string;
  Value: string;
  Index: Integer;
begin
  Path := ProfilePath(ARootPath, 'assemblers', AProfileId);
  if not FsExists(Path) then
    raise EToolProfileError.Create('missing-tool-profile: ' + Path);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Path);
    CurrentSection := '';
    for Index := 0 to Lines.Count - 1 do
    begin
      NextKeyValue(Lines[Index], CurrentSection, Key, Value);
      if (CurrentSection <> 'assembler_profile') or (Key = '') then
        Continue;

      if Key = 'id' then
        Result.Id := TrimQuotes(Value)
      else if Key = 'tool_flavor' then
        Result.ToolFlavor := TrimQuotes(Value)
      else if Key = 'driver_candidates' then
        Result.DriverCandidates := ParseStringArrayLiteral(Value)
      else if Key = 'input_kind' then
        Result.InputKind := TrimQuotes(Value)
      else if Key = 'output_kind' then
        Result.OutputKind := TrimQuotes(Value)
      else if Key = 'command_template_kind' then
        Result.CommandTemplateKind := TrimQuotes(Value)
      else if Key = 'response_file_mode' then
        Result.ResponseFileMode := TrimQuotes(Value)
      else if Key = 'target_selector_mode' then
        Result.TargetSelectorMode := TrimQuotes(Value)
      else if Key = 'llvm_toolchain_member' then
      begin
        Result.LlvmToolchainMember := ParseBooleanLiteral(
          TrimQuotes(Value),
          'assembler_profile.llvm_toolchain_member'
        );
        Result.HasLlvmToolchainMember := True;
      end
      else if Key = 'smartlink_section_support' then
        Result.SmartlinkSectionSupport := TrimQuotes(Value);
    end;
  finally
    Lines.Free;
  end;

  RequireField(Result.Id, 'assembler_profile.id');
  RequireField(Result.ToolFlavor, 'assembler_profile.tool_flavor');
  RequireField(Result.InputKind, 'assembler_profile.input_kind');
  RequireField(Result.OutputKind, 'assembler_profile.output_kind');
  RequireField(Result.CommandTemplateKind, 'assembler_profile.command_template_kind');
  RequireField(Result.ResponseFileMode, 'assembler_profile.response_file_mode');
  RequireField(Result.TargetSelectorMode, 'assembler_profile.target_selector_mode');
  RequireFlag(Result.HasLlvmToolchainMember, 'assembler_profile.llvm_toolchain_member');
  RequireField(Result.SmartlinkSectionSupport, 'assembler_profile.smartlink_section_support');
end;

function LoadLinkerProfile(
  const ARootPath: string;
  const AProfileId: string
): TLinkerProfile;
var
  CurrentSection: string;
  Key: string;
  Lines: TStringList;
  Path: string;
  Value: string;
  Index: Integer;
begin
  Path := ProfilePath(ARootPath, 'linkers', AProfileId);
  if not FsExists(Path) then
    raise EToolProfileError.Create('missing-tool-profile: ' + Path);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Path);
    CurrentSection := '';
    for Index := 0 to Lines.Count - 1 do
    begin
      NextKeyValue(Lines[Index], CurrentSection, Key, Value);
      if (CurrentSection <> 'linker_profile') or (Key = '') then
        Continue;

      if Key = 'id' then
        Result.Id := TrimQuotes(Value)
      else if Key = 'tool_flavor' then
        Result.ToolFlavor := TrimQuotes(Value)
      else if Key = 'driver_kind' then
        Result.DriverKind := TrimQuotes(Value)
      else if Key = 'driver_candidates' then
        Result.DriverCandidates := ParseStringArrayLiteral(Value)
      else if Key = 'executable_kinds' then
        Result.ExecutableKinds := ParseStringArrayLiteral(Value)
      else if Key = 'command_template_kind' then
        Result.CommandTemplateKind := TrimQuotes(Value)
      else if Key = 'response_file_mode' then
        Result.ResponseFileMode := TrimQuotes(Value)
      else if Key = 'script_asset_kind' then
        Result.ScriptAssetKind := TrimQuotes(Value)
      else if Key = 'dynamic_linker_policy' then
        Result.DynamicLinkerPolicy := TrimQuotes(Value)
      else if Key = 'library_search_flag' then
        Result.LibrarySearchFlag := TrimQuotes(Value)
      else if Key = 'shared_flag' then
        Result.SharedFlag := TrimQuotes(Value)
      else if Key = 'map_file_support' then
        Result.MapFileSupport := TrimQuotes(Value)
      else if Key = 'ordered_symbols_support' then
        Result.OrderedSymbolsSupport := TrimQuotes(Value);
    end;
  finally
    Lines.Free;
  end;

  RequireField(Result.Id, 'linker_profile.id');
  RequireField(Result.ToolFlavor, 'linker_profile.tool_flavor');
  RequireField(Result.DriverKind, 'linker_profile.driver_kind');
  RequireField(Result.CommandTemplateKind, 'linker_profile.command_template_kind');
  RequireField(Result.ResponseFileMode, 'linker_profile.response_file_mode');
  RequireField(Result.ScriptAssetKind, 'linker_profile.script_asset_kind');
  RequireField(Result.DynamicLinkerPolicy, 'linker_profile.dynamic_linker_policy');
  RequireField(Result.LibrarySearchFlag, 'linker_profile.library_search_flag');
  RequireField(Result.SharedFlag, 'linker_profile.shared_flag');
  RequireField(Result.MapFileSupport, 'linker_profile.map_file_support');
  RequireField(Result.OrderedSymbolsSupport, 'linker_profile.ordered_symbols_support');
end;

function LoadArchiverProfile(
  const ARootPath: string;
  const AProfileId: string
): TArchiverProfile;
var
  CurrentSection: string;
  Key: string;
  Lines: TStringList;
  Path: string;
  Value: string;
  Index: Integer;
begin
  Path := ProfilePath(ARootPath, 'archivers', AProfileId);
  if not FsExists(Path) then
    raise EToolProfileError.Create('missing-tool-profile: ' + Path);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Path);
    CurrentSection := '';
    for Index := 0 to Lines.Count - 1 do
    begin
      NextKeyValue(Lines[Index], CurrentSection, Key, Value);
      if (CurrentSection <> 'archiver_profile') or (Key = '') then
        Continue;

      if Key = 'id' then
        Result.Id := TrimQuotes(Value)
      else if Key = 'tool_flavor' then
        Result.ToolFlavor := TrimQuotes(Value)
      else if Key = 'driver_candidates' then
        Result.DriverCandidates := ParseStringArrayLiteral(Value)
      else if Key = 'add_file_mode' then
        Result.AddFileMode := TrimQuotes(Value)
      else if Key = 'create_mode' then
        Result.CreateMode := TrimQuotes(Value)
      else if Key = 'finish_mode' then
        Result.FinishMode := TrimQuotes(Value)
      else if Key = 'script_mode' then
        Result.ScriptMode := TrimQuotes(Value)
      else if Key = 'archive_format' then
        Result.ArchiveFormat := TrimQuotes(Value)
      else if Key = 'index_policy' then
        Result.IndexPolicy := TrimQuotes(Value);
    end;
  finally
    Lines.Free;
  end;

  RequireField(Result.Id, 'archiver_profile.id');
  RequireField(Result.ToolFlavor, 'archiver_profile.tool_flavor');
  RequireField(Result.AddFileMode, 'archiver_profile.add_file_mode');
  RequireField(Result.CreateMode, 'archiver_profile.create_mode');
  RequireField(Result.FinishMode, 'archiver_profile.finish_mode');
  RequireField(Result.ScriptMode, 'archiver_profile.script_mode');
  RequireField(Result.ArchiveFormat, 'archiver_profile.archive_format');
  RequireField(Result.IndexPolicy, 'archiver_profile.index_policy');
end;

function LoadResourceToolProfile(
  const ARootPath: string;
  const AProfileId: string
): TResourceToolProfile;
var
  CurrentSection: string;
  Key: string;
  Lines: TStringList;
  Path: string;
  Value: string;
  Index: Integer;
begin
  Path := ProfilePath(ARootPath, 'resources', AProfileId);
  if not FsExists(Path) then
    raise EToolProfileError.Create('missing-tool-profile: ' + Path);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Path);
    CurrentSection := '';
    for Index := 0 to Lines.Count - 1 do
    begin
      NextKeyValue(Lines[Index], CurrentSection, Key, Value);
      if (CurrentSection <> 'resource_tool_profile') or (Key = '') then
        Continue;

      if Key = 'id' then
        Result.Id := TrimQuotes(Value)
      else if Key = 'pipeline_kind' then
        Result.PipelineKind := TrimQuotes(Value)
      else if Key = 'rc_driver_candidates' then
        Result.RcDriverCandidates := ParseStringArrayLiteral(Value)
      else if Key = 'res_driver_candidates' then
        Result.ResDriverCandidates := ParseStringArrayLiteral(Value)
      else if Key = 'rc_command_template_kind' then
        Result.RcCommandTemplateKind := TrimQuotes(Value)
      else if Key = 'res_command_template_kind' then
        Result.ResCommandTemplateKind := TrimQuotes(Value)
      else if Key = 'input_suffixes' then
        Result.InputSuffixes := ParseStringArrayLiteral(Value)
      else if Key = 'output_suffixes' then
        Result.OutputSuffixes := ParseStringArrayLiteral(Value)
      else if Key = 'intermediate_asset_kind' then
        Result.IntermediateAssetKind := TrimQuotes(Value)
      else if Key = 'single_stage_fallback' then
        Result.SingleStageFallback := TrimQuotes(Value)
      else if Key = 'arch_parameter_mode' then
        Result.ArchParameterMode := TrimQuotes(Value);
    end;
  finally
    Lines.Free;
  end;

  RequireField(Result.Id, 'resource_tool_profile.id');
  RequireField(Result.PipelineKind, 'resource_tool_profile.pipeline_kind');
  RequireField(Result.RcCommandTemplateKind, 'resource_tool_profile.rc_command_template_kind');
  RequireField(Result.ResCommandTemplateKind, 'resource_tool_profile.res_command_template_kind');
  RequireField(Result.IntermediateAssetKind, 'resource_tool_profile.intermediate_asset_kind');
  RequireField(Result.SingleStageFallback, 'resource_tool_profile.single_stage_fallback');
  RequireField(Result.ArchParameterMode, 'resource_tool_profile.arch_parameter_mode');
end;

function LoadLlvmExecutableSet(
  const ARootPath: string;
  const ASetId: string
): TLlvmExecutableSet;
var
  CurrentSection: string;
  Key: string;
  Lines: TStringList;
  Path: string;
  Value: string;
  Index: Integer;
begin
  Path := ProfilePath(ARootPath, 'llvm', ASetId);
  if not FsExists(Path) then
    raise EToolProfileError.Create('missing-tool-profile: ' + Path);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Path);
    CurrentSection := '';
    for Index := 0 to Lines.Count - 1 do
    begin
      NextKeyValue(Lines[Index], CurrentSection, Key, Value);
      if (CurrentSection <> 'llvm_executable_set') or (Key = '') then
        Continue;

      if Key = 'id' then
        Result.Id := TrimQuotes(Value)
      else if Key = 'tool_root_kind' then
        Result.ToolRootKind := TrimQuotes(Value)
      else if Key = 'clang_driver' then
        Result.ClangDriver := TrimQuotes(Value)
      else if Key = 'llc' then
        Result.Llc := TrimQuotes(Value)
      else if Key = 'opt' then
        Result.Opt := TrimQuotes(Value)
      else if Key = 'lld' then
        Result.Lld := TrimQuotes(Value)
      else if Key = 'llvm_ar' then
        Result.LlvmAr := TrimQuotes(Value)
      else if Key = 'suffix_policy' then
        Result.SuffixPolicy := TrimQuotes(Value)
      else if Key = 'version_contract' then
        Result.VersionContract := TrimQuotes(Value);
    end;
  finally
    Lines.Free;
  end;

  RequireField(Result.Id, 'llvm_executable_set.id');
  RequireField(Result.ToolRootKind, 'llvm_executable_set.tool_root_kind');
  RequireField(Result.ClangDriver, 'llvm_executable_set.clang_driver');
  RequireField(Result.Llc, 'llvm_executable_set.llc');
  RequireField(Result.Opt, 'llvm_executable_set.opt');
  RequireField(Result.Lld, 'llvm_executable_set.lld');
  RequireField(Result.LlvmAr, 'llvm_executable_set.llvm_ar');
  RequireField(Result.SuffixPolicy, 'llvm_executable_set.suffix_policy');
  RequireField(Result.VersionContract, 'llvm_executable_set.version_contract');
end;

end.
