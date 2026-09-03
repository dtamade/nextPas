unit nextpas.core.execution.intf;

{$I nextpas.core.settings.inc}

interface

type
  { 单飞执行句柄（通用，不含 db 取消语义） }
  IExecutionHandle = interface
    ['{E7F3A10B-5C2D-4A8B-9F11-3D2A6C9E0011}']
    function IsDone: Boolean;
    function WaitFor(const ATimeoutMs: Cardinal): Boolean;
    function ErrorObj: Exception;
  end;

implementation

end.
