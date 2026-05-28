function MOCKLeaf: Integer; assembler; nostackframe;
asm
  mov eax, 4
end;

function MOCKCompose: Integer;
begin
  Result := MOCKLeaf();
end;
