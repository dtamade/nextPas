{ 二分查找模板体 — 由 nextpas.core.text.unicode.base.pas 通过宏展开使用 }
var
  LLo: SizeInt;
  LHi: SizeInt;
  LMid: SizeInt;
begin
  LLo := 0;
  LHi := High(ARanges);
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) div 2);
    if ACp <= ARanges[LMid].Hi then
    begin
      if ACp >= ARanges[LMid].Lo then
      begin
        {$IFDEF FIND_RANGE_RETURN_INDEX}
          Exit(Int32(LMid));
        {$ELSE}
          AValue := ARanges[LMid].Value;
          Exit(True);
        {$ENDIF}
      end;
      LHi := LMid - 1;
    end
    else
      LLo := LMid + 1;
  end;
  {$IFDEF FIND_RANGE_RETURN_INDEX}
    Result := -1;
  {$ELSE}
    Result := False;
  {$ENDIF}
end;
