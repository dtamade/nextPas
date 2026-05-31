unit nextpas.core.tui.app.screen;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.error,
  nextpas.core.tui.event,
  nextpas.core.tui.buffer;

type
  TScreenStack = class;

  EFtuiScreenError = class(ETui);

  TScreen = class
  private
    FStack: TScreenStack;
  public
    property Stack: TScreenStack read FStack write FStack;
    procedure Render(const Area: TRect; Buf: TBuffer); virtual; abstract;
    procedure HandleEvent(const Ev: TEvent); virtual;
    procedure OnEnter; virtual;
    procedure OnLeave; virtual;
  end;

  TScreenStack = class
  private
    FScreens: array of TScreen;
    FCount: Integer;
    FQuitRequested: Boolean;
    procedure ValidateIncomingScreen(AScreen: TScreen; const AOperation: AnsiString);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Push(AScreen: TScreen);
    function Pop: TScreen;
    procedure Replace(AScreen: TScreen);
    function Top: TScreen;
    function Count: Integer; inline;
    function IsEmpty: Boolean; inline;
    procedure RequestQuit; inline;
    procedure ClearQuitRequest; inline;
    function ConsumeQuitRequested: Boolean; inline;
    property QuitRequested: Boolean read FQuitRequested write FQuitRequested;
    procedure Render(const Area: TRect; Buf: TBuffer);
    procedure HandleEvent(const Ev: TEvent);
  end;

implementation

{ TScreen }

procedure TScreen.HandleEvent(const Ev: TEvent);
begin
end;

procedure TScreen.OnEnter;
begin
end;

procedure TScreen.OnLeave;
begin
end;

{ TScreenStack }

constructor TScreenStack.Create;
begin
  inherited Create;
  FCount := 0;
  FScreens := nil;
  FQuitRequested := False;
end;

procedure TScreenStack.ValidateIncomingScreen(AScreen: TScreen;
  const AOperation: AnsiString);
begin
  if AScreen = nil then
    raise EFtuiScreenError.Create('TScreenStack.' + AOperation + ' requires a screen');
  if AScreen.FStack <> nil then
    raise EFtuiScreenError.Create('TScreenStack.' + AOperation + ' received screen already owned by a stack');
end;

destructor TScreenStack.Destroy;
var I: Integer;
begin
  if FCount > 0 then
  begin
    try
      FScreens[FCount - 1].OnLeave;
    except
      // Best-effort teardown: keep freeing owned screens even if the final
      // leave hook refuses to cooperate.
    end;
  end;

  for I := 0 to FCount - 1 do
    FScreens[I].FStack := nil;

  for I := 0 to FCount - 1 do
  begin
    FScreens[I].Free;
    FScreens[I] := nil;
  end;
  inherited;
end;

procedure TScreenStack.Push(AScreen: TScreen);
var
  OldTop: TScreen;
  NewIndex: Integer;
begin
  ValidateIncomingScreen(AScreen, 'Push');
  NewIndex := FCount;
  if NewIndex + 1 > Length(FScreens) then
    SetLength(FScreens, (NewIndex + 1) * 2);

  OldTop := nil;
  if FCount > 0 then
  begin
    OldTop := FScreens[FCount - 1];
    OldTop.OnLeave;
  end;

  FScreens[NewIndex] := AScreen;
  AScreen.FStack := Self;
  Inc(FCount);
  try
    AScreen.OnEnter;
  except
    Dec(FCount);
    FScreens[NewIndex] := nil;
    AScreen.FStack := nil;
    if OldTop <> nil then
    begin
      // Preserve the incoming screen's failure; rollback enter is best-effort.
      try
        OldTop.OnEnter;
      except
      end;
    end;
    raise;
  end;
end;

function TScreenStack.Pop: TScreen;
var
  OldIndex: Integer;
  Resuming: TScreen;
begin
  Result := nil;
  if FCount = 0 then Exit;
  OldIndex := FCount - 1;
  Result := FScreens[OldIndex];
  Result.OnLeave;
  Result.FStack := nil;
  FScreens[OldIndex] := nil;
  Dec(FCount);
  if FCount > 0 then
  begin
    Resuming := FScreens[FCount - 1];
    try
      Resuming.OnEnter;
    except
      Inc(FCount);
      FScreens[OldIndex] := Result;
      Result.FStack := Self;
      // Preserve the resumed screen's failure; rollback enter is best-effort.
      try
        Result.OnEnter;
      except
      end;
      raise;
    end;
  end;
end;

procedure TScreenStack.Replace(AScreen: TScreen);
var
  Old: TScreen;
begin
  ValidateIncomingScreen(AScreen, 'Replace');
  if FCount > 0 then
  begin
    Old := FScreens[FCount - 1];
    Old.OnLeave;
    FScreens[FCount - 1] := AScreen;
    AScreen.FStack := Self;
    try
      AScreen.OnEnter;
    except
      AScreen.FStack := nil;
      FScreens[FCount - 1] := Old;
      // Preserve the incoming screen's failure; rollback enter is best-effort.
      try
        Old.OnEnter;
      except
      end;
      raise;
    end;
    Old.FStack := nil;
    Old.Free;
    Exit;
  end
  else
  begin
    if Length(FScreens) = 0 then
      SetLength(FScreens, 2);
    Inc(FCount);
    FScreens[FCount - 1] := AScreen;
  end;
  AScreen.FStack := Self;
  try
    AScreen.OnEnter;
  except
    AScreen.FStack := nil;
    FScreens[FCount - 1] := nil;
    Dec(FCount);
    raise;
  end;
end;

function TScreenStack.Top: TScreen;
begin
  if FCount = 0 then
    Result := nil
  else
    Result := FScreens[FCount - 1];
end;

function TScreenStack.Count: Integer;
begin
  Result := FCount;
end;

function TScreenStack.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

procedure TScreenStack.RequestQuit;
begin
  FQuitRequested := True;
end;

procedure TScreenStack.ClearQuitRequest;
begin
  FQuitRequested := False;
end;

function TScreenStack.ConsumeQuitRequested: Boolean;
begin
  Result := FQuitRequested;
  FQuitRequested := False;
end;

procedure TScreenStack.Render(const Area: TRect; Buf: TBuffer);
begin
  if FCount > 0 then
    FScreens[FCount - 1].Render(Area, Buf);
end;

procedure TScreenStack.HandleEvent(const Ev: TEvent);
begin
  if FCount > 0 then
    FScreens[FCount - 1].HandleEvent(Ev);
end;

end.
