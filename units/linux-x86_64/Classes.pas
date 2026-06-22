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
  fmShareDenyWrite = $0020;

type
  TDuplicates = (dupIgnore, dupAccept, dupError);

  EStreamError = class(Exception);

  TSeekOrigin = (soBeginning, soCurrent, soEnd);

  TStream = class
  protected
    function GetPosition: Int64; virtual;
    procedure SetPosition(const Pos: Int64); virtual;
    function GetSize: Int64; virtual;
    procedure SetSize(const NewSize: Int64); virtual;
  public
    function Read(var Buffer; Count: LongInt): LongInt; virtual;
    function Write(const Buffer; Count: LongInt): LongInt; virtual;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; virtual;
    procedure ReadBuffer(var Buffer; Count: LongInt);
    procedure WriteBuffer(const Buffer; Count: LongInt);
    function ReadByte: Byte;
    procedure WriteByte(B: Byte);
    function CopyFrom(Source: TStream; Count: Int64): Int64;
    property Position: Int64 read GetPosition write SetPosition;
    property Size: Int64 read GetSize write SetSize;
  end;

  TList = class
  private
    FItems: array of Pointer;
    FCount: Integer;
    function GetItem(Index: Integer): Pointer;
    procedure SetItem(Index: Integer; Value: Pointer);
  public
    constructor Create;
    destructor Destroy; override;
    function Add(Item: Pointer): Integer;
    procedure Delete(Index: Integer);
    procedure Clear;
    function IndexOf(Item: Pointer): Integer;
    property Count: Integer read FCount;
    property Items[Index: Integer]: Pointer read GetItem write SetItem; default;
  end;

  TInterfaceList = class
  private
    FItems: array of IInterface;
    FCount: Integer;
    function GetItem(Index: Integer): IInterface;
    procedure SetItem(Index: Integer; const Value: IInterface);
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const Item: IInterface): Integer;
    procedure Delete(Index: Integer);
    procedure Clear;
    function IndexOf(const Item: IInterface): Integer;
    procedure Remove(const Item: IInterface);
    property Count: Integer read FCount;
    property Items[Index: Integer]: IInterface read GetItem write SetItem; default;
  end;

  TFileStream = class(TStream)
  private
    FHandle: File;
    FFileName: string;
  protected
    function GetSize: Int64; override;
  public
    constructor Create(const AFileName: string; Mode: Word);
    destructor Destroy; override;

    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  TStringList = class
  private
    FItems: array of string;
    FObjects: array of TObject;
    FCount: Integer;
    FSorted: Boolean;
    FDelimiter: Char;
    FQuoteChar: Char;
    FDuplicates: TDuplicates;
    FOwnsObjects: Boolean;
    FTextLineBreakStyle: Integer; // 0=LF, 1=CRLF
    function GetString(Index: Integer): string;
    procedure SetString(Index: Integer; const Value: string);
    function GetObject(Index: Integer): TObject;
    procedure SetObject(Index: Integer; Value: TObject);
    function GetValue(const Name: string): string;
    procedure SetValue(const Name, Value: string);
    function GetName(Index: Integer): string;
    function GetText: string;
    procedure SetText(const Value: string);
    function GetDelimitedText: string;
    procedure SetDelimitedText(const Value: string);
    procedure SetSorted(Value: Boolean);
  public
    constructor Create;
    destructor Destroy; override;

    function Add(const S: string): Integer;
    function AddObject(const S: string; AObject: TObject): Integer;
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
    property Sorted: Boolean read FSorted write SetSorted;
    property Delimiter: Char read FDelimiter write FDelimiter;
    property QuoteChar: Char read FQuoteChar write FQuoteChar;
    property Duplicates: TDuplicates read FDuplicates write FDuplicates;
    property DelimitedText: string read GetDelimitedText write SetDelimitedText;
    property OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
    property Strings[Index: Integer]: string read GetString write SetString; default;
    property Names[Index: Integer]: string read GetName;
    property Objects[Index: Integer]: TObject read GetObject write SetObject;
    property Values[const Name: string]: string read GetValue write SetValue;
    property Text: string read GetText write SetText;
  end;

