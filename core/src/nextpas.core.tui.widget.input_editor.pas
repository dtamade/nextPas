unit nextpas.core.tui.widget.input_editor;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.text.width, nextpas.core.text.utf8,
  nextpas.core.tui.event,
  nextpas.core.tui.widget.syntax,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.intf;

type
  TEditorSnapshot = record
    Text: AnsiString;
    CurByte: Integer;
    Anchor: Integer;
  end;

  { 查找命中区间(字节偏移,含长度);SetFindHits 渲染高亮用 }
  TFindHit = record
    Start, Len: Integer;
  end;
  TFindHits = array of TFindHit;

  IInputEditor = interface(IWidget)
    ['{D4E5F6A7-B8C9-4D0E-1F2A-3B4C5D6E7F80}']
    function HandleKey(const K: TKeyEvent): Boolean;
    procedure InsertChar(Cp: LongWord);
    procedure InsertNewline;
    procedure DeleteBackward;
    procedure DeleteForward;
    procedure DeleteWordBackward;
    procedure DeleteWordForward;
    procedure MoveLeft;
    procedure MoveRight;
    procedure MoveUp;
    procedure MoveDown;
    procedure MoveHome;
    procedure MoveEnd;
    procedure MoveWordLeft;
    procedure MoveWordRight;
    procedure SelectAll;
    procedure CopySelection;
    procedure CutSelection;
    procedure Paste;
    procedure PasteText(const AText: AnsiString);
    { 选区读写(宿主剪贴板集成用:系统剪贴板复制/剪切选区;
      DeleteSelected 入撤销栈,一次 Undo 恢复) }
    function HasSelection: Boolean;
    function SelectedText: AnsiString;
    procedure DeleteSelected;
    procedure DeleteLine;
    procedure Undo;
    procedure Redo;
    procedure Clear;
    { 整文替换（单 undo 操作：一次 Undo 恢复替换前全文与光标；
      供 AI 补全/提示词优化等一次性回填，避免逐字符插入污染撤销栈） }
    procedure ReplaceContent(const AText: AnsiString; ACaret: Integer);
    function Content: AnsiString;
    function IsEmpty: Boolean;
    function LineCount: Integer;
    function CursorRow: Integer;  { 光标所在绝对行（0-based，与滚动无关） }
    function CursorScreenPos(const AArea: TRect): TPosition;
    { 定位到字节偏移:仅移动光标(清选区/目标列),不进撤销栈(查找跳转等) }
    procedure MoveTo(const ABufOffset: Integer);
    { 屏幕坐标 → 文本字节偏移(含滚动行换算;越界 clamp 到最近位置)。
      供鼠标点击定位光标:先 ByteOffsetAt 再 MoveTo }
    function ByteOffsetAt(const AArea: TRect; AX, AY: Integer): Integer;
    { 查找命中高亮:全部命中用 AStyle、当前命中(ACur 下标)用 ACurStyle,
      独立于选区样式;Render 内叠加绘制 }
    procedure SetFindHits(const AHits: array of TFindHit; ACur: Integer;
      const AStyle, ACurStyle: TStyle);
    function WithTextStyle(const S: TStyle): IInputEditor;
    function WithPlaceholderStyle(const S: TStyle): IInputEditor;
    function WithSelectionStyle(const S: TStyle): IInputEditor;
    function WithPlaceholder(const P: AnsiString): IInputEditor;
    function WithMaxLines(N: Integer): IInputEditor;
    { 布局配置面（PH33 P2b，additive）：块包装 }
    function WithBlock(ABlock: IBlock): IInputEditor;
    { 行号 gutter 开关（PH33 P5a，additive）：默认关=既有行为逐字节不变 }
    function WithLineNumbers(AOn: Boolean): IInputEditor;
    procedure SetHighlighter(AHL: IHighlighter; const ATheme: TSyntaxTheme);
  end;

  TInputEditor = class(TInterfacedObject, IWidget, IInputEditor)
  private
    FText: AnsiString;
    FCurByte: Integer;
    FTargetCol: Integer;
    FMaxLines: Integer;
    FLineNumbers: Boolean;
    FScrollRow: Integer;
    FAnchor: Integer;
    FUndoStack: array of TEditorSnapshot;
    FUndoCount: Integer;
    FRedoStack: array of TEditorSnapshot;
    FRedoCount: Integer;
    FClipboard: AnsiString;
    FHighlighter: IHighlighter;
    FSyntaxDoc: TSyntaxDoc;
    FSyntaxTheme: TSyntaxTheme;
    FTextStyle: TStyle;
    FPlaceholderStyle: TStyle;
    FSelectionStyle: TStyle;
    FPlaceholder: AnsiString;
    FFindHits: TFindHits;      { 查找命中缓存(SetFindHits 刷新;Render 只读) }
    FFindCur: Integer;         { 当前命中下标(-1 无) }
    FFindStyle: TStyle;        { 非当前命中高亮 }
    FFindCurStyle: TStyle;     { 当前命中高亮(可加粗区分) }
    FBlock: IBlock;            { PH33 P2b：块包装(nil=无块) }

    procedure RenderContent(const AArea: TRect; ABuffer: TBuffer);
    function LineCount_: Integer;
    procedure CursorToRowCol(out Row, Col: Integer);
    function RowColToByte(Row, Col: Integer): Integer;
    function LineStartByte(Row: Integer): Integer;
    function LineEndByte(Row: Integer): Integer;
    function LineWidth(Row: Integer): Integer;
    procedure EnsureCursorVisible(VisibleHeight: Integer);
    function PrevGraphemeByte: Integer;
    function NextGraphemeByte: Integer;

    procedure ClearSelection; inline;
    procedure SelectionRange(out SelStart, SelEnd: Integer);
    procedure CollapseSelectionToStart;
    procedure CollapseSelectionToEnd;
    procedure DeleteSelection;

    procedure PushUndo;
    function IsWordByte(B: Byte): Boolean; inline;
    function PrevWordBoundary: Integer;
    function NextWordBoundary: Integer;
    procedure MoveLeftInternal(Selecting: Boolean);
    procedure MoveRightInternal(Selecting: Boolean);
    procedure MoveUpInternal(Selecting: Boolean);
    procedure MoveDownInternal(Selecting: Boolean);
    procedure MoveHomeInternal(Selecting: Boolean);
    procedure MoveEndInternal(Selecting: Boolean);
    procedure MoveWordLeftInternal(Selecting: Boolean);
    procedure MoveWordRightInternal(Selecting: Boolean);
    procedure NotifySyntaxEdit;
    procedure GetLineForSyntax(LineIndex: Integer; out P: PAnsiChar; out Len: Integer);
  public
    class function New: IInputEditor; static;
    class function NewWithMaxLines(AMax: Integer): IInputEditor; static;
    destructor Destroy; override;

    function HandleKey(const K: TKeyEvent): Boolean;
    procedure InsertChar(Cp: LongWord);
    procedure InsertNewline;
    procedure DeleteBackward;
    procedure DeleteForward;
    procedure DeleteWordBackward;
    procedure DeleteWordForward;
    procedure MoveLeft;
    procedure MoveRight;
    procedure MoveUp;
    procedure MoveDown;
    procedure MoveHome;
    procedure MoveEnd;
    procedure MoveWordLeft;
    procedure MoveWordRight;

    procedure SelectAll;
    procedure CopySelection;
    procedure CutSelection;
    procedure Paste;
    procedure PasteText(const AText: AnsiString);
    function HasSelection: Boolean; inline;
    function SelectedText: AnsiString;
    procedure DeleteSelected;
    procedure DoPaste(const AText: AnsiString);
    procedure DeleteLine;
    procedure Undo;
    procedure Redo;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);

    function CursorScreenPos(const AArea: TRect): TPosition;

    procedure Clear;
    procedure ReplaceContent(const AText: AnsiString; ACaret: Integer);
    function Content: AnsiString;
    function IsEmpty: Boolean; inline;
    function LineCount: Integer; inline;
    function CursorRow: Integer;
    procedure MoveTo(const ABufOffset: Integer);
    function ByteOffsetAt(const AArea: TRect; AX, AY: Integer): Integer;
    procedure SetFindHits(const AHits: array of TFindHit; ACur: Integer;
      const AStyle, ACurStyle: TStyle);

    function WithTextStyle(const S: TStyle): IInputEditor;
    function WithPlaceholderStyle(const S: TStyle): IInputEditor;
    function WithSelectionStyle(const S: TStyle): IInputEditor;
    function WithPlaceholder(const P: AnsiString): IInputEditor;
    function WithMaxLines(N: Integer): IInputEditor;
    function WithBlock(ABlock: IBlock): IInputEditor;
    function WithLineNumbers(AOn: Boolean): IInputEditor;
    procedure SetHighlighter(AHL: IHighlighter; const ATheme: TSyntaxTheme);
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.grapheme;

