unit nextpas.compiler.toolchain.toolchain_plan;

{$mode objfpc}{$H+}

interface

uses
  np_toolchain_plan;

type
  TToolArtifactRef = np_toolchain_plan.TToolArtifactRef;
  TToolSidecarRef = np_toolchain_plan.TToolSidecarRef;
  TToolEnvDelta = np_toolchain_plan.TToolEnvDelta;
  TLogicalLibraryRequest = np_toolchain_plan.TLogicalLibraryRequest;
  TToolArtifactRefVec = np_toolchain_plan.TToolArtifactRefVec;
  TToolSidecarRefVec = np_toolchain_plan.TToolSidecarRefVec;
  TToolEnvDeltaVec = np_toolchain_plan.TToolEnvDeltaVec;
  TToolchainStringVec = np_toolchain_plan.TToolchainStringVec;
  TLogicalLibraryRequestVec = np_toolchain_plan.TLogicalLibraryRequestVec;
  TToolInvocationStep = np_toolchain_plan.TToolInvocationStep;
  TToolInvocationStepVec = np_toolchain_plan.TToolInvocationStepVec;
  TLogicalLinkRequest = np_toolchain_plan.TLogicalLinkRequest;
  TLlvmExecutableContract = np_toolchain_plan.TLlvmExecutableContract;
  TToolchainPlan = np_toolchain_plan.TToolchainPlan;
  TToolchainPlanner = np_toolchain_plan.TToolchainPlanner;

implementation

end.