implementation

{ TStream }

function TStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  raise Exception.Create('TStream.Read not implemented');
end;

function TStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  raise Exception.Create('TStream.Write not implemented');
end;

function TStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  raise Exception.Create('TStream.Seek not implemented');
end;

function TStream.ReadByte: Byte;
begin
  Read(Result, 1);
end;

procedure TStream.WriteByte(B: Byte);
begin
  Write(B, 1);
end;

procedure TStream.ReadBuffer(var Buffer; Count: LongInt);
var
  N: LongInt;
begin
  N := Read(Buffer, Count);
  if N <> Count then
    raise Exception.Create('ReadBuffer: insufficient data');
end;

procedure TStream.WriteBuffer(const Buffer; Count: LongInt);
var
  N: LongInt;
begin
  N := Write(Buffer, Count);
  if N <> Count then
    raise Exception.Create('WriteBuffer: write failed');
end;

function TStream.GetPosition: Int64;
begin
  Result := Seek(0, soCurrent);
end;

procedure TStream.SetPosition(const Pos: Int64);
begin
  Seek(Pos, soBeginning);
end;

function TStream.GetSize: Int64;
var
  LPos: Int64;
begin
  LPos := GetPosition;
  Result := Seek(0, soEnd);
  SetPosition(LPos);
end;

procedure TStream.SetSize(const NewSize: Int64);
begin
  // no-op
end;

function TStream.CopyFrom(Source: TStream; Count: Int64): Int64;
const
  BUF_SIZE = 32768;
var
  Buf: array[0..BUF_SIZE - 1] of Byte;
  N: LongInt;
  LRemain: Int64;
begin
  Result := 0;
  if Count = 0 then
  begin
    Source.SetPosition(0);
    Count := Source.GetSize;
  end;
  LRemain := Count;
  while LRemain > 0 do
  begin
    N := Source.Read(Buf[0], BUF_SIZE);
    if N <= 0 then Break;
    Write(Buf[0], N);
    Inc(Result, N);
    Dec(LRemain, N);
  end;
end;

{ TList }

constructor TList.Create;
begin
  inherited Create;
  FCount := 0;
  SetLength(FItems, 0);
end;

destructor TList.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TList.Add(Item: Pointer): Integer;
begin
  SetLength(FItems, FCount + 1);
  FItems[FCount] := Item;
  Result := FCount;
  Inc(FCount);
end;

procedure TList.Delete(Index: Integer);
var
  I: Integer;
begin
  if (Index < 0) or (Index >= FCount) then Exit;
  for I := Index to FCount - 2 do
    FItems[I] := FItems[I + 1];
  Dec(FCount);
  SetLength(FItems, FCount);
end;

procedure TList.Clear;
begin
  SetLength(FItems, 0);
  FCount := 0;
end;

function TList.GetItem(Index: Integer): Pointer;
begin
  if (Index < 0) or (Index >= FCount) then
    Result := nil
  else
    Result := FItems[Index];
end;

procedure TList.SetItem(Index: Integer; Value: Pointer);
begin
  if (Index >= 0) and (Index < FCount) then
    FItems[Index] := Value;
end;

function TList.IndexOf(Item: Pointer): Integer;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FItems[I] = Item then
      Exit(I);
  Result := -1;
end;

{ TInterfaceList }

constructor TInterfaceList.Create;
begin
  inherited Create;
  FCount := 0;
  SetLength(FItems, 0);
end;

destructor TInterfaceList.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TInterfaceList.Add(const Item: IInterface): Integer;
begin
  SetLength(FItems, FCount + 1);
  FItems[FCount] := Item;
  Result := FCount;
  Inc(FCount);
end;

procedure TInterfaceList.Delete(Index: Integer);
var
  I: Integer;
begin
  if (Index < 0) or (Index >= FCount) then Exit;
  FItems[Index] := nil;
  for I := Index to FCount - 2 do
    FItems[I] := FItems[I + 1];
  FItems[FCount - 1] := nil;
  Dec(FCount);
  SetLength(FItems, FCount);
