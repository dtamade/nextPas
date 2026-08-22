unit nextpas.core.tui.ansi.parse;

{**
 * @desc 输入 ANSI 流 → 行模型（终端语义模拟）。
 *
 * 对照 grok-build `render_terminal_lines`（TermSink + vte Perform）：
 *   - \r 覆盖、\n/0x0b/0x0c 换行、\t 8 列停靠、BS 回退
 *   - CSI K（erase_line 0/1/2）、J（erase_display 0/2/3）、A/B/C/D/G 光标移动
 *   - SGR 全参数：16 色/亮色、256 色（38;5;n）、真彩（38;2;r;g;b）、
 *     修饰符（Bold/Dim/Italic/Underlined/Reversed 及关闭码）；冒号子参数
 *     归一为分号（38:5:n ≡ 38;5;n）
 *   - 行/列上限（MaxRows/MaxColumns）超出 clamp（对齐 grok MAX_ROWS/MAX_COLS）
 *   - 尾部「空格 + 基础样式」裁剪（对齐 grok row_to_line）
 *   - 尾部换行不产生空行（对齐 str::lines 语义）
 *
 * 差异（优于 grok）：UTF-8 按 grapheme 解码（宽字形占 2 列，对齐 TBuffer）；
 * 真彩不量化，保留 ckRgb（grok quantize 到 256 色）。
 * 输出样式为「列区间段」，消费方渲染时决定单元格细分。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.utils,
  nextpas.core.text.builder,
  nextpas.core.text.view,
  nextpas.core.tui.style,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier;

const
  ANSI_PARSE_DEFAULT_MAX_COLS = 200;
  ANSI_PARSE_DEFAULT_MAX_ROWS = 100000;

type
  { 一段连续同样式列区间（StartCol..StartCol+Len-1） }
  TAnsiLineSegment = record
    StartCol: Integer;
    Len: Integer;
    Style: TStyle;
  end;

  { 一行解析结果：纯文本 + 样式段（列 0 起） }
  TAnsiLine = record
    ColumnCount: Integer;                 { 逻辑列数（裁剪后） }
    Chars: AnsiString;                    { UTF-8 字符序列（按列序） }
    Segments: array of TAnsiLineSegment;
  end;
  TAnsiLineArray = array of TAnsiLine;

  TAnsiParseOptions = record
    MaxColumns: Integer;
    MaxRows: Integer;
    class function Create: TAnsiParseOptions; static;
  end;

{ 解析 AStr[0..ALen-1]（ANSI 字节流）→ 行模型。
  ABase：无样式（reset）基准；行尾裁剪也以它为基准。 }
function ParseAnsiLines(const AStr: PAnsiChar; ALen: Integer;
  const ABase: TStyle; const AOptions: TAnsiParseOptions): TAnsiLineArray;

{ AnsiString 便利重载 }
function ParseAnsiLines(const AStr: AnsiString;
  const ABase: TStyle; const AOptions: TAnsiParseOptions): TAnsiLineArray;

implementation

uses
  nextpas.core.text.utf8,
  nextpas.core.text.width,
  nextpas.core.text.grapheme;

const
  kCellMaxBytes = 4;
  kMaxCsiParams = 16;

type
  TAnsiCell = record
    Buf: array[0..kCellMaxBytes - 1] of Byte;
    Len: Byte;
    Width: Byte;
    Style: TStyle;
  end;
  TAnsiRow = array of TAnsiCell;
  TAnsiRowArray = array of TAnsiRow;

  TParsedRows = record
    Rows: TAnsiRowArray;
    Row: Integer;
    Col: Integer;
    MaxColumns: Integer;
    MaxRows: Integer;
    CurStyle: TStyle;
    BaseStyle: TStyle;
  end;

class function TAnsiParseOptions.Create: TAnsiParseOptions;
begin
  Result.MaxColumns := ANSI_PARSE_DEFAULT_MAX_COLS;
  Result.MaxRows := ANSI_PARSE_DEFAULT_MAX_ROWS;
end;

function CellBlank(const AStyle: TStyle): TAnsiCell;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Buf[0] := Byte(' ');
  Result.Len := 1;
  Result.Width := 1;
  Result.Style := AStyle;
end;

function StyleSame(const A, B: TStyle): Boolean;
begin
  Result := Compare(@A, @B, SizeOf(TStyle)) = 0;
end;

procedure RowEnsure(var P: TParsedRows);
begin
  if P.Row >= P.MaxRows then
    P.Row := P.MaxRows - 1;
  { 容量翻倍增长：避免逐行 realloc 的 O(n²) }
  if System.Length(P.Rows) <= P.Row then
    System.SetLength(P.Rows, P.Row * 2 + 16);
end;

{ 保证 P.Rows[P.Row] 有 ACol 列（0-based），新列填 blank }
procedure RowGrow(var P: TParsedRows; ACol: Integer);
var
  LOldLen, LI: Integer;
  LBlank: TAnsiCell;
begin
  LOldLen := System.Length(P.Rows[P.Row]);
  if LOldLen > ACol then
    Exit;
  System.SetLength(P.Rows[P.Row], ACol + 1);
  LBlank := CellBlank(P.BaseStyle);
  for LI := LOldLen to ACol do
    P.Rows[P.Row][LI] := LBlank;
end;

procedure PutGrapheme(var P: TParsedRows; const ABuf: PByte; ALen, AWidth: Integer);
var
  LCell: ^TAnsiCell;
begin
  if P.Col >= P.MaxColumns then
    Exit;
  RowEnsure(P);
  RowGrow(P, P.Col);
  LCell := @P.Rows[P.Row][P.Col];
  if ALen > kCellMaxBytes then
    ALen := kCellMaxBytes;
  System.Move(ABuf^, LCell^.Buf[0], ALen);
  LCell^.Len := ALen;
  if AWidth <= 0 then
    AWidth := 1;
  LCell^.Width := AWidth;
  LCell^.Style := P.CurStyle;
  Inc(P.Col, AWidth);
  if AWidth = 2 then
  begin
    { 宽字形：尾列写 skip 标记（Len=0），Chars 拼接跳过；对齐 TBuffer 模型 }
    if P.Col < P.MaxColumns then
    begin
      RowGrow(P, P.Col - 1);
      LCell := @P.Rows[P.Row][P.Col - 1];
      FillChar(LCell^, SizeOf(LCell^), 0);
      LCell^.Style := P.CurStyle;
    end;
  end;
end;

{ ASCII 可见字符批量落 cell（一次 RowGrow 扩到位），避开逐字符 SetLength +
  GraphemeNext 的 UTF-8 解码/宽度表开销——工具输出以 ASCII 为主，热路径。 }
procedure PutAsciiRun(var P: TParsedRows; ABuf: PByte; ACount: Integer);
var
  LCol, LI: Integer;
  LCell: ^TAnsiCell;
begin
  if ACount <= 0 then
    Exit;
  if P.Col + ACount > P.MaxColumns then
    ACount := P.MaxColumns - P.Col;
  if ACount <= 0 then
    Exit;
  RowEnsure(P);
  RowGrow(P, P.Col + ACount - 1);
  LCol := P.Col;
  LI := 0;
  while LI < ACount do
  begin
    LCell := @P.Rows[P.Row][LCol];
    LCell^.Buf[0] := ABuf[LI];
    LCell^.Len := 1;
    LCell^.Width := 1;
    LCell^.Style := P.CurStyle;
    Inc(LCol);
    Inc(LI);
  end;
  P.Col := LCol;
end;

procedure Newline(var P: TParsedRows);
begin
  Inc(P.Row);
  P.Col := 0;
  RowEnsure(P);
end;

procedure EraseLine(var P: TParsedRows; AMode: Integer);
var
  LBlank: TAnsiCell;
  LI, LEnd: Integer;
begin
  RowEnsure(P);
  LBlank := CellBlank(P.BaseStyle);
  case AMode of
    0:
      if System.Length(P.Rows[P.Row]) > P.Col then
        System.SetLength(P.Rows[P.Row], P.Col);
    1:
      begin
        LEnd := System.Length(P.Rows[P.Row]);
        if LEnd > P.Col + 1 then
          LEnd := P.Col + 1;
        for LI := 0 to LEnd - 1 do
          P.Rows[P.Row][LI] := LBlank;
      end;
    2:
      System.SetLength(P.Rows[P.Row], 0);
  end;
end;

procedure EraseDisplay(var P: TParsedRows; AMode: Integer);
begin
  case AMode of
    0:
      begin
        RowEnsure(P);
        if System.Length(P.Rows[P.Row]) > P.Col then
          System.SetLength(P.Rows[P.Row], P.Col);
        System.SetLength(P.Rows, P.Row + 1);
      end;
    2, 3:
      begin
        System.SetLength(P.Rows, 1);
        P.Rows[0] := nil;
        P.Row := 0;
        P.Col := 0;
      end;
  end;
end;

procedure ApplySgr(var P: TParsedRows; const AParams: array of Integer;
  ACount: Integer);
var
  I: Integer;
  LCode: Integer;
begin
  if ACount <= 0 then
  begin
    P.CurStyle := P.BaseStyle;
    Exit;
  end;
  I := 0;
  while I < ACount do
  begin
    LCode := AParams[I];
    case LCode of
      0: P.CurStyle := P.BaseStyle;
      1: P.CurStyle.AddMod := P.CurStyle.AddMod + [mbBold];
      2: P.CurStyle.AddMod := P.CurStyle.AddMod + [mbDim];
      3: P.CurStyle.AddMod := P.CurStyle.AddMod + [mbItalic];
      4: P.CurStyle.AddMod := P.CurStyle.AddMod + [mbUnderlined];
      7: P.CurStyle.AddMod := P.CurStyle.AddMod + [mbReversed];
      22: P.CurStyle.AddMod := P.CurStyle.AddMod - [mbBold, mbDim];
      23: P.CurStyle.AddMod := P.CurStyle.AddMod - [mbItalic];
      24: P.CurStyle.AddMod := P.CurStyle.AddMod - [mbUnderlined];
      27: P.CurStyle.AddMod := P.CurStyle.AddMod - [mbReversed];
      30..37: P.CurStyle.Fg := IndexedColor(LCode - 30);
      39: P.CurStyle.Fg := P.BaseStyle.Fg;
      40..47: P.CurStyle.Bg := IndexedColor(LCode - 40);
      49: P.CurStyle.Bg := P.BaseStyle.Bg;
      90..97: P.CurStyle.Fg := IndexedColor(LCode - 90 + 8);
      100..107: P.CurStyle.Bg := IndexedColor(LCode - 100 + 8);
      38, 48:
        if (I + 1 < ACount) and (AParams[I + 1] = 5) and (I + 2 < ACount) then
        begin
          if LCode = 38 then
            P.CurStyle.Fg := IndexedColor(AParams[I + 2])
          else
            P.CurStyle.Bg := IndexedColor(AParams[I + 2]);
          Inc(I, 2);
        end
        else if (I + 1 < ACount) and (AParams[I + 1] = 2) and (I + 4 < ACount) then
        begin
          if LCode = 38 then
            P.CurStyle.Fg := RgbColor(AParams[I + 2], AParams[I + 3], AParams[I + 4])
          else
            P.CurStyle.Bg := RgbColor(AParams[I + 2], AParams[I + 3], AParams[I + 4]);
          Inc(I, 4);
        end;
    end;
    Inc(I);
  end;
end;

{ 归一化 CSI 参数：分号/冒号/问号前缀统一；`:` 当 `;`（38:5:n ≡ 38;5;n） }
procedure CollectCsiParams(const AText: PAnsiChar; AStart, ALen: Integer;
  var AParams: array of Integer; var ACount: Integer);
var
  I: Integer;
  LVal: Integer;
begin
  ACount := 0;
  LVal := 0;
  for I := AStart to AStart + ALen - 1 do
  begin
    case AText[I] of
      '0'..'9':
        LVal := LVal * 10 + (Ord(AText[I]) - 48);
      ';', ':':
        begin
          if ACount < System.Length(AParams) then
            AParams[ACount] := LVal;
          Inc(ACount);
          LVal := 0;
        end;
    end;
  end;
  if ACount < System.Length(AParams) then
    AParams[ACount] := LVal;
  Inc(ACount);
end;

function ParseAnsiLines(const AStr: PAnsiChar; ALen: Integer;
  const ABase: TStyle; const AOptions: TAnsiParseOptions): TAnsiLineArray;
var
  P: TParsedRows;
  I: Integer;
  LGR: TGraphemeResult;
  LState: Integer;
  LCsiStart: Integer;
  LParams: array[0..kMaxCsiParams - 1] of Integer;
  LParamCount: Integer;
  LArg: Integer;
  LRow, LCol, LEnd, LI: Integer;
  LSegStart: Integer;
  LSegStyle: TStyle;
  LSegments: array of TAnsiLineSegment;
  LSegCount: Integer;
  LOutCount, LOutCap: Integer;
  LSB: TStringBuilder;
begin
  LCsiStart := 0;
  Result := nil;
  System.SetLength(Result, 0);
  if ALen <= 0 then
    Exit;

  P.MaxColumns := AOptions.MaxColumns;
  if P.MaxColumns <= 0 then
    P.MaxColumns := ANSI_PARSE_DEFAULT_MAX_COLS;
  P.MaxRows := AOptions.MaxRows;
  if P.MaxRows <= 0 then
    P.MaxRows := ANSI_PARSE_DEFAULT_MAX_ROWS;
  P.Rows := nil;
  P.Row := 0;
  P.Col := 0;
  P.BaseStyle := ABase;
  P.CurStyle := ABase;
  RowEnsure(P);

  LState := 0;   { 0=ground 1=esc 2=csi 3=osc }
  I := 0;
  while I < ALen do
  begin
    case LState of
      0:
        case AStr[I] of
          #27:
            begin
              LState := 1;
              Inc(I);
            end;
          #10, #11, #12:
            begin
              Newline(P);
              Inc(I);
            end;
          #13:
            begin
              P.Col := 0;
              Inc(I);
            end;
          #9:
            begin
              P.Col := (P.Col div 8 + 1) * 8;
              if P.Col > P.MaxColumns then
                P.Col := P.MaxColumns;
              Inc(I);
            end;
          #8:
            begin
              if P.Col > 0 then
                Dec(P.Col);
              Inc(I);
            end;
          #0..#7, #14..#26, #28..#31, #127:
            Inc(I);
          else
            if (Byte(AStr[I]) >= $20) and (Byte(AStr[I]) < $7F) then
            begin
              { ASCII 快速路径：批量扫描可见字符段（控制字符已单独处理） }
              LI := I;
              while (LI < ALen) and (Byte(AStr[LI]) >= $20) and
                    (Byte(AStr[LI]) < $7F) do
                Inc(LI);
              PutAsciiRun(P, PByte(@AStr[I]), LI - I);
              I := LI;
            end
            else
            begin
              LGR := GraphemeNext(PByte(@AStr[I]), ALen - I);
              if LGR.ByteLen <= 0 then
                Inc(I)
              else
              begin
                PutGrapheme(P, PByte(@AStr[I]), LGR.ByteLen, LGR.Width);
                Inc(I, LGR.ByteLen);
              end;
            end;
        end;
      1:
        case AStr[I] of
          '[':
            begin
              LCsiStart := I + 1;
              LState := 2;
              Inc(I);
            end;
          ']':
            begin
              LState := 3;
              Inc(I);
            end;
          else
            begin
              LState := 0;
              Inc(I);
            end;
        end;
      2:
        if AStr[I] in ['@', 'a'..'z', 'A'..'Z'] then
        begin
          CollectCsiParams(AStr, LCsiStart, I - LCsiStart, LParams, LParamCount);
          LArg := 0;
          if LParamCount > 0 then
            LArg := LParams[0];
          case AStr[I] of
            'm':
              ApplySgr(P, LParams, LParamCount);
            'K':
              EraseLine(P, LArg);
            'J':
              EraseDisplay(P, LArg);
            'A':
              begin
                if LArg = 0 then LArg := 1;
                if P.Row >= LArg then
                  Dec(P.Row, LArg)
                else
                  P.Row := 0;
              end;
            'B':
              begin
                if LArg = 0 then LArg := 1;
                Inc(P.Row, LArg);
                if P.Row >= System.Length(P.Rows) then
                  P.Row := System.Length(P.Rows) - 1;
              end;
            'C':
              begin
                if LArg = 0 then LArg := 1;
                Inc(P.Col, LArg);
                if P.Col > P.MaxColumns then
                  P.Col := P.MaxColumns;
              end;
            'D':
              begin
                if LArg = 0 then LArg := 1;
                if P.Col >= LArg then
                  Dec(P.Col, LArg)
                else
                  P.Col := 0;
              end;
            'G':
              begin
                if LArg > 0 then
                  Dec(LArg);
                if LArg > P.MaxColumns then
                  LArg := P.MaxColumns;
                P.Col := LArg;
              end;
          end;
          LState := 0;
          Inc(I);
        end
        else if AStr[I] in ['0'..'9', ';', ':', '?', ' ', '!', '"', '#', '$',
          '%', '&', '''', '(', ')', '*', '+', ',', '-', '.', '/', '<', '=', '>'] then
          Inc(I)
        else
        begin
          LState := 0;
          Inc(I);
        end;
      3:
        if (AStr[I] = #7) or
           ((AStr[I] = #27) and (I + 1 < ALen) and (AStr[I + 1] = #92)) then
        begin
          LState := 0;
          Inc(I);
          if (I > 0) and (AStr[I - 1] = #27) and (I < ALen) then
            Inc(I);
        end
        else
          Inc(I);
    end;
  end;

  { finish：尾部空行裁剪（尾部换行不产生空行） }
  while (System.Length(P.Rows) > 0) and
        (System.Length(P.Rows[System.Length(P.Rows) - 1]) = 0) do
    System.SetLength(P.Rows, System.Length(P.Rows) - 1);

  LSB.Init(256);
  LOutCount := 0;
  LOutCap := 0;
  for LRow := 0 to System.Length(P.Rows) - 1 do
  begin
    LEnd := System.Length(P.Rows[LRow]);
    while (LEnd > 0) and
          (P.Rows[LRow][LEnd - 1].Width = 1) and
          (P.Rows[LRow][LEnd - 1].Buf[0] = Byte(' ')) and
          StyleSame(P.Rows[LRow][LEnd - 1].Style, P.BaseStyle) do
      Dec(LEnd);

    LSB.Clear;
    LSegments := nil;
    LSegCount := 0;
    if LEnd > 0 then
    begin
      LSegStart := 0;
      LSegStyle := P.Rows[LRow][0].Style;
      for LCol := 0 to LEnd - 1 do
      begin
        if P.Rows[LRow][LCol].Len = 0 then
          Continue;   { 宽字形 skip 尾列：不产出文本/段 }
        if not StyleSame(P.Rows[LRow][LCol].Style, LSegStyle) then
        begin
          if LSegCount = System.Length(LSegments) then
            System.SetLength(LSegments, LSegCount + 8);
          LSegments[LSegCount].StartCol := LSegStart;
          LSegments[LSegCount].Len := LCol - LSegStart;
          LSegments[LSegCount].Style := LSegStyle;
          Inc(LSegCount);
          LSegStart := LCol;
          LSegStyle := P.Rows[LRow][LCol].Style;
        end;
        LSB.AppendView(TStringView.Create(@P.Rows[LRow][LCol].Buf[0], P.Rows[LRow][LCol].Len));
      end;
      if LSegCount = System.Length(LSegments) then
        System.SetLength(LSegments, LSegCount + 8);
      LSegments[LSegCount].StartCol := LSegStart;
      LSegments[LSegCount].Len := LEnd - LSegStart;
      LSegments[LSegCount].Style := LSegStyle;
      Inc(LSegCount);
    end;

    { 输出数组容量翻倍：避免逐行 realloc 的 O(n²) }
    if LOutCount >= LOutCap then
    begin
      LOutCap := LOutCap * 2 + 16;
      System.SetLength(Result, LOutCap);
    end;
    Result[LOutCount].ColumnCount := LEnd;
    Result[LOutCount].Chars := LSB.ToString;
    Result[LOutCount].Segments := LSegments;
    System.SetLength(Result[LOutCount].Segments, LSegCount);
    Inc(LOutCount);
  end;
  System.SetLength(Result, LOutCount);
  LSB.Done;
end;

function ParseAnsiLines(const AStr: AnsiString;
  const ABase: TStyle; const AOptions: TAnsiParseOptions): TAnsiLineArray;
begin
  Result := ParseAnsiLines(PAnsiChar(AStr), System.Length(AStr), ABase, AOptions);
end;

end.
