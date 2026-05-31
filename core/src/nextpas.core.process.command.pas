unit nextpas.core.process.command;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.process.base,
  nextpas.core.process.child;

type
  { ICommand — Builder 接口，链式配置子进程 }
  ICommand = interface
    ['{A1B2C3D4-E5F6-7890-AB01-000000000010}']
    function Arg(const AValue: string): ICommand;
    function Args(const AValues: array of string): ICommand;
    function Dir(const AWorkDir: string): ICommand;
    function Env(const AEnvPairs: array of string): ICommand;
    function EnvAdd(const AKey, AValue: string): ICommand;
    function Stdin(const AMode: TStdio): ICommand;
    function Stdout(const AMode: TStdio): ICommand;
    function Stderr(const AMode: TStdio): ICommand;
    function Spawn: IChild;
    function Output: TProcessOutput;
    function Status: Integer;
  end;

  { TCommand — ICommand 实现 }
  TCommand = class(TInterfacedObject, ICommand)
  private
    FPath: string;
    FArgs: TStringArray;
    FWorkDir: string;
    FEnv: TStringArray;
    FStdinMode: TStdio;
    FStdoutMode: TStdio;
    FStderrMode: TStdio;
  public
    constructor Create(const APath: string);
    class function New(const APath: string): ICommand;
    function Arg(const AValue: string): ICommand;
    function Args(const AValues: array of string): ICommand;
    function Dir(const AWorkDir: string): ICommand;
    function Env(const AEnvPairs: array of string): ICommand;
    function EnvAdd(const AKey, AValue: string): ICommand;
    function Stdin(const AMode: TStdio): ICommand;
    function Stdout(const AMode: TStdio): ICommand;
    function Stderr(const AMode: TStdio): ICommand;
    function Spawn: IChild;
    function Output: TProcessOutput;
    function Status: Integer;
  end;

implementation

uses
  nextpas.core.io.intf,
  nextpas.core.process.pipe,
  nextpas.core.platform.process,
  nextpas.core.platform.process.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

{ TCommand }

constructor TCommand.Create(const APath: string);
begin
  inherited Create;
  FPath := APath;
  FArgs := nil;
  FWorkDir := '';
  FEnv := nil;
  FStdinMode := stInherit;
  FStdoutMode := stInherit;
  FStderrMode := stInherit;
end;

class function TCommand.New(const APath: string): ICommand;
begin
  Result := TCommand.Create(APath);
end;

function TCommand.Arg(const AValue: string): ICommand;
begin
  SetLength(FArgs, Length(FArgs) + 1);
  FArgs[High(FArgs)] := AValue;
  Result := Self;
end;

function TCommand.Args(const AValues: array of string): ICommand;
var
  I, LBase: Integer;
begin
  LBase := Length(FArgs);
  SetLength(FArgs, LBase + Length(AValues));
  for I := 0 to High(AValues) do
    FArgs[LBase + I] := AValues[I];
  Result := Self;
end;

function TCommand.Dir(const AWorkDir: string): ICommand;
begin
  FWorkDir := AWorkDir;
  Result := Self;
end;

function TCommand.Env(const AEnvPairs: array of string): ICommand;
var
  I: Integer;
begin
  SetLength(FEnv, Length(AEnvPairs));
  for I := 0 to High(AEnvPairs) do
    FEnv[I] := AEnvPairs[I];
  Result := Self;
end;

function TCommand.EnvAdd(const AKey, AValue: string): ICommand;
begin
  SetLength(FEnv, Length(FEnv) + 1);
  FEnv[High(FEnv)] := AKey + '=' + AValue;
  Result := Self;
end;

function TCommand.Stdin(const AMode: TStdio): ICommand;
begin
  FStdinMode := AMode;
  Result := Self;
end;

function TCommand.Stdout(const AMode: TStdio): ICommand;
begin
  FStdoutMode := AMode;
  Result := Self;
end;

function TCommand.Stderr(const AMode: TStdio): ICommand;
begin
  FStderrMode := AMode;
  Result := Self;
end;

function TCommand.Spawn: IChild;
var
  LArgv: array of PAnsiChar;
  LEnvp: array of PAnsiChar;
  LArgc, LEnvc, I, LErr: Integer;
  LProc: TPlatformProcess;
  LCwd: PAnsiChar;
  LStdinW: IWriter;
  LStdoutR: IReader;
  LStderrR: IReader;
  LStdinPipe, LStdoutPipe, LStderrPipe: array[0..1] of Int32;
  LChildStdin, LChildStdout, LChildStderr: PtrInt;
  LDevNull: Int32;
