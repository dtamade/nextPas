unit nextpas.core.ssh.buffer;

{** nextpas.core.ssh - RFC 4251 wire 数据类型读写器。
 *
 * TSshWriter 把 byte/boolean/uint32/string/mpint/name-list 打进载荷；
 * TSshReader 做反向解析。所有越界访问抛 ESSHError(sekProtocol)。
 *
 * 约定：string 与 TBytes 之间按原始字节透传（UTF-8 由调用方保证），
 * 不在本单元做字符集转换。PutStringText 入口显式校验 UTF-8，
 * 非法即抛 sekProtocol；STATUS 描述等读侧非法 UTF-8 走替换。
 *
 * 实现：record 栈上值语义，零堆对象分配；FBuf 按 BytesEnsureCapacity 几何倍增
 * 单源，Move 零拷贝，inline 热路径；生命周期由编译器托管字段自动终结，Free/Done 幂等。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.text.strings,
  nextpas.core.text.utf8,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors;

type
  { SSH 载荷写入器 — record 栈上零堆，FBuf 托管 TBytes 自动终结 }
  TSshWriter = record
  private
    FBuf: TBytes;
    FLen: SizeUInt;
    procedure Ensure(ACount: SizeUInt);
  public
    constructor Create(ACapacityHint: SizeUInt);
    procedure Init(ACapacityHint: SizeUInt = 256); inline;
    procedure Done; inline;
    procedure Free; inline;
    procedure Clear; inline;
    function Count: SizeUInt; inline;
    function ToBytes: TBytes; inline;

    procedure PutByte(AValue: Byte); inline;
    procedure PutBoolean(AValue: Boolean); inline;
    procedure PutUInt32(AValue: UInt32); inline;
    procedure PutUInt64(AValue: UInt64); inline;
    procedure PutStringBytes(const AValue: TBytes); inline;
    procedure PutStringText(const AText: string); inline;
    { 无符号大端 magnitude → RFC 4251 mpint（补符号位前导零；0 编码为空串）}
    procedure PutMPInt(const AMagnitude: TBytes);
    procedure PutNameList(const ANames: array of string);
    procedure PutRaw(const APtr: PByte; ALen: SizeUInt); overload; inline;
    procedure PutRaw(const AValue: TBytes); overload; inline;
  end;

  { SSH 载荷读取器 — record 栈上零堆，FData 引用拷贝+位置游标 }
  TSshReader = record
  private
    FData: TBytes;
    FPos: SizeUInt;
    procedure Need(ACount: SizeUInt); inline;
  public
    constructor Create(const AData: TBytes);
    procedure Init(const AData: TBytes); inline;
    procedure Done; inline;
    procedure Free; inline;

    function AtEnd: Boolean; inline;
    function Remaining: SizeUInt; inline;
    function Position: SizeUInt; inline;

    function PeekByte: Byte; inline;
    function ReadByte: Byte; inline;
    procedure Skip(ACount: SizeUInt); inline;
    function ReadBoolean: Boolean; inline;
    function ReadUInt32: UInt32; inline;
    function ReadUInt64: UInt64; inline;
    function ReadStringBytes: TBytes; inline;
    function ReadStringSpan: TByteSpan; inline;
    function ReadStringText: string;
    { 解析 mpint 为无符号大端 magnitude（剥离前导零；负数高位按无符号处理）}
    function ReadMPInt: TBytes; inline;
    function ReadMPIntSpan: TByteSpan; inline;
    function ReadNameList: TStringArray;
  end;

function SshTextFromBytes(const ABytes: TBytes): string; inline;
function SshBytesFromText(const AText: string): TBytes; inline;

implementation

{ SshTextFromBytes/SshBytesFromText — raw bytes ↔ string 透传（UTF-8 由调用方保证，不做转换）。
  单源：委托 bytes.ops.BytesToString/StringToBytes 单源（SetLength+单次 Move 零拷贝），
  本单元仅作 ssh CONTRACT 的 inline 薄转发，避免自实现 Move 导致单源漂移。
  perf: inline 薄转发消除调用开销，零拷贝单次 Move，无二次分配；空串/空 bytes 在 bytes.ops 内短路。
  stability: 不手写 Move 取 [0]，无野指针；复用 bytes.ops 异常安全 SetLength。 }
function SshTextFromBytes(const ABytes: TBytes): string; inline;
begin
  Result := nextpas.core.bytes.ops.BytesToString(ABytes);
end;

function SshBytesFromText(const AText: string): TBytes; inline;
begin
  Result := nextpas.core.bytes.ops.StringToBytes(AText);
end;

{ TSshWriter }

constructor TSshWriter.Create(ACapacityHint: SizeUInt);
begin
  // record 栈上：无 inherited，无堆对象头；仅托管 FBuf 一次 SetLength 预分配
  FBuf := nil;
  SetLength(FBuf, ACapacityHint);
  FLen := 0;
end;

procedure TSshWriter.Init(ACapacityHint: SizeUInt); inline;
begin
  // 复用构造路径：栈上重初始化，避免重复实现；单 SetLength+零 FLen
  FBuf := nil;
  SetLength(FBuf, ACapacityHint);
  FLen := 0;
end;

procedure TSshWriter.Done; inline;
begin
  // 幂等释放：托管字段置 nil 触发 refcount 递减；FLen 清零防复用泄漏；栈上自动终结亦安全
  FBuf := nil;
  FLen := 0;
end;

procedure TSshWriter.Free; inline;
begin
  Done;
end;

procedure TSshWriter.Ensure(ACount: SizeUInt);
var
  LNeed: SizeUInt;
begin
  if FLen > High(SizeUInt) - ACount then
    raise ESSHError.Create(sekProtocol, 'ssh buffer: writer overflow');
  LNeed := FLen + ACount;
  if LNeed <= SizeUInt(Length(FBuf)) then
    Exit;
  { perf: single source via nextpas.core.bytes.ops.BytesEnsureCapacity (BYTES_BUILDER_MIN_GROW=64 floor,
    2x geometric doubling loop, overflow clamped); amortized O(1) per Put*, single SetLength+Move
    zero-copy via Move, avoids O(n²) churn; non-inline: real loop body stays out-of-line to avoid
    I-Cache bloat (design-conventions §2 red line), thin caller remains inline candidate.
    single source aligns with sftp.wire.TSshChannelWire.EnsureCapacity (same BytesEnsureCapacity),
    threshold unified to SSH_MAX_RECEIVE_PACKET+1024.
    stability: overflow/packet-limit guarded, exception-safe SetLength, no manual header poke. }
  if LNeed > SSH_MAX_RECEIVE_PACKET + 1024 then
    raise ESSHError.Create(sekProtocol, 'ssh buffer: packet too large');
  BytesEnsureCapacity(FBuf, LNeed);
end;

procedure TSshWriter.Clear; inline;
begin
  FLen := 0;
end;

function TSshWriter.Count: SizeUInt; inline;
begin
  Result := FLen;
end;

function TSshWriter.ToBytes: TBytes; inline;
begin
  { perf: single source via bytes.ops.SpanCopySlice (SetLength+single Move zero-copy), FLen=0 short-circuit no alloc; inline thin forward avoids duplicate Move drift }
  Result := nextpas.core.bytes.ops.SpanCopySlice(TByteSpan.FromBytes(FBuf), 0, FLen);
end;

procedure TSshWriter.PutByte(AValue: Byte); inline;
begin
  Ensure(1);
  FBuf[FLen] := AValue;
  Inc(FLen);
end;

procedure TSshWriter.PutBoolean(AValue: Boolean); inline;
begin
  PutByte(Ord(AValue));
end;

procedure TSshWriter.PutUInt32(AValue: UInt32); inline;
begin
  Ensure(4);
  // 单源：复用 bytes.binary.WriteUInt32BE，避免手写移位与 buffer 直写漂移；inline 零拷贝
  WriteUInt32BE(PByte(@FBuf[FLen]), AValue);
  Inc(FLen, 4);
end;

procedure TSshWriter.PutUInt64(AValue: UInt64); inline;
begin
  PutUInt32(UInt32(AValue shr 32));
  PutUInt32(UInt32(AValue and $FFFFFFFF));
end;

procedure TSshWriter.PutStringBytes(const AValue: TBytes); inline;
begin
  PutUInt32(UInt32(Length(AValue)));
  PutRaw(AValue);
end;

procedure TSshWriter.PutStringText(const AText: string); inline;
begin
  if (Length(AText) > 0) and (not UTF8IsValid(PByte(PChar(AText)), SizeUInt(Length(AText)))) then
    raise ESSHError.Create(sekProtocol, 'ssh buffer: PutStringText requires UTF-8');
  PutUInt32(UInt32(Length(AText)));
  if Length(AText) > 0 then
    PutRaw(PByte(PChar(AText)), SizeUInt(Length(AText)));
end;

procedure TSshWriter.PutMPInt(const AMagnitude: TBytes);
var
  LView: TByteSpan;
begin
  LView := StripLeadingZeroView(AMagnitude);
  if IsZeroBytes(AMagnitude) then
  begin
    PutUInt32(0);
    Exit;
  end;
  if (LView.Data^ and $80) <> 0 then
  begin
    PutUInt32(UInt32(LView.Len + 1));
    PutByte(0);
    PutRaw(LView.Data, LView.Len);
  end
  else
  begin
    PutUInt32(UInt32(LView.Len));
    PutRaw(LView.Data, LView.Len);
  end;
end;

procedure TSshWriter.PutNameList(const ANames: array of string);
var
  I: Integer;
  LArr: TStringArray;
  LJoined: string;
begin
  if Length(ANames) = 0 then
  begin
    PutStringText('');
    Exit;
  end;
  { single source: comma join via text.strings.StringsJoin, UTF-8 via PutStringText }
  SetLength(LArr, Length(ANames));
  for I := 0 to High(ANames) do
    LArr[I] := ANames[I];
  LJoined := StringsJoin(LArr, ',');
  PutStringText(LJoined);
end;

procedure TSshWriter.PutRaw(const APtr: PByte; ALen: SizeUInt); inline;
begin
  if (ALen = 0) or (APtr = nil) then
    Exit;
  Ensure(ALen);
  Move(APtr^, FBuf[FLen], ALen);
  Inc(FLen, ALen);
end;

procedure TSshWriter.PutRaw(const AValue: TBytes); inline;
begin
  if Length(AValue) > 0 then
    PutRaw(@AValue[0], SizeUInt(Length(AValue)));
end;

{ TSshReader }

constructor TSshReader.Create(const AData: TBytes);
begin
  // record 栈上：引用拷贝无堆分配（AddRef），零拷贝视图；不做深拷贝
  FData := AData;
  FPos := 0;
end;

procedure TSshReader.Init(const AData: TBytes); inline;
begin
  FData := AData;
  FPos := 0;
end;

procedure TSshReader.Done; inline;
begin
  FData := nil;
  FPos := 0;
end;

procedure TSshReader.Free; inline;
begin
  Done;
end;

procedure TSshReader.Need(ACount: SizeUInt); inline;
begin
  if Remaining < ACount then
    raise ESSHError.Create(sekProtocol,
      'ssh buffer: truncated payload (need ' + nextpas.core.text.conv.IntToStr(Int64(ACount)) +
      ', remaining ' + nextpas.core.text.conv.IntToStr(Int64(Remaining)) + ')');
end;

function TSshReader.AtEnd: Boolean; inline;
begin
  Result := FPos >= SizeUInt(Length(FData));
end;

function TSshReader.Remaining: SizeUInt; inline;
begin
  Result := SizeUInt(Length(FData)) - FPos;
end;

function TSshReader.Position: SizeUInt; inline;
begin
  Result := FPos;
end;

function TSshReader.PeekByte: Byte; inline;
begin
  Need(1);
  Result := FData[FPos];
end;

function TSshReader.ReadByte: Byte; inline;
begin
  Need(1);
  Result := FData[FPos];
  Inc(FPos);
end;

procedure TSshReader.Skip(ACount: SizeUInt); inline;
begin
  Need(ACount);
  Inc(FPos, ACount);
end;

function TSshReader.ReadBoolean: Boolean; inline;
begin
  Result := ReadByte <> 0;
end;

function TSshReader.ReadUInt32: UInt32; inline;
begin
  Need(4);
  // 单源：复用 bytes.binary.ReadUInt32BE，避免手写移位
  Result := ReadUInt32BE(PByte(@FData[FPos]));
  Inc(FPos, 4);
end;

function TSshReader.ReadUInt64: UInt64; inline;
begin
  Result := (UInt64(ReadUInt32) shl 32) or UInt64(ReadUInt32);
end;

function TSshReader.ReadStringSpan: TByteSpan; inline;
var
  LLen: UInt32;
begin
  { perf: zero-copy view into FData — no SetLength/Move/alloc; lifetime bound to TSshReader.FData; empty → TByteSpan.Empty; single source TByteSpan.Create }
  LLen := ReadUInt32;
  Need(LLen);
  if LLen = 0 then
    Exit(TByteSpan.Empty);
  Result := TByteSpan.Create(PByte(@FData[FPos]), LLen);
  Inc(FPos, LLen);
end;

function TSshReader.ReadStringBytes: TBytes; inline;
begin
  { perf: single source via bytes.ops.SpanClone (SetLength+single Move zero-copy); ReadStringSpan is zero-alloc view, clone allocates only when caller needs owned TBytes; large payload callers can call ReadStringSpan to avoid alloc entirely }
  Result := nextpas.core.bytes.ops.SpanClone(ReadStringSpan);
end;

function TSshReader.ReadStringText: string;
var
  LSpan: TByteSpan;
begin
  { perf: direct span→string single Move, no intermediate TBytes alloc; LSpan is zero-copy view }
  LSpan := ReadStringSpan;
  if LSpan.Len = 0 then
    Exit('');
  SetLength(Result, LSpan.Len);
  Move(LSpan.Data^, Result[1], LSpan.Len);
end;

function TSshReader.ReadMPIntSpan: TByteSpan; inline;
var
  LSpan: TByteSpan;
begin
  { perf: zero-copy mpint magnitude view — ReadStringSpan zero-alloc + StripLeadingZeroSpan pointer bump, no alloc; negative check on view }
  LSpan := ReadStringSpan;
  if (LSpan.Len > 0) and ((LSpan.Data^ and $80) <> 0) then
    raise ESSHError.Create(sekProtocol, 'ssh buffer: mpint negative');
  Result := StripLeadingZeroSpan(LSpan);
end;

function TSshReader.ReadMPInt: TBytes; inline;
begin
  { perf: single source via bytes.ops.SpanClone; ReadMPIntSpan is zero-copy, clone is single Move — halves allocations vs old ReadStringBytes(alloc)+Strip+Move(double alloc) }
  Result := nextpas.core.bytes.ops.SpanClone(ReadMPIntSpan);
end;

function TSshReader.ReadNameList: TStringArray;
var
  LJoined: string;
begin
  LJoined := ReadStringText;
  if LJoined = '' then
    Exit(nil);
  { single source: one scan with RemoveEmpty, no second allocation }
  Result := StringsSplit(LJoined, ',', True);
end;

end.
