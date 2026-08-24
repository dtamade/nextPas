program translate_bench;
{$mode ObjFPC}{$H+}
uses SysUtils;
{ 与 nextpas.core.db.pg.adapter.TranslatePlaceholders 相同的拼接模式 }
function TranslateLike(const ASql: string): string;
var LB: string; I: Integer; C: Char;
begin
  LB := '';
  for I := 1 to Length(ASql) do
  begin
    C := ASql[I];
    if C <> '?' then LB := LB + C else LB := LB + '$1';
  end;
  Result := LB;
end;
var
  S: string;
  I, Len: Integer;
  T0, T1: QWord;
  Sizes: array[0..3] of Integer = (10000, 100000, 500000, 2000000);
begin
  for I := 0 to 3 do
  begin
    Len := Sizes[I];
    SetLength(S, Len);
    for Len := 1 to High(S) do S[Len] := Chr(65 + (Len mod 26));
    T0 := GetTickCount64;
    S := TranslateLike(S);
    T1 := GetTickCount64;
    WriteLn(Format('len=%9d -> %6d ms (outlen=%d)', [Sizes[I], T1-T0, Length(S)]));
  end;
end.
