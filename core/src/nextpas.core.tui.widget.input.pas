unit nextpas.core.tui.widget.input;

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
  nextpas.core.text.utf8, nextpas.core.text.width,
  nextpas.core.tui.event,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.intf;

type
  TInputState = record
    Text: AnsiString;
    Cursor: Integer;
    ScrollX: Integer;
    { 选区(0-based 字节偏移;-1 = 无):Anchor 固定端,Head 随拖拽/Shift 移动 }
    SelAnchor: Integer;
    SelHead: Integer;

    class function Empty: TInputState; static;
    class function WithText(const S: AnsiString): TInputState; static;
    procedure InsertChar(Cp: LongWord);
    procedure InsertStr(const S: AnsiString);
    procedure DeleteBack;
    procedure DeleteForward;
    procedure MoveLeft;
    procedure MoveRight;
    procedure MoveHome;
    procedure MoveEnd;
    { 词操作:词边界 = 空白分隔(对齐 bubbles textinput) }
    procedure MoveWordLeft;    { Ctrl+←:跳到上一词首 }
    procedure MoveWordRight;   { Ctrl+→:跳到下一词尾 }
    procedure DeleteWordLeft;  { Ctrl+Backspace:删光标前一词 }
    procedure DeleteWordRight; { Ctrl+Delete:删光标后一词 }
    function HandleKey(const K: TKeyEvent): Boolean;
    function CursorCol: Integer;
    function TextWidth: Integer;

    { ---- 选区(鼠标拖选/Shift 扩展/双击词/三击全选)---- }
    procedure BeginSelect(APos: Integer);     { 锚=头=APos(按下落点) }
    procedure UpdateSelect(APos: Integer);    { 头=APos(拖动/Shift 扩展) }
    procedure ClearSelection;
    function HasSelection: Boolean;
    function SelFrom: Integer;                { min(Anchor,Head) }
    function SelTo: Integer;                  { max(Anchor,Head),不含端点 }
    function SelectedText: AnsiString;        { 仅拷贝动作时分配 }
    function DeleteSelection: Boolean;        { True=有选区已删,光标落 From }
    function SelectWordAt(APos: Integer): Boolean; { 双击选词;点空白 False }
    procedure SelectAll;
    function ColToBytePos(ACol: Integer): Integer; { 点击列→字节偏移(图素感知夹紧) }
    { Shift 扩展移动:无选区先以当前光标为锚,再移动头 }
    procedure MoveLeftExtend;
    procedure MoveRightExtend;
    procedure MoveHomeExtend;
    procedure MoveEndExtend;
    procedure MoveWordLeftExtend;
    procedure MoveWordRightExtend;
  end;

  IInput = interface(IWidget)
    ['{A7B8C9D0-E1F2-3456-ABCD-890123456789}']
    function WithPlaceholder(const S: AnsiString): IInput;
    function WithMask(Ch: Char): IInput;
    function WithStyle(const S: TStyle): IInput;
    function WithPlaceholderStyle(const S: TStyle): IInput;
    function WithCursorStyle(const S: TStyle): IInput;
    function WithSelectionStyle(const S: TStyle): IInput;
    function WithBlock(ABlock: IBlock): IInput;
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TInputState);
    procedure RenderInline(ABuffer: TBuffer; X, Y, MaxWidth: Integer;
      var AState: TInputState);
  end;

  TInput = class(TInterfacedObject, IWidget, IInput)
  private
    FPlaceholder: AnsiString;
    FMaskChar: Char;
    FStyle: TStyle;
    FPlaceholderStyle: TStyle;
    FCursorStyle: TStyle;
    FSelStyle: TStyle;
    FBlock: IBlock;
  public
    class function New: IInput; static;

    function WithPlaceholder(const S: AnsiString): IInput;
    function WithMask(Ch: Char): IInput;
    function WithStyle(const S: TStyle): IInput;
    function WithPlaceholderStyle(const S: TStyle): IInput;
    function WithCursorStyle(const S: TStyle): IInput;
    function WithSelectionStyle(const S: TStyle): IInput;
    function WithBlock(ABlock: IBlock): IInput;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
    { IInput }
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TInputState);
    procedure RenderInline(ABuffer: TBuffer; X, Y, MaxWidth: Integer;
      var AState: TInputState);
  end;

