unit nextpas.core.tui.widget.form;

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
  nextpas.core.tui.buffer;

type
  TCheckbox = record
    Label_: AnsiString;
    Checked: Boolean;
    Style: TStyle;
    CheckedStyle: TStyle;

    class function Create(const ALabel: AnsiString; AChecked: Boolean): TCheckbox; static;
    function WithStyle(const S: TStyle): TCheckbox;
    function WithCheckedStyle(const S: TStyle): TCheckbox;
    procedure Render(const Area: TRect; ABuf: TBuffer);
    procedure Toggle;
  end;

  TRadioGroup = record
    Items: array of AnsiString;
    Selected: Integer;
    Style: TStyle;
    SelectedStyle: TStyle;

    class function Create(const AItems: array of AnsiString): TRadioGroup; static;
    function WithStyle(const S: TStyle): TRadioGroup;
    function WithSelectedStyle(const S: TStyle): TRadioGroup;
    procedure Select(Idx: Integer);
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

implementation

{ TCheckbox }

class function TCheckbox.Create(const ALabel: AnsiString; AChecked: Boolean): TCheckbox;
begin
  Result.Label_ := ALabel;
  Result.Checked := AChecked;
  Result.Style := TStyle.Default;
  Result.CheckedStyle := TStyle.Default;
end;

function TCheckbox.WithStyle(const S: TStyle): TCheckbox;
begin
  Result := Self;
  Result.Style := S;
end;

function TCheckbox.WithCheckedStyle(const S: TStyle): TCheckbox;
begin
  Result := Self;
  Result.CheckedStyle := S;
end;

procedure TCheckbox.Toggle;
begin
  Checked := not Checked;
end;

procedure TCheckbox.Render(const Area: TRect; ABuf: TBuffer);
var
  Marker, Text: AnsiString;
  Sty: TStyle;
begin
  if Area.IsEmpty then Exit;
  if Checked then
  begin
    Marker := '[x] ';
    Sty := Style.Patch(CheckedStyle);
  end
  else
  begin
    Marker := '[ ] ';
    Sty := Style;
  end;
  Text := Marker + Label_;
  ABuf.SetStringN(Area.X, Area.Y, Text, Area.Width, Sty);
end;

{ TRadioGroup }

class function TRadioGroup.Create(const AItems: array of AnsiString): TRadioGroup;
var I: Integer;
begin
  SetLength(Result.Items, Length(AItems));
  for I := 0 to High(AItems) do
    Result.Items[I] := AItems[I];
  Result.Selected := 0;
  Result.Style := TStyle.Default;
  Result.SelectedStyle := TStyle.Default;
end;

function TRadioGroup.WithStyle(const S: TStyle): TRadioGroup;
begin
  Result := Self;
  Result.Style := S;
end;

function TRadioGroup.WithSelectedStyle(const S: TStyle): TRadioGroup;
begin
  Result := Self;
  Result.SelectedStyle := S;
end;

procedure TRadioGroup.Select(Idx: Integer);
begin
  if (Idx >= 0) and (Idx < Length(Items)) then
    Selected := Idx;
end;

procedure TRadioGroup.Render(const Area: TRect; ABuf: TBuffer);
var
  I, Y, MaxRows: Integer;
  Marker, Text: AnsiString;
  Sty: TStyle;
begin
  if Area.IsEmpty then Exit;
  MaxRows := Area.Height;
  Y := Area.Y;
  for I := 0 to High(Items) do
  begin
    if I >= MaxRows then Break;
    if I = Selected then
    begin
      Marker := '(*) ';
      Sty := Style.Patch(SelectedStyle);
    end
    else
    begin
      Marker := '( ) ';
      Sty := Style;
    end;
    Text := Marker + Items[I];
    ABuf.SetStringN(Area.X, Y, Text, Area.Width, Sty);
    Inc(Y);
  end;
end;

end.
