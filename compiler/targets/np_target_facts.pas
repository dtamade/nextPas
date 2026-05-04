unit np_target_facts;

{$mode objfpc}{$H+}

interface

type
  TTargetFactsView = record
    TargetId: string;
    ConfigPath: string;
    HostId: string;
    HostOS: string;
    HostCPU: string;
    CompilerExecutable: string;
    UnitsDir: string;
    ObjectFormat: string;
    AssemblerFlavor: string;
    LinkerFlavor: string;
    RuntimeLayoutKey: string;
    CSymbolPrefix: string;
    CLibraryNaming: string;
    LlvmTriple: string;
    LlvmDataLayout: string;
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

function BuildTargetFactsView(
  const ATargetId: string;
  const AConfigPath: string;
  const AHostId: string;
  const AHostOS: string;
  const AHostCPU: string;
  const ACompilerExecutable: string;
  const AUnitsDir: string;
  const AObjectFormat: string;
  const AAssemblerFlavor: string;
  const ALinkerFlavor: string;
  const ARuntimeLayoutKey: string;
  const ACSymbolPrefix: string;
  const ACLibraryNaming: string;
  const ALlvmTriple: string;
  const ALlvmDataLayout: string;
  const AToolchainBindingId: string;
  const AHostCompilerProfileId: string;
  const ABackendFamily: string;
  const AAssemblerProfileId: string;
  const ALinkerProfileId: string;
  const AArchiverProfileId: string;
  const AResourceToolProfileId: string;
  const ASysrootMode: string;
  const ARuntimeSdkId: string;
  const AAllowHostFallback: Boolean;
  const AToolRootKind: string;
  const ARuntimeRootKind: string;
  const AResponseFilePolicy: string;
  const ALinkScriptPolicy: string;
  const ALlvmEnabled: Boolean;
  const ALlvmExecutableSetId: string
): TTargetFactsView;

implementation

function BuildTargetFactsView(
  const ATargetId: string;
  const AConfigPath: string;
  const AHostId: string;
  const AHostOS: string;
  const AHostCPU: string;
  const ACompilerExecutable: string;
  const AUnitsDir: string;
  const AObjectFormat: string;
  const AAssemblerFlavor: string;
  const ALinkerFlavor: string;
  const ARuntimeLayoutKey: string;
  const ACSymbolPrefix: string;
  const ACLibraryNaming: string;
  const ALlvmTriple: string;
  const ALlvmDataLayout: string;
  const AToolchainBindingId: string;
  const AHostCompilerProfileId: string;
  const ABackendFamily: string;
  const AAssemblerProfileId: string;
  const ALinkerProfileId: string;
  const AArchiverProfileId: string;
  const AResourceToolProfileId: string;
  const ASysrootMode: string;
  const ARuntimeSdkId: string;
  const AAllowHostFallback: Boolean;
  const AToolRootKind: string;
  const ARuntimeRootKind: string;
  const AResponseFilePolicy: string;
  const ALinkScriptPolicy: string;
  const ALlvmEnabled: Boolean;
  const ALlvmExecutableSetId: string
): TTargetFactsView;
begin
  Result.TargetId := ATargetId;
  Result.ConfigPath := AConfigPath;
  Result.HostId := AHostId;
  Result.HostOS := AHostOS;
  Result.HostCPU := AHostCPU;
  Result.CompilerExecutable := ACompilerExecutable;
  Result.UnitsDir := AUnitsDir;
  Result.ObjectFormat := AObjectFormat;
  Result.AssemblerFlavor := AAssemblerFlavor;
  Result.LinkerFlavor := ALinkerFlavor;
  Result.RuntimeLayoutKey := ARuntimeLayoutKey;
  Result.CSymbolPrefix := ACSymbolPrefix;
  Result.CLibraryNaming := ACLibraryNaming;
  Result.LlvmTriple := ALlvmTriple;
  Result.LlvmDataLayout := ALlvmDataLayout;
  Result.ToolchainBindingId := AToolchainBindingId;
  Result.HostCompilerProfileId := AHostCompilerProfileId;
  Result.BackendFamily := ABackendFamily;
  Result.AssemblerProfileId := AAssemblerProfileId;
  Result.LinkerProfileId := ALinkerProfileId;
  Result.ArchiverProfileId := AArchiverProfileId;
  Result.ResourceToolProfileId := AResourceToolProfileId;
  Result.SysrootMode := ASysrootMode;
  Result.RuntimeSdkId := ARuntimeSdkId;
  Result.AllowHostFallback := AAllowHostFallback;
  Result.ToolRootKind := AToolRootKind;
  Result.RuntimeRootKind := ARuntimeRootKind;
  Result.ResponseFilePolicy := AResponseFilePolicy;
  Result.LinkScriptPolicy := ALinkScriptPolicy;
  Result.LlvmEnabled := ALlvmEnabled;
  Result.LlvmExecutableSetId := ALlvmExecutableSetId;
end;

end.
