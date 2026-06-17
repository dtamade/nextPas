unit nextpas.core.tui.widget.markdown;

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
  TMdLineKind = (mlNormal, mlH1, mlH2, mlH3, mlBullet, mlNumbered, mlCode, mlCodeBlock, mlHRule);

  TMdLine = record
    Kind: TMdLineKind;
    Text: AnsiString;
    Indent: Integer;
  end;

  TMdLineArray = array of TMdLine;

  TMdTheme = record
    Normal: TStyle;
    H1: TStyle;
    H2: TStyle;
    H3: TStyle;
    Bold: TStyle;
    Italic: TStyle;
    Code: TStyle;
    Bullet: TStyle;
    HRule: TStyle;

    class function Default: TMdTheme; static;
  end;

  IMarkdown = interface(IWidget)
    ['{F1A2B3C4-D5E6-7890-ABCD-EF1234567890}']
    function WithTheme(const ATheme: TMdTheme): IMarkdown;
    function WithBlock(ABlock: IBlock): IMarkdown;
  end;

  TMarkdown = class(TInterfacedObject, IWidget, IMarkdown)
  private
    FSource: AnsiString;
    FTheme: TMdTheme;
    FBlock: IBlock;
  public
    class function New(const ASource: AnsiString): IMarkdown; static;

    { IMarkdown builder }
    function WithTheme(const ATheme: TMdTheme): IMarkdown;
    function WithBlock(ABlock: IBlock): IMarkdown;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

function ParseMarkdownLines(const Source: AnsiString): TMdLineArray;

implementation

uses
  nextpas.core.text.conv;

{ TMdTheme }

class function TMdTheme.Default: TMdTheme;
begin
  Result.Normal := TStyle.Default;
  Result.H1 := TStyle.Default.WithModifier([mbBold]).WithFg(TUI_CYAN);
  Result.H2 := TStyle.Default.WithModifier([mbBold]).WithFg(TUI_GREEN);
  Result.H3 := TStyle.Default.WithModifier([mbBold]).WithFg(TUI_YELLOW);
  Result.Bold := TStyle.Default.WithModifier([mbBold]);
  Result.Italic := TStyle.Default.WithModifier([mbItalic]);
  Result.Code := TStyle.Default.WithFg(TUI_MAGENTA);
  Result.Bullet := TStyle.Default.WithFg(TUI_CYAN);
  Result.HRule := TStyle.Default.WithFg(TUI_DARK_GRAY);
end;

{ Parsing }

function ParseMarkdownLines(const Source: AnsiString): TMdLineArray;
var
  Lines: TMdLineArray;
  Count, Cap, I, Start, Len: Integer;
  RawLine, Trimmed: AnsiString;
  InCodeBlock: Boolean;

  procedure AddLine(AKind: TMdLineKind; const AText: AnsiString; AIndent: Integer = 0);
  begin
    if Count = Cap then
    begin
      if Cap = 0 then Cap := 32 else Cap := Cap * 2;
      SetLength(Lines, Cap);
    end;
    Lines[Count].Kind := AKind;
    Lines[Count].Text := AText;
    Lines[Count].Indent := AIndent;
    Inc(Count);
  end;

