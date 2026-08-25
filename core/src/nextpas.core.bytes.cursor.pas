unit nextpas.core.bytes.cursor;
{**
 * @desc 边界受查的字节缓冲游标：容器格式（ZIP/PNG/git pack/WASM 等）解析的
 *       通用只读原语。支持顺序读与绝对偏移读，全部越界受查。
 *
 * 错误模型：Try* 变体返回 Boolean 不 raise；其余越界一律
 * EIndexOutOfRangeError。游标不拥有缓冲区；裸指针构造由调用方保证生命周期。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.binary;

type
  {** @desc 只读字节游标（TBytes 或裸指针 + 长度） *}
  IByteCursor = interface
    ['{4B8D2C57-9E31-4A6F-B7D5-08C3A1E62F94}']
    {** 缓冲区总长 *}
    function Length: SizeUInt;
    {** 当前顺序位置 *}
    function Position: SizeUInt;
    {** 剩余可读字节数 *}
    function Remaining: SizeUInt;
    {** 绝对定位；越界 raise EIndexOutOfRangeError *}
    procedure Seek(APos: SizeUInt);
    {** 绝对定位；越界 False 不 raise *}
    function TrySeek(APos: SizeUInt): Boolean;
    {** 从当前位置读无符号 LE/BE 并推进；越界 raise *}
    function ReadU16LE: UInt16;
    function ReadU32LE: UInt32;
    function ReadU64LE: UInt64;
    function ReadU16BE: UInt16;
    function ReadU32BE: UInt32;
    function ReadU64BE: UInt64;
    {** 绝对偏移读取，不推进位置；越界 raise *}
    function PeekU16LE(AAt: SizeUInt): UInt16;
    function PeekU32LE(AAt: SizeUInt): UInt32;
    function PeekU64LE(AAt: SizeUInt): UInt64;
    {** 从当前位置拷贝 ACount 字节并推进；越界 raise *}
    function ReadBytes(ACount: SizeUInt): TBytes;
    {** 同上；不足 ACount 返回 False 不推进 *}
    function TryReadBytes(ACount: SizeUInt; out AOut: TBytes): Boolean;
  end;

{** TBytes 构造游标。 *}
function NewByteCursor(const AData: TBytes): IByteCursor;

{** 裸指针构造（调用方保证生命周期）。 *}
function NewByteCursorAt(const AData: PByte; ALen: SizeUInt): IByteCursor;

implementation

uses
  nextpas.core.exception;

type
  TByteCursor = class(TInterfacedObject, IByteCursor)
  private
    FData: PByte;
    FLen: SizeUInt;
    FPos: SizeUInt;
    FOwnsCopy: TBytes;   { TBytes 构造时持有引用，保证指针有效 }
    procedure CheckRange(APos, ALen: SizeUInt);
  public
    constructor Create(const AData: TBytes); overload;
    constructor Create(AData: PByte; ALen: SizeUInt); overload;
    function Length: SizeUInt;
    function Position: SizeUInt;
    function Remaining: SizeUInt;
    procedure Seek(APos: SizeUInt);
    function TrySeek(APos: SizeUInt): Boolean;
    function ReadU16LE: UInt16;
    function ReadU32LE: UInt32;
    function ReadU64LE: UInt64;
    function ReadU16BE: UInt16;
    function ReadU32BE: UInt32;
    function ReadU64BE: UInt64;
    function PeekU16LE(AAt: SizeUInt): UInt16;
    function PeekU32LE(AAt: SizeUInt): UInt32;
    function PeekU64LE(AAt: SizeUInt): UInt64;
    function ReadBytes(ACount: SizeUInt): TBytes;
    function TryReadBytes(ACount: SizeUInt; out AOut: TBytes): Boolean;
  end;

function NewByteCursor(const AData: TBytes): IByteCursor;
begin
  Result := TByteCursor.Create(AData);
end;

function NewByteCursorAt(const AData: PByte; ALen: SizeUInt): IByteCursor;
begin
  Result := TByteCursor.Create(AData, ALen);
end;

constructor TByteCursor.Create(const AData: TBytes);
begin
  inherited Create;
  FOwnsCopy := AData;
  if System.Length(AData) > 0 then
    FData := @AData[0]
  else
    FData := nil;
  FLen := System.Length(AData);
  FPos := 0;
end;

constructor TByteCursor.Create(AData: PByte; ALen: SizeUInt);
begin
  inherited Create;
  FData := AData;
  FLen := ALen;
  FPos := 0;
end;

procedure TByteCursor.CheckRange(APos, ALen: SizeUInt);
begin
  { APos + ALen 溢出安全：APos、ALen 均 ≤ High(SizeUInt)，先比大小 }
  if (ALen > FLen) or (APos > FLen - ALen) then
    raise EIndexOutOfRangeError.Create(
      'byte cursor: range out of bounds (pos=' + IntToStr(Int64(APos)) +
      ', len=' + IntToStr(Int64(ALen)) + ', size=' + IntToStr(Int64(FLen)) + ')');
end;

function TByteCursor.Length: SizeUInt;
begin
  Result := FLen;
end;

function TByteCursor.Position: SizeUInt;
begin
  Result := FPos;
end;

function TByteCursor.Remaining: SizeUInt;
begin
  Result := FLen - FPos;
end;

procedure TByteCursor.Seek(APos: SizeUInt);
begin
  CheckRange(APos, 0);
  FPos := APos;
end;

function TByteCursor.TrySeek(APos: SizeUInt): Boolean;
begin
  Result := APos <= FLen;
  if Result then
    FPos := APos;
end;

function TByteCursor.ReadU16LE: UInt16;
begin
  CheckRange(FPos, 2);
  Result := ReadUInt16LE(FData + FPos);
  Inc(FPos, 2);
end;

function TByteCursor.ReadU32LE: UInt32;
begin
  CheckRange(FPos, 4);
  Result := ReadUInt32LE(FData + FPos);
  Inc(FPos, 4);
end;

function TByteCursor.ReadU64LE: UInt64;
begin
  CheckRange(FPos, 8);
  Result := ReadUInt64LE(FData + FPos);
  Inc(FPos, 8);
end;

function TByteCursor.ReadU16BE: UInt16;
begin
  CheckRange(FPos, 2);
  Result := ReadUInt16BE(FData + FPos);
  Inc(FPos, 2);
end;

function TByteCursor.ReadU32BE: UInt32;
begin
  CheckRange(FPos, 4);
  Result := ReadUInt32BE(FData + FPos);
  Inc(FPos, 4);
end;

function TByteCursor.ReadU64BE: UInt64;
begin
  CheckRange(FPos, 8);
  Result := ReadUInt64BE(FData + FPos);
  Inc(FPos, 8);
end;

function TByteCursor.PeekU16LE(AAt: SizeUInt): UInt16;
begin
  CheckRange(AAt, 2);
  Result := ReadUInt16LE(FData + AAt);
end;

function TByteCursor.PeekU32LE(AAt: SizeUInt): UInt32;
begin
  CheckRange(AAt, 4);
  Result := ReadUInt32LE(FData + AAt);
end;

function TByteCursor.PeekU64LE(AAt: SizeUInt): UInt64;
begin
  CheckRange(AAt, 8);
  Result := ReadUInt64LE(FData + AAt);
end;

function TByteCursor.ReadBytes(ACount: SizeUInt): TBytes;
var
  LOut: TBytes;
begin
  CheckRange(FPos, ACount);
  SetLength(LOut, ACount);
  if ACount > 0 then
    Move((FData + FPos)^, LOut[0], ACount);
  Inc(FPos, ACount);
  Result := LOut;
end;

function TByteCursor.TryReadBytes(ACount: SizeUInt; out AOut: TBytes): Boolean;
begin
  Result := ACount <= Remaining;
  if not Result then
    Exit;
  AOut := ReadBytes(ACount);
end;

end.
