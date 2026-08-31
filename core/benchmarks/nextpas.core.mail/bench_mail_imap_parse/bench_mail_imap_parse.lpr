program bench_mail_imap_parse;

{ IMAP 会话解析热路径基准。
  场景 1 对齐原版 protocol.imap.parse_request_line 基线
  （fafafa-mail-server docs/perf/release-baseline.md：
  [245.19 ns 262.89 ns 280.60 ns]），验收预算 ≤2x 基线中位。
  场景 2 为序列集解析（本实现 mask 化，无原版对应项），信息性记录。

  用法：make run；数字记入 core/docs/mail/CONTRACT.md §9。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.mail.imap.base,
  nextpas.core.time.stopwatch;

const
  ITERATIONS = 2000000;
  LINE_WARMUP = 10000;
  { 与原版 bench 相同的请求行（行为基线） }
  SAMPLE_LINE = 'A143 UID FETCH 1:* (FLAGS UID ENVELOPE BODY[])';
  SEQ_UIDS = 64;

var
  LSW: TStopwatch;
  LI: Integer;
  LTotalMs: Int64;
  LNsPerOp: Int64;
  LOpsSec: Int64;
  LTag, LVerb, LArgs: string;
  LCheck: Integer;
  LUids: TImapUidArray;
  LPicked: TImapUidArray;
begin
  { ── 场景 1：请求行解析（对标原版 262.89ns）── }
  for LI := 1 to LINE_WARMUP do
    if not ImapParseRequestLine(SAMPLE_LINE, LTag, LVerb, LArgs) then
      Halt(1);

  LSW := TStopwatch.StartNew;
  LCheck := 0;
  for LI := 1 to ITERATIONS do
  begin
    if ImapParseRequestLine(SAMPLE_LINE, LTag, LVerb, LArgs) then
      LCheck := LCheck xor (Length(LTag) + Length(LVerb))
    else
      LCheck := LCheck xor 1;
  end;
  LSW.Stop;

  LTotalMs := LSW.ElapsedMilliseconds;
  if LTotalMs < 1 then
    LTotalMs := 1;
  LOpsSec := Int64(ITERATIONS) * 1000 div LTotalMs;
  LNsPerOp := LTotalMs * 1000000 div ITERATIONS;
  WriteLn('imap parse_request_line: ' + IntToStr(ITERATIONS) + ' iters in '
    + IntToStr(LTotalMs) + ' ms => ' + IntToStr(LOpsSec) + ' ops/s, '
    + IntToStr(LNsPerOp) + ' ns/op (check=' + IntToStr(LCheck)
    + '; original median 262.89 ns, budget <=525 ns)');

  { ── 场景 2：序列集解析（UID 模式，64 邮箱升序）── }
  SetLength(LUids, SEQ_UIDS);
  for LI := 0 to SEQ_UIDS - 1 do
    LUids[LI] := Int64(LI) * 3 + 1;   { 稀疏升序：1,4,7,… }

  for LI := 1 to LINE_WARMUP do
    if not ImapResolveSequenceSet('1:*', LUids, True, LPicked) then
      Halt(2);

  LSW := TStopwatch.StartNew;
  LCheck := 0;
  for LI := 1 to ITERATIONS do
  begin
    if ImapResolveSequenceSet('1:*', LUids, True, LPicked) then
      LCheck := LCheck xor Length(LPicked)
    else
      LCheck := LCheck xor 2;
  end;
  LSW.Stop;

  LTotalMs := LSW.ElapsedMilliseconds;
  if LTotalMs < 1 then
    LTotalMs := 1;
  LOpsSec := Int64(ITERATIONS) * 1000 div LTotalMs;
  LNsPerOp := LTotalMs * 1000000 div ITERATIONS;
  WriteLn('imap resolve_sequence_set(uid,64): ' + IntToStr(ITERATIONS)
    + ' iters in ' + IntToStr(LTotalMs) + ' ms => ' + IntToStr(LOpsSec)
    + ' ops/s, ' + IntToStr(LNsPerOp) + ' ns/op (check=' + IntToStr(LCheck)
    + ')');
end.
