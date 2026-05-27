program test_platform_ffi_import_workflow;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  DOC_PATH_FROM_TEST = '../../../docs/platform-ffi-import-workflow.md';
  DOC_PATH_FROM_ROOT = 'core/docs/platform-ffi-import-workflow.md';
  DESIGN_CONVENTIONS_PATH_FROM_TEST = '../../../docs/design-conventions.md';
  DESIGN_CONVENTIONS_PATH_FROM_ROOT = 'core/docs/design-conventions.md';
  SOURCE_EVIDENCE_PATH_FROM_TEST = '../../../docs/platform-ffi-source-evidence-index.md';
  SOURCE_EVIDENCE_PATH_FROM_ROOT = 'core/docs/platform-ffi-source-evidence-index.md';
  HOST_GAP_MATRIX_PATH_FROM_TEST = '../../../docs/platform-host-ffi-gap-matrix.md';
  HOST_GAP_MATRIX_PATH_FROM_ROOT = 'core/docs/platform-host-ffi-gap-matrix.md';
  VERIFY_LOCAL_PATH_FROM_TEST = '../../../../build/verify_local.sh';
  VERIFY_LOCAL_PATH_FROM_ROOT = 'build/verify_local.sh';

var
  T: TTestRunner;

function ReadSourceFile(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LowerCase(LLine) + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolvePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

function ResolveRequiredPath(
  const APathFromTest,
  APathFromRoot,
  AMessage: string): string;
begin
  Result := ResolvePath(APathFromTest, APathFromRoot);
  Check(FileExists(Result), AMessage + ': ' + Result);
end;

procedure CheckTokenPresent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckWorkflowDocument(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform ffi import workflow',
    'workflow doc must have the canonical title');
  CheckTokenPresent(ADoc, 'fpc source is reference authority, not production dependency',
    'workflow doc must preserve the FPC dependency boundary');
  CheckTokenPresent(ADoc, 'api import wave',
    'workflow doc must name the batch unit');
  CheckTokenPresent(ADoc, 'source evidence',
    'workflow doc must require source evidence before declarations');
  CheckTokenPresent(ADoc, 'host base/ffi owner',
    'workflow doc must require host ownership before declarations');
  CheckTokenPresent(ADoc, 'red gate',
    'workflow doc must require a failing source-surface gate before import');
  CheckTokenPresent(ADoc, 'green import',
    'workflow doc must name the implementation phase');
  CheckTokenPresent(ADoc, 'raw os api',
    'workflow doc must name the raw OS API boundary');
  CheckTokenPresent(ADoc, 'not runtime tests',
    'workflow doc must forbid raw OS API runtime tests');
  CheckTokenPresent(ADoc, 'linux runtime',
    'workflow doc must distinguish Linux runtime evidence');
  CheckTokenPresent(ADoc, 'win64 compile-only',
    'workflow doc must distinguish Win64 compile-only evidence');
  CheckTokenPresent(ADoc, 'simulated host compile-only',
    'workflow doc must distinguish simulated host evidence');
  CheckTokenPresent(ADoc, 'task_plan.md',
    'workflow doc must require task_plan persistence');
  CheckTokenPresent(ADoc, 'progress.md',
    'workflow doc must require progress persistence');
  CheckTokenPresent(ADoc, 'findings.md',
    'workflow doc must require findings persistence');
  CheckTokenPresent(ADoc, 'recovery entry',
    'workflow doc must provide a recovery entry');
  CheckTokenPresent(ADoc, 'worktree',
    'workflow doc must require isolated worktrees');
  CheckTokenPresent(ADoc, 'commit',
    'workflow doc must require traceable commits');
  CheckTokenPresent(ADoc, 'merge',
    'workflow doc must require an explicit merge step');
  CheckTokenPresent(ADoc, 'cleanup',
    'workflow doc must require cleanup after merge');
end;

procedure CheckRouteTruth(
  const ADesign,
  ASourceEvidence,
  AGapMatrix,
  AVerify: string);
begin
  CheckTokenPresent(ADesign, 'docs/platform-ffi-import-workflow.md',
    'design conventions must index the workflow doc');
  CheckTokenPresent(ADesign, 'core-platform-ffi-import-workflow-check',
    'design conventions must name the workflow line token');
  CheckTokenPresent(ADesign, 'coreplatformffiimportworkflowcheck',
    'design conventions must name the workflow envelope token');
  CheckTokenPresent(ASourceEvidence, 'docs/platform-ffi-import-workflow.md',
    'source evidence index must point to the import workflow');
  CheckTokenPresent(AGapMatrix, 'docs/platform-ffi-import-workflow.md',
    'host gap matrix must point to the import workflow');
  CheckTokenPresent(AVerify, 'require_path core/docs/platform-ffi-import-workflow.md',
    'verify_local must require the workflow doc');
  CheckTokenPresent(AVerify, 'core-platform-ffi-import-workflow-check=running',
    'verify_local must run the workflow focused check');
  CheckTokenPresent(AVerify, 'nextpas\.core\.platform\.ffi_import_workflow: 2 total, 2 passed, 0 failed',
    'verify_local must assert the workflow summary');
  CheckTokenPresent(AVerify, 'coreplatformffiimportworkflowcheck',
    'verify_local final envelope must include the workflow token');
end;

procedure TestWorkflowDocument;
var
  LDoc: string;
begin
  LDoc := ReadSourceFile(ResolveRequiredPath(
    DOC_PATH_FROM_TEST,
    DOC_PATH_FROM_ROOT,
    'platform ffi import workflow doc must exist'));

  CheckWorkflowDocument(LDoc);
end;

procedure TestWorkflowRouteTruth;
var
  LDesign: string;
  LSourceEvidence: string;
  LGapMatrix: string;
  LVerify: string;
begin
  LDesign := ReadSourceFile(ResolveRequiredPath(
    DESIGN_CONVENTIONS_PATH_FROM_TEST,
    DESIGN_CONVENTIONS_PATH_FROM_ROOT,
    'design conventions doc must exist'));
  LSourceEvidence := ReadSourceFile(ResolveRequiredPath(
    SOURCE_EVIDENCE_PATH_FROM_TEST,
    SOURCE_EVIDENCE_PATH_FROM_ROOT,
    'source evidence index doc must exist'));
  LGapMatrix := ReadSourceFile(ResolveRequiredPath(
    HOST_GAP_MATRIX_PATH_FROM_TEST,
    HOST_GAP_MATRIX_PATH_FROM_ROOT,
    'platform host gap matrix doc must exist'));
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckRouteTruth(LDesign, LSourceEvidence, LGapMatrix, LVerify);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.ffi_import_workflow');
  T.Run('platform ffi import workflow doc is explicit', @TestWorkflowDocument);
  T.Run('platform ffi import workflow route truth stays indexed', @TestWorkflowRouteTruth);
  T.Summary;
end.
