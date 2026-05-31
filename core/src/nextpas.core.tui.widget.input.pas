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
  nextpas.core.tui.widget.block;

type
  TInputState = record
    Text: AnsiString;
    Cursor: Integer;
    ScrollX: Integer;

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
    function HandleKey(const K: TKeyEvent): Boolean;
    function CursorCol: Integer;
    function TextWidth: Integer;
  end;

  TInput = record
    Placeholder: AnsiString;
    MaskChar: Char;
    Style: TStyle;
    PlaceholderStyle: TStyle;
    CursorStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;

    class function Default: TInput; static;
    function WithPlaceholder(const S: AnsiString): TInput;
    function WithMask(Ch: Char): TInput;
    function WithStyle(const S: TStyle): TInput;
    function WithPlaceholderStyle(const S: TStyle): TInput;
    function WithCursorStyle(const S: TStyle): TInput;
    function WithBlock(ABlock: IBlock): TInput;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TInputState);
    procedure RenderInline(ABuf: TBuffer; X, Y, MaxWidth: Integer; var State: TInputState);
  end;

implementation

type
  TInputAdv = class(TInterfacedObject) ByteLen, Width: Integer; Codepoint: UInt32; end;

function InputGraphemeAt(const ABuf; ALen, AOffset: Integer): TInputAdv; inline;
var LDec: TUTF8DecodeResult;
begin
  LDec := UTF8Decode(@PByte(@ABuf)[AOffset], ALen - AOffset);
  if LDec.ByteLen = 0 then begin Result.ByteLen := 1; Result.Width := 1; Result.Codepoint := $FFFD; end
  else begin Result.ByteLen := LDec.ByteLen; Result.Width := CodepointWidth(LDec.CodePoint); Result.Codepoint := LDec.CodePoint; end;
end;

function Ucs4ToUtf8(Cp: LongWord): AnsiString;
begin
  if Cp < $80 then
  begin
    SetLength(Result, 1);
    Result[1] := Chr(Cp);
  end
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
  while (P > 0) and ((Byte(S[P + 1]) and $C0) = $80) do
    Dec(P);
  if P < 0 then P := 0;
  Result := P;
end;

function GraphemeCount(const S: AnsiString): Integer;
var P: Integer; Adv: TInputAdv;
begin
  if Length(S) = 0 then Exit(0);
  Result := 0;
  P := 0;
  while P < Length(S) do
  begin
    Adv := InputGraphemeAt(S[1], Length(S), P);
    Inc(P, Adv.ByteLen);
    Inc(Result);
  end;
end;

function GraphemeCountUpTo(const S: AnsiString; BytePos: Integer): Integer;
var P: Integer; Adv: TInputAdv;
begin
  if Length(S) = 0 then Exit(0);
  Result := 0;
  P := 0;
  while P < BytePos do
  begin
    if P >= Length(S) then Break;
    Adv := InputGraphemeAt(S[1], Length(S), P);
    Inc(P, Adv.ByteLen);
    Inc(Result);
  end;
end;

function ColWidthUpTo(const S: AnsiString; BytePos: Integer): Integer;
var P: Integer; Adv: TInputAdv;
begin
  if Length(S) = 0 then Exit(0);
  Result := 0;
  P := 0;
  while P < BytePos do
  begin
    if P >= Length(S) then Break;
    Adv := InputGraphemeAt(S[1], Length(S), P);
    Inc(Result, Adv.Width);
    Inc(P, Adv.ByteLen);
  end;
end;

{ TInputState }

class function TInputState.Empty: TInputState;
begin
  Result.Text := '';
  Result.Cursor := 0;
  Result.ScrollX := 0;
end;

class function TInputState.WithText(const S: AnsiString): TInputState;
begin
  Result.Text := S;
  Result.Cursor := Length(S);
  Result.ScrollX := 0;
end;

procedure TInputState.InsertChar(Cp: LongWord);
var S: AnsiString;
begin
  if (Cp < 32) or (Cp > $10FFFF) then Exit;
  S := Ucs4ToUtf8(Cp);
  Insert(S, Text, Cursor + 1);
  Inc(Cursor, Length(S));
end;

