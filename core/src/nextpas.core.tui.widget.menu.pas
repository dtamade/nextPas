unit nextpas.core.tui.widget.menu;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.text.width, nextpas.core.text.utf8,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf;

type
  TMenuItemKind = (mikAction, mikSeparator, mikSubmenu);

  TMenuItem = record
    Kind: TMenuItemKind;
    Label_: AnsiString;
    Shortcut: AnsiString;
    Enabled: Boolean;
    Children: array of TMenuItem;

    class function Action(const ALabel: AnsiString): TMenuItem; static;
    class function Separator: TMenuItem; static;
    function WithShortcut(const S: AnsiString): TMenuItem;
    function WithEnabled(E: Boolean): TMenuItem;
    function WithChildren(const AItems: array of TMenuItem): TMenuItem;
  end;

  TMenuState = record
    Selected: Integer;
    Open: Boolean;
    class function Default: TMenuState; static;
  end;

  IMenu = interface(IWidget)
    ['{C9D0E1F2-A3B4-5678-CDEF-012345678901}']
    function WithStyle(const S: TStyle): IMenu;
    function WithHighlightStyle(const S: TStyle): IMenu;
    function WithDisabledStyle(const S: TStyle): IMenu;
    function WithWidth(W: Integer): IMenu;
    function ItemCount: Integer;
    function SelectableCount: Integer;
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TMenuState);
    procedure MoveUp(var AState: TMenuState);
    procedure MoveDown(var AState: TMenuState);
  end;

  TMenu = class(TInterfacedObject, IWidget, IMenu)
  private
    FItems: array of TMenuItem;
    FStyle: TStyle;
    FHighlightStyle: TStyle;
    FDisabledStyle: TStyle;
    FWidth: Integer;
  public
    class function New(const AItems: array of TMenuItem): IMenu; static;

    function WithStyle(const S: TStyle): IMenu;
    function WithHighlightStyle(const S: TStyle): IMenu;
    function WithDisabledStyle(const S: TStyle): IMenu;
    function WithWidth(W: Integer): IMenu;
    function ItemCount: Integer;
    function SelectableCount: Integer;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
    { IMenu }
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TMenuState);
    procedure MoveUp(var AState: TMenuState);
    procedure MoveDown(var AState: TMenuState);
  end;

implementation

{ TMenuItem }

class function TMenuItem.Action(const ALabel: AnsiString): TMenuItem;
begin
  Result.Kind := mikAction; Result.Label_ := ALabel;
  Result.Shortcut := ''; Result.Enabled := True; Result.Children := nil;
end;

class function TMenuItem.Separator: TMenuItem;
begin
  Result.Kind := mikSeparator; Result.Label_ := '';
  Result.Shortcut := ''; Result.Enabled := False; Result.Children := nil;
end;

function TMenuItem.WithShortcut(const S: AnsiString): TMenuItem;
begin Result := Self; Result.Shortcut := S; end;

function TMenuItem.WithEnabled(E: Boolean): TMenuItem;
begin Result := Self; Result.Enabled := E; end;

function TMenuItem.WithChildren(const AItems: array of TMenuItem): TMenuItem;
var I: Integer;
begin
  Result := Self; Result.Kind := mikSubmenu;
  SetLength(Result.Children, Length(AItems));
  for I := 0 to High(AItems) do Result.Children[I] := AItems[I];
end;

{ TMenuState }

class function TMenuState.Default: TMenuState;
begin Result.Selected := 0; Result.Open := True; end;

{ TMenu }

class function TMenu.New(const AItems: array of TMenuItem): IMenu;
var LSelf: TMenu; I: Integer;
begin
  LSelf := TMenu.Create;
  SetLength(LSelf.FItems, Length(AItems));
  for I := 0 to High(AItems) do LSelf.FItems[I] := AItems[I];
  LSelf.FStyle := TStyle.Default;
  LSelf.FHighlightStyle := TStyle.Default.WithModifier([mbReversed]);
  LSelf.FDisabledStyle := TStyle.Default.WithModifier([mbDim]);
  LSelf.FWidth := 0;
  Result := LSelf;
