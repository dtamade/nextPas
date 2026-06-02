unit nextpas.core.tui.text;

{**
 * @desc Span / Line / Text——ratatui 文本树原语，映射为 FreePascal record。
 *
 * ratatui 层级：
 *   Span : content + style              一段带样式的文本
 *   Line : spans + style + alignment    一行
 *   Text : lines + style + alignment    多行
 *
 * Pascal 映射：
 *   TSpan : record (Content + Style)
 *   TLine : record (Spans + Style + Alignment)
 *   TText : record (Lines + Style + Alignment)
 *
 * 宽度计算走 nextpas.core.text.width.StringDisplayWidth：纯 ASCII 快路径，
 * 非 ASCII 路径按 grapheme cluster 推进（组合标记/ZWJ/keycap/emoji 变体
 * 不拆列，东亚宽字符 2 列）。
 *
 * 样式由渲染层（TBlock/TParagraph/TList）遍历树时把各节点 Style patch 到
 * Span.Style 上——文本 record 只携带样式，不应用样式。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style;

type
  TAlignment = (caLeft, caCenter, caRight);

  TSpan = record
    Content: AnsiString;
    Style: TStyle;

    class function Raw(const AStr: AnsiString): TSpan; static;
    class function Styled(const AStr: AnsiString; const AStyle: TStyle): TSpan; static;
    { 快捷：带前景色的文本片段 }
    class function Colored(const AStr: AnsiString; const AColor: TColor): TSpan; static;
    { 快捷：加粗文本 }
    class function Bold(const AStr: AnsiString): TSpan; static;

    function Width: Integer;       { grapheme-aware 显示宽度 }
    function WithStyle(const AStyle: TStyle): TSpan;
  end;
  TSpans = array of TSpan;

  TLine = record
    Spans: TSpans;
    Style: TStyle;
    HasAlignment: Boolean;
    Alignment: TAlignment;

    class function Empty: TLine; static;
    class function FromString(const AStr: AnsiString): TLine; static;
    class function Raw(const AStr: AnsiString): TLine; static;
    class function Styled(const AStr: AnsiString; const AStyle: TStyle): TLine; static;
    class function FromSpans(const ASpans: array of TSpan): TLine; static;

    function Width: Integer;
    function WithStyle(const AStyle: TStyle): TLine;
    function WithAlignment(AAlignment: TAlignment): TLine;
  end;
  TLines = array of TLine;

  { 链式 TLine 构建器 }
  TLineBuilder = record
  private
    FSpans: TSpans;
    FCount: Integer;
  public
    class function Start: TLineBuilder; static;
    function Add(const AStr: AnsiString): TLineBuilder;
    function AddStyled(const AStr: AnsiString; const AStyle: TStyle): TLineBuilder;
    function AddColored(const AStr: AnsiString; const AColor: TColor): TLineBuilder;
    function AddBold(const AStr: AnsiString): TLineBuilder;
    function Build: TLine;
  end;

  TText = record
    Lines: TLines;
    Style: TStyle;
    HasAlignment: Boolean;
    Alignment: TAlignment;

    class function Empty: TText; static;
    class function FromString(const AStr: AnsiString): TText; static;
    class function FromLines(const ALines: array of TLine): TText; static;
    class function Raw(const AStr: AnsiString): TText; static;
    class function Styled(const AStr: AnsiString; const AStyle: TStyle): TText; static;

    function Width: Integer;        { 最大行宽 }
    function Height: Integer;       { 行数 }
    function WithStyle(const AStyle: TStyle): TText;
    function WithAlignment(AAlignment: TAlignment): TText;
  end;

implementation

uses
  nextpas.core.text.width;

{ TSpan }

class function TSpan.Raw(const AStr: AnsiString): TSpan;
begin
  Result.Content := AStr;
  Result.Style := TStyle.Default;
end;

class function TSpan.Styled(const AStr: AnsiString; const AStyle: TStyle): TSpan;
begin
  Result.Content := AStr;
  Result.Style := AStyle;
end;

function TSpan.Width: Integer;
begin
  Result := Integer(StringDisplayWidth(Content));
end;

function TSpan.WithStyle(const AStyle: TStyle): TSpan;
begin
  Result := Self;
  Result.Style := AStyle;
end;

class function TSpan.Colored(const AStr: AnsiString; const AColor: TColor): TSpan;
begin
  Result.Content := AStr;
  Result.Style := TStyle.Default;
  Result.Style.Fg := AColor;
end;

class function TSpan.Bold(const AStr: AnsiString): TSpan;
begin
  Result.Content := AStr;
  Result.Style := TStyle.Default;
  Result.Style.AddMod := [mbBold];
end;

{ TLine }

class function TLine.Empty: TLine;
begin
  Result.Spans := nil;
  Result.Style := TStyle.Default;
  Result.HasAlignment := False;
  Result.Alignment := caLeft;
end;

class function TLine.FromString(const AStr: AnsiString): TLine;
begin
  Result := Empty;
  SetLength(Result.Spans, 1);
  Result.Spans[0] := TSpan.Raw(AStr);
end;

class function TLine.Raw(const AStr: AnsiString): TLine;
begin
  Result := FromString(AStr);
end;

class function TLine.Styled(const AStr: AnsiString; const AStyle: TStyle): TLine;
begin
  Result := Empty;
  SetLength(Result.Spans, 1);
  Result.Spans[0] := TSpan.Styled(AStr, AStyle);
end;

class function TLine.FromSpans(const ASpans: array of TSpan): TLine;
var
  LI: Integer;
begin
  Result := Empty;
  SetLength(Result.Spans, System.Length(ASpans));
  for LI := 0 to System.High(ASpans) do
    Result.Spans[LI] := ASpans[LI];
end;

function TLine.Width: Integer;
var
  LI: Integer;
begin
  Result := 0;
  for LI := 0 to System.High(Spans) do
    Inc(Result, Spans[LI].Width);
end;

function TLine.WithStyle(const AStyle: TStyle): TLine;
begin
  Result := Self;
  Result.Style := AStyle;
end;

function TLine.WithAlignment(AAlignment: TAlignment): TLine;
begin
  Result := Self;
  Result.HasAlignment := True;
  Result.Alignment := AAlignment;
end;

{ TText }

class function TText.Empty: TText;
begin
  Result.Lines := nil;
  Result.Style := TStyle.Default;
  Result.HasAlignment := False;
  Result.Alignment := caLeft;
end;

{ 按 LF 分行，CRLF 视同 LF。仅 ASCII 控制处理——CR/LF 之外的控制字节
  原样透传（buffer 层写 cell 时会剥离控制字符，此处保持简单）。 }
class function TText.FromString(const AStr: AnsiString): TText;
var
  LI, LStart, LLineCount: Integer;
  LCh: Byte;
begin
  Result := Empty;

  { 两遍解析：先计数再物化，保持 SetLength 单次。 }
  LLineCount := 1;
  for LI := 1 to System.Length(AStr) do
    if AStr[LI] = #10 then Inc(LLineCount);
  SetLength(Result.Lines, LLineCount);

  LLineCount := 0;
  LStart := 1;
  LI := 1;
  while LI <= System.Length(AStr) do
  begin
    LCh := Byte(AStr[LI]);
    if LCh = 10 then
    begin
      { 去掉行尾 CR }
      if (LI - 1 >= LStart) and (AStr[LI - 1] = #13) then
        Result.Lines[LLineCount] := TLine.FromString(Copy(AStr, LStart, LI - 1 - LStart))
      else
        Result.Lines[LLineCount] := TLine.FromString(Copy(AStr, LStart, LI - LStart));
      Inc(LLineCount);
      LStart := LI + 1;
    end;
    Inc(LI);
  end;
  { 最后一行（若 S 以 LF 结尾则可能为空）。 }
  Result.Lines[LLineCount] := TLine.FromString(Copy(AStr, LStart, System.Length(AStr) - LStart + 1));
end;

class function TText.FromLines(const ALines: array of TLine): TText;
var
  LI: Integer;
begin
  Result := Empty;
  SetLength(Result.Lines, System.Length(ALines));
  for LI := 0 to System.High(ALines) do
    Result.Lines[LI] := ALines[LI];
end;

class function TText.Raw(const AStr: AnsiString): TText;
begin
  Result := FromString(AStr);
end;

class function TText.Styled(const AStr: AnsiString; const AStyle: TStyle): TText;
begin
  Result := FromString(AStr);
  Result.Style := AStyle;
end;

function TText.Width: Integer;
var
  LI, LW: Integer;
begin
  Result := 0;
  for LI := 0 to System.High(Lines) do
  begin
    LW := Lines[LI].Width;
    if LW > Result then Result := LW;
  end;
end;

function TText.Height: Integer;
begin
  Result := System.Length(Lines);
end;

function TText.WithStyle(const AStyle: TStyle): TText;
begin
  Result := Self;
  Result.Style := AStyle;
end;

function TText.WithAlignment(AAlignment: TAlignment): TText;
begin
  Result := Self;
  Result.HasAlignment := True;
  Result.Alignment := AAlignment;
end;

{ TLineBuilder }

class function TLineBuilder.Start: TLineBuilder;
begin
  Result.FSpans := nil;
  Result.FCount := 0;
end;

function TLineBuilder.Add(const AStr: AnsiString): TLineBuilder;
begin
  Result := Self;
  if Result.FCount >= Length(Result.FSpans) then
    SetLength(Result.FSpans, Result.FCount + 4);
  Result.FSpans[Result.FCount] := TSpan.Raw(AStr);
  Inc(Result.FCount);
end;

function TLineBuilder.AddStyled(const AStr: AnsiString; const AStyle: TStyle): TLineBuilder;
begin
  Result := Self;
  if Result.FCount >= Length(Result.FSpans) then
    SetLength(Result.FSpans, Result.FCount + 4);
  Result.FSpans[Result.FCount] := TSpan.Styled(AStr, AStyle);
  Inc(Result.FCount);
end;

function TLineBuilder.AddColored(const AStr: AnsiString; const AColor: TColor): TLineBuilder;
begin
  Result := Self;
  if Result.FCount >= Length(Result.FSpans) then
    SetLength(Result.FSpans, Result.FCount + 4);
  Result.FSpans[Result.FCount] := TSpan.Colored(AStr, AColor);
  Inc(Result.FCount);
end;

function TLineBuilder.AddBold(const AStr: AnsiString): TLineBuilder;
begin
  Result := Self;
  if Result.FCount >= Length(Result.FSpans) then
    SetLength(Result.FSpans, Result.FCount + 4);
  Result.FSpans[Result.FCount] := TSpan.Bold(AStr);
  Inc(Result.FCount);
end;

function TLineBuilder.Build: TLine;
begin
  Result := TLine.Empty;
  SetLength(Result.Spans, FCount);
  if FCount > 0 then
    Move(FSpans[0], Result.Spans[0], FCount * SizeOf(TSpan));
end;
end.
