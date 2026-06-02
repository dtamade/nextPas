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
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.intf;

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

  IDiffView = interface(IWidget)
    ['{1A2B3C4D-5E6F-7890-ABCD-EF0123456701}']
    function WithStyle(const S: TStyle): IDiffView;
    function WithAddedStyle(const S: TStyle): IDiffView;
    function WithRemovedStyle(const S: TStyle): IDiffView;
    function WithBlock(ABlock: IBlock): IDiffView;
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TDiffViewState);
  end;

  TDiffView = class(TInterfacedObject, IWidget, IDiffView)
  private
    FLines: array of TDiffLine;
    FStyle: TStyle;
    FAddedStyle: TStyle;
    FRemovedStyle: TStyle;
    FHeaderStyle: TStyle;
    FLineNumStyle: TStyle;
    FBlock: IBlock;
  public
    class function New(const ALines: array of TDiffLine): IDiffView; static;
    class function FromUnifiedDiff(const Diff: AnsiString): IDiffView; static;

    function WithStyle(const S: TStyle): IDiffView;
    function WithAddedStyle(const S: TStyle): IDiffView;
    function WithRemovedStyle(const S: TStyle): IDiffView;
    function WithBlock(ABlock: IBlock): IDiffView;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
    { IDiffView }
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TDiffViewState);
  end;

implementation

uses
  SysUtils;

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

class function TDiffView.New(const ALines: array of TDiffLine): IDiffView;
var
  Obj: TDiffView;
  I: Integer;
begin
  Obj := TDiffView.Create;
  SetLength(Obj.FLines, Length(ALines));
  for I := 0 to High(ALines) do
    Obj.FLines[I] := ALines[I];
  Obj.FStyle := TStyle.Default;
  Obj.FAddedStyle := TStyle.Default.WithFg(TUI_GREEN);
  Obj.FRemovedStyle := TStyle.Default.WithFg(TUI_RED);
  Obj.FHeaderStyle := TStyle.Default.WithFg(TUI_CYAN).WithModifier([mbBold]);
  Obj.FLineNumStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  Obj.FBlock := nil;
  Result := Obj;
end;

class function TDiffView.FromUnifiedDiff(const Diff: AnsiString): IDiffView;
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

  Result := TDiffView.New(ParsedLines);
end;

function TDiffView.WithStyle(const S: TStyle): IDiffView;
begin FStyle := S; Result := Self; end;

function TDiffView.WithAddedStyle(const S: TStyle): IDiffView;
begin FAddedStyle := S; Result := Self; end;

function TDiffView.WithRemovedStyle(const S: TStyle): IDiffView;
begin FRemovedStyle := S; Result := Self; end;

function TDiffView.WithBlock(ABlock: IBlock): IDiffView;
begin FBlock := ABlock; Result := Self; end;

procedure TDiffView.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LState: TDiffViewState;
begin
  LState := TDiffViewState.Empty;
  RenderStateful(AArea, ABuffer, LState);
end;

procedure TDiffView.RenderStateful(const AArea: TRect; ABuffer: TBuffer;
  var AState: TDiffViewState);
var
  Inner: TRect;
  I, Y, Row, ViewH, GutterW, TextX, TextW: Integer;
  LineSty: TStyle;
  Prefix: AnsiChar;
  NumBuf: string[4];
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

  ViewH := Inner.Height;
  GutterW := 5;
  TextX := Inner.X + GutterW;
  TextW := Inner.Width - GutterW;
  if TextW < 1 then TextW := 1;

  // Clamp scroll
  if AState.ScrollY > Length(FLines) - ViewH then
    AState.ScrollY := Length(FLines) - ViewH;
  if AState.ScrollY < 0 then AState.ScrollY := 0;

  Y := Inner.Y;
  for I := 0 to ViewH - 1 do
  begin
    Row := AState.ScrollY + I;
    if Row >= Length(FLines) then Break;

    case FLines[Row].Kind of
      dlAdded:
      begin
        LineSty := FAddedStyle;
        Prefix := '+';
      end;
      dlRemoved:
      begin
        LineSty := FRemovedStyle;
        Prefix := '-';
      end;
      dlHeader:
      begin
        LineSty := FHeaderStyle;
        Prefix := ' ';
      end;
    else
      LineSty := FStyle;
      Prefix := ' ';
    end;

    // Line number
    if FLines[Row].NewNum > 0 then
      Str(FLines[Row].NewNum:4, NumBuf)
    else if FLines[Row].OldNum > 0 then
      Str(FLines[Row].OldNum:4, NumBuf)
    else
      NumBuf := '    ';

    ABuffer.SetStringN(Inner.X, Y, NumBuf, GutterW - 1, FLineNumStyle);
    ABuffer.SetStringN(Inner.X + GutterW - 1, Y, Prefix, 1, LineSty);
    ABuffer.SetStringN(TextX, Y, FLines[Row].Text, TextW, LineSty);

    Inc(Y);
  end;
end;

end.
