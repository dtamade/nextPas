unit nextpas.core.db.redis.resp;

{** @desc RESP2 协议编解码纯函数（V3-A5）。
       编码：参数数组 → RESP array-of-bulk-strings 帧（二进制安全，
       值无需转义——长度前缀即注入安全边界）。解析：增量式
       TryParse（数据不足返回 false 不抛错），数组递归；RESP2 空形
       （$-1/*-1）与 RESP3 `_` 归 rvkNull。错误帧（-）不在此归一
       分类，仅解出 ErrType/载荷——语义映射在 db.err.ClassifyRedis。

       本单元无 IO、无 transport 依赖，独立可测（test_db_redis_base
       钉死帧格式与增量解析行为）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.text.number,
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.db.base,
  nextpas.core.db.redis.base;

type
  TRespArgs = array of TBytes;   { 命令参数计划产物 }

{ 参数数组 → RESP 命令帧：*N\r\n $len\r\n <data> \r\n ... }
procedure RespEncodeCommand(const AArgs: array of TBytes;
  out AOut: TBytes);
{ 单帧长度预检（owner 单源：RespDigitsLen 阈值比较零 UIntToBuffer 填充，inline 零分配）；用于 pipeline 直写预留，一次长度计算单次编码，消除 LFrame 临时二次拷贝 }
function RespEncodeCommandLength(const AArgs: array of TBytes): SizeUInt; inline;
{ 直接编码至已预留缓冲（零拷贝 Move 单源 text.number.UIntToBuffer + bulk Move，调用方预 EnsureCap，直写 ADest 无临时分配/二次拷贝）；not inline 因含索引 Move }
procedure RespEncodeCommandInto(const AArgs: array of TBytes; ADest: PByte);

{ 命令文本 → 参数计划：空白分词（'...' 引号字面量内不分词），
  ? 顺序槽 / ?N 显式槽替换为对应绑定值的独立 bulk 参数。
  返回物理参数个数；ARewritten 无用（RESP 无重写文案），保留
  出参仅为与 TranslatePlaceholders* 家族签名同构的说明性占位。
  未绑定槽 / 未知 ?N / 重复逻辑号 fail-fast 抛 EDbError。 }
function RespPlanCommand(const ASql: string;
  const ABound: array of TBytes; out AArgs: TRespArgs): Integer;

{ 从 APos 起尝试解析一个完整回复。解析成功 = Result true 且
  APos 前移；缓冲不足 = false 且 ANeedMore true；帧格式非法 =
  抛 EDbError(dbkRedis)。 }
function RespTryParse(const ABuf: TBytes; var APos: Integer;
  out AValue: TRespValue; out ANeedMore: Boolean): Boolean; overload;
{ Span 零拷贝重载：直接以 TByteSpan 视图解析（bytes.ops 单源 TByteSpan.FromBytes/Slice
  零拷贝、无堆分配；高吞吐 pump 以窗口 Span 喂解析，彻底消除 Copy 全量拷贝导致的 O(n²)）。
  Owner 反哺：resp 作为协议解析 owner 提供 Span 能力，subscribe 等高频消费方复用单源视图。 }
// perf: not inline (递归 + 线性扫描) per red line 2, zero-copy view via TByteSpan (bytes.ops single source), no alloc per frame
function RespTryParse(const ASpan: TByteSpan; var APos: Integer;
  out AValue: TRespValue; out ANeedMore: Boolean): Boolean; overload;

{ 预览单帧完整长度（零拷贝，不分配 Value）：从 APos 起若首部已完整可计算
  帧总字节数（含终止 CRLF、bulk 载荷、数组递归），返回 True 且 ANeeded 为总长；
  首部不完整则 False（需更多字节才可预分配）。用于 ReadReply 按 frameLen 一次性
  预分配以削减 64K cap 下 1MiB 帧的 16 次 Recv。 }
// perf: not inline per red line 2 (递归/扫描), zero-copy span scan, inline header poke single source
function RespPeekFrameLength(const ASpan: TByteSpan; APos: Integer;
  out ANeeded: Integer): Boolean; overload;
function RespPeekFrameLength(const ABuf: TBytes; APos: Integer;
  out ANeeded: Integer): Boolean; overload;

{ 错误载荷首词（ERR/Wrongpass/MOVED…）：大写化 ASCII 后返回 }
function RespErrorType(const APayload: TBytes): string;

{ bulk/simple/int 值渲染为文本（GetText 面）；array 不适用 }
function RespValueToText(const AValue: TRespValue): string;

{ 载荷字节 → 文本（SetString 直拷，无转码假设）}
function RespBytesToStr(const ABuf: TBytes): string;

{ INFO 文本载荷取段键值：按 CRLF 行扫 section:key=value，命中首个
  AKey 返回 value，未命中空串。ASection 非 '#' 行即全局段。 }
function RespInfoFieldValue(const APayload: TBytes;
  const AKey: string): string;

implementation

function RespBytesToStr(const ABuf: TBytes): string;
begin
  if Length(ABuf) = 0 then
    Exit('');
  SetString(Result, PAnsiChar(@ABuf[0]), Length(ABuf));
end;

{ String→Bytes 单源：bytes.ops.StringToBytes 单 Move 零拷贝证据 }
// perf: not inline per bytes.ops red line 1 (Move with indexed element must not be inline, avoids I-Cache bloat); single Move via bytes.ops.StringToBytes single source
function StrToBytes(const AStr: string): TBytes;
begin
  Result := StringToBytes(AStr);
end;

procedure RespAppendCrlf(var ABuf: TBytes);
var
  LOld: SizeUInt;
  LNeed: SizeUInt;
begin
  // perf: single allocation via bytes.ops.BytesEnsureCapacity (amortized doubling MIN_GROW 64, single SetLength + header poke), zero-copy
  LOld := SizeUInt(Length(ABuf));
  LNeed := LOld + 2;
  BytesEnsureCapacity(ABuf, LNeed);
  ABuf[LOld] := 13;
  ABuf[LOld + 1] := 10;
end;

procedure RespAppendLine(var ABuf: TBytes; const AHead: AnsiChar;
  const ATail: TBytes); overload;
var
  LOld, LTail: SizeUInt;
  LNeed: SizeUInt;
begin
  // perf: pre-growth single allocation via bytes.ops.BytesEnsureCapacity (single SetLength + poke), zero-copy Move; header+tail+CRLF single growth, not two SetLengths
  LOld := SizeUInt(Length(ABuf));
  LTail := SizeUInt(Length(ATail));
  LNeed := LOld + 1 + LTail + 2;
  BytesEnsureCapacity(ABuf, LNeed);
  ABuf[LOld] := Ord(AHead);
  if LTail > 0 then
    Move(ATail[0], ABuf[LOld + 1], LTail);
  ABuf[LOld + 1 + LTail] := 13;
  ABuf[LOld + 1 + LTail + 1] := 10;
end;

function RespDigitsLen(const AVal: SizeUInt): SizeUInt; inline;
begin
  // perf: threshold compares (no div/mod, no buffer fill) — ~5 compares avg vs UIntToBuffer digit-pair loop + Move
  // single source counting for length preflight; actual encoding still via text.number.UIntToBuffer single pass
  if AVal < 10000000000 then
  begin
    if AVal < 100000 then
    begin
      if AVal < 1000 then
      begin
        if AVal < 10 then Exit(1)
        else if AVal < 100 then Exit(2)
        else Exit(3);
      end
      else
      begin
        if AVal < 10000 then Exit(4) else Exit(5);
      end;
    end
    else
    begin
      if AVal < 100000000 then
      begin
        if AVal < 1000000 then Exit(6)
        else if AVal < 10000000 then Exit(7)
        else Exit(8);
      end
      else
      begin
        if AVal < 1000000000 then Exit(9) else Exit(10);
      end;
    end;
  end
  else
  begin
    if AVal < 1000000000000000 then
    begin
      if AVal < 1000000000000 then
      begin
        if AVal < 100000000000 then Exit(11) else Exit(12);
      end
      else
      begin
        if AVal < 10000000000000 then Exit(13)
        else if AVal < 100000000000000 then Exit(14)
        else Exit(15);
      end;
    end
    else
    begin
      if AVal < 1000000000000000000 then
      begin
        if AVal < 10000000000000000 then Exit(16)
        else if AVal < 100000000000000000 then Exit(17)
        else Exit(18);
      end
      else
      begin
        if AVal < 10000000000000000000 then Exit(19) else Exit(20);
      end;
    end;
  end;
end;

function RespEncodeCommandLength(const AArgs: array of TBytes): SizeUInt; inline;
var
  I: Integer;
begin
  // perf: inline threshold compares (RespDigitsLen) zero alloc, single source length preflight for direct-encode reservation
  Result := 1 + RespDigitsLen(SizeUInt(Length(AArgs))) + 2;
  for I := 0 to High(AArgs) do
    Result := Result + 1 + RespDigitsLen(SizeUInt(Length(AArgs[I]))) + 2 + SizeUInt(Length(AArgs[I])) + 2;
end;

procedure RespEncodeCommandInto(const AArgs: array of TBytes; ADest: PByte);
var
  I: Integer;
  LPos: SizeUInt;
  LTail: SizeUInt;
begin
  // perf: not inline per red line 1 (Move with indexed element must not be inline); zero-copy via text.number.UIntToBuffer direct into buffer tail, single bulk Move per arg
  // owner single source: pipeline/reuse direct encode without LFrame temp, eliminates 10k× O(total) double copy + extra allocation, bandwidth tax
  if ADest = nil then
    Exit;
  LPos := 0;
  ADest[LPos] := Ord('*');
  Inc(LPos);
  LTail := SizeUInt(UIntToBuffer(SizeUInt(Length(AArgs)), PAnsiChar(@ADest[LPos])));
  Inc(LPos, LTail);
  ADest[LPos] := 13;
  ADest[LPos + 1] := 10;
  Inc(LPos, 2);
  for I := 0 to High(AArgs) do
  begin
    ADest[LPos] := Ord('$');
    Inc(LPos);
    LTail := SizeUInt(UIntToBuffer(SizeUInt(Length(AArgs[I])), PAnsiChar(@ADest[LPos])));
    Inc(LPos, LTail);
    ADest[LPos] := 13;
    ADest[LPos + 1] := 10;
    Inc(LPos, 2);
    LTail := SizeUInt(Length(AArgs[I]));
    if LTail > 0 then
    begin
      Move(AArgs[I][0], ADest[LPos], LTail);
      Inc(LPos, LTail);
    end;
    ADest[LPos] := 13;
    ADest[LPos + 1] := 10;
    Inc(LPos, 2);
  end;
end;

procedure RespEncodeCommand(const AArgs: array of TBytes;
  out AOut: TBytes);
var
  LTotal: SizeUInt;
begin
  // perf: single source via RespEncodeCommandLength (inline threshold) + RespEncodeCommandInto (direct tail write), single BytesEnsureCapacity alloc, bulk Move zero-copy
  // not inline per red line 1 (Move with indexed element must not be inline)
  LTotal := RespEncodeCommandLength(AArgs);
  SetLength(AOut, 0);
  if LTotal = 0 then
    Exit;
  BytesEnsureCapacity(AOut, LTotal);
  RespEncodeCommandInto(AArgs, @AOut[0]);
end;

function IsSpace(C: Char): Boolean; inline;
begin
  Result := (C = ' ') or (C = #9) or (C = #13) or (C = #10);
end;

{ 计划命令参数。扫描规则对齐家族 ?/?N 槽位契约：Seq 只对裸 ?
  递增；显式 ?N 映射逻辑号 N；重复逻辑号不支持（fail-fast）。 }
function RespPlanCommand(const ASql: string;
  const ABound: array of TBytes; out AArgs: TRespArgs): Integer;
var
  LTok: string;
  LSlots: array of Integer;   { 物理 slot -> 逻辑号 }
  I, J, LStart, LEnd: Integer;
  LSeq, LLogical: Integer;
  LArgCount, LSlotCount: Integer;

  // perf: amortized doubling via bytes.ops BytesCalcGrowCap single source (MIN_GROW 64,*2) — avoids O(n²) SetLength Move in 999-placeholder pipeline; single SetLength to Cap, zero-copy Move
  procedure EnsureArgs(const ARequired: Integer); inline;
  var
    LCap: SizeUInt;
  begin
    if ARequired <= Length(AArgs) then Exit;
    LCap := BytesCalcGrowCap(SizeUInt(Length(AArgs)), SizeUInt(ARequired));
    SetLength(AArgs, Integer(LCap));
  end;

  procedure EnsureSlots(const ARequired: Integer); inline;
  var
    LCap: SizeUInt;
  begin
    if ARequired <= Length(LSlots) then Exit;
    LCap := BytesCalcGrowCap(SizeUInt(Length(LSlots)), SizeUInt(ARequired));
    SetLength(LSlots, Integer(LCap));
  end;

  procedure EmitToken(const ATxt: string);
  begin
    // perf: pre-reserve via BytesCalcGrowCap single source, not per-token SetLength(Len+1) O(n²) Move
    EnsureArgs(LArgCount + 1);
    AArgs[LArgCount] := StrToBytes(ATxt);
    Inc(LArgCount);
  end;

  procedure EmitSlot(ALogical: Integer);
  var
    LS: Integer;
  begin
    for LS := 0 to LSlotCount - 1 do
      if LSlots[LS] = ALogical then
        raise EDbError.CreateSimple(dbkRedis,
          'duplicate placeholder logical number ?' + IntToStr(ALogical));
    if (ALogical < 1) or (ALogical > Length(ABound)) then
      raise EDbError.CreateSimple(dbkRedis,
        'placeholder ?' + IntToStr(ALogical) + ' unbound (' +
        IntToStr(Length(ABound)) + ' params bound)');
    EnsureSlots(LSlotCount + 1);
    LSlots[LSlotCount] := ALogical;
    Inc(LSlotCount);
    EnsureArgs(LArgCount + 1);
    AArgs[LArgCount] := ABound[ALogical - 1];
    Inc(LArgCount);
  end;

begin
  SetLength(AArgs, 0);
  SetLength(LSlots, 0);
  LArgCount := 0;
  LSlotCount := 0;
  LSeq := 0;
  I := 1;
  while I <= Length(ASql) do
  begin
    if IsSpace(ASql[I]) then
    begin
      Inc(I);
      Continue;
    end;
    { 一个 token：'...' 引号包裹时剥壳取内容（引号是词边界标记，
      不属于参数值）；其余按空白截断 }
    if ASql[I] = '''' then
    begin
      Inc(I);
      LStart := I;
      while (I <= Length(ASql)) and (ASql[I] <> '''') do
        Inc(I);
      if I > Length(ASql) then
        raise EDbError.CreateSimple(dbkRedis,
          'unterminated quoted literal in command');
      LEnd := I - 1;
      Inc(I);
    end
    else
    begin
      LStart := I;
      while (I <= Length(ASql)) and not IsSpace(ASql[I]) do
        Inc(I);
      LEnd := I - 1;
    end;
    LTok := Copy(ASql, LStart, LEnd - LStart + 1);

    { 槽位判定：裸 ? / ?N / 其余字面 token }
    if LTok = '?' then
    begin
      Inc(LSeq);
      EmitSlot(LSeq);
    end
    else if (Length(LTok) >= 2) and (LTok[1] = '?') and
            (LTok[2] in ['1'..'9']) then
    begin
      LLogical := 0;
      for J := 2 to Length(LTok) do
        if LTok[J] in ['0'..'9'] then
          LLogical := LLogical * 10 + (Ord(LTok[J]) - Ord('0'))
        else
          raise EDbError.CreateSimple(dbkRedis,
            'malformed placeholder token "' + LTok + '"');
      EmitSlot(LLogical);
    end
    else
      EmitToken(LTok);
  end;
  // stability: trim over-reserved cap to logical count (single SetLength, FPC shrink keeps block no Move if still fits); capacity via BytesCalcGrowCap single source
  if Length(AArgs) <> LArgCount then
    SetLength(AArgs, LArgCount);
  Result := LArgCount;
end;

function ReadCrlfLine(const ABuf: TBytes; APos: Integer;
  out ALine: TBytes; out ANext: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  I := APos;
  while I <= High(ABuf) do
  begin
    if (ABuf[I] = 13) and (I + 1 <= High(ABuf)) then
    begin
      if ABuf[I + 1] <> 10 then
        raise EDbError.CreateSimple(dbkRedis,
          'resp: CR without LF');
      SetLength(ALine, I - APos);
      if I > APos then
        Move(ABuf[APos], ALine[0], I - APos);
      ANext := I + 2;
      Result := True;
      Exit;
    end;
    Inc(I);
  end;
end;

function ParseScalar(AKind: TRespValueKind; const ALine: TBytes;
  out AValue: TRespValue): Boolean;
var
  LTxt: string;
  LCode: Integer;
begin
  Result := True;
  AValue.Kind := AKind;
  case AKind of
    rvkInteger:
      begin
        LTxt := RespBytesToStr(ALine);
        if LTxt = '' then
          raise EDbError.CreateSimple(dbkRedis, 'resp: empty integer');
        Val(LTxt, AValue.Int, LCode);
        if LCode <> 0 then
          raise EDbError.CreateSimple(dbkRedis,
            'resp: malformed integer "' + LTxt + '"');
      end;
    rvkBulk, rvkArray:
      begin
        { 长度行：-1 合法（RESP2 空形，调用方转 null），其余负数非法 }
        LTxt := RespBytesToStr(ALine);
        Val(LTxt, AValue.Int, LCode);
        if (LCode <> 0) or ((AValue.Int < 0) and (AValue.Int <> -1)) then
          raise EDbError.CreateSimple(dbkRedis,
            'resp: malformed length "' + LTxt + '"');
      end;
    rvkSimple, rvkError, rvkNull:
      begin end;   { 不经此路径：ParseScalar 仅消费数值型行头 }
  end;
end;

function ReadCrlfLineSpan(const ASpan: TByteSpan; APos: Integer;
  out ALine: TBytes; out ANext: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  I := APos;
  // perf: linear scan on TByteSpan view (bytes.ops single source), zero-copy, not inline per red line 2
  while I < Integer(ASpan.Len) do
  begin
    if (ASpan.Data[I] = 13) and (I + 1 < Integer(ASpan.Len)) then
    begin
      if ASpan.Data[I + 1] <> 10 then
        raise EDbError.CreateSimple(dbkRedis,
          'resp: CR without LF');
      SetLength(ALine, I - APos);
      if I > APos then
        Move(ASpan.Data[APos], ALine[0], I - APos);
      ANext := I + 2;
      Result := True;
      Exit;
    end;
    Inc(I);
  end;
end;

// perf: Span 零拷贝主路径（bytes.ops TByteSpan 单源视图，不分配 Copy；递归增量解析，amortized 单遍扫描）
// not inline per red line 2: recursive + bulk Move must not be inline
function RespTryParse(const ASpan: TByteSpan; var APos: Integer;
  out AValue: TRespValue; out ANeedMore: Boolean): Boolean;
var
  C: AnsiChar;
  LLine, LLn: TBytes;
  LNext, I, LLen, LChildPos: Integer;
  LChild: TRespValue;
  LChildNeed: Boolean;
begin
  Result := False;
  ANeedMore := False;
  if (ASpan.Len = 0) or (APos >= Integer(ASpan.Len)) then
  begin
    ANeedMore := True;
    Exit;
  end;
  C := AnsiChar(ASpan.Data[APos]);
  case C of
    '+', '-':
      begin
        if not ReadCrlfLineSpan(ASpan, APos + 1, LLine, LNext) then
        begin
          ANeedMore := True;
          Exit;
        end;
        APos := LNext;
        if C = '+' then
          AValue.Kind := rvkSimple
        else
          AValue.Kind := rvkError;
        AValue.Data := LLine;
        Result := True;
      end;
    ':':
      begin
        if not ReadCrlfLineSpan(ASpan, APos + 1, LLine, LNext) then
        begin
          ANeedMore := True;
          Exit;
        end;
        APos := LNext;
        ParseScalar(rvkInteger, LLine, AValue);
        Result := True;
      end;
    '$':
      begin
        if not ReadCrlfLineSpan(ASpan, APos + 1, LLn, LNext) then
        begin
          ANeedMore := True;
          Exit;
        end;
        ParseScalar(rvkBulk, LLn, AValue);
        if AValue.Int = -1 then
        begin
          APos := LNext;
          AValue.Kind := rvkNull;
          Result := True;
          Exit;
        end;
        LLen := Integer(AValue.Int);
        if LNext + LLen + 2 > Integer(ASpan.Len) then
        begin
          ANeedMore := True;
          Exit;
        end;
        SetLength(AValue.Data, LLen);
        if LLen > 0 then
          Move(ASpan.Data[LNext], AValue.Data[0], LLen);
        if (ASpan.Data[LNext + LLen] <> 13) or (ASpan.Data[LNext + LLen + 1] <> 10)
        then
          raise EDbError.CreateSimple(dbkRedis,
            'resp: bulk missing CRLF terminator');
        APos := LNext + LLen + 2;
        Result := True;
      end;
    '*':
      begin
        if not ReadCrlfLineSpan(ASpan, APos + 1, LLn, LNext) then
        begin
          ANeedMore := True;
          Exit;
        end;
        ParseScalar(rvkArray, LLn, AValue);
        if AValue.Int = -1 then
        begin
          APos := LNext;
          AValue.Kind := rvkNull;
          Result := True;
          Exit;
        end;
        LLen := Integer(AValue.Int);
        SetLength(AValue.Items, LLen);
        LChildPos := LNext;
        for I := 0 to LLen - 1 do
        begin
          if not RespTryParse(ASpan, LChildPos, LChild, LChildNeed) then
          begin
            ANeedMore := True;
            Exit;
          end;
          AValue.Items[I] := LChild;
        end;
        APos := LChildPos;
        Result := True;
      end;
    '_':
      begin
        if not ReadCrlfLineSpan(ASpan, APos + 1, LLine, LNext) then
        begin
          ANeedMore := True;
          Exit;
        end;
        APos := LNext;
        AValue.Kind := rvkNull;
        Result := True;
      end;
  else
    raise EDbError.CreateSimple(dbkRedis,
      'resp: unknown reply type byte $' + IntToHex(Ord(C), 2));
  end;
end;

function RespTryParse(const ABuf: TBytes; var APos: Integer;
  out AValue: TRespValue; out ANeedMore: Boolean): Boolean;
begin
  // perf: thin inline forwarder to Span single source (bytes.ops TByteSpan.FromBytes zero-copy view, no Copy)
  Result := RespTryParse(TByteSpan.FromBytes(ABuf), APos, AValue, ANeedMore);
end;

{ ---- frame length peek (owner 反哺：resp 提供帧长预分配能力，adapter 复用) ---- }

function PeekFindCrlf(const ASpan: TByteSpan; AStart: Integer;
  out ACrlfPos: Integer): Boolean;
var
  I: Integer;
begin
  I := AStart;
  while I + 1 < Integer(ASpan.Len) do
  begin
    if (ASpan.Data[I] = 13) and (ASpan.Data[I + 1] = 10) then
    begin
      if I > 0 then
        if ASpan.Data[I - 1] = 13 then
        begin
          // guard: avoid mis-align on stray CR without LF already raised elsewhere; treat as not found until LF verified
        end;
      ACrlfPos := I;
      Exit(True);
    end;
    Inc(I);
  end;
  Result := False;
end;

function PeekParseInt(const ASpan: TByteSpan; AFrom, AToExcl: Integer;
  out AVal: Int64): Boolean;
var
  I: Integer;
  LNeg: Boolean;
  LVal: Int64;
  B: Byte;
begin
  Result := False;
  if AFrom >= AToExcl then Exit;
  LNeg := False;
  I := AFrom;
  if ASpan.Data[I] = Ord('-') then
  begin
    LNeg := True;
    Inc(I);
    if I >= AToExcl then Exit;
  end;
  LVal := 0;
  while I < AToExcl do
  begin
    B := ASpan.Data[I];
    if (B < Ord('0')) or (B > Ord('9')) then Exit;
    // overflow guard: RESP length fits Int64; cap at 1G+ to avoid wrap, treat as invalid
    if LVal > (High(Int64) div 10) then Exit;
    LVal := LVal * 10 + Int64(B - Ord('0'));
    Inc(I);
  end;
  if LNeg then LVal := -LVal;
  AVal := LVal;
  Result := True;
end;

function RespPeekFrameLength(const ASpan: TByteSpan; APos: Integer;
  out ANeeded: Integer): Boolean;
var
  C: AnsiChar;
  LCrlf, LNext, LChildPos, LChildNeed, LSum, LLen: Integer;
  LVal: Int64;
  I: Integer;
begin
  Result := False;
  ANeeded := 0;
  if (ASpan.Len = 0) or (APos < 0) or (APos >= Integer(ASpan.Len)) then Exit;
  C := AnsiChar(ASpan.Data[APos]);
  case C of
    '+', '-', ':','_':
      begin
        if not PeekFindCrlf(ASpan, APos + 1, LCrlf) then Exit;
        ANeeded := (LCrlf + 2) - APos;
        Result := True;
      end;
    '$':
      begin
        if not PeekFindCrlf(ASpan, APos + 1, LCrlf) then Exit;
        if not PeekParseInt(ASpan, APos + 1, LCrlf, LVal) then Exit;
        LNext := LCrlf + 2;
        if LVal = -1 then
        begin
          ANeeded := LNext - APos;
          Result := True;
          Exit;
        end;
        if (LVal < 0) or (LVal > DB_REDIS_READ_FRAME_MAX + 1024) then Exit; // defensive cap single source DB_REDIS_READ_FRAME_MAX, let full parser raise; peek fails => fallback chunk
        LLen := Integer(LVal);
        ANeeded := (LNext - APos) + LLen + 2;
        Result := True;
      end;
    '*':
      begin
        if not PeekFindCrlf(ASpan, APos + 1, LCrlf) then Exit;
        if not PeekParseInt(ASpan, APos + 1, LCrlf, LVal) then Exit;
        LNext := LCrlf + 2;
        if LVal = -1 then
        begin
          ANeeded := LNext - APos;
          Result := True;
          Exit;
        end;
        if (LVal < 0) or (LVal > 1024 * 1024) then Exit; // absurd array size fallback
        LSum := LNext - APos;
        LChildPos := LNext;
        for I := 0 to Integer(LVal) - 1 do
        begin
          if not RespPeekFrameLength(ASpan, LChildPos, LChildNeed) then Exit;
          // overflow guard
          if LSum > High(Integer) - LChildNeed then Exit;
          Inc(LSum, LChildNeed);
          Inc(LChildPos, LChildNeed);
          if LChildPos > Integer(ASpan.Len) then
          begin
            // child extends beyond available buffer but its header was enough to compute its total;
            // for peek we can still sum total even if payload not yet in buffer (childNeeded already includes payload)
            // so continue; no extra check needed
          end;
        end;
        ANeeded := LSum;
        Result := True;
      end;
  else
    Exit;
  end;
end;

function RespPeekFrameLength(const ABuf: TBytes; APos: Integer;
  out ANeeded: Integer): Boolean;
begin
  Result := RespPeekFrameLength(TByteSpan.FromBytes(ABuf), APos, ANeeded);
end;

function RespInfoFieldValue(const APayload: TBytes;
  const AKey: string): string;
var
  S, Line, RK: string;
  P, Q, R: Integer;
begin
  Result := '';
  S := RespBytesToStr(APayload);
  P := 1;
  while P <= Length(S) do
  begin
    Q := P;
    while (Q <= Length(S)) and not ((S[Q] = #13) and
      (Q < Length(S)) and (S[Q + 1] = #10)) do
      Inc(Q);
    Line := Copy(S, P, Q - P);
    if Q > Length(S) then
      P := Q + 1
    else
      P := Q + 2;
    if (Line <> '') and (Line[1] = '#') then
      Continue;                       { 段头跳过 }
    Q := Pos(':', Line);
    if Q = 0 then
      Continue;
    RK := Copy(Line, 1, Q - 1);
    if RK = AKey then
      Exit(Copy(Line, Q + 1, MaxInt));
  end;
end;

function RespErrorType(const APayload: TBytes): string;
var
  S, U: string;
  I, LSp: Integer;
begin
  S := RespBytesToStr(APayload);
  LSp := Pos(' ', S);
  if LSp > 0 then
    S := Copy(S, 1, LSp - 1);
  U := S;
  for I := 1 to Length(U) do
    U[I] := UpCase(U[I]);
  Result := U;
end;

function RespValueToText(const AValue: TRespValue): string;
begin
  case AValue.Kind of
    rvkInteger: Result := IntToStr(AValue.Int);
    rvkSimple, rvkError, rvkBulk: Result := RespBytesToStr(AValue.Data);
    rvkNull: Result := '';
  else
    Result := '';   { array 由调用方逐元素渲染，不落此分支 }
  end;
end;

end.
