// nextpas.core.text.unicode.test_helpers.inc
// 共享测试辅助函数 — 被 test_collate / test_normalize / test_case 引用

procedure AppendUtf8(var ADst: string; const ACp: TUnicodeCodepoint);
var
  LBuf: array[0..3] of Byte;
  LLen: Byte;
  LOldLen: SizeInt;
  I: Byte;
begin
  LLen := UTF8Encode(ACp, @LBuf[0]);
  Check(LLen > 0, 'test codepoint must be UTF-8 encodable');

  LOldLen := Length(ADst);
  SetLength(ADst, LOldLen + LLen);
  for I := 0 to LLen - 1 do
    ADst[LOldLen + I + 1] := AnsiChar(LBuf[I]);
end;

function Utf8Of(const ACps: array of TUnicodeCodepoint): string;
var
  I: SizeInt;
begin
  Result := '';
  for I := 0 to High(ACps) do
    AppendUtf8(Result, ACps[I]);
end;
