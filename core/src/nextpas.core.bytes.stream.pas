unit nextpas.core.bytes.stream;
{**
 * 可增长字节缓冲流（append / consume / compact 一体化）。
 *
 * 抽象了 IO 泵/协议栈中最常见的一类缓冲管理模式：字节流从尾部
 * 追加（网络读入、解密产出），从头部消费（交付调用方），消费到
 * 阈值后自动压实（memmove 搬回头部）——tlsfp 的 FPlainOut/FNetIn/
 * FNetTx 三处手搓同一模式（见 nextpas.core.net.async.tlsfp），
 * proxy888 数据面同类缓冲亦可复用。
 *
 * 设计要点：
 * - 容量保留：Clear/消费不释放底层块；Reserve 一次性预留后，追加
 *   路径零分配零复制（除非超出容量）。Grow 倍增且按需精确。
 * - 头游标：消费不搬移；仅当可用字节耗尽（或尾部余量不足且头部
 *   空洞可观）才压实。摊薄成本 O(消费量/压实阈值)。
 * - 内存上界由调用方以 Reserve/EnsureCapacity 显式声明；本模块
 *   不做隐式无限增长（S2 纪律：缓冲与连接数解耦，每连接有界）。
 * - 纯 core：无 FPC RTL 动态数组依赖（除基础类型），块经 TMemAllocator。
 *}

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.intf;

type
  TByteStreamBuf = class
  private
    FAllocator: IAllocator;
    FPtr: PByte;
    FCap: SizeUInt;
    FLen: SizeUInt;      { 有效字节数（头游标之后） }
    FOff: SizeUInt;      { 头游标：已消费前缀长度 }
    procedure Grow(const ANeeded: SizeUInt);
  public
    constructor Create(const AAllocator: IAllocator;
      const AInitialCapacity: SizeUInt = 0);
    destructor Destroy; override;

    { 容量 }
    function Capacity: SizeUInt; inline;
    function Length: SizeUInt; inline;
    { 未消费字节首指针（消费/读取视图起点） }
    function Data: PByte; inline;
    { 未消费字节数 }
    function Available: SizeUInt; inline;
    { 尾部空闲字节数（追加可直接写入的空间） }
    function TailSpace: SizeUInt; inline;

    { 预留：确保总容量 ≥ ANewCapacity（保留已有内容）。幂等。 }
    procedure EnsureCapacity(const ANewCapacity: SizeUInt);
    { 追加预留：确保尾部可再写 AAdditional 字节（必要时压实+增长）。
      返回可直接写入的尾部指针（写后必须 CommitAppend 提交长度）。 }
    function ReserveAppend(const AAdditional: SizeUInt): PByte;
    { 提交追加：ReserveAppend 返回的指针区已写入 ACount 字节。 }
    procedure CommitAppend(const ACount: SizeUInt); inline;
    { 追加（复制）。 }
    procedure Append(const AData: PByte; const ACount: SizeUInt);
    procedure AppendByte(const AValue: Byte);

    { 消费：从头部移除 ACount 字节（返回实际移除数）。 }
    function Consume(const ACount: SizeUInt): SizeUInt;
    { 清空（保留容量）。 }
    procedure Clear; inline;
    { 强制压实：把未消费字节搬回头部（消费后尾部余量不足时自动发生，
      一般无需手动调用）。 }
    procedure Compact;
  end;

implementation

uses
  nextpas.core.mem;

{ TByteStreamBuf }

constructor TByteStreamBuf.Create(const AAllocator: IAllocator;
  const AInitialCapacity: SizeUInt);
begin
  inherited Create;
  FAllocator := AAllocator;
  FPtr := nil;
  FCap := 0;
  FLen := 0;
  FOff := 0;
  if AInitialCapacity > 0 then
    EnsureCapacity(AInitialCapacity);
end;

destructor TByteStreamBuf.Destroy;
begin
  if FPtr <> nil then
  begin
    FreeMemOf(FAllocator, FPtr, FCap);
    FPtr := nil;
  end;
  inherited;
end;

function TByteStreamBuf.Capacity: SizeUInt;
begin
  Result := FCap;
end;

function TByteStreamBuf.Length: SizeUInt;
begin
  Result := FLen;
end;

function TByteStreamBuf.Data: PByte;
begin
  Result := FPtr + FOff;
end;

function TByteStreamBuf.Available: SizeUInt;
begin
  Result := FLen;
end;

function TByteStreamBuf.TailSpace: SizeUInt;
begin
  Result := FCap - (FOff + FLen);
end;

procedure TByteStreamBuf.Grow(const ANeeded: SizeUInt);
var
  LNewCap: SizeUInt;
begin
  LNewCap := FCap;
  if LNewCap = 0 then
    LNewCap := 4096;
  while LNewCap < ANeeded do
  begin
    if LNewCap <= High(SizeUInt) div 2 then
      LNewCap := LNewCap * 2
    else
    begin
      LNewCap := ANeeded;
      Break;
    end;
  end;
  { 增长时先把未消费字节搬回头部（若 FOff > 0），避免两段复制 }
  if (FOff > 0) and (FLen > 0) then
    Move(FPtr[FOff], FPtr[0], FLen);
  FOff := 0;
  FPtr := ReallocMemOf(FAllocator, FPtr, FCap, LNewCap);
  FCap := LNewCap;
end;

procedure TByteStreamBuf.EnsureCapacity(const ANewCapacity: SizeUInt);
begin
  if ANewCapacity <= FCap then
    Exit;
  Grow(ANewCapacity);
end;

function TByteStreamBuf.ReserveAppend(const AAdditional: SizeUInt): PByte;
begin
  if FOff + FLen + AAdditional > FCap then
  begin
    { 尾部不够：先压实（搬回头部腾出尾部），仍不够再增长 }
    if FLen + AAdditional <= FCap then
      Compact
    else
      Grow(FOff + FLen + AAdditional);
  end;
  Result := FPtr + FOff + FLen;
end;

procedure TByteStreamBuf.CommitAppend(const ACount: SizeUInt);
begin
  Inc(FLen, ACount);
end;

procedure TByteStreamBuf.Append(const AData: PByte; const ACount: SizeUInt);
begin
  if ACount = 0 then
    Exit;
  Move(AData^, ReserveAppend(ACount)^, ACount);
  CommitAppend(ACount);
end;

procedure TByteStreamBuf.AppendByte(const AValue: Byte);
begin
  ReserveAppend(1)^ := AValue;
  CommitAppend(1);
end;

function TByteStreamBuf.Consume(const ACount: SizeUInt): SizeUInt;
begin
  if ACount >= FLen then
  begin
    Result := FLen;
    FOff := 0;
    FLen := 0;
    Exit;
  end;
  Result := ACount;
  Inc(FOff, ACount);
  Dec(FLen, ACount);
end;

procedure TByteStreamBuf.Clear;
begin
  FOff := 0;
  FLen := 0;
end;

procedure TByteStreamBuf.Compact;
begin
  if (FOff > 0) and (FLen > 0) then
    Move(FPtr[FOff], FPtr[0], FLen);
  FOff := 0;
end;

end.
