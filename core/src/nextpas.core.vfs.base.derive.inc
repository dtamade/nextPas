{ Single-source template for VfsDeriveChildNames / VfsDeriveChildNamesFromSpans
  Shared algorithm: LowerBound + SpanStartsWith Early-Break + '/' segment + SpanEqual dedup + 16× growth cap + Move zero-copy
  Expects in outer function:
    - Locals: N, OutN, PrefixLen, SegPos, J, Lo, Hi, Mid, I, Cap: SizeInt; ChildSpan, PrevSpan, PrefixSpan, CurSpan: TByteSpan; NeedAdd: Boolean; Result: TVfsNameArray; PrefixSpan already built; N already set; Result = nil on entry
    - For spans path: define VFS_DERIVE_USE_SPANS and have ASpans: array of TByteSpan in scope
    - For strings path: define VFS_DERIVE_USE_STRINGS and have ASortedPaths: array of string in scope
  Reuses bytes.ops single source: SpanCompare / SpanStartsWith / SpanEqual inline zero-copy; Move single-copy materialization only on unique child
  Performance: LowerBound O(log n) + Early-Break O(k) where k=fan-out; capacity 16-doubling capped at N-Lo; Child dedup via SpanEqual zero-copy view (only unique Move)
  Stability: No heap alloc besides Result growth; SetLength caps at N-Lo } 
  // LowerBound: first index >= PrefixSpan
  Lo := 0;
  Hi := N;
  if PrefixLen > 0 then
  begin
    while Lo < Hi do
    begin
      Mid := Lo + (Hi - Lo) div 2;
      {$IFDEF VFS_DERIVE_USE_SPANS}
      CurSpan := ASpans[Mid];
      {$ELSE}
      if Length(ASortedPaths[Mid]) = 0 then CurSpan := TByteSpan.Empty else CurSpan := TByteSpan.Create(PByte(@ASortedPaths[Mid][1]), SizeUInt(Length(ASortedPaths[Mid])));
      {$ENDIF}
      if SpanCompare(CurSpan, PrefixSpan) < 0 then
        Lo := Mid + 1
      else
        Hi := Mid;
    end;
  end;
  SetLength(Result, 0);
  OutN := 0;
  for I := Lo to N - 1 do
  begin
    {$IFDEF VFS_DERIVE_USE_SPANS}
    CurSpan := ASpans[I];
    {$ELSE}
    if Length(ASortedPaths[I]) = 0 then CurSpan := TByteSpan.Empty else CurSpan := TByteSpan.Create(PByte(@ASortedPaths[I][1]), SizeUInt(Length(ASortedPaths[I])));
    {$ENDIF}
    if SizeInt(CurSpan.Len) <= PrefixLen then Continue;
    if PrefixLen > 0 then
    begin
      if not SpanStartsWith(CurSpan, PrefixSpan) then
        Break;
    end;
    SegPos := 0;
    for J := PrefixLen to SizeInt(CurSpan.Len) - 1 do
      if CurSpan.Data[J] = Ord('/') then
      begin
        SegPos := J + 1;
        Break;
      end;
    if SegPos > 0 then
      ChildSpan := TByteSpan.Create(CurSpan.Data, SizeUInt(SegPos - 1))
    else
      ChildSpan := CurSpan;
    if OutN = 0 then
      NeedAdd := True
    else
    begin
      if Length(Result[OutN - 1]) = 0 then PrevSpan := TByteSpan.Empty else PrevSpan := TByteSpan.Create(PByte(@Result[OutN - 1][1]), SizeUInt(Length(Result[OutN - 1])));
      NeedAdd := not SpanEqual(PrevSpan, ChildSpan);
    end;
    if NeedAdd then
    begin
      if OutN >= Length(Result) then
      begin
        Cap := Length(Result);
        if Cap = 0 then Cap := 16;
        while Cap <= OutN do Cap := Cap * 2;
        if Cap > N - Lo then Cap := N - Lo;
        SetLength(Result, Cap);
      end;
      SetLength(Result[OutN], ChildSpan.Len);
      if ChildSpan.Len > 0 then
        Move(ChildSpan.Data^, Result[OutN][1], ChildSpan.Len);
      Inc(OutN);
    end;
  end;
  SetLength(Result, OutN);
