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


  TPlatformProcessSpawnStage = (
    pssNone,
    pssPipe,
    pssFork,
    pssChdir,
    pssDupStdin,
    pssDupStdout,
    pssDupStderr,
    pssExec
  );

  TPosixSpawnWireError = packed record
    Stage: UInt8;
    Reserved: array[0..2] of UInt8;
    ErrNo: Int32;
  end;
implementation

end.
