unit np_preprocessor;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  np_base_types;

type
  { Case-insensitive symbol table for {$define}/{$undef}.
    Names are normalized to upper-case (FPC define names are
    case-insensitive). Each entry may carry an optional value
    (for {$define X := value} macros and {$if} value reads). }
  TDefineEntry = record
    Name: string;
    Value: string;
    HasValue: Boolean;
  end;

  TDefineTable = class
  private
    FEntries: array of TDefineEntry;
    FCount: LongInt;
    function IndexOf(const AName: string): LongInt;
  public
    constructor Create;
    procedure Define(const AName: string);
    procedure DefineValue(const AName, AValue: string);
    procedure Undef(const AName: string);
    function IsDefined(const AName: string): Boolean;
    function TryGetValue(const AName: string; out AValue: string): Boolean;
    function ValueOf(const AName: string): string;
    procedure Clear;
    function Count: LongInt;
  end;

implementation

uses
  SysUtils;

constructor TDefineTable.Create;
begin
  inherited Create;
  SetLength(FEntries, 0);
  FCount := 0;
end;

function TDefineTable.IndexOf(const AName: string): LongInt;
var
  I: LongInt;
  Norm: string;
begin
  Norm := UpperCase(AName);
  for I := 0 to FCount - 1 do
    if FEntries[I].Name = Norm then
      Exit(I);
  Result := -1;
end;

procedure TDefineTable.Define(const AName: string);
var
  Idx: LongInt;
begin
  if AName = '' then Exit;
  Idx := IndexOf(AName);
  if Idx >= 0 then
  begin
    FEntries[Idx].Value := '';
    FEntries[Idx].HasValue := False;
    Exit;
  end;
  if FCount >= Length(FEntries) then
    SetLength(FEntries, FCount + 16);
  FEntries[FCount].Name := UpperCase(AName);
  FEntries[FCount].Value := '';
  FEntries[FCount].HasValue := False;
  Inc(FCount);
end;

procedure TDefineTable.DefineValue(const AName, AValue: string);
var
  Idx: LongInt;
begin
  if AName = '' then Exit;
  Idx := IndexOf(AName);
  if Idx >= 0 then
  begin
    FEntries[Idx].Value := AValue;
    FEntries[Idx].HasValue := True;
    Exit;
  end;
  if FCount >= Length(FEntries) then
    SetLength(FEntries, FCount + 16);
  FEntries[FCount].Name := UpperCase(AName);
  FEntries[FCount].Value := AValue;
  FEntries[FCount].HasValue := True;
  Inc(FCount);
end;

procedure TDefineTable.Undef(const AName: string);
var
  Idx, J: LongInt;
begin
  Idx := IndexOf(AName);
  if Idx < 0 then Exit;
  for J := Idx to FCount - 2 do
    FEntries[J] := FEntries[J + 1];
  Dec(FCount);
end;

function TDefineTable.IsDefined(const AName: string): Boolean;
begin
  Result := IndexOf(AName) >= 0;
end;

function TDefineTable.TryGetValue(const AName: string; out AValue: string): Boolean;
var
  Idx: LongInt;
begin
  AValue := '';
  Idx := IndexOf(AName);
  if (Idx < 0) or (not FEntries[Idx].HasValue) then
    Exit(False);
  AValue := FEntries[Idx].Value;
  Result := True;
end;

function TDefineTable.ValueOf(const AName: string): string;
var
  Idx: LongInt;
begin
  Idx := IndexOf(AName);
  if (Idx >= 0) and FEntries[Idx].HasValue then
    Result := FEntries[Idx].Value
  else
    Result := '';
end;

procedure TDefineTable.Clear;
begin
  FCount := 0;
  SetLength(FEntries, 0);
end;

function TDefineTable.Count: LongInt;
begin
  Result := FCount;
end;

end.
