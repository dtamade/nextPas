unit Classes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  fmOpenRead = $0000;
  fmOpenWrite = $0001;
  fmOpenReadWrite = $0002;
  fmCreate = $FF00;
  fmShareDenyNone = $0040;

type
  TFileStream = class
  private
    FHandle: File;
    FFileName: string;
    function GetSize: LongInt;
  public
    constructor Create(const AFileName: string; Mode: Word);
    destructor Destroy; override;

    function Read(var Buffer; Count: LongInt): LongInt;
    function Write(const Buffer; Count: LongInt): LongInt;
    procedure ReadBuffer(var Buffer; Count: LongInt);
    procedure WriteBuffer(const Buffer; Count: LongInt);
    function Seek(Offset: LongInt; Origin: Word): LongInt;
    property Size: LongInt read GetSize;
  end;

  TStringList = class
  private
    FItems: array of string;
    FCount: Integer;
    FTextLineBreakStyle: Integer; // 0=LF, 1=CRLF
    function GetString(Index: Integer): string;
    procedure SetString(Index: Integer; const Value: string);
    function GetValue(const Name: string): string;
    procedure SetValue(const Name, Value: string);
    function GetName(Index: Integer): string;
    function GetText: string;
    procedure SetText(const Value: string);
  public
    constructor Create;
    destructor Destroy; override;

    function Add(const S: string): Integer;
    procedure Insert(Index: Integer; const S: string);
    procedure Clear;
    function IndexOf(const S: string): Integer;
    function IndexOfName(const Name: string): Integer;
    procedure Delete(Index: Integer);
    procedure LoadFromFile(const FileName: string);
    procedure SaveToFile(const FileName: string);
    procedure LoadFromStream(AStream: TFileStream);
    procedure AddStrings(AList: TStringList);

    property Count: Integer read FCount;
    property Strings[Index: Integer]: string read GetString write SetString; default;
    property Names[Index: Integer]: string read GetName;
    property Values[const Name: string]: string read GetValue write SetValue;
    property Text: string read GetText write SetText;
  end;

implementation

{ TFileStream }

constructor TFileStream.Create(const AFileName: string; Mode: Word);
begin
  inherited Create;
  FFileName := AFileName;
  Assign(FHandle, AFileName);
  {$I-}
  if (Mode and fmOpenWrite) <> 0 then
    Rewrite(FHandle, 1)
  else
    Reset(FHandle, 1);
  {$I+}
  if IOResult <> 0 then
    raise Exception.Create('Cannot open file: ' + AFileName);
end;

destructor TFileStream.Destroy;
begin
  {$I-}
  Close(FHandle);
  {$I+}
  IOResult; // Clear error
  inherited Destroy;
end;

function TFileStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  {$I-}
  BlockRead(FHandle, Buffer, Count, Result);
  {$I+}
  if IOResult <> 0 then
    Result := 0;
end;

function TFileStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  {$I-}
  BlockWrite(FHandle, Buffer, Count, Result);
  {$I+}
  if IOResult <> 0 then
    Result := 0;
end;

procedure TFileStream.ReadBuffer(var Buffer; Count: LongInt);
var
  BytesRead: LongInt;
begin
  BytesRead := Read(Buffer, Count);
  if BytesRead <> Count then
    raise Exception.Create('Read error');
end;

procedure TFileStream.WriteBuffer(const Buffer; Count: LongInt);
var
  BytesWritten: LongInt;
begin
  BytesWritten := Write(Buffer, Count);
  if BytesWritten <> Count then
    raise Exception.Create('Write error');
end;

function TFileStream.Seek(Offset: LongInt; Origin: Word): LongInt;
begin
  {$I-}
  System.Seek(FHandle, Offset);
  Result := FilePos(FHandle);
  {$I+}
  if IOResult <> 0 then
    Result := -1;
end;

function TFileStream.GetSize: LongInt;
begin
  {$I-}
  Result := FileSize(FHandle);
  {$I+}
  if IOResult <> 0 then
    Result := 0;
end;

{ TStringList }

constructor TStringList.Create;
begin
  inherited Create;
  FCount := 0;
  SetLength(FItems, 0);
end;

destructor TStringList.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TStringList.Add(const S: string): Integer;
begin
  SetLength(FItems, FCount + 1);
  FItems[FCount] := S;
  Result := FCount;
  Inc(FCount);
