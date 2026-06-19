{**
 * nextpas.core.text.tstring — TString: SSO + CoW 字符串实现
 *
 * 24-byte variant record:
 *   SSO 路径 (tag=0):   ≤15 字节内联, 零堆分配
 *   Heap 路径 (tag=$FF): PStringHeader + payload, 原子引用计数 CoW
 *
 * @note SizeOf(TString) = 24, 8-byte aligned
 * @note 空串 = 零初始化 (SSOTag=0, SSOLen=0)
 * @note UTF-8 透传, 不转码
 *}
{$I nextpas.core.settings.inc}
unit nextpas.core.text.tstring;
interface

const
  { TString tag 常量 }
  TSTRING_SSO_TAG  = Byte(0);
  TSTRING_HEAP_TAG = Byte($FF);
  TSTRING_SSO_MAX  = 15;

type
  PStringHeader = ^TStringHeader;
  TStringHeader = record
    RefCount: LongInt;  { 原子引用计数, 1 = 独占, >1 = 共享 (CoW), <0 = literal }
    Capacity: LongWord; { payload 容量 (不含 header + null terminator), 上限 4GB }
  end;
  { SizeOf(TStringHeader) = 8 bytes }

  TString = record
    { 生命周期 — 方法在 variant case 之前 }
    class function Empty: TString; static; inline;
    class function Create(const AData: PByte; ALen: SizeUInt): TString; static;
    class function FromFPC(const AStr: string): TString; static;
    procedure Done;

    { 查询 }
    function Len: SizeUInt; inline;
    function Data: PByte; inline;
    function RefCount: SizeInt; inline;
    function IsEmpty: Boolean; inline;
    function IsSSO: Boolean; inline;
    function IsHeap: Boolean; inline;

    { 转换 }
    function ToFPC: string;

    { 比较 }
    function Equals(const AOther: TString): Boolean;

    { 变体数据 }
    case Boolean of
      False: (
        SSOTag: Byte;
        SSOLen: Byte;
        SSOBuf: array[0..TSTRING_SSO_MAX - 1] of Byte;
        SSOPad: array[0..6] of Byte;
      );
      True: (
        HeapTag: Byte;
        HeapPad: array[0..6] of Byte;
        HeapHeader: PStringHeader;
        HeapLen: SizeUInt;
      );
  end;

{ 编译期布局断言 — 防止跨平台 SizeOf 变化 }
{$ASSERT SizeOf(TString) = 24}
{$ASSERT SizeOf(TStringHeader) = 8}

{ 顶层操作 — 编译器 emit / RAII 使用 }
procedure StringInit(var S: TString);
procedure StringFini(var S: TString);
procedure StringAssign(var ADest: TString; const ASource: TString);
procedure StringMove(var ADest: TString; var ASource: TString);
procedure StringSetLength(var S: TString; ANewLen: SizeUInt);

function StringLen(const S: TString): SizeUInt; inline;
function StringData(const S: TString): PByte; inline;
function StringRefCount(const S: TString): SizeInt; inline;
function StringIsEmpty(const S: TString): Boolean; inline;
function StringCreate(const AData: PByte; ALen: SizeUInt): TString;
function StringFromFPC(const AStr: string): TString;
function StringToFPC(const S: TString): string;
function StringEqual(const A, B: TString): Boolean;
function StringCompare(const A, B: TString): SizeInt;

implementation

{$ASSERTIONS ON}

{ ===== 内部分配辅助 ===== }

function HeapAlloc(ACapacity: SizeUInt): PStringHeader;
var
  LTotal: SizeUInt;
begin
  Assert(ACapacity <= High(LongWord), 'string capacity exceeds 4GB');
  LTotal := SizeOf(TStringHeader) + ACapacity + 1;
  Result := PStringHeader(GetMem(LTotal));
  Result^.RefCount := 1;
  Result^.Capacity := LongWord(ACapacity);
  { null terminator }
  PByte(Result)[SizeOf(TStringHeader) + ACapacity] := 0;