end;

procedure TInterfaceList.Clear;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    FItems[I] := nil;
  SetLength(FItems, 0);
  FCount := 0;
end;

function TInterfaceList.GetItem(Index: Integer): IInterface;
begin
  if (Index < 0) or (Index >= FCount) then
    Result := nil
  else
    Result := FItems[Index];
end;

procedure TInterfaceList.SetItem(Index: Integer; const Value: IInterface);
begin
  if (Index >= 0) and (Index < FCount) then
    FItems[Index] := Value;
end;

function TInterfaceList.IndexOf(const Item: IInterface): Integer;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FItems[I] = Item then
      Exit(I);
  Result := -1;
end;

procedure TInterfaceList.Remove(const Item: IInterface);
var
  Idx: Integer;
begin
  Idx := IndexOf(Item);
  if Idx >= 0 then
    Delete(Idx);
end;

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

function TFileStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  {$I-}
  case Origin of
    soBeginning: System.Seek(FHandle, Offset);
    soEnd: System.Seek(FHandle, FileSize(FHandle) + Offset);
    soCurrent: System.Seek(FHandle, FilePos(FHandle) + Offset);
  end;
  Result := FilePos(FHandle);
  {$I+}
  if IOResult <> 0 then
    Result := -1;
end;

function TFileStream.GetSize: Int64;
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
  FDelimiter := ',';
  FQuoteChar := '"';
  FDuplicates := dupIgnore;
end;

destructor TStringList.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TStringList.Add(const S: string): Integer;
begin
  Result := AddObject(S, nil);
end;

function TStringList.AddObject(const S: string; AObject: TObject): Integer;
begin
  SetLength(FItems, FCount + 1);
  SetLength(FObjects, FCount + 1);
  FItems[FCount] := S;
  FObjects[FCount] := AObject;
  Result := FCount;
  Inc(FCount);
end;

procedure TStringList.Clear;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    FObjects[I] := nil;
  SetLength(FItems, 0);
  SetLength(FObjects, 0);
  FCount := 0;
end;

function TStringList.GetObject(Index: Integer): TObject;
begin
  if (Index < 0) or (Index >= FCount) then
    Result := nil
  else
    Result := FObjects[Index];
end;

procedure TStringList.SetObject(Index: Integer; Value: TObject);
begin
  if (Index >= 0) and (Index < FCount) then
    FObjects[Index] := Value;
end;

procedure TStringList.SetSorted(Value: Boolean);
begin
  FSorted := Value;
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

function TStringList.GetDelimitedText: string;
var
  I: Integer;
  S: string;
begin
  Result := '';
  for I := 0 to FCount - 1 do
  begin
    S := FItems[I];
    if (FQuoteChar <> #0) and (Pos(FDelimiter, S) > 0) or (Pos(FQuoteChar, S) > 0) then
      S := FQuoteChar + S + FQuoteChar;
    if I > 0 then
      Result := Result + FDelimiter;
    Result := Result + S;
  end;
end;

procedure TStringList.SetDelimitedText(const Value: string);
var
  I, L, Start: Integer;
  InQuote: Boolean;
begin
  Clear;
  if Value = '' then Exit;
  I := 1;
  L := Length(Value);
  while I <= L do
  begin
    Start := I;
    InQuote := False;
    if (FQuoteChar <> #0) and (Value[I] = FQuoteChar) then
    begin
      InQuote := True;
      Inc(I);
      Start := I;
      while (I <= L) and (Value[I] <> FQuoteChar) do
        Inc(I);
      Add(Copy(Value, Start, I - Start));
      if (I <= L) and (Value[I] = FQuoteChar) then
        Inc(I);
      if (I <= L) and (Value[I] = FDelimiter) then
        Inc(I);
    end
    else
    begin
      while (I <= L) and (Value[I] <> FDelimiter) do
        Inc(I);
      Add(Copy(Value, Start, I - Start));
      Inc(I);
    end;
  end;
end;

end.