type
  TEditorAdv = record ByteLen, Width: Integer; Codepoint: UInt32; end;

{ PH33 P5a：gutter 宽=max(最大行号位数+1,3)——RenderContent 绘制与
  CursorScreenPos 光标换算共用，两处口径必须一致 }
function EditorGutW(ALineCount: Integer): Integer; inline;
begin
  Result := Length(IntToStr(ALineCount)) + 1;
  if Result < 3 then Result := 3;
end;

function EditorGraphemeAt(const ABuf; ALen, AOffset: Integer): TEditorAdv; inline;
var LGR: TGraphemeResult; LDec: TUTF8DecodeResult;
begin
  LGR := GraphemeNext(@PByte(@ABuf)[AOffset], ALen - AOffset);
  Result.ByteLen := LGR.ByteLen;
  Result.Width := LGR.Width;
  LDec := UTF8Decode(@PByte(@ABuf)[AOffset], ALen - AOffset);
  if LDec.ByteLen > 0 then Result.Codepoint := LDec.CodePoint
  else Result.Codepoint := $FFFD;
end;

const
  UNDO_MAX = 100;

function Ucs4ToUtf8(Cp: LongWord): AnsiString;
begin
  if Cp < $80 then begin SetLength(Result, 1); Result[1] := AnsiChar(Cp); end
  else if Cp < $800 then begin SetLength(Result, 2); Result[1] := AnsiChar($C0 or (Cp shr 6)); Result[2] := AnsiChar($80 or (Cp and $3F)); end
  else if Cp < $10000 then begin SetLength(Result, 3); Result[1] := AnsiChar($E0 or (Cp shr 12)); Result[2] := AnsiChar($80 or ((Cp shr 6) and $3F)); Result[3] := AnsiChar($80 or (Cp and $3F)); end
  else begin SetLength(Result, 4); Result[1] := AnsiChar($F0 or (Cp shr 18)); Result[2] := AnsiChar($80 or ((Cp shr 12) and $3F)); Result[3] := AnsiChar($80 or ((Cp shr 6) and $3F)); Result[4] := AnsiChar($80 or (Cp and $3F)); end;
end;

{ TInputEditor }