end;

procedure HeapFree(AHeader: PStringHeader);
begin
  FreeMem(AHeader);
end;

function HeapPayloadPtr(AHeader: PStringHeader): PByte; inline;
begin
  Result := PByte(AHeader) + SizeOf(TStringHeader);
end;

{ ===== CoW 内部操作 ===== }

procedure InternalHeapDecr(var S: TString);
var
  LOldRef: LongInt;
  LOldHeader: PStringHeader;
begin
  LOldHeader := S.HeapHeader;
  if LOldHeader = nil then
    Exit;
  LOldRef := LOldHeader^.RefCount;
  if LOldRef < 0 then
    Exit; { literal (ref=-1): 不可释放, 不参与引用计数 }
  if LOldRef = 1 then
  begin
    { 快速路径: 独占, 直接释放, 无需原子操作 }
    HeapFree(LOldHeader);
    Exit;
  end;
  { 共享: 原子递减 }
  if InterlockedDecrement(LOldHeader^.RefCount) = 0 then
    HeapFree(LOldHeader);
end;

procedure InternalHeapIncr(AHeader: PStringHeader); inline;
begin
  if (AHeader <> nil) and (AHeader^.RefCount >= 0) then
    InterlockedIncrement(AHeader^.RefCount);
end;

{ ===== TString record 方法 ===== }

class function TString.Empty: TString;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

class function TString.Create(const AData: PByte; ALen: SizeUInt): TString;
begin
  if ALen <= TSTRING_SSO_MAX then
  begin
    { SSO 路径 }
    FillChar(Result, SizeOf(Result), 0);
    Result.SSOTag := TSTRING_SSO_TAG;
    Result.SSOLen := Byte(ALen);
    if ALen > 0 then
      Move(AData^, Result.SSOBuf, ALen);
  end
  else
  begin
    { Heap 路径 }
    FillChar(Result, SizeOf(Result), 0);
    Result.HeapTag := TSTRING_HEAP_TAG;
    Result.HeapHeader := HeapAlloc(ALen);
    Result.HeapLen := ALen;
    Move(AData^, HeapPayloadPtr(Result.HeapHeader)^, ALen);
  end;
end;

class function TString.FromFPC(const AStr: string): TString;
var
  LLen: SizeUInt;
begin
  LLen := SizeUInt(System.Length(AStr));
  if LLen = 0 then
    Result := Empty
  else
    Result := Create(PByte(AStr), LLen);
end;

procedure TString.Done;
begin
  StringFini(Self);
end;

function TString.Len: SizeUInt;
begin
  Result := StringLen(Self);
end;

function TString.Data: PByte;
begin
  Result := StringData(Self);
end;

function TString.RefCount: SizeInt;
begin
  Result := StringRefCount(Self);
end;

function TString.IsEmpty: Boolean;
begin
  Result := StringIsEmpty(Self);
end;

function TString.IsSSO: Boolean;
begin
  Result := Self.SSOTag = TSTRING_SSO_TAG;
end;

function TString.IsHeap: Boolean;
begin
  Result := Self.HeapTag = TSTRING_HEAP_TAG;
end;

function TString.ToFPC: string;
begin
  Result := StringToFPC(Self);
end;

function TString.Equals(const AOther: TString): Boolean;
begin
  Result := StringEqual(Self, AOther);
end;

{ ===== 顶层操作实现 ===== }

procedure StringInit(var S: TString);
begin
  FillChar(S, SizeOf(S), 0);
end;

procedure StringFini(var S: TString);
begin
  if S.IsHeap then
    InternalHeapDecr(S);
  FillChar(S, SizeOf(S), 0);
end;

procedure StringAssign(var ADest: TString; const ASource: TString);
var
  LNewHeader: PStringHeader;
  LNewLen: SizeUInt;
