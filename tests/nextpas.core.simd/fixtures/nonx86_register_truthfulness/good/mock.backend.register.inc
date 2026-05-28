procedure RegisterMock;
var
  table: record
    Exact: Pointer;
    Suffix: Pointer;
  end;
begin
  {$IFDEF MOCK_ASM}
  table.Exact := @MOCKExact;
  table.Suffix := @MOCKSuffix_ASM;
  {$ENDIF}
end;
