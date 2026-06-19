{**
 * bench_fair — 公平基准: 测量真实场景，避免编译器优化偏见
 *
 * 关键设计: 用 volatile sink 防止 FPC 优化掉循环
 *}
program bench_fair;
{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.text.tstring;

const
  N = 500000;

var
  i: Integer;
  t0, t1: TDateTime;
  SinkS: string = '';
  SinkTS: TString;

function S(const AStr: AnsiString): TString;
begin
  Result := TString.Create(@AStr[1], Length(AStr));
end;

{ 确保编译器不优化掉赋值 }
procedure Sink(constref s: string); begin SinkS := s; end;
procedure SinkT(constref ts: TString); begin SinkTS := ts; end;

{ === FPC 测试 === }

procedure FPC_SSO_Lifecycle;
var
  s: string;
begin
  t0 := Now;
  for i := 1 to N do
  begin
    s := 'hello';  { 5B, 每次 alloc+free }
    Sink(s);
    s := '';
  end;
  t1 := Now;
  WriteLn('[FPC]    SSO lifecycle  (5B) x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

procedure FPC_SSO_Assign;
var
  s, s2: string;
begin
  s := 'test string';
  t0 := Now;
  for i := 1 to N do
  begin
    s2 := s;   { refcount incr/decr }
    Sink(s2);
  end;
  t1 := Now;
  s := ''; s2 := '';
  WriteLn('[FPC]    SSO assign     (11B) x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

procedure FPC_Heap_Lifecycle;
var
  s: string;
begin
  t0 := Now;
  for i := 1 to N do
  begin
    s := 'this is a long string over 15'; { 30B, heap }
    Sink(s);
    s := '';
  end;
  t1 := Now;
  WriteLn('[FPC]    heap lifecycle (30B) x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

procedure FPC_Heap_Assign;
var
  s, s2: string;
begin
  s := 'this is a long string over 15';
  t0 := Now;
  for i := 1 to N do
  begin
    s2 := s;   { refcount only }
    Sink(s2);
  end;
  t1 := Now;
  s := ''; s2 := '';
  WriteLn('[FPC]    heap assign    (30B) x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

{ === TString 测试 === }

procedure TS_SSO_Lifecycle;
var
  src: AnsiString;
  ts: TString;
begin
  src := 'hello';
  t0 := Now;
  for i := 1 to N do
  begin
    ts := TString.Create(@src[1], Length(src));
    SinkT(ts);
    StringFini(ts);
  end;
  t1 := Now;
  WriteLn('[TStr]   SSO lifecycle  (5B) x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

{ Note: FPC SSO assign 实际是 heap AnsiString (有引用计数),
  而 TString SSO assign 是纯 memcpy (无原子操作)。
  这使 TString SSO 赋值天然更快, 不是完全公平的比较。 }
procedure TS_SSO_Assign;
var
  ts, ts2: TString;
begin
  ts := S('test string');
  t0 := Now;
  for i := 1 to N do
  begin
    StringAssign(ts2, ts);
    SinkT(ts2);
  end;
  t1 := Now;
  StringFini(ts);
  StringFini(ts2);
  WriteLn('[TStr]   SSO assign     (11B) x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

procedure TS_Heap_Lifecycle;
var
  src: AnsiString;
  ts: TString;
begin
  src := 'this is a long string over 15';
  t0 := Now;
  for i := 1 to N do
  begin
    ts := TString.Create(@src[1], Length(src));
    SinkT(ts);
    StringFini(ts);
  end;
  t1 := Now;
  WriteLn('[TStr]   heap lifecycle (30B) x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

procedure TS_Heap_Assign;
var
  src: AnsiString;
  ts, ts2: TString;
begin
  src := 'this is a long string over 15';
  ts := TString.Create(@src[1], Length(src));
  t0 := Now;
  for i := 1 to N do
  begin
    StringAssign(ts2, ts);
    SinkT(ts2);
  end;
  t1 := Now;
  StringFini(ts);
  StringFini(ts2);
  WriteLn('[TStr]   heap assign    (30B) x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

begin
  WriteLn('=== Fair Benchmark: TString v2 vs FPC AnsiString ===');
  WriteLn('FPC: ', {$I %FPCVERSION%}, ' / ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%});
  WriteLn('TStringHeader = ', SizeOf(TStringHeader), 'B');
  WriteLn('N = ', N);
  WriteLn;

  WriteLn('--- Create + Destroy ---');
  FPC_SSO_Lifecycle;
  TS_SSO_Lifecycle;
  WriteLn;
  FPC_Heap_Lifecycle;
  TS_Heap_Lifecycle;

  WriteLn;
  WriteLn('--- Assign (refcount) ---');
  FPC_SSO_Assign;
  TS_SSO_Assign;
  WriteLn;
  FPC_Heap_Assign;
  TS_Heap_Assign;

  WriteLn;
  WriteLn('--- Memory Analysis ---');
  WriteLn('FPC header: 16B | TString header: ', SizeOf(TStringHeader), 'B');
  WriteLn('FPC var: 8B (ptr) | TString var: ', SizeOf(TString), 'B (inline)');
  WriteLn('SSO heap savings (5B): ', 16+5+1, 'B alloc avoided');
  WriteLn('SSO heap savings (14B): ', 16+14+1, 'B alloc avoided');

  WriteLn;
  WriteLn('Done.');
end.
