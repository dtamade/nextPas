{**
 * nextpas.core.graphics.path - TPath 值类型 COW + TGradient 不可变
 * 指数扩容 AlignUp(mem.base 单源 8) + BytesCopy(bytes.ops 单源)；L1 graphics.base 零 bytes 依赖，无重复 AlignUp/bytes 实现。
 * COW 写时 RC<>1 判别（复用 TBitmap.EnsureUnique 模式，Unique 时零拷贝）；TPath 链式 fluent 不可变值语义，
 * 小路径(<64)链式 O(N²) 常数小可直接用；Reserve 预分配后链式仍 O(N²)（1K 链式≈500K 拷贝，因 Result:=Self 共享 RC=2 需逐次 COW），
 * 大路径必须用 TPathBuilder 批量 O(N) 约 1K 拷贝（热点显著，链式禁用）；Builder fluent 链式
 * (MoveTo/LineTo→TPathBuilder) 与 TPath 风格统一，Append* 为同构别名；EnsureUnique 仅拷贝已用前缀非全容量。
 * TGradient 防御性 Copy 冷路径，热路径零分配；Colors/Stops 为防御性 Copy（不可变冷路径一次堆分配），
 * 高频循环用 GetColor/GetStop+Count inline 零堆分配；拒绝 ColorsView/StopsView 零拷贝别名外泄可变引用。
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

  { TPath 不可变链 fluent：小路径(<64)链式可用 O(N²) 常数小；大路径必须用 TPathBuilder 批量 O(N)（热点，Reserve 后链式仍 O(N²)，COW RC=2 逐次拷贝） }
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
    function Append(const AOther: TPath): TPath;
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
    function MoveTo(X, Y: Single): TPathBuilder; inline;
    function LineTo(X, Y: Single): TPathBuilder; inline;
    function QuadTo(CX, CY, X, Y: Single): TPathBuilder; inline;
    function CubicTo(C1X, C1Y, C2X, C2Y, X, Y: Single): TPathBuilder; inline;
    function Close: TPathBuilder; inline;
    function AppendMove(X, Y: Single): TPathBuilder; inline;
    function AppendLine(X, Y: Single): TPathBuilder; inline;
    function AppendClose: TPathBuilder; inline;
    function AppendPath(const AOther: TPath): TPathBuilder; inline;
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
    function GetColors: TColor32Array; // cold: defensive Copy heap alloc; hot use GetColor inline zero-alloc
    function GetStops: TSingleArray; // cold: defensive Copy heap alloc; hot use GetStop inline zero-alloc
  public
    class function Create(AKind: TGradientKind; const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient; overload; static;
    class function Create(AKind: TGradientKind; const AColors: TColor32Array; const AStops: TSingleArray): TGradient; overload; static; inline;
    class function Linear(const AColors: TColor32Array; const AStops: TSingleArray): TGradient; overload; static; inline;
    class function Linear(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient; overload; static; inline;
    class function Radial(const AColors: TColor32Array; const AStops: TSingleArray): TGradient; overload; static; inline;
    class function Radial(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient; overload; static; inline;
    property Kind: TGradientKind read FKind;
    property Colors: TColor32Array read GetColors; // cold defensive Copy; hot use GetColor/ColorCount inline zero-alloc
    property Stops: TSingleArray read GetStops; // cold defensive Copy; hot use GetStop/StopCount inline zero-alloc
    property Transform: TMat2D read FTransform;
    function ColorCount: Integer; inline; // inline zero-alloc
    function StopCount: Integer; inline; // inline zero-alloc
    function GetColor(AIndex: Integer): TColor32; inline; // inline zero-alloc
    function GetStop(AIndex: Integer): Single; inline; // inline zero-alloc
    function Clone: TGradient; inline;
    function WithTransform(const M: TMat2D): TGradient; inline;
    function WithOpacity(A: Single): TGradient;
  end;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.math;

{ TPath helpers — EnsureCap 复用 mem.base AlignUp 单源，EnsureUnique 查 RC<>1 零拷贝，BytesCopy 单源(bytes.ops)；保持 L1 graphics.base 零 bytes 依赖，无重复 AlignUp/bytes 实现
  EnsureUnique/EnsureCap 共享时仅拷贝已用前缀 (FVerbCount/FPointCount) 非全容量，减少 Reserve 后链式尾部垃圾拷贝；大路径仍 O(N²)，须用 Builder 批量 O(N) }

procedure TPath.EnsureVerbCap(ANeeded: Integer);
var
  LCap, LNewCap: SizeUInt;
  LOld: array of TPathVerb;
  LCopy: Integer;
  P: PByte;
  RC: SizeInt;
  PRC: ^SizeInt;
begin
  LCap := SizeUInt(Length(FVerbs));
  if LCap >= SizeUInt(ANeeded) then Exit;
  if LCap = 0 then LNewCap := 8
  else begin LNewCap := LCap * 2; if LNewCap < SizeUInt(ANeeded) then LNewCap := SizeUInt(ANeeded); end;
  LNewCap := AlignUp(LNewCap, 8);
  if LNewCap = 0 then LNewCap := SizeUInt(ANeeded);
  if Length(FVerbs) = 0 then begin SetLength(FVerbs, Integer(LNewCap)); Exit; end;
  // Unique 时直接 SetLength 复用 realloc；共享时仅拷贝已用前缀非全容量
  P := PByte(@FVerbs[0]);
  PRC := Pointer(NativeUInt(P) - SizeOf(SizeInt) * 2);
  RC := PRC^;
  if RC = 1 then begin SetLength(FVerbs, Integer(LNewCap)); Exit; end;
  if FVerbCount > 0 then LCopy := FVerbCount else LCopy := 0;
  LOld := FVerbs;
  FVerbs := nil;
  SetLength(FVerbs, Integer(LNewCap));
  if LCopy > 0 then BytesCopy(@FVerbs[0], @LOld[0], LCopy * SizeOf(TPathVerb));
end;

procedure TPath.EnsurePointCap(ANeeded: Integer);
var
  LCap, LNewCap: SizeUInt;
  LOld: array of TVec2;
  LCopy: Integer;
  P: PByte;
  RC: SizeInt;
  PRC: ^SizeInt;
begin
  LCap := SizeUInt(Length(FPoints));
  if LCap >= SizeUInt(ANeeded) then Exit;
  if LCap = 0 then LNewCap := 8
  else begin LNewCap := LCap * 2; if LNewCap < SizeUInt(ANeeded) then LNewCap := SizeUInt(ANeeded); end;
  LNewCap := AlignUp(LNewCap, 8);
  if LNewCap = 0 then LNewCap := SizeUInt(ANeeded);
  if Length(FPoints) = 0 then begin SetLength(FPoints, Integer(LNewCap)); Exit; end;
  P := PByte(@FPoints[0]);
  PRC := Pointer(NativeUInt(P) - SizeOf(SizeInt) * 2);
  RC := PRC^;
  if RC = 1 then begin SetLength(FPoints, Integer(LNewCap)); Exit; end;
  if FPointCount > 0 then LCopy := FPointCount else LCopy := 0;
  LOld := FPoints;
  FPoints := nil;
  SetLength(FPoints, Integer(LNewCap));
  if LCopy > 0 then BytesCopy(@FPoints[0], @LOld[0], LCopy * SizeOf(TVec2));
end;

procedure TPath.EnsureVerbUnique;
var
  P: PByte;
  RC: SizeInt;
  PRC: ^SizeInt;
  LCap: Integer;
  LOld: array of TPathVerb;
begin
  if Length(FVerbs) = 0 then Exit;
  P := PByte(@FVerbs[0]);
  PRC := Pointer(NativeUInt(P) - SizeOf(SizeInt) * 2);
  RC := PRC^;
  if RC <> 1 then
  begin
    LCap := Length(FVerbs);
    LOld := FVerbs;
    FVerbs := nil;
    SetLength(FVerbs, LCap);
    if FVerbCount > 0 then BytesCopy(@FVerbs[0], @LOld[0], FVerbCount * SizeOf(TPathVerb));
  end;
end;

procedure TPath.EnsurePointUnique;
var
  P: PByte;
  RC: SizeInt;
  PRC: ^SizeInt;
  LCap: Integer;
  LOld: array of TVec2;
begin
  if Length(FPoints) = 0 then Exit;
  P := PByte(@FPoints[0]);
  PRC := Pointer(NativeUInt(P) - SizeOf(SizeInt) * 2);
  RC := PRC^;
  if RC <> 1 then
  begin
    LCap := Length(FPoints);
    LOld := FPoints;
    FPoints := nil;
    SetLength(FPoints, LCap);
    if FPointCount > 0 then BytesCopy(@FPoints[0], @LOld[0], FPointCount * SizeOf(TVec2));
  end;
end;

class function TPath.New: TPath;
begin
  Result.FVerbs := nil; Result.FPoints := nil;
  Result.FVerbCount := 0; Result.FPointCount := 0;
end;

function TPath.GetCount: Integer;
begin Result := FVerbCount; end;

function TPath.Reserve(ACapVerbs, ACapPoints: Integer): TPath;
begin
  if ACapVerbs < 0 then ACapVerbs := 0;
  if ACapPoints < 0 then ACapPoints := 0;
  Result := Self;
  if ACapVerbs > Length(Result.FVerbs) then Result.EnsureVerbCap(ACapVerbs)
  else if Length(Result.FVerbs) > 0 then Result.EnsureVerbUnique;
  if ACapPoints > Length(Result.FPoints) then Result.EnsurePointCap(ACapPoints)
  else if Length(Result.FPoints) > 0 then Result.EnsurePointUnique;
end;

function TPath.MoveTo(X, Y: Single): TPath;
begin
  if IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EVectorError.Create('nextpas.core.graphics.path.pas: TPath.MoveTo: X/Y must be finite');
  Result := Self;
  if (Result.FVerbCount > 0) and (Result.FVerbs[Result.FVerbCount - 1] = pvMove) then
  begin
    if Length(Result.FPoints) > 0 then Result.EnsurePointUnique;
    if Length(Result.FVerbs) > 0 then Result.EnsureVerbUnique;
    Result.FPoints[Result.FPointCount - 1] := TVec2.Create(X, Y);
    Exit;
  end;
  if SizeUInt(Length(Result.FVerbs)) < SizeUInt(Result.FVerbCount + 1) then Result.EnsureVerbCap(Result.FVerbCount + 1)
  else Result.EnsureVerbUnique;
  if SizeUInt(Length(Result.FPoints)) < SizeUInt(Result.FPointCount + 1) then Result.EnsurePointCap(Result.FPointCount + 1)
  else Result.EnsurePointUnique;
  Result.FVerbs[Result.FVerbCount] := pvMove; Inc(Result.FVerbCount);
  Result.FPoints[Result.FPointCount] := TVec2.Create(X, Y); Inc(Result.FPointCount);
end;

function TPath.LineTo(X, Y: Single): TPath;
begin
  if IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EVectorError.Create('nextpas.core.graphics.path.pas: TPath.LineTo: X/Y must be finite');
  Result := Self;
  if SizeUInt(Length(Result.FVerbs)) < SizeUInt(Result.FVerbCount + 1) then Result.EnsureVerbCap(Result.FVerbCount + 1)
  else Result.EnsureVerbUnique;
  if SizeUInt(Length(Result.FPoints)) < SizeUInt(Result.FPointCount + 1) then Result.EnsurePointCap(Result.FPointCount + 1)
  else Result.EnsurePointUnique;
  Result.FVerbs[Result.FVerbCount] := pvLine; Inc(Result.FVerbCount);
  Result.FPoints[Result.FPointCount] := TVec2.Create(X, Y); Inc(Result.FPointCount);
end;

function TPath.QuadTo(CX, CY, X, Y: Single): TPath;
begin
  if IsNaN(CX) or IsInfinite(CX) or IsNaN(CY) or IsInfinite(CY) or IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EVectorError.Create('nextpas.core.graphics.path.pas: TPath.QuadTo: CX/CY/X/Y must be finite');
  Result := Self;
  if SizeUInt(Length(Result.FVerbs)) < SizeUInt(Result.FVerbCount + 1) then Result.EnsureVerbCap(Result.FVerbCount + 1)
  else Result.EnsureVerbUnique;
  if SizeUInt(Length(Result.FPoints)) < SizeUInt(Result.FPointCount + 2) then Result.EnsurePointCap(Result.FPointCount + 2)
  else Result.EnsurePointUnique;
  Result.FVerbs[Result.FVerbCount] := pvQuad; Inc(Result.FVerbCount);
  Result.FPoints[Result.FPointCount] := TVec2.Create(CX, CY);
  Result.FPoints[Result.FPointCount + 1] := TVec2.Create(X, Y); Inc(Result.FPointCount, 2);
end;

function TPath.CubicTo(C1X, C1Y, C2X, C2Y, X, Y: Single): TPath;
begin
  if IsNaN(C1X) or IsInfinite(C1X) or IsNaN(C1Y) or IsInfinite(C1Y) or IsNaN(C2X) or IsInfinite(C2X) or IsNaN(C2Y) or IsInfinite(C2Y) or IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then
    raise EVectorError.Create('nextpas.core.graphics.path.pas: TPath.CubicTo: C1X/C1Y/C2X/C2Y/X/Y must be finite');
  Result := Self;
  if SizeUInt(Length(Result.FVerbs)) < SizeUInt(Result.FVerbCount + 1) then Result.EnsureVerbCap(Result.FVerbCount + 1)
  else Result.EnsureVerbUnique;
  if SizeUInt(Length(Result.FPoints)) < SizeUInt(Result.FPointCount + 3) then Result.EnsurePointCap(Result.FPointCount + 3)
  else Result.EnsurePointUnique;
  Result.FVerbs[Result.FVerbCount] := pvCubic; Inc(Result.FVerbCount);
  Result.FPoints[Result.FPointCount] := TVec2.Create(C1X, C1Y);
  Result.FPoints[Result.FPointCount + 1] := TVec2.Create(C2X, C2Y);
  Result.FPoints[Result.FPointCount + 2] := TVec2.Create(X, Y); Inc(Result.FPointCount, 3);
end;

function TPath.Close: TPath;
begin
  if (FVerbCount > 0) and (FVerbs[FVerbCount - 1] = pvClose) then Exit(Self);
  Result := Self;
  if SizeUInt(Length(Result.FVerbs)) < SizeUInt(Result.FVerbCount + 1) then Result.EnsureVerbCap(Result.FVerbCount + 1)
  else Result.EnsureVerbUnique;
  Result.FVerbs[Result.FVerbCount] := pvClose; Inc(Result.FVerbCount);
end;

function TPath.Append(const AOther: TPath): TPath;
var LNeedV, LNeedP: Integer;
begin
  if AOther.FVerbCount = 0 then Exit(Self);
  Result := Self;
  LNeedV := Result.FVerbCount + AOther.FVerbCount;
  LNeedP := Result.FPointCount + AOther.FPointCount;
  // Append 批量零拷贝：单次 Reserve(AlignUp 单源) + BytesCopy(bytes.ops 单源) O(N) 降级
  if SizeUInt(Length(Result.FVerbs)) < SizeUInt(LNeedV) then Result.EnsureVerbCap(LNeedV)
  else if Length(Result.FVerbs) > 0 then Result.EnsureVerbUnique;
  if SizeUInt(Length(Result.FPoints)) < SizeUInt(LNeedP) then Result.EnsurePointCap(LNeedP)
  else if Length(Result.FPoints) > 0 then Result.EnsurePointUnique;
  if (Result.FVerbCount > 0) and (AOther.FVerbCount > 0) and (Result.FVerbs[Result.FVerbCount - 1] = pvMove) and (AOther.FVerbs[0] = pvMove) then
  begin
    Result.FPoints[Result.FPointCount - 1] := AOther.FPoints[0];
    if AOther.FVerbCount > 1 then BytesCopy(@Result.FVerbs[Result.FVerbCount], @AOther.FVerbs[1], (AOther.FVerbCount - 1) * SizeOf(TPathVerb));
    if AOther.FPointCount > 1 then BytesCopy(@Result.FPoints[Result.FPointCount], @AOther.FPoints[1], (AOther.FPointCount - 1) * SizeOf(TVec2));
    Inc(Result.FVerbCount, AOther.FVerbCount - 1); Inc(Result.FPointCount, AOther.FPointCount - 1); Exit;
  end;
  BytesCopy(@Result.FVerbs[Result.FVerbCount], @AOther.FVerbs[0], AOther.FVerbCount * SizeOf(TPathVerb));
  BytesCopy(@Result.FPoints[Result.FPointCount], @AOther.FPoints[0], AOther.FPointCount * SizeOf(TVec2));
  Inc(Result.FVerbCount, AOther.FVerbCount); Inc(Result.FPointCount, AOther.FPointCount);
end;

procedure TPathBuilder.EnsureVerbCap(ANeeded: Integer);
var LCap, LNewCap: SizeUInt;
begin
  LCap := SizeUInt(Length(FVerbs)); if LCap >= SizeUInt(ANeeded) then Exit;
  if LCap = 0 then LNewCap := 8 else begin LNewCap := LCap * 2; if LNewCap < SizeUInt(ANeeded) then LNewCap := SizeUInt(ANeeded); end;
  LNewCap := AlignUp(LNewCap, 8); if LNewCap = 0 then LNewCap := SizeUInt(ANeeded);
  SetLength(FVerbs, Integer(LNewCap));
end;

procedure TPathBuilder.EnsurePointCap(ANeeded: Integer);
var LCap, LNewCap: SizeUInt;
begin
  LCap := SizeUInt(Length(FPoints)); if LCap >= SizeUInt(ANeeded) then Exit;
  if LCap = 0 then LNewCap := 8 else begin LNewCap := LCap * 2; if LNewCap < SizeUInt(ANeeded) then LNewCap := SizeUInt(ANeeded); end;
  LNewCap := AlignUp(LNewCap, 8); if LNewCap = 0 then LNewCap := SizeUInt(ANeeded);
  SetLength(FPoints, Integer(LNewCap));
end;

class function TPathBuilder.Create: TPathBuilder;
begin Result.FVerbs := nil; Result.FPoints := nil; Result.FVerbCount := 0; Result.FPointCount := 0; end;

procedure TPathBuilder.Reserve(ACapVerbs, ACapPoints: Integer);
begin if ACapVerbs > 0 then EnsureVerbCap(ACapVerbs); if ACapPoints > 0 then EnsurePointCap(ACapPoints); end;

function TPathBuilder.MoveTo(X, Y: Single): TPathBuilder;
begin
  if IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then raise EVectorError.Create('nextpas.core.graphics.path.pas: TPathBuilder.MoveTo: X/Y must be finite');
  if (FVerbCount > 0) and (FVerbs[FVerbCount - 1] = pvMove) then begin FPoints[FPointCount - 1] := TVec2.Create(X, Y); Result := Self; Exit; end;
  EnsureVerbCap(FVerbCount + 1); EnsurePointCap(FPointCount + 1);
  FVerbs[FVerbCount] := pvMove; Inc(FVerbCount); FPoints[FPointCount] := TVec2.Create(X, Y); Inc(FPointCount);
  Result := Self;
end;

function TPathBuilder.LineTo(X, Y: Single): TPathBuilder;
begin
  if IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then raise EVectorError.Create('nextpas.core.graphics.path.pas: TPathBuilder.LineTo: X/Y must be finite');
  EnsureVerbCap(FVerbCount + 1); EnsurePointCap(FPointCount + 1);
  FVerbs[FVerbCount] := pvLine; Inc(FVerbCount); FPoints[FPointCount] := TVec2.Create(X, Y); Inc(FPointCount);
  Result := Self;
end;

function TPathBuilder.QuadTo(CX, CY, X, Y: Single): TPathBuilder;
begin
  if IsNaN(CX) or IsInfinite(CX) or IsNaN(CY) or IsInfinite(CY) or IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then raise EVectorError.Create('nextpas.core.graphics.path.pas: TPathBuilder.QuadTo: CX/CY/X/Y must be finite');
  EnsureVerbCap(FVerbCount + 1); EnsurePointCap(FPointCount + 2);
  FVerbs[FVerbCount] := pvQuad; Inc(FVerbCount); FPoints[FPointCount] := TVec2.Create(CX, CY); FPoints[FPointCount + 1] := TVec2.Create(X, Y); Inc(FPointCount, 2);
  Result := Self;
end;

function TPathBuilder.CubicTo(C1X, C1Y, C2X, C2Y, X, Y: Single): TPathBuilder;
begin
  if IsNaN(C1X) or IsInfinite(C1X) or IsNaN(C1Y) or IsInfinite(C1Y) or IsNaN(C2X) or IsInfinite(C2X) or IsNaN(C2Y) or IsInfinite(C2Y) or IsNaN(X) or IsInfinite(X) or IsNaN(Y) or IsInfinite(Y) then raise EVectorError.Create('nextpas.core.graphics.path.pas: TPathBuilder.CubicTo: C1X/C1Y/C2X/C2Y/X/Y must be finite');
  EnsureVerbCap(FVerbCount + 1); EnsurePointCap(FPointCount + 3);
  FVerbs[FVerbCount] := pvCubic; Inc(FVerbCount); FPoints[FPointCount] := TVec2.Create(C1X, C1Y); FPoints[FPointCount + 1] := TVec2.Create(C2X, C2Y); FPoints[FPointCount + 2] := TVec2.Create(X, Y); Inc(FPointCount, 3);
  Result := Self;
end;

function TPathBuilder.Close: TPathBuilder;
begin if (FVerbCount > 0) and (FVerbs[FVerbCount - 1] = pvClose) then begin Result := Self; Exit; end; EnsureVerbCap(FVerbCount + 1); FVerbs[FVerbCount] := pvClose; Inc(FVerbCount); Result := Self; end;

function TPathBuilder.AppendMove(X, Y: Single): TPathBuilder; begin Result := MoveTo(X, Y); end;
function TPathBuilder.AppendLine(X, Y: Single): TPathBuilder; begin Result := LineTo(X, Y); end;
function TPathBuilder.AppendClose: TPathBuilder; begin Result := Close; end;

function TPathBuilder.AppendPath(const AOther: TPath): TPathBuilder;
var LNeedV, LNeedP: Integer;
begin
  if AOther.FVerbCount = 0 then begin Result := Self; Exit; end;
  LNeedV := FVerbCount + AOther.FVerbCount; LNeedP := FPointCount + AOther.FPointCount;
  EnsureVerbCap(LNeedV); EnsurePointCap(LNeedP);
  if (FVerbCount > 0) and (AOther.FVerbs[0] = pvMove) and (FVerbs[FVerbCount - 1] = pvMove) then
  begin
    FPoints[FPointCount - 1] := AOther.FPoints[0];
    if AOther.FVerbCount > 1 then BytesCopy(@FVerbs[FVerbCount], @AOther.FVerbs[1], (AOther.FVerbCount - 1) * SizeOf(TPathVerb));
    if AOther.FPointCount > 1 then BytesCopy(@FPoints[FPointCount], @AOther.FPoints[1], (AOther.FPointCount - 1) * SizeOf(TVec2));
    Inc(FVerbCount, AOther.FVerbCount - 1); Inc(FPointCount, AOther.FPointCount - 1); Result := Self; Exit;
  end;
  BytesCopy(@FVerbs[FVerbCount], @AOther.FVerbs[0], AOther.FVerbCount * SizeOf(TPathVerb));
  BytesCopy(@FPoints[FPointCount], @AOther.FPoints[0], AOther.FPointCount * SizeOf(TVec2));
  Inc(FVerbCount, AOther.FVerbCount); Inc(FPointCount, AOther.FPointCount);
  Result := Self;
end;

function TPathBuilder.Build: TPath;
begin
  if FVerbCount > 0 then Result.FVerbs := Copy(FVerbs, 0, FVerbCount) else Result.FVerbs := nil;
  if FPointCount > 0 then Result.FPoints := Copy(FPoints, 0, FPointCount) else Result.FPoints := nil;
  Result.FVerbCount := FVerbCount; Result.FPointCount := FPointCount;
end;

function TPathBuilder.IsEmpty: Boolean; begin Result := FVerbCount = 0; end;
function TPathBuilder.VerbCount: Integer; begin Result := FVerbCount; end;
function TPathBuilder.PointCount: Integer; begin Result := FPointCount; end;
function TPath.IsEmpty: Boolean; begin Result := FVerbCount = 0; end;
function TPath.VerbCount: Integer; begin Result := FVerbCount; end;
function TPath.PointCount: Integer; begin Result := FPointCount; end;

function TPath.GetVerb(AIndex: Integer): TPathVerb;
begin
  if (AIndex < 0) or (AIndex >= FVerbCount) then raise EVectorError.Create('nextpas.core.graphics.path.pas: TPath.GetVerb: index out of range (index=' + IntToStr(AIndex) + ' VerbCount=' + IntToStr(FVerbCount) + ')');
  Result := FVerbs[AIndex];
end;

function TPath.GetPoint(AIndex: Integer): TVec2;
begin
  if (AIndex < 0) or (AIndex >= FPointCount) then raise EVectorError.Create('nextpas.core.graphics.path.pas: TPath.GetPoint: index out of range (index=' + IntToStr(AIndex) + ' PointCount=' + IntToStr(FPointCount) + ')');
  Result := FPoints[AIndex];
end;

function TStrokeOptions.GetWidth: Single; inline; begin Result := FWidth; end;
function TStrokeOptions.GetCap: TLineCap; inline; begin Result := FCap; end;
function TStrokeOptions.GetJoin: TLineJoin; inline; begin Result := FJoin; end;
function TStrokeOptions.GetMiterLimit: Single; inline; begin Result := FMiterLimit; end;

class function TStrokeOptions.Create(AWidth: Single; ACap: TLineCap; AJoin: TLineJoin; AMiter: Single): TStrokeOptions;
begin
  if IsNaN(AWidth) or IsInfinite(AWidth) then raise EVectorError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.Create: Width must be finite');
  if AWidth < 0 then raise EVectorError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.Create: Width must be >= 0');
  if IsNaN(AMiter) or IsInfinite(AMiter) then raise EVectorError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.Create: MiterLimit must be finite');
  if AMiter < 0 then raise EVectorError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.Create: MiterLimit must be >= 0');
  Result.FWidth := AWidth; Result.FCap := ACap; Result.FJoin := AJoin; Result.FMiterLimit := AMiter;
end;

function TStrokeOptions.WithWidth(AWidth: Single): TStrokeOptions;
begin
  if IsNaN(AWidth) or IsInfinite(AWidth) then raise EVectorError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.WithWidth: Width must be finite');
  if AWidth < 0 then raise EVectorError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.WithWidth: Width must be >= 0');
  Result := Self; Result.FWidth := AWidth;
end;

function TStrokeOptions.WithCap(ACap: TLineCap): TStrokeOptions; inline; begin Result := Self; Result.FCap := ACap; end;
function TStrokeOptions.WithJoin(AJoin: TLineJoin): TStrokeOptions; inline; begin Result := Self; Result.FJoin := AJoin; end;

function TStrokeOptions.WithMiterLimit(AMiter: Single): TStrokeOptions;
begin
  if IsNaN(AMiter) or IsInfinite(AMiter) then raise EVectorError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.WithMiterLimit: MiterLimit must be finite');
  if AMiter < 0 then raise EVectorError.Create('nextpas.core.graphics.path.pas: TStrokeOptions.WithMiterLimit: MiterLimit must be >= 0');
  Result := Self; Result.FMiterLimit := AMiter;
end;

{ TGradient }

class function TGradient.Create(AKind: TGradientKind; const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient;
var I: Integer; S, Prev: Single;
begin
  if Length(AColors) < 2 then raise EColorError.Create('nextpas.core.graphics.path.pas: TGradient.Create: gradient needs >=2 colors');
  if (Length(AStops) <> 0) and (Length(AStops) <> Length(AColors)) then raise EColorError.Create('nextpas.core.graphics.path.pas: TGradient.Create: stops/colors length mismatch');
  if IsNaN(ATransform.A) or IsInfinite(ATransform.A) or IsNaN(ATransform.B) or IsInfinite(ATransform.B) or IsNaN(ATransform.C) or IsInfinite(ATransform.C) or IsNaN(ATransform.D) or IsInfinite(ATransform.D) or IsNaN(ATransform.Tx) or IsInfinite(ATransform.Tx) or IsNaN(ATransform.Ty) or IsInfinite(ATransform.Ty) then raise EColorError.Create('nextpas.core.graphics.path.pas: TGradient.Create: transform must be finite');
  if Length(AStops) > 0 then begin Prev := -1; for I := 0 to High(AStops) do begin S := AStops[I]; if IsNaN(S) or IsInfinite(S) then raise EColorError.Create('nextpas.core.graphics.path.pas: TGradient.Create: stop must be finite'); if (S < -1e-6) or (S > 1 + 1e-6) then raise EColorError.Create('nextpas.core.graphics.path.pas: TGradient.Create: stop out of [0,1]'); if S < Prev - 1e-6 then raise EColorError.Create('nextpas.core.graphics.path.pas: TGradient.Create: stops must be monotonic'); Prev := S; end; end;
  Result.FKind := AKind;
  if Length(AColors) > 0 then Result.FColors := Copy(AColors, 0, Length(AColors)) else Result.FColors := nil;
  if Length(AStops) > 0 then Result.FStops := Copy(AStops, 0, Length(AStops)) else Result.FStops := nil;
  Result.FTransform := ATransform;
end;

class function TGradient.Create(AKind: TGradientKind; const AColors: TColor32Array; const AStops: TSingleArray): TGradient;
begin Result := Create(AKind, AColors, AStops, TMat2D.Identity); end;
class function TGradient.Linear(const AColors: TColor32Array; const AStops: TSingleArray): TGradient;
begin Result := Create(gkLinear, AColors, AStops, TMat2D.Identity); end;
class function TGradient.Linear(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient;
begin Result := Create(gkLinear, AColors, AStops, ATransform); end;
class function TGradient.Radial(const AColors: TColor32Array; const AStops: TSingleArray): TGradient;
begin Result := Create(gkRadial, AColors, AStops, TMat2D.Identity); end;
class function TGradient.Radial(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TGradient;
begin Result := Create(gkRadial, AColors, AStops, ATransform); end;
function TGradient.ColorCount: Integer; inline; begin Result := Length(FColors); end;
function TGradient.StopCount: Integer; inline; begin Result := Length(FStops); end;
function TGradient.GetColor(AIndex: Integer): TColor32; inline;
begin if (AIndex < 0) or (AIndex >= Length(FColors)) then raise EColorError.Create('nextpas.core.graphics.path.pas: TGradient.GetColor: index out of range (index=' + IntToStr(AIndex) + ' ColorCount=' + IntToStr(Length(FColors)) + ')'); Result := FColors[AIndex]; end;
function TGradient.GetStop(AIndex: Integer): Single; inline;
begin if (AIndex < 0) or (AIndex >= Length(FStops)) then raise EColorError.Create('nextpas.core.graphics.path.pas: TGradient.GetStop: index out of range (index=' + IntToStr(AIndex) + ' StopCount=' + IntToStr(Length(FStops)) + ')'); Result := FStops[AIndex]; end;
function TGradient.GetColors: TColor32Array; // defensive Copy cold; hot use GetColor inline zero-alloc
begin if Length(FColors) > 0 then Result := Copy(FColors, 0, Length(FColors)) else Result := nil; end;
function TGradient.GetStops: TSingleArray; // defensive Copy cold; hot use GetStop inline zero-alloc
begin if Length(FStops) > 0 then Result := Copy(FStops, 0, Length(FStops)) else Result := nil; end;
function TGradient.Clone: TGradient;
begin Result.FKind := FKind; Result.FTransform := FTransform; if Length(FColors) > 0 then Result.FColors := Copy(FColors, 0, Length(FColors)) else Result.FColors := nil; if Length(FStops) > 0 then Result.FStops := Copy(FStops, 0, Length(FStops)) else Result.FStops := nil; end;
function TGradient.WithTransform(const M: TMat2D): TGradient; inline;
begin if IsNaN(M.A) or IsInfinite(M.A) or IsNaN(M.B) or IsInfinite(M.B) or IsNaN(M.C) or IsInfinite(M.C) or IsNaN(M.D) or IsInfinite(M.D) or IsNaN(M.Tx) or IsInfinite(M.Tx) or IsNaN(M.Ty) or IsInfinite(M.Ty) then raise EColorError.Create('nextpas.core.graphics.path.pas: TGradient.WithTransform: matrix must be finite'); Result := Clone; Result.FTransform := FTransform.Concat(M); end;
function TGradient.WithOpacity(A: Single): TGradient;
var I: Integer; Rgba: TRgba;
begin
  if IsNaN(A) or IsInfinite(A) then raise EColorError.Create('nextpas.core.graphics.path.pas: TGradient.WithOpacity: opacity must be finite');
  if (A < -1e-6) or (A > 1 + 1e-6) then raise EColorError.Create('nextpas.core.graphics.path.pas: TGradient.WithOpacity: opacity out of [0,1]');
  if A < 0 then A := 0 else if A > 1 then A := 1;
  Result := Clone; if Length(Result.FColors) = 0 then Exit;
  for I := 0 to High(Result.FColors) do begin Rgba := Color32ToRgba(Result.FColors[I]); Rgba.A := Rgba.A * A; Result.FColors[I] := RgbaToColor32(Rgba); end;
end;

end.
