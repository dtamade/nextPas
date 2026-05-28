function MOCKExact: Integer; assembler; nostackframe;
asm
  mov eax, 1
end;

function MOCKSuffix: Integer;
begin
  Result := MOCKSuffix_ASM;
end;

function MOCKSuffix_ASM: Integer; assembler; nostackframe;
asm
  mov eax, 2
end;

function MOCKWrapper: Integer;
begin
  Result := 3;
end;
