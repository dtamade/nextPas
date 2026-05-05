unit np_backend_plan;

{$mode objfpc}{$H+}
{$UNITPATH ../ir}
{$UNITPATH ../targets}

interface

uses
  SysUtils, np_mir_model, np_target_facts, nextpas_json_helpers;

type
  TBackendArtifact = record
    ArtifactId: LongInt;
    Kind: string;
    Path: string;
  end;

  TBackendLogicalLibraryRequest = record
    RequestId: LongInt;
    LogicalId: string;
    LinkageKind: string;
    Strength: string;
  end;

  TBackendPlan = class
  private
    FArtifacts: array of TBackendArtifact;
    FLogicalLibraryRequests: array of TBackendLogicalLibraryRequest;
    FStatus: string;
    FRootName: string;
    FOutputKind: string;
    FPrimaryArtifactKind: string;
    FPrimaryArtifactPath: string;
    FHostId: string;
    FToolchainBindingId: string;
    FHostCompilerProfileId: string;
    FBackendFamily: string;
    FAssemblerProfileId: string;
    FLinkerProfileId: string;
    FArchiverProfileId: string;
    FResourceToolProfileId: string;
    FObjectFormat: string;
    FAssemblerFlavor: string;
    FLinkerFlavor: string;
    FRuntimeLayoutKey: string;
    FTargetCSymbolPrefix: string;
    FTargetCLibraryNaming: string;
    FLlvmTriple: string;
    FLlvmDataLayout: string;
    FSysrootMode: string;
    FRuntimeSdkId: string;
    FAllowHostFallback: Boolean;
    FToolRootKind: string;
    FRuntimeRootKind: string;
    FResponseFilePolicy: string;
    FLinkScriptPolicy: string;
    FLlvmEnabled: Boolean;
    FLlvmExecutableSetId: string;
  public
    constructor Create;
    function AddArtifact(const AKind: string; const APath: string): LongInt;
    function ArtifactCount: LongInt;
    function ArtifactAt(const AIndex: LongInt): TBackendArtifact;
    function ArtifactPathByKind(const AKind: string): string;
    function ArtifactsJson: string;
    function AddLogicalLibraryRequest(
      const ALogicalId: string;
      const ALinkageKind: string;
      const AStrength: string
    ): LongInt;
    function LogicalLibraryRequestCount: LongInt;
    function LogicalLibraryRequestAt(
      const AIndex: LongInt
    ): TBackendLogicalLibraryRequest;
    procedure SetRootName(const AName: string);
    function RootName: string;
    procedure SetOutputKind(const AKind: string);
    function OutputKind: string;
    procedure SetPrimaryArtifact(const AKind: string; const APath: string);
    function PrimaryArtifactKind: string;
    function PrimaryArtifactPath: string;
    procedure SetTargetMetadata(const ATargetFacts: TTargetFactsView);
    function HostId: string;
    function ToolchainBindingId: string;
    function HostCompilerProfileId: string;
    function BackendFamily: string;
    function AssemblerProfileId: string;
    function LinkerProfileId: string;
    function ArchiverProfileId: string;
    function ResourceToolProfileId: string;
    function ObjectFormat: string;
    function AssemblerFlavor: string;
    function LinkerFlavor: string;
    function RuntimeLayoutKey: string;
    function TargetCSymbolPrefix: string;
    function TargetCLibraryNaming: string;
    function LlvmTriple: string;
    function LlvmDataLayout: string;
    function SysrootMode: string;
    function RuntimeSdkId: string;
    function AllowHostFallback: Boolean;
    function ToolRootKind: string;
    function RuntimeRootKind: string;
    function ResponseFilePolicy: string;
    function LinkScriptPolicy: string;
    function LlvmEnabled: Boolean;
    function LlvmExecutableSetId: string;
    procedure MarkReady;
    procedure MarkFailure;
    function Status: string;
  end;

  TBackendPlanner = class
  private
    FMirModel: TMirModel;
    FTargetFacts: TTargetFactsView;
    FSourcePath: string;
    FArtifactRootPath: string;
    FOutputDirPath: string;
    FPlan: TBackendPlan;
    function BackendIntermediateRootPath: string;
  public
    constructor Create(
      const AMirModel: TMirModel;
      const ATargetFacts: TTargetFactsView;
      const ASourcePath: string;
      const AArtifactRootPath: string;
      const AOutputDirPath: string
    );
    destructor Destroy; override;
    procedure Plan;
    function DetachPlan: TBackendPlan;
  end;

implementation