end;

function TMenu.WithStyle(const S: TStyle): IMenu;
begin FStyle := S; Result := Self; end;

function TMenu.WithHighlightStyle(const S: TStyle): IMenu;
begin FHighlightStyle := S; Result := Self; end;

function TMenu.WithDisabledStyle(const S: TStyle): IMenu;
begin FDisabledStyle := S; Result := Self; end;

function TMenu.WithWidth(W: Integer): IMenu;
begin FWidth := W; Result := Self; end;

function TMenu.ItemCount: Integer;
begin Result := Length(FItems); end;

function TMenu.SelectableCount: Integer;
var I, C: Integer;
begin
  C := 0;
  for I := 0 to High(FItems) do
    if (FItems[I].Kind <> mikSeparator) and FItems[I].Enabled then Inc(C);
  Result := C;
end;

procedure TMenu.Render(const AArea: TRect; ABuffer: TBuffer);
var LState: TMenuState;
begin
  LState := TMenuState.Default;
  RenderStateful(AArea, ABuffer, LState);
end;

procedure TMenu.RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TMenuState);
var
  I, Y, W, ShortcutX: Integer;
  Sty: TStyle;
  Line: AnsiString;
begin
  if AArea.IsEmpty then Exit;
  if Length(FItems) = 0 then Exit;

  W := FWidth;
  if W <= 0 then W := AArea.Width;
  if W > AArea.Width then W := AArea.Width;

  ABuffer.SetStyle(TRect.Make(AArea.X, AArea.Y, W, AArea.Height), FStyle);

  Y := AArea.Y;
  for I := 0 to High(FItems) do
  begin
    if Y >= AArea.Y + AArea.Height then Break;

    if FItems[I].Kind = mikSeparator then
    begin
      Line := StringOfChar('-', W);
      ABuffer.SetStringN(AArea.X, Y, Line, W, FStyle);
    end
    else
    begin
      if not FItems[I].Enabled then Sty := FDisabledStyle
      else if I = AState.Selected then Sty := FHighlightStyle
      else Sty := FStyle;

      ABuffer.SetStyle(TRect.Make(AArea.X, Y, W, 1), Sty);
      ABuffer.SetStringN(AArea.X + 1, Y, FItems[I].Label_, W - 2, Sty);

      if FItems[I].Shortcut <> '' then
      begin
        ShortcutX := AArea.X + W - Integer(StringDisplayWidth(FItems[I].Shortcut)) - 1;
        if ShortcutX > AArea.X + 1 then
          ABuffer.SetStringN(ShortcutX, Y, FItems[I].Shortcut,
            Integer(StringDisplayWidth(FItems[I].Shortcut)), Sty);
      end;

      if FItems[I].Kind = mikSubmenu then
        ABuffer.SetStringN(AArea.X + W - 2, Y, '>', 1, Sty);
    end;
    Inc(Y);
  end;
end;

procedure TMenu.MoveDown(var AState: TMenuState);
var Start, I: Integer;
begin
  if Length(FItems) = 0 then Exit;
  Start := AState.Selected;
  I := (Start + 1) mod Length(FItems);
  while I <> Start do
  begin
    if (FItems[I].Kind <> mikSeparator) and FItems[I].Enabled then
    begin AState.Selected := I; Exit; end;
    I := (I + 1) mod Length(FItems);
  end;
end;

procedure TMenu.MoveUp(var AState: TMenuState);
var Start, I: Integer;
begin
  if Length(FItems) = 0 then Exit;
  Start := AState.Selected;
  I := Start - 1;
  if I < 0 then I := High(FItems);
  while I <> Start do
  begin
    if (FItems[I].Kind <> mikSeparator) and FItems[I].Enabled then
    begin AState.Selected := I; Exit; end;
    Dec(I);
    if I < 0 then I := High(FItems);
  end;
end;

end.
