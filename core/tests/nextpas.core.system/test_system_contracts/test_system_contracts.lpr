program test_system_contracts;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.system.contracts;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.system.contracts');
  T.Run('process and lifecycle contract names', @TestProcessLifecycleContractNames);
  T.Run('object free contract names', @TestObjectFreeContractNames);
  T.Summary;
end.
