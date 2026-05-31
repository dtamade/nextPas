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

  IInput = interface(IWidget)
    ['{A7B8C9D0-E1F2-3456-ABCD-890123456789}']
    function WithPlaceholder(const S: AnsiString): IInput;
    function WithMask(Ch: Char): IInput;
    function WithStyle(const S: TStyle): IInput;
    function WithPlaceholderStyle(const S: TStyle): IInput;
    function WithCursorStyle(const S: TStyle): IInput;
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
    FBlock: IBlock;
  public
    class function New: IInput; static;

    function WithPlaceholder(const S: AnsiString): IInput;
    function WithMask(Ch: Char): IInput;
    function WithStyle(const S: TStyle): IInput;
    function WithPlaceholderStyle(const S: TStyle): IInput;
    function WithCursorStyle(const S: TStyle): IInput;
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

type
  TInputAdv = record ByteLen, Width: Integer; Codepoint: UInt32; end;

function InputGraphemeAt(const ABuffer; ALen, AOffset: Integer): TInputAdv;
var
  P: PByte;
  B0, B1, B2, B3: Byte;
  Cp: LongWord;
  Need: Integer;
begin
  Result.ByteLen := 1;
  Result.Width := 1;
  Result.Codepoint := $FFFD;
  if AOffset >= ALen then Exit;
  P := PByte(@ABuffer);
  B0 := P[AOffset];
  if B0 < $80 then
  begin
    Result.Codepoint := B0;
    Result.Width := CodepointWidth(B0);
    Exit;
  end;
  if (B0 and $E0) = $C0 then Need := 2
  else if (B0 and $F0) = $E0 then Need := 3
  else if (B0 and $F8) = $F0 then Need := 4
  else Exit;
  if AOffset + Need > ALen then Exit;
  case Need of
    2: begin
      B1 := P[AOffset + 1];
      if (B1 and $C0) <> $80 then Exit;
      Cp := (LongWord(B0 and $1F) shl 6) or LongWord(B1 and $3F);
      if Cp < $80 then Exit;
    end;
    3: begin
      B1 := P[AOffset + 1]; B2 := P[AOffset + 2];
      if ((B1 and $C0) <> $80) or ((B2 and $C0) <> $80) then Exit;
      Cp := (LongWord(B0 and $0F) shl 12) or (LongWord(B1 and $3F) shl 6) or LongWord(B2 and $3F);
      if Cp < $800 then Exit;
      if (Cp >= $D800) and (Cp <= $DFFF) then Exit;
    end;
    4: begin
      B1 := P[AOffset + 1]; B2 := P[AOffset + 2]; B3 := P[AOffset + 3];
      if ((B1 and $C0) <> $80) or ((B2 and $C0) <> $80) or ((B3 and $C0) <> $80) then Exit;
      Cp := (LongWord(B0 and $07) shl 18) or (LongWord(B1 and $3F) shl 12) or
            (LongWord(B2 and $3F) shl 6) or LongWord(B3 and $3F);
      if Cp < $10000 then Exit;
      if Cp > $10FFFF then Exit;
    end;
  else Exit;
  end;
  Result.ByteLen := Need;
  Result.Codepoint := Cp;
  Result.Width := CodepointWidth(Cp);
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
end;

class function TInputState.WithText(const S: AnsiString): TInputState;
begin
  Result.Text := S; Result.Cursor := Length(S); Result.ScrollX := 0;
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
  Len := 0; SetLength(Clean, Length(S));
  for I := 1 to Length(S) do
    if (S[I] <> #10) and (S[I] <> #13) then
    begin Inc(Len); Clean[Len] := S[I]; end;
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
begin Cursor := 0; end;

procedure TInputState.MoveEnd;
begin Cursor := Length(Text); end;

function TInputState.HandleKey(const K: TKeyEvent): Boolean;
begin
  Result := True;
  case K.Code of
    kcChar:
      if not (kmCtrl in K.Modifiers) then InsertChar(K.Ch)
      else Result := False;
    kcBackspace: DeleteBack;
    kcDelete:    DeleteForward;
    kcLeft:      MoveLeft;
    kcRight:     MoveRight;
    kcHome:      MoveHome;
    kcEnd:       MoveEnd;
  else Result := False;
  end;
end;

function TInputState.CursorCol: Integer;
begin Result := ColWidthUpTo(Text, Cursor); end;

function TInputState.TextWidth: Integer;
begin Result := Integer(StringDisplayWidth(Text)); end;

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
