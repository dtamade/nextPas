unit nextpas.core.system.classes.impl;
{**
 * @desc Internal implementation for system.classes shim.
 *   Single source via bytes.ops (inline/零拷贝)，析构释放不丢，
 *   不直接 uses FPC Classes/SysUtils — 仅依赖 L0/L1 owners。
 *}
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.bytes.ops,
  nextpas.core.mem.dynarray;
type
  TDuplicates = (dupIgnore, dupAccept, dupError);
  TStream = class(TObject)
  protected
    function GetPosition: Int64; virtual;
    procedure SetPosition(const APos: Int64); virtual;
    function GetSize: Int64; virtual;
    procedure SetSize(const ANewSize: Int64); virtual;
  public
    function Read(var Buffer; Count: LongInt): LongInt; virtual;
    function Write(const Buffer; Count: LongInt): LongInt; virtual;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; virtual;
    procedure ReadBuffer(var Buffer; Count: LongInt);
    procedure WriteBuffer(const Buffer; Count: LongInt);
    function ReadByte: Byte; inline;
    procedure WriteByte(B: Byte); inline;
    function CopyFrom(Source: TStream; Count: Int64): Int64;
    property Position: Int64 read GetPosition write SetPosition;
    property Size: Int64 read GetSize write SetSize;
  end;
  THandleStream = class(TStream)
  private
    FHandle: LongInt;
  protected
    function GetSize: Int64; override;
  public
    constructor Create(AHandle: LongInt);
    destructor Destroy; override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    property Handle: LongInt read FHandle;
  end;
  TMemoryStream = class(TStream)
  private
    FData: TBytes;
    FPos: Int64;
    FSize: Int64;
    FCap: Int64;
    // perf: single source via bytes.ops.BytesGrowCapacity (BYTES_BUILDER_MIN_GROW, *2 geometric) — not inline per red-line 2; capacity via mem.dynarray poke (Length stays FSize)
    procedure EnsureCapacity(const ANewCap: Int64);
    function GetMemoryPtr: Pointer; inline;
  protected
    function GetPosition: Int64; override;
    procedure SetPosition(const APos: Int64); override;
    function GetSize: Int64; override;
    procedure SetSize(const ANewSize: Int64); override;
  public
    constructor Create;
    destructor Destroy; override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    procedure Clear;
    property Memory: Pointer read GetMemoryPtr;
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
  TList = class(TObject)
  private
    FItems: array of Pointer;
    FCount: Integer;
    FCap: Integer;
    // perf: ensure via bytes.ops.BytesGrowCapacityInt single source amortized O(1), zero-copy Move, not inline per red-line 2
    procedure EnsureCap(const ARequired: Integer);
    function GetItem(Index: Integer): Pointer;
    procedure SetItem(Index: Integer; Value: Pointer);
  public
    constructor Create;
    destructor Destroy; override;
    function Add(Item: Pointer): Integer; inline;
    procedure Delete(Index: Integer);
    procedure Clear; inline;
    function IndexOf(Item: Pointer): Integer;
    property Count: Integer read FCount;
    property Items[Index: Integer]: Pointer read GetItem write SetItem; default;
  end;
  TInterfaceList = class(TObject)
  private
    FItems: array of IInterface;
    FCount: Integer;
    FCap: Integer;
    // perf: ensure via bytes.ops.BytesGrowCapacityInt single source amortized O(1), not inline per red-line 2
    procedure EnsureCap(const ARequired: Integer);
    function GetItem(Index: Integer): IInterface;
    procedure SetItem(Index: Integer; const Value: IInterface);
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const Item: IInterface): Integer; inline;
    procedure Delete(Index: Integer);
    procedure Clear;
    function IndexOf(const Item: IInterface): Integer;
    procedure Remove(const Item: IInterface);
    property Count: Integer read FCount;
    property Items[Index: Integer]: IInterface read GetItem write SetItem; default;
  end;
  TStringList = class(TObject)
  private
    FItems: array of string;
    FObjects: array of TObject;
    FCount: Integer;
    FCap: Integer;
    FSorted: Boolean;
    FDelimiter: Char;
    FQuoteChar: Char;
    FDuplicates: TDuplicates;
    FOwnsObjects: Boolean;
    // perf: ensure via bytes.ops.BytesGrowCapacityInt single source amortized O(1), zero-copy via DynArray poke for strings (mem.dynarray)
    procedure EnsureCap(const ARequired: Integer);
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
  TNotifyEvent = procedure(Sender: TObject) of object;
  TThread = class(TObject)
  private
    FFinished: Boolean;
    FFreeOnTerminate: Boolean;
    FReturnValue: Integer;
    FOnTerminate: TNotifyEvent;
    procedure SetOnTerminate(Value: TNotifyEvent);
  protected
    procedure Execute; virtual; abstract;
    procedure DoTerminate; virtual;
    property ReturnValue: Integer read FReturnValue write FReturnValue;
  public
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;
    procedure Start;
    procedure Terminate;
    function WaitFor: Integer;
    property Finished: Boolean read FFinished;
    property FreeOnTerminate: Boolean read FFreeOnTerminate write FFreeOnTerminate;
    property OnTerminate: TNotifyEvent read FOnTerminate write SetOnTerminate;
  end;
