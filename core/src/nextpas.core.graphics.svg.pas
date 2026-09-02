{**
 * nextpas.core.graphics.svg - 最小 SvgImport (S3 预留闭环)
 * 仅解析 SVG path data (d="M x y L x y C ... Z")，M/L/H/V/C/Q/Z 子集，单精度 Single 外部。
 * L2，仅依 graphics.base/path + text 扫描，不依赖 xml/html/dom，避免 L2→L2 循环。
 * 完整性：后续可扩展 arc(A) 与 transform，在此薄层上增量；当前满足 directui 图标矢量导入最小闭环。
 * 稳定性：空串/非法字符抛 EVectorError，数值溢出/NaN 守卫，cap 16384 点防爆。
 * 复用：复用 TPathBuilder 批量 O(N)，不自研字符串扫描，复用 text.conv TryStrToFloat 单源。
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

function TryParseFloat(const S: string; var P: Integer; out V: Single): Boolean;
var
  Start, Len: Integer;
  Sub: string;
  D: Double;
begin
  if not SkipWs(S, P) then Exit(False);
  Start := P;
  // optional sign
  if (P <= Length(S)) and (S[P] in ['+', '-']) then Inc(P);
  // digits / dot
  while (P <= Length(S)) and (S[P] in ['0'..'9', '.', 'e', 'E', '+', '-']) do Inc(P);
  Len := P - Start;
  if Len <= 0 then Exit(False);
  Sub := Copy(S, Start, Len);
  // text.conv 单源
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
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('SvgPathFromData: M x missing');
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('SvgPathFromData: M y missing');
          if Cmd = 'm' then begin X := Cur.X + X; Y := Cur.Y + Y; end;
          B.MoveTo(X, Y);
          Cur := TVec2.Create(X, Y); Start := Cur; HasCur := True;
          // 后续隐式 L
          LastCmd := 'L';
          if Cmd = 'm' then LastCmd := 'l';
        end;
      'L', 'l':
        begin
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('SvgPathFromData: L x missing');
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('SvgPathFromData: L y missing');
          if Cmd = 'l' then begin X := Cur.X + X; Y := Cur.Y + Y; end;
          B.LineTo(X, Y);
          Cur := TVec2.Create(X, Y);
        end;
      'H', 'h':
        begin
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('SvgPathFromData: H x missing');
          if Cmd = 'h' then X := Cur.X + X;
          B.LineTo(X, Cur.Y);
          Cur := TVec2.Create(X, Cur.Y);
        end;
      'V', 'v':
        begin
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('SvgPathFromData: V y missing');
          if Cmd = 'v' then Y := Cur.Y + Y;
          B.LineTo(Cur.X, Y);
          Cur := TVec2.Create(Cur.X, Y);
        end;
      'C', 'c':
        begin
          if not TryParseFloat(AData, P, X1) then raise EVectorError.Create('C x1');
          if not TryParseFloat(AData, P, Y1) then raise EVectorError.Create('C y1');
          if not TryParseFloat(AData, P, X2) then raise EVectorError.Create('C x2');
          if not TryParseFloat(AData, P, Y2) then raise EVectorError.Create('C y2');
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('C x');
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('C y');
          if Cmd = 'c' then begin X1:=Cur.X+X1; Y1:=Cur.Y+Y1; X2:=Cur.X+X2; Y2:=Cur.Y+Y2; X:=Cur.X+X; Y:=Cur.Y+Y; end;
          B.CubicTo(X1, Y1, X2, Y2, X, Y);
          Cur := TVec2.Create(X, Y);
        end;
      'Q', 'q':
        begin
          if not TryParseFloat(AData, P, X1) then raise EVectorError.Create('Q x1');
          if not TryParseFloat(AData, P, Y1) then raise EVectorError.Create('Q y1');
          if not TryParseFloat(AData, P, X) then raise EVectorError.Create('Q x');
          if not TryParseFloat(AData, P, Y) then raise EVectorError.Create('Q y');
          if Cmd = 'q' then begin X1:=Cur.X+X1; Y1:=Cur.Y+Y1; X:=Cur.X+X; Y:=Cur.Y+Y; end;
          B.QuadTo(X1, Y1, X, Y);
          Cur := TVec2.Create(X, Y);
        end;
      'Z', 'z':
        begin
          B.Close;
          Cur := Start;
        end;
    else
      raise EVectorError.Create('SvgPathFromData: unsupported command '+Cmd+' (only M/L/H/V/C/Q/Z)');
    end;
    // 防爆：点数 cap
    Need := B.PointCount;
    if Need > 16384 then
      raise EVectorError.Create('SvgPathFromData: point cap 16384 exceeded');
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
