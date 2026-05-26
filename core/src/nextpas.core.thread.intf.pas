unit nextpas.core.thread.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.base;

type
  IThreadPool = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111000001}']
    procedure Submit(const ATask: TThreadTask);
    procedure Shutdown;
    procedure WaitAll;
    function GetWorkerCount: Integer;
    property WorkerCount: Integer read GetWorkerCount;
  end;

  generic IChannel<T> = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111000002}']
    procedure Send(const AValue: T);
    function Receive(out AValue: T): Boolean;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

end.
