unit nextpas.core.stopwatch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.stopwatch.tick;

type
  TLapArray = array of TDuration;

  TStopwatch = record
  private
    FTick: ITick;
    FStartTick: UInt64;
    FAccumulated: UInt64;
    FRunning: Boolean;
    FLastLapTick: UInt64;
    FLaps: array of UInt64;
    procedure EnsureTick;
    function CurrentTicks: UInt64;
    function TicksToNs(ATicks: UInt64): Int64;
  public
    class function Create: TStopwatch; static;
    class function CreateWithTick(const ATick: ITick): TStopwatch; static;
    class function StartNew: TStopwatch; static;
    class function StartNewWithTick(const ATick: ITick): TStopwatch; static;

    procedure Start;
    procedure Stop;
    procedure Reset;
    procedure Restart;

    function IsRunning: Boolean; inline;
    function Elapsed: TDuration; inline;
    function ElapsedNs: Int64; inline;
    function ElapsedUs: Int64; inline;
    function ElapsedMs: Int64; inline;
    function ElapsedSec: Double; inline;

    function Lap: TDuration;
    function GetLaps: TLapArray;
    function GetLapCount: Integer; inline;
    procedure ClearLaps;

    function ToString: string;
  end;

  TStopwatchScope = record
  private
    FSw: TStopwatch;
    FName: string;
    FActive: Boolean;
  public
    class function Create(const AName: string = ''): TStopwatchScope; static;
    procedure Finish;
    function Elapsed: TDuration; inline;
    function ElapsedMs: Int64; inline;
  end;

type
  TMeasureProc = reference to procedure;

function MeasureTime(const AProc: TMeasureProc): TDuration;
function MeasureTimeMs(const AProc: TMeasureProc): Int64;
function MeasureTimeNs(const AProc: TMeasureProc): Int64;

implementation

uses
  SysUtils;

{ TStopwatch }

procedure TStopwatch.EnsureTick;
begin
  if FTick = nil then
    FTick := MakeBestTick;
end;

function TStopwatch.CurrentTicks: UInt64;
begin
  if FRunning then
    Result := FAccumulated + (FTick.Tick - FStartTick)
  else
    Result := FAccumulated;
end;

function TStopwatch.TicksToNs(ATicks: UInt64): Int64;
var
  LRes, LQ, LR: UInt64;
begin
  LRes := FTick.GetResolution;
  if LRes = 0 then Exit(0);
  if LRes = 1000000000 then Exit(Int64(ATicks));
  LQ := ATicks div LRes;
  LR := ATicks - LQ * LRes;
  Result := Int64(LQ * 1000000000 + (LR * 1000000000) div LRes);
end;

class function TStopwatch.Create: TStopwatch;
begin
  Result.FTick := nil;
  Result.FStartTick := 0;
  Result.FAccumulated := 0;
  Result.FRunning := False;
  Result.FLastLapTick := 0;
  SetLength(Result.FLaps, 0);
end;

class function TStopwatch.CreateWithTick(const ATick: ITick): TStopwatch;
begin
  Result := TStopwatch.Create;
  Result.FTick := ATick;
end;

class function TStopwatch.StartNew: TStopwatch;
begin
  Result := TStopwatch.Create;
  Result.Start;
end;

class function TStopwatch.StartNewWithTick(const ATick: ITick): TStopwatch;
begin
  Result := TStopwatch.CreateWithTick(ATick);
  Result.Start;
end;

procedure TStopwatch.Start;
begin
  if not FRunning then
  begin
    EnsureTick;
    FStartTick := FTick.Tick;
    FLastLapTick := FStartTick;
    FRunning := True;
  end;
end;

procedure TStopwatch.Stop;
begin
  if FRunning then
  begin
    FAccumulated := FAccumulated + (FTick.Tick - FStartTick);
    FRunning := False;
  end;
end;

procedure TStopwatch.Reset;
begin
  FAccumulated := 0;
  FRunning := False;
  FLastLapTick := 0;
  SetLength(FLaps, 0);
end;

procedure TStopwatch.Restart;
begin
  Reset;
  Start;
end;

function TStopwatch.IsRunning: Boolean;
begin
  Result := FRunning;
end;

function TStopwatch.Elapsed: TDuration;
begin
  Result := TDuration.FromNanoseconds(ElapsedNs);
end;

function TStopwatch.ElapsedNs: Int64;
begin
  EnsureTick;
  Result := TicksToNs(CurrentTicks);
end;

function TStopwatch.ElapsedUs: Int64;
begin
  Result := ElapsedNs div 1000;
end;

function TStopwatch.ElapsedMs: Int64;
begin
  Result := ElapsedNs div 1000000;
end;

function TStopwatch.ElapsedSec: Double;
begin
  Result := ElapsedNs / 1000000000.0;
end;

function TStopwatch.Lap: TDuration;
var
  LNow, LDelta: UInt64;
begin
  if not FRunning then
    Exit(TDuration.Zero);
  LNow := FTick.Tick;
  LDelta := LNow - FLastLapTick;
  FLastLapTick := LNow;
  SetLength(FLaps, Length(FLaps) + 1);
  FLaps[High(FLaps)] := LDelta;
  Result := TDuration.FromNanoseconds(TicksToNs(LDelta));
end;

function TStopwatch.GetLaps: TLapArray;
var
  LI: Integer;
begin
  SetLength(Result, Length(FLaps));
  for LI := 0 to High(FLaps) do
    Result[LI] := TDuration.FromNanoseconds(TicksToNs(FLaps[LI]));
end;

function TStopwatch.GetLapCount: Integer;
begin
  Result := Length(FLaps);
end;

procedure TStopwatch.ClearLaps;
begin
  SetLength(FLaps, 0);
  if FRunning then
    FLastLapTick := FTick.Tick
  else
    FLastLapTick := 0;
end;

function TStopwatch.ToString: string;
var
  LMs: Int64;
begin
  LMs := ElapsedMs;
  if LMs < 1000 then
    Result := Format('%d ms', [LMs])
  else if LMs < 60000 then
    Result := Format('%.2f s', [LMs / 1000.0])
  else
    Result := Format('%.2f min', [LMs / 60000.0]);
end;

{ TStopwatchScope }

class function TStopwatchScope.Create(const AName: string): TStopwatchScope;
begin
  Result.FSw := TStopwatch.StartNew;
  Result.FName := AName;
  Result.FActive := True;
end;

procedure TStopwatchScope.Finish;
begin
  if FActive then
  begin
    FSw.Stop;
    if FName <> '' then
      WriteLn(Format('%s: %s', [FName, FSw.ToString]));
    FActive := False;
  end;
end;

function TStopwatchScope.Elapsed: TDuration;
begin
  Result := FSw.Elapsed;
end;

function TStopwatchScope.ElapsedMs: Int64;
begin
  Result := FSw.ElapsedMs;
end;

{ MeasureTime }

function MeasureTime(const AProc: TMeasureProc): TDuration;
var
  LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  AProc();
  LSw.Stop;
  Result := LSw.Elapsed;
end;

function MeasureTimeMs(const AProc: TMeasureProc): Int64;
var
  LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  AProc();
  LSw.Stop;
  Result := LSw.ElapsedMs;
end;

function MeasureTimeNs(const AProc: TMeasureProc): Int64;
var
  LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  AProc();
  LSw.Stop;
  Result := LSw.ElapsedNs;
end;

end.