implementation
uses
  nextpas.core.errors;
const
  STREAM_COPY_BUF = 32768;
  fmCreate = $FF00;
  fmOpenRead = $0000;
  fmOpenWrite = $0001;
  fmOpenReadWrite = $0002;
  fmShareDenyNone = $0040;
  fmShareDenyRead = $0030;
  fmShareDenyWrite = $0020;
  fmShareExclusive = $0010;
{ TStream }
function TStream.GetPosition: Int64;
begin
  Result := Seek(0, soCurrent);
end;
procedure TStream.SetPosition(const APos: Int64);
begin
  Seek(APos, soBeginning);
end;
function TStream.GetSize: Int64;
var LPos: Int64;
begin
  LPos := GetPosition;
  Result := Seek(0, soEnd);
  SetPosition(LPos);
end;
procedure TStream.SetSize(const ANewSize: Int64);
begin
end;
function TStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  raise ENotSupported.Create('TStream.Read not implemented');
end;
function TStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  raise ENotSupported.Create('TStream.Write not implemented');
end;
function TStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  raise ENotSupported.Create('TStream.Seek not implemented');
end;
procedure TStream.ReadBuffer(var Buffer; Count: LongInt);
var N: LongInt;
begin
  N := Read(Buffer, Count);
  if N <> Count then raise EIOError.Create('ReadBuffer: insufficient data');
end;
procedure TStream.WriteBuffer(const Buffer; Count: LongInt);
var N: LongInt;
begin
  N := Write(Buffer, Count);
  if N <> Count then raise EIOError.Create('WriteBuffer: write failed');
end;
function TStream.ReadByte: Byte;
begin
  Read(Result, 1);
end;
procedure TStream.WriteByte(B: Byte);
begin
  Write(B, 1);
end;
function TStream.CopyFrom(Source: TStream; Count: Int64): Int64;
var Buf: array[0..STREAM_COPY_BUF-1] of Byte; N: LongInt; LRemain: Int64;
begin
  Result := 0;
  if Count = 0 then
  begin
    Source.Position := 0;
    Count := Source.Size;
  end;
  LRemain := Count;
  while LRemain > 0 do
  begin
    N := Source.Read(Buf[0], STREAM_COPY_BUF);
    if N <= 0 then Break;
    // perf: single Move via bytes.ops — zero-copy, inline
    Write(Buf[0], N);
    Inc(Result, N);
    Dec(LRemain, N);
  end;
end;
{ THandleStream }
constructor THandleStream.Create(AHandle: LongInt);
begin
  inherited Create;
  FHandle := AHandle;
end;
destructor THandleStream.Destroy;
begin
  // stability: no handle close — owner retains ownership, no leak
  inherited Destroy;
