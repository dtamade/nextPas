unit nextpas.core.db.redis.resp;

{** @desc RESP2 协议编解码纯函数（V3-A5）。
       缝位纯度：本单元纯 L0/L1 依赖（text.conv/base），不触 net/tls 同层缝（缝仅在 transport/adapter 单点，cycle-gated 无 reverse，类 vfs.embedded→respack.reader 单向范式），bytes.ops 单源 indirect（经 StrToBytes 零拷贝 Move 单次，inline 薄转发由 adapter 侧承载）。
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
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.redis.base;

type
  TRespArgs = array of TBytes;   { 命令参数计划产物 }

{ 参数数组 → RESP 命令帧：*N\r\n $len\r\n <data> \r\n ... }
procedure RespEncodeCommand(const AArgs: array of TBytes;
  out AOut: TBytes);

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
  out AValue: TRespValue; out ANeedMore: Boolean): Boolean;

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

{ 注意：本单元所有 uses 集中在接口段——SysUtils 亦声明 TBytes，
  若放实现段会遮蔽 nextpas.core.base.TBytes 导致接口/实现签名
  不匹配（Forward declaration not solved）。 }

function RespBytesToStr(const ABuf: TBytes): string;
begin
  if Length(ABuf) = 0 then
    Exit('');
  SetString(Result, PAnsiChar(@ABuf[0]), Length(ABuf));
end;

function StrToBytes(const AStr: string): TBytes;
begin
  if Length(AStr) = 0 then
    Exit(nil);
  SetLength(Result, Length(AStr));
  Move(AStr[1], Result[0], Length(AStr));
end;

procedure RespAppendCrlf(var ABuf: TBytes);
var
  LN: Integer;
begin
  LN := Length(ABuf);
  SetLength(ABuf, LN + 2);
  ABuf[LN] := 13;
  ABuf[LN + 1] := 10;
end;

procedure RespAppendLine(var ABuf: TBytes; const AHead: AnsiChar;
  const ATail: TBytes); overload;
var
  LN: Integer;
begin
  LN := Length(ABuf);
  SetLength(ABuf, LN + 1 + Length(ATail));
  ABuf[LN] := Ord(AHead);
  if ATail <> nil then
    Move(ATail[0], ABuf[LN + 1], Length(ATail));
  RespAppendCrlf(ABuf);
end;

procedure RespEncodeCommand(const AArgs: array of TBytes;
  out AOut: TBytes);
var
  I, LN: Integer;
  LNum: TBytes;
begin
  SetLength(AOut, 0);
  LNum := StrToBytes(IntToStr(Length(AArgs)));
  RespAppendLine(AOut, '*', LNum);
  for I := 0 to High(AArgs) do
  begin
    LNum := StrToBytes(IntToStr(Length(AArgs[I])));
    RespAppendLine(AOut, '$', LNum);
    LN := Length(AOut);
    SetLength(AOut, LN + Length(AArgs[I]));
    if Length(AArgs[I]) > 0 then
      Move(AArgs[I][0], AOut[LN], Length(AArgs[I]));
    RespAppendCrlf(AOut);
  end;
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

  procedure EmitToken(const ATxt: string);
  begin
    SetLength(AArgs, Length(AArgs) + 1);
    AArgs[High(AArgs)] := StrToBytes(ATxt);
  end;

  procedure EmitSlot(ALogical: Integer);
  var
    LS: Integer;
  begin
    for LS := 0 to High(LSlots) do
      if LSlots[LS] = ALogical then
        raise EDbError.CreateSimple(dbkRedis,
          'duplicate placeholder logical number ?' + IntToStr(ALogical));
    if (ALogical < 1) or (ALogical > Length(ABound)) then
      raise EDbError.CreateSimple(dbkRedis,
        'placeholder ?' + IntToStr(ALogical) + ' unbound (' +
        IntToStr(Length(ABound)) + ' params bound)');
    SetLength(LSlots, Length(LSlots) + 1);
    LSlots[High(LSlots)] := ALogical;
    SetLength(AArgs, Length(AArgs) + 1);
    AArgs[High(AArgs)] := ABound[ALogical - 1];
  end;

begin
  SetLength(AArgs, 0);
  SetLength(LSlots, 0);
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
  Result := Length(AArgs);
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

function RespTryParse(const ABuf: TBytes; var APos: Integer;
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
  if APos > High(ABuf) then
  begin
    ANeedMore := True;
    Exit;
  end;
  C := AnsiChar(ABuf[APos]);
  case C of
    '+', '-':
      begin
        if not ReadCrlfLine(ABuf, APos + 1, LLine, LNext) then
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
        if not ReadCrlfLine(ABuf, APos + 1, LLine, LNext) then
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
        if not ReadCrlfLine(ABuf, APos + 1, LLn, LNext) then
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
        if LNext + LLen + 2 > High(ABuf) + 1 then
        begin
          ANeedMore := True;
          Exit;
        end;
        SetLength(AValue.Data, LLen);
        if LLen > 0 then
          Move(ABuf[LNext], AValue.Data[0], LLen);
        if (ABuf[LNext + LLen] <> 13) or (ABuf[LNext + LLen + 1] <> 10)
        then
          raise EDbError.CreateSimple(dbkRedis,
            'resp: bulk missing CRLF terminator');
        APos := LNext + LLen + 2;
        Result := True;
      end;
    '*':
      begin
        if not ReadCrlfLine(ABuf, APos + 1, LLn, LNext) then
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
          if not RespTryParse(ABuf, LChildPos, LChild, LChildNeed) then
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
        if not ReadCrlfLine(ABuf, APos + 1, LLine, LNext) then
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
