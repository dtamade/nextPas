program test_lockfree_tdigest;

{$mode objfpc}{$H+}

uses
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.lockfree.tdigest,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

procedure TestTDigestBasic;
var
  LDigest: TTDigestImpl;
  LVal: Double;
  LI: Integer;
begin
  LDigest := TTDigestImpl.Create(50);
  try
    { Add 100 values: 1..100 }
    for LI := 1 to 100 do
      CheckEqual(Ord(tdOk), Ord(LDigest.Add(LI)));

    CheckEqual(UInt64(100), LDigest.Count);

    { Median should be close to 50 }
    CheckEqual(Ord(tdOk), Ord(LDigest.Quantile(0.5, LVal)));
    Check(LVal > 30, 'Median should be > 30');
    Check(LVal < 70, 'Median should be < 70');

    { P99 should be close to 99 }
    CheckEqual(Ord(tdOk), Ord(LDigest.Quantile(0.99, LVal)));
    Check(LVal > 90, 'P99 should be > 90');
  finally
    LDigest.Free;
  end;
end;

procedure TestTDigestEdgeCases;
var
  LDigest: TTDigestImpl;
  LVal: Double;
begin
  LDigest := TTDigestImpl.Create(10);
  try
    { Empty digest }
    CheckEqual(Ord(tdEmpty), Ord(LDigest.Quantile(0.5, LVal)));

    { Single value }
    LDigest.Add(42.0);
    CheckEqual(Ord(tdOk), Ord(LDigest.Quantile(0.5, LVal)));
    Check(Abs(LVal - 42.0) < 1.0, 'Single value quantile should be ~42');

    { Invalid quantile }
    CheckEqual(Ord(tdEmpty), Ord(LDigest.Quantile(-0.1, LVal)));
    CheckEqual(Ord(tdEmpty), Ord(LDigest.Quantile(1.1, LVal)));
  finally
    LDigest.Free;
  end;
end;

procedure TestTDigestClose;
var
  LDigest: TTDigestImpl;
begin
  LDigest := TTDigestImpl.Create(50);
  try
    LDigest.Add(1.0);
    LDigest.Close;
    Check(LDigest.IsClosed, 'Should be closed');
    CheckEqual(Ord(tdClosed), Ord(LDigest.Add(2.0)));
  finally
    LDigest.Free;
  end;
end;

procedure TestTDigestManyValues;
var
  LDigest: TTDigestImpl;
  LVal: Double;
  LI: Integer;
begin
  LDigest := TTDigestImpl.Create(100);
  try
    for LI := 1 to 10000 do
      LDigest.Add(LI * 0.1);

    CheckEqual(UInt64(10000), LDigest.Count);

    { P10 should be > 50 }
    CheckEqual(Ord(tdOk), Ord(LDigest.Quantile(0.1, LVal)));
    Check(LVal > 50, 'P10 should be > 50, got ' + FloatToStr(LVal));

    { P90 should be > 500 }
    CheckEqual(Ord(tdOk), Ord(LDigest.Quantile(0.9, LVal)));
    Check(LVal > 500, 'P90 should be > 500, got ' + FloatToStr(LVal));
  finally
    LDigest.Free;
  end;
end;

procedure TestTDigestCompressionPreservesTailOrder;
var
  LDigest: TTDigestImpl;
  LVal: Double;
  LI: Integer;
begin
  LDigest := TTDigestImpl.Create(10);
  try
    for LI := 1 to 1000 do
      CheckEqual(Ord(tdOk), Ord(LDigest.Add(LI)));

    CheckEqual(Ord(tdOk), Ord(LDigest.Quantile(0.99, LVal)));
    Check(LVal > 950.0, 'Compressed P99 should preserve the upper tail');
    CheckEqual(Ord(tdOk), Ord(LDigest.Quantile(1.0, LVal)));
    Check(LVal > 990.0, 'Compressed maximum should remain in the upper tail');
  finally
    LDigest.Free;
  end;
end;

procedure TestTDigestCompressionUsesQuantileWeight;
var
  LSource: string;
begin
  LSource := ReadFileText('../../../src/nextpas.core.lockfree.tdigest.pas');
    Check(Pos('LCumulativeWeight', LSource) > 0,
      'Compression must track cumulative centroid weight');
    Check(Pos('4.0 * FTotalWeight * LQ * (1.0 - LQ) / FCompression',
      LSource) > 0, 'Compression must apply the quantile weight bound');
end;

begin
  WriteLn('=== test_lockfree_tdigest ===');
  WriteLn;

  TestTDigestBasic;
  WriteLn('  + Basic quantiles');

  TestTDigestEdgeCases;
  WriteLn('  + Edge cases');

  TestTDigestClose;
  WriteLn('  + Close semantics');

  TestTDigestManyValues;
  WriteLn('  + Many values');

  TestTDigestCompressionPreservesTailOrder;
  WriteLn('  + Compression preserves tail order');

  TestTDigestCompressionUsesQuantileWeight;
  WriteLn('  + Quantile-weight compression contract');

  WriteLn;
  WriteLn('All T-Digest tests passed!');
end.