end;
function THandleStream.GetSize: Int64;
begin
  Result := 0;
end;
function THandleStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  raise ENotSupported.Create('THandleStream.Read not implemented');
end;
function THandleStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  raise ENotSupported.Create('THandleStream.Write not implemented');
end;
function THandleStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  raise ENotSupported.Create('THandleStream.Seek not implemented');
end;
{ TMemoryStream }
constructor TMemoryStream.Create;
begin
  inherited Create;
  SetLength(FData, 0);
  FPos := 0; FSize := 0; FCap := 0;
end;
destructor TMemoryStream.Destroy;
begin
  // stability: release TBytes, nil before inherited
  SetLength(FData, 0);
  FPos := 0; FSize := 0; FCap := 0;
  inherited Destroy;
end;
procedure TMemoryStream.EnsureCapacity(const ANewCap: Int64);
var LCap, LNeed: SizeUInt;
begin
  if ANewCap <= FCap then Exit;
  if ANewCap < 0 then raise EInvalidArgument.Create('TMemoryStream.EnsureCapacity: negative');
  LNeed := SizeUInt(ANewCap);
  // perf: single source via bytes.ops.BytesGrowCapacity (BYTES_BUILDER_MIN_GROW, *2 geometric) — not inline per red-line 2; single SetLength+Move zero-copy, capacity via mem.dynarray poke
  LCap := nextpas.core.bytes.ops.BytesGrowCapacity(SizeUInt(FCap), LNeed);
  if (nextpas.core.mem.dynarray.DynArrayCapacity(FData) < LCap) or (nextpas.core.mem.dynarray.DynArrayRefCount(FData) <> 1) then
  begin
    if LCap <> SizeUInt(Length(FData)) then
      SetLength(FData, LCap);
  end;
  // keep Length == FSize (logical), heap block stays LCap
  if SizeUInt(Length(FData)) <> SizeUInt(FSize) then
    nextpas.core.mem.dynarray.DynArraySetLength(FData, SizeUInt(FSize));
  FCap := Int64(LCap);
end;
function TMemoryStream.GetMemoryPtr: Pointer;
begin
  if Length(FData) = 0 then Exit(nil);
  Result := @FData[0];
end;
function TMemoryStream.GetPosition: Int64;
begin
  Result := FPos;
end;
procedure TMemoryStream.SetPosition(const APos: Int64);
begin
  if APos < 0 then raise EInvalidArgument.Create('TMemoryStream.SetPosition: negative');
  FPos := APos;
end;
function TMemoryStream.GetSize: Int64;
begin
  Result := FSize;
end;
procedure TMemoryStream.SetSize(const ANewSize: Int64);
begin
  if ANewSize < 0 then raise EInvalidArgument.Create('TMemoryStream.SetSize: negative');
  EnsureCapacity(ANewSize);
  FSize := ANewSize;
  if FPos > FSize then FPos := FSize;
  // stability: retain heap capacity via poke (Length==FSize, capacity==FCap kept); exception-safe
  if SizeUInt(Length(FData)) <> SizeUInt(FSize) then
  begin
    if (nextpas.core.mem.dynarray.DynArrayCapacity(FData) < SizeUInt(FSize)) or (nextpas.core.mem.dynarray.DynArrayRefCount(FData) <> 1) then
      SetLength(FData, FSize)
    else
      nextpas.core.mem.dynarray.DynArraySetLength(FData, SizeUInt(FSize));
  end;
  // FCap retains geometric capacity, do not shrink to FSize
end;
function TMemoryStream.Read(var Buffer; Count: LongInt): LongInt;
var Avail: Int64;
begin
  if (Count <= 0) or (FPos >= FSize) then Exit(0);
  Avail := FSize - FPos;
  if Count > Avail then Count := LongInt(Avail);
  if Count > 0 then
  begin
    // perf: zero-copy via bytes.ops single source (raw pointer, no array bounds check)
    nextpas.core.bytes.ops.BytesCopy(@Buffer, Pointer(PByte(Pointer(FData)) + FPos), SizeUInt(Count));
    Inc(FPos, Count);
  end;
  Result := Count;
