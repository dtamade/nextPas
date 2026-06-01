program fuzz_input_parser;
{$I nextpas.core.settings.inc}
uses
  BaseUnix,
  nextpas.core.tui.event,
  nextpas.core.tui.input;
var
  LBuf: array[0..65535] of Byte;
  LLen, LConsumed, LPos, LIter: Integer;
  LRead: TSSize;
  LEv: TEvent;
  LRes: TParseResult;
begin
  LLen := 0;
  repeat
    LRead := fpRead(0, @LBuf[LLen], SizeOf(LBuf) - LLen);
    if LRead > 0 then Inc(LLen, LRead);
  until (LRead <= 0) or (LLen >= SizeOf(LBuf));
  if LLen = 0 then Halt(0);

  LPos := 0;
  LIter := 0;
  while LPos < LLen do
  begin
    LRes := ParseOne(LBuf[LPos], LLen - LPos, True, LEv, LConsumed);
    case LRes of
      prSuccess:
        if LConsumed > 0 then Inc(LPos, LConsumed)
        else Inc(LPos);
      prNeedMore:
        Inc(LPos);
      prInvalid:
        Inc(LPos);
    end;
    Inc(LIter);
    if LIter > 100000 then Halt(1);
  end;
end.
