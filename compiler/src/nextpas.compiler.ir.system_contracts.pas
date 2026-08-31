unit nextpas.compiler.ir.system_contracts;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.system.contracts;

type
  TSystemContractKind = (
    sckProcessInit,
    sckProcessFini,
    sckUnitInit,
    sckUnitFini,
    sckHalt,
    sckStringInit,
    sckStringFini,
    sckStringAssign,
    sckDynArrayInit,
    sckDynArrayFini,
    sckDynArraySetLength,
    sckInterfaceAddRef,
    sckInterfaceRelease,
    sckManagedRecordInit,
    sckManagedRecordFini,
    sckHeapAlloc,
    sckHeapFree,
    sckObjectAlloc,
    sckObjectFree,
    sckObjectFreeDestroy,
    sckObjectFreeCleanup,
    sckObjectFreeRelease,
    sckRuntimeFault,
    sckExceptionTryPush,
    sckExceptionTryPop,
    sckExceptionRaise,
    sckExceptionFinallyEnd,
    sckExceptionExceptEnd
  );

  TSystemContractEvidenceLevel = (
    scelVocabulary,
    scelSemantic,
    scelHir,
    scelBackend,
    scelExecutable
  );

  TSystemContractDefinition = record
    Kind: TSystemContractKind;
    SemanticName: string;
    DeclarationOwner: string;
    SourceSymbol: string;
    TargetIdentity: string;
    OwnershipIntent: string;
    FailureBehavior: string;
    HirEvidence: string;
    RuntimeMapping: string;
    FocusedEvidence: string;
    EvidenceLevel: TSystemContractEvidenceLevel;
  end;

function SystemContractCount: LongInt;
function SystemContractAt(AKind: TSystemContractKind): TSystemContractDefinition;
function TryFindSystemContract(const ASemanticName: string;
  out ADefinition: TSystemContractDefinition): Boolean;

implementation