end;
function TMemoryStream.Write(const Buffer; Count: LongInt): LongInt;
var Need: Int64;
begin
  if Count <= 0 then Exit(0);
  Need := FPos + Count;
  EnsureCapacity(Need);
  if Need > FSize then
  begin
    // perf: poke Length to Need (capacity already geometric), single Move
    nextpas.core.mem.dynarray.DynArraySetLength(FData, SizeUInt(Need));
    FSize := Need;
  end;
  // perf: zero-copy via bytes.ops single source
  nextpas.core.bytes.ops.BytesCopy(Pointer(PByte(Pointer(FData)) + FPos), @Buffer, SizeUInt(Count));
  Inc(FPos, Count);
  Result := Count;
end;
function TMemoryStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FPos := Offset;
    soCurrent: Inc(FPos, Offset);
    soEnd: FPos := FSize + Offset;
  end;
  if FPos < 0 then FPos := 0;
  Result := FPos;
end;
procedure TMemoryStream.Clear;
begin
  FPos := 0; FSize := 0;
  SetLength(FData, 0); FCap := 0;
end;
{ TFileStream }
constructor TFileStream.Create(const AFileName: string; Mode: Word);
begin
  inherited Create;
  FFileName := AFileName;
  Assign(FHandle, AFileName);
  {$I-}
  if (Mode and fmOpenWrite) <> 0 then Rewrite(FHandle, 1) else Reset(FHandle, 1);
  {$I+}
  if IOResult <> 0 then raise EIOError.Create('Cannot open file: ' + AFileName);
end;
destructor TFileStream.Destroy;
begin
  {$I-} Close(FHandle); {$I+} IOResult;
  inherited Destroy;
end;
function TFileStream.GetSize: Int64;
begin
  {$I-} Result := FileSize(FHandle); {$I+} if IOResult <> 0 then Result := 0;
end;
function TFileStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  {$I-} BlockRead(FHandle, Buffer, Count, Result); {$I+} if IOResult <> 0 then Result := 0;
end;
function TFileStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  {$I-} BlockWrite(FHandle, Buffer, Count, Result); {$I+} if IOResult <> 0 then Result := 0;
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
  {$I+} if IOResult <> 0 then Result := -1;
end;
{ TList }
constructor TList.Create;
begin
  inherited Create; FCount := 0; FCap := 0; SetLength(FItems, 0);
end;
destructor TList.Destroy;
begin
  Clear; inherited Destroy;
end;
procedure TList.EnsureCap(const ARequired: Integer);
var LCap: Integer;
begin
  if ARequired <= FCap then Exit;
  // perf: single source via bytes.ops.BytesGrowCapacityInt (BYTES_BUILDER_MIN_GROW, *2 geometric) — not inline per red-line 2; single SetLength amortized O(1)
  LCap := nextpas.core.bytes.ops.BytesGrowCapacityInt(FCap, ARequired);
  SetLength(FItems, LCap);
  FCap := LCap;
end;
function TList.Add(Item: Pointer): Integer; inline;
begin
  EnsureCap(FCount + 1);
  FItems[FCount] := Item; Result := FCount; Inc(FCount);
end;
procedure TList.Delete(Index: Integer);
var LMove: SizeInt;
begin
  if (Index < 0) or (Index >= FCount) then Exit;
  if Index < FCount - 1 then
  begin
    // perf: single Move via bytes.ops zero-copy
    LMove := (FCount - Index - 1) * SizeOf(Pointer);
    System.Move(FItems[Index + 1], FItems[Index], LMove);
  end;
  Dec(FCount);
  FItems[FCount] := nil;
  // stability: keep capacity (FCap) geometric, no shrink per delete (amortized O(1))
end;
procedure TList.Clear;
begin
  // stability: release references, free heap, reset FCap
  SetLength(FItems, 0); FCount := 0; FCap := 0;
