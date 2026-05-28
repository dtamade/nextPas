procedure RegisterMock;
var
  table: record
    Mixed: Pointer;
  end;
begin
  {$IFDEF MOCK_ASM}
  table.Mixed := @MOCKMixed;
  {$ENDIF}
end;
