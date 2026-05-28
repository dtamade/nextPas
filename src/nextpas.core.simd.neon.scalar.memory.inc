// === Memory Operations ===

function NEONLoadF32x4(p: PSingle): TVecF32x4;
begin
  Result := ScalarLoadF32x4(p);
end;

function NEONLoadF32x4Aligned(p: PSingle): TVecF32x4;
begin
  Result := ScalarLoadF32x4Aligned(p);
end;

procedure NEONStoreF32x4(p: PSingle; const a: TVecF32x4);
begin
  ScalarStoreF32x4(p, a);
end;

procedure NEONStoreF32x4Aligned(p: PSingle; const a: TVecF32x4);
begin
  ScalarStoreF32x4Aligned(p, a);
end;
