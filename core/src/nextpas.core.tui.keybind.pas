unit nextpas.core.tui.keybind;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.event;

type
  TKeybindMode = (kmNormal, kmInsert, kmVisual, kmCommand);

  TKeybindActionKind = (kaNone, kaProcedure, kaMethod);
  TKeybindAction = procedure;
  TKeybindMethodAction = procedure of object;

  TKeybinding = record
    Mode: TKeybindMode;
    Code: TKeyCodeKind;
    Ch: Byte;
    Modifiers: TKeyModifiers;
    ActionKind: TKeybindActionKind;
    Action: TKeybindAction;
    MethodAction: TKeybindMethodAction;
    Description: AnsiString;
  end;

  TKeybindManager = class
  private
    FBindings: array of TKeybinding;
    FMode: TKeybindMode;
    FCount: Integer;
    procedure StoreBinding(AMode: TKeybindMode; ACode: TKeyCodeKind; ACh: Byte;
      AMods: TKeyModifiers; AActionKind: TKeybindActionKind;
      AAction: TKeybindAction; AMethodAction: TKeybindMethodAction;
      const ADesc: AnsiString);
  public
    constructor Create;
    procedure SetMode(M: TKeybindMode);
    function Mode: TKeybindMode; inline;
    procedure Bind(AMode: TKeybindMode; ACode: TKeyCodeKind; ACh: Byte;
      AMods: TKeyModifiers; AAction: TKeybindAction; const ADesc: AnsiString);
    procedure BindMethod(AMode: TKeybindMode; ACode: TKeyCodeKind; ACh: Byte;
      AMods: TKeyModifiers; AAction: TKeybindMethodAction; const ADesc: AnsiString);
    procedure BindChar(AMode: TKeybindMode; Ch: Char;
      AAction: TKeybindAction; const ADesc: AnsiString);
    procedure BindCharMethod(AMode: TKeybindMode; Ch: Char;
      AAction: TKeybindMethodAction; const ADesc: AnsiString);
    procedure BindCtrl(AMode: TKeybindMode; Ch: Char;
      AAction: TKeybindAction; const ADesc: AnsiString);
    procedure BindCtrlMethod(AMode: TKeybindMode; Ch: Char;
      AAction: TKeybindMethodAction; const ADesc: AnsiString);
    procedure BindAlt(AMode: TKeybindMode; Ch: Char;
      AAction: TKeybindAction; const ADesc: AnsiString);
    procedure BindAltMethod(AMode: TKeybindMode; Ch: Char;
      AAction: TKeybindMethodAction; const ADesc: AnsiString);
    procedure BindKey(AMode: TKeybindMode; ACode: TKeyCodeKind;
      AAction: TKeybindAction; const ADesc: AnsiString);
    procedure BindKeyMethod(AMode: TKeybindMode; ACode: TKeyCodeKind;
      AAction: TKeybindMethodAction; const ADesc: AnsiString);
    function HandleKey(const K: TKeyEvent): Boolean;
    function BindingCount: Integer; inline;
    function GetBinding(I: Integer): TKeybinding;
    function HelpText: AnsiString;
  end;

implementation

uses
  SysUtils;

constructor TKeybindManager.Create;
begin
  inherited Create;
  FBindings := nil;
  FMode := kmNormal;
  FCount := 0;
end;

procedure TKeybindManager.SetMode(M: TKeybindMode);
begin
  FMode := M;
end;

function TKeybindManager.Mode: TKeybindMode;
begin
  Result := FMode;
end;

procedure TKeybindManager.Bind(AMode: TKeybindMode; ACode: TKeyCodeKind; ACh: Byte;
  AMods: TKeyModifiers; AAction: TKeybindAction; const ADesc: AnsiString);
begin
  StoreBinding(AMode, ACode, ACh, AMods, kaProcedure, AAction, nil, ADesc);
end;

procedure TKeybindManager.BindMethod(AMode: TKeybindMode; ACode: TKeyCodeKind;
  ACh: Byte; AMods: TKeyModifiers; AAction: TKeybindMethodAction;
  const ADesc: AnsiString);
begin
  StoreBinding(AMode, ACode, ACh, AMods, kaMethod, nil, AAction, ADesc);
end;

procedure TKeybindManager.StoreBinding(AMode: TKeybindMode; ACode: TKeyCodeKind;
  ACh: Byte; AMods: TKeyModifiers; AActionKind: TKeybindActionKind;
  AAction: TKeybindAction; AMethodAction: TKeybindMethodAction;
  const ADesc: AnsiString);
begin
  Inc(FCount);
  SetLength(FBindings, FCount);
  FBindings[FCount - 1].Mode := AMode;
  FBindings[FCount - 1].Code := ACode;
  FBindings[FCount - 1].Ch := ACh;
  FBindings[FCount - 1].Modifiers := AMods;
  FBindings[FCount - 1].ActionKind := AActionKind;
  FBindings[FCount - 1].Action := AAction;
  FBindings[FCount - 1].MethodAction := AMethodAction;
  FBindings[FCount - 1].Description := ADesc;
