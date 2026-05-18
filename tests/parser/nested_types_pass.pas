program Nested_types_pass;

{$mode objfpc}{$H+}

type
  TStatus = (stIdle, stRunning, stDone, stError);

  TCallback = procedure(Sender: TObject; Status: TStatus);

  TConfig = record
    Name: string;
    Value: Integer;
    Enabled: Boolean;
  end;

  TConfigArray = array of TConfig;

  PConfig = ^TConfig;

  TManager = class
  private
    FItems: TConfigArray;
    FCount: Integer;
    FCallback: TCallback;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const AName: string; AValue: Integer);
    function Find(const AName: string): PConfig;
    function GetCount: Integer;
    property Count: Integer read GetCount;
    property OnChange: TCallback read FCallback write FCallback;
  end;

constructor TManager.Create;
begin
  FCount := 0;
  FCallback := nil;
end;

destructor TManager.Destroy;
begin
  SetLength(FItems, 0);
  inherited Destroy;
end;

procedure TManager.Add(const AName: string; AValue: Integer);
begin
  Inc(FCount);
  SetLength(FItems, FCount);
  FItems[FCount - 1].Name := AName;
  FItems[FCount - 1].Value := AValue;
  FItems[FCount - 1].Enabled := True;
end;

function TManager.Find(const AName: string): PConfig;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FCount - 1 do
    if FItems[I].Name = AName then
    begin
      Result := @FItems[I];
      Exit;
    end;
end;

function TManager.GetCount: Integer;
begin
  Result := FCount;
end;

var
  Mgr: TManager;
  Cfg: PConfig;
begin
  Mgr := TManager.Create;
  try
    Mgr.Add('debug', 1);
    Mgr.Add('verbose', 0);
    Cfg := Mgr.Find('debug');
    if Cfg <> nil then
      Cfg^.Value := 2;
  finally
    Mgr.Free;
  end;
end.
