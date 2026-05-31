unit nextpas.core.process;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.process.base;

type
  TProcessResult = nextpas.core.process.base.TProcessResult;
  TProcessOptions = nextpas.core.process.base.TProcessOptions;

function Execute(const AExecutable: string;
  const AArgs: array of string): TProcessResult;
function Execute(const AExecutable: string;
  const AArgs: array of string;
  const AWorkDir: string): TProcessResult;
function ExecuteWithOptions(const AExecutable: string;
  const AArgs: array of string;
  const AOptions: TProcessOptions): TProcessResult;
function CaptureOutput(const AExecutable: string;
  const AArgs: array of string): string;

implementation

uses
  nextpas.core.platform.process,
  nextpas.core.platform.process.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

const
  READ_BUF_SIZE = 65536;

function BuildArgv(const AExecutable: string;
  const AArgs: array of string): PPAnsiChar;
var
  LArgc, I: Integer;
  LArr: array of PAnsiChar;
begin
  LArgc := Length(AArgs) + 2;
  SetLength(LArr, LArgc);
  LArr[0] := PAnsiChar(AExecutable);
  for I := 0 to High(AArgs) do
    LArr[I + 1] := PAnsiChar(AArgs[I]);
  LArr[LArgc - 1] := nil;
  Result := @LArr[0];
end;

function ReadPipeFd(AFd: Int32): string;
var
  LBuf: array[0..READ_BUF_SIZE - 1] of AnsiChar;
  LRead: ssize_t;
  LTotal: Int32;
  LResult: string;
begin
  LResult := '';
  LTotal := 0;
  repeat
    LRead := read(AFd, @LBuf[0], READ_BUF_SIZE);
    if LRead > 0 then
    begin
      SetLength(LResult, LTotal + LRead);
      Move(LBuf[0], LResult[LTotal + 1], LRead);
      Inc(LTotal, LRead);
    end;
  until LRead <= 0;
  Result := LResult;
end;

function ExecuteWithOptions(const AExecutable: string;
  const AArgs: array of string;
  const AOptions: TProcessOptions): TProcessResult;
var
  LProc: TPlatformProcess;
  LPipes: TPlatformProcessPipes;
  LWaitResult: TPlatformProcessResult;
  LArgv: array of PAnsiChar;
  LArgc, I, LErr: Integer;
  LCwd: PAnsiChar;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.ExitCode := -1;
  Result.Success := False;

  LArgc := Length(AArgs) + 2;
  SetLength(LArgv, LArgc);
  LArgv[0] := PAnsiChar(AExecutable);
  for I := 0 to High(AArgs) do
    LArgv[I + 1] := PAnsiChar(AArgs[I]);
  LArgv[LArgc - 1] := nil;

  if AOptions.WorkDir <> '' then
    LCwd := PAnsiChar(AOptions.WorkDir)
  else
    LCwd := nil;

  LErr := platform_process_spawn_piped_cwd(
    PAnsiChar(AExecutable), @LArgv[0], nil, LCwd, LProc, LPipes);
  if LErr <> 0 then
  begin
    Result.StdErr := 'Failed to spawn process: ' + AExecutable;
    Exit;
  end;

  close(LPipes.StdinWrite);

  Result.StdOut := ReadPipeFd(LPipes.StdoutRead);
  Result.StdErr := ReadPipeFd(LPipes.StderrRead);

  close(LPipes.StdoutRead);
  close(LPipes.StderrRead);

  platform_process_wait(LProc, LWaitResult);
  Result.ExitCode := LWaitResult.ExitCode;
  Result.Success := (LWaitResult.Status = psExited) and (LWaitResult.ExitCode = 0);
end;

function Execute(const AExecutable: string;
  const AArgs: array of string): TProcessResult;
begin
  Result := ExecuteWithOptions(AExecutable, AArgs, DEFAULT_PROCESS_OPTIONS);
end;

function Execute(const AExecutable: string;
  const AArgs: array of string;
  const AWorkDir: string): TProcessResult;
var
  LOpts: TProcessOptions;
begin
  LOpts := DEFAULT_PROCESS_OPTIONS;
  LOpts.WorkDir := AWorkDir;
  Result := ExecuteWithOptions(AExecutable, AArgs, LOpts);
end;

function CaptureOutput(const AExecutable: string;
  const AArgs: array of string): string;
var
  LResult: TProcessResult;
begin
  LResult := Execute(AExecutable, AArgs);
  Result := LResult.StdOut;
end;

end.
