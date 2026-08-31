program test_os_procinfo;

{ nextpas.core.os.procinfo 契约测试：
  - RSS 可读且为正（Linux；其他平台返回哨兵值，断言按平台分支）
  - 峰值 ≥ 当前 RSS
  - 触碰新分配内存后 RSS 增长（口径有效性：resident 随真实常驻变化）
  - 源码契约：os.procinfo 源与测试无裸 FPC RTL uses }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.os.procinfo;

var
  T: TTestSuite;

{$I ../../fpc_rtl_uses_scan.inc}

function LoadSourceText(const ARelativePath: string): string;
begin
  Result := ReadFileText(PathAbs('../../../' + ARelativePath));
end;

procedure AssertSourceNoBareFpcRtlUses(const ALabel, ASource: string);
var
  LHit: string;
  LOk: Boolean;
  LMsg: string;
begin
  LOk := not FindBareFpcRtlInUses(ASource, LHit);
  LMsg := ALabel + ' — no bare FPC RTL in uses';
  if not LOk then
    LMsg := LMsg + ' (hit: ' + LHit + ')';
  Check(LOk, LMsg);
end;

procedure TestProcinfoOwnedSourcesNoFpcRtl;
begin
  AssertSourceNoBareFpcRtlUses('procinfo src',
    LoadSourceText('src/nextpas.core.os.procinfo.pas'));
end;

procedure TestProcinfoTestSuiteNoFpcRtl;
begin
  AssertSourceNoBareFpcRtlUses('procinfo test',
    LoadSourceText('tests/nextpas.core.os.procinfo/test_os_procinfo/test_os_procinfo.lpr'));
end;

procedure TestRssReadable;
var
  LRss: Int64;
begin
  LRss := ProcessRssBytes;
  {$IFDEF LINUX}
  Check((LRss > 0) and (LRss <> cProcessMemUnknown),
    'Linux 上 RSS 应可读且为正，实际 ' + IntToStr(LRss));
  {$ELSE}
  Check(LRss = cProcessMemUnknown,
    '无后端平台应返回 cProcessMemUnknown');
  {$ENDIF}
end;

procedure TestPeakGeCurrent;
var
  LRss, LPeak: Int64;
begin
  LRss := ProcessRssBytes;
  LPeak := ProcessPeakRssBytes;
  if LRss = cProcessMemUnknown then
  begin
    Check(LPeak = cProcessMemUnknown,
      'RSS 未知时峰值也应同哨兵');
    Exit;
  end;
  Check((LPeak >= LRss) and (LPeak > 0),
    '峰值应为正且 ≥ 当前 RSS：peak=' + IntToStr(LPeak) +
    ' rss=' + IntToStr(LRss));
end;

{ 口径有效性：分配并逐页触碰 8MB 后 RSS 至少增长 ~4MB。
  放在用例序列末尾：最小化堆复用已常驻空闲页的概率。 }
procedure TestRssGrowsOnTouch;
const
  cChunk = 8 * 1024 * 1024;
var
  LBefore, LAfter: Int64;
  LP: PByte;
  LI: Integer;
begin
  LBefore := ProcessRssBytes;
  if LBefore = cProcessMemUnknown then
  begin
    Check(True, '无后端平台跳过增长断言');
    Exit;
  end;
  GetMem(LP, cChunk);
  LI := 0;
  while LI < cChunk do
  begin
    LP[LI] := Byte(LI);
    LI := LI + 4096;
  end;
  LAfter := ProcessRssBytes;
  FreeMem(LP);
  Check(LAfter >= LBefore + cChunk div 2,
    '触碰 8MB 后 RSS 应至少增长 ~4MB：before=' + IntToStr(LBefore) +
    ' after=' + IntToStr(LAfter));
end;

begin
  T := TTestSuite.Create('nextpas.core.os.procinfo');
  T.Test('sources no bare FPC RTL', @TestProcinfoOwnedSourcesNoFpcRtl);
  T.Test('test suite no bare FPC RTL', @TestProcinfoTestSuiteNoFpcRtl);
  T.Test('RSS readable', @TestRssReadable);
  T.Test('peak >= current', @TestPeakGeCurrent);
  T.Test('RSS grows on touch', @TestRssGrowsOnTouch);
  if not T.Run then Halt(1);
end.
