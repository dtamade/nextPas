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

  TStream = class
  public
    function Read(var Buffer; Count: Longint): Longint; virtual; abstract;
    function Write(const Buffer; Count: Longint): Longint; virtual; abstract;
    function Seek(Offset: Int64; Origin: Integer): Int64; virtual; abstract;
    procedure ReadBuffer(var Buffer; Count: Longint);
    procedure WriteBuffer(const Buffer; Count: Longint);
    function GetSize: Int64; virtual;
    function GetPosition: Int64; virtual;
    procedure SetPosition(Value: Int64); virtual;
    property Size: Int64 read GetSize;
    property Position: Int64 read GetPosition write SetPosition;
  end;

  TFileStream = class(TStream)
  private
    FHandle: Int32;
    FFileName: string;
  public
    constructor Create(const AFileName: string; Mode: Word);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Int64; Origin: Integer): Int64; override;
    property FileName: string read FFileName;
  end;

const
  fmCreate = $FF00;

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
  LBuf: Pointer;
  LLen: PtrUInt;
  LContent: string;
begin
  Clear;
  if platform_fs_read_file(PAnsiChar(FileName), LBuf, LLen) <> 0 then Exit;
  if LLen = 0 then
  begin
    platform_fs_free_buf(LBuf);
    Exit;
  end;
  SetString(LContent, PAnsiChar(LBuf), LLen);
  platform_fs_free_buf(LBuf);
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

{ --- TStream --- }

procedure TStream.ReadBuffer(var Buffer; Count: Longint);
begin
  if Read(Buffer, Count) <> Count then
    RunError(100);
end;

procedure TStream.WriteBuffer(const Buffer; Count: Longint);
begin
  if Write(Buffer, Count) <> Count then
    RunError(101);
end;

function TStream.GetSize: Int64;
var LPos: Int64;
begin
  LPos := Seek(0, 1);
  Result := Seek(0, 2);
  Seek(LPos, 0);
end;

function TStream.GetPosition: Int64;
begin
  Result := Seek(0, 1);
end;

procedure TStream.SetPosition(Value: Int64);
begin
  Seek(Value, 0);
end;

{ --- TFileStream --- }

constructor TFileStream.Create(const AFileName: string; Mode: Word);
var
  LH: TPlatformFileHandle;
  LMode: TPlatformFileOpenMode;
  LCreate: TPlatformFileCreateMode;
begin
  inherited Create;
  FFileName := AFileName;
  if Mode = fmCreate then
  begin
    LMode := fomReadWrite;
    LCreate := fcmCreateAlways;
  end
  else
  begin
    case Mode and $03 of
      0: LMode := fomReadOnly;
      1: LMode := fomWriteOnly;
    else
      LMode := fomReadWrite;
    end;
    LCreate := fcmOpenExisting;
  end;
  if platform_file_open(PAnsiChar(AFileName), LMode, LCreate, LH) <> 0 then
    RunError(2);
{$IFDEF NEXTPAS_WINDOWS}
  FHandle := Int32(PtrUInt(LH.Value));
{$ELSE}
  FHandle := LH.Value;
{$ENDIF}
end;

destructor TFileStream.Destroy;
var LH: TPlatformFileHandle;
begin
  if FHandle >= 0 then
  begin
    LH.Value := {$IFDEF NEXTPAS_WINDOWS}HANDLE(PtrUInt(FHandle)){$ELSE}FHandle{$ENDIF};
    platform_file_close(LH);
  end;
  inherited Destroy;
end;

function TFileStream.Read(var Buffer; Count: Longint): Longint;
var
  LH: TPlatformFileHandle;
  LRead: PtrUInt;
begin
  LH.Value := {$IFDEF NEXTPAS_WINDOWS}HANDLE(PtrUInt(FHandle)){$ELSE}FHandle{$ENDIF};
  if platform_file_read(LH, @Buffer, PtrUInt(Count), LRead) = 0 then
    Result := Longint(LRead)
  else
    Result := 0;
end;

function TFileStream.Write(const Buffer; Count: Longint): Longint;
var
  LH: TPlatformFileHandle;
  LWritten: PtrUInt;
begin
  LH.Value := {$IFDEF NEXTPAS_WINDOWS}HANDLE(PtrUInt(FHandle)){$ELSE}FHandle{$ENDIF};
  if platform_file_write(LH, @Buffer, PtrUInt(Count), LWritten) = 0 then
    Result := Longint(LWritten)
  else
    Result := 0;
end;

function TFileStream.Seek(Offset: Int64; Origin: Integer): Int64;
var
  LH: TPlatformFileHandle;
  LOrigin: TPlatformFileSeekOrigin;
begin
  LH.Value := {$IFDEF NEXTPAS_WINDOWS}HANDLE(PtrUInt(FHandle)){$ELSE}FHandle{$ENDIF};
  case Origin of
    0: LOrigin := fsoBegin;
    1: LOrigin := fsoCurrent;
  else
    LOrigin := fsoEnd;
  end;
  if platform_file_seek(LH, Offset, LOrigin, Result) <> 0 then
    Result := -1;
end;

end.
