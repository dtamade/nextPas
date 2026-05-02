unit Process;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TComponent = class
  end;

  TProcessOption = (poWaitOnExit, poUsePipes, poStderrToOutPut);
  TProcessOptions = set of TProcessOption;

  TProcess = class
  private
    FExecutable: string;
    FCurrentDirectory: string;
    FParameters: TStringList;
    FOptions: TProcessOptions;
    FExitStatus: Integer;
  public
    constructor Create(AOwner: TComponent);
    destructor Destroy; override;

    procedure Execute;

    property Executable: string read FExecutable write FExecutable;
    property CurrentDirectory: string read FCurrentDirectory write FCurrentDirectory;
    property Parameters: TStringList read FParameters;
    property Options: TProcessOptions read FOptions write FOptions;
    property ExitStatus: Integer read FExitStatus;
  end;

implementation

{ TProcess }

constructor TProcess.Create(AOwner: TComponent);
begin
  inherited Create;
  FParameters := TStringList.Create;
  FExitStatus := 0;
  FExecutable := '';
  FCurrentDirectory := '';
  FOptions := [];
end;

destructor TProcess.Destroy;
begin
  FParameters.Free;
  inherited Destroy;
end;

procedure TProcess.Execute;
var
  CommandLine: string;
  I: Integer;
  SaveDir: string;
  ExitCode: Integer;
begin
  // Build command line
  CommandLine := FExecutable;
  for I := 0 to FParameters.Count - 1 do
    CommandLine := CommandLine + ' ' + FParameters[I];

  // Save current directory if needed
  if FCurrentDirectory <> '' then
  begin
    GetDir(0, SaveDir);
    {$I-}
    ChDir(FCurrentDirectory);
    {$I+}
    if IOResult <> 0 then
      raise Exception.Create('Cannot change to directory: ' + FCurrentDirectory);
  end;

  try
    // Execute command
    {$I-}
    ExitCode := 0;
    // TODO: Implement actual process execution
    // For now, this is a stub that always succeeds
    FExitStatus := ExitCode;
    {$I+}
  finally
    // Restore directory
    if FCurrentDirectory <> '' then
    begin
      {$I-}
      ChDir(SaveDir);
      {$I+}
      IOResult; // Clear error
    end;
  end;
end;

end.
