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
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf;

type
  ICheckbox = interface(IWidget)
    ['{A1B2C3D4-E5F6-4718-9A0B-C1D2E3F4A5B6}']
    function WithStyle(const AStyle: TStyle): ICheckbox;
    function WithCheckedStyle(const AStyle: TStyle): ICheckbox;
    procedure Toggle;
    function IsChecked: Boolean;
  end;

  IRadioGroup = interface(IWidget)
    ['{B2C3D4E5-F6A7-4829-0B1C-D2E3F4A5B6C7}']
    function WithStyle(const AStyle: TStyle): IRadioGroup;
    function WithSelectedStyle(const AStyle: TStyle): IRadioGroup;
    procedure Select(AIdx: Integer);
    function GetSelected: Integer;
  end;

  TCheckbox = class(TInterfacedObject, IWidget, ICheckbox)
  private
    FLabel: AnsiString;
    FChecked: Boolean;
    FStyle: TStyle;
    FCheckedStyle: TStyle;
  public
    class function New(const ALabel: AnsiString; AChecked: Boolean): ICheckbox; static;
    function WithStyle(const AStyle: TStyle): ICheckbox;
    function WithCheckedStyle(const AStyle: TStyle): ICheckbox;
    procedure Toggle;
    function IsChecked: Boolean;
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

  TRadioGroup = class(TInterfacedObject, IWidget, IRadioGroup)
  private
    FItems: array of AnsiString;
    FSelected: Integer;
    FStyle: TStyle;
    FSelectedStyle: TStyle;
  public
    class function New(const AItems: array of AnsiString): IRadioGroup; static;
    function WithStyle(const AStyle: TStyle): IRadioGroup;
    function WithSelectedStyle(const AStyle: TStyle): IRadioGroup;
    procedure Select(AIdx: Integer);
    function GetSelected: Integer;
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

{ TCheckbox }

class function TCheckbox.New(const ALabel: AnsiString; AChecked: Boolean): ICheckbox;
var Obj: TCheckbox;
begin
  Obj := TCheckbox.Create;
  Obj.FLabel := ALabel;
  Obj.FChecked := AChecked;
  Obj.FStyle := TStyle.Default;
  Obj.FCheckedStyle := TStyle.Default;
  Result := Obj;
end;

function TCheckbox.WithStyle(const AStyle: TStyle): ICheckbox;
begin
  FStyle := AStyle;
  Result := Self;
end;

function TCheckbox.WithCheckedStyle(const AStyle: TStyle): ICheckbox;
begin
  FCheckedStyle := AStyle;
  Result := Self;
end;

procedure TCheckbox.Toggle;
begin
  FChecked := not FChecked;
end;

function TCheckbox.IsChecked: Boolean;
begin
  Result := FChecked;
end;

procedure TCheckbox.Render(const AArea: TRect; ABuffer: TBuffer);
var
  Marker, Text: AnsiString;
  Sty: TStyle;
begin
  if AArea.IsEmpty then Exit;
  if FChecked then
  begin
    Marker := '[x] ';
    Sty := FStyle.Patch(FCheckedStyle);
  end
  else
  begin
    Marker := '[ ] ';
    Sty := FStyle;
  end;
  Text := Marker + FLabel;
  ABuffer.SetStringN(AArea.X, AArea.Y, Text, AArea.Width, Sty);
end;

{ TRadioGroup }

class function TRadioGroup.New(const AItems: array of AnsiString): IRadioGroup;
var
  Obj: TRadioGroup;
  I: Integer;
begin
  Obj := TRadioGroup.Create;
  SetLength(Obj.FItems, Length(AItems));
  for I := 0 to High(AItems) do
    Obj.FItems[I] := AItems[I];
  Obj.FSelected := 0;
  Obj.FStyle := TStyle.Default;
  Obj.FSelectedStyle := TStyle.Default;
  Result := Obj;
end;

function TRadioGroup.WithStyle(const AStyle: TStyle): IRadioGroup;
begin
  FStyle := AStyle;
  Result := Self;
end;

function TRadioGroup.WithSelectedStyle(const AStyle: TStyle): IRadioGroup;
begin
  FSelectedStyle := AStyle;
  Result := Self;
end;

procedure TRadioGroup.Select(AIdx: Integer);
begin
  if (AIdx >= 0) and (AIdx < Length(FItems)) then
    FSelected := AIdx;
end;

function TRadioGroup.GetSelected: Integer;
begin
  Result := FSelected;
end;

procedure TRadioGroup.Render(const AArea: TRect; ABuffer: TBuffer);
var
  I, Y, MaxRows: Integer;
  Marker, Text: AnsiString;
  Sty: TStyle;
begin
  if AArea.IsEmpty then Exit;
  MaxRows := AArea.Height;
  Y := AArea.Y;
  for I := 0 to High(FItems) do
  begin
    if I >= MaxRows then Break;
    if I = FSelected then
    begin
      Marker := '(*) ';
      Sty := FStyle.Patch(FSelectedStyle);
    end
    else
    begin
      Marker := '( ) ';
      Sty := FStyle;
    end;
    Text := Marker + FItems[I];
    ABuffer.SetStringN(AArea.X, Y, Text, AArea.Width, Sty);
    Inc(Y);
  end;
end;

end.
