{**
 * nextpas.core.graphics.text - 文本薄层产 TGlyphRun（Scale 打通 window/gpu.canvas）
 * 不直依 font，仅排版度量占位；真实字形由 font 层注入，此处保持高级感接口稳定。
 *}
unit nextpas.core.graphics.text;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.graphics.base;

type
  TTextLayout = record
    Text: AnsiString;
    FontSize: Single;
    Scale: Single; // DisplayScale
    MaxWidth: Single; // 0=无限
    GlyphRun: TGlyphRun;
    Bounds: TRect;
  end;

function LayoutText(const AText: AnsiString; AFontSize, AScale: Single): TTextLayout;
function LayoutTextWrapped(const AText: AnsiString; AFontSize, AScale, AMaxWidth: Single): TTextLayout;

implementation

function LayoutText(const AText: AnsiString; AFontSize, AScale: Single): TTextLayout;
var
  I, N: Integer;
  X: Single;
begin
  Result.Text := AText;
  Result.FontSize := AFontSize;
  Result.Scale := AScale;
  Result.MaxWidth := 0;
  N := Length(AText);
  SetLength(Result.GlyphRun.Glyphs, N);
  SetLength(Result.GlyphRun.Positions, N);
  Result.GlyphRun.Scale := AScale;
  X := 0;
  for I := 0 to N-1 do
  begin
    Result.GlyphRun.Glyphs[I] := Byte(AText[I+1]);
    Result.GlyphRun.Positions[I] := TVec2.Create(X, 0);
    X := X + AFontSize * 0.6 * AScale; // 等宽占位
  end;
  Result.Bounds := TRect.From(0, 0, X, AFontSize * AScale);
end;

function LayoutTextWrapped(const AText: AnsiString; AFontSize, AScale, AMaxWidth: Single): TTextLayout;
begin
  Result := LayoutText(AText, AFontSize, AScale);
  Result.MaxWidth := AMaxWidth;
  // S2+ 真实换行：当前直通占位，保持 API 高级感
end;

end.