begin
  if @ADest = @ASource then
    Exit;

  if ASource.IsSSO then
  begin
    { 源是 SSO: 先释放旧目标, 再 memcpy }
    if ADest.IsHeap then
      InternalHeapDecr(ADest);
    Move(ASource, ADest, SizeOf(TString));
  end
  else
  begin
    { 源是 Heap: 先 incr 源, 再 decr 旧目标 (经典 CoW 顺序) }
    LNewHeader := ASource.HeapHeader;
    LNewLen := ASource.HeapLen;
    InternalHeapIncr(LNewHeader);
    if ADest.IsHeap then
      InternalHeapDecr(ADest);
    FillChar(ADest, SizeOf(ADest), 0);
    ADest.HeapTag := TSTRING_HEAP_TAG;
    ADest.HeapHeader := LNewHeader;
    ADest.HeapLen := LNewLen;
  end;
end;

procedure StringMove(var ADest: TString; var ASource: TString);
begin
  if @ADest = @ASource then
    Exit;
  if ADest.IsHeap then
    InternalHeapDecr(ADest);
  Move(ASource, ADest, SizeOf(TString));
  FillChar(ASource, SizeOf(ASource), 0);
end;

procedure StringSetLength(var S: TString; ANewLen: SizeUInt);
var
  LHeader: PStringHeader;
  LData: PByte;
  LCopyLen: SizeUInt;
begin
  if ANewLen = 0 then
  begin
    StringFini(S);
    Exit;
  end;

  if S.IsSSO then
  begin
    if ANewLen <= TSTRING_SSO_MAX then
    begin
      { SSO 内调整 }
      S.SSOLen := Byte(ANewLen);
    end
    else
    begin
      { SSO → Heap 提升 }
      LHeader := HeapAlloc(ANewLen);
      LData := HeapPayloadPtr(LHeader);
      if S.SSOLen > 0 then
        Move(S.SSOBuf, LData^, S.SSOLen);
      FillChar(S, SizeOf(S), 0);
      S.HeapTag := TSTRING_HEAP_TAG;
      S.HeapHeader := LHeader;
      S.HeapLen := ANewLen;
    end;
  end
  else
  begin
    { Heap 路径 }
    LHeader := S.HeapHeader;
    if LHeader^.RefCount = 1 then
    begin
      { 独占: 可能原地修改或 realloc }
      if ANewLen <= LHeader^.Capacity then
      begin
        { 容量足够, 直接改长度 }
        S.HeapLen := ANewLen;
        { 更新 null terminator }
        HeapPayloadPtr(LHeader)[ANewLen] := 0;
      end
      else
      begin
        { 需要 realloc }
        LCopyLen := S.HeapLen;
        LHeader := PStringHeader(ReallocMem(LHeader,
          SizeOf(TStringHeader) + ANewLen + 1));
        LHeader^.Capacity := ANewLen;
        LHeader^.RefCount := 1;
        HeapPayloadPtr(LHeader)[ANewLen] := 0;
        S.HeapHeader := LHeader;
        S.HeapLen := ANewLen;
      end;
    end
    else
    begin
      { 共享 (CoW): 分配新块, 复制数据 }
      LCopyLen := S.HeapLen;
      if ANewLen < LCopyLen then
        LCopyLen := ANewLen;
      LHeader := HeapAlloc(ANewLen);
      Move(HeapPayloadPtr(S.HeapHeader)^, HeapPayloadPtr(LHeader)^, LCopyLen);
      InternalHeapDecr(S);
      S.HeapHeader := LHeader;
      S.HeapLen := ANewLen;
    end;
  end;
end;

function StringLen(const S: TString): SizeUInt;
begin
  if S.IsSSO then
    Result := S.SSOLen
  else
    Result := S.HeapLen;
end;

function StringData(const S: TString): PByte;
begin
  if S.IsSSO then
    Result := @S.SSOBuf
  else if S.HeapHeader <> nil then
    Result := HeapPayloadPtr(S.HeapHeader)
  else
    Result := nil;
end;

