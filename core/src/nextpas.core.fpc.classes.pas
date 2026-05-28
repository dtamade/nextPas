unit nextpas.core.fpc.classes;

{$I nextpas.core.settings.inc}

interface

type
  TStringList = class
  private
    FItems: array of string;
    FCount: Integer;
    FCapacity: Integer;
    function GetItem(Index: Integer): string;
    procedure SetItem(Index: Integer; const Value: string);
    procedure Grow;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const S: string): Integer;
    procedure Delete(Index: Integer);
    procedure Clear;
    procedure LoadFromFile(const FileName: string);
    procedure SaveToFile(const FileName: string);
    function IndexOf(const S: string): Integer;
    procedure SetText(const Value: string);
    function GetText: string;
    property Count: Integer read FCount;
    property Strings[Index: Integer]: string read GetItem write SetItem; default;
    property Text: string read GetText write SetText;
  end;

implementation

uses
  nextpas.core.fpc.sysutils,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.platform.fs;

constructor TStringList.Create;
begin
  inherited Create;
  FCount := 0;
  FCapacity := 0;
  SetLength(FItems, 0);
end;

destructor TStringList.Destroy;
begin
  SetLength(FItems, 0);
  inherited Destroy;
end;

procedure TStringList.Grow;
var NewCap: Integer;
begin
  if FCapacity = 0 then
    NewCap := 16
  else
    NewCap := FCapacity * 2;
  SetLength(FItems, NewCap);
  FCapacity := NewCap;
end;

function TStringList.GetItem(Index: Integer): string;
begin
  if (Index < 0) or (Index >= FCount) then
    RunError(201);
  Result := FItems[Index];
end;

procedure TStringList.SetItem(Index: Integer; const Value: string);
begin
  if (Index < 0) or (Index >= FCount) then
    RunError(201);
  FItems[Index] := Value;
end;

function TStringList.Add(const S: string): Integer;
begin
  if FCount >= FCapacity then Grow;
  FItems[FCount] := S;
  Result := FCount;
  Inc(FCount);
end;

procedure TStringList.Delete(Index: Integer);
var I: Integer;
begin
  if (Index < 0) or (Index >= FCount) then
    RunError(201);
  for I := Index to FCount - 2 do
    FItems[I] := FItems[I + 1];
  FItems[FCount - 1] := '';
  Dec(FCount);
end;

procedure TStringList.Clear;
var I: Integer;
begin
  for I := 0 to FCount - 1 do
    FItems[I] := '';
  FCount := 0;
end;

function TStringList.IndexOf(const S: string): Integer;
var I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FItems[I] = S then Exit(I);
  Result := -1;
end;

procedure TStringList.LoadFromFile(const FileName: string);
var
  H: TPlatformFileHandle;
  LSize: Int64;
  LBuf: PAnsiChar;
  LRead: PtrUInt;
  LContent: string;
begin
  Clear;
  if platform_fs_file_size(PAnsiChar(FileName), LSize) <> 0 then Exit;
  if LSize = 0 then Exit;
  if platform_file_open(PAnsiChar(FileName), fomReadOnly, fcmOpenExisting, H) <> 0 then Exit;
  GetMem(LBuf, LSize + 1);
  try
    platform_file_read(H, LBuf, PtrUInt(LSize), LRead);
    platform_file_close(H);
    LBuf[LRead] := #0;
    SetString(LContent, LBuf, LRead);
  finally
    FreeMem(LBuf);
  end;
  SetText(LContent);
end;

procedure TStringList.SaveToFile(const FileName: string);
var
  H: TPlatformFileHandle;
  LContent: string;
  LWritten: PtrUInt;
begin
  LContent := GetText;
  if platform_file_open(PAnsiChar(FileName), fomWriteOnly, fcmCreateAlways, H) <> 0 then Exit;
  if Length(LContent) > 0 then
    platform_file_write(H, @LContent[1], PtrUInt(Length(LContent)), LWritten);
  platform_file_close(H);
end;

procedure TStringList.SetText(const Value: string);
var
  I, LStart, LLen: Integer;
begin
  Clear;
  LLen := Length(Value);
  LStart := 1;
  I := 1;
  while I <= LLen do
  begin
    if Value[I] = #10 then
    begin
      if (I > LStart) and (Value[I - 1] = #13) then
        Add(Copy(Value, LStart, I - LStart - 1))
      else
        Add(Copy(Value, LStart, I - LStart));
      LStart := I + 1;
    end;
    Inc(I);
  end;
  if LStart <= LLen then
    Add(Copy(Value, LStart, LLen - LStart + 1));
end;

function TStringList.GetText: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FCount - 1 do
  begin
    if I > 0 then
      Result := Result + LineEnding;
    Result := Result + FItems[I];
  end;
  if FCount > 0 then
    Result := Result + LineEnding;
end;

end.
