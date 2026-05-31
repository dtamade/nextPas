unit nextpas.core.platform.process.base;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformProcess = record
  {$IFDEF NEXTPAS_WINDOWS}
    ProcessHandle: PtrUInt;
    ThreadHandle: PtrUInt;
    Pid: UInt32;
  {$ELSE}
    Pid: Int32;
  {$ENDIF}
  end;

  TPlatformProcessStatus = (
    psRunning,
    psExited,
    psSignaled,
    psUnknown
  );

  TPlatformProcessResult = record
    Status: TPlatformProcessStatus;
    ExitCode: Int32;
  end;

  TPlatformProcessPipes = record
    StdinWrite: PtrInt;
    StdoutRead: PtrInt;
    StderrRead: PtrInt;
  end;

implementation

end.