class function TInputEditor.New: IInputEditor;
var LSelf: TInputEditor;
begin
  LSelf := TInputEditor.Create;
  LSelf.FText := '';
  LSelf.FCurByte := 0;
  LSelf.FTargetCol := -1;
  LSelf.FMaxLines := 4;
  LSelf.FScrollRow := 0;
  LSelf.FAnchor := -1;
  SetLength(LSelf.FUndoStack, UNDO_MAX);
  LSelf.FUndoCount := 0;
  SetLength(LSelf.FRedoStack, UNDO_MAX);
  LSelf.FRedoCount := 0;
  LSelf.FClipboard := '';
  LSelf.FTextStyle := TStyle.Default;
  LSelf.FPlaceholderStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  LSelf.FSelectionStyle := TStyle.Default.WithModifier([mbReversed]);
  LSelf.FPlaceholder := '';
  LSelf.FFindCur := -1;
  Result := LSelf;
end;

class function TInputEditor.NewWithMaxLines(AMax: Integer): IInputEditor;
var LSelf: TInputEditor;
begin
  LSelf := TInputEditor.Create;
  LSelf.FText := '';
  LSelf.FCurByte := 0;
  LSelf.FTargetCol := -1;
  LSelf.FMaxLines := AMax;
  LSelf.FScrollRow := 0;
  LSelf.FAnchor := -1;
  SetLength(LSelf.FUndoStack, UNDO_MAX);
  LSelf.FUndoCount := 0;
  SetLength(LSelf.FRedoStack, UNDO_MAX);
  LSelf.FRedoCount := 0;
  LSelf.FClipboard := '';
  LSelf.FTextStyle := TStyle.Default;
  LSelf.FPlaceholderStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  LSelf.FSelectionStyle := TStyle.Default.WithModifier([mbReversed]);
  LSelf.FPlaceholder := '';
  LSelf.FFindCur := -1;
  Result := LSelf;
end;

destructor TInputEditor.Destroy;
begin
  FSyntaxDoc.Free;
  inherited Destroy;
end;

function TInputEditor.LineCount_: Integer;
var I: Integer;
begin
  Result := 1;
  for I := 1 to Length(FText) do
    if FText[I] = #10 then Inc(Result);
end;

function TInputEditor.LineCount: Integer;
begin
  Result := LineCount_;
end;

function TInputEditor.CursorRow: Integer;
var Row, Col: Integer;
begin
  { 绝对行：复用内部 CursorToRowCol（仅依赖 FCurByte/FText，不经过
    FScrollRow——滚动后依然准确）。0-based，与行内逻辑一致。 }
  CursorToRowCol(Row, Col);
  Result := Row;
end;

function TInputEditor.IsEmpty: Boolean;
begin
  Result := Length(FText) = 0;
end;

function TInputEditor.Content: AnsiString;
begin
  Result := FText;
end;

procedure TInputEditor.Clear;
begin
  FText := '';
  FCurByte := 0;
  FTargetCol := -1;
  FScrollRow := 0;
  FAnchor := -1;
end;

procedure TInputEditor.ReplaceContent(const AText: AnsiString; ACaret: Integer);
begin
  if (FText = AText) and (FCurByte = ACaret) then
    Exit;                        { 无变化不压栈（Paste 幂等） }
  PushUndo;                      { 单快照 = 替换前全文，一次 Undo 即还原 }
  FText := AText;
  if ACaret < 0 then
    FCurByte := 0
  else if ACaret > Length(AText) then
    FCurByte := Length(AText)
  else
    FCurByte := ACaret;
  FAnchor := -1;
  FTargetCol := -1;
  FScrollRow := 0;
  NotifySyntaxEdit;
end;

{ 定位到字节偏移:仅移动光标/清选区,不进撤销栈(查找跳转、鼠标点击等) }
procedure TInputEditor.MoveTo(const ABufOffset: Integer);
begin
  if ABufOffset <= 0 then
    FCurByte := 0
  else if ABufOffset >= Length(FText) then
    FCurByte := Length(FText)
  else
    FCurByte := ABufOffset;
  FAnchor := -1;
  FTargetCol := -1;
end;

{ 屏幕坐标 → 文本字节偏移:滚动首行换算 + 行内 grapheme 列累计;越界 clamp }
function TInputEditor.ByteOffsetAt(const AArea: TRect; AX, AY: Integer): Integer;
var
  DY, Row, StartB, EndB, P, C, CW: Integer;
  Adv: TEditorAdv;
begin
  if IsEmpty then Exit(0);
  DY := AY - AArea.Y;
  if DY < 0 then DY := 0;
  Row := FScrollRow + DY;
  if Row > LineCount_ - 1 then Row := LineCount_ - 1;
  if Row < 0 then Row := 0;
  StartB := LineStartByte(Row);
  EndB := LineEndByte(Row);
  C := AX - AArea.X;
  if C <= 0 then Exit(StartB);
  { 光标列 C = 前方已有 C 列宽内容;grapheme 消费到宽度和 >= C,
    超列(半字符)落点停在字符前 }
  P := StartB;
  while P < EndB do
  begin
    if FText[P + 1] = #10 then Break;
    Adv := EditorGraphemeAt(FText[1], Length(FText), P);
    if C <= 0 then Break;            { 已消费满 C 列 }
    if Adv.Width > C then Break;     { 超列(半字符):光标停字符前 }
    Dec(C, Adv.Width);
    Inc(P, Adv.ByteLen);
  end;
  Result := P;
end;

{ 查找命中高亮:缓存命中与样式(独立于选区),Render 内叠加;空数组清除 }
procedure TInputEditor.SetFindHits(const AHits: array of TFindHit; ACur: Integer;
  const AStyle, ACurStyle: TStyle);
var
  I: Integer;
begin
  SetLength(FFindHits, Length(AHits));
  for I := 0 to High(AHits) do
    FFindHits[I] := AHits[I];
  FFindCur := ACur;
  FFindStyle := AStyle;
  FFindCurStyle := ACurStyle;
  if (FFindCur < -1) or (FFindCur >= Length(FFindHits)) then
    FFindCur := -1;
end;