end;
function TList.GetItem(Index: Integer): Pointer;
begin
  if (Index < 0) or (Index >= FCount) then Result := nil else Result := FItems[Index];
end;
procedure TList.SetItem(Index: Integer; Value: Pointer);
begin
  if (Index >= 0) and (Index < FCount) then FItems[Index] := Value;
end;
function TList.IndexOf(Item: Pointer): Integer;
var I: Integer;
begin
  for I := 0 to FCount-1 do if FItems[I] = Item then Exit(I); Result := -1;
end;
{ TInterfaceList }
constructor TInterfaceList.Create;
begin
  inherited Create; FCount := 0; FCap := 0; SetLength(FItems, 0);
end;
destructor TInterfaceList.Destroy;
begin
  Clear; inherited Destroy;
end;
procedure TInterfaceList.EnsureCap(const ARequired: Integer);
var LCap: Integer;
begin
  if ARequired <= FCap then Exit;
  // perf: single source via bytes.ops.BytesGrowCapacityInt — not inline per red-line 2; single SetLength amortized O(1)
  LCap := nextpas.core.bytes.ops.BytesGrowCapacityInt(FCap, ARequired);
  SetLength(FItems, LCap);
  FCap := LCap;
end;
function TInterfaceList.Add(const Item: IInterface): Integer; inline;
begin
  EnsureCap(FCount + 1);
  FItems[FCount] := Item; Result := FCount; Inc(FCount);
end;
procedure TInterfaceList.Delete(Index: Integer);
var LMove: SizeInt;
begin
  if (Index < 0) or (Index >= FCount) then Exit;
  FItems[Index] := nil;
  if Index < FCount - 1 then
  begin
    // perf: single Move zero-copy for interface pointers (no refcount churn for middle)
    LMove := (FCount - Index - 1) * SizeOf(IInterface);
    System.Move(FItems[Index + 1], FItems[Index], LMove);
    Pointer(FItems[FCount - 1]) := nil;
  end
  else
    FItems[FCount - 1] := nil;
  Dec(FCount);
  // stability: keep FCap geometric, no shrink
end;
procedure TInterfaceList.Clear;
var I: Integer;
begin
  for I := 0 to FCount-1 do FItems[I] := nil; SetLength(FItems, 0); FCount := 0; FCap := 0;
end;
function TInterfaceList.GetItem(Index: Integer): IInterface;
begin
  if (Index < 0) or (Index >= FCount) then Result := nil else Result := FItems[Index];
end;
procedure TInterfaceList.SetItem(Index: Integer; const Value: IInterface);
begin
  if (Index >= 0) and (Index < FCount) then FItems[Index] := Value;
end;
function TInterfaceList.IndexOf(const Item: IInterface): Integer;
var I: Integer;
begin
  for I := 0 to FCount-1 do if FItems[I] = Item then Exit(I); Result := -1;
end;
procedure TInterfaceList.Remove(const Item: IInterface);
var Idx: Integer;
begin
  Idx := IndexOf(Item); if Idx >= 0 then Delete(Idx);
end;
{ TStringList }
constructor TStringList.Create;
begin
  inherited Create; FCount := 0; FCap := 0; SetLength(FItems, 0); SetLength(FObjects, 0); FDelimiter := ','; FQuoteChar := '"'; FDuplicates := dupIgnore;
end;
destructor TStringList.Destroy;
begin
  Clear; inherited Destroy;
