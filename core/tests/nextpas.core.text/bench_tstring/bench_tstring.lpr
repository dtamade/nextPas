{**
 * bench_tstring — TString vs FPC AnsiString 性能对比
 *
 * 同场景直接对比：创建/赋值/CoW/内存
 *}
program bench_tstring;
{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.text.tstring;

const
  N = 1000000;

var
  i: Integer;
  t0, t1: TDateTime;

{ === FPC AnsiString 基线 === }

procedure FPC_SmallCreate;
var
  s: string;
begin
  t0 := Now;
  for i := 1 to N do
    s := 'hello';
  t1 := Now;
  s := '';
  WriteLn('[FPC]    small (5B)  create x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

procedure FPC_MediumCreate;
var
  s: string;
begin
  t0 := Now;
  for i := 1 to N do
    s := 'hello world!!!';
  t1 := Now;
  s := '';
  WriteLn('[FPC]    medium(14B) create x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

procedure FPC_HeapCreate;
var
  s: string;
begin
  t0 := Now;
  for i := 1 to N do
    s := '0123456789abcdef';
  t1 := Now;
  s := '';
  WriteLn('[FPC]    heap  (16B) create x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

procedure FPC_Assign;
var
  s, s2: string;
begin
  s := 'shared string value longer than 15';
  t0 := Now;
  for i := 1 to N do
  begin
    s2 := s;
    s2 := '';
  end;
  t1 := Now;
  s := '';
  WriteLn('[FPC]    heap assign   x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

{ === TString 测试 === }

procedure TS_SmallCreate;
var
  src: AnsiString;
  ts: TString;
begin
  src := 'hello';
  t0 := Now;
  for i := 1 to N do
  begin
    ts := TString.Create(@src[1], Length(src));
    StringFini(ts);
  end;
  t1 := Now;
  WriteLn('[TStr]   small (5B)  create x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms', ' (SSO)');
end;

procedure TS_MediumCreate;
var
  src: AnsiString;
  ts: TString;
begin
  src := 'hello world!!!';
  t0 := Now;
  for i := 1 to N do
  begin
    ts := TString.Create(@src[1], Length(src));
    StringFini(ts);
  end;
  t1 := Now;
  WriteLn('[TStr]   medium(14B) create x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms', ' (SSO)');
end;

procedure TS_HeapCreate;
var
  src: AnsiString;
  ts: TString;
begin
  src := '0123456789abcdef';
  t0 := Now;
  for i := 1 to N do
  begin
    ts := TString.Create(@src[1], Length(src));
    StringFini(ts);
  end;
  t1 := Now;
  WriteLn('[TStr]   heap  (16B) create x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms', ' (heap)');
end;

function S(const AStr: AnsiString): TString;
begin
  Result := TString.Create(@AStr[1], Length(AStr));
end;

procedure TS_Assign_Heap;
var
  ts, ts2: TString;
begin
  ts := S('shared string value longer than 15');
  t0 := Now;
  for i := 1 to N do
  begin
    StringAssign(ts2, ts);
    StringFini(ts2);
  end;
  t1 := Now;
  StringFini(ts);
  WriteLn('[TStr]   heap assign   x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

procedure TS_Assign_SSO;
var
  ts, ts2: TString;
begin
  ts := S('hello');
  t0 := Now;
  for i := 1 to N do
  begin
    StringAssign(ts2, ts);
    StringFini(ts2);
  end;
  t1 := Now;
  StringFini(ts);
  WriteLn('[TStr]   SSO assign    x', N, ': ',
    FormatFloat('0.000', (t1 - t0) * 86400 * 1000), ' ms');
end;

{ === SizeOf & 内存分析 === }

procedure ShowMemoryAnalysis;
begin
  WriteLn;
  WriteLn('=== 内存布局分析 ===');
  WriteLn('FPC AnsiString:');
  WriteLn('  SizeOf = ', SizeOf(AnsiString), ' bytes (指针)');
  WriteLn('  Header = 16 bytes (CodePage:2 + ElemSize:2 + Ref:4 + Len:8)');
  WriteLn('  5B  data: 16+5+1 = 22 bytes heap (每次创建)');
  WriteLn('  14B data: 16+14+1 = 31 bytes heap');
  WriteLn('  16B data: 16+16+1 = 33 bytes heap');
  WriteLn;
  WriteLn('TString:');
  WriteLn('  SizeOf = ', SizeOf(TString), ' bytes (值类型)');
  WriteLn('  SSO (<=15B): 0 bytes heap, 数据内联');
  WriteLn('  Heap(>15B):  24 header + data + 1 null');
  WriteLn('  16B data: 24+16+1 = 41 bytes heap');
  WriteLn;
  WriteLn('SSO 收益:');
  WriteLn('  5B  字符串: 省 22 bytes/次, 0 alloc vs 1 alloc');
  WriteLn('  14B 字符串: 省 31 bytes/次, 0 alloc vs 1 alloc');
  WriteLn('  16B 字符串: 多花 8 bytes/次 (header 更大)');
  WriteLn;
  WriteLn('FPC inclocked/declocked: 编译器内建 → lock add/sub (单指令)');
  WriteLn('TString TAtomicISize:    函数调用 → lock xadd (可能多几条指令)');
end;

begin
  WriteLn('=== TString vs FPC AnsiString 性能对比 ===');
  WriteLn('FPC version: ', {$I %FPCVERSION%});
  WriteLn('Target: ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%});
  WriteLn('Iterations: ', N);
  WriteLn;

  WriteLn('--- 创建 ---');
  FPC_SmallCreate;
  TS_SmallCreate;
  WriteLn;
  FPC_MediumCreate;
  TS_MediumCreate;
  WriteLn;
  FPC_HeapCreate;
  TS_HeapCreate;

  WriteLn;
  WriteLn('--- 赋值 ---');
  FPC_Assign;
  TS_Assign_Heap;
  TS_Assign_SSO;

  ShowMemoryAnalysis;

  WriteLn;
  WriteLn('Done.');
end.