begin
  LArgc := Length(FArgs) + 2;
  SetLength(LArgv, LArgc);
  LArgv[0] := PAnsiChar(FPath);
  for I := 0 to High(FArgs) do
    LArgv[I + 1] := PAnsiChar(FArgs[I]);
  LArgv[LArgc - 1] := nil;

  if Length(FEnv) > 0 then
  begin
    LEnvc := Length(FEnv) + 1;
    SetLength(LEnvp, LEnvc);
    for I := 0 to High(FEnv) do
      LEnvp[I] := PAnsiChar(FEnv[I]);
    LEnvp[LEnvc - 1] := nil;
  end
  else
    LEnvp := nil;

  if FWorkDir <> '' then
    LCwd := PAnsiChar(FWorkDir)
  else
    LCwd := nil;

  LStdinW := nil;
  LStdoutR := nil;
  LStderrR := nil;
  LChildStdin := -1;
  LChildStdout := -1;
  LChildStderr := -1;

  if FStdinMode = stPiped then
  begin
    if pipe(@LStdinPipe[0]) <> 0 then
      raise EProcessError.Create('Failed to create stdin pipe');
    LChildStdin := LStdinPipe[0];
  end
  else if FStdinMode = stNull then
  begin
    LDevNull := nextpas.core.platform.posix.ffi.open('/dev/null', 0, 0);
    if LDevNull >= 0 then
      LChildStdin := LDevNull;
  end;

  if FStdoutMode = stPiped then
  begin
    if pipe(@LStdoutPipe[0]) <> 0 then
      raise EProcessError.Create('Failed to create stdout pipe');
    LChildStdout := LStdoutPipe[1];
  end
  else if FStdoutMode = stNull then
  begin
    LDevNull := nextpas.core.platform.posix.ffi.open('/dev/null', 1, 0);
    if LDevNull >= 0 then
      LChildStdout := LDevNull;
  end;

  if FStderrMode = stPiped then
  begin
    if pipe(@LStderrPipe[0]) <> 0 then
      raise EProcessError.Create('Failed to create stderr pipe');
    LChildStderr := LStderrPipe[1];
  end
  else if FStderrMode = stNull then
  begin
    LDevNull := nextpas.core.platform.posix.ffi.open('/dev/null', 1, 0);
    if LDevNull >= 0 then
      LChildStderr := LDevNull;
  end;

  if LEnvp <> nil then
    LErr := platform_process_spawn_fds(PAnsiChar(FPath), @LArgv[0], @LEnvp[0],
      LCwd, LChildStdin, LChildStdout, LChildStderr, LProc)
  else
    LErr := platform_process_spawn_fds(PAnsiChar(FPath), @LArgv[0], nil,
      LCwd, LChildStdin, LChildStdout, LChildStderr, LProc);

  if LErr <> 0 then
    raise EProcessError.Create('Failed to spawn: ' + FPath, LErr);

  if (FStdinMode = stPiped) then
    nextpas.core.platform.posix.ffi.close(LStdinPipe[0]);
  if (FStdoutMode = stPiped) then
    nextpas.core.platform.posix.ffi.close(LStdoutPipe[1]);
  if (FStderrMode = stPiped) then
    nextpas.core.platform.posix.ffi.close(LStderrPipe[1]);

  if FStdinMode = stPiped then
    LStdinW := TPipeWriter.Create(LStdinPipe[1]) as IWriter;
  if FStdoutMode = stPiped then
    LStdoutR := TPipeReader.Create(LStdoutPipe[0]) as IReader;
  if FStderrMode = stPiped then
    LStderrR := TPipeReader.Create(LStderrPipe[0]) as IReader;

  Result := TChild.Create(LProc, LStdinW, LStdoutR, LStderrR);
end;

function TCommand.Output: TProcessOutput;
var
  LChild: IChild;
begin
  FStdoutMode := stPiped;
  FStderrMode := stPiped;
  LChild := Spawn;
  Result := LChild.WaitWithOutput;
end;

function TCommand.Status: Integer;
var
  LChild: IChild;
  LOutput: TProcessOutput;
begin
  LChild := Spawn;
  LOutput := LChild.Wait;
  Result := LOutput.ExitCode;
end;

end.
