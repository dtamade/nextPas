unit nextpas.core.execution;

{** @desc execution 门面：通用执行抽象（单飞执行器），收敛 thread.pool/sync/platform.time
       多 L1 依赖为单一 execution 依赖。db.async 等上层经此单源消费执行能力。 */}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.execution.base,
  nextpas.core.execution.intf,
  nextpas.core.execution.single;

type
  TExecutionWork = nextpas.core.execution.base.TExecutionWork;
  IExecutionHandle = nextpas.core.execution.intf.IExecutionHandle;
  TSingleFlightExecutor = nextpas.core.execution.single.TSingleFlightExecutor;

const
  EXECUTION_MOUNT_OVERHEAD_US = nextpas.core.execution.base.EXECUTION_MOUNT_OVERHEAD_US;
  EXECUTION_MIN_WORTHWHILE_US = nextpas.core.execution.base.EXECUTION_MIN_WORTHWHILE_US;

function ExecutionShouldOffload(const AEstimatedUs: Cardinal): Boolean; inline;

implementation

function ExecutionShouldOffload(const AEstimatedUs: Cardinal): Boolean; inline;
begin
  Result := nextpas.core.execution.base.ExecutionShouldOffload(AEstimatedUs);
end;

end.
