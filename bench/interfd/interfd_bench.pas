program interfd_bench;

{$mode objfpc}{$H+}

uses nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 100000;

type
  IShape = interface
    function Area: Double;
    function Perimeter: Double;
    function Kind: Integer;
  end;

  TCircle = class(TInterfacedObject, IShape)
  private
    FRadius: Double;
  public
    constructor Create(ARadius: Double);
    function Area: Double;
    function Perimeter: Double;
    function Kind: Integer;
  end;

  TRect = class(TInterfacedObject, IShape)
  private
    FW, FH: Double;
  public
    constructor Create(AW, AH: Double);
    function Area: Double;
    function Perimeter: Double;
    function Kind: Integer;
  end;

  TTriangle = class(TInterfacedObject, IShape)
  private
    FA, FB, FC: Double;
  public
    constructor Create(AA, AB, AC: Double);
    function Area: Double;
    function Perimeter: Double;
    function Kind: Integer;
  end;

constructor TCircle.Create(ARadius: Double);
begin
  inherited Create;
  FRadius := ARadius;
end;

function TCircle.Area: Double;
begin
  Result := 3.14159265 * FRadius * FRadius;
end;

function TCircle.Perimeter: Double;
begin
  Result := 2.0 * 3.14159265 * FRadius;
end;

function TCircle.Kind: Integer;
begin
  Result := 0;
end;

constructor TRect.Create(AW, AH: Double);
begin
  inherited Create;
  FW := AW;
  FH := AH;
end;

function TRect.Area: Double;
begin
  Result := FW * FH;
end;

function TRect.Perimeter: Double;
begin
  Result := 2.0 * (FW + FH);
end;

function TRect.Kind: Integer;
begin
  Result := 1;
end;

constructor TTriangle.Create(AA, AB, AC: Double);
begin
  inherited Create;
  FA := AA;
  FB := AB;
  FC := AC;
end;

function TTriangle.Area: Double;
var
  LS: Double;
begin
  LS := (FA + FB + FC) * 0.5;
  Result := Sqrt(LS * (LS - FA) * (LS - FB) * (LS - FC));
end;

function TTriangle.Perimeter: Double;
begin
  Result := FA + FB + FC;
end;

function TTriangle.Kind: Integer;
begin
  Result := 2;
end;

var
  GShapes: array[0..N-1] of IShape;
  GSink: Double;

procedure InitData;
var
  I: Integer;
begin
  for I := 0 to N-1 do
    case I mod 3 of
      0: GShapes[I] := TCircle.Create(1.0 + I * 0.001);
      1: GShapes[I] := TRect.Create(1.0 + I * 0.001, 2.0 + I * 0.001);
      2: GShapes[I] := TTriangle.Create(3.0, 4.0, 5.0);
    end;
end;

{ --- Interface dispatch: virtual call through interface --- }

procedure BenchInterfaced_Area(const ACtx: IBenchContext);
var
  I: Integer;
  LSum: Double;
begin
  LSum := 0;
  for I := 0 to N-1 do
    LSum := LSum + GShapes[I].Area;
  GSink := LSum;
  ACtx.SetBytes(N * 16);
end;

procedure BenchInterfaced_Perimeter(const ACtx: IBenchContext);
var
  I: Integer;
  LSum: Double;
begin
  LSum := 0;
  for I := 0 to N-1 do
    LSum := LSum + GShapes[I].Perimeter;
  GSink := LSum;
  ACtx.SetBytes(N * 16);
end;

procedure BenchInterfaced_Kind(const ACtx: IBenchContext);
var
  I, LSum: Integer;
begin
  LSum := 0;
  for I := 0 to N-1 do
    LSum := LSum + GShapes[I].Kind;
  GSink := LSum;
  ACtx.SetBytes(N * 8);
end;

{ --- Direct class call (baseline, no dispatch) --- }

procedure BenchDirect_Area(const ACtx: IBenchContext);
var
  I: Integer;
  LSum: Double;
  LC: TCircle;
begin
  LC := TCircle.Create(1.5);
  LSum := 0;
  for I := 0 to N-1 do
    LSum := LSum + LC.Area;
  GSink := LSum;
  FreeAndNil(LC);
  ACtx.SetBytes(N * 16);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('interfd');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('Interfaced/Area/100K', @BenchInterfaced_Area);
  LSuite.Add('Interfaced/Perimeter/100K', @BenchInterfaced_Perimeter);
  LSuite.Add('Interfaced/Kind/100K', @BenchInterfaced_Kind);
  LSuite.Add('Direct/Area/100K', @BenchDirect_Area);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
