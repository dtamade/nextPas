unit nextpas.core.fpc.process;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.fpc.classes;

type
  TProcessOption = (
    poRunSuspended,
    poWaitOnExit,
    poUsePipes,
    poStderrToOutPut,
    poNoConsole,
    poNewConsole,
    poDefaultErrorMode,
    poNewProcessGroup,
    poDebugProcess,
    poDebugOnlyThisProcess
  );
  TProcessOptions = set of TProcessOption;

  TProcess = class
  private
    FExecutable: string;
    FCurrentDirectory: string;
    FParameters: TStringList;
    FOptions: TProcessOptions;
    FExitStatus: Integer;
    FRunning: Boolean;
  public
    constructor Create(AOwner: TObject);
    destructor Destroy; override;
    procedure Execute;
    property Executable: string read FExecutable write FExecutable;
    property CurrentDirectory: string read FCurrentDirectory write FCurrentDirectory;
    property Parameters: TStringList read FParameters;
    property Options: TProcessOptions read FOptions write FOptions;
    property ExitStatus: Integer read FExitStatus;
    property Running: Boolean read FRunning;
  end;

implementation

uses
  nextpas.core.platform.process,
  nextpas.core.platform.process.base,
  nextpas.core.platform.posix.ffi;

constructor TProcess.Create(AOwner: TObject);
begin
  inherited Create;
  FParameters := TStringList.Create;
  FOptions := [];
  FExitStatus := -1;
  FRunning := False;
end;

destructor TProcess.Destroy;
begin
  FParameters.Free;
  inherited Destroy;
end;

procedure TProcess.Execute;
var
  LArgv: array of PAnsiChar;
  LProc: TPlatformProcess;
  LResult: TPlatformProcessResult;
  LCwd: PAnsiChar;
  I, LArgCount: Integer;
begin
  LArgCount := FParameters.Count + 2;
  SetLength(LArgv, LArgCount);
  LArgv[0] := PAnsiChar(FExecutable);
  for I := 0 to FParameters.Count - 1 do
    LArgv[I + 1] := PAnsiChar(FParameters[I]);
  LArgv[LArgCount - 1] := nil;

  if FCurrentDirectory <> '' then
    LCwd := PAnsiChar(FCurrentDirectory)
  else
    LCwd := nil;

  if platform_process_spawn_cwd(PAnsiChar(FExecutable), @LArgv[0],
    nil, LCwd, LProc) <> 0 then
  begin
    FExitStatus := 127;
    Exit;
  end;

  FRunning := True;

  if poWaitOnExit in FOptions then
  begin
    platform_process_wait(LProc, LResult);
    FExitStatus := LResult.ExitCode;
    FRunning := False;
  end;
end;

end.
