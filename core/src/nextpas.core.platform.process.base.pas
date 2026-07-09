unit nextpas.core.platform.process.base;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc 进程句柄（平台无关封装） *}
  TPlatformProcess = record
  {$IFDEF NEXTPAS_WINDOWS}
    ProcessHandle: PtrUInt;
    ThreadHandle: PtrUInt;
    Pid: UInt32;
  {$ELSE}
    Pid: Int32;
  {$ENDIF}
  end;

  {** @desc 进程退出状态枚举 *}
  TPlatformProcessStatus = (
    psRunning,
    psExited,
    psSignaled,
    psUnknown
  );

  {** @desc 进程运行结果 *}
  TPlatformProcessResult = record
    Status: TPlatformProcessStatus;
    ExitCode: Int32;
  end;

  {** @desc 进程管道集合（stdin/stdout/stderr） *}
  TPlatformProcessPipes = record
    StdinWrite: PtrInt;
    StdoutRead: PtrInt;
    StderrRead: PtrInt;
  end;

  {** @desc 进程启动失败阶段枚举 *}
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

  {** @desc POSIX spawn 错误传输结构（通过管道传递） *}
  TPosixSpawnWireError = packed record
    Stage: UInt8;
    Reserved: array[0..2] of UInt8;
    ErrNo: Int32;
  end;
implementation

end.