const
  SYSTEM_CONTRACT_OWNER = 'nextpas.core.system.contracts';
  SYSTEM_CONTRACTS: array[TSystemContractKind] of TSystemContractDefinition = (
    (
      Kind: sckProcessInit;
      SemanticName: NPSYSTEM_PROCESS_INIT;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.np_process_init';
      TargetIdentity: 'process';
      OwnershipIntent: 'runtime-owned process state';
      FailureBehavior: 'runtime-startup-failed';
      HirEvidence: 'process-init-runtime';
      RuntimeMapping: 'np_process_init';
      FocusedEvidence: 'test_process_lifecycle';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckProcessFini;
      SemanticName: NPSYSTEM_PROCESS_FINI;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.np_process_fini';
      TargetIdentity: 'process';
      OwnershipIntent: 'runtime-owned process state';
      FailureBehavior: 'runtime-abort';
      HirEvidence: 'process-fini-runtime';
      RuntimeMapping: 'np_process_fini';
      FocusedEvidence: 'test_process_lifecycle';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckUnitInit;
      SemanticName: NPSYSTEM_UNIT_INIT;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System unit initialization';
      TargetIdentity: 'unit';
      OwnershipIntent: 'compiler-ordered unit state';
      FailureBehavior: 'unit-initialization-failed';
      HirEvidence: 'unit-init-runtime';
      RuntimeMapping: 'unit-specific init entry';
      FocusedEvidence: 'test_semantic_runtime_contract_seed';
      EvidenceLevel: scelSemantic
    ),
    (
      Kind: sckUnitFini;
      SemanticName: NPSYSTEM_UNIT_FINI;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System unit finalization';
      TargetIdentity: 'unit';
      OwnershipIntent: 'compiler-ordered unit state';
      FailureBehavior: 'unit-finalization-failed';
      HirEvidence: 'unit-fini-runtime';
      RuntimeMapping: 'unit-specific fini entry';
      FocusedEvidence: 'test_semantic_runtime_contract_seed';
      EvidenceLevel: scelSemantic
    ),
    (
      Kind: sckHalt;
      SemanticName: NPSYSTEM_HALT;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.Halt';
      TargetIdentity: 'exit-code';
      OwnershipIntent: 'none';
      FailureBehavior: 'runtime-abort';
      HirEvidence: 'typed sckHalt / halt-call-runtime';
      RuntimeMapping: 'backend halt lowering';
      FocusedEvidence: 'test_hir_halt_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckStringInit;
      SemanticName: NPSYSTEM_STRING_INIT;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.AnsiString';
      TargetIdentity: 'managed-string';
      OwnershipIntent: 'owned destination';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'tstring_init / np.system.string_init';
      RuntimeMapping: 'np_tstring_init';
      FocusedEvidence: 'test_hir_string_ownership_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckStringFini;
      SemanticName: NPSYSTEM_STRING_FINI;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.AnsiString';
      TargetIdentity: 'managed-string';
      OwnershipIntent: 'owned value release';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'tstring_fini / np.system.string_fini';
      RuntimeMapping: 'np_tstring_fini';
      FocusedEvidence: 'test_hir_string_ownership_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckStringAssign;
      SemanticName: NPSYSTEM_STRING_ASSIGN;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.AnsiString';
      TargetIdentity: 'managed-string';
      OwnershipIntent: 'copy or move assignment';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'tstring_assign / np.system.string_assign';
      RuntimeMapping: 'np_tstring_assign';
      FocusedEvidence: 'test_hir_string_ownership_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckDynArrayInit;
      SemanticName: NPSYSTEM_DYNARRAY_INIT;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System dynamic array';
      TargetIdentity: 'managed-dynarray';
      OwnershipIntent: 'owned destination';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'deferred';
      RuntimeMapping: 'deferred';
      FocusedEvidence: 'runtime-contracts.md';
      EvidenceLevel: scelVocabulary
    ),
    (
      Kind: sckDynArrayFini;
      SemanticName: NPSYSTEM_DYNARRAY_FINI;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System dynamic array';
      TargetIdentity: 'managed-dynarray';
      OwnershipIntent: 'owned value release';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'typed sckDynArrayFini / dynarray-cleanup-runtime';
      RuntimeMapping: 'np_dynarray_release';
      FocusedEvidence: 'test_hir_dynarray_typed_contract';
      EvidenceLevel: scelExecutable
    ),
    (
      Kind: sckDynArraySetLength;
      SemanticName: NPSYSTEM_DYNARRAY_SET_LENGTH;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System dynamic array';
      TargetIdentity: 'managed-dynarray';
      OwnershipIntent: 'owned buffer resize';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'typed sckDynArraySetLength / setlength-arr-runtime';
      RuntimeMapping: 'np_dynarray_resize';
      FocusedEvidence: 'test_hir_dynarray_typed_contract';
      EvidenceLevel: scelExecutable
    ),
    (
      Kind: sckInterfaceAddRef;
      SemanticName: NPSYSTEM_INTERFACE_ADDREF;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System interface reference';
      TargetIdentity: 'interface-reference';
      OwnershipIntent: 'shared reference acquire';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'typed sckInterfaceAddRef / intf-addref-runtime';
      RuntimeMapping: 'np_intf_addref';
      FocusedEvidence: 'test_hir_interface_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckInterfaceRelease;
      SemanticName: NPSYSTEM_INTERFACE_RELEASE;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System interface reference';
      TargetIdentity: 'interface-reference';
      OwnershipIntent: 'shared reference release';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'typed sckInterfaceRelease / intf-release-runtime';
      RuntimeMapping: 'np_intf_release';
      FocusedEvidence: 'test_hir_interface_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckManagedRecordInit;
      SemanticName: NPSYSTEM_MANAGED_RECORD_INIT;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System managed record';
      TargetIdentity: 'managed-record';
      OwnershipIntent: 'owned fields initialize';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'deferred';
      RuntimeMapping: 'deferred';
      FocusedEvidence: 'runtime-contracts.md';
      EvidenceLevel: scelVocabulary
    ),
    (
      Kind: sckManagedRecordFini;
      SemanticName: NPSYSTEM_MANAGED_RECORD_FINI;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System managed record';
      TargetIdentity: 'managed-record';
      OwnershipIntent: 'owned fields release';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'typed sckManagedRecordFini / managed-record-cleanup-runtime';
      RuntimeMapping: 'compiler-planned field cleanup';
      FocusedEvidence: 'test_hir_managed_record_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckHeapAlloc;
      SemanticName: NPSYSTEM_HEAP_ALLOC;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.GetMem';
      TargetIdentity: 'allocation-size';
      OwnershipIntent: 'caller-owned allocation';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'typed sckHeapAlloc / getmem-runtime';
      RuntimeMapping: 'np_alloc';
      FocusedEvidence: 'test_hir_heap_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckHeapFree;
      SemanticName: NPSYSTEM_HEAP_FREE;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.FreeMem';
      TargetIdentity: 'allocation';
      OwnershipIntent: 'owned allocation release';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'typed sckHeapFree / freemem-runtime';
      RuntimeMapping: 'np_free';
      FocusedEvidence: 'test_hir_heap_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckObjectAlloc;
      SemanticName: NPSYSTEM_OBJECT_ALLOC;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.TObject.Create / class-new';
      TargetIdentity: 'class-instance';
      OwnershipIntent: 'caller-owned object allocation';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'typed sckObjectAlloc / class-new-runtime';
      RuntimeMapping: 'np_object_alloc';
      FocusedEvidence: 'test_hir_object_alloc_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckObjectFree;
      SemanticName: NPSYSTEM_OBJECT_FREE;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.TObject.Free';
      TargetIdentity: 'class-instance';
      OwnershipIntent: 'owned object release';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'object-free-runtime';
      RuntimeMapping: 'np_object_free_release';
      FocusedEvidence: 'test_hir_object_free_contract';
      EvidenceLevel: scelBackend
    ),
    (
      Kind: sckObjectFreeDestroy;
      SemanticName: NPSYSTEM_OBJECT_FREE_DESTROY;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.TObject.Destroy';
      TargetIdentity: 'class-instance';
      OwnershipIntent: 'object destruction';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'np.system.object_free.destroy';
      RuntimeMapping: 'virtual Destroy dispatch';
      FocusedEvidence: 'test_hir_object_free_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckObjectFreeCleanup;
      SemanticName: NPSYSTEM_OBJECT_FREE_CLEANUP;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.TObject.Free';
      TargetIdentity: 'class-instance';
      OwnershipIntent: 'managed field cleanup';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'np.system.object_free.cleanup';
      RuntimeMapping: 'compiler-planned cleanup';
      FocusedEvidence: 'test_hir_object_free_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckObjectFreeRelease;
      SemanticName: NPSYSTEM_OBJECT_FREE_RELEASE;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System.TObject.Free';
      TargetIdentity: 'class-instance';
      OwnershipIntent: 'object storage release';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'np.system.object_free.release';
      RuntimeMapping: 'np_object_free_release';
      FocusedEvidence: 'test_hir_object_free_contract';
      EvidenceLevel: scelBackend
    ),
    (
      Kind: sckRuntimeFault;
      SemanticName: NPSYSTEM_RUNTIME_FAULT;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System runtime fault boundary';
      TargetIdentity: 'fault-code';
      OwnershipIntent: 'none';
      FailureBehavior: 'runtime-fault';
      HirEvidence: 'fault-specific nodes';
      RuntimeMapping: 'np_allocator_fault and np_dynarray_fault';
      FocusedEvidence: 'runtime-contracts.md';
      EvidenceLevel: scelBackend
    ),
    (
      Kind: sckExceptionTryPush;
      SemanticName: NPSYSTEM_EXCEPTION_TRY_PUSH;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System exception boundary';
      TargetIdentity: 'exception-frame';
      OwnershipIntent: 'runtime-owned exception frame';
      FailureBehavior: 'runtime-abort';
      HirEvidence: 'typed sckExceptionTryPush / try-begin-runtime';
      RuntimeMapping: 'np_try_push';
      FocusedEvidence: 'test_hir_exception_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckExceptionTryPop;
      SemanticName: NPSYSTEM_EXCEPTION_TRY_POP;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System exception boundary';
      TargetIdentity: 'exception-frame';
      OwnershipIntent: 'runtime-owned exception frame';
      FailureBehavior: 'runtime-abort';
      HirEvidence: 'typed sckExceptionTryPop / try-end-runtime';
      RuntimeMapping: 'np_try_pop';
      FocusedEvidence: 'test_hir_exception_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckExceptionRaise;
      SemanticName: NPSYSTEM_EXCEPTION_RAISE;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System exception boundary';
      TargetIdentity: 'exception-object';
      OwnershipIntent: 'transferred exception object';
      FailureBehavior: 'runtime-abort';
      HirEvidence: 'typed sckExceptionRaise / raise-runtime';
      RuntimeMapping: 'np_raise';
      FocusedEvidence: 'test_hir_exception_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckExceptionFinallyEnd;
      SemanticName: NPSYSTEM_EXCEPTION_FINALLY_END;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System exception boundary';
      TargetIdentity: 'exception-frame';
      OwnershipIntent: 'runtime-owned exception frame';
      FailureBehavior: 'runtime-abort';
      HirEvidence: 'typed sckExceptionFinallyEnd / finally-end-runtime';
      RuntimeMapping: 'np_finally_end';
      FocusedEvidence: 'test_hir_exception_contract';
      EvidenceLevel: scelHir
    ),
    (
      Kind: sckExceptionExceptEnd;
      SemanticName: NPSYSTEM_EXCEPTION_EXCEPT_END;
      DeclarationOwner: SYSTEM_CONTRACT_OWNER;
      SourceSymbol: 'System exception boundary';
      TargetIdentity: 'exception-frame';
      OwnershipIntent: 'runtime-owned exception frame';
      FailureBehavior: 'runtime-abort';
      HirEvidence: 'typed sckExceptionExceptEnd / except-end-runtime';
      RuntimeMapping: 'np_except_end';
      FocusedEvidence: 'test_hir_exception_contract';
      EvidenceLevel: scelHir
    )
  );

