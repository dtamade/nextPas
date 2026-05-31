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
  nextpas.core.platform.process.base
  {$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.ffi
  {$ENDIF};

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
  LPipes: TPlatformProcessPipes;
  LCwd: PAnsiChar;
  LNeedPipes: Boolean;
  LStdinW: IWriter;
  LStdoutR: IReader;
  LStderrR: IReader;
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

  LNeedPipes := (FStdinMode = stPiped) or (FStdoutMode = stPiped) or (FStderrMode = stPiped);

  if LNeedPipes then
  begin
    if LEnvp <> nil then
      LErr := platform_process_spawn_piped_cwd(PAnsiChar(FPath), @LArgv[0], @LEnvp[0], LCwd, LProc, LPipes)
    else
      LErr := platform_process_spawn_piped_cwd(PAnsiChar(FPath), @LArgv[0], nil, LCwd, LProc, LPipes);

    if LErr <> 0 then
      raise EProcessError.Create('Failed to spawn: ' + FPath, LErr);

    if FStdinMode = stPiped then
      LStdinW := TPipeWriter.Create(LPipes.StdinWrite) as IWriter
    else
    begin
      {$IFDEF NEXTPAS_UNIX}
      nextpas.core.platform.posix.ffi.close(LPipes.StdinWrite);
      {$ENDIF}
    end;

    if FStdoutMode = stPiped then
      LStdoutR := TPipeReader.Create(LPipes.StdoutRead) as IReader
    else
    begin
      {$IFDEF NEXTPAS_UNIX}
      nextpas.core.platform.posix.ffi.close(LPipes.StdoutRead);
      {$ENDIF}
    end;

    if FStderrMode = stPiped then
      LStderrR := TPipeReader.Create(LPipes.StderrRead) as IReader
    else
    begin
      {$IFDEF NEXTPAS_UNIX}
      nextpas.core.platform.posix.ffi.close(LPipes.StderrRead);
      {$ENDIF}
    end;
  end
  else
  begin
    if LEnvp <> nil then
      LErr := platform_process_spawn_cwd(PAnsiChar(FPath), @LArgv[0], @LEnvp[0], LCwd, LProc)
    else
      LErr := platform_process_spawn_cwd(PAnsiChar(FPath), @LArgv[0], nil, LCwd, LProc);

    if LErr <> 0 then
      raise EProcessError.Create('Failed to spawn: ' + FPath, LErr);
  end;

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
