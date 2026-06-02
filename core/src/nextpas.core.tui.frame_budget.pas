unit nextpas.core.tui.frame_budget;

{$I nextpas.core.settings.inc}


interface

type
  TFrameStats = record
    FrameCount: Integer;
    TotalMs: Double;
    MinMs: Double;
    MaxMs: Double;
    LastMs: Double;
    OverBudgetCount: Integer;

    class function Empty: TFrameStats; static;
    function AvgMs: Double; inline;
    function OverBudgetPct: Double;
  end;

  TFrameBudget = record
    BudgetMs: Double;
    DegradeAfterMs: Double;
    Stats: TFrameStats;
    FrameStart: QWord;
    ShouldDegrade: Boolean;

    class function Create(ABudgetMs: Double): TFrameBudget; static;
    function WithDegradeThreshold(Ms: Double): TFrameBudget;
    procedure BeginFrame;
    procedure EndFrame;
    procedure Reset;
    function ElapsedMs: Double;
    function IsOverBudget: Boolean; inline;
  end;

implementation

uses
  nextpas.core.platform.console, nextpas.core.platform.signal, nextpas.core.platform.time;

{ TFrameStats }

class function TFrameStats.Empty: TFrameStats;
begin
  Result.FrameCount := 0;
  Result.TotalMs := 0;
  Result.MinMs := 1e9;
  Result.MaxMs := 0;
  Result.LastMs := 0;
  Result.OverBudgetCount := 0;
end;

function TFrameStats.AvgMs: Double;
begin
  if FrameCount = 0 then Exit(0);
  Result := TotalMs / FrameCount;
end;

function TFrameStats.OverBudgetPct: Double;
begin
  if FrameCount = 0 then Exit(0);
  Result := (OverBudgetCount / FrameCount) * 100;
end;

{ TFrameBudget }

class function TFrameBudget.Create(ABudgetMs: Double): TFrameBudget;
begin
  Result.BudgetMs := ABudgetMs;
  Result.DegradeAfterMs := ABudgetMs * 0.8;
  Result.Stats := TFrameStats.Empty;
  Result.FrameStart := 0;
  Result.ShouldDegrade := False;
end;

function TFrameBudget.WithDegradeThreshold(Ms: Double): TFrameBudget;
begin
  Result := Self;
  Result.DegradeAfterMs := Ms;
end;

procedure TFrameBudget.BeginFrame;
begin
  FrameStart := (platform_monotonic_ns div 1000000);
  ShouldDegrade := False;
end;

procedure TFrameBudget.EndFrame;
var Ms: Double;
begin
  Ms := (platform_monotonic_ns div 1000000) - FrameStart;
  Stats.LastMs := Ms;
  Stats.TotalMs := Stats.TotalMs + Ms;
  Inc(Stats.FrameCount);
  if Ms < Stats.MinMs then Stats.MinMs := Ms;
  if Ms > Stats.MaxMs then Stats.MaxMs := Ms;
  if Ms > BudgetMs then Inc(Stats.OverBudgetCount);
  ShouldDegrade := Ms > DegradeAfterMs;
end;

procedure TFrameBudget.Reset;
begin
  Stats := TFrameStats.Empty;
  ShouldDegrade := False;
end;

function TFrameBudget.ElapsedMs: Double;
begin
  Result := (platform_monotonic_ns div 1000000) - FrameStart;
end;

function TFrameBudget.IsOverBudget: Boolean;
begin
  Result := ElapsedMs > BudgetMs;
end;

end.
