unit nextpas.compiler.backend.backend_plan;

{$mode objfpc}{$H+}
{$UNITPATH ../ir}
{$UNITPATH ../targets}
{$UNITPATH ../diagnostics}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.text.conv, nextpas.core.path, nextpas.core.fs.dir, nextpas.core.os.env,
  nextpas.core.mem.intf, nextpas.core.compiler.mem,
  nextpas.core.collections.vec,
  np_target_facts,
  np_semantic_model, np_hir_types, np_hir_model, np_hir_builder,
  np_hir_llvm_emitter, nextpas_json_helpers,
  np_hir_to_mir, np_mir_model, np_mir_to_llvm,
  np_mir_optimize, np_mir_pass_registry;

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

  TBackendArtifactVec = specialize TVec<TBackendArtifact>;
  TBackendLogicalLibraryRequestVec = specialize TVec<TBackendLogicalLibraryRequest>;

  TBackendPlan = class
  private
    FArtifacts: TBackendArtifactVec;
    FLogicalLibraryRequests: TBackendLogicalLibraryRequestVec;
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
    destructor Destroy; override;
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
    FSemaModel: TSemanticModel;
    FTargetFacts: TTargetFactsView;
    FSourcePath: string;
    FArtifactRootPath: string;
    FOutputDirPath: string;
    FRootKindName: string;
    FNoFold: Boolean;
    FOptLevel: string;
    FPlan: TBackendPlan;
    function BackendIntermediateRootPath: string;
  public
    constructor Create(
      const ASemaModel: TSemanticModel;
      const ATargetFacts: TTargetFactsView;
      const ASourcePath: string;
      const AArtifactRootPath: string;
      const AOutputDirPath: string;
      const ARootKindName: string;
      const ANoFold: Boolean;
      const AOptLevel: string
    );
    destructor Destroy; override;
    procedure Plan;
    function DetachPlan: TBackendPlan;
  end;

implementation

constructor TBackendPlan.Create;
begin
  inherited Create;
  FArtifacts := TBackendArtifactVec.Create;
  FLogicalLibraryRequests := TBackendLogicalLibraryRequestVec.Create;
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

destructor TBackendPlan.Destroy;
begin
  FLogicalLibraryRequests.Free;
  FLogicalLibraryRequests := nil;
  FArtifacts.Free;
  FArtifacts := nil;
  inherited Destroy;
end;

{--- inlined np_backend_plan_accessors.inc ---}
function TBackendPlan.AddArtifact(const AKind: string; const APath: string): LongInt;
var
  Entry: TBackendArtifact;
begin
  if FArtifacts = nil then
    FArtifacts := TBackendArtifactVec.Create;
  Entry := Default(TBackendArtifact);
  Entry.ArtifactId := LongInt(FArtifacts.Count) + 1;
  Entry.Kind := AKind;
  Entry.Path := APath;
  FArtifacts.Push(Entry);
  Result := Entry.ArtifactId;
end;

function TBackendPlan.ArtifactCount: LongInt;
begin
  if FArtifacts = nil then
    Exit(0);
  Result := LongInt(FArtifacts.Count);
end;

function TBackendPlan.ArtifactAt(const AIndex: LongInt): TBackendArtifact;
begin
  if (FArtifacts = nil) or (AIndex < 0) or (AIndex >= LongInt(FArtifacts.Count)) then
  begin
    Result.ArtifactId := 0;
    Result.Kind := '';
    Result.Path := '';
    Exit;
  end;

  Result := FArtifacts[SizeUInt(AIndex)];
end;

function TBackendPlan.ArtifactPathByKind(const AKind: string): string;
var
  Index: LongInt;
begin
  Result := '';
  if FArtifacts = nil then
    Exit;
  for Index := 0 to LongInt(FArtifacts.Count) - 1 do
    if SameText(FArtifacts[SizeUInt(Index)].Kind, AKind) then
      Exit(FArtifacts[SizeUInt(Index)].Path);
end;

function TBackendPlan.ArtifactsJson: string;
var
  EntryFields: string;
  Index: LongInt;
