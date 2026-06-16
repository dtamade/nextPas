unit nextpas.core.process.command;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.time.base,
  nextpas.core.process.base,
  nextpas.core.process.child;

type
  {**
   * ICommand
   *
   * @desc 子进程配置 Builder（链式 API）
   *
   * @note 可多次调用 Spawn/Output/Status（每次创建新子进程）
   * @note 引用计数自动管理，无需手动释放
   *
   * @example
   *   Command('/bin/fpc').Args(['--version']).Dir('/tmp').Output;
   *}
  TProcessEnvMode = (
    pemInherit,
    pemReplace,
    pemOverlay
  );

  {** @note 非线程安全。不要在多个线程间共享同一个 ICommand 实例 *}
  ICommand = interface
    ['{A1B2C3D4-E5F6-7890-AB01-000000000010}']
    {** 追加单个命令行参数 *}
    function Arg(const AValue: string): ICommand;
    {** 追加多个命令行参数 *}
    function Args(const AValues: array of string): ICommand;
    {** 设置子进程工作目录 *}
    function Dir(const AWorkDir: string): ICommand;
    {** 完全替换子进程环境变量（格式：KEY=VALUE） *}
    function Env(const AEnvPairs: array of string): ICommand;
    {** 追加环境变量到替换列表（注意：设置任何 Env/EnvAdd 后不再继承父进程环境） *}
    function EnvAdd(const AKey, AValue: string): ICommand;
    {** 配置 stdin 模式 *}
    function Stdin(const AMode: TStdio): ICommand;
    {** 配置 stdout 模式 *}
    function Stdout(const AMode: TStdio): ICommand;
    {** 配置 stderr 模式 *}
    function Stderr(const AMode: TStdio): ICommand;
    {** 异步启动子进程，返回 IChild 句柄 *}
    function Spawn: IChild;
    {** 同步执行：自动设置 stdout+stderr 为 Piped，捕获输出 *}
    function Output: TProcessOutput;
    {** 同步执行：只返回退出码 *}
    function Status: Integer;
    {** 设置超时时间，超时后自动 Kill *}
    function Timeout(const ADuration: TDuration): ICommand;
  end;

  { TCommand — ICommand 实现 }
  TCommand = class(TInterfacedObject, ICommand)
  private
    FPath: string;
    FArgs: TStringArray;
    FWorkDir: string;
    FEnvMode: TProcessEnvMode;
    FEnvPairs: TStringArray;
    FStdinMode: TStdio;
    FStdoutMode: TStdio;
    FStderrMode: TStdio;
    FTimeout: TDuration;
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
    function Timeout(const ADuration: TDuration): ICommand;
  end;

implementation

uses
  nextpas.core.io.intf,
  nextpas.core.process.pipe,
  nextpas.core.platform.process,
  nextpas.core.platform.process.base,
  nextpas.core.os.env,
  nextpas.core.text.compare,
  nextpas.core.process.pathresolve;

{ TCommand }