end;

procedure TStringList.Clear;
begin
  SetLength(FItems, 0);
  FCount := 0;
end;

function TStringList.IndexOf(const S: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FItems[I] = S then
      Exit(I);
  Result := -1;
end;

procedure TStringList.Delete(Index: Integer);
var
  I: Integer;
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.Create('Index out of bounds');

  for I := Index to FCount - 2 do
    FItems[I] := FItems[I + 1];

  Dec(FCount);
  SetLength(FItems, FCount);
end;

procedure TStringList.LoadFromFile(const FileName: string);
var
  F: Text;
  Line: string;
begin
  Clear;
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then
    raise Exception.Create('Cannot open file: ' + FileName);

  try
    while not Eof(F) do
    begin
      ReadLn(F, Line);
      Add(Line);
    end;
  finally
    Close(F);
  end;
end;

procedure TStringList.SaveToFile(const FileName: string);
var
  F: Text;
  I: Integer;
begin
  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  if IOResult <> 0 then
    raise Exception.Create('Cannot create file: ' + FileName);

  try
    for I := 0 to FCount - 1 do
      WriteLn(F, FItems[I]);
  finally
    Close(F);
  end;
end;

function TStringList.GetString(Index: Integer): string;
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.Create('Index out of bounds');
  Result := FItems[Index];
end;

procedure TStringList.SetString(Index: Integer; const Value: string);
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.Create('Index out of bounds');
  FItems[Index] := Value;
end;

procedure TStringList.Insert(Index: Integer; const S: string);
var
  I: Integer;
begin
  if (Index < 0) or (Index > FCount) then
    raise Exception.Create('Index out of bounds');
  SetLength(FItems, FCount + 1);
  for I := FCount downto Index + 1 do
    FItems[I] := FItems[I - 1];
  FItems[Index] := S;
  Inc(FCount);
end;

function TStringList.IndexOfName(const Name: string): Integer;
var
  I, P: Integer;
begin
  for I := 0 to FCount - 1 do
  begin
    P := Pos('=', FItems[I]);
    if (P > 0) and (Copy(FItems[I], 1, P - 1) = Name) then
      Exit(I);
  end;
  Result := -1;
end;

function TStringList.GetName(Index: Integer): string;
var
  P: Integer;
begin
  if (Index < 0) or (Index >= FCount) then
    Exit('');
  P := Pos('=', FItems[Index]);
  if P > 0 then
    Result := Copy(FItems[Index], 1, P - 1)
  else
    Result := FItems[Index];
end;

function TStringList.GetValue(const Name: string): string;
var
  I: Integer;
begin
  I := IndexOfName(Name);
  if I >= 0 then
    Result := Copy(FItems[I], Length(Name) + 2, MaxInt)
  else
    Result := '';
end;

procedure TStringList.SetValue(const Name, Value: string);
var
  I: Integer;
begin
  I := IndexOfName(Name);
  if I >= 0 then
    FItems[I] := Name + '=' + Value
  else
    Add(Name + '=' + Value);
end;

function TStringList.GetText: string;
var
  I: Integer;
  Sep: string;
begin
  if FCount = 0 then
    Exit('');
  Sep := #10;
  Result := FItems[0];
  for I := 1 to FCount - 1 do
    Result := Result + Sep + FItems[I];
end;

procedure TStringList.SetText(const Value: string);
var
  I, L, Start: Integer;
begin
  Clear;
  I := 1;
  L := Length(Value);
  while I <= L do
  begin
    Start := I;
    while (I <= L) and (Value[I] <> #10) and (Value[I] <> #13) do
      Inc(I);
    Add(Copy(Value, Start, I - Start));
    while (I <= L) and ((Value[I] = #10) or (Value[I] = #13)) do
      Inc(I);
  end;
end;

procedure TStringList.LoadFromStream(AStream: TFileStream);
var
  Buf: string;
  N: LongInt;
begin
  if AStream = nil then Exit;
  SetLength(Buf, AStream.Size);
  N := AStream.Read(Buf[1], Length(Buf));
  SetLength(Buf, N);
  SetText(Buf);
end;

procedure TStringList.AddStrings(AList: TStringList);
var
  I: Integer;
begin
  if AList = nil then Exit;
  for I := 0 to AList.Count - 1 do
    Add(AList[I]);
end;

end.
