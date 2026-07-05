program test_system_contracts;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.system.contracts;

var
  T: TTestSuite;

procedure TestProcessLifecycleContractNames;
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

begin
  T := TTestSuite.Create('nextpas.core.system.contracts');
  T.Test('process and lifecycle contract names', @TestProcessLifecycleContractNames);
  T.Test('object free contract names', @TestObjectFreeContractNames);
  T.Test('exception boundary contract names', @TestExceptionBoundaryContractNames);
  if not T.Run then Halt(1);
end.
