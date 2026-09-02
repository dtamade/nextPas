unit nextpas.core.archive.pax;
{**
 * @desc Archive 通用 pax 键值解析：length-prefix 严格校验零拷贝 PByte 切片，供归档族复用。
 * 抽取 tar pax 仅 path/linkpath 沉默忽略局限，归一 atime/mtime/size 等扩展键的零拷贝迭代能力；
 * strict fail-closed：长度前缀非法/越界/缺换行即抛 EIOError，避免外层静默丢弃回退截断名。
 * 性能：零拷贝 PByte 切片 + bytes.ops SpanEqual 单源；循环体外联禁 inline 避 I-Cache 膨胀。
 * 归属：archive 共享内核（内部核例外形态，四件套外），仅供 tar/zip/sevenz 族复用，禁止门面外直引。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base;

type
  {** @desc pax 键值处理器：零拷贝视图回调，生命周期绑解析缓冲 *}
  TArchivePaxKVHandler = reference to procedure(const AKey, AValue: TByteSpan);

{** @desc 通用 pax 记录解析：零拷贝 PByte 切片，严格 length-prefix 校验，畸形抛 EIOError
 *  @note 回调对每条 key=value 零拷贝分发，仅命中时物化；空缓冲返回 False；无分配
 *  @perf 外联（真实循环体禁 inline），单源复用 bytes.ops 视图
 *}
function ArchivePaxParseRecords(ABase: PByte; ALen: SizeUInt; const AHandler: TArchivePaxKVHandler): Boolean;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops;

function ArchivePaxParseRecords(ABase: PByte; ALen: SizeUInt; const AHandler: TArchivePaxKVHandler): Boolean;
var
  P, Sp, Eq, RecEnd: SizeInt;
  LenVal: SizeInt;
  I: SizeInt;
  B: Byte;
  KeySpan, ValSpan: TByteSpan;
  KeyLen, ValLen: SizeInt;
begin
  Result := False;
  if (ABase = nil) or (ALen = 0) then
    Exit(False);
  P := 0;
  while P < SizeInt(ALen) do
  begin
    Sp := P;
    while (Sp < SizeInt(ALen)) and (ABase[Sp] <> Ord(' ')) do
      Inc(Sp);
    if Sp >= SizeInt(ALen) then
      raise EIOError.CreateFmt('pax: missing length separator at offset %d (need space)', [P]);
    LenVal := 0;
    for I := P to Sp - 1 do
    begin
      B := ABase[I];
      if (B < Ord('0')) or (B > Ord('9')) then
        raise EIOError.CreateFmt('pax: invalid length digit %d at offset %d', [B, I]);
      // overflow guard: LenVal*10+digit within SizeInt/ALen
      if LenVal > (High(SizeInt) - (B - Ord('0'))) div 10 then
        raise EIOError.CreateFmt('pax: length overflow at offset %d', [P]);
      LenVal := LenVal * 10 + (B - Ord('0'));
      if LenVal > SizeInt(ALen) then
        raise EIOError.CreateFmt('pax: length %d exceeds total %d at offset %d', [LenVal, ALen, P]);
    end;
    if LenVal <= 0 then
      raise EIOError.CreateFmt('pax: invalid length %d at offset %d', [LenVal, P]);
    RecEnd := P + LenVal;
    if (RecEnd <= P) or (RecEnd > SizeInt(ALen)) then
      raise EIOError.CreateFmt('pax: record end %d out of range at offset %d (total %d)', [RecEnd, P, ALen]);
    if ABase[RecEnd - 1] <> 10 then
      raise EIOError.CreateFmt('pax: missing trailing newline at offset %d', [RecEnd - 1]);
    Eq := Sp + 1;
    while (Eq < RecEnd - 1) and (ABase[Eq] <> Ord('=')) do
      Inc(Eq);
    if Eq >= RecEnd - 1 then
    begin
      // 无 '=' 的记录视为畸形但非 length 越界，按 pax 规范应抛；为兼容 tar 历史静默跳过，仍继续下条
      // strict 策略：length 已严格，key 缺 '=' 仅跳过不抛，避免整档因单条扩展键失败；如需硬失败可改为 raise
      P := RecEnd;
      Continue;
    end;
    KeyLen := Eq - Sp - 1;
    ValLen := RecEnd - 1 - (Eq + 1);
    if KeyLen > 0 then
      KeySpan := TByteSpan.Create(@ABase[Sp + 1], SizeUInt(KeyLen))
    else
      KeySpan := TByteSpan.Empty;
    if ValLen > 0 then
      ValSpan := TByteSpan.Create(@ABase[Eq + 1], SizeUInt(ValLen))
    else
      ValSpan := TByteSpan.Empty;
    if Assigned(AHandler) then
      AHandler(KeySpan, ValSpan);
    Result := True;
    P := RecEnd;
  end;
end;

end.