begin
  Count := 0;
  Cap := 0;
  Lines := nil;
  InCodeBlock := False;
  Len := Length(Source);
  Start := 1;

  for I := 1 to Len + 1 do
  begin
    if (I > Len) or (Source[I] = #10) then
    begin
      RawLine := Copy(Source, Start, I - Start);
      Start := I + 1;

      if InCodeBlock then
      begin
        if Copy(RawLine, 1, 3) = '```' then
          InCodeBlock := False
        else
          AddLine(mlCodeBlock, RawLine);
        Continue;
      end;

      Trimmed := Trim(RawLine);

      if Copy(Trimmed, 1, 3) = '```' then
      begin
        InCodeBlock := True;
        Continue;
      end;

      if (Length(Trimmed) >= 3) and (Trimmed[1] = '-') and (Trimmed[2] = '-') and (Trimmed[3] = '-') then
        AddLine(mlHRule, '')
      else if Copy(Trimmed, 1, 4) = '### ' then
        AddLine(mlH3, Copy(Trimmed, 5, Length(Trimmed) - 4))
      else if Copy(Trimmed, 1, 3) = '## ' then
        AddLine(mlH2, Copy(Trimmed, 4, Length(Trimmed) - 3))
      else if Copy(Trimmed, 1, 2) = '# ' then
        AddLine(mlH1, Copy(Trimmed, 3, Length(Trimmed) - 2))
      else if (Length(Trimmed) >= 2) and (Trimmed[1] = '-') and (Trimmed[2] = ' ') then
        AddLine(mlBullet, Copy(Trimmed, 3, Length(Trimmed) - 2))
      else if (Length(Trimmed) >= 2) and (Trimmed[1] = '*') and (Trimmed[2] = ' ') then
        AddLine(mlBullet, Copy(Trimmed, 3, Length(Trimmed) - 2))
      else if (Length(Trimmed) >= 3) and (Trimmed[1] in ['0'..'9']) and (Trimmed[2] = '.') and (Trimmed[3] = ' ') then
        AddLine(mlNumbered, Copy(Trimmed, 1, 2) + Copy(Trimmed, 3, Length(Trimmed) - 2))
      else
        AddLine(mlNormal, Trimmed);
    end;
  end;

  SetLength(Lines, Count);
  Result := Lines;
end;

{ TMarkdown }

class function TMarkdown.New(const ASource: AnsiString): IMarkdown;
var
  LObj: TMarkdown;
begin
  LObj := TMarkdown.Create;
  LObj.FSource := ASource;
  LObj.FTheme := TMdTheme.Default;
  LObj.FBlock := nil;
  Result := LObj;
end;

function TMarkdown.WithTheme(const ATheme: TMdTheme): IMarkdown;
begin
  FTheme := ATheme;
  Result := Self;
end;

function TMarkdown.WithBlock(ABlock: IBlock): IMarkdown;
begin
  FBlock := ABlock;
  Result := Self;
end;

procedure TMarkdown.Render(const AArea: TRect; ABuffer: TBuffer);
var
  Inner: TRect;
  Lines: TMdLineArray;
  I, Y: Integer;
  LineSty: TStyle;
  Prefix: AnsiString;
begin
  if AArea.IsEmpty then Exit;

  ABuffer.SetStyle(AArea, FTheme.Normal);

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;

  Lines := ParseMarkdownLines(FSource);

  Y := Inner.Y;
  for I := 0 to High(Lines) do
  begin
    if Y >= Inner.Y + Inner.Height then Break;

    case Lines[I].Kind of
      mlH1:
      begin
        LineSty := FTheme.H1;
        ABuffer.SetStringN(Inner.X, Y, Lines[I].Text, Inner.Width, LineSty);
      end;
      mlH2:
      begin
        LineSty := FTheme.H2;
        ABuffer.SetStringN(Inner.X, Y, Lines[I].Text, Inner.Width, LineSty);
      end;
      mlH3:
      begin
        LineSty := FTheme.H3;
        ABuffer.SetStringN(Inner.X, Y, Lines[I].Text, Inner.Width, LineSty);
      end;
      mlBullet:
      begin
        Prefix := '  ' + #$E2#$80#$A2 + ' ';
        ABuffer.SetStringN(Inner.X, Y, Prefix, 4, FTheme.Bullet);
        ABuffer.SetStringN(Inner.X + 4, Y, Lines[I].Text, Inner.Width - 4, FTheme.Normal);
      end;
      mlNumbered:
      begin
        Prefix := '  ' + Lines[I].Text;
        ABuffer.SetStringN(Inner.X, Y, Prefix, Inner.Width, FTheme.Normal);
      end;
      mlCodeBlock:
      begin
        ABuffer.SetStringN(Inner.X, Y, '  ' + Lines[I].Text, Inner.Width, FTheme.Code);
      end;
      mlHRule:
      begin
        ABuffer.SetStringN(Inner.X, Y,
          StringOfChar('-', Inner.Width), Inner.Width, FTheme.HRule);
      end;
    else
      ABuffer.SetStringN(Inner.X, Y, Lines[I].Text, Inner.Width, FTheme.Normal);
    end;

    Inc(Y);
  end;
end;

end.