implementation

uses
  nextpas.core.text.grapheme;

type
  TInputAdv = record ByteLen, Width: Integer; Codepoint: UInt32; end;

function InputGraphemeAt(const ABuffer; ALen, AOffset: Integer): TInputAdv;
var LGR: TGraphemeResult; LDec: TUTF8DecodeResult;
begin
  LGR := GraphemeNext(@PByte(@ABuffer)[AOffset], ALen - AOffset);
  Result.ByteLen := LGR.ByteLen;
  Result.Width := LGR.Width;
  LDec := UTF8Decode(@PByte(@ABuffer)[AOffset], ALen - AOffset);
  if LDec.ByteLen > 0 then Result.Codepoint := LDec.CodePoint
  else Result.Codepoint := $FFFD;
end;

function Ucs4ToUtf8(Cp: LongWord): AnsiString;
begin
  if Cp < $80 then
  begin SetLength(Result, 1); Result[1] := Chr(Cp); end
  else if Cp < $800 then
  begin
    SetLength(Result, 2);
    Result[1] := Chr($C0 or (Cp shr 6));
    Result[2] := Chr($80 or (Cp and $3F));
  end
  else if Cp < $10000 then
  begin
    SetLength(Result, 3);
    Result[1] := Chr($E0 or (Cp shr 12));
    Result[2] := Chr($80 or ((Cp shr 6) and $3F));
    Result[3] := Chr($80 or (Cp and $3F));
  end
  else
  begin
    SetLength(Result, 4);
    Result[1] := Chr($F0 or (Cp shr 18));
    Result[2] := Chr($80 or ((Cp shr 12) and $3F));
    Result[3] := Chr($80 or ((Cp shr 6) and $3F));
    Result[4] := Chr($80 or (Cp and $3F));
  end;
end;

function PrevGraphemeByte(const S: AnsiString; Pos: Integer): Integer;
var P: Integer;
begin
  P := Pos - 1;
  while (P > 0) and ((Byte(S[P + 1]) and $C0) = $80) do Dec(P);
  if P < 0 then P := 0;
  Result := P;
end;

function GraphemeCount(const S: AnsiString): Integer;
var P: Integer; Adv: TInputAdv;
begin
  if Length(S) = 0 then Exit(0);
  Result := 0; P := 0;
  while P < Length(S) do
  begin
    Adv := InputGraphemeAt(S[1], Length(S), P);
    Inc(P, Adv.ByteLen); Inc(Result);
  end;
end;

function GraphemeCountUpTo(const S: AnsiString; BytePos: Integer): Integer;
var P: Integer; Adv: TInputAdv;
begin
  if Length(S) = 0 then Exit(0);
  Result := 0; P := 0;
  while P < BytePos do
  begin
    if P >= Length(S) then Break;
    Adv := InputGraphemeAt(S[1], Length(S), P);
    Inc(P, Adv.ByteLen); Inc(Result);
  end;
end;

function ColWidthUpTo(const S: AnsiString; BytePos: Integer): Integer;
var P: Integer; Adv: TInputAdv;
begin
  if Length(S) = 0 then Exit(0);
  Result := 0; P := 0;
  while P < BytePos do
  begin
    if P >= Length(S) then Break;
    Adv := InputGraphemeAt(S[1], Length(S), P);
    Inc(Result, Adv.Width); Inc(P, Adv.ByteLen);
  end;
end;

{ TInputState }

class function TInputState.Empty: TInputState;
begin
  Result.Text := ''; Result.Cursor := 0; Result.ScrollX := 0;
  Result.SelAnchor := -1; Result.SelHead := -1;
end;

class function TInputState.WithText(const S: AnsiString): TInputState;
begin
  Result.Text := S; Result.Cursor := Length(S); Result.ScrollX := 0;
  Result.SelAnchor := -1; Result.SelHead := -1;
end;

procedure TInputState.InsertChar(Cp: LongWord);
var S: AnsiString;
begin
  if (Cp < 32) or (Cp > $10FFFF) then Exit;
  DeleteSelection;   { 有选区先删:输入替换选区(标准编辑器语义) }
  S := Ucs4ToUtf8(Cp);
  Insert(S, Text, Cursor + 1);
  Inc(Cursor, Length(S));