procedure TInputState.InsertStr(const S: AnsiString);
var I, Len: Integer; Clean: AnsiString;
begin
  Len := 0;
  SetLength(Clean, Length(S));
  for I := 1 to Length(S) do
    if (S[I] <> #10) and (S[I] <> #13) then
    begin
      Inc(Len);
      Clean[Len] := S[I];
    end;
  SetLength(Clean, Len);
  if Len = 0 then Exit;
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
begin
  Cursor := 0;
end;

procedure TInputState.MoveEnd;
begin
  Cursor := Length(Text);
end;

function TInputState.HandleKey(const K: TKeyEvent): Boolean;
begin
  Result := True;
  case K.Code of
    kcChar:
      if not (kmCtrl in K.Modifiers) then
        InsertChar(K.Ch)
      else
        Result := False;
    kcBackspace: DeleteBack;
    kcDelete:    DeleteForward;
    kcLeft:      MoveLeft;
    kcRight:     MoveRight;
    kcHome:      MoveHome;
    kcEnd:       MoveEnd;
  else
    Result := False;
  end;
end;

function TInputState.CursorCol: Integer;
begin
  Result := ColWidthUpTo(Text, Cursor);
end;

function TInputState.TextWidth: Integer;
begin
  Result := Integer(StringDisplayWidth(Text));
end;

{ TInput }

class function TInput.Default: TInput;
begin
  Result.Placeholder := '';
  Result.MaskChar := #0;
  Result.Style := TStyle.Default;
  Result.PlaceholderStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  Result.CursorStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.HasBlock := False;
  Result.Block := nil;
end;

function TInput.WithPlaceholder(const S: AnsiString): TInput;
begin
  Result := Self;
  Result.Placeholder := S;
end;

function TInput.WithMask(Ch: Char): TInput;
begin
  Result := Self;
  Result.MaskChar := Ch;
end;

function TInput.WithStyle(const S: TStyle): TInput;
begin
  Result := Self;
  Result.Style := S;
end;

function TInput.WithPlaceholderStyle(const S: TStyle): TInput;
begin
  Result := Self;
  Result.PlaceholderStyle := S;
end;

function TInput.WithCursorStyle(const S: TStyle): TInput;
begin
  Result := Self;
  Result.CursorStyle := S;
end;

function TInput.WithBlock(ABlock: IBlock): TInput;
begin
  Result := Self;
  Result.HasBlock := True;
  Result.Block := ABlock;
end;

procedure TInput.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TInputState);
var
  Inner: TRect;
  DisplayText: AnsiString;
  VisibleW, CursorCol, ScrollCol: Integer;
  P, Col: Integer;
  Adv: TInputAdv;
begin
  if Area.IsEmpty then Exit;

  ABuf.SetStyle(Area, Style);

  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;

  VisibleW := Inner.Width;

  // Build display text and map cursor/scroll to display coordinates
  if MaskChar <> #0 then
  begin
    DisplayText := StringOfChar(MaskChar, GraphemeCount(State.Text));
    // In mask mode, cursor position = grapheme index (each mask char is 1 col)
    CursorCol := GraphemeCountUpTo(State.Text, State.Cursor);
    ScrollCol := GraphemeCountUpTo(State.Text, State.ScrollX);
  end
  else
  begin
    DisplayText := State.Text;
    CursorCol := ColWidthUpTo(DisplayText, State.Cursor);
    ScrollCol := ColWidthUpTo(DisplayText, State.ScrollX);
  end;

  // Adjust ScrollX so cursor is visible (using column widths)
  if CursorCol < ScrollCol then
  begin
    State.ScrollX := State.Cursor;
    ScrollCol := CursorCol;
  end
  else if CursorCol - ScrollCol >= VisibleW then
  begin
    P := State.Cursor;
    Col := 0;
    while (P > 0) and (Col < VisibleW - 1) do
    begin
      P := PrevGraphemeByte(State.Text, P);
      if Length(State.Text) = 0 then Break; Adv := InputGraphemeAt(State.Text[1], Length(State.Text), P);
      Inc(Col, Adv.Width);
      if MaskChar <> #0 then Col := Col - Adv.Width + 1;
    end;
    State.ScrollX := P;
    if MaskChar <> #0 then
      ScrollCol := GraphemeCountUpTo(State.Text, State.ScrollX)
    else
      ScrollCol := ColWidthUpTo(DisplayText, State.ScrollX);
  end;
  if State.ScrollX < 0 then
  begin
    State.ScrollX := 0;
    ScrollCol := 0;
  end;

  // Render text or placeholder
  if (Length(DisplayText) = 0) and (Length(Placeholder) > 0) then
    ABuf.SetStringN(Inner.X, Inner.Y, Placeholder, VisibleW, PlaceholderStyle)
  else if Length(DisplayText) > 0 then
  begin
    if MaskChar <> #0 then
      ABuf.SetStringN(Inner.X, Inner.Y,
        Copy(DisplayText, ScrollCol + 1, Length(DisplayText) - ScrollCol),
        VisibleW, Style)
    else
      ABuf.SetStringN(Inner.X, Inner.Y,
        Copy(DisplayText, State.ScrollX + 1, Length(DisplayText) - State.ScrollX),
        VisibleW, Style);
  end;

  // Cursor highlight (at correct column position)
  Col := CursorCol - ScrollCol;
  if (Col >= 0) and (Col < VisibleW) then
    ABuf.SetStyle(TRect.Make(Inner.X + Col, Inner.Y, 1, 1), CursorStyle);
end;

procedure TInput.RenderInline(ABuf: TBuffer; X, Y, MaxWidth: Integer; var State: TInputState);
var
  Area: TRect;
  SaveBlock: Boolean;
begin
  if MaxWidth <= 0 then Exit;
  SaveBlock := HasBlock;
  HasBlock := False;
  Area := TRect.Make(Word(X), Word(Y), Word(MaxWidth), 1);
  RenderStateful(Area, ABuf, State);
  HasBlock := SaveBlock;
end;

end.
