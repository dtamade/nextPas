unit nextpas.core.archive.pax;
{**
 * @desc Archive 通用 pax 键值解析：length-prefix 严格校验零拷贝 PByte 切片，供归档族复用。
 * 抽取 tar pax 仅 path/linkpath 沉默忽略局限，归一 atime/mtime/size 等扩展键的零拷贝迭代能力；
 * strict fail-closed：长度前缀非法/越界/缺换行/缺 '=' 即抛 EIOError，避免外层静默丢弃回退截断名。
 * 性能：零拷贝 PByte 切片 + bytes.ops SpanEqual 单源；循环体外联禁 inline 避 I-Cache 膨胀。
 * 归属：archive 共享内核（内部核例外形态，四件套外），仅供 tar/zip/sevenz 族复用，禁止门面外直引。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.builder;

type
  {** @desc pax 键值处理器：零拷贝视图回调，生命周期绑解析缓冲 *}
  TArchivePaxKVHandler = reference to procedure(const AKey, AValue: TByteSpan);
  {** @desc 零分配 pax 键值处理器：plain procedural + UserData，无 reference 捕获堆分配，供热路径单源复用 *}
  TArchivePaxKVHandlerRaw = procedure(const AKey, AValue: TByteSpan; AUserData: Pointer);

{** @desc 通用 pax 记录解析：零拷贝 PByte 切片，严格 length-prefix 校验，畸形抛 EIOError
 *  @note 回调对每条 key=value 零拷贝分发，仅命中时物化；空缓冲返回 False；无分配
 *  @perf 外联（真实循环体禁 inline），单源复用 bytes.ops 视图
 *}
function ArchivePaxParseRecords(ABase: PByte; ALen: SizeUInt; const AHandler: TArchivePaxKVHandler): Boolean; overload;
{** @desc 零分配重载：plain procedural + UserData，零堆分配，归一 per-pax 闭包消除；热路径单源复用 *}
function ArchivePaxParseRecords(ABase: PByte; ALen: SizeUInt; AHandler: TArchivePaxKVHandlerRaw; AUserData: Pointer): Boolean; overload;
{** @desc pax 记录格式化/追加单源：length-prefix 自洽，builder 零拷贝最优路径单源，供 tar/zip 复用；含循环/分配，外联禁 inline *}
function ArchivePaxCalcRecordLen(const AKey, AValue: string): Integer;
procedure ArchivePaxAppendRecord(const ABuilder: IBytesBuilder; const AKey, AValue: string);
function ArchivePaxFormatRecord(const AKey, AValue: string): string;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.text.number;

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
      raise EIOError.CreateFmt('pax: missing key-value separator at offset %d (need ''='')', [Eq]);
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

function ArchivePaxParseRecords(ABase: PByte; ALen: SizeUInt; AHandler: TArchivePaxKVHandlerRaw; AUserData: Pointer): Boolean;
var
  P, Sp, Eq, RecEnd: SizeInt;
  LenVal: SizeInt;
  I: SizeInt;
  B: Byte;
  KeySpan, ValSpan: TByteSpan;
  KeyLen, ValLen: SizeInt;
begin
  // 零分配重载：plain procedural + UserData，无匿名闭包堆分配，归一 per-pax 闭包消除，零拷贝 PByte 切片单源
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
      raise EIOError.CreateFmt('pax: missing key-value separator at offset %d (need ''='')', [Eq]);
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
      AHandler(KeySpan, ValSpan, AUserData);
    Result := True;
    P := RecEnd;
  end;
end;

function ArchivePaxCalcRecordLen(const AKey, AValue: string): Integer;
var
  LBase, LDigits, LNeed: Integer;
begin
  LBase := 1 + Length(AKey) + 1 + Length(AValue) + 1;
  LDigits := 1;
  Result := LBase + LDigits;
  while True do
  begin
    LNeed := UInt64DecimalDigits(UInt64(Result));
    if LNeed = LDigits then Break;
    LDigits := LNeed;
    Result := LBase + LDigits;
  end;
end;

procedure ArchivePaxAppendRecord(const ABuilder: IBytesBuilder; const AKey, AValue: string);
var
  LLen: Integer;
  LBuf: array[0..20] of AnsiChar;
  LNumLen: Int32;
begin
  if ABuilder = nil then Exit;
  LLen := ArchivePaxCalcRecordLen(AKey, AValue);
  LNumLen := UIntToBuffer(UInt64(LLen), @LBuf[0]);
  ABuilder.Reserve(SizeUInt(LLen));
  ABuilder.AppendBytes(PByte(@LBuf[0]), SizeUInt(LNumLen));
  ABuilder.AppendByte(Ord(' '));
  if Length(AKey) > 0 then
    ABuilder.AppendBytes(PByte(PAnsiChar(AKey)), SizeUInt(Length(AKey)));
  ABuilder.AppendByte(Ord('='));
  if Length(AValue) > 0 then
    ABuilder.AppendBytes(PByte(PAnsiChar(AValue)), SizeUInt(Length(AValue)));
  ABuilder.AppendByte(10);
end;

function ArchivePaxFormatRecord(const AKey, AValue: string): string;
var
  LBuilder: IBytesBuilder;
  LSpan: TByteSpan;
begin
  LBuilder := CreateBytesBuilder(SizeUInt(ArchivePaxCalcRecordLen(AKey, AValue)));
  ArchivePaxAppendRecord(LBuilder, AKey, AValue);
  LSpan := LBuilder.WrittenSpan;
  Result := SpanToString(LSpan);
end;

end.