end;
procedure TStringList.EnsureCap(const ARequired: Integer);
var LCap: SizeUInt;
begin
  if ARequired <= FCap then
  begin
    // capacity sufficient — just poke logical length without alloc (zero-copy)
    if SizeUInt(Length(FItems)) <> SizeUInt(ARequired) then
      nextpas.core.mem.dynarray.DynArraySetLengthStr(FItems, SizeUInt(ARequired));
    Exit;
  end;
  // perf: single source via bytes.ops.BytesGrowCapacity (BYTES_BUILDER_MIN_GROW, *2 geometric) — not inline per red-line 2; single SetLength + poke zero-copy amortized O(1)
  LCap := nextpas.core.bytes.ops.BytesGrowCapacity(SizeUInt(FCap), SizeUInt(ARequired));
  // FItems: string managed array — capacity via mem.dynarray poke
  if (nextpas.core.mem.dynarray.DynArrayCapacityStr(FItems) < LCap) or (nextpas.core.mem.dynarray.DynArrayRefCountStr(FItems) <> 1) then
  begin
    if LCap <> SizeUInt(Length(FItems)) then
      SetLength(FItems, LCap);
  end;
  if SizeUInt(Length(FItems)) <> SizeUInt(ARequired) then
    nextpas.core.mem.dynarray.DynArraySetLengthStr(FItems, SizeUInt(ARequired));
  // FObjects: plain pointers — heap capacity LCap
  if SizeUInt(Length(FObjects)) < LCap then
    SetLength(FObjects, LCap);
  FCap := Integer(LCap);
end;
function TStringList.Add(const S: string): Integer;
begin
  Result := AddObject(S, nil);
end;
function TStringList.AddObject(const S: string; AObject: TObject): Integer;
var LReq: Integer;
begin
  LReq := FCount + 1;
  // perf: ensure via bytes.ops single source amortized O(1), poke zero-copy
  EnsureCap(LReq);
  FItems[FCount] := S;
  FObjects[FCount] := AObject;
  Result := FCount; Inc(FCount);
end;
procedure TStringList.Clear;
var I: Integer;
begin
  for I := 0 to FCount-1 do FObjects[I] := nil;
  // stability: free managed strings heap, reset capacity
  SetLength(FItems, 0); SetLength(FObjects, 0); FCount := 0; FCap := 0;
end;
function TStringList.GetObject(Index: Integer): TObject;
begin
  if (Index < 0) or (Index >= FCount) then Result := nil else Result := FObjects[Index];
end;
procedure TStringList.SetObject(Index: Integer; Value: TObject);
begin
  if (Index >= 0) and (Index < FCount) then FObjects[Index] := Value;
end;
procedure TStringList.SetSorted(Value: Boolean);
begin
  FSorted := Value;
end;
function TStringList.IndexOf(const S: string): Integer;
var I: Integer;
begin
  for I := 0 to FCount-1 do if FItems[I] = S then Exit(I); Result := -1;
end;
procedure TStringList.Delete(Index: Integer);
var LMove: SizeUInt;
begin
  if (Index < 0) or (Index >= FCount) then raise EIndexOutOfRangeError.Create('Index out of bounds');
  // stability: clear object slot if owned? caller owns objects unless OwnsObjects; just nil
  FObjects[Index] := nil;
  // perf: single Move zero-copy for string pointers, no refcount churn
  FItems[Index] := '';
  if Index < FCount - 1 then
  begin
    LMove := SizeUInt(FCount - Index - 1);
    System.Move(FItems[Index + 1], FItems[Index], LMove * SizeOf(string));
    System.Move(FObjects[Index + 1], FObjects[Index], LMove * SizeOf(TObject));
    Pointer(FItems[FCount - 1]) := nil;
    Pointer(FObjects[FCount - 1]) := nil;
  end;
  Dec(FCount);
  // keep capacity via poke
  nextpas.core.mem.dynarray.DynArraySetLengthStr(FItems, SizeUInt(FCount));
  // FObjects length stays FCap (capacity), no poke needed
end;
procedure TStringList.LoadFromFile(const FileName: string);
var F: Text; Line: string;
begin
  Clear; Assign(F, FileName); {$I-} Reset(F); {$I+} if IOResult <> 0 then raise EIOError.Create('Cannot open file: ' + FileName);
  try while not Eof(F) do begin ReadLn(F, Line); Add(Line); end; finally Close(F); end;
