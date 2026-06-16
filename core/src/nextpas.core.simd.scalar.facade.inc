// === 标量门面函数实现 ===

// 内存操作函数
// 优化为 8 字节批量比较
function MemEqual_Scalar(a, b: Pointer; len: SizeUInt): LongBool;
var
  pa, pb: PByte;
  pqa, pqb: PQWord;
  i, qwordCount, remaining: SizeUInt;
begin
  {$PUSH}{$Q-}{$R-}  // Disable overflow/range checks for SIMD-style loop
  if len = 0 then
  begin
    Result := True;
    Exit;
  end;

  if (a = nil) or (b = nil) then
  begin
    Result := (a = b);
    Exit;
  end;

  pa := PByte(a);
  pb := PByte(b);

  // 快速路径: 按 8 字节 (QWord) 批量比较
  qwordCount := len div 8;
  if qwordCount > 0 then
  begin
    pqa := PQWord(pa);
    pqb := PQWord(pb);
    for i := 0 to qwordCount - 1 do
    begin
      if pqa[i] <> pqb[i] then
      begin
        Result := False;
        Exit;
      end;
    end;
    // 移动指针到剩余字节
    pa := pa + qwordCount * 8;
    pb := pb + qwordCount * 8;
  end;

  // 处理剩余的 0-7 字节
  remaining := len mod 8;
  // 当 remaining=0 时，remaining-1 会下溢到 High(SizeUInt)
  if remaining > 0 then
    for i := 0 to remaining - 1 do
    begin
      if pa[i] <> pb[i] then
      begin
        Result := False;
        Exit;
      end;
    end;

  Result := True;
  {$POP}
end;

