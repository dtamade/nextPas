unit nextpas.core.tui.widget.diffview;

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
  nextpas.core.tui.widget.block;

type
  TDiffLineKind = (dlContext, dlAdded, dlRemoved, dlHeader);

  TDiffLine = record
    Kind: TDiffLineKind;
    Text: AnsiString;
    OldNum: Integer;
    NewNum: Integer;
  end;

  TDiffViewState = record
    ScrollY: Integer;
    Selected: Integer;
    class function Empty: TDiffViewState; static;
    procedure ScrollDown(N: Integer = 1);
    procedure ScrollUp(N: Integer = 1);
  end;

  TDiffView = record
    Lines: array of TDiffLine;
    Style: TStyle;
    AddedStyle: TStyle;
    RemovedStyle: TStyle;
    HeaderStyle: TStyle;
    LineNumStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;

    class function Create(const ALines: array of TDiffLine): TDiffView; static;
    class function FromUnifiedDiff(const Diff: AnsiString): TDiffView; static;
    function WithStyle(const S: TStyle): TDiffView;
    function WithAddedStyle(const S: TStyle): TDiffView;
    function WithRemovedStyle(const S: TStyle): TDiffView;
    function WithBlock(const B: TBlock): TDiffView;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TDiffViewState);
  end;

implementation

{ TDiffViewState }

class function TDiffViewState.Empty: TDiffViewState;
begin
  Result.ScrollY := 0;
  Result.Selected := 0;
end;

procedure TDiffViewState.ScrollDown(N: Integer);
begin Inc(ScrollY, N); end;

procedure TDiffViewState.ScrollUp(N: Integer);
begin
  Dec(ScrollY, N);
  if ScrollY < 0 then ScrollY := 0;
end;

{ TDiffView }

class function TDiffView.Create(const ALines: array of TDiffLine): TDiffView;
var I: Integer;
begin
  SetLength(Result.Lines, Length(ALines));
  for I := 0 to High(ALines) do
    Result.Lines[I] := ALines[I];
  Result.Style := TStyle.Default;
  Result.AddedStyle := TStyle.Default.WithFg(TUI_GREEN);
  Result.RemovedStyle := TStyle.Default.WithFg(TUI_RED);
  Result.HeaderStyle := TStyle.Default.WithFg(TUI_CYAN).WithModifier([mbBold]);
  Result.LineNumStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  Result.HasBlock := False;
  Result.Block := nil;
end;

class function TDiffView.FromUnifiedDiff(const Diff: AnsiString): TDiffView;
var
  I, Start, Len, Count: Integer;
  RawLine: AnsiString;
  DL: TDiffLine;
  ParsedLines: array of TDiffLine;
  OldN, NewN: Integer;
begin
  Count := 0;
  ParsedLines := nil;
  Len := Length(Diff);
  Start := 1;
  OldN := 0;
  NewN := 0;

  for I := 1 to Len + 1 do
  begin
    if (I > Len) or (Diff[I] = #10) then
    begin
      RawLine := Copy(Diff, Start, I - Start);
      Start := I + 1;

      DL.OldNum := 0;
      DL.NewNum := 0;

      if (Length(RawLine) >= 3) and (Copy(RawLine, 1, 3) = '---') then
      begin
        DL.Kind := dlHeader;
        DL.Text := RawLine;
      end
      else if (Length(RawLine) >= 3) and (Copy(RawLine, 1, 3) = '+++') then
      begin
        DL.Kind := dlHeader;
        DL.Text := RawLine;
      end
      else if (Length(RawLine) >= 2) and (Copy(RawLine, 1, 2) = '@@') then
      begin
        DL.Kind := dlHeader;
        DL.Text := RawLine;
        OldN := 1; NewN := 1;
      end
      else if (Length(RawLine) >= 1) and (RawLine[1] = '+') then
      begin
        DL.Kind := dlAdded;
        DL.Text := Copy(RawLine, 2, Length(RawLine) - 1);
        DL.NewNum := NewN;
        Inc(NewN);
      end
      else if (Length(RawLine) >= 1) and (RawLine[1] = '-') then
      begin
        DL.Kind := dlRemoved;
        DL.Text := Copy(RawLine, 2, Length(RawLine) - 1);
        DL.OldNum := OldN;
        Inc(OldN);
      end
      else
      begin
        DL.Kind := dlContext;
        if Length(RawLine) > 0 then
          DL.Text := Copy(RawLine, 2, Length(RawLine) - 1)
        else
          DL.Text := '';
        DL.OldNum := OldN;
        DL.NewNum := NewN;
        Inc(OldN);
        Inc(NewN);
      end;

      Inc(Count);
      SetLength(ParsedLines, Count);
      ParsedLines[Count - 1] := DL;
    end;
  end;

  Result := TDiffView.Create(ParsedLines);
end;

function TDiffView.WithStyle(const S: TStyle): TDiffView;
begin Result := Self; Result.Style := S; end;

function TDiffView.WithAddedStyle(const S: TStyle): TDiffView;
begin Result := Self; Result.AddedStyle := S; end;

function TDiffView.WithRemovedStyle(const S: TStyle): TDiffView;
begin Result := Self; Result.RemovedStyle := S; end;

function TDiffView.WithBlock(const B: TBlock): TDiffView;
begin Result := Self; Result.HasBlock := True; Result.Block := B; end;

procedure TDiffView.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TDiffViewState);
var
  Inner: TRect;
  I, Y, Row, ViewH, GutterW, TextX, TextW: Integer;
  LineSty: TStyle;
  Prefix: AnsiChar;
  NumBuf: string[4];
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

  ViewH := Inner.Height;
  GutterW := 5;
  TextX := Inner.X + GutterW;
  TextW := Inner.Width - GutterW;
  if TextW < 1 then TextW := 1;

  // Clamp scroll
  if State.ScrollY > Length(Lines) - ViewH then
    State.ScrollY := Length(Lines) - ViewH;
  if State.ScrollY < 0 then State.ScrollY := 0;

  Y := Inner.Y;
  for I := 0 to ViewH - 1 do
  begin
    Row := State.ScrollY + I;
    if Row >= Length(Lines) then Break;

    case Lines[Row].Kind of
      dlAdded:
      begin
        LineSty := AddedStyle;
        Prefix := '+';
      end;
      dlRemoved:
      begin
        LineSty := RemovedStyle;
        Prefix := '-';
      end;
      dlHeader:
      begin
        LineSty := HeaderStyle;
        Prefix := ' ';
      end;
    else
      LineSty := Style;
      Prefix := ' ';
    end;

    // Line number
    if Lines[Row].NewNum > 0 then
      Str(Lines[Row].NewNum:4, NumBuf)
    else if Lines[Row].OldNum > 0 then
      Str(Lines[Row].OldNum:4, NumBuf)
    else
      NumBuf := '    ';

    ABuf.SetStringN(Inner.X, Y, NumBuf, GutterW - 1, LineNumStyle);
    ABuf.SetStringN(Inner.X + GutterW - 1, Y, Prefix, 1, LineSty);
    ABuf.SetStringN(TextX, Y, Lines[Row].Text, TextW, LineSty);

    Inc(Y);
  end;
end;

end.
