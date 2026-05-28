procedure RegisterMock;
var
  table: record
    Compose: Pointer;
  end;
begin
  {$IFDEF MOCK_ASM}
  table.Compose := @MOCKCompose;
  {$ENDIF}
end;