begin
  Result := '';
  if FArtifacts = nil then
    Exit('[]');
  for Index := 0 to LongInt(FArtifacts.Count) - 1 do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(
      EntryFields,
      'artifactId',
      IntToStr(FArtifacts[SizeUInt(Index)].ArtifactId)
    );
    AppendJsonField(EntryFields, 'kind', JsonString(FArtifacts[SizeUInt(Index)].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(FArtifacts[SizeUInt(Index)].Path));
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
  Entry: TBackendLogicalLibraryRequest;
  Index: LongInt;
begin
  if FLogicalLibraryRequests = nil then
    FLogicalLibraryRequests := TBackendLogicalLibraryRequestVec.Create;
  for Index := 0 to LongInt(FLogicalLibraryRequests.Count) - 1 do
    if SameText(FLogicalLibraryRequests[SizeUInt(Index)].LogicalId, ALogicalId) and
      SameText(FLogicalLibraryRequests[SizeUInt(Index)].LinkageKind, ALinkageKind) and
      SameText(FLogicalLibraryRequests[SizeUInt(Index)].Strength, AStrength) then
      Exit(FLogicalLibraryRequests[SizeUInt(Index)].RequestId);

  Entry := Default(TBackendLogicalLibraryRequest);
  Entry.RequestId := LongInt(FLogicalLibraryRequests.Count) + 1;
  Entry.LogicalId := ALogicalId;
  Entry.LinkageKind := ALinkageKind;
  Entry.Strength := AStrength;
  FLogicalLibraryRequests.Push(Entry);
  Result := Entry.RequestId;
end;

function TBackendPlan.LogicalLibraryRequestCount: LongInt;
begin
  if FLogicalLibraryRequests = nil then
    Exit(0);
  Result := LongInt(FLogicalLibraryRequests.Count);
end;

function TBackendPlan.LogicalLibraryRequestAt(
  const AIndex: LongInt
): TBackendLogicalLibraryRequest;
begin
  if (FLogicalLibraryRequests = nil) or (AIndex < 0) or
    (AIndex >= LongInt(FLogicalLibraryRequests.Count)) then
  begin
    Result.RequestId := 0;
    Result.LogicalId := '';
    Result.LinkageKind := '';
    Result.Strength := '';
    Exit;
  end;

  Result := FLogicalLibraryRequests[SizeUInt(AIndex)];
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
  const ASemaModel: TSemanticModel;
  const ATargetFacts: TTargetFactsView;
  const ASourcePath: string;
  const AArtifactRootPath: string;
  const AOutputDirPath: string;
  const ARootKindName: string;
  const ANoFold: Boolean;
  const AOptLevel: string
);
begin
  inherited Create;
  FSemaModel := ASemaModel;
  FTargetFacts := ATargetFacts;
  FSourcePath := ASourcePath;
  FArtifactRootPath := AArtifactRootPath;
  FOutputDirPath := AOutputDirPath;
  FRootKindName := ARootKindName;
  FNoFold := ANoFold;
  FOptLevel := AOptLevel;
  FPlan := TBackendPlan.Create;
end;

destructor TBackendPlanner.Destroy;
begin
  FPlan.Free;
  inherited Destroy;
end;


{--- end ---}
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
  HirBuilder: THIRBuilder;
  HirEmitter: THIRLlvmEmitter;
  Lowering: THirToMirLowering;
  LlvmTranslator: TMirToLlvmTranslator;
  MirModule: TMirModule;
  PassManager: TMirPassManager;
  IntermediateRoot: string;
  LlvmIrArtifactPath: string;
  ObjectArtifactPath: string;
  OutputKindValue: string;
  PrimaryArtifactKindValue: string;
  PrimaryArtifactPath: string;
  PhaseScratch: IAllocator;