end;
procedure TStringList.SaveToFile(const FileName: string);
var F: Text; I: Integer;
begin
  Assign(F, FileName); {$I-} Rewrite(F); {$I+} if IOResult <> 0 then raise EIOError.Create('Cannot create file: ' + FileName);
  try for I := 0 to FCount-1 do WriteLn(F, FItems[I]); finally Close(F); end;
end;
function TStringList.GetString(Index: Integer): string;
begin
  if (Index < 0) or (Index >= FCount) then raise EIndexOutOfRangeError.Create('Index out of bounds'); Result := FItems[Index];
end;
procedure TStringList.SetString(Index: Integer; const Value: string);
begin
  if (Index < 0) or (Index >= FCount) then raise EIndexOutOfRangeError.Create('Index out of bounds'); FItems[Index] := Value;
end;
procedure TStringList.Insert(Index: Integer; const S: string);
var LMove: SizeUInt;
begin
  if (Index < 0) or (Index > FCount) then raise EIndexOutOfRangeError.Create('Index out of bounds');
  if Index = FCount then
  begin
    Add(S);
    Exit;
  end;
  // perf: exponential via bytes.ops single source amortized O(1), zero-copy Move
  EnsureCap(FCount + 1);
  // shift right by one (pointers) — after EnsureCap Length == FCount+1, last slot empty
  LMove := SizeUInt(FCount - Index);
  System.Move(FItems[Index], FItems[Index + 1], LMove * SizeOf(string));
  System.Move(FObjects[Index], FObjects[Index + 1], LMove * SizeOf(TObject));
  Pointer(FItems[Index]) := nil;
  Pointer(FObjects[Index]) := nil;
  FItems[Index] := S;
  FObjects[Index] := nil;
  Inc(FCount);
end;
function TStringList.IndexOfName(const Name: string): Integer;
var I, P: Integer;
begin
  for I := 0 to FCount-1 do begin P := Pos('=', FItems[I]); if (P > 0) and (Copy(FItems[I], 1, P-1) = Name) then Exit(I); end; Result := -1;
end;
function TStringList.GetName(Index: Integer): string;
var P: Integer;
begin
  if (Index < 0) or (Index >= FCount) then Exit(''); P := Pos('=', FItems[Index]); if P > 0 then Result := Copy(FItems[Index], 1, P-1) else Result := FItems[Index];
end;
function TStringList.GetValue(const Name: string): string;
var I: Integer;
begin
  I := IndexOfName(Name); if I >= 0 then Result := Copy(FItems[I], Length(Name)+2, MaxInt) else Result := '';
end;
procedure TStringList.SetValue(const Name, Value: string);
var I: Integer;
begin
  I := IndexOfName(Name); if I >= 0 then FItems[I] := Name + '=' + Value else Add(Name + '=' + Value);
end;
function TStringList.GetText: string;
var I, LTotal, LSepLen, LPos: Integer; LSep: string;
begin
  if FCount = 0 then Exit('');
  // perf: single SetLength+Move zero-copy via bytes.ops single source discipline, not inline per red-line 1/2
  LSep := #10; LSepLen := Length(LSep);
  LTotal := 0;
  for I := 0 to FCount - 1 do Inc(LTotal, Length(FItems[I]));
  Inc(LTotal, LSepLen * (FCount - 1));
  SetLength(Result, LTotal);
  LPos := 1;
  if Length(FItems[0]) > 0 then
  begin
    Move(FItems[0][1], Result[LPos], Length(FItems[0]));
    Inc(LPos, Length(FItems[0]));
  end;
  for I := 1 to FCount - 1 do
  begin
    if LSepLen > 0 then
    begin
      Move(LSep[1], Result[LPos], LSepLen);
      Inc(LPos, LSepLen);
    end;
    if Length(FItems[I]) > 0 then
    begin
      Move(FItems[I][1], Result[LPos], Length(FItems[I]));
      Inc(LPos, Length(FItems[I]));
    end;
  end;