function TInputEditor.LineStartByte(Row: Integer): Integer;
var I, R: Integer;
begin
  if Row <= 0 then Exit(0);
  R := 0;
  for I := 1 to Length(FText) do
  begin
    if FText[I] = #10 then
    begin
      Inc(R);
      if R = Row then Exit(I);
    end;
  end;
  Result := Length(FText);
end;

function TInputEditor.LineEndByte(Row: Integer): Integer;
var I, R: Integer;
begin
  R := 0;
  for I := 1 to Length(FText) do
  begin
    if FText[I] = #10 then
    begin
      if R = Row then Exit(I - 1);
      Inc(R);
    end;
  end;
  Result := Length(FText);
end;

function TInputEditor.LineWidth(Row: Integer): Integer;
var StartB, EndB: Integer;
begin
  StartB := LineStartByte(Row);
  EndB := LineEndByte(Row);
  if EndB < StartB then Exit(0);
  Result := Integer(StringDisplayWidth(Copy(FText, StartB + 1, EndB - StartB)));
end;

procedure TInputEditor.CursorToRowCol(out Row, Col: Integer);
var P: Integer; Adv: TEditorAdv;
begin
  Row := 0;
  Col := 0;
  P := 0;
  while P < FCurByte do
  begin
    if (P < Length(FText)) and (FText[P + 1] = #10) then
    begin
      Inc(Row);
      Col := 0;
      Inc(P);
    end
    else if P < Length(FText) then
    begin
      Adv := EditorGraphemeAt(FText[1], Length(FText), P);
      Inc(Col, Adv.Width);
      Inc(P, Adv.ByteLen);
    end
    else
      Break;
  end;
end;
function TInputEditor.RowColToByte(Row, Col: Integer): Integer;
var StartB, EndB, P, C: Integer; Adv: TEditorAdv;
begin
  StartB := LineStartByte(Row);
  EndB := LineEndByte(Row);
  P := StartB;
  C := 0;
  while (P < EndB) and (C < Col) do
  begin
    Adv := EditorGraphemeAt(FText[1], Length(FText), P);
    if C + Adv.Width > Col then Break;
    Inc(C, Adv.Width);
    Inc(P, Adv.ByteLen);
  end;
  Result := P;
end;

procedure TInputEditor.EnsureCursorVisible(VisibleHeight: Integer);
var Row, Col: Integer;
begin
  if VisibleHeight <= 0 then Exit;
  CursorToRowCol(Row, Col);
  if Row < FScrollRow then
    FScrollRow := Row;
  if Row >= FScrollRow + VisibleHeight then
    FScrollRow := Row - VisibleHeight + 1;
end;

function TInputEditor.PrevGraphemeByte: Integer;
var P: Integer; Adv: TEditorAdv;
begin
  Result := FCurByte;
  if FCurByte <= 0 then Exit(0);
  P := 0;
  Result := 0;
  while P < FCurByte do
  begin
    Result := P;
    if FText[P + 1] = #10 then
      Inc(P)
    else
    begin
      Adv := EditorGraphemeAt(FText[1], Length(FText), P);
      Inc(P, Adv.ByteLen);
    end;
  end;
end;

function TInputEditor.NextGraphemeByte: Integer;
var Adv: TEditorAdv;
begin
  if FCurByte >= Length(FText) then Exit(FCurByte);
  if FText[FCurByte + 1] = #10 then
    Result := FCurByte + 1
  else
  begin
    Adv := EditorGraphemeAt(FText[1], Length(FText), FCurByte);
    Result := FCurByte + Adv.ByteLen;
  end;
end;

{ Selection }

function TInputEditor.HasSelection: Boolean;
begin
  Result := (FAnchor >= 0) and (FAnchor <> FCurByte);
end;

procedure TInputEditor.ClearSelection;
begin
  FAnchor := -1;
end;

procedure TInputEditor.SelectionRange(out SelStart, SelEnd: Integer);
begin
  if FAnchor < FCurByte then begin SelStart := FAnchor; SelEnd := FCurByte; end
  else begin SelStart := FCurByte; SelEnd := FAnchor; end;
end;

procedure TInputEditor.CollapseSelectionToStart;
var S, E: Integer;
begin
  SelectionRange(S, E);
  FCurByte := S;
  FAnchor := -1;
end;

procedure TInputEditor.CollapseSelectionToEnd;
var S, E: Integer;
begin
  SelectionRange(S, E);
  FCurByte := E;
  FAnchor := -1;
end;

function TInputEditor.SelectedText: AnsiString;
var S, E: Integer;
begin
  if not HasSelection then Exit('');
  SelectionRange(S, E);
  Result := Copy(FText, S + 1, E - S);
end;

procedure TInputEditor.DeleteSelection;
var S, E: Integer;
begin
  if not HasSelection then Exit;
  SelectionRange(S, E);
  Delete(FText, S + 1, E - S);
  FCurByte := S;
  FAnchor := -1;
end;
{ Undo/Redo }

procedure TInputEditor.NotifySyntaxEdit;
var Row, Col: Integer;
begin
  if FSyntaxDoc <> nil then
  begin
    CursorToRowCol(Row, Col);
    FSyntaxDoc.Invalidate(Row);
  end;
end;

procedure TInputEditor.GetLineForSyntax(LineIndex: Integer; out P: PAnsiChar; out Len: Integer);
var StartB, EndB: Integer;
begin
  StartB := LineStartByte(LineIndex);
  EndB := LineEndByte(LineIndex);
  Len := EndB - StartB;
  if Len > 0 then
    P := @FText[StartB + 1]
  else
    P := nil;
end;

procedure TInputEditor.PushUndo;
var Snap: TEditorSnapshot;
begin
  Snap.Text := FText;
  Snap.CurByte := FCurByte;
  Snap.Anchor := FAnchor;
  if FUndoCount < UNDO_MAX then
  begin
    FUndoStack[FUndoCount] := Snap;
    Inc(FUndoCount);
  end
  else
  begin
    { Move 搬托管 record 会绕开引用计数：先释放槽 0 旧串再搬移，
      否则每次栈满推送泄漏一个快照串（tui888 PH111 符号化实证） }
    FUndoStack[0] := Default(TEditorSnapshot);
    Move(FUndoStack[1], FUndoStack[0], (UNDO_MAX - 1) * SizeOf(TEditorSnapshot));
    FUndoStack[UNDO_MAX - 1] := Snap;
  end;
  FRedoCount := 0;
end;

procedure TInputEditor.Undo;
var Snap, Curr: TEditorSnapshot;
begin
  if FUndoCount = 0 then Exit;
  Curr.Text := FText;
  Curr.CurByte := FCurByte;
  Curr.Anchor := FAnchor;
  if FRedoCount < UNDO_MAX then
  begin
    FRedoStack[FRedoCount] := Curr;
    Inc(FRedoCount);
  end;
  Dec(FUndoCount);
  Snap := FUndoStack[FUndoCount];
  FText := Snap.Text;
  FCurByte := Snap.CurByte;
  FAnchor := Snap.Anchor;
  FTargetCol := -1;
  NotifySyntaxEdit;
end;

procedure TInputEditor.Redo;
var Snap, Curr: TEditorSnapshot;
begin
  if FRedoCount = 0 then Exit;
  Curr.Text := FText;
  Curr.CurByte := FCurByte;
  Curr.Anchor := FAnchor;
  if FUndoCount < UNDO_MAX then
  begin
    FUndoStack[FUndoCount] := Curr;
    Inc(FUndoCount);
  end;
  Dec(FRedoCount);
  Snap := FRedoStack[FRedoCount];
  FText := Snap.Text;
  FCurByte := Snap.CurByte;
  FAnchor := Snap.Anchor;
  FTargetCol := -1;
  NotifySyntaxEdit;
end;

{ Word boundaries }

function TInputEditor.IsWordByte(B: Byte): Boolean;
begin
  Result := (B >= Ord('A')) and (B <= Ord('Z')) or
            (B >= Ord('a')) and (B <= Ord('z')) or
            (B >= Ord('0')) and (B <= Ord('9')) or
            (B = Ord('_')) or (B >= 128);
end;

function TInputEditor.PrevWordBoundary: Integer;
var P: Integer;
begin
  P := FCurByte;
  if P <= 0 then Exit(0);
  Dec(P);
  while (P > 0) and not IsWordByte(Byte(FText[P + 1])) do Dec(P);
  while (P > 0) and IsWordByte(Byte(FText[P])) do Dec(P);
  Result := P;
end;

function TInputEditor.NextWordBoundary: Integer;
var P, Len: Integer;
begin
  Len := Length(FText);
  P := FCurByte;
  if P >= Len then Exit(Len);
  while (P < Len) and IsWordByte(Byte(FText[P + 1])) do Inc(P);
  while (P < Len) and not IsWordByte(Byte(FText[P + 1])) do Inc(P);
  Result := P;
end;
{ Movement internals }

procedure TInputEditor.MoveLeftInternal(Selecting: Boolean);
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else if HasSelection then begin CollapseSelectionToStart; FTargetCol := -1; Exit; end
  else ClearSelection;
  if FCurByte > 0 then
    FCurByte := PrevGraphemeByte;
  FTargetCol := -1;
end;

procedure TInputEditor.MoveRightInternal(Selecting: Boolean);
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else if HasSelection then begin CollapseSelectionToEnd; FTargetCol := -1; Exit; end
  else ClearSelection;
  if FCurByte < Length(FText) then
    FCurByte := NextGraphemeByte;
  FTargetCol := -1;
end;

procedure TInputEditor.MoveUpInternal(Selecting: Boolean);
var Row, Col, Target: Integer;
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  CursorToRowCol(Row, Col);
  if Row <= 0 then Exit;
  if FTargetCol < 0 then FTargetCol := Col;
  Target := FTargetCol;
  FCurByte := RowColToByte(Row - 1, Target);
end;

procedure TInputEditor.MoveDownInternal(Selecting: Boolean);
var Row, Col, Target: Integer;
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  CursorToRowCol(Row, Col);
  if Row >= LineCount_ - 1 then Exit;
  if FTargetCol < 0 then FTargetCol := Col;
  Target := FTargetCol;
  FCurByte := RowColToByte(Row + 1, Target);
end;

procedure TInputEditor.MoveHomeInternal(Selecting: Boolean);
var Row, Col: Integer;
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  CursorToRowCol(Row, Col);
  FCurByte := LineStartByte(Row);
  FTargetCol := -1;
end;

procedure TInputEditor.MoveEndInternal(Selecting: Boolean);
var Row, Col: Integer;
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  CursorToRowCol(Row, Col);
  FCurByte := LineEndByte(Row);
  FTargetCol := -1;
end;

procedure TInputEditor.MoveWordLeftInternal(Selecting: Boolean);
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  FCurByte := PrevWordBoundary;
  FTargetCol := -1;
end;

procedure TInputEditor.MoveWordRightInternal(Selecting: Boolean);
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  FCurByte := NextWordBoundary;
  FTargetCol := -1;
end;
{ Public movement (non-selecting) }

procedure TInputEditor.MoveLeft;      begin MoveLeftInternal(False); end;
procedure TInputEditor.MoveRight;     begin MoveRightInternal(False); end;
procedure TInputEditor.MoveUp;        begin MoveUpInternal(False); end;
procedure TInputEditor.MoveDown;      begin MoveDownInternal(False); end;
procedure TInputEditor.MoveHome;      begin MoveHomeInternal(False); end;
procedure TInputEditor.MoveEnd;       begin MoveEndInternal(False); end;
procedure TInputEditor.MoveWordLeft;  begin MoveWordLeftInternal(False); end;
procedure TInputEditor.MoveWordRight; begin MoveWordRightInternal(False); end;

{ Editing operations }

procedure TInputEditor.InsertChar(Cp: LongWord);
var S: AnsiString;
begin
  if Cp = 10 then begin InsertNewline; Exit; end;
  if Cp < 32 then Exit;
  PushUndo;
  if HasSelection then DeleteSelection;
  S := Ucs4ToUtf8(Cp);
  Insert(S, FText, FCurByte + 1);
  Inc(FCurByte, Length(S));
  FTargetCol := -1;
  NotifySyntaxEdit;
end;

procedure TInputEditor.InsertNewline;
begin
  if LineCount_ >= FMaxLines then Exit;
  PushUndo;
  if HasSelection then DeleteSelection;
  Insert(#10, FText, FCurByte + 1);
  Inc(FCurByte);
  FTargetCol := -1;
  NotifySyntaxEdit;
end;

procedure TInputEditor.DeleteBackward;
var Prev: Integer;
begin
  if HasSelection then begin PushUndo; DeleteSelection; FTargetCol := -1; NotifySyntaxEdit; Exit; end;
  if FCurByte <= 0 then Exit;
  PushUndo;
  Prev := PrevGraphemeByte;
  Delete(FText, Prev + 1, FCurByte - Prev);
  FCurByte := Prev;
  FTargetCol := -1;
  NotifySyntaxEdit;
end;

procedure TInputEditor.DeleteWordBackward;
var Bound: Integer;
begin
  { Ctrl+Backspace：删光标前一词（复用 PrevWordBoundary，与
    Ctrl+← 移动的边界定义一致；单 undo；选区优先同 DeleteBackward） }
  if HasSelection then begin PushUndo; DeleteSelection; FTargetCol := -1; NotifySyntaxEdit; Exit; end;
  if FCurByte <= 0 then Exit;
  PushUndo;
  Bound := PrevWordBoundary;
  Delete(FText, Bound + 1, FCurByte - Bound);
  FCurByte := Bound;
  FTargetCol := -1;
  NotifySyntaxEdit;
end;

procedure TInputEditor.DeleteWordForward;
var Bound: Integer;
begin
  { Ctrl+Delete：删到下一词首（与 Ctrl+→ 光标落点一致——
    删到哪光标跳到哪，用户视觉自洽） }
  if HasSelection then begin PushUndo; DeleteSelection; FTargetCol := -1; NotifySyntaxEdit; Exit; end;
  if FCurByte >= Length(FText) then Exit;
  PushUndo;
  Bound := NextWordBoundary;
  Delete(FText, FCurByte + 1, Bound - FCurByte);
  FTargetCol := -1;
  NotifySyntaxEdit;
end;

procedure TInputEditor.DeleteForward;
var Next: Integer;
begin
  if HasSelection then begin PushUndo; DeleteSelection; FTargetCol := -1; NotifySyntaxEdit; Exit; end;
  if FCurByte >= Length(FText) then Exit;
  PushUndo;
  Next := NextGraphemeByte;
  Delete(FText, FCurByte + 1, Next - FCurByte);
  FTargetCol := -1;
  NotifySyntaxEdit;
end;

{ Clipboard }

procedure TInputEditor.SelectAll;
begin
  FAnchor := 0;
  FCurByte := Length(FText);
  FTargetCol := -1;
end;

procedure TInputEditor.CopySelection;
begin
  if HasSelection then
    FClipboard := SelectedText;
end;

procedure TInputEditor.CutSelection;
begin
  if not HasSelection then Exit;
  FClipboard := SelectedText;
  PushUndo;
  DeleteSelection;
  FTargetCol := -1;
end;

{ 删除选区(宿主剪贴板剪切用,入撤销栈;一次 Undo 恢复) }
procedure TInputEditor.DeleteSelected;
begin
  if not HasSelection then Exit;
  PushUndo;
  DeleteSelection;
  FTargetCol := -1;
end;

procedure TInputEditor.Paste;
begin
  DoPaste(FClipboard);
end;

procedure TInputEditor.PasteText(const AText: AnsiString);
begin
  DoPaste(AText);
end;

procedure TInputEditor.DoPaste(const AText: AnsiString);
var I, NewLines, CurLines: Integer;
    Clipped: AnsiString;
begin
  if AText = '' then Exit;
  PushUndo;
  if HasSelection then DeleteSelection;
  Clipped := AText;
  CurLines := LineCount_;
  NewLines := 0;
  for I := 1 to Length(Clipped) do
    if Clipped[I] = #10 then Inc(NewLines);
  if CurLines + NewLines > FMaxLines then
  begin
    NewLines := FMaxLines - CurLines;
    if NewLines < 0 then NewLines := 0;
    I := 0;
    while (I < Length(Clipped)) and (NewLines >= 0) do
    begin
      Inc(I);
      if Clipped[I] = #10 then
      begin
        Dec(NewLines);
        if NewLines < 0 then begin Clipped := Copy(Clipped, 1, I - 1); Break; end;
      end;
    end;
  end;
  Insert(Clipped, FText, FCurByte + 1);
  Inc(FCurByte, Length(Clipped));
  FTargetCol := -1;
  NotifySyntaxEdit;
end;

procedure TInputEditor.DeleteLine;
var Row, Col, StartB, EndB: Integer;
begin
  PushUndo;
  CursorToRowCol(Row, Col);
  StartB := LineStartByte(Row);
  EndB := LineEndByte(Row);
  if (EndB < Length(FText)) and (FText[EndB + 1] = #10) then
    Inc(EndB);
  if EndB < StartB then EndB := StartB;
  Delete(FText, StartB + 1, EndB - StartB);
  FCurByte := StartB;
  if FCurByte > Length(FText) then FCurByte := Length(FText);
  FAnchor := -1;
  FTargetCol := -1;
  NotifySyntaxEdit;
end;
{ HandleKey }

function TInputEditor.HandleKey(const K: TKeyEvent): Boolean;
begin
  Result := True;
  case K.Code of
    kcChar:
      if kmCtrl in K.Modifiers then
      begin
        case K.Ch of
          Ord('a'), Ord('A'): SelectAll;
          Ord('c'), Ord('C'): CopySelection;
          Ord('x'), Ord('X'): CutSelection;
          Ord('v'), Ord('V'): Paste;
          Ord('z'), Ord('Z'):
            if kmShift in K.Modifiers then Redo else Undo;
          Ord('y'), Ord('Y'): Redo;
          Ord('d'), Ord('D'): DeleteLine;
        else
          InsertChar(K.Ch);
        end;
      end
      else
        InsertChar(K.Ch);
    kcEnter:
      if (kmShift in K.Modifiers) or (kmAlt in K.Modifiers) then
        InsertNewline
      else
        Result := False;
    kcBackspace:
      if kmCtrl in K.Modifiers then DeleteWordBackward
      else DeleteBackward;
    kcDelete:
      if kmCtrl in K.Modifiers then DeleteWordForward
      else DeleteForward;
    kcLeft:
      if kmCtrl in K.Modifiers then
        MoveWordLeftInternal(kmShift in K.Modifiers)
      else
        MoveLeftInternal(kmShift in K.Modifiers);
    kcRight:
      if kmCtrl in K.Modifiers then
        MoveWordRightInternal(kmShift in K.Modifiers)
      else
        MoveRightInternal(kmShift in K.Modifiers);
    kcUp:
      MoveUpInternal(kmShift in K.Modifiers);
    kcDown:
      MoveDownInternal(kmShift in K.Modifiers);
    kcHome:
      MoveHomeInternal(kmShift in K.Modifiers);
    kcEnd:
      MoveEndInternal(kmShift in K.Modifiers);
  else
    Result := False;
  end;
end;
{ Render }

function TInputEditor.WithTextStyle(const S: TStyle): IInputEditor;
begin FTextStyle := S; Result := Self; end;

function TInputEditor.WithPlaceholderStyle(const S: TStyle): IInputEditor;
begin FPlaceholderStyle := S; Result := Self; end;

function TInputEditor.WithSelectionStyle(const S: TStyle): IInputEditor;
begin FSelectionStyle := S; Result := Self; end;

function TInputEditor.WithPlaceholder(const P: AnsiString): IInputEditor;
begin FPlaceholder := P; Result := Self; end;

function TInputEditor.WithMaxLines(N: Integer): IInputEditor;
begin FMaxLines := N; Result := Self; end;

{ PH33 P2b：布局配置面——块包装（additive，nil 时行为不变） }
function TInputEditor.WithBlock(ABlock: IBlock): IInputEditor;
begin FBlock := ABlock; Result := Self; end;

{ PH33 P5a：行号 gutter 开关（additive，默认关=既有行为逐字节不变） }
function TInputEditor.WithLineNumbers(AOn: Boolean): IInputEditor;
begin FLineNumbers := AOn; Result := Self; end;

procedure TInputEditor.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LArea: TRect;
begin
  { PH33 P2b：块包装——先画块，再以块内容区为内容渲染区 }
  LArea := AArea;
  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    LArea := FBlock.Inner(AArea);
    if LArea.IsEmpty then Exit;
  end;
  RenderContent(LArea, ABuffer);
end;

procedure TInputEditor.RenderContent(const AArea: TRect; ABuffer: TBuffer);
var
  VisH, Row, I, StartB, EndB, DrawRow, LineLen: Integer;
  SelStart, SelEnd: Integer;
  SelActive: Boolean;
  LineByteStart, Col, P: Integer;
  Adv: TEditorAdv;
  SelColStart, SelColEnd, C: Integer;
  SelRect: TRect;
  TokPtr: PToken;
  TokCount, T: Integer;
  H, HS, HE, HSCol, HECol: Integer;
  HRect: TRect;
  LGutW, LI2: Integer;
  LNumStr: string;
  LContent: TRect;
  BndCol: array of Integer;
begin
  VisH := AArea.Height;
  if VisH <= 0 then Exit;
  EnsureCursorVisible(VisH);

  { PH33 P5a：行号 gutter——行号右对齐 + 1 隔列，内容区左移同宽；
    默认关时 LContent=AArea 零变化。宽式见 EditorGutW }
  LContent := AArea;
  if FLineNumbers then
  begin
    LGutW := EditorGutW(LineCount_);
    for LI2 := 0 to VisH - 1 do
    begin
      if FScrollRow + LI2 >= LineCount_ then Break;  { 越过末行不画号 }
      LNumStr := IntToStr(FScrollRow + LI2 + 1);
      ABuffer.SetStringN(AArea.X + LGutW - 1 - Length(LNumStr),
        AArea.Y + LI2, LNumStr, Length(LNumStr),
        TStyle.Default.WithFg(TUI_DARK_GRAY));
    end;
    LContent.X := AArea.X + LGutW;
    LContent.Width := AArea.Width - LGutW;
  end;

  if IsEmpty then
  begin
    ABuffer.SetStringN(LContent.X, LContent.Y, FPlaceholder, LContent.Width, FPlaceholderStyle);
    Exit;
  end;

  if FSyntaxDoc <> nil then
    FSyntaxDoc.SetLineCount(LineCount_);

  SelActive := HasSelection;
  if SelActive then SelectionRange(SelStart, SelEnd)
  else begin SelStart := 0; SelEnd := 0; end;

  Row := 0;
  I := 0;
  while (Row < FScrollRow) and (I < Length(FText)) do
  begin
    if FText[I + 1] = #10 then Inc(Row);
    Inc(I);
  end;

  DrawRow := 0;
  StartB := I;
  while (DrawRow < VisH) and (StartB <= Length(FText)) do
  begin
    EndB := StartB;
    while (EndB < Length(FText)) and (FText[EndB + 1] <> #10) do
      Inc(EndB);
    LineLen := EndB - StartB;

    if (FSyntaxDoc <> nil) and (LineLen > 0) then
    begin
      FSyntaxDoc.GetTokens(FScrollRow + DrawRow, TokPtr, TokCount);
      { PH33 P5a：token 字节偏移→显示列换算（与选区/查找命中同 EditorGraphemeAt
        口径）——此前字节偏移直当屏幕列，CJK 多字节行高亮错位。token 起始
        字节严格递增，单趟图素游走收集各边界列 }
      if TokCount > 0 then
      begin
        SetLength(BndCol, TokCount);
        P := StartB;
        Col := 0;
        for T := 0 to TokCount - 1 do
        begin
          while P < StartB + TokPtr[T].Start - 1 do
          begin
            Adv := EditorGraphemeAt(FText[1], Length(FText), P);
            Inc(Col, Adv.Width);
            Inc(P, Adv.ByteLen);
          end;
          BndCol[T] := Col;
        end;
        for T := 0 to TokCount - 1 do
          if BndCol[T] < LContent.Width then
            ABuffer.SetStringP(LContent.X + BndCol[T], LContent.Y + DrawRow,
              @FText[StartB + TokPtr[T].Start], TokPtr[T].Len,
              LContent.Width - BndCol[T],
              FSyntaxTheme.StyleFor(TokPtr[T].Kind));
      end;
    end
    else
      ABuffer.SetStringP(LContent.X, LContent.Y + DrawRow,
        @FText[StartB + 1], LineLen, LContent.Width, FTextStyle);

    if SelActive and (SelStart < EndB) and (SelEnd > StartB) then
    begin
      LineByteStart := StartB;
      SelColStart := 0;
      SelColEnd := 0;
      P := LineByteStart;
      Col := 0;
      while P < EndB do
      begin
        if P = SelStart then SelColStart := Col
        else if P < SelStart then SelColStart := Col + 1;
        if FText[P + 1] = #10 then Break;
        Adv := EditorGraphemeAt(FText[1], Length(FText), P);
        Inc(Col, Adv.Width);
        Inc(P, Adv.ByteLen);
        if P <= SelEnd then SelColEnd := Col;
      end;
      if SelStart <= LineByteStart then SelColStart := 0;
      if SelEnd >= EndB then SelColEnd := Col;
      if SelColEnd > SelColStart then
      begin
        C := SelColEnd - SelColStart;
        if C > LContent.Width - SelColStart then C := LContent.Width - SelColStart;
        SelRect := TRect.Make(LContent.X + SelColStart, LContent.Y + DrawRow, C, 1);
        ABuffer.SetStyle(SelRect, FSelectionStyle);
      end;
    end;

    { 查找命中高亮(独立于选区/语法):逐命中求行内列区间后叠底 }
    if Length(FFindHits) > 0 then
    begin
      for H := 0 to High(FFindHits) do
      begin
        HS := FFindHits[H].Start;
        HE := HS + FFindHits[H].Len;
        if (HE <= StartB) or (HS >= EndB) then Continue;
        P := StartB;
        Col := 0;
        HSCol := 0;
        HECol := 0;
        while P < EndB do
        begin
          if P = HS then HSCol := Col
          else if P < HS then HSCol := Col + 1;
          if FText[P + 1] = #10 then Break;
          Adv := EditorGraphemeAt(FText[1], Length(FText), P);
          Inc(Col, Adv.Width);
          Inc(P, Adv.ByteLen);
          if P <= HE then HECol := Col;
        end;
        if HS <= StartB then HSCol := 0;
        if HE >= EndB then HECol := Col;
        if HECol > HSCol then
        begin
          C := HECol - HSCol;
          if C > LContent.Width - HSCol then C := LContent.Width - HSCol;
          HRect := TRect.Make(LContent.X + HSCol, LContent.Y + DrawRow, C, 1);
          if H = FFindCur then
            ABuffer.SetStyle(HRect, FFindCurStyle)
          else
            ABuffer.SetStyle(HRect, FFindStyle);
        end;
      end;
    end;

    Inc(DrawRow);
    if (EndB < Length(FText)) and (FText[EndB + 1] = #10) then
      StartB := EndB + 1
    else
      Break;
  end;
end;

function TInputEditor.CursorScreenPos(const AArea: TRect): TPosition;
var Row, Col, G: Integer;
begin
  CursorToRowCol(Row, Col);
  { PH33 P5a：gutter 开时与 RenderContent 内容区同宽偏移（EditorGutW） }
  G := 0;
  if FLineNumbers then G := EditorGutW(LineCount_);
  Result.X := AArea.X + Col + G;
  Result.Y := AArea.Y + (Row - FScrollRow);
end;

procedure TInputEditor.SetHighlighter(AHL: IHighlighter; const ATheme: TSyntaxTheme);
begin
  FHighlighter := AHL;
  FSyntaxTheme := ATheme;
  if FSyntaxDoc <> nil then FSyntaxDoc.Free;
  if AHL <> nil then
    FSyntaxDoc := TSyntaxDoc.Create(AHL, LineCount_, @GetLineForSyntax)
  else
    FSyntaxDoc := nil;
end;

end.