begin
  if FSemaModel = nil then
  begin
    FPlan.MarkFailure;
    Exit;
  end;

  FPlan.SetRootName(FSemaModel.RootName);
  FPlan.SetTargetMetadata(FTargetFacts);
  OutputKindValue := 'executable';
  PrimaryArtifactKindValue := 'executable';
  if SameText(Trim(FRootKindName), 'unit') then
  begin
    OutputKindValue := 'object-file';
    PrimaryArtifactKindValue := 'object-file';
  end;
  FPlan.SetOutputKind(OutputKindValue);
  BaseName := ChangeFileExt(ExtractFileName(FSourcePath), '');
  IntermediateRoot := BackendIntermediateRootPath;
  AssemblyArtifactPath := ExpandFileName(
    IncludeTrailingPathDelimiter(IntermediateRoot) + BaseName + '.s'
  );
  ObjectArtifactPath := ExpandFileName(
    IncludeTrailingPathDelimiter(IntermediateRoot) + BaseName + '.o'
  );
  if SameText(OutputKindValue, 'object-file') then
  begin
    if Trim(FOutputDirPath) <> '' then
      ObjectArtifactPath := ExpandFileName(
        IncludeTrailingPathDelimiter(FOutputDirPath) +
        BaseName + '.o'
      );
    PrimaryArtifactPath := ObjectArtifactPath;
  end
  else if Trim(FOutputDirPath) <> '' then
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

    { FsMkdirAll is procedure (INV-5): failure raises; map to plan failure. }
    try
      FsMkdirAll(IntermediateRoot);
    except
      FPlan.MarkFailure;
      Exit;
    end;

    { Phase scratch for HIR builder / MIR value-map working storage.
      MIR/HIR modules themselves stay on the default heap. }
    PhaseScratch := CompilerCreateUnitAllocator;
    try
      HirBuilder := THIRBuilder.Create(FSemaModel, nil, 0, PhaseScratch);
      try
        HirBuilder.Build;
        if GetEnvironmentVariable('NEXTPAS_MIR') = '1' then
        begin
          { Opt-in: HIR -> MIR -> MIR passes -> LLVM IR pipeline }
          Lowering := THirToMirLowering.Create(HirBuilder.Module, PhaseScratch);
          try
            Lowering.Lower;
            MirModule := Lowering.DetachModule;
          finally
            Lowering.Free;
          end;

          { Run MIR optimization passes; registry TVec on PhaseScratch }
          if not FNoFold then
          begin
            PassManager := TMirPassManager.Create(PhaseScratch);
            try
              RegisterMirPassesForLevel(PassManager, FOptLevel);
              PassManager.RunAll(MirModule);
            finally
              PassManager.Free;
            end;
          end;

          { MIR→LLVM output lines on PhaseScratch TVec }
          LlvmTranslator := TMirToLlvmTranslator.Create(MirModule, PhaseScratch);
          try
            LlvmTranslator.SaveToFile(LlvmIrArtifactPath);
          finally
            LlvmTranslator.Free;
          end;
        end
        else
        begin
          { Default: HIR -> LLVM IR direct path; lines/refs on PhaseScratch }
          HirEmitter := THIRLlvmEmitter.Create(HirBuilder.Module,
            FTargetFacts.LlvmTriple, FTargetFacts.LlvmDataLayout,
            False, PhaseScratch);
          try
            HirEmitter.EmitModule;
            HirEmitter.SaveToFile(LlvmIrArtifactPath);
          finally
            HirEmitter.Free;
          end;
        end;
      finally
        HirBuilder.Free;
      end;
    finally
      PhaseScratch := nil;
    end;
  end
  else
    FPlan.AddArtifact('assembly-text', AssemblyArtifactPath);

  FPlan.AddArtifact('object-file', ObjectArtifactPath);
  if SameText(OutputKindValue, 'executable') then
    FPlan.AddArtifact('executable', PrimaryArtifactPath);
  FPlan.SetPrimaryArtifact(PrimaryArtifactKindValue, PrimaryArtifactPath);
  FPlan.MarkReady;
end;

function TBackendPlanner.DetachPlan: TBackendPlan;
begin
  Result := FPlan;
  FPlan := nil;
end;

end.
