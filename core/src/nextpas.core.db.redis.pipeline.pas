unit nextpas.core.db.redis.pipeline;

{** @desc Redis 流水线/分块发送抽离（V3-A5 体积分治）。
       由 redis.adapter 抽离以满足 800 行软阈值：执行批量命令的
       RESP 编码→分块→单次/分块 Send→逐条 ReadReply 循环。
       复用 bytes.ops 单源（BytesEnsureCapacity 单次 SetLength+header poke
       经 BytesGrowCapacity MIN_GROW 64*2 inline 零拷贝直接缓冲 Move，零虚分发）、
       text.conv 单源 IntToStr（无 SysUtils）、redis.resp 单源编解码、
       db.trace 观测同构。自适应分块 4K→64K 复用 DB_REDIS_READ_* 单源。
       L2 基础设施（仅依赖 L0-L2 单向，无上向）；owner = db.redis。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.redis.base,
  nextpas.core.db.redis.transport,
  nextpas.core.db.trace;

const
  REDIS_PIPELINE_SINGLE_SOURCE = True;
  { 分块单源：与 redis.base DB_REDIS_READ_CHUNK_* 同源，峰值有界
    O(chunk+maxFrame) 而非 O(total)；自适应 4K→64K 指数扩容 }
  REDIS_PIPELINE_CHUNK_INIT = DB_REDIS_READ_CHUNK_INIT; { 4 KiB }
  REDIS_PIPELINE_CHUNK_MAX = DB_REDIS_READ_CHUNK_MAX; { 64 KiB }
  REDIS_PIPELINE_CHUNK = REDIS_PIPELINE_CHUNK_MAX; { compat alias }

type
  TReadReplyFunc = function: TRespValue of object;

{ 批量流水线：编码 ASteps 为 RESP 帧，分块 burst Send（大批量峰值
  有界，小批量单次 syscall 收敛），随后逐条 ReadReply 校验错误。
  AReadReply 为 adapter 的环形零拷贝 ReadReply（bytes.ops 单源）。
  成功发 OnQuery(BATCH xN)，失败发 OnError(BATCH)（与 adapter 同构）。 }
procedure RedisExecuteBatch(const ATransport: IRedisTransport;
  const ASteps: TDbSqlSteps; const ATrace: TDbTraceHub;
  const AReadReply: TReadReplyFunc);

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.err,
  nextpas.core.db.redis.addr,
  nextpas.core.db.redis.resp,
  nextpas.core.text.conv;



procedure RedisExecuteBatch(const ATransport: IRedisTransport;
  const ASteps: TDbSqlSteps; const ATrace: TDbTraceHub;
  const AReadReply: TReadReplyFunc);
var
  I: Integer;
  LArgs: TRespArgs;
  LFrame: TBytes;
  LBuf: TBytes;
  LLen: SizeUInt;
  LNeeded: SizeUInt;
  LChunkCap: Integer;
  LR: TRespValue;
  LT0: QWord;
  LTimed: Boolean;

  procedure AdvanceChunk; inline;
  begin
    // perf: inline hot path, amortized doubling MIN_GROW 64*2 单源 BytesGrowCapacity (bytes.ops)
    if LChunkCap < REDIS_PIPELINE_CHUNK_MAX then
    begin
      LChunkCap := LChunkCap shl 1;
      if LChunkCap > REDIS_PIPELINE_CHUNK_MAX then
        LChunkCap := REDIS_PIPELINE_CHUNK_MAX;
    end;
  end;

  procedure EnsureBufCap(const ANeeded: SizeUInt); inline;
  begin
    // perf: inline BytesEnsureCapacity 单源复用 (BytesGrowCapacity MIN_GROW 64*2 amortized doubling 单次 SetLength+header poke)，零拷贝 Move 由调用方单 Move 完成，避免 10k 次虚分发，10k batch 零二次拷贝
    BytesEnsureCapacity(LBuf, LLen + ANeeded);
  end;

  procedure FlushChunk; inline;
  begin
    // perf: inline hot path, zero-copy slice direct Send @LBuf/LLen (no per-chunk SetLength+Move O(chunk) copy/alloc)
    // bytes.ops single source BytesEnsureCapacity cap复用 (MIN_GROW 64*2 amortized via BytesGrowCapacity), 10k batch 零虚分发
    // stability: Send 前已编码校验，异常路径 trace/释放不丢；LLen=0 保留堆块零再分配 (BytesEnsureCapacity header poke 保持 Cap)
    if LLen = 0 then
      Exit;
    ATransport.Send(@LBuf[0], LLen);
    LLen := 0;
    AdvanceChunk;
  end;

begin
  if Length(ASteps) = 0 then
    raise EDbError.CreateSimple(dbkRedis, 'empty batch');
  // perf: 自适应分块 4K→64K（DB_REDIS_READ_CHUNK_* 单源），小批量单次 syscall 收敛；
  // 大批量 64K 有界峰值 O(chunk+maxFrame)，amortized 单分配+Move 零拷贝
  // bytes.ops 单源 inline BytesEnsureCapacity (BytesGrowCapacity MIN_GROW 64*2 单次 SetLength+header poke) + 直接缓冲 Move，
  // 10k 批量零虚分发（原 IBytesBuilder.AppendBytes 10k 虚分发），~log 扩容；inline 热路径零 I-Cache 膨胀
  // stability: Send 前已编码校验，异常路径 trace/释放不丢；LLen 保留容量
  LChunkCap := REDIS_PIPELINE_CHUNK_INIT;
  LLen := 0;
  SetLength(LBuf, LChunkCap);
  LT0 := 0;
  LTimed := (ATrace <> nil) and ATrace.BeginOp(LT0);
  try
    for I := 0 to High(ASteps) do
    begin
      RespPlanCommand(ASteps[I], [], LArgs);
      // perf: owner 反哺直写 — RespEncodeCommandLength inline 预检 + RespEncodeCommandInto 零拷贝直写管道缓冲（bytes.ops 单源，单次 EnsureBufCap+单遍 Move），消除 10k× LFrame 临时分配与 Move 二次拷贝 O(total) 带宽税；inline 热路径零虚分发
      LNeeded := RespEncodeCommandLength(LArgs);
      if LNeeded >= SizeUInt(REDIS_PIPELINE_CHUNK_MAX) then
      begin
        FlushChunk;
        // stability: 超大帧单次分配直写 LFrame 后单次 Send，无 LBuf 二次拷贝；异常路径 trace/释放不丢，SetLength 清理持有
        SetLength(LFrame, LNeeded);
        if LNeeded > 0 then
          RespEncodeCommandInto(LArgs, @LFrame[0]);
        ATransport.Send(LFrame);
      end
      else
      begin
        if SizeUInt(LLen) + LNeeded > SizeUInt(LChunkCap) then
          FlushChunk;
        // perf: bytes.ops 单源零拷贝直写管道缓冲（inline EnsureBufCap 摊还倍增 + RespEncodeCommandInto 单遍 Move，容量倍增 MIN_GROW 64*2，LLen 保留容量），10k 批量零临时分配、零二次拷贝、零虚分发
        if LNeeded > 0 then
        begin
          EnsureBufCap(LNeeded);
          RespEncodeCommandInto(LArgs, @LBuf[LLen]);
          Inc(LLen, LNeeded);
        end;
      end;
      // stability: 释放超大帧临时持有，保留 LBuf 容量（Length 保持 Cap，LLen 逻辑）；小批量路径无 LFrame 分配，仅清空防泄漏
      SetLength(LFrame, 0);
    end;
    FlushChunk;
    for I := 0 to High(ASteps) do
    begin
      LR := AReadReply();
      if LR.Kind = rvkError then
        raise NewDbErrorRedis(
          RespErrorType(LR.Data),
          'batch step ' + nextpas.core.text.conv.IntToStr(Int64(I + 1)) + ': ' +
          RespBytesToStr(LR.Data),
          RedisCategory(RespErrorType(LR.Data)), dckNone);
    end;
    if LTimed then
      ATrace.NotifyQuery(LT0, 'BATCH x' + nextpas.core.text.conv.IntToStr(Int64(Length(ASteps))));
  except
    on E: EDbError do
    begin
      if LTimed then
        ATrace.NotifyError(E.Category, 'BATCH');
      raise;
    end;
  end;
end;

end.