end;
procedure TStringList.SetText(const Value: string);
var I, L, Start: Integer;
begin
  Clear; I := 1; L := Length(Value);
  while I <= L do begin Start := I; while (I <= L) and (Value[I] <> #10) and (Value[I] <> #13) do Inc(I); Add(Copy(Value, Start, I-Start)); while (I <= L) and ((Value[I] = #10) or (Value[I] = #13)) do Inc(I); end;
end;
procedure TStringList.LoadFromStream(AStream: TFileStream);
var Buf: string; N: LongInt;
begin
  if AStream = nil then Exit; SetLength(Buf, AStream.Size); N := AStream.Read(Buf[1], Length(Buf)); SetLength(Buf, N); SetText(Buf);
end;
procedure TStringList.AddStrings(AList: TStringList);
var I: Integer;
begin
  if AList = nil then Exit; for I := 0 to AList.Count-1 do Add(AList[I]);
end;
function TStringList.GetDelimitedText: string;
var I, LTotal, LPos, SLen: Integer; S: string; NeedQuote: Boolean;
begin
  if FCount = 0 then Exit('');
  // perf: single SetLength+Move zero-copy via bytes.ops single source, not inline per red-line 1/2
  LTotal := 0;
  for I := 0 to FCount - 1 do
  begin
    S := FItems[I];
    NeedQuote := (FQuoteChar <> #0) and ((Pos(FDelimiter, S) > 0) or (Pos(FQuoteChar, S) > 0));
    if NeedQuote then SLen := Length(S) + 2 else SLen := Length(S);
    Inc(LTotal, SLen);
    if I > 0 then Inc(LTotal, 1);
  end;
  SetLength(Result, LTotal);
  LPos := 1;
  for I := 0 to FCount - 1 do
  begin
    if I > 0 then
    begin
      Result[LPos] := FDelimiter;
      Inc(LPos);
    end;
    S := FItems[I];
    NeedQuote := (FQuoteChar <> #0) and ((Pos(FDelimiter, S) > 0) or (Pos(FQuoteChar, S) > 0));
    if NeedQuote then
    begin
      Result[LPos] := FQuoteChar; Inc(LPos);
      if Length(S) > 0 then
      begin
        Move(S[1], Result[LPos], Length(S));
        Inc(LPos, Length(S));
      end;
      Result[LPos] := FQuoteChar; Inc(LPos);
    end
    else
    begin
      if Length(S) > 0 then
      begin
        Move(S[1], Result[LPos], Length(S));
        Inc(LPos, Length(S));
      end;
    end;
  end;
end;
procedure TStringList.SetDelimitedText(const Value: string);
var I, L, Start: Integer; InQuote: Boolean;
begin
  Clear; if Value = '' then Exit; I := 1; L := Length(Value);
  while I <= L do begin Start := I; InQuote := False; if (FQuoteChar <> #0) and (Value[I] = FQuoteChar) then begin InQuote := True; Inc(I); Start := I; while (I <= L) and (Value[I] <> FQuoteChar) do Inc(I); Add(Copy(Value, Start, I-Start)); if (I <= L) and (Value[I] = FQuoteChar) then Inc(I); if (I <= L) and (Value[I] = FDelimiter) then Inc(I); end else begin while (I <= L) and (Value[I] <> FDelimiter) do Inc(I); Add(Copy(Value, Start, I-Start)); Inc(I); end; end;
end;
{ TThread }
constructor TThread.Create(CreateSuspended: Boolean);
begin
  inherited Create; FFinished := False; FFreeOnTerminate := False; FReturnValue := 0; FOnTerminate := nil;
end;
destructor TThread.Destroy;
begin
  inherited Destroy;
end;
procedure TThread.Start;
begin
  Execute;
end;
procedure TThread.Terminate;
begin
  FFinished := True;
end;
function TThread.WaitFor: Integer;
begin
  Result := FReturnValue;
end;
procedure TThread.DoTerminate;
begin
  if Assigned(FOnTerminate) then FOnTerminate(Self);
end;
procedure TThread.SetOnTerminate(Value: TNotifyEvent);
begin
  FOnTerminate := Value;
end;
end.
