{$IFDEF SORT_INT32}
procedure SortI32(aData: PInt32; aCount: SizeUInt);
type TElem = Int32; PElem = PInt32;
{$ENDIF}
{$IFDEF SORT_INT64}
procedure SortI64(aData: PInt64; aCount: SizeUInt);
type TElem = Int64; PElem = PInt64;
{$ENDIF}
{$IFDEF SORT_UINT32}
procedure SortU32(aData: PUInt32; aCount: SizeUInt);
type TElem = UInt32; PElem = PUInt32;
{$ENDIF}
{$IFDEF SORT_UINT64}
procedure SortU64(aData: PUInt64; aCount: SizeUInt);
type TElem = UInt64; PElem = PUInt64;
{$ENDIF}
const
  INSERTION_THRESHOLD = 24;
  PARTIAL_INSERTION_LIMIT = 12;

  procedure InsertionSort(aL, aR: SizeUInt); inline;
  var
    i, j: SizeUInt;
    tmp: TElem;
  begin
    for i := aL + 1 to aR do
    begin
      tmp := aData[i];
      j := i;
      while (j > aL) and (aData[j - 1] > tmp) do
      begin
        aData[j] := aData[j - 1];
        Dec(j);
      end;
      aData[j] := tmp;
    end;
  end;

  function TryPartialInsertionSort(aL, aR: SizeUInt): Boolean; inline;
  var
    i, j: SizeUInt;
    tmp: TElem;
    LMoves: Integer;
  begin
    LMoves := 0;
    for i := aL + 1 to aR do
    begin
      tmp := aData[i];
      j := i;
      while (j > aL) and (aData[j - 1] > tmp) do
      begin
        aData[j] := aData[j - 1];
        Dec(j);
        Inc(LMoves);
        if LMoves > PARTIAL_INSERTION_LIMIT then Exit(False);
      end;
      aData[j] := tmp;
    end;
    Result := True;
  end;

  procedure HeapSort(aL, aR: SizeUInt);
  var
    LSize, i, idx, child: SizeUInt;
    tmp: TElem;
  begin
    LSize := aR - aL + 1;
    i := LSize div 2;
    while True do
    begin
      Dec(i);
      idx := i;
      tmp := aData[aL + idx];
      while True do
      begin
        child := 2 * idx + 1;
        if child >= LSize then Break;
        if (child + 1 < LSize) and (aData[aL + child] < aData[aL + child + 1]) then
          Inc(child);
        if tmp >= aData[aL + child] then Break;
        aData[aL + idx] := aData[aL + child];
        idx := child;
      end;
      aData[aL + idx] := tmp;
      if i = 0 then Break;
    end;
    i := LSize - 1;
    while i > 0 do
    begin
      tmp := aData[aL + i];
      aData[aL + i] := aData[aL];
      aData[aL] := tmp;
      Dec(LSize);
      idx := 0;
      tmp := aData[aL];
      while True do
      begin
        child := 2 * idx + 1;
        if child >= LSize then Break;
        if (child + 1 < LSize) and (aData[aL + child] < aData[aL + child + 1]) then
          Inc(child);
        if tmp >= aData[aL + child] then Break;
        aData[aL + idx] := aData[aL + child];
        idx := child;
      end;
      aData[aL + idx] := tmp;
      Dec(i);
    end;
  end;

  procedure IntroSort(aLeft, aRight: SizeUInt; aDepth: Integer);
  var
    lt, gt, i, LMid: SizeUInt;
    pivot, tmp: TElem;
  begin
    while aLeft < aRight do
    begin
      if aRight - aLeft < INSERTION_THRESHOLD then
      begin
        InsertionSort(aLeft, aRight);
        Exit;
      end;

      if aDepth = 0 then
      begin
        HeapSort(aLeft, aRight);
        Exit;
      end;
      Dec(aDepth);

      LMid := aLeft + (aRight - aLeft) div 2;
      if aData[aLeft] > aData[LMid] then
      begin tmp := aData[aLeft]; aData[aLeft] := aData[LMid]; aData[LMid] := tmp; end;
      if aData[LMid] > aData[aRight] then
      begin tmp := aData[LMid]; aData[LMid] := aData[aRight]; aData[aRight] := tmp; end;
      if aData[aLeft] > aData[LMid] then
      begin tmp := aData[aLeft]; aData[aLeft] := aData[LMid]; aData[LMid] := tmp; end;
      pivot := aData[LMid];

      lt := aLeft;
      gt := aRight;
      i := aLeft;
      while i <= gt do
      begin
        if aData[i] < pivot then
        begin
          tmp := aData[i]; aData[i] := aData[lt]; aData[lt] := tmp;
          Inc(lt); Inc(i);
        end
        else if aData[i] > pivot then
        begin
          tmp := aData[i]; aData[i] := aData[gt]; aData[gt] := tmp;
          Dec(gt);
        end
        else
          Inc(i);
      end;

      if (lt > aLeft) and TryPartialInsertionSort(aLeft, lt - 1) then
        { left done }
      else if lt > aLeft + 1 then
        IntroSort(aLeft, lt - 1, aDepth);

      if (gt < aRight) and TryPartialInsertionSort(gt + 1, aRight) then
        Exit
      else
        aLeft := gt + 1;
    end;
  end;

var
  LDepth: Integer;
  LN, i, LEnd: SizeUInt;
  tmp: TElem;
begin
  if aCount < 2 then Exit;

  LEnd := aCount - 2;
  i := 0;
  while (i <= LEnd) and (aData[i] = aData[i + 1]) do Inc(i);
  if i > LEnd then Exit;

  if aData[i] < aData[i + 1] then
  begin
    Inc(i);
    while (i <= LEnd) and (aData[i] <= aData[i + 1]) do Inc(i);
    if i > LEnd then Exit;
  end
  else
  begin
    Inc(i);
    while (i <= LEnd) and (aData[i] >= aData[i + 1]) do Inc(i);
    if i > LEnd then
    begin
      i := 0; LEnd := aCount - 1;
      while i < LEnd do
      begin
        tmp := aData[i]; aData[i] := aData[LEnd]; aData[LEnd] := tmp;
        Inc(i); Dec(LEnd);
      end;
      Exit;
    end;
  end;

  LDepth := 0;
  LN := aCount;
  while LN > 1 do begin LN := LN shr 1; Inc(LDepth); end;
  LDepth := LDepth * 2;

  IntroSort(0, aCount - 1, LDepth);
end;