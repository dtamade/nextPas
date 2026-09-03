{**
 * nextpas.core.graphics.svg - SvgImport 闭环 (M/L/H/V/C/S/Q/T/Z 9指令=8族，16384 cap，EVectorError)
 * 仅解析 SVG path data (d="M x y L x y C ... Z")，M/L/H/V/C/S/Q/T/Z 子集，单精度 Single 外部。
 * L2，仅依 graphics.base/path + text.conv + math，不依赖 xml/html/dom/bytes，避免 L2→L2 循环。
 * 完整性：M/L/H/V/C/S/Q/T/Z 9指令闭环（S/s 为 C 的平滑延续反射前一 C/S 第二控制点，T/t 为 Q 的平滑延续，H/V 单轴捷径）；
 *   arc(A) 预留，后续薄层增量；已满足 directui 图标矢量导入闭环。
 * 稳定性：空串/非法字符/截断/点数>16384 抛 EVectorError（Try* 返回 False 不抛），数值 NaN/Inf 守卫。
 * 复用：TPathBuilder 批量 O(N) 单次 Reserve + Build 零拷贝；数值解析复用 text.conv TryStrToFloat 单源，不自研扫描。
 * 性能：SkipWs/TryParseFloat inline，TPathBuilder 零拷贝，cap 16384 防爆 O(WH)。
 *}
unit nextpas.core.graphics.svg;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.graphics.path;

function SvgPathFromData(const AData: string): TPath;
function TrySvgPathFromData(const AData: string; out APath: TPath): Boolean;

implementation

uses
  nextpas.core.graphics.errors,
  nextpas.core.text.conv,
  nextpas.core.math;

