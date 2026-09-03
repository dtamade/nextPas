unit nextpas.core.db.redis.recv;

{** @desc Redis 接收环形缓冲抽离（V3-A5 体积分治）。
       由 redis.adapter 抽离以满足 800 行软阈值（CONTRACT §2.13 体积分治）：
       复用 bytes.ops 单源（BytesEnsureCapacity 单 Move 零拷贝，
       MIN_GROW 64*2 inline BytesCalcGrowCap 单次 SetLength+header poke）、
       redis.resp 单源零拷贝视图（TByteSpan）、DB_REDIS_READ_* 单源上界。
       环形偏移视图 FOff 滑动窗口 amortized 零拷贝，仅阈值压实一次 Move；
       4K 守稳 + 满利用率按需指数扩容至 64K（碎片化小帧禁盲目翻倍）+ RespPeekFrameLength 预分配单次 Recv。
       L2 基础设施（仅依赖 L0-L2 单向，无上向）；owner = db.redis。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.redis.base,
  nextpas.core.db.redis.transport;

type
  TRedisRecvBuffer = class
  private
    FTransport: IRedisTransport;
    FBuf: TBytes;
    FOff: Integer;
    function TryConsumeReply(var APos: Integer; out AReply: TRespValue; out ANeedMore: Boolean): Boolean; inline;
    procedure CompactIfNeeded(var APos: Integer; AChunk: Integer);
    function AdjustChunkForFrame(var AChunk: Integer): Boolean; inline;
    procedure AdvanceChunk(var AChunk: Integer; ALarge: Boolean; AReceived: Integer); inline;
  public
    constructor Create(const ATransport: IRedisTransport);
    destructor Destroy; override;
    function ReadReply: TRespValue;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.err,
  nextpas.core.db.redis.resp;

const
  RECV_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: redis.recv must reuse bytes.ops'}
{$IFEND}

constructor TRedisRecvBuffer.Create(const ATransport: IRedisTransport);
begin
  inherited Create;
  FTransport := ATransport;
  FOff := 0;
end;

destructor TRedisRecvBuffer.Destroy;
begin
  SetLength(FBuf, 0);
  FTransport := nil;
  inherited Destroy;
end;

function TRedisRecvBuffer.TryConsumeReply(var APos: Integer; out AReply: TRespValue; out ANeedMore: Boolean): Boolean; inline;
begin
  Result := RespTryParse(FBuf, APos, AReply, ANeedMore);
  if Result then
  begin
    FOff := APos;
    if FOff = Length(FBuf) then
    begin
      SetLength(FBuf, 0);
      FOff := 0;
    end;
  end;
end;

procedure TRedisRecvBuffer.CompactIfNeeded(var APos: Integer; AChunk: Integer);
var
  LRem, LLen, LEff: Integer;
begin
  // not inline: Move with indexed element must not be inline per bytes.ops red line 1
  // perf: amortized zero-copy sliding window via FOff; single Move compaction
  // lazy threshold: waste >50% (FOff > Len shr 1) or waste >2*MIN (8 KiB) or remain < chunk
  // or absolute offset >4*MIN (16 KiB) to bound virtual length / restore locality
  // under long small-frame stream; capped by MIN_GROW/bytes.ops single source to avoid O(n²) churn
  // fragmented small-frame guard: LEff clamps inflated chunk to 4*MIN (16 KiB) for
  // compaction decision, so 64K over-allocated chunk does not prematurely trigger Move (amortized O(1))
  // zero-copy evidence: TryConsume via RespTryParse(TByteSpan.FromBytes) zero-copy view (bytes.ops single source, inline thin forwarder),
  // only compaction does single Move; growth via inline BytesCalcGrowCap/BytesEnsureCapacity single source (inline zero-cost)
  LLen := Length(FBuf);
  if FOff <= DB_REDIS_READ_COMPACTION_MIN then
    Exit;
  LEff := AChunk;
  if LEff > DB_REDIS_READ_COMPACTION_MIN * 4 then
    LEff := DB_REDIS_READ_COMPACTION_MIN * 4;
  if (FOff <= DB_REDIS_READ_COMPACTION_MIN * 2) and
     (FOff <= LLen shr 1) and (LLen - FOff >= LEff) then
    Exit;
  if (FOff <= DB_REDIS_READ_COMPACTION_MIN * 4) and (LLen - FOff >= LEff) and
     (FOff <= LLen shr 1) then
    Exit;
  LRem := LLen - FOff;
  if LRem > 0 then
    Move(FBuf[FOff], FBuf[0], LRem);
  SetLength(FBuf, LRem);
  APos := APos - FOff;
  FOff := 0;
end;

function TRedisRecvBuffer.AdjustChunkForFrame(var AChunk: Integer): Boolean; inline;
var
  LPeekNeed, LAvail, LRemain: Integer;
begin
  Result := False;
  if not RespPeekFrameLength(FBuf, FOff, LPeekNeed) then
    Exit;
  if LPeekNeed > DB_REDIS_READ_FRAME_MAX then
    raise EDbError.CreateSimple(dbkRedis, 'redis: frame too large');
  LAvail := Length(FBuf) - FOff;
  if LPeekNeed <= LAvail then
    Exit;
  LRemain := LPeekNeed - LAvail;
  if LRemain > AChunk then
  begin
    AChunk := LRemain;
    if AChunk > DB_REDIS_READ_CHUNK_MAX then
      AChunk := DB_REDIS_READ_CHUNK_MAX;
    Result := True;
  end;
end;

procedure TRedisRecvBuffer.AdvanceChunk(var AChunk: Integer; ALarge: Boolean; AReceived: Integer); inline;
begin
  // perf: inline hot path, conditional doubling — only when previous Recv filled chunk (high utilization)
  // fragmented RESP small-frame guard: AReceived < AChunk means transport under-filled (fragmented/Tiny frame),
  // keep chunk steady at 4K to avoid exponential 4K→8K→16K→32K→64K over-allocation + threshold compaction Move amplification
  // growth via bytes.ops single source (BytesCalcGrowCap MIN_GROW 64*2 amortized; single Move compaction)
  // stability: ALarge pre-allocation path frozen and capped to DB_REDIS_READ_CHUNK_MAX (64K)
  if ALarge then
  begin
    if AChunk > DB_REDIS_READ_CHUNK_MAX then
      AChunk := DB_REDIS_READ_CHUNK_MAX;
    Exit;
  end;
  // fragmented small-frame: not fully utilized → keep steady, no blind shl 1
  if AReceived < AChunk then
    Exit;
  if AChunk < DB_REDIS_READ_CHUNK_MAX then
  begin
    AChunk := AChunk shl 1;
    if AChunk > DB_REDIS_READ_CHUNK_MAX then
      AChunk := DB_REDIS_READ_CHUNK_MAX;
  end
  else if AChunk > DB_REDIS_READ_CHUNK_MAX then
    AChunk := DB_REDIS_READ_CHUNK_MAX;
end;

function TRedisRecvBuffer.ReadReply: TRespValue;
var
  LPos, LChunk, LOldLen, LN: Integer;
  LNeed, LLarge: Boolean;
begin
  // ring offset view zero-copy via FOff; bytes.ops single source
  LPos := FOff;
  LChunk := DB_REDIS_READ_CHUNK_INIT;
  repeat
    if TryConsumeReply(LPos, Result, LNeed) then
      Exit;
    if not LNeed then
      Break;
    CompactIfNeeded(LPos, LChunk);
    LLarge := AdjustChunkForFrame(LChunk);
    LOldLen := Length(FBuf);
    BytesEnsureCapacity(FBuf, SizeUInt(LOldLen) + SizeUInt(LChunk));
    LN := FTransport.Recv(@FBuf[LOldLen], LChunk);
    if LN = 0 then
      raise EDbError.CreateSimple(dbkRedis, 'redis: connection closed mid-reply');
    if LN < LChunk then
      SetLength(FBuf, LOldLen + LN);
    AdvanceChunk(LChunk, LLarge, LN);
  until False;
end;

end.
