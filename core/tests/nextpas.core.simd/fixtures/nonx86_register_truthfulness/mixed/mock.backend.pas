{$IFDEF ALT_IMPL}
function MOCKMixed: Integer;
begin
  Result := 7;
end;
{$ELSE}
function MOCKMixed: Integer;
begin
  Result := ScalarMixed;
end;
{$ENDIF}

function ScalarMixed: Integer;
begin
  Result := 11;
end;
