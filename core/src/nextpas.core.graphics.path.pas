{**
 * nextpas.core.graphics.path - TPath 不可变链（值类型 COW，array of TVec2/Byte，零 TBytes/bytes）
 * 指数扩容 + AlignUp 复用 mem.base，TGradient 私有化不可变。
 * TPath 链式 MoveTo/LineTo 为不可变值类型：每次 COW 全量拷贝共享数组；
 * 未 Reserve 时 N 次链式总拷贝 O(N²)；大路径请用 TPathBuilder+Reserve，
 * Reserve 已分 Verbs/Points 双容量正确处理。
 *}
unit nextpas.core.graphics.path;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.mem.base;

type
  TPathVerb = (pvMove, pvLine, pvQuad, pvCubic, pvClose);

  TColor32Array = array of TColor32;
  TSingleArray = array of Single;

  { TPath 不可变链：每次 MoveTo/LineTo 通过 COW 全量拷贝；未 Reserve 时 N 次链式 O(N²)，
    大路径请用 TPathBuilder+Reserve；Reserve 分 Verbs/Points 双容量正确分配 }
  TPath = record
  private
    FVerbs: array of TPathVerb;
    FPoints: array of TVec2;
    FVerbCount: Integer;
    FPointCount: Integer;
    procedure EnsureVerbCap(ANeeded: Integer); inline;
    procedure EnsurePointCap(ANeeded: Integer); inline;
    procedure EnsureVerbUnique; inline;
    procedure EnsurePointUnique; inline;
    function GetCount: Integer; inline;
  public
    class function New: TPath; static;
    function Reserve(ACapVerbs, ACapPoints: Integer): TPath;
    function MoveTo(X, Y: Single): TPath;
    function LineTo(X, Y: Single): TPath;
    function QuadTo(CX, CY, X, Y: Single): TPath;
    function CubicTo(C1X, C1Y, C2X, C2Y, X, Y: Single): TPath;
    function Close: TPath;
    function IsEmpty: Boolean; inline;
    function VerbCount: Integer; inline;
    function PointCount: Integer; inline;
    function GetVerb(AIndex: Integer): TPathVerb; inline;
    function GetPoint(AIndex: Integer): TVec2; inline;
  end;

  TPathBuilder = record
  private
    FVerbs: array of TPathVerb;
    FPoints: array of TVec2;
    FVerbCount: Integer;
    FPointCount: Integer;
    procedure EnsureVerbCap(ANeeded: Integer); inline;
    procedure EnsurePointCap(ANeeded: Integer); inline;
  public
    class function Create: TPathBuilder; static; inline;
    procedure Reserve(ACapVerbs, ACapPoints: Integer); inline;
    procedure MoveTo(X, Y: Single); inline;
    procedure LineTo(X, Y: Single); inline;
    procedure QuadTo(CX, CY, X, Y: Single); inline;
    procedure CubicTo(C1X, C1Y, C2X, C2Y, X, Y: Single); inline;
    procedure Close; inline;
    procedure AppendMove(X, Y: Single); inline;
    procedure AppendLine(X, Y: Single); inline;
    procedure AppendClose; inline;
    function Build: TPath; inline;
    function IsEmpty: Boolean; inline;
    function VerbCount: Integer; inline;
    function PointCount: Integer; inline;
  end;

  TLineCap = (lcButt, lcRound, lcSquare);
  TLineJoin = (ljMiter, ljRound, ljBevel);
  TGradientKind = (gkLinear, gkRadial);

  TStrokeOptions = record
  private
    FWidth: Single;
    FCap: TLineCap;
    FJoin: TLineJoin;
    FMiterLimit: Single;
    function GetWidth: Single; inline;
    function GetCap: TLineCap; inline;
    function GetJoin: TLineJoin; inline;
    function GetMiterLimit: Single; inline;
  public
    class function Create(AWidth: Single; ACap: TLineCap = lcButt; AJoin: TLineJoin = ljMiter; AMiter: Single = 4): TStrokeOptions; static;
    property Width: Single read GetWidth;
    property Cap: TLineCap read GetCap;
    property Join: TLineJoin read GetJoin;
    property MiterLimit: Single read GetMiterLimit;
    function WithWidth(AWidth: Single): TStrokeOptions;
    function WithCap(ACap: TLineCap): TStrokeOptions; inline;
    function WithJoin(AJoin: TLineJoin): TStrokeOptions; inline;
    function WithMiterLimit(AMiter: Single): TStrokeOptions;
  end;

  TGradient = record
  private
    FKind: TGradientKind;
    FColors: TColor32Array;
    FStops: TSingleArray;
    FTransform: TMat2D;
    function GetColors: TColor32Array; inline;
    function GetStops: TSingleArray; inline;
  public
    class function Create(AKind: TGradientKind; const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient; overload; static;
    class function Create(AKind: TGradientKind; const AColors: TColor32Array; const AStops: TSingleArray): TGradient; overload; static; inline;
    class function Linear(const AColors: TColor32Array; const AStops: TSingleArray): TGradient; overload; static; inline;
    class function Linear(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient; overload; static; inline;
    class function Radial(const AColors: TColor32Array; const AStops: TSingleArray): TGradient; overload; static; inline;
    class function Radial(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient; overload; static; inline;
    property Kind: TGradientKind read FKind;
    property Colors: TColor32Array read GetColors;
    property Stops: TSingleArray read GetStops;
    property Transform: TMat2D read FTransform;
    function ColorCount: Integer; inline;
    function StopCount: Integer; inline;
    function GetColor(AIndex: Integer): TColor32; inline;
    function GetStop(AIndex: Integer): Single; inline;
    function Clone: TGradient; inline;
    function WithTransform(const M: TMat2D): TGradient; inline;
    function WithOpacity(A: Single): TGradient;
  end;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.math;

{ TPath helpers }

procedure TPath.EnsureVerbCap(ANeeded: Integer);
var
  LCap, LNewCap: SizeUInt;
begin
  LCap := SizeUInt(Length(FVerbs));
  if LCap >= SizeUInt(ANeeded) then Exit;
  if LCap = 0 then
    LNewCap := 8
  else
  begin
    LNewCap := LCap * 2;
    if LNewCap < SizeUInt(ANeeded) then
      LNewCap := SizeUInt(ANeeded);
  end;
  LNewCap := AlignUp(LNewCap, 8);
  if LNewCap = 0 then
    LNewCap := SizeUInt(ANeeded);
  SetLength(FVerbs, Integer(LNewCap));
end;

procedure TPath.EnsurePointCap(ANeeded: Integer);
var
  LCap, LNewCap: SizeUInt;
begin
  LCap := SizeUInt(Length(FPoints));
  if LCap >= SizeUInt(ANeeded) then Exit;
  if LCap = 0 then
    LNewCap := 8
  else
  begin
    LNewCap := LCap * 2;
    if LNewCap < SizeUInt(ANeeded) then
      LNewCap := SizeUInt(ANeeded);
  end;
  LNewCap := AlignUp(LNewCap, 8);
  if LNewCap = 0 then
    LNewCap := SizeUInt(ANeeded);
  SetLength(FPoints, Integer(LNewCap));
end;

procedure TPath.EnsureVerbUnique;
begin
  if Length(FVerbs) > 0 then
    SetLength(FVerbs, Length(FVerbs));
end;

procedure TPath.EnsurePointUnique;
begin
  if Length(FPoints) > 0 then
    SetLength(FPoints, Length(FPoints));
end;

class function TPath.New: TPath;
begin
  Result.FVerbs := nil;
  Result.FPoints := nil;
  Result.FVerbCount := 0;
  Result.FPointCount := 0;
end;

function TPath.GetCount: Integer;
begin
  Result := FVerbCount;
end;

function TPath.Reserve(ACapVerbs, ACapPoints: Integer): TPath;
begin
  if ACapVerbs < 0 then ACapVerbs := 0;
  if ACapPoints < 0 then ACapPoints := 0;
  Result := Self;
  if ACapVerbs > Length(Result.FVerbs) then
    Result.EnsureVerbCap(ACapVerbs)
  else if Length(Result.FVerbs) > 0 then
    Result.EnsureVerbUnique;
  if ACapPoints > Length(Result.FPoints) then
    Result.EnsurePointCap(ACapPoints)
  else if Length(Result.FPoints) > 0 then
    Result.EnsurePointUnique;
end;

function TPath.MoveTo(X, Y: Single): TPath;
begin
  if IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TPath.MoveTo: X/Y must be finite');
  Result := Self;
  if SizeUInt(Length(Result.FVerbs)) < SizeUInt(Result.FVerbCount + 1) then
    Result.EnsureVerbCap(Result.FVerbCount + 1)
  else
    Result.EnsureVerbUnique;
  if SizeUInt(Length(Result.FPoints)) < SizeUInt(Result.FPointCount + 1) then
    Result.EnsurePointCap(Result.FPointCount + 1)
  else
    Result.EnsurePointUnique;
  Result.FVerbs[Result.FVerbCount] := pvMove;
  Inc(Result.FVerbCount);
  Result.FPoints[Result.FPointCount] := TVec2.Create(X, Y);
  Inc(Result.FPointCount);
end;

function TPath.LineTo(X, Y: Single): TPath;
begin
  if IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TPath.LineTo: X/Y must be finite');
  Result := Self;
  if SizeUInt(Length(Result.FVerbs)) < SizeUInt(Result.FVerbCount + 1) then
    Result.EnsureVerbCap(Result.FVerbCount + 1)
  else
    Result.EnsureVerbUnique;
  if SizeUInt(Length(Result.FPoints)) < SizeUInt(Result.FPointCount + 1) then
    Result.EnsurePointCap(Result.FPointCount + 1)
  else
    Result.EnsurePointUnique;
  Result.FVerbs[Result.FVerbCount] := pvLine;
  Inc(Result.FVerbCount);
  Result.FPoints[Result.FPointCount] := TVec2.Create(X, Y);
  Inc(Result.FPointCount);
end;

function TPath.QuadTo(CX, CY, X, Y: Single): TPath;
begin
  if IsNaN(CX) or IsInfinite(CX) or IsNaN(CY) or IsInfinite(CY) or
     IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TPath.QuadTo: CX/CY/X/Y must be finite');
  Result := Self;
  if SizeUInt(Length(Result.FVerbs)) < SizeUInt(Result.FVerbCount + 1) then
    Result.EnsureVerbCap(Result.FVerbCount + 1)
  else
    Result.EnsureVerbUnique;
  if SizeUInt(Length(Result.FPoints)) < SizeUInt(Result.FPointCount + 2) then
    Result.EnsurePointCap(Result.FPointCount + 2)
  else
    Result.EnsurePointUnique;
  Result.FVerbs[Result.FVerbCount] := pvQuad;
  Inc(Result.FVerbCount);
  Result.FPoints[Result.FPointCount] := TVec2.Create(CX, CY);
  Result.FPoints[Result.FPointCount + 1] := TVec2.Create(X, Y);
  Inc(Result.FPointCount, 2);
end;

function TPath.CubicTo(C1X, C1Y, C2X, C2Y, X, Y: Single): TPath;
begin
  if IsNaN(C1X) or IsInfinite(C1X) or IsNaN(C1Y) or IsInfinite(C1Y) or
     IsNaN(C2X) or IsInfinite(C2X) or IsNaN(C2Y) or IsInfinite(C2Y) or
     IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TPath.CubicTo: C1X/C1Y/C2X/C2Y/X/Y must be finite');
  Result := Self;
  if SizeUInt(Length(Result.FVerbs)) < SizeUInt(Result.FVerbCount + 1) then
    Result.EnsureVerbCap(Result.FVerbCount + 1)
  else
    Result.EnsureVerbUnique;
  if SizeUInt(Length(Result.FPoints)) < SizeUInt(Result.FPointCount + 3) then
    Result.EnsurePointCap(Result.FPointCount + 3)
  else
    Result.EnsurePointUnique;
  Result.FVerbs[Result.FVerbCount] := pvCubic;
  Inc(Result.FVerbCount);
  Result.FPoints[Result.FPointCount] := TVec2.Create(C1X, C1Y);
  Result.FPoints[Result.FPointCount + 1] := TVec2.Create(C2X, C2Y);
  Result.FPoints[Result.FPointCount + 2] := TVec2.Create(X, Y);
  Inc(Result.FPointCount, 3);
end;

function TPath.Close: TPath;
begin
  if (FVerbCount > 0) and (FVerbs[FVerbCount - 1] = pvClose) then
    Exit(Self);
  Result := Self;
  if SizeUInt(Length(Result.FVerbs)) < SizeUInt(Result.FVerbCount + 1) then
    Result.EnsureVerbCap(Result.FVerbCount + 1)
  else
    Result.EnsureVerbUnique;
  Result.FVerbs[Result.FVerbCount] := pvClose;
  Inc(Result.FVerbCount);
end;

procedure TPathBuilder.EnsureVerbCap(ANeeded: Integer);
var
  LCap, LNewCap: SizeUInt;
begin
  LCap := SizeUInt(Length(FVerbs));
  if LCap >= SizeUInt(ANeeded) then Exit;
  if LCap = 0 then
    LNewCap := 8
  else
  begin
    LNewCap := LCap * 2;
    if LNewCap < SizeUInt(ANeeded) then
      LNewCap := SizeUInt(ANeeded);
  end;
  LNewCap := AlignUp(LNewCap, 8);
  if LNewCap = 0 then
    LNewCap := SizeUInt(ANeeded);
  SetLength(FVerbs, Integer(LNewCap));
end;

procedure TPathBuilder.EnsurePointCap(ANeeded: Integer);
var
  LCap, LNewCap: SizeUInt;
begin
  LCap := SizeUInt(Length(FPoints));
  if LCap >= SizeUInt(ANeeded) then Exit;
  if LCap = 0 then
    LNewCap := 8
  else
  begin
    LNewCap := LCap * 2;
    if LNewCap < SizeUInt(ANeeded) then
      LNewCap := SizeUInt(ANeeded);
  end;
  LNewCap := AlignUp(LNewCap, 8);
  if LNewCap = 0 then
    LNewCap := SizeUInt(ANeeded);
  SetLength(FPoints, Integer(LNewCap));
end;

class function TPathBuilder.Create: TPathBuilder;
begin
  Result.FVerbs := nil;
  Result.FPoints := nil;
  Result.FVerbCount := 0;
  Result.FPointCount := 0;
end;

procedure TPathBuilder.Reserve(ACapVerbs, ACapPoints: Integer);
begin
  if ACapVerbs > 0 then EnsureVerbCap(ACapVerbs);
  if ACapPoints > 0 then EnsurePointCap(ACapPoints);
end;

procedure TPathBuilder.MoveTo(X, Y: Single);
begin
  if IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TPathBuilder.MoveTo: X/Y must be finite');
  EnsureVerbCap(FVerbCount + 1);
  EnsurePointCap(FPointCount + 1);
  FVerbs[FVerbCount] := pvMove;
  Inc(FVerbCount);
  FPoints[FPointCount] := TVec2.Create(X, Y);
  Inc(FPointCount);
end;

procedure TPathBuilder.LineTo(X, Y: Single);
begin
  if IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TPathBuilder.LineTo: X/Y must be finite');
  EnsureVerbCap(FVerbCount + 1);
  EnsurePointCap(FPointCount + 1);
  FVerbs[FVerbCount] := pvLine;
  Inc(FVerbCount);
  FPoints[FPointCount] := TVec2.Create(X, Y);
  Inc(FPointCount);
end;

procedure TPathBuilder.QuadTo(CX, CY, X, Y: Single);
begin
  if IsNaN(CX) or IsInfinite(CX) or IsNaN(CY) or IsInfinite(CY) or
     IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TPathBuilder.QuadTo: CX/CY/X/Y must be finite');
  EnsureVerbCap(FVerbCount + 1);
  EnsurePointCap(FPointCount + 2);
  FVerbs[FVerbCount] := pvQuad;
  Inc(FVerbCount);
  FPoints[FPointCount] := TVec2.Create(CX, CY);
  FPoints[FPointCount + 1] := TVec2.Create(X, Y);
  Inc(FPointCount, 2);
end;

procedure TPathBuilder.CubicTo(C1X, C1Y, C2X, C2Y, X, Y: Single);
begin
  if IsNaN(C1X) or IsInfinite(C1X) or IsNaN(C1Y) or IsInfinite(C1Y) or
     IsNaN(C2X) or IsInfinite(C2X) or IsNaN(C2Y) or IsInfinite(C2Y) or
     IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TPathBuilder.CubicTo: C1X/C1Y/C2X/C2Y/X/Y must be finite');
  EnsureVerbCap(FVerbCount + 1);
  EnsurePointCap(FPointCount + 3);
  FVerbs[FVerbCount] := pvCubic;
  Inc(FVerbCount);
  FPoints[FPointCount] := TVec2.Create(C1X, C1Y);
  FPoints[FPointCount + 1] := TVec2.Create(C2X, C2Y);
  FPoints[FPointCount + 2] := TVec2.Create(X, Y);
  Inc(FPointCount, 3);
end;

procedure TPathBuilder.Close;
begin
  if (FVerbCount > 0) and (FVerbs[FVerbCount - 1] = pvClose) then Exit;
  EnsureVerbCap(FVerbCount + 1);
  FVerbs[FVerbCount] := pvClose;
  Inc(FVerbCount);
end;

procedure TPathBuilder.AppendMove(X, Y: Single);
begin
  MoveTo(X, Y);
end;

procedure TPathBuilder.AppendLine(X, Y: Single);
begin
  LineTo(X, Y);
end;

procedure TPathBuilder.AppendClose;
begin
  Close;
end;

function TPathBuilder.Build: TPath;
begin
  if FVerbCount > 0 then
    Result.FVerbs := Copy(FVerbs, 0, FVerbCount)
  else
    Result.FVerbs := nil;
  if FPointCount > 0 then
    Result.FPoints := Copy(FPoints, 0, FPointCount)
  else
    Result.FPoints := nil;
  Result.FVerbCount := FVerbCount;
  Result.FPointCount := FPointCount;
end;

function TPathBuilder.IsEmpty: Boolean;
begin
  Result := FVerbCount = 0;
end;

function TPathBuilder.VerbCount: Integer;
begin
  Result := FVerbCount;
end;

function TPathBuilder.PointCount: Integer;
begin
  Result := FPointCount;
end;

function TPath.IsEmpty: Boolean;
begin
  Result := FVerbCount = 0;
end;

function TPath.VerbCount: Integer;
begin
  Result := FVerbCount;
end;

function TPath.PointCount: Integer;
begin
  Result := FPointCount;
end;

function TPath.GetVerb(AIndex: Integer): TPathVerb;
begin
  if (AIndex < 0) or (AIndex >= FVerbCount) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TPath.GetVerb: index out of range (index=' + IntToStr(AIndex) + ' VerbCount=' + IntToStr(FVerbCount) + ')');
  Result := FVerbs[AIndex];
end;

function TPath.GetPoint(AIndex: Integer): TVec2;
begin
  if (AIndex < 0) or (AIndex >= FPointCount) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TPath.GetPoint: index out of range (index=' + IntToStr(AIndex) + ' PointCount=' + IntToStr(FPointCount) + ')');
  Result := FPoints[AIndex];
end;

function TStrokeOptions.GetWidth: Single; inline;
begin
  Result := FWidth;
end;

function TStrokeOptions.GetCap: TLineCap; inline;
begin
  Result := FCap;
end;

function TStrokeOptions.GetJoin: TLineJoin; inline;
begin
  Result := FJoin;
end;

function TStrokeOptions.GetMiterLimit: Single; inline;
begin
  Result := FMiterLimit;
end;

class function TStrokeOptions.Create(AWidth: Single; ACap: TLineCap; AJoin: TLineJoin; AMiter: Single): TStrokeOptions;
begin
  if IsNaN(AWidth) or IsInfinite(AWidth) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.Create: Width must be finite');
  if AWidth < 0 then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.Create: Width must be >= 0');
  if IsNaN(AMiter) or IsInfinite(AMiter) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.Create: MiterLimit must be finite');
  if AMiter < 0 then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.Create: MiterLimit must be >= 0');
  Result.FWidth := AWidth;
  Result.FCap := ACap;
  Result.FJoin := AJoin;
  Result.FMiterLimit := AMiter;
end;

function TStrokeOptions.WithWidth(AWidth: Single): TStrokeOptions;
begin
  if IsNaN(AWidth) or IsInfinite(AWidth) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.WithWidth: Width must be finite');
  if AWidth < 0 then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.WithWidth: Width must be >= 0');
  Result := Self;
  Result.FWidth := AWidth;
end;

function TStrokeOptions.WithCap(ACap: TLineCap): TStrokeOptions; inline;
begin
  Result := Self;
  Result.FCap := ACap;
end;

function TStrokeOptions.WithJoin(AJoin: TLineJoin): TStrokeOptions; inline;
begin
  Result := Self;
  Result.FJoin := AJoin;
end;

function TStrokeOptions.WithMiterLimit(AMiter: Single): TStrokeOptions;
begin
  if IsNaN(AMiter) or IsInfinite(AMiter) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.WithMiterLimit: MiterLimit must be finite');
  if AMiter < 0 then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.WithMiterLimit: MiterLimit must be >= 0');
  Result := Self;
  Result.FMiterLimit := AMiter;
end;

{ TGradient }

class function TGradient.Create(AKind: TGradientKind; const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient;
var
  I: Integer;
  S, Prev: Single;
begin
  if Length(AColors) < 2 then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TGradient.Create: gradient needs >=2 colors');
  if (Length(AStops) <> 0) and (Length(AStops) <> Length(AColors)) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TGradient.Create: stops/colors length mismatch');
  if IsNaN(ATransform.A) or IsInfinite(ATransform.A) or IsNaN(ATransform.B) or IsInfinite(ATransform.B) or
     IsNaN(ATransform.C) or IsInfinite(ATransform.C) or IsNaN(ATransform.D) or IsInfinite(ATransform.D) or
     IsNaN(ATransform.Tx) or IsInfinite(ATransform.Tx) or IsNaN(ATransform.Ty) or IsInfinite(ATransform.Ty) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TGradient.Create: transform must be finite');
  if Length(AStops) > 0 then
  begin
    Prev := -1;
    for I := 0 to High(AStops) do
    begin
      S := AStops[I];
      if IsNaN(S) or IsInfinite(S) then
        raise EArgumentError.Create('nextpas.core.graphics.path.pas: TGradient.Create: stop must be finite');
      if (S < -1e-6) or (S > 1 + 1e-6) then
        raise EArgumentError.Create('nextpas.core.graphics.path.pas: TGradient.Create: stop out of [0,1]');
      if S < Prev - 1e-6 then
        raise EArgumentError.Create('nextpas.core.graphics.path.pas: TGradient.Create: stops must be monotonic');
      Prev := S;
    end;
  end;
  Result.FKind := AKind;
  if Length(AColors) > 0 then
    Result.FColors := Copy(AColors, 0, Length(AColors))
  else
    Result.FColors := nil;
  if Length(AStops) > 0 then
    Result.FStops := Copy(AStops, 0, Length(AStops))
  else
    Result.FStops := nil;
  Result.FTransform := ATransform;
end;

class function TGradient.Create(AKind: TGradientKind; const AColors: TColor32Array; const AStops: TSingleArray): TGradient;
begin
  Result := Create(AKind, AColors, AStops, TMat2D.Identity);
end;

class function TGradient.Linear(const AColors: TColor32Array; const AStops: TSingleArray): TGradient;
begin
  Result := Create(gkLinear, AColors, AStops, TMat2D.Identity);
end;

class function TGradient.Linear(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient;
begin
  Result := Create(gkLinear, AColors, AStops, ATransform);
end;

class function TGradient.Radial(const AColors: TColor32Array; const AStops: TSingleArray): TGradient;
begin
  Result := Create(gkRadial, AColors, AStops, TMat2D.Identity);
end;

class function TGradient.Radial(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient;
begin
  Result := Create(gkRadial, AColors, AStops, ATransform);
end;

function TGradient.ColorCount: Integer;
begin
  Result := Length(FColors);
end;

function TGradient.StopCount: Integer;
begin
  Result := Length(FStops);
end;

function TGradient.GetColor(AIndex: Integer): TColor32;
begin
  if (AIndex < 0) or (AIndex >= Length(FColors)) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TGradient.GetColor: index out of range (index=' + IntToStr(AIndex) + ' ColorCount=' + IntToStr(Length(FColors)) + ')');
  Result := FColors[AIndex];
end;

function TGradient.GetStop(AIndex: Integer): Single;
begin
  if (AIndex < 0) or (AIndex >= Length(FStops)) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TGradient.GetStop: index out of range (index=' + IntToStr(AIndex) + ' StopCount=' + IntToStr(Length(FStops)) + ')');
  Result := FStops[AIndex];
end;

function TGradient.GetColors: TColor32Array; inline;
begin
  if Length(FColors) > 0 then
    Result := Copy(FColors, 0, Length(FColors))
  else
    Result := nil;
end;

function TGradient.GetStops: TSingleArray; inline;
begin
  if Length(FStops) > 0 then
    Result := Copy(FStops, 0, Length(FStops))
  else
    Result := nil;
end;

function TGradient.Clone: TGradient;
begin
  Result.FKind := FKind;
  Result.FTransform := FTransform;
  if Length(FColors) > 0 then
    Result.FColors := Copy(FColors, 0, Length(FColors))
  else
    Result.FColors := nil;
  if Length(FStops) > 0 then
    Result.FStops := Copy(FStops, 0, Length(FStops))
  else
    Result.FStops := nil;
end;

function TGradient.WithTransform(const M: TMat2D): TGradient; inline;
begin
  if IsNaN(M.A) or IsInfinite(M.A) or IsNaN(M.B) or IsInfinite(M.B) or
     IsNaN(M.C) or IsInfinite(M.C) or IsNaN(M.D) or IsInfinite(M.D) or
     IsNaN(M.Tx) or IsInfinite(M.Tx) or IsNaN(M.Ty) or IsInfinite(M.Ty) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TGradient.WithTransform: matrix must be finite');
  Result := Clone;
  Result.FTransform := FTransform.Concat(M);
end;

function TGradient.WithOpacity(A: Single): TGradient;
var
  I: Integer;
  Rgba: TRgba;
begin
  if IsNaN(A) or IsInfinite(A) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TGradient.WithOpacity: opacity must be finite');
  if (A < -1e-6) or (A > 1 + 1e-6) then
    raise EArgumentError.Create('nextpas.core.graphics.path.pas: TGradient.WithOpacity: opacity out of [0,1]');
  if A < 0 then A := 0 else if A > 1 then A := 1;
  Result := Clone;
  if Length(Result.FColors) = 0 then Exit;
  for I := 0 to High(Result.FColors) do
  begin
    Rgba := Color32ToRgba(Result.FColors[I]);
    Rgba.A := Rgba.A * A;
    Result.FColors[I] := RgbaToColor32(Rgba);
  end;
end;

end.