constructor TBackendPlan.Create;
begin
  inherited Create;
  SetLength(FArtifacts, 0);
  SetLength(FLogicalLibraryRequests, 0);
  FStatus := 'deferred';
  FRootName := '';
  FOutputKind := '';
  FPrimaryArtifactKind := '';
  FPrimaryArtifactPath := '';
  FHostId := '';
  FToolchainBindingId := '';
  FHostCompilerProfileId := '';
  FBackendFamily := '';
  FAssemblerProfileId := '';
  FLinkerProfileId := '';
  FArchiverProfileId := '';
  FResourceToolProfileId := '';
  FObjectFormat := '';
  FAssemblerFlavor := '';
  FLinkerFlavor := '';
  FRuntimeLayoutKey := '';
  FTargetCSymbolPrefix := '';
  FTargetCLibraryNaming := '';
  FLlvmTriple := '';
  FLlvmDataLayout := '';
  FSysrootMode := '';
  FRuntimeSdkId := '';
  FAllowHostFallback := False;
  FToolRootKind := '';
  FRuntimeRootKind := '';
  FResponseFilePolicy := '';
  FLinkScriptPolicy := '';
  FLlvmEnabled := False;
  FLlvmExecutableSetId := '';
end;

function TBackendPlan.AddArtifact(const AKind: string; const APath: string): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FArtifacts);
  SetLength(FArtifacts, NextIndex + 1);
  FArtifacts[NextIndex].ArtifactId := NextIndex + 1;
  FArtifacts[NextIndex].Kind := AKind;
  FArtifacts[NextIndex].Path := APath;
  Result := FArtifacts[NextIndex].ArtifactId;
end;

function TBackendPlan.ArtifactCount: LongInt;
begin
  Result := Length(FArtifacts);
end;

function TBackendPlan.ArtifactAt(const AIndex: LongInt): TBackendArtifact;
begin
  if (AIndex < 0) or (AIndex > High(FArtifacts)) then
  begin
    Result.ArtifactId := 0;
    Result.Kind := '';
    Result.Path := '';
    Exit;
  end;

  Result := FArtifacts[AIndex];
end;

function TBackendPlan.ArtifactPathByKind(const AKind: string): string;
var
  Index: LongInt;
begin
  Result := '';
  for Index := 0 to High(FArtifacts) do
    if SameText(FArtifacts[Index].Kind, AKind) then
      Exit(FArtifacts[Index].Path);
end;

function TBackendPlan.ArtifactsJson: string;
var
  EntryFields: string;
  Index: LongInt;
begin
  Result := '';
  for Index := 0 to High(FArtifacts) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(
      EntryFields,
      'artifactId',
      IntToStr(FArtifacts[Index].ArtifactId)
    );
    AppendJsonField(EntryFields, 'kind', JsonString(FArtifacts[Index].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(FArtifacts[Index].Path));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

function TBackendPlan.AddLogicalLibraryRequest(
  const ALogicalId: string;
  const ALinkageKind: string;
  const AStrength: string
): LongInt;
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FLogicalLibraryRequests) - 1 do
    if SameText(FLogicalLibraryRequests[Index].LogicalId, ALogicalId) and
      SameText(FLogicalLibraryRequests[Index].LinkageKind, ALinkageKind) and
      SameText(FLogicalLibraryRequests[Index].Strength, AStrength) then
      Exit(FLogicalLibraryRequests[Index].RequestId);

  NextIndex := Length(FLogicalLibraryRequests);
  SetLength(FLogicalLibraryRequests, NextIndex + 1);
  FLogicalLibraryRequests[NextIndex].RequestId := NextIndex + 1;
  FLogicalLibraryRequests[NextIndex].LogicalId := ALogicalId;
  FLogicalLibraryRequests[NextIndex].LinkageKind := ALinkageKind;
  FLogicalLibraryRequests[NextIndex].Strength := AStrength;
  Result := FLogicalLibraryRequests[NextIndex].RequestId;
end;

function TBackendPlan.LogicalLibraryRequestCount: LongInt;
begin
  Result := Length(FLogicalLibraryRequests);
end;

function TBackendPlan.LogicalLibraryRequestAt(
  const AIndex: LongInt
): TBackendLogicalLibraryRequest;
begin
  if (AIndex < 0) or (AIndex > High(FLogicalLibraryRequests)) then
  begin
    Result.RequestId := 0;
    Result.LogicalId := '';
    Result.LinkageKind := '';
    Result.Strength := '';
    Exit;
  end;

  Result := FLogicalLibraryRequests[AIndex];
end;

procedure TBackendPlan.SetRootName(const AName: string);
begin
  FRootName := AName;
end;

function TBackendPlan.RootName: string;
begin
  Result := FRootName;
end;