function StringRefCount(const S: TString): SizeInt;
begin
  if S.IsSSO then
    Result := 0
  else if S.HeapHeader <> nil then
    Result := S.HeapHeader^.RefCount
  else
    Result := 0;
end;

function StringIsEmpty(const S: TString): Boolean;
begin
  Result := (S.SSOTag = TSTRING_SSO_TAG) and (S.SSOLen = 0);
end;

function StringCreate(const AData: PByte; ALen: SizeUInt): TString;
begin
  Result := TString.Create(AData, ALen);
end;

function StringFromFPC(const AStr: string): TString;
begin
  Result := TString.FromFPC(AStr);
end;

function StringToFPC(const S: TString): string;
var
  LLen: SizeUInt;
  LData: PByte;
begin
  LLen := StringLen(S);
  if LLen = 0 then
  begin
    Result := '';
    Exit;
  end;
  LData := StringData(S);
  SetLength(Result, LLen);
  Move(LData^, PByte(Result)^, LLen);
end;

{ 安全内存比较 — 无越界读, 兼容 ASan/Valgrind }
{ 1-4B: 栈上 zero-padded 4B 比较 }
{ 5-8B: 栈上 zero-padded 8B 比较 }
{ 9-16B: 首尾重叠 i64 比较 (两端各 ≥8B, 无越界) }
{ >16B: 逐字节 }
function FastMemEqual(const A, B; ALen: SizeUInt): Boolean;
var
  LA, LB: PByte;
  LA4, LB4: Cardinal;
  LA8, LB8: Int64;
  I: SizeUInt;
begin
  case ALen of
    0: Result := True;
    1..4:
    begin
      { 栈上 zero-padded 比较, 无越界读 }
      LA4 := 0;
      LB4 := 0;
      Move(A, LA4, ALen);
      Move(B, LB4, ALen);
      Result := LA4 = LB4;
    end;
    5..8:
    begin
      { 栈上 zero-padded 比较, 无越界读 }
      LA8 := 0;
      LB8 := 0;
      Move(A, LA8, ALen);
      Move(B, LB8, ALen);
      Result := LA8 = LB8;
    end;
    9..16:
    begin
      { 首尾重叠 i64: 两端各读 8B, 9≤ALen≤16 时无越界 }
      LA := PByte(@A);
      LB := PByte(@B);
      Result := (PInt64(LA)^ = PInt64(LB)^) and
                (PInt64(LA + ALen - 8)^ = PInt64(LB + ALen - 8)^);
    end;
  else
    { 通用路径: 逐字节 }
    LA := PByte(@A);
    LB := PByte(@B);
    Result := True;
    for I := 0 to ALen - 1 do
      if LA[I] <> LB[I] then
      begin
        Result := False;
        Exit;
      end;
  end;
end;

function StringEqual(const A, B: TString): Boolean;
var
  LALen: SizeUInt;
begin
  LALen := StringLen(A);
  if LALen <> StringLen(B) then
    Exit(False);
  if LALen = 0 then
    Exit(True);
  Result := FastMemEqual(StringData(A)^, StringData(B)^, LALen);
end;

function StringCompare(const A, B: TString): SizeInt;
var
  LALen, LBLen, LMin, I: SizeUInt;
  LAData, LBData: PByte;
  LAByte, LBByte: Byte;
begin
  LALen := StringLen(A);
  LBLen := StringLen(B);
  if LALen < LBLen then
    LMin := LALen
  else
    LMin := LBLen;

  LAData := StringData(A);
  LBData := StringData(B);

  for I := 0 to LMin - 1 do
  begin
    LAByte := LAData[I];
    LBByte := LBData[I];
    if LAByte < LBByte then
    begin
      Result := -1;
      Exit;
    end
    else if LAByte > LBByte then
    begin
      Result := 1;
      Exit;
    end;
  end;

  if LALen < LBLen then
    Result := -1
  else if LALen > LBLen then
    Result := 1
  else
    Result := 0;
end;

end.