function EmptySystemContractDefinition: TSystemContractDefinition;
begin
  Result.Kind := Low(TSystemContractKind);
  Result.SemanticName := '';
  Result.DeclarationOwner := '';
  Result.SourceSymbol := '';
  Result.TargetIdentity := '';
  Result.OwnershipIntent := '';
  Result.FailureBehavior := '';
  Result.HirEvidence := '';
  Result.RuntimeMapping := '';
  Result.FocusedEvidence := '';
  Result.EvidenceLevel := scelVocabulary;
end;

function SystemContractCount: LongInt;
begin
  Result := Ord(High(TSystemContractKind)) - Ord(Low(TSystemContractKind)) + 1;
end;

function SystemContractAt(AKind: TSystemContractKind): TSystemContractDefinition;
begin
  if (Ord(AKind) < Ord(Low(TSystemContractKind))) or
    (Ord(AKind) > Ord(High(TSystemContractKind))) then
    Exit(EmptySystemContractDefinition);
  Result := SYSTEM_CONTRACTS[AKind];
end;

function TryFindSystemContract(const ASemanticName: string;
  out ADefinition: TSystemContractDefinition): Boolean;
var
  Candidate: TSystemContractDefinition;
  Kind: TSystemContractKind;
begin
  ADefinition := EmptySystemContractDefinition;
  for Kind := Low(TSystemContractKind) to High(TSystemContractKind) do
  begin
    Candidate := SystemContractAt(Kind);
    if Candidate.SemanticName = ASemanticName then
    begin
      ADefinition := Candidate;
      Exit(True);
    end;
  end;
  Result := False;
end;

end.
