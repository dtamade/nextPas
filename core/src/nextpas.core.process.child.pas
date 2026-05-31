unit nextpas.core.process.child;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.process.base,
  nextpas.core.platform.process.base;

type
  { IChild — 正在运行的子进程 }
  IChild = interface
    ['{A1B2C3D4-E5F6-7890-AB01-000000000001}']
    function Wait: TProcessOutput;
    function TryWait(out AOutput: TProcessOutput): Boolean;
    procedure Kill;
    function Pid: Integer;
    function TakeStdin: IWriter;
    function TakeStdout: IReader;
    function TakeStderr: IReader;
    function WaitWithOutput: TProcessOutput;
  end;

  { TChild — IChild 实现 }
  TChild = class(TInterfacedObject, IChild)
  private
    FProc: TPlatformProcess;
    FStdinWriter: IWriter;
    FStdoutReader: IReader;
    FStderrReader: IReader;
    FWaited: Boolean;
  public
    constructor Create(const AProc: TPlatformProcess;
      const AStdin: IWriter; const AStdout: IReader; const AStderr: IReader);
    destructor Destroy; override;
    function Wait: TProcessOutput;
    function TryWait(out AOutput: TProcessOutput): Boolean;
    procedure Kill;
    function Pid: Integer;
    function TakeStdin: IWriter;
    function TakeStdout: IReader;
    function TakeStderr: IReader;
    function WaitWithOutput: TProcessOutput;
  end;

implementation

uses
  nextpas.core.platform.process;

const
  READ_BUF_SIZE = 65536;

function ReadAll(const AReader: IReader): string;
var
  LBuf: array[0..READ_BUF_SIZE - 1] of Byte;
  LRead: SizeUInt;
  LTotal: Integer;
begin
  Result := '';
  if AReader = nil then Exit;
  LTotal := 0;
  repeat
    LRead := AReader.Read(LBuf[0], READ_BUF_SIZE);
    if LRead > 0 then
    begin
      SetLength(Result, LTotal + Integer(LRead));
      Move(LBuf[0], Result[LTotal + 1], LRead);
      Inc(LTotal, Integer(LRead));
    end;
  until LRead = 0;
end;

{ TChild }

constructor TChild.Create(const AProc: TPlatformProcess;
  const AStdin: IWriter; const AStdout: IReader; const AStderr: IReader);
begin
  inherited Create;
  FProc := AProc;
  FStdinWriter := AStdin;
  FStdoutReader := AStdout;
  FStderrReader := AStderr;
  FWaited := False;
end;

destructor TChild.Destroy;
begin
  if not FWaited then
    Kill;
  FStdinWriter := nil;
  FStdoutReader := nil;
  FStderrReader := nil;
  inherited;
end;

function TChild.Wait: TProcessOutput;
var
  LResult: TPlatformProcessResult;
begin
  FillChar(Result, SizeOf(Result), 0);
  FStdinWriter := nil;
  platform_process_wait(FProc, LResult);
  FWaited := True;
  Result.ExitCode := LResult.ExitCode;
  case LResult.Status of
    psExited: Result.Status := nextpas.core.process.base.psExited;
    psSignaled: Result.Status := nextpas.core.process.base.psSignaled;
    psRunning: Result.Status := nextpas.core.process.base.psRunning;
  else
    Result.Status := nextpas.core.process.base.psUnknown;
  end;
end;

function TChild.TryWait(out AOutput: TProcessOutput): Boolean;
var
  LResult: TPlatformProcessResult;
begin
  FillChar(AOutput, SizeOf(AOutput), 0);
  platform_process_try_wait(FProc, LResult);
  if LResult.Status = nextpas.core.platform.process.base.psRunning then
    Exit(False);
  FWaited := True;
  AOutput.ExitCode := LResult.ExitCode;
  case LResult.Status of
    psExited: AOutput.Status := nextpas.core.process.base.psExited;
    psSignaled: AOutput.Status := nextpas.core.process.base.psSignaled;
  else
    AOutput.Status := nextpas.core.process.base.psUnknown;
  end;
  Result := True;
end;

procedure TChild.Kill;
begin
  if FWaited then Exit;
  platform_process_kill(FProc);
end;

function TChild.Pid: Integer;
begin
  Result := platform_process_pid(FProc);
end;

function TChild.TakeStdin: IWriter;
begin
  Result := FStdinWriter;
  FStdinWriter := nil;
end;

function TChild.TakeStdout: IReader;
begin
  Result := FStdoutReader;
  FStdoutReader := nil;
end;

function TChild.TakeStderr: IReader;
begin
  Result := FStderrReader;
  FStderrReader := nil;
end;

function TChild.WaitWithOutput: TProcessOutput;
var
  LWait: TProcessOutput;
begin
  FStdinWriter := nil;
  Result.StdOut := ReadAll(FStdoutReader);
  Result.StdErr := ReadAll(FStderrReader);
  FStdoutReader := nil;
  FStderrReader := nil;
  LWait := Wait;
  Result.ExitCode := LWait.ExitCode;
  Result.Status := LWait.Status;
end;

end.
