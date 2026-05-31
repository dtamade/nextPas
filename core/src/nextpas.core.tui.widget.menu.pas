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
  nextpas.core.tui.buffer;

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

  TMenu = class(TInterfacedObject)
    Items: array of TMenuItem;
    Style: TStyle;
    HighlightStyle: TStyle;
    DisabledStyle: TStyle;
    Width: Integer;

    class function Create(const AItems: array of TMenuItem): TMenu; static;
    function WithStyle(const S: TStyle): TMenu;
    function WithHighlightStyle(const S: TStyle): TMenu;
    function WithDisabledStyle(const S: TStyle): TMenu;
    function WithWidth(W: Integer): TMenu;
    function ItemCount: Integer;
    function SelectableCount: Integer;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TMenuState);
    procedure MoveUp(var State: TMenuState);
    procedure MoveDown(var State: TMenuState);
  end;

implementation

{ TMenuItem }

class function TMenuItem.Action(const ALabel: AnsiString): TMenuItem;
begin
  Result.Kind := mikAction;
  Result.Label_ := ALabel;
  Result.Shortcut := '';
  Result.Enabled := True;
  Result.Children := nil;
end;

class function TMenuItem.Separator: TMenuItem;
begin
  Result.Kind := mikSeparator;
  Result.Label_ := '';
  Result.Shortcut := '';
  Result.Enabled := False;
  Result.Children := nil;
end;

function TMenuItem.WithShortcut(const S: AnsiString): TMenuItem;
begin
  Result := Self;
  Result.Shortcut := S;
end;

function TMenuItem.WithEnabled(E: Boolean): TMenuItem;
begin
  Result := Self;
  Result.Enabled := E;
end;

function TMenuItem.WithChildren(const AItems: array of TMenuItem): TMenuItem;
var I: Integer;
begin
  Result := Self;
  Result.Kind := mikSubmenu;
  SetLength(Result.Children, Length(AItems));
  for I := 0 to High(AItems) do
    Result.Children[I] := AItems[I];
end;

{ TMenuState }

class function TMenuState.Default: TMenuState;
begin
  Result.Selected := 0;
  Result.Open := True;
end;

{ TMenu }

class function TMenu.Create(const AItems: array of TMenuItem): TMenu;
var I: Integer;
begin
  SetLength(Result.Items, Length(AItems));
  for I := 0 to High(AItems) do
    Result.Items[I] := AItems[I];
  Result.Style := TStyle.Default;
  Result.HighlightStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.DisabledStyle := TStyle.Default.WithModifier([mbDim]);
  Result.Width := 0;
end;

function TMenu.WithStyle(const S: TStyle): TMenu;
begin
  Result := Self;
  Result.Style := S;
end;

function TMenu.WithHighlightStyle(const S: TStyle): TMenu;
begin
  Result := Self;
  Result.HighlightStyle := S;
end;

function TMenu.WithDisabledStyle(const S: TStyle): TMenu;
begin
  Result := Self;
  Result.DisabledStyle := S;
end;

function TMenu.WithWidth(W: Integer): TMenu;
begin
  Result := Self;
  Result.Width := W;
end;

function TMenu.ItemCount: Integer;
begin
  Result := Length(Items);
end;

function TMenu.SelectableCount: Integer;
var I, C: Integer;
begin
  C := 0;
  for I := 0 to High(Items) do
    if (Items[I].Kind <> mikSeparator) and Items[I].Enabled then
      Inc(C);
  Result := C;
end;

procedure TMenu.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TMenuState);
var
  I, Y, W, ShortcutX: Integer;
  Sty: TStyle;
  Line: AnsiString;
begin
  if Area.IsEmpty then Exit;
  if Length(Items) = 0 then Exit;

  W := Width;
  if W <= 0 then W := Area.Width;
  if W > Area.Width then W := Area.Width;

  ABuf.SetStyle(TRect.Make(Area.X, Area.Y, W, Area.Height), Style);

  Y := Area.Y;
  for I := 0 to High(Items) do
  begin
    if Y >= Area.Y + Area.Height then Break;

    if Items[I].Kind = mikSeparator then
    begin
      Line := StringOfChar('-', W);
      ABuf.SetStringN(Area.X, Y, Line, W, Style);
    end
    else
    begin
      if not Items[I].Enabled then
        Sty := DisabledStyle
      else if I = State.Selected then
        Sty := HighlightStyle
      else
        Sty := Style;

      ABuf.SetStyle(TRect.Make(Area.X, Y, W, 1), Sty);
      ABuf.SetStringN(Area.X + 1, Y, Items[I].Label_, W - 2, Sty);

      if Items[I].Shortcut <> '' then
      begin
        ShortcutX := Area.X + W - Integer(StringDisplayWidth(Items[I].Shortcut)) - 1;
        if ShortcutX > Area.X + 1 then
          ABuf.SetStringN(ShortcutX, Y, Items[I].Shortcut,
            Integer(StringDisplayWidth(Items[I].Shortcut)), Sty);
      end;

      if Items[I].Kind = mikSubmenu then
        ABuf.SetStringN(Area.X + W - 2, Y, '>', 1, Sty);
    end;

    Inc(Y);
  end;
end;

procedure TMenu.MoveDown(var State: TMenuState);
var Start, I: Integer;
begin
  if Length(Items) = 0 then Exit;
  Start := State.Selected;
  I := (Start + 1) mod Length(Items);
  while I <> Start do
  begin
    if (Items[I].Kind <> mikSeparator) and Items[I].Enabled then
    begin
      State.Selected := I;
      Exit;
    end;
    I := (I + 1) mod Length(Items);
  end;
end;

procedure TMenu.MoveUp(var State: TMenuState);
var Start, I: Integer;
begin
  if Length(Items) = 0 then Exit;
  Start := State.Selected;
  I := Start - 1;
  if I < 0 then I := High(Items);
  while I <> Start do
  begin
    if (Items[I].Kind <> mikSeparator) and Items[I].Enabled then
    begin
      State.Selected := I;
      Exit;
    end;
    Dec(I);
    if I < 0 then I := High(Items);
  end;
end;

end.