function ContainsNul(const AValue: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(AValue) do
    if AValue[I] = #0 then
      Exit(True);
  Result := False;
end;

procedure ValidateNoNul(const AValue, AField: string);
begin
  if ContainsNul(AValue) then
    raise EProcessError.Create(AField + ' must not contain NUL');
end;

procedure ValidatePath(const APath: string);
begin
  if APath = '' then
    raise EProcessError.Create('command path must not be empty');
  ValidateNoNul(APath, 'command path');
end;

procedure ValidateEnvKey(const AKey: string);
begin
  if AKey = '' then
    raise EProcessError.Create('environment variable name must not be empty');
  if Pos('=', AKey) > 0 then
    raise EProcessError.Create('environment variable name must not contain "="');
  ValidateNoNul(AKey, 'environment variable name');
end;

procedure ValidateEnvValue(const AValue: string);
begin
  ValidateNoNul(AValue, 'environment variable value');
end;

procedure ValidateEnvPair(const APair: string);
var
  P: Integer;
begin
  ValidateNoNul(APair, 'environment variable pair');
  P := Pos('=', APair);
  if P <= 1 then
    raise EProcessError.Create('environment variable pair must be KEY=VALUE');
end;

procedure EnvPut(var AItems: TStringArray; const AKey, AValue: string);
var
  I, P: Integer;
  LKey: string;
begin
  for I := 0 to High(AItems) do
  begin
    P := Pos('=', AItems[I]);
    if P > 0 then
    begin
      LKey := Copy(AItems[I], 1, P - 1);
      if (EnvironmentVariableNamesCaseSensitive and (LKey = AKey)) or
        ((not EnvironmentVariableNamesCaseSensitive) and TextEqualI(LKey, AKey)) then
      begin
        AItems[I] := AKey + '=' + AValue;
        Exit;
      end;
    end;
  end;
  SetLength(AItems, Length(AItems) + 1);
  AItems[High(AItems)] := AKey + '=' + AValue;
end;

function BuildFinalEnv(const AMode: TProcessEnvMode;
  const AExplicit: TStringArray): TStringArray;
var
  I, P: Integer;
begin
  case AMode of
    pemInherit:
      Result := nil;
    pemReplace:
    begin
      SetLength(Result, Length(AExplicit));
      for I := 0 to High(AExplicit) do
        Result[I] := AExplicit[I];
    end;
    pemOverlay:
    begin
      Result := EnvironmentVariables;
      for I := 0 to High(AExplicit) do
      begin
        P := Pos('=', AExplicit[I]);
        if P > 0 then
          EnvPut(Result, Copy(AExplicit[I], 1, P - 1),
            Copy(AExplicit[I], P + 1, Length(AExplicit[I]) - P));
      end;
    end;
  end;
end;

constructor TCommand.Create(const APath: string);
begin
  inherited Create;
  ValidatePath(APath);
  FPath := APath;
  FArgs := nil;
  FWorkDir := '';
  FEnvMode := pemInherit;
  FEnvPairs := nil;
  FStdinMode := stInherit;
  FStdoutMode := stInherit;
  FStderrMode := stInherit;
  FTimeout := TDuration.Zero;
end;

class function TCommand.New(const APath: string): ICommand;
begin
  Result := TCommand.Create(APath);
end;

function TCommand.Arg(const AValue: string): ICommand;
begin
  ValidateNoNul(AValue, 'command argument');
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
  begin
    ValidateNoNul(AValues[I], 'command argument');
    FArgs[LBase + I] := AValues[I];
  end;
  Result := Self;
end;

function TCommand.Dir(const AWorkDir: string): ICommand;
begin
  ValidateNoNul(AWorkDir, 'working directory');
  FWorkDir := AWorkDir;
  Result := Self;
end;

function TCommand.Env(const AEnvPairs: array of string): ICommand;
var
  I: Integer;
begin
  FEnvMode := pemReplace;
  SetLength(FEnvPairs, Length(AEnvPairs));
  for I := 0 to High(AEnvPairs) do
  begin
    ValidateEnvPair(AEnvPairs[I]);
    FEnvPairs[I] := AEnvPairs[I];
  end;
  Result := Self;
end;

function TCommand.EnvAdd(const AKey, AValue: string): ICommand;
begin
  ValidateEnvKey(AKey);
  ValidateEnvValue(AValue);
  if FEnvMode = pemInherit then
    FEnvMode := pemOverlay;
  SetLength(FEnvPairs, Length(FEnvPairs) + 1);
  FEnvPairs[High(FEnvPairs)] := AKey + '=' + AValue;
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
  LStdinPipe, LStdoutPipe, LStderrPipe: array[0..1] of PtrInt;
  LChildStdin, LChildStdout, LChildStderr: PtrInt;
  LDevNull: PtrInt;
  LFinalEnv: TStringArray;
  LFailStage: TPlatformProcessSpawnStage;
  LResolvedPath: string;
  LCleanFds: array[0..8] of PtrInt;
  LCleanCount, LCleanIdx: Integer;
begin
  { Resolve path: search PATH if using custom env and name has no directory part }
  if (FEnvMode <> pemInherit) and (not CommandPathHasDirectoryPart(FPath)) then
  begin
    LFinalEnv := BuildFinalEnv(FEnvMode, FEnvPairs);
    LResolvedPath := ResolveExecutablePath(FPath, LFinalEnv, FWorkDir);
  end
  else
    LResolvedPath := FPath;

  LArgc := Length(FArgs) + 2;
  SetLength(LArgv, LArgc);
  LArgv[0] := PAnsiChar(LResolvedPath);
  for I := 0 to High(FArgs) do
    LArgv[I + 1] := PAnsiChar(FArgs[I]);
  LArgv[LArgc - 1] := nil;

  { Build envp based on env mode }
  if FEnvMode = pemInherit then
    LEnvp := nil
  else
  begin
    LFinalEnv := BuildFinalEnv(FEnvMode, FEnvPairs);
    LEnvc := Length(LFinalEnv) + 1;
    SetLength(LEnvp, LEnvc);
    for I := 0 to High(LFinalEnv) do
      LEnvp[I] := PAnsiChar(LFinalEnv[I]);
    LEnvp[LEnvc - 1] := nil;
  end;

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
  LStdinPipe[0] := -1; LStdinPipe[1] := -1;
  LStdoutPipe[0] := -1; LStdoutPipe[1] := -1;
  LStderrPipe[0] := -1; LStderrPipe[1] := -1;

  try
    if FStdinMode = stPiped then
    begin
      if platform_process_create_pipe(LStdinPipe[0], LStdinPipe[1]) <> 0 then
        raise EProcessError.Create('Failed to create stdin pipe');
      LChildStdin := LStdinPipe[0];
    end
    else if FStdinMode = stNull then
    begin
      if platform_process_open_null(False, LDevNull) <> 0 then
        raise EProcessError.Create('Failed to open null stdin');
      LChildStdin := LDevNull;
    end;

    if FStdoutMode = stPiped then
    begin
      if platform_process_create_pipe(LStdoutPipe[0], LStdoutPipe[1]) <> 0 then
        raise EProcessError.Create('Failed to create stdout pipe');
      LChildStdout := LStdoutPipe[1];
    end
    else if FStdoutMode = stNull then
    begin
      if platform_process_open_null(True, LDevNull) <> 0 then
        raise EProcessError.Create('Failed to open null stdout');
      LChildStdout := LDevNull;
    end;

    if FStderrMode = stPiped then
    begin
      if platform_process_create_pipe(LStderrPipe[0], LStderrPipe[1]) <> 0 then
        raise EProcessError.Create('Failed to create stderr pipe');
      LChildStderr := LStderrPipe[1];
    end
    else if FStderrMode = stNull then
    begin
      if platform_process_open_null(True, LDevNull) <> 0 then
        raise EProcessError.Create('Failed to open null stderr');
      LChildStderr := LDevNull;
    end;

    { Spawn }
    if LEnvp <> nil then
      LErr := platform_process_spawn_fds(PAnsiChar(LResolvedPath), @LArgv[0], @LEnvp[0],
        LCwd, LChildStdin, LChildStdout, LChildStderr, LProc, LFailStage)
    else
      LErr := platform_process_spawn_fds(PAnsiChar(LResolvedPath), @LArgv[0], nil,
        LCwd, LChildStdin, LChildStdout, LChildStderr, LProc, LFailStage);

    if LErr <> 0 then
      case LFailStage of
        pssChdir: raise EProcessError.Create('Failed to chdir: ' + FWorkDir, LErr);
        pssExec: raise EProcessError.Create('Failed to exec: ' + FPath, LErr);
      else
        raise EProcessError.Create('Failed to spawn: ' + FPath, LErr);
      end;

  except
    { Collect all open fds and close them in a single pass.
      platform_process_close_handle sets handle to -1 after closing,
      so duplicate entries are safe. }
    LCleanCount := 0;
    { Pipe pairs }
    if LStdinPipe[0] >= 0 then begin LCleanFds[LCleanCount] := LStdinPipe[0]; Inc(LCleanCount); end;
    if LStdinPipe[1] >= 0 then begin LCleanFds[LCleanCount] := LStdinPipe[1]; Inc(LCleanCount); end;
    if LStdoutPipe[0] >= 0 then begin LCleanFds[LCleanCount] := LStdoutPipe[0]; Inc(LCleanCount); end;
    if LStdoutPipe[1] >= 0 then begin LCleanFds[LCleanCount] := LStdoutPipe[1]; Inc(LCleanCount); end;
    if LStderrPipe[0] >= 0 then begin LCleanFds[LCleanCount] := LStderrPipe[0]; Inc(LCleanCount); end;
    if LStderrPipe[1] >= 0 then begin LCleanFds[LCleanCount] := LStderrPipe[1]; Inc(LCleanCount); end;
    { Null fds — only collected if not already in a pipe pair }
    if (FStdinMode = stNull) and (LChildStdin >= 0) then begin LCleanFds[LCleanCount] := LChildStdin; Inc(LCleanCount); end;
    if (FStdoutMode = stNull) and (LChildStdout >= 0) then begin LCleanFds[LCleanCount] := LChildStdout; Inc(LCleanCount); end;
    if (FStderrMode = stNull) and (LChildStderr >= 0) then begin LCleanFds[LCleanCount] := LChildStderr; Inc(LCleanCount); end;
    for LCleanIdx := 0 to LCleanCount - 1 do
      platform_process_close_handle(LCleanFds[LCleanIdx]);
    raise;
  end;

  { Close child-side fds in parent }
  if (FStdinMode = stPiped) then
    platform_process_close_handle(LStdinPipe[0]);
  if (FStdoutMode = stPiped) then
    platform_process_close_handle(LStdoutPipe[1]);
  if (FStderrMode = stPiped) then
    platform_process_close_handle(LStderrPipe[1]);
  if (FStdinMode = stNull) and (LChildStdin >= 0) then
    platform_process_close_handle(LChildStdin);
  if (FStdoutMode = stNull) and (LChildStdout >= 0) then
    platform_process_close_handle(LChildStdout);
  if (FStderrMode = stNull) and (LChildStderr >= 0) then
    platform_process_close_handle(LChildStderr);

  { Create pipe wrappers }
  if FStdinMode = stPiped then
    LStdinW := TPipeWriter.Create(LStdinPipe[1]) as IWriter;
  if FStdoutMode = stPiped then
    LStdoutR := TPipeReader.Create(LStdoutPipe[0]) as IReader;
  if FStderrMode = stPiped then
    LStderrR := TPipeReader.Create(LStderrPipe[0]) as IReader;

  Result := TChild.Create(LProc, LStdinW, LStdoutR, LStderrR, FTimeout);
end;

function TCommand.Timeout(const ADuration: TDuration): ICommand;
begin
  FTimeout := ADuration;
  Result := Self;
end;

function TCommand.Output: TProcessOutput;
var
  LChild: IChild;
  LSavedStdout, LSavedStderr: TStdio;
begin
  LSavedStdout := FStdoutMode;
  LSavedStderr := FStderrMode;
  FStdoutMode := stPiped;
  FStderrMode := stPiped;
  try
    LChild := Spawn;
    Result := LChild.WaitWithOutput;
  finally
    FStdoutMode := LSavedStdout;
    FStderrMode := LSavedStderr;
  end;
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
