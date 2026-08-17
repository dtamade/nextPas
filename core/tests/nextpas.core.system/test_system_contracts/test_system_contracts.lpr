program test_system_contracts;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.system.contracts,
  np_system_contracts;

var
  T: TTestSuite;

procedure TestCoreContractNames;
begin
  CheckEqual('np.system.process_init', NPSYSTEM_PROCESS_INIT,
    'process init contract name should be stable');
  CheckEqual('np.system.process_fini', NPSYSTEM_PROCESS_FINI,
    'process fini contract name should be stable');
  CheckEqual('np.system.unit_init', NPSYSTEM_UNIT_INIT,
    'unit init contract name should be stable');
  CheckEqual('np.system.unit_fini', NPSYSTEM_UNIT_FINI,
    'unit fini contract name should be stable');
  CheckEqual('np.system.halt', NPSYSTEM_HALT,
    'halt contract name should be stable');
  CheckEqual('np.system.runtime_fault', NPSYSTEM_RUNTIME_FAULT,
    'runtime fault contract name should be stable');
  CheckEqual('np.system.string_init', NPSYSTEM_STRING_INIT,
    'string init contract name should be stable');
  CheckEqual('np.system.string_fini', NPSYSTEM_STRING_FINI,
    'string fini contract name should be stable');
  CheckEqual('np.system.string_assign', NPSYSTEM_STRING_ASSIGN,
    'string assign contract name should be stable');
  CheckEqual('np.system.dynarray_init', NPSYSTEM_DYNARRAY_INIT,
    'dynamic array init contract name should be stable');
  CheckEqual('np.system.dynarray_fini', NPSYSTEM_DYNARRAY_FINI,
    'dynamic array fini contract name should be stable');
  CheckEqual('np.system.dynarray_set_length', NPSYSTEM_DYNARRAY_SET_LENGTH,
    'dynamic array resize contract name should be stable');
  CheckEqual('np.system.interface_addref', NPSYSTEM_INTERFACE_ADDREF,
    'interface addref contract name should be stable');
  CheckEqual('np.system.interface_release', NPSYSTEM_INTERFACE_RELEASE,
    'interface release contract name should be stable');
  CheckEqual('np.system.managed_record_init', NPSYSTEM_MANAGED_RECORD_INIT,
    'managed record init contract name should be stable');
  CheckEqual('np.system.managed_record_fini', NPSYSTEM_MANAGED_RECORD_FINI,
    'managed record fini contract name should be stable');
  CheckEqual('np.system.heap_alloc', NPSYSTEM_HEAP_ALLOC,
    'heap allocation contract name should be stable');
  CheckEqual('np.system.heap_free', NPSYSTEM_HEAP_FREE,
    'heap free contract name should be stable');
end;

procedure TestObjectFreeContractNames;
begin
  CheckEqual('np.system.object_free', NPSYSTEM_OBJECT_FREE,
    'object free contract name should be stable');
  CheckEqual('np.system.object_free.destroy', NPSYSTEM_OBJECT_FREE_DESTROY,
    'object free destroy sub-contract name should be stable');
  CheckEqual('np.system.object_free.cleanup', NPSYSTEM_OBJECT_FREE_CLEANUP,
    'object free cleanup sub-contract name should be stable');
  CheckEqual('np.system.object_free.release', NPSYSTEM_OBJECT_FREE_RELEASE,
    'object free release sub-contract name should be stable');
end;

procedure TestExceptionBoundaryContractNames;
begin
  CheckEqual('np.system.exception_try_push', NPSYSTEM_EXCEPTION_TRY_PUSH,
    'exception try push contract name should be stable');
  CheckEqual('np.system.exception_try_pop', NPSYSTEM_EXCEPTION_TRY_POP,
    'exception try pop contract name should be stable');
  CheckEqual('np.system.exception_raise', NPSYSTEM_EXCEPTION_RAISE,
    'exception raise contract name should be stable');
  CheckEqual('np.system.exception_finally_end', NPSYSTEM_EXCEPTION_FINALLY_END,
    'exception finally end contract name should be stable');
  CheckEqual('np.system.exception_except_end', NPSYSTEM_EXCEPTION_EXCEPT_END,
    'exception except end contract name should be stable');
end;

procedure TestLedgerCompleteness;
var
  Definition: TSystemContractDefinition;
  Kind: TSystemContractKind;
  OtherDefinition: TSystemContractDefinition;
  OtherKind: TSystemContractKind;
begin
  CheckEqual(Int64(28), Int64(SystemContractCount),
    'ledger should cover every declared system contract');
  for Kind := Low(TSystemContractKind) to High(TSystemContractKind) do
  begin
    Definition := SystemContractAt(Kind);
    CheckEqual(Int64(Ord(Kind)), Int64(Ord(Definition.Kind)),
      'ledger index and contract kind should match');
    CheckStartsWith(Definition.SemanticName, 'np.system.',
      'semantic names should stay in the system namespace');
    CheckTrue(Definition.DeclarationOwner <> '',
      'declaration owner is required');
    CheckTrue(Definition.SourceSymbol <> '',
      'source symbol or deferred marker is required');
    CheckTrue(Definition.TargetIdentity <> '',
      'target identity is required');
    CheckTrue(Definition.OwnershipIntent <> '',
      'ownership intent is required');
    CheckTrue(Definition.FailureBehavior <> '',
      'failure behavior is required');
    CheckTrue(Definition.HirEvidence <> '',
      'HIR evidence or deferred marker is required');
    CheckTrue(Definition.RuntimeMapping <> '',
      'runtime mapping or deferred marker is required');
    CheckTrue(Definition.FocusedEvidence <> '',
      'focused evidence is required');
    if Kind < High(TSystemContractKind) then
      for OtherKind := Succ(Kind) to High(TSystemContractKind) do
      begin
        OtherDefinition := SystemContractAt(OtherKind);
        CheckNotEqual(Definition.SemanticName, OtherDefinition.SemanticName,
          'semantic names must be unique');
      end;
  end;
end;

procedure TestLedgerLookup;
var
  Definition: TSystemContractDefinition;
begin
  CheckTrue(TryFindSystemContract(NPSYSTEM_OBJECT_FREE, Definition),
    'object-free contract should be discoverable');
  CheckEqual(Int64(Ord(sckObjectFree)), Int64(Ord(Definition.Kind)),
    'lookup should return typed object-free identity');
  CheckFalse(TryFindSystemContract('np.system.not_registered', Definition),
    'unknown contracts must fail closed');
  CheckFalse(TryFindSystemContract('NP.SYSTEM.OBJECT_FREE', Definition),
    'contract lookup must stay case sensitive');
end;

begin
  T := TTestSuite.Create('nextpas.core.system.contracts');
  T.Test('core contract names', @TestCoreContractNames);
  T.Test('object free contract names', @TestObjectFreeContractNames);
  T.Test('exception boundary contract names', @TestExceptionBoundaryContractNames);
  T.Test('typed ledger completeness', @TestLedgerCompleteness);
  T.Test('typed ledger lookup', @TestLedgerLookup);
  if not T.Run then Halt(1);
end.