end;

procedure TKeybindManager.BindChar(AMode: TKeybindMode; Ch: Char;
  AAction: TKeybindAction; const ADesc: AnsiString);
begin
  Bind(AMode, kcChar, Ord(Ch), [], AAction, ADesc);
end;

procedure TKeybindManager.BindCharMethod(AMode: TKeybindMode; Ch: Char;
  AAction: TKeybindMethodAction; const ADesc: AnsiString);
begin
  BindMethod(AMode, kcChar, Ord(Ch), [], AAction, ADesc);
end;

procedure TKeybindManager.BindCtrl(AMode: TKeybindMode; Ch: Char;
  AAction: TKeybindAction; const ADesc: AnsiString);
begin
  Bind(AMode, kcChar, Ord(Ch), [kmCtrl], AAction, ADesc);
end;

procedure TKeybindManager.BindCtrlMethod(AMode: TKeybindMode; Ch: Char;
  AAction: TKeybindMethodAction; const ADesc: AnsiString);
begin
  BindMethod(AMode, kcChar, Ord(Ch), [kmCtrl], AAction, ADesc);
end;

procedure TKeybindManager.BindAlt(AMode: TKeybindMode; Ch: Char;
  AAction: TKeybindAction; const ADesc: AnsiString);
begin
  Bind(AMode, kcChar, Ord(Ch), [kmAlt], AAction, ADesc);
end;

procedure TKeybindManager.BindAltMethod(AMode: TKeybindMode; Ch: Char;
  AAction: TKeybindMethodAction; const ADesc: AnsiString);
begin
  BindMethod(AMode, kcChar, Ord(Ch), [kmAlt], AAction, ADesc);
end;

procedure TKeybindManager.BindKey(AMode: TKeybindMode; ACode: TKeyCodeKind;
  AAction: TKeybindAction; const ADesc: AnsiString);
begin
  Bind(AMode, ACode, 0, [], AAction, ADesc);
end;

procedure TKeybindManager.BindKeyMethod(AMode: TKeybindMode; ACode: TKeyCodeKind;
  AAction: TKeybindMethodAction; const ADesc: AnsiString);
begin
  BindMethod(AMode, ACode, 0, [], AAction, ADesc);
end;

function TKeybindManager.HandleKey(const K: TKeyEvent): Boolean;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
  begin
    if FBindings[I].Mode <> FMode then Continue;
    if FBindings[I].Code <> K.Code then Continue;
    if (FBindings[I].Code = kcChar) and (FBindings[I].Ch <> K.Ch) then Continue;
    if FBindings[I].Modifiers <> K.Modifiers then Continue;
    case FBindings[I].ActionKind of
      kaProcedure:
        if Assigned(FBindings[I].Action) then
          FBindings[I].Action();
      kaMethod:
        if Assigned(FBindings[I].MethodAction) then
          FBindings[I].MethodAction();
    else
    end;
    Exit(True);
  end;
  Result := False;
end;

function TKeybindManager.BindingCount: Integer;
begin
  Result := FCount;
end;

function TKeybindManager.GetBinding(I: Integer): TKeybinding;
begin
  Result := FBindings[I];
end;

function TKeybindManager.HelpText: AnsiString;
var
  I: Integer;
  ModeStr, KeyStr, ModStr: AnsiString;
begin
  Result := '';
  for I := 0 to FCount - 1 do
  begin
    case FBindings[I].Mode of
      kmNormal: ModeStr := 'N';
      kmInsert: ModeStr := 'I';
      kmVisual: ModeStr := 'V';
      kmCommand: ModeStr := 'C';
    end;

    ModStr := '';
    if kmCtrl in FBindings[I].Modifiers then ModStr := ModStr + 'C-';
    if kmAlt in FBindings[I].Modifiers then ModStr := ModStr + 'M-';
    if kmShift in FBindings[I].Modifiers then ModStr := ModStr + 'S-';

    if FBindings[I].Code = kcChar then
      KeyStr := ModStr + Chr(FBindings[I].Ch)
    else
      case FBindings[I].Code of
        kcEnter: KeyStr := ModStr + 'Enter';
        kcEsc: KeyStr := ModStr + 'Esc';
        kcBackspace: KeyStr := ModStr + 'BS';
        kcTab: KeyStr := ModStr + 'Tab';
        kcUp: KeyStr := ModStr + 'Up';
        kcDown: KeyStr := ModStr + 'Down';
        kcLeft: KeyStr := ModStr + 'Left';
        kcRight: KeyStr := ModStr + 'Right';
      else
        KeyStr := ModStr + '?';
      end;

    Result := Result + Format('[%s] %-10s %s', [ModeStr, KeyStr, FBindings[I].Description]);
    if I < FCount - 1 then Result := Result + #10;
  end;
end;

end.