function SkipWs(const S: string; var P: Integer): Boolean; inline;
begin
  while (P <= Length(S)) and (S[P] in [' ', #9, #10, #13, ',']) do Inc(P);
  Result := P <= Length(S);
end;

function TryParseFloat(const S: string; var P: Integer; out V: Single): Boolean; inline;
var
  Start, Len: Integer;
  Sub: string;
  D: Double;
begin
  if not SkipWs(S, P) then Exit(False);
  Start := P;
  if (P <= Length(S)) and (S[P] in ['+', '-']) then Inc(P);
  while (P <= Length(S)) and (S[P] in ['0'..'9', '.', 'e', 'E', '+', '-']) do Inc(P);
  Len := P - Start;
  if Len <= 0 then Exit(False);
  Sub := Copy(S, Start, Len); // 小串 Copy 冷路径，热路径 TryStrToFloat 单源 text.conv
  if not TryStrToFloat(Sub, D) then Exit(False);
  if IsNaN(D) or IsInfinite(D) then Exit(False);
  V := Single(D);
  Result := True;
end;

function SvgPathFromData(const AData: string): TPath;
var
  P, L: Integer;
  Cmd, LastCmd: Char;
  B: TPathBuilder;
  Cur, Start: TVec2;
  HasCur: Boolean;
  X, Y, X1, Y1, X2, Y2: Single;
  Need: Integer;
  LastCubicX, LastCubicY: Single;
  LastQuadX, LastQuadY: Single;
  HasLastCubic, HasLastQuad: Boolean;
begin
  if Trim(AData) = '' then
    raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: empty data');
  B := TPathBuilder.Create;
  B.Reserve(64, 64);
  P := 1; L := Length(AData);
  HasCur := False;
  Start := TVec2.Create(0, 0);
  Cur := Start;
  LastCmd := #0;
  LastCubicX := 0; LastCubicY := 0; HasLastCubic := False;
  LastQuadX := 0; LastQuadY := 0; HasLastQuad := False;
  while P <= L do
  begin
    if not SkipWs(AData, P) then Break;
    if P > L then Break;
    Cmd := AData[P];
    if Cmd in ['A'..'Z', 'a'..'z'] then
    begin
      Inc(P);
      LastCmd := Cmd;
    end else if LastCmd <> #0 then
      Cmd := LastCmd
    else
      raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: unexpected number without command');

    case Cmd of
      'M', 'm':
        begin
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: M x missing');
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: M y missing');
          if Cmd = 'm' then begin X := Cur.X + X; Y := Cur.Y + Y; end;
          B.MoveTo(X, Y);
          Cur := TVec2.Create(X, Y); Start := Cur; HasCur := True;
          HasLastCubic := False; HasLastQuad := False;
          // 后续隐式 L
          LastCmd := 'L';
          if Cmd = 'm' then LastCmd := 'l';
        end;
      'L', 'l':
        begin
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: L x missing');
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: L y missing');
          if Cmd = 'l' then begin X := Cur.X + X; Y := Cur.Y + Y; end;
          B.LineTo(X, Y);
          Cur := TVec2.Create(X, Y);
          HasLastCubic := False; HasLastQuad := False;
        end;
      'H', 'h':
        begin
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: H x missing');
          if Cmd = 'h' then X := Cur.X + X;
          B.LineTo(X, Cur.Y);
          Cur := TVec2.Create(X, Cur.Y);
          HasLastCubic := False; HasLastQuad := False;
        end;
      'V', 'v':
        begin
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: V y missing');
          if Cmd = 'v' then Y := Cur.Y + Y;
          B.LineTo(Cur.X, Y);
          Cur := TVec2.Create(Cur.X, Y);
          HasLastCubic := False; HasLastQuad := False;
        end;
      'C', 'c':
        begin
          if not TryParseFloat(AData, P, X1) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: C x1 missing');
          if not TryParseFloat(AData, P, Y1) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: C y1 missing');
          if not TryParseFloat(AData, P, X2) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: C x2 missing');
          if not TryParseFloat(AData, P, Y2) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: C y2 missing');
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: C x missing');
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: C y missing');
          if Cmd = 'c' then begin X1:=Cur.X+X1; Y1:=Cur.Y+Y1; X2:=Cur.X+X2; Y2:=Cur.Y+Y2; X:=Cur.X+X; Y:=Cur.Y+Y; end;
          B.CubicTo(X1, Y1, X2, Y2, X, Y);
          Cur := TVec2.Create(X, Y);
          LastCubicX := X2; LastCubicY := Y2; HasLastCubic := True; HasLastQuad := False;
        end;
      'S', 's':
        begin
          if HasLastCubic then begin X1 := Cur.X * 2 - LastCubicX; Y1 := Cur.Y * 2 - LastCubicY; end
          else begin X1 := Cur.X; Y1 := Cur.Y; end;
          if not TryParseFloat(AData, P, X2) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: S x2 missing');
          if not TryParseFloat(AData, P, Y2) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: S y2 missing');
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: S x missing');
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: S y missing');
          if Cmd = 's' then begin X2:=Cur.X+X2; Y2:=Cur.Y+Y2; X:=Cur.X+X; Y:=Cur.Y+Y; end;
          B.CubicTo(X1, Y1, X2, Y2, X, Y);
          Cur := TVec2.Create(X, Y);
          LastCubicX := X2; LastCubicY := Y2; HasLastCubic := True; HasLastQuad := False;
        end;
      'Q', 'q':
        begin
          if not TryParseFloat(AData, P, X1) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: Q x1 missing');
          if not TryParseFloat(AData, P, Y1) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: Q y1 missing');
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: Q x missing');
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: Q y missing');
          if Cmd = 'q' then begin X1:=Cur.X+X1; Y1:=Cur.Y+Y1; X:=Cur.X+X; Y:=Cur.Y+Y; end;
          B.QuadTo(X1, Y1, X, Y);
          Cur := TVec2.Create(X, Y);
          LastQuadX := X1; LastQuadY := Y1; HasLastQuad := True; HasLastCubic := False;
        end;
      'T', 't':
        begin
          if HasLastQuad then begin X1 := Cur.X * 2 - LastQuadX; Y1 := Cur.Y * 2 - LastQuadY; end
          else begin X1 := Cur.X; Y1 := Cur.Y; end;
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: T x missing');
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: T y missing');
          if Cmd = 't' then begin X:=Cur.X+X; Y:=Cur.Y+Y; end;
          B.QuadTo(X1, Y1, X, Y);
          Cur := TVec2.Create(X, Y);
          LastQuadX := X1; LastQuadY := Y1; HasLastQuad := True; HasLastCubic := False;
        end;
      'Z', 'z':
        begin
          B.Close;
          Cur := Start;
          HasLastCubic := False; HasLastQuad := False;
        end;
    else
      raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: unsupported command '+Cmd+' (only M/L/H/V/C/S/Q/T/Z)');
    end;
    // 防爆：点数+动词 cap 16384（点为主，动词同阈防爆）
    Need := B.PointCount;
    if (Need > 16384) or (B.VerbCount > 16384) then
      raise EVectorError.Create('nextpas.core.graphics.svg.pas: SvgPathFromData: point cap 16384 exceeded');
  end;
  Result := B.Build;
  if Result.IsEmpty and HasCur then
    // 至少有 Move 即非空，但 Build 可能空时补
    Result := B.Build;
end;

function TrySvgPathFromData(const AData: string; out APath: TPath): Boolean;
begin
  try
    APath := SvgPathFromData(AData);
    Result := True;
  except
    on E: EVectorError do begin APath := TPath.New; Result := False; end;
  end;
end;

end.