procedure TBackendPlan.SetOutputKind(const AKind: string);
begin
  FOutputKind := AKind;
end;

function TBackendPlan.OutputKind: string;
begin
  Result := FOutputKind;
end;

procedure TBackendPlan.SetPrimaryArtifact(const AKind: string; const APath: string);
begin
  FPrimaryArtifactKind := AKind;
  FPrimaryArtifactPath := APath;
end;

function TBackendPlan.PrimaryArtifactKind: string;
begin
  Result := FPrimaryArtifactKind;
end;

function TBackendPlan.PrimaryArtifactPath: string;
begin
  Result := FPrimaryArtifactPath;
end;

procedure TBackendPlan.SetTargetMetadata(const ATargetFacts: TTargetFactsView);
begin
  FHostId := ATargetFacts.HostId;
  FToolchainBindingId := ATargetFacts.ToolchainBindingId;
  FHostCompilerProfileId := ATargetFacts.HostCompilerProfileId;
  FBackendFamily := ATargetFacts.BackendFamily;
  FAssemblerProfileId := ATargetFacts.AssemblerProfileId;
  FLinkerProfileId := ATargetFacts.LinkerProfileId;
  FArchiverProfileId := ATargetFacts.ArchiverProfileId;
  FResourceToolProfileId := ATargetFacts.ResourceToolProfileId;
  FObjectFormat := ATargetFacts.ObjectFormat;
  FAssemblerFlavor := ATargetFacts.AssemblerFlavor;
  FLinkerFlavor := ATargetFacts.LinkerFlavor;
  FRuntimeLayoutKey := ATargetFacts.RuntimeLayoutKey;
  FTargetCSymbolPrefix := ATargetFacts.CSymbolPrefix;
  FTargetCLibraryNaming := ATargetFacts.CLibraryNaming;
  FLlvmTriple := ATargetFacts.LlvmTriple;
  FLlvmDataLayout := ATargetFacts.LlvmDataLayout;
  FSysrootMode := ATargetFacts.SysrootMode;
  FRuntimeSdkId := ATargetFacts.RuntimeSdkId;
  FAllowHostFallback := ATargetFacts.AllowHostFallback;
  FToolRootKind := ATargetFacts.ToolRootKind;
  FRuntimeRootKind := ATargetFacts.RuntimeRootKind;
  FResponseFilePolicy := ATargetFacts.ResponseFilePolicy;
  FLinkScriptPolicy := ATargetFacts.LinkScriptPolicy;
  FLlvmEnabled := ATargetFacts.LlvmEnabled;
  FLlvmExecutableSetId := ATargetFacts.LlvmExecutableSetId;
end;

function TBackendPlan.HostId: string;
begin
  Result := FHostId;
end;

function TBackendPlan.ToolchainBindingId: string;
begin
  Result := FToolchainBindingId;
end;

function TBackendPlan.HostCompilerProfileId: string;
begin
  Result := FHostCompilerProfileId;
end;

function TBackendPlan.BackendFamily: string;
begin
  Result := FBackendFamily;
end;

function TBackendPlan.AssemblerProfileId: string;
begin
  Result := FAssemblerProfileId;
end;

function TBackendPlan.LinkerProfileId: string;
begin
  Result := FLinkerProfileId;
end;

function TBackendPlan.ArchiverProfileId: string;
begin
  Result := FArchiverProfileId;
end;

function TBackendPlan.ResourceToolProfileId: string;
begin
  Result := FResourceToolProfileId;
end;

function TBackendPlan.ObjectFormat: string;
begin
  Result := FObjectFormat;
end;

function TBackendPlan.AssemblerFlavor: string;
begin
  Result := FAssemblerFlavor;
end;

function TBackendPlan.LinkerFlavor: string;
begin
  Result := FLinkerFlavor;
end;

function TBackendPlan.RuntimeLayoutKey: string;
begin
  Result := FRuntimeLayoutKey;
end;

function TBackendPlan.TargetCSymbolPrefix: string;
begin
  Result := FTargetCSymbolPrefix;
end;

function TBackendPlan.TargetCLibraryNaming: string;
begin
  Result := FTargetCLibraryNaming;
end;

function TBackendPlan.LlvmTriple: string;
begin
  Result := FLlvmTriple;
end;

function TBackendPlan.LlvmDataLayout: string;
begin
  Result := FLlvmDataLayout;
end;

function TBackendPlan.SysrootMode: string;
begin
  Result := FSysrootMode;
end;

function TBackendPlan.RuntimeSdkId: string;
begin
  Result := FRuntimeSdkId;
end;

function TBackendPlan.AllowHostFallback: Boolean;
begin
  Result := FAllowHostFallback;
