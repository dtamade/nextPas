unit np_backend_plan;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.backend.backend_plan;

type
  TBackendArtifact = nextpas.compiler.backend.backend_plan.TBackendArtifact;
  TBackendLogicalLibraryRequest = nextpas.compiler.backend.backend_plan.TBackendLogicalLibraryRequest;
  TBackendArtifactVec = nextpas.compiler.backend.backend_plan.TBackendArtifactVec;
  TBackendLogicalLibraryRequestVec = nextpas.compiler.backend.backend_plan.TBackendLogicalLibraryRequestVec;
  TBackendPlan = nextpas.compiler.backend.backend_plan.TBackendPlan;
  TBackendPlanner = nextpas.compiler.backend.backend_plan.TBackendPlanner;

implementation

end.