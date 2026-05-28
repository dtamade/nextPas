procedure RegisterMock;
var
  table: record
    Exact: Pointer;
    SuffixWrong: Pointer;
    WrapperAsmOnly: Pointer;
    WrapperNoAsm: Pointer;
  end;
begin
  {$IFDEF MOCK_ASM}
  table.Exact := @MOCKExact;
  table.SuffixWrong := @MOCKSuffix;
  table.WrapperAsmOnly := @MOCKWrapper;
  {$ENDIF}

  {$IFNDEF MOCK_ASM}
  table.WrapperNoAsm := @MOCKWrapper;
  {$ENDIF}
end;