end;

procedure TInputState.InsertStr(const S: AnsiString);
var I, Len: Integer; Clean: AnsiString;
begin
  Len := 0; SetLength(Clean, Length(S));
  for I := 1 to Length(S) do
    if (S[I] <> #10) and (S[I] <> #13) then
    begin Inc(Len); Clean[Len] := S[I]; end;
  SetLength(Clean, Len);
  if Len = 0 then Exit;
  DeleteSelection;   { 粘贴替换选区 }
  Insert(Clean, Text, Cursor + 1);
  Inc(Cursor, Len);
end;

procedure TInputState.DeleteBack;
var Prev: Integer;
begin
  if Cursor <= 0 then Exit;
  Prev := PrevGraphemeByte(Text, Cursor);
  Delete(Text, Prev + 1, Cursor - Prev);
  Cursor := Prev;
end;

procedure TInputState.DeleteForward;
var Adv: TInputAdv;
begin
  if Cursor >= Length(Text) then Exit;
  Adv := InputGraphemeAt(Text[1], Length(Text), Cursor);
  Delete(Text, Cursor + 1, Adv.ByteLen);
end;

procedure TInputState.MoveLeft;
begin
  if Cursor <= 0 then Exit;
  Cursor := PrevGraphemeByte(Text, Cursor);
end;

procedure TInputState.MoveRight;
var Adv: TInputAdv;
begin
  if Cursor >= Length(Text) then Exit;
  Adv := InputGraphemeAt(Text[1], Length(Text), Cursor);
  Inc(Cursor, Adv.ByteLen);
end;

procedure TInputState.MoveHome;
begin Cursor := 0; end;

procedure TInputState.MoveEnd;
begin Cursor := Length(Text); end;

{ 词操作:词 = 空白(空格/Tab)分隔的连续非空白段,光标为 0-based 字节偏移 }

procedure TInputState.MoveWordLeft;
begin
  { 跳到上一词首:先跳过紧邻光标左侧的空白,再越过词内字符停在词首 }
  if Cursor <= 0 then Exit;
  while (Cursor > 0) and (Byte(Text[Cursor]) = 32) do
    Cursor := PrevGraphemeByte(Text, Cursor);
  while (Cursor > 0) and (Byte(Text[Cursor]) <> 32) do
    Cursor := PrevGraphemeByte(Text, Cursor);
end;

procedure TInputState.MoveWordRight;
var Adv: TInputAdv;
begin
  { 跳到词尾:若在词中→本词尾;若在空白/词尾→下一词尾 }
  if Cursor >= Length(Text) then Exit;
  while Cursor < Length(Text) do
  begin
    Adv := InputGraphemeAt(Text[1], Length(Text), Cursor);
    if Byte(Text[Cursor + 1]) <> 32 then Break;
    Inc(Cursor, Adv.ByteLen);
  end;
  while Cursor < Length(Text) do
  begin
    Adv := InputGraphemeAt(Text[1], Length(Text), Cursor);
    Inc(Cursor, Adv.ByteLen);
    if Cursor >= Length(Text) then Break;
    if Byte(Text[Cursor + 1]) = 32 then Break;
  end;
end;

procedure TInputState.DeleteWordLeft;
var Start: Integer;
begin
  { 删掉光标前一词(词自身,保留词间空白分隔) }
  if Cursor <= 0 then Exit;
  Start := Cursor;
  while (Start > 0) and (Byte(Text[Start]) = 32) do
    Start := PrevGraphemeByte(Text, Start);
  while (Start > 0) and (Byte(Text[Start]) <> 32) do
    Start := PrevGraphemeByte(Text, Start);
  Delete(Text, Start + 1, Cursor - Start);
  Cursor := Start;
end;

procedure TInputState.DeleteWordRight;
var EndPos: Integer; Adv: TInputAdv;
begin
  { 删掉光标后一词(跳过前导空白) }
  if Cursor >= Length(Text) then Exit;
  EndPos := Cursor;
  while EndPos < Length(Text) do
  begin
    Adv := InputGraphemeAt(Text[1], Length(Text), EndPos);
    if Byte(Text[EndPos + 1]) <> 32 then Break;
    Inc(EndPos, Adv.ByteLen);
  end;
  while EndPos < Length(Text) do
  begin
    Adv := InputGraphemeAt(Text[1], Length(Text), EndPos);
    Inc(EndPos, Adv.ByteLen);
    if EndPos >= Length(Text) then Break;
    if Byte(Text[EndPos + 1]) = 32 then Break;
  end;
  Delete(Text, Cursor + 1, EndPos - Cursor);
end;

function TInputState.HandleKey(const K: TKeyEvent): Boolean;
var LExt: Boolean;
begin
  Result := True;
  { Shift+导航 = 扩展选区;普通导航 = 收拢选区后纯移动 }
  LExt := kmShift in K.Modifiers;
  case K.Code of
    kcChar:
      if not (kmCtrl in K.Modifiers) then InsertChar(K.Ch)
      else Result := False;
    kcBackspace:
      if kmCtrl in K.Modifiers then DeleteWordLeft
      else if not DeleteSelection then DeleteBack;
    kcDelete:
      if kmCtrl in K.Modifiers then DeleteWordRight
      else if not DeleteSelection then DeleteForward;
    kcLeft:
      if LExt then
      begin
        if kmCtrl in K.Modifiers then MoveWordLeftExtend else MoveLeftExtend;
      end
      else
      begin
        ClearSelection;
        if kmCtrl in K.Modifiers then MoveWordLeft else MoveLeft;
      end;
    kcRight:
      if LExt then
      begin
        if kmCtrl in K.Modifiers then MoveWordRightExtend else MoveRightExtend;
      end
      else
      begin
        ClearSelection;
        if kmCtrl in K.Modifiers then MoveWordRight else MoveRight;
      end;
    kcHome:
      if LExt then MoveHomeExtend
      else begin ClearSelection; MoveHome; end;
    kcEnd:
      if LExt then MoveEndExtend
      else begin ClearSelection; MoveEnd; end;
  else Result := False;
  end;
end;

function TInputState.CursorCol: Integer;
begin Result := ColWidthUpTo(Text, Cursor); end;

function TInputState.TextWidth: Integer;
begin Result := Integer(StringDisplayWidth(Text)); end;

{ ---- 选区 ---- }

procedure TInputState.BeginSelect(APos: Integer);
begin
  SelAnchor := APos; SelHead := APos;
end;

procedure TInputState.UpdateSelect(APos: Integer);
begin
  SelHead := APos;
end;

procedure TInputState.ClearSelection;
begin
  SelAnchor := -1; SelHead := -1;
end;

function TInputState.HasSelection: Boolean;
begin
  Result := (SelAnchor >= 0) and (SelHead >= 0) and (SelAnchor <> SelHead);
end;

function TInputState.SelFrom: Integer;
begin
  if SelAnchor <= SelHead then Result := SelAnchor else Result := SelHead;
end;

function TInputState.SelTo: Integer;
begin
  if SelAnchor <= SelHead then Result := SelHead else Result := SelAnchor;
end;

function TInputState.SelectedText: AnsiString;
begin
  if HasSelection then
    Result := Copy(Text, SelFrom + 1, SelTo - SelFrom)
  else
    Result := '';
end;

function TInputState.DeleteSelection: Boolean;
var LHad: Boolean;
begin
  LHad := HasSelection;
  if LHad then
  begin
    Delete(Text, SelFrom + 1, SelTo - SelFrom);
    Cursor := SelFrom;
    ClearSelection;
  end;
  Result := LHad;
end;

function TInputState.SelectWordAt(APos: Integer): Boolean;
var S, E: Integer; Adv: TInputAdv;
begin
  Result := False;
  if Length(Text) = 0 then Exit;
  { 点在末图素之后:回退到最后一个图素再试(grok 双击行尾同语义) }
  if APos >= Length(Text) then APos := PrevGraphemeByte(Text, Length(Text));
  if Byte(Text[APos + 1]) = 32 then Exit;   { 点空白不选中 }
  S := APos;
  while (S > 0) and (Byte(Text[S]) <> 32) do
    S := PrevGraphemeByte(Text, S);
  E := APos;
  while E < Length(Text) do
  begin
    Adv := InputGraphemeAt(Text[1], Length(Text), E);
    Inc(E, Adv.ByteLen);
    if E >= Length(Text) then Break;
    if Byte(Text[E + 1]) = 32 then Break;
  end;
  SelAnchor := S; SelHead := E;
  Cursor := E;   { neovim 风格:双击后光标落词尾 }
  Result := True;
end;

procedure TInputState.SelectAll;
begin
  if Length(Text) = 0 then Exit;
  SelAnchor := 0; SelHead := Length(Text);
end;

function TInputState.ColToBytePos(ACol: Integer): Integer;
var P, W: Integer; Adv: TInputAdv;
begin
  { 点击显示列→字节偏移;宽字符落点夹到其起始字节 }
  Result := 0;
  if Length(Text) = 0 then Exit;
  P := 0; W := 0;
  while P < Length(Text) do
  begin
    Adv := InputGraphemeAt(Text[1], Length(Text), P);
    if W + Adv.Width > ACol then Exit(P);
    Inc(W, Adv.Width); Inc(P, Adv.ByteLen);
  end;
  Result := P;
end;

{ Shift 扩展移动:无选区先以当前光标为锚,再移动头 }

procedure TInputState.MoveLeftExtend;
begin
  if not HasSelection then BeginSelect(Cursor);
  MoveLeft; UpdateSelect(Cursor);
end;

procedure TInputState.MoveRightExtend;
begin
  if not HasSelection then BeginSelect(Cursor);
  MoveRight; UpdateSelect(Cursor);
end;

procedure TInputState.MoveHomeExtend;
begin
  if not HasSelection then BeginSelect(Cursor);
  MoveHome; UpdateSelect(Cursor);
end;

procedure TInputState.MoveEndExtend;
begin
  if not HasSelection then BeginSelect(Cursor);
  MoveEnd; UpdateSelect(Cursor);
end;

procedure TInputState.MoveWordLeftExtend;
begin
  if not HasSelection then BeginSelect(Cursor);
  MoveWordLeft; UpdateSelect(Cursor);
end;

procedure TInputState.MoveWordRightExtend;
begin
  if not HasSelection then BeginSelect(Cursor);
  MoveWordRight; UpdateSelect(Cursor);
end;

{ TInput }

class function TInput.New: IInput;
var LSelf: TInput;
begin
  LSelf := TInput.Create;
  LSelf.FPlaceholder := '';
  LSelf.FMaskChar := #0;
  LSelf.FStyle := TStyle.Default;
  LSelf.FPlaceholderStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  LSelf.FCursorStyle := TStyle.Default.WithModifier([mbReversed]);
  LSelf.FSelStyle := TStyle.Default.WithModifier([mbReversed]);
  LSelf.FBlock := nil;
  Result := LSelf;
end;

function TInput.WithPlaceholder(const S: AnsiString): IInput;
begin FPlaceholder := S; Result := Self; end;

function TInput.WithMask(Ch: Char): IInput;
begin FMaskChar := Ch; Result := Self; end;

function TInput.WithStyle(const S: TStyle): IInput;
begin FStyle := S; Result := Self; end;

function TInput.WithPlaceholderStyle(const S: TStyle): IInput;
begin FPlaceholderStyle := S; Result := Self; end;

function TInput.WithCursorStyle(const S: TStyle): IInput;
begin FCursorStyle := S; Result := Self; end;

function TInput.WithSelectionStyle(const S: TStyle): IInput;
begin FSelStyle := S; Result := Self; end;

function TInput.WithBlock(ABlock: IBlock): IInput;
begin FBlock := ABlock; Result := Self; end;

procedure TInput.Render(const AArea: TRect; ABuffer: TBuffer);
var LState: TInputState;
begin
  LState := TInputState.Empty;
  RenderStateful(AArea, ABuffer, LState);
end;

procedure TInput.RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TInputState);
var
  Inner: TRect;
  DisplayText: AnsiString;
  VisibleW, CurCol, ScrollCol: Integer;
  P, Col: Integer;
  HF, HT: Integer;
  Adv: TInputAdv;
