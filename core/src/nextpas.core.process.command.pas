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
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.posix.base,
  nextpas.core.process.pathresolve;

{ TCommand }

procedure EnvPut(var AItems: TStringArray; const AKey, AValue: string);
var
  I, P: Integer;
begin
  for I := 0 to High(AItems) do
  begin
    P := Pos('=', AItems[I]);
    if (P > 0) and (Copy(AItems[I], 1, P - 1) = AKey) then
    begin
      AItems[I] := AKey + '=' + AValue;
      Exit;
    end;
  end;
  SetLength(AItems, Length(AItems) + 1);
  AItems[High(AItems)] := AKey + '=' + AValue;
end;

function BuildFinalEnv(const AMode: TProcessEnvMode;
  const AExplicit: TStringArray): TStringArray;
var
  I, P, LCount: Integer;
  LCur: PPAnsiChar;
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
      { Snapshot parent environment }
      LCur := environ;
      LCount := 0;
      if LCur <> nil then
        while LCur[LCount] <> nil do
          Inc(LCount);
      SetLength(Result, LCount);
      for I := 0 to LCount - 1 do
        Result[I] := string(LCur[I]);
      { Apply overlays }
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
  FEnvMode := pemReplace;
  SetLength(FEnvPairs, Length(AEnvPairs));
  for I := 0 to High(AEnvPairs) do
    FEnvPairs[I] := AEnvPairs[I];
  Result := Self;
end;

function TCommand.EnvAdd(const AKey, AValue: string): ICommand;
begin
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
  LStdinPipe, LStdoutPipe, LStderrPipe: array[0..1] of Int32;
  LChildStdin, LChildStdout, LChildStderr: PtrInt;
  LDevNull: Int32;
  LFinalEnv: TStringArray;
  LFailStage: TPlatformProcessSpawnStage;
  LResolvedPath: string;
begin
  { Resolve path: search PATH if using custom env and name has no '/' }
  if (FEnvMode <> pemInherit) and (Pos('/', FPath) = 0) then
  begin
    LFinalEnv := BuildFinalEnv(FEnvMode, FEnvPairs);
    LResolvedPath := ResolveExecutablePath(FPath, LFinalEnv);
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
      if pipe(@LStdinPipe[0]) <> 0 then
        raise EProcessError.Create('Failed to create stdin pipe');
      LChildStdin := LStdinPipe[0];
    end
    else if FStdinMode = stNull then
    begin
      LDevNull := nextpas.core.platform.posix.ffi.open(PAnsiChar('/dev/null'), 0, 0);
      if LDevNull < 0 then
        raise EProcessError.Create('Failed to open /dev/null for stdin');
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
      LDevNull := nextpas.core.platform.posix.ffi.open(PAnsiChar('/dev/null'), 1, 0);
      if LDevNull < 0 then
        raise EProcessError.Create('Failed to open /dev/null for stdout');
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
      LDevNull := nextpas.core.platform.posix.ffi.open(PAnsiChar('/dev/null'), 1, 0);
      if LDevNull < 0 then
        raise EProcessError.Create('Failed to open /dev/null for stderr');
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
    { Clean up all created fds on failure }
    if LStdinPipe[0] >= 0 then nextpas.core.platform.posix.ffi.close(LStdinPipe[0]);
    if LStdinPipe[1] >= 0 then nextpas.core.platform.posix.ffi.close(LStdinPipe[1]);
    if LStdoutPipe[0] >= 0 then nextpas.core.platform.posix.ffi.close(LStdoutPipe[0]);
    if LStdoutPipe[1] >= 0 then nextpas.core.platform.posix.ffi.close(LStdoutPipe[1]);
    if LStderrPipe[0] >= 0 then nextpas.core.platform.posix.ffi.close(LStderrPipe[0]);
    if LStderrPipe[1] >= 0 then nextpas.core.platform.posix.ffi.close(LStderrPipe[1]);
    raise;
  end;

  { Close child-side fds in parent }
  if (FStdinMode = stPiped) then
    nextpas.core.platform.posix.ffi.close(LStdinPipe[0]);
  if (FStdoutMode = stPiped) then
    nextpas.core.platform.posix.ffi.close(LStdoutPipe[1]);
  if (FStderrMode = stPiped) then
    nextpas.core.platform.posix.ffi.close(LStderrPipe[1]);
  if (FStdinMode = stNull) and (LChildStdin >= 0) then
    nextpas.core.platform.posix.ffi.close(LChildStdin);
  if (FStdoutMode = stNull) and (LChildStdout >= 0) then
    nextpas.core.platform.posix.ffi.close(LChildStdout);
  if (FStderrMode = stNull) and (LChildStderr >= 0) then
    nextpas.core.platform.posix.ffi.close(LChildStderr);

  { Create pipe wrappers }
  if FStdinMode = stPiped then
    LStdinW := TPipeWriter.Create(LStdinPipe[1]) as IWriter;
  if FStdoutMode = stPiped then
    LStdoutR := TPipeReader.Create(LStdoutPipe[0]) as IReader;
  if FStderrMode = stPiped then
    LStderrR := TPipeReader.Create(LStderrPipe[0]) as IReader;

  Result := TChild.Create(LProc, LStdinW, LStdoutR, LStderrR, FTimeout);
end;

function ReadAllFromReader(const AReader: IReader): string;
var
  LBuf: array[0..65535] of Byte;
  LRead: SizeUInt;
  LTotal: Integer;
begin
  Result := '';
  if AReader = nil then Exit;
  LTotal := 0;
  repeat
    LRead := AReader.Read(LBuf[0], 65536);
    if LRead > 0 then
    begin
      SetLength(Result, LTotal + Integer(LRead));
      Move(LBuf[0], Result[LTotal + 1], LRead);
      Inc(LTotal, Integer(LRead));
    end;
  until LRead = 0;
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
  LWait: TProcessOutput;
begin
  LSavedStdout := FStdoutMode;
  LSavedStderr := FStderrMode;
  FStdoutMode := stPiped;
  FStderrMode := stPiped;
  try
    LChild := Spawn;
    if FTimeout.IsZero then
      Result := LChild.WaitWithOutput
    else
    begin
      { With timeout: Wait first (may kill), then drain pipes }
      LWait := LChild.Wait;
      Result.StdOut := ReadAllFromReader(LChild.TakeStdout);
      Result.StdErr := ReadAllFromReader(LChild.TakeStderr);
      Result.ExitCode := LWait.ExitCode;
      Result.Status := LWait.Status;
    end;
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
