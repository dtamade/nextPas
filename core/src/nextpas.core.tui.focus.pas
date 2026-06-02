unit nextpas.core.tui.focus;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.event;

type
  TFocusId = UInt32;

  TFocusEntry = packed record
    Id: TFocusId;
    Area: TRect;
    TabOrder: Word;
    Enabled: Boolean;
  end;

  TFocusNav = (fnNext, fnPrev, fnUp, fnDown, fnLeft, fnRight);

  TFocusManager = class
  private
    FEntries: array of TFocusEntry;
    FCount: Integer;
    FCurrent: TFocusId;
    FGenCounter: TFocusId;
    function IndexOf(Id: TFocusId): Integer;
    function FindNearest(Nav: TFocusNav): Integer;
    procedure NavigateTabOrder(Forward: Boolean);
  public
    constructor Create;
    procedure BeginFrame;
    procedure ResetSession;
    function Register(const Area: TRect; TabOrder: Word = 0): TFocusId;
    procedure RegisterWithId(Id: TFocusId; const Area: TRect; TabOrder: Word = 0);
    function IsFocused(Id: TFocusId): Boolean; inline;
    function FocusedId: TFocusId; inline;
    function FocusedArea: TRect;
    function EntryCount: Integer; inline;
    procedure Navigate(Nav: TFocusNav);
    procedure FocusOn(Id: TFocusId);
    function HandleKey(const K: TKeyEvent): Boolean;
  end;

const
  FOCUS_NONE: TFocusId = 0;

implementation

constructor TFocusManager.Create;
begin
  inherited;
  SetLength(FEntries, 16);
  FCount := 0;
  FCurrent := FOCUS_NONE;
  FGenCounter := 0;
end;

procedure TFocusManager.BeginFrame;
begin
  FCount := 0;
end;

procedure TFocusManager.ResetSession;
begin
  FCount := 0;
  FCurrent := FOCUS_NONE;
end;

function TFocusManager.Register(const Area: TRect; TabOrder: Word): TFocusId;
begin
  Inc(FGenCounter);
  Result := FGenCounter;
  RegisterWithId(Result, Area, TabOrder);
end;

procedure TFocusManager.RegisterWithId(Id: TFocusId; const Area: TRect; TabOrder: Word);
begin
  if FCount >= Length(FEntries) then
    SetLength(FEntries, Length(FEntries) * 2);
  FEntries[FCount].Id := Id;
  FEntries[FCount].Area := Area;
  FEntries[FCount].TabOrder := TabOrder;
  FEntries[FCount].Enabled := True;
  Inc(FCount);
  if (FCurrent = FOCUS_NONE) and (FCount = 1) then
    FCurrent := Id;
end;

function TFocusManager.IsFocused(Id: TFocusId): Boolean;
begin
  Result := (Id <> FOCUS_NONE) and (Id = FCurrent);
end;

function TFocusManager.FocusedId: TFocusId;
begin
  Result := FCurrent;
end;

function TFocusManager.EntryCount: Integer;
begin
  Result := FCount;
end;

function TFocusManager.FocusedArea: TRect;
var Idx: Integer;
begin
  Idx := IndexOf(FCurrent);
  if Idx >= 0 then
    Result := FEntries[Idx].Area
  else
    Result := TRect.Make(0, 0, 0, 0);
end;

function TFocusManager.IndexOf(Id: TFocusId): Integer;
var I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FEntries[I].Id = Id then Exit(I);
  Result := -1;
end;

procedure TFocusManager.FocusOn(Id: TFocusId);
begin
  if IndexOf(Id) >= 0 then
    FCurrent := Id;
end;
procedure TFocusManager.NavigateTabOrder(Forward: Boolean);
var
  CurIdx, I, Next: Integer;
begin
  if FCount = 0 then Exit;
  CurIdx := IndexOf(FCurrent);
  if CurIdx < 0 then begin FCurrent := FEntries[0].Id; Exit; end;
  if Forward then
  begin
    Next := (CurIdx + 1) mod FCount;
    for I := 0 to FCount - 1 do
    begin
      if FEntries[Next].Enabled then begin FCurrent := FEntries[Next].Id; Exit; end;
      Next := (Next + 1) mod FCount;
    end;
  end
  else
  begin
    Next := (CurIdx - 1 + FCount) mod FCount;
    for I := 0 to FCount - 1 do
    begin
      if FEntries[Next].Enabled then begin FCurrent := FEntries[Next].Id; Exit; end;
      Next := (Next - 1 + FCount) mod FCount;
    end;
  end;
end;

function TFocusManager.FindNearest(Nav: TFocusNav): Integer;
var
  CurIdx, I, Best, Dist, BestDist: Integer;
  CX, CY, TX, TY: Integer;
begin
  Result := -1;
  CurIdx := IndexOf(FCurrent);
  if CurIdx < 0 then Exit;
  CX := FEntries[CurIdx].Area.X + FEntries[CurIdx].Area.Width div 2;
  CY := FEntries[CurIdx].Area.Y + FEntries[CurIdx].Area.Height div 2;
  Best := -1;
  BestDist := MaxInt;
  for I := 0 to FCount - 1 do
  begin
    if I = CurIdx then Continue;
    if not FEntries[I].Enabled then Continue;
    TX := FEntries[I].Area.X + FEntries[I].Area.Width div 2;
    TY := FEntries[I].Area.Y + FEntries[I].Area.Height div 2;
    case Nav of
      fnUp:    if TY >= CY then Continue;
      fnDown:  if TY <= CY then Continue;
      fnLeft:  if TX >= CX then Continue;
      fnRight: if TX <= CX then Continue;
    else Continue;
    end;
    Dist := Abs(TX - CX) + Abs(TY - CY);
    if Dist < BestDist then begin BestDist := Dist; Best := I; end;
  end;
  Result := Best;
end;

procedure TFocusManager.Navigate(Nav: TFocusNav);
var Idx: Integer;
begin
  case Nav of
    fnNext: NavigateTabOrder(True);
    fnPrev: NavigateTabOrder(False);
  else
    begin
      Idx := FindNearest(Nav);
      if Idx >= 0 then FCurrent := FEntries[Idx].Id;
    end;
  end;
end;

function TFocusManager.HandleKey(const K: TKeyEvent): Boolean;
begin
  Result := False;
  if K.Code = kcTab then
  begin
    if kmShift in K.Modifiers then
      Navigate(fnPrev)
    else
      Navigate(fnNext);
    Result := True;
  end;
end;

end.