end;

function TBackendPlan.ToolRootKind: string;
begin
  Result := FToolRootKind;
end;

function TBackendPlan.RuntimeRootKind: string;
begin
  Result := FRuntimeRootKind;
end;

function TBackendPlan.ResponseFilePolicy: string;
begin
  Result := FResponseFilePolicy;
end;

function TBackendPlan.LinkScriptPolicy: string;
begin
  Result := FLinkScriptPolicy;
end;

function TBackendPlan.LlvmEnabled: Boolean;
begin
  Result := FLlvmEnabled;
end;

function TBackendPlan.LlvmExecutableSetId: string;
begin
  Result := FLlvmExecutableSetId;
end;

procedure TBackendPlan.MarkReady;
begin
  FStatus := 'ready';
end;

procedure TBackendPlan.MarkFailure;
begin
  FStatus := 'failure';
end;

function TBackendPlan.Status: string;
begin
  Result := FStatus;
end;

constructor TBackendPlanner.Create(
  const AMirModel: TMirModel;
  const ATargetFacts: TTargetFactsView;
  const ASourcePath: string;
  const AArtifactRootPath: string;
  const AOutputDirPath: string
);
begin
  inherited Create;
  FMirModel := AMirModel;
  FTargetFacts := ATargetFacts;
  FSourcePath := ASourcePath;
  FArtifactRootPath := AArtifactRootPath;
  FOutputDirPath := AOutputDirPath;
  FPlan := TBackendPlan.Create;
end;

destructor TBackendPlanner.Destroy;
begin
  FPlan.Free;
  inherited Destroy;
end;

function TBackendPlanner.BackendIntermediateRootPath: string;
begin
  if Trim(FArtifactRootPath) <> '' then
    Exit(
      ExpandFileName(
        IncludeTrailingPathDelimiter(FArtifactRootPath) + 'cache' +
        DirectorySeparator + 'backend' + DirectorySeparator +
        FTargetFacts.TargetId
      )
    );

  if Trim(FOutputDirPath) <> '' then
    Exit(ExpandFileName(FOutputDirPath));

  Result := ExtractFileDir(ExpandFileName(FSourcePath));
end;

procedure TBackendPlanner.Plan;
var
  AssemblyArtifactPath: string;
  BaseName: string;
  BitcodeArtifactPath: string;
  IntermediateRoot: string;
  LlvmIrArtifactPath: string;
  ObjectArtifactPath: string;
  PrimaryArtifactPath: string;
begin
  if (FMirModel = nil) or (FMirModel.Status <> 'ready') then
  begin
    FPlan.MarkFailure;
    Exit;
  end;

  FPlan.SetRootName(FMirModel.RootName);
  FPlan.SetTargetMetadata(FTargetFacts);
  FPlan.SetOutputKind('executable');
  BaseName := ChangeFileExt(ExtractFileName(FSourcePath), '');
  IntermediateRoot := BackendIntermediateRootPath;
  AssemblyArtifactPath := ExpandFileName(
    IncludeTrailingPathDelimiter(IntermediateRoot) + BaseName + '.s'
  );
  ObjectArtifactPath := ExpandFileName(
    IncludeTrailingPathDelimiter(IntermediateRoot) + BaseName + '.o'
  );
  if Trim(FOutputDirPath) <> '' then
    PrimaryArtifactPath := ExpandFileName(
      IncludeTrailingPathDelimiter(FOutputDirPath) +
      BaseName
    )
  else
    PrimaryArtifactPath := ChangeFileExt(FSourcePath, '');

  if SameText(FTargetFacts.BackendFamily, 'llvm') then
  begin
    LlvmIrArtifactPath := ExpandFileName(
      IncludeTrailingPathDelimiter(IntermediateRoot) + BaseName + '.ll'
    );
    BitcodeArtifactPath := ExpandFileName(
      IncludeTrailingPathDelimiter(IntermediateRoot) + BaseName + '.bc'
    );
    FPlan.AddArtifact('llvm-ir', LlvmIrArtifactPath);
    FPlan.AddArtifact('llvm-bitcode', BitcodeArtifactPath);
  end
  else
    FPlan.AddArtifact('assembly-text', AssemblyArtifactPath);

  FPlan.AddArtifact('object-file', ObjectArtifactPath);
  FPlan.AddArtifact('executable', PrimaryArtifactPath);
  FPlan.SetPrimaryArtifact('executable', PrimaryArtifactPath);
  FPlan.MarkReady;
end;

function TBackendPlanner.DetachPlan: TBackendPlan;
begin
  Result := FPlan;
  FPlan := nil;
end;

end.