function MemFindByte_Scalar(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
var
  pb: PByte;
  i: SizeUInt;
begin
  if (len = 0) or (p = nil) then
  begin
    Result := -1;
    Exit;
  end;

  pb := PByte(p);

  for i := 0 to len - 1 do
  begin
    if pb[i] = value then
    begin
      Result := PtrInt(i);
      Exit;
    end;
  end;

  Result := -1;
end;

function MemDiffRange_Scalar(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
var
  pa, pb: PByte;
  i: SizeUInt;
  foundFirst: Boolean;
begin
  firstDiff := 0;
  lastDiff := 0;

  if len = 0 then
  begin
    Result := False;
    Exit;
  end;

  if (a = nil) or (b = nil) then
  begin
    if a <> b then
    begin
      firstDiff := 0;
      lastDiff := len - 1;
      Result := True;
    end
    else
      Result := False;
    Exit;
  end;

  pa := PByte(a);
  pb := PByte(b);
  foundFirst := False;

  for i := 0 to len - 1 do
  begin
    if pa[i] <> pb[i] then
    begin
      if not foundFirst then
      begin
        firstDiff := i;
        foundFirst := True;
      end;
      lastDiff := i;
    end;
  end;

  Result := foundFirst;
end;

procedure MemCopy_Scalar(src, dst: Pointer; len: SizeUInt);
begin
  if (len = 0) or (src = nil) or (dst = nil) then
    Exit;

  Move(src^, dst^, len);
end;

procedure MemSet_Scalar(dst: Pointer; len: SizeUInt; value: Byte);
begin
  if (len = 0) or (dst = nil) then
    Exit;

  FillChar(dst^, len, value);
end;

procedure MemReverse_Scalar(p: Pointer; len: SizeUInt);
var
  pb: PByte;
  i: SizeUInt;
  temp: Byte;
begin
  if (len <= 1) or (p = nil) then
    Exit;

  pb := PByte(p);

  for i := 0 to (len div 2) - 1 do
  begin
    temp := pb[i];
    pb[i] := pb[len - 1 - i];
    pb[len - 1 - i] := temp;
  end;
end;

// 统计函数
// 优化为 8 字节批量读取并展开循环
function SumBytes_Scalar(p: Pointer; len: SizeUInt): UInt64;
var
  pb: PByte;
  pq: PQWord;
  i, qwordCount, remaining: SizeUInt;
  qval: QWord;
  sum0, sum1, sum2, sum3: UInt64;
begin
  {$PUSH}{$Q-}{$R-}  // Disable overflow/range checks for SIMD-style loop
  Result := 0;

  if (len = 0) or (p = nil) then
    Exit;

  pb := PByte(p);

  // 使用4路累加器减少依赖
  sum0 := 0;
  sum1 := 0;
  sum2 := 0;
  sum3 := 0;

  // 快速路径: 按 8 字节 (QWord) 批量读取
  qwordCount := len div 8;
  if qwordCount > 0 then
  begin
    pq := PQWord(pb);
    for i := 0 to qwordCount - 1 do
    begin
      qval := pq[i];
      // 提取并累加每个字节
      sum0 := sum0 + (qval and $FF);
      sum1 := sum1 + ((qval shr 8) and $FF);
      sum2 := sum2 + ((qval shr 16) and $FF);
      sum3 := sum3 + ((qval shr 24) and $FF);
      sum0 := sum0 + ((qval shr 32) and $FF);
      sum1 := sum1 + ((qval shr 40) and $FF);
      sum2 := sum2 + ((qval shr 48) and $FF);
      sum3 := sum3 + ((qval shr 56) and $FF);
    end;
    pb := pb + qwordCount * 8;
  end;

  // 处理剩余的 0-7 字节
  remaining := len mod 8;
  // 当 remaining=0 时，remaining-1 会下溢到 High(SizeUInt)
  if remaining > 0 then
    for i := 0 to remaining - 1 do
      sum0 := sum0 + pb[i];

  Result := sum0 + sum1 + sum2 + sum3;
  {$POP}
end;

procedure MinMaxBytes_Scalar(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
var
  pb: PByte;
  i: SizeUInt;
begin
  minVal := 255;
  maxVal := 0;

  if (len = 0) or (p = nil) then
    Exit;

  pb := PByte(p);
  minVal := pb[0];
  maxVal := pb[0];

  for i := 1 to len - 1 do
  begin
    if pb[i] < minVal then
      minVal := pb[i];
    if pb[i] > maxVal then
      maxVal := pb[i];
  end;
end;

function CountByte_Scalar(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
var
  pb: PByte;
  i: SizeUInt;
begin
  Result := 0;

  if (len = 0) or (p = nil) then
    Exit;

  pb := PByte(p);

  for i := 0 to len - 1 do
  begin
    if pb[i] = value then
      Inc(Result);
  end;
end;

// 文本处理函数
function Utf8Validate_Scalar(p: Pointer; len: SizeUInt): Boolean;
var
  pb: PByte;
  i: SizeUInt;
  b, b2: Byte;
  seqLen: Integer;
  j: Integer;
begin
  Result := True;

  // 空长度有效，空指针无效
  if len = 0 then
    Exit(True);
  if p = nil then
    Exit(False);

  pb := PByte(p);
  i := 0;

  while i < len do
  begin
    b := pb[i];

    // ASCII (0xxxxxxx)
    if (b and $80) = 0 then
    begin
      Inc(i);
      Continue;
    end;

    // Multi-byte sequence
    // 2-byte sequences: $C2-$DF (NOT $C0-$C1 which are overlong)
    if (b >= $C2) and (b <= $DF) then
      seqLen := 2
    // 3-byte sequences: $E0-$EF
    else if (b and $F0) = $E0 then
      seqLen := 3
    // 4-byte sequences: $F0-$F4
    else if (b >= $F0) and (b <= $F4) then
      seqLen := 4
    else
    begin
      // Invalid leading byte ($C0, $C1, $F5-$FF, or continuation byte)
      Result := False;
      Exit;
    end;

    // Check if we have enough bytes
    if i + SizeUInt(seqLen) > len then
    begin
      Result := False;
      Exit;
    end;

    // Check continuation bytes
    for j := 1 to seqLen - 1 do
    begin
      if (pb[i + SizeUInt(j)] and $C0) <> $80 then
      begin
        Result := False;
        Exit;
      end;
    end;

    // Additional checks for overlong sequences
    if seqLen = 3 then
    begin
      b2 := pb[i + 1];
      // E0 followed by 80-9F is overlong
      if (b = $E0) and (b2 < $A0) then
      begin
        Result := False;
        Exit;
      end;
      // ED followed by A0-BF is surrogate (invalid in UTF-8)
      if (b = $ED) and (b2 >= $A0) then
      begin
        Result := False;
        Exit;
      end;
    end
    else if seqLen = 4 then
    begin
      b2 := pb[i + 1];
      // F0 followed by 80-8F is overlong
      if (b = $F0) and (b2 < $90) then
      begin
        Result := False;
        Exit;
      end;
      // F4 followed by 90-BF is beyond Unicode range
      if (b = $F4) and (b2 >= $90) then
      begin
        Result := False;
        Exit;
      end;
    end;

    Inc(i, seqLen);
  end;
end;

function AsciiIEqual_Scalar(a, b: Pointer; len: SizeUInt): Boolean;
var
  pa, pb: PByte;
  i: SizeUInt;
  ca, cb: Byte;
begin
  if len = 0 then
  begin
    Result := True;
    Exit;
  end;

  if (a = nil) or (b = nil) then
  begin
    Result := (a = b);
    Exit;
  end;

  pa := PByte(a);
  pb := PByte(b);

  for i := 0 to len - 1 do
  begin
    ca := pa[i];
    cb := pb[i];

    // Convert to lowercase for comparison
    if (ca >= Ord('A')) and (ca <= Ord('Z')) then
      ca := ca + 32;
    if (cb >= Ord('A')) and (cb <= Ord('Z')) then
      cb := cb + 32;

    if ca <> cb then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

procedure ToLowerAscii_Scalar(p: Pointer; len: SizeUInt);
var
  pb: PByte;
  i: SizeUInt;
begin
  if (len = 0) or (p = nil) then
    Exit;

  pb := PByte(p);

  for i := 0 to len - 1 do
  begin
    if (pb[i] >= Ord('A')) and (pb[i] <= Ord('Z')) then
      pb[i] := pb[i] + 32;
  end;
end;

procedure ToUpperAscii_Scalar(p: Pointer; len: SizeUInt);
var
  pb: PByte;
  i: SizeUInt;
begin
  if (len = 0) or (p = nil) then
    Exit;

  pb := PByte(p);

  for i := 0 to len - 1 do
  begin
    if (pb[i] >= Ord('a')) and (pb[i] <= Ord('z')) then
      pb[i] := pb[i] - 32;
  end;
end;

// 搜索函数
function BytesIndexOf_Scalar(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;
var
  ph, pn: PByte;
  i, j: SizeUInt;
  found: Boolean;
begin
  Result := -1;

  if (haystackLen = 0) or (needleLen = 0) or (haystack = nil) or (needle = nil) then
    Exit;

  if needleLen > haystackLen then
    Exit;

  ph := PByte(haystack);
  pn := PByte(needle);

  for i := 0 to haystackLen - needleLen do
  begin
    found := True;
    for j := 0 to needleLen - 1 do
    begin
      if ph[i + j] <> pn[j] then
      begin
        found := False;
        Break;
      end;
    end;

    if found then
    begin
      Result := PtrInt(i);
      Exit;
    end;
  end;
end;

// 位集函数
// 使用 256 字节查找表实现 O(1) 每字节的 popcount
const
  PopCountTable: array[0..255] of Byte = (
    0,1,1,2,1,2,2,3,1,2,2,3,2,3,3,4,  // 0x00-0x0F
    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,  // 0x10-0x1F
    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,  // 0x20-0x2F
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0x30-0x3F
    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,  // 0x40-0x4F
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0x50-0x5F
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0x60-0x6F
    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,  // 0x70-0x7F
    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,  // 0x80-0x8F
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0x90-0x9F
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0xA0-0xAF
    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,  // 0xB0-0xBF
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0xC0-0xCF
    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,  // 0xD0-0xDF
    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,  // 0xE0-0xEF
    4,5,5,6,5,6,6,7,5,6,6,7,6,7,7,8   // 0xF0-0xFF
  );

function BitsetPopCount_Scalar(p: Pointer; byteLen: SizeUInt): SizeUInt;
var
  pb: PByte;
  i: SizeUInt;
begin
  Result := 0;

  if (byteLen = 0) or (p = nil) then
    Exit;

  pb := PByte(p);

  // 使用查找表 O(1) 每字节，而非逐位循环 O(8)
  for i := 0 to byteLen - 1 do
    Result := Result + PopCountTable[pb[i]];
end;

