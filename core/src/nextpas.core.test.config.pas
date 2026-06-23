unit nextpas.core.test.config;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

type
  TAnsiMode = (amAuto, amOn, amOff);

  IOutputSink = interface
    ['{92B1BE7D-E6E5-49B1-8533-1D934BF43D07}']
    procedure Write(const AText: string);
    procedure WriteLn(const AText: string);
    procedure Flush;
  end;

  TStdoutSink = class(TInterfacedObject, IOutputSink)
  public
    procedure Write(const AText: string);
    procedure WriteLn(const AText: string);
    procedure Flush;
  end;

  TStderrSink = class(TInterfacedObject, IOutputSink)
  public
    procedure Write(const AText: string);
    procedure WriteLn(const AText: string);
    procedure Flush;
  end;

  TStringLines = array of string;

  TBufferSink = class(TInterfacedObject, IOutputSink)
  private
    FLines: TStringLines;
    FHasOpenLine: Boolean;
    function GetLines: TStringLines;
    procedure EnsureOpenLine;
  public
    procedure Write(const AText: string);
    procedure WriteLn(const AText: string);
    procedure Flush;
    function GetOutput: string;
    procedure Clear;
    property Lines: TStringLines read GetLines;
  end;

  TTestConfig = record
    FilterPattern: string;
    TimeoutMs: UInt64;
    AnsiMode: TAnsiMode;
    OutSink: IOutputSink;
    ErrSink: IOutputSink;
    RetryCount: Integer;
  end;

function DefaultConfig: TTestConfig;
function ResolveConfig(const AConfig: TTestConfig): TTestConfig;
procedure ResetDefaultConfig;
procedure SetDefaultFilterPattern(const APattern: string);
procedure SetDefaultTimeoutMs(ATimeoutMs: UInt64);
procedure SetDefaultAnsiMode(AAnsiMode: TAnsiMode);
procedure SetDefaultOutSink(const ASink: IOutputSink);
procedure SetDefaultErrSink(const ASink: IOutputSink);
procedure SetDefaultRetryCount(ARetryCount: Integer);

implementation

var
  GDefaultConfig: TTestConfig;

function CreateDefaultConfig: TTestConfig;
begin
  Result.FilterPattern := '';
  Result.TimeoutMs := 0;
  Result.AnsiMode := amAuto;
  Result.OutSink := TStdoutSink.Create;
  Result.ErrSink := TStderrSink.Create;
  Result.RetryCount := 0;
end;

function DefaultConfig: TTestConfig;
begin
  Result := GDefaultConfig;
end;

function ResolveConfig(const AConfig: TTestConfig): TTestConfig;
var
  LDefaults: TTestConfig;
begin
  Result := AConfig;
  LDefaults := DefaultConfig;
  if Result.FilterPattern = '' then
    Result.FilterPattern := LDefaults.FilterPattern;
  if Result.TimeoutMs = 0 then
    Result.TimeoutMs := LDefaults.TimeoutMs;
  if Result.AnsiMode = amAuto then
    Result.AnsiMode := LDefaults.AnsiMode;
  if Result.OutSink = nil then
    Result.OutSink := LDefaults.OutSink;
  if Result.ErrSink = nil then
    Result.ErrSink := LDefaults.ErrSink;
  if Result.RetryCount = 0 then
    Result.RetryCount := LDefaults.RetryCount;
end;

procedure ResetDefaultConfig;
begin
  GDefaultConfig := CreateDefaultConfig;
end;

procedure SetDefaultFilterPattern(const APattern: string);
begin
  GDefaultConfig.FilterPattern := APattern;
end;

procedure SetDefaultTimeoutMs(ATimeoutMs: UInt64);
begin
  GDefaultConfig.TimeoutMs := ATimeoutMs;
end;

procedure SetDefaultAnsiMode(AAnsiMode: TAnsiMode);
begin
  GDefaultConfig.AnsiMode := AAnsiMode;
end;

procedure SetDefaultOutSink(const ASink: IOutputSink);
begin
  if ASink = nil then
    GDefaultConfig.OutSink := TStdoutSink.Create
  else
    GDefaultConfig.OutSink := ASink;
end;

procedure SetDefaultErrSink(const ASink: IOutputSink);
begin
  if ASink = nil then
    GDefaultConfig.ErrSink := TStderrSink.Create
  else
    GDefaultConfig.ErrSink := ASink;
end;

procedure SetDefaultRetryCount(ARetryCount: Integer);
begin
  GDefaultConfig.RetryCount := ARetryCount;
end;

procedure TStdoutSink.Write(const AText: string);
begin
  System.Write(AText);
end;

procedure TStdoutSink.WriteLn(const AText: string);
begin
  System.WriteLn(AText);
end;

procedure TStdoutSink.Flush;
begin
  System.Flush(Output);
end;

procedure TStderrSink.Write(const AText: string);
begin
  System.Write(StdErr, AText);
end;

procedure TStderrSink.WriteLn(const AText: string);
begin
  System.WriteLn(StdErr, AText);
end;

procedure TStderrSink.Flush;
begin
  System.Flush(StdErr);
end;

function TBufferSink.GetLines: TStringLines;
begin
  Result := FLines;
end;

procedure TBufferSink.EnsureOpenLine;
begin
  if not FHasOpenLine then
  begin
    SetLength(FLines, Length(FLines) + 1);
    FLines[High(FLines)] := '';
    FHasOpenLine := True;
  end;
end;

procedure TBufferSink.Write(const AText: string);
begin
  EnsureOpenLine;
  FLines[High(FLines)] := FLines[High(FLines)] + AText;
end;

procedure TBufferSink.WriteLn(const AText: string);
begin
  EnsureOpenLine;
  FLines[High(FLines)] := FLines[High(FLines)] + AText;
  FHasOpenLine := False;
end;

procedure TBufferSink.Flush;
begin
end;

function TBufferSink.GetOutput: string;
var
  I: Integer;
begin
  if Length(FLines) = 0 then
    Exit('');
  Result := FLines[0];
  for I := 1 to High(FLines) do
    Result := Result + LineEnding + FLines[I];
end;

procedure TBufferSink.Clear;
begin
  FLines := nil;
  FHasOpenLine := False;
end;

initialization
  ResetDefaultConfig;

end.
