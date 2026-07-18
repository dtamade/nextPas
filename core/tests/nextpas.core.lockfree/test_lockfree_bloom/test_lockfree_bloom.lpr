program test_lockfree_bloom;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.bloom,
  nextpas.core.text.conv,
  nextpas.core.test;

type
  TIntBloom = specialize TConcurrentBloomFilter<Int64>;

procedure TestBloomBasic;
var
  LBloom: TIntBloom;
begin
  LBloom := TIntBloom.Create(1000, 0.01);
  try
    // Empty filter
    Check(not LBloom.IsClosed, 'Filter should not be closed');
    CheckEqual(PtrUInt(0), LBloom.Count);
    Check(LBloom.BitCount > 0, 'Bit count should be > 0');
    Check(LBloom.HashCount > 0, 'Hash count should be > 0');

    // Add one element
    Check(LBloom.Add(42), 'Should add element');
    CheckEqual(PtrUInt(1), LBloom.Count);

    // Contains element
    Check(LBloom.Contains(42), 'Should contain 42');

    // Does not contain other element
    // (May have false positive, but very unlikely with good params)
    // Just check that it doesn't crash
    LBloom.Contains(43);
  finally
    LBloom.Free;
  end;
end;

procedure TestBloomMultipleElements;
var
  LBloom: TIntBloom;
  I: Integer;
begin
  LBloom := TIntBloom.Create(10000, 0.01);
  try
    // Add many elements
    for I := 1 to 100 do
      Check(LBloom.Add(I * 10), 'Should add element');

    CheckEqual(PtrUInt(100), LBloom.Count);

    // Contains all added elements
    for I := 1 to 100 do
      Check(LBloom.Contains(I * 10), 'Should contain element');
  finally
    LBloom.Free;
  end;
end;

procedure TestBloomNoFalseNegative;
var
  LBloom: TIntBloom;
  I: Integer;
begin
  LBloom := TIntBloom.Create(1000, 0.01);
  try
    // Add elements
    for I := 1 to 100 do
      LBloom.Add(I);

    // All added elements should be found (no false negative)
    for I := 1 to 100 do
      Check(LBloom.Contains(I), 'Should not have false negative');
  finally
    LBloom.Free;
  end;
end;

procedure TestBloomFalsePositiveRate;
var
  LBloom: TIntBloom;
  I: Integer;
  LFalsePositives: Integer;
begin
  LBloom := TIntBloom.Create(1000, 0.01);
  try
    // Add elements 1-1000
    for I := 1 to 1000 do
      LBloom.Add(I);

    // Check elements 1001-2000 (should not be present)
    LFalsePositives := 0;
    for I := 1001 to 2000 do
    begin
      if LBloom.Contains(I) then
        Inc(LFalsePositives);
    end;

    // False positive rate should be around 1% (10 out of 1000)
    // Allow some tolerance: 0-30 false positives
    Check(LFalsePositives <= 30, 'False positive rate too high: ' + IntToStr(LFalsePositives));
  finally
    LBloom.Free;
  end;
end;

procedure TestBloomUsesNearestOptimalHashCount;
var
  LBloom: TIntBloom;
  LExpectedHashCount: Integer;
begin
  LBloom := TIntBloom.Create(1000, 0.1);
  try
    LExpectedHashCount := Round(Double(LBloom.BitCount) / 1000.0 * 0.6931471805599453);
    CheckEqual(LExpectedHashCount, LBloom.HashCount,
      'Hash count should use the nearest integer to the theoretical optimum');
  finally
    LBloom.Free;
  end;
end;

procedure TestBloomClear;
var
  LBloom: TIntBloom;
begin
  LBloom := TIntBloom.Create(1000, 0.01);
  try
    // Add elements
    LBloom.Add(1);
    LBloom.Add(2);
    LBloom.Add(3);

    CheckEqual(PtrUInt(3), LBloom.Count);

    // Clear
    LBloom.Clear;

    CheckEqual(PtrUInt(0), LBloom.Count);
  finally
    LBloom.Free;
  end;
end;

procedure TestBloomClose;
var
  LBloom: TIntBloom;
begin
  LBloom := TIntBloom.Create(1000, 0.01);
  try
    // Add element
    LBloom.Add(42);

    // Close
    LBloom.Close;
    Check(LBloom.IsClosed, 'Filter should be closed');

    // Can still check contains
    Check(LBloom.Contains(42), 'Should still contain 42');

    // Cannot add after close
    Check(not LBloom.Add(43), 'Should not add after close');
  finally
    LBloom.Free;
  end;
end;

procedure TestBloomDifferentTypes;
var
  LIntBloom: specialize TConcurrentBloomFilter<Integer>;
  LStrBloom: specialize TConcurrentBloomFilter<ShortString>;
begin
  // Test with Integer
  LIntBloom := specialize TConcurrentBloomFilter<Integer>.Create(100, 0.01);
  try
    LIntBloom.Add(42);
    Check(LIntBloom.Contains(42), 'Should contain 42');
  finally
    LIntBloom.Free;
  end;

  // Test with ShortString
  LStrBloom := specialize TConcurrentBloomFilter<ShortString>.Create(100, 0.01);
  try
    LStrBloom.Add('hello');
    Check(LStrBloom.Contains('hello'), 'Should contain hello');
  finally
    LStrBloom.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_bloom ===');
  WriteLn;

  TestBloomBasic;
  WriteLn('  + Basic add/contains');

  TestBloomMultipleElements;
  WriteLn('  + Multiple elements');

  TestBloomNoFalseNegative;
  WriteLn('  + No false negative');

  TestBloomFalsePositiveRate;
  WriteLn('  + False positive rate');

  TestBloomUsesNearestOptimalHashCount;
  WriteLn('  + Optimal hash count');

  TestBloomClear;
  WriteLn('  + Clear');

  TestBloomClose;
  WriteLn('  + Close semantics');

  TestBloomDifferentTypes;
  WriteLn('  + Different types');

  WriteLn;
  WriteLn('All bloom filter tests passed!');
end.
