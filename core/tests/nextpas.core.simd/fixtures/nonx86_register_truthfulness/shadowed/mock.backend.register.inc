procedure RegisterMock;
var
  table: record
    Shadowed: Pointer;
  end;
begin
  {$IFDEF MOCK_ASM}
  table.Shadowed := @MOCKSuffix_ASM;
  {$ENDIF}
  table.Shadowed := @MOCKWrapper;
end;