begin
  if AArea.IsEmpty then Exit;
  ABuffer.SetStyle(AArea, FStyle);

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;
  VisibleW := Inner.Width;

  if FMaskChar <> #0 then
  begin
    DisplayText := StringOfChar(FMaskChar, GraphemeCount(AState.Text));
    CurCol := GraphemeCountUpTo(AState.Text, AState.Cursor);
    ScrollCol := GraphemeCountUpTo(AState.Text, AState.ScrollX);
  end
  else
  begin
    DisplayText := AState.Text;
    CurCol := ColWidthUpTo(DisplayText, AState.Cursor);
    ScrollCol := ColWidthUpTo(DisplayText, AState.ScrollX);
  end;

  if CurCol < ScrollCol then
  begin
    AState.ScrollX := AState.Cursor;
    ScrollCol := CurCol;
  end
  else if CurCol - ScrollCol >= VisibleW then
  begin
    P := AState.Cursor; Col := 0;
    while (P > 0) and (Col < VisibleW - 1) do
    begin
      P := PrevGraphemeByte(AState.Text, P);
      if Length(AState.Text) = 0 then Break;
      Adv := InputGraphemeAt(AState.Text[1], Length(AState.Text), P);
      Inc(Col, Adv.Width);
      if FMaskChar <> #0 then Col := Col - Adv.Width + 1;
    end;
    AState.ScrollX := P;
    if FMaskChar <> #0 then
      ScrollCol := GraphemeCountUpTo(AState.Text, AState.ScrollX)
    else
      ScrollCol := ColWidthUpTo(DisplayText, AState.ScrollX);
  end;
  if AState.ScrollX < 0 then begin AState.ScrollX := 0; ScrollCol := 0; end;

  if (Length(DisplayText) = 0) and (Length(FPlaceholder) > 0) then
    ABuffer.SetStringN(Inner.X, Inner.Y, FPlaceholder, VisibleW, FPlaceholderStyle)
  else if Length(DisplayText) > 0 then
  begin
    if FMaskChar <> #0 then
      ABuffer.SetStringN(Inner.X, Inner.Y,
        Copy(DisplayText, ScrollCol + 1, Length(DisplayText) - ScrollCol),
        VisibleW, FStyle)
    else
      ABuffer.SetStringN(Inner.X, Inner.Y,
        Copy(DisplayText, AState.ScrollX + 1, Length(DisplayText) - AState.ScrollX),
        VisibleW, FStyle);
  end;

  { 选区高亮:选区显示列与可见窗求交(遮罩态按图素计数),零分配 }
  if AState.HasSelection() then
  begin
    if FMaskChar <> #0 then
    begin
      HF := GraphemeCountUpTo(AState.Text, AState.SelFrom()) - ScrollCol;
      HT := GraphemeCountUpTo(AState.Text, AState.SelTo()) - ScrollCol;
    end
    else
    begin
      HF := ColWidthUpTo(DisplayText, AState.SelFrom()) - ScrollCol;
      HT := ColWidthUpTo(DisplayText, AState.SelTo()) - ScrollCol;
    end;
    if HF < 0 then HF := 0;
    if HT > VisibleW then HT := VisibleW;
    if HT > HF then
      ABuffer.SetStyle(TRect.Make(Inner.X + HF, Inner.Y, Word(HT - HF), 1),
        FSelStyle);
  end;

  Col := CurCol - ScrollCol;
  if (Col >= 0) and (Col < VisibleW) then
    ABuffer.SetStyle(TRect.Make(Inner.X + Col, Inner.Y, 1, 1), FCursorStyle);
end;

procedure TInput.RenderInline(ABuffer: TBuffer; X, Y, MaxWidth: Integer; var AState: TInputState);
var Area: TRect; SaveBlock: IBlock;
begin
  if MaxWidth <= 0 then Exit;
  SaveBlock := FBlock;
  FBlock := nil;
  Area := TRect.Make(Word(X), Word(Y), Word(MaxWidth), 1);
  RenderStateful(Area, ABuffer, AState);
  FBlock := SaveBlock;
end;

end.
