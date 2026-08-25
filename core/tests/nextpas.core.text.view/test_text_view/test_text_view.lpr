program test_text_view;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text,
  nextpas.core.text.view,
  nextpas.core.base,
  nextpas.core.test;

var
  T: TTestSuite;

procedure CheckInvalidViewCreateRaises(const AMessage: string);
begin
  try
    TStringView.Create(nil, 1);
    Fail(AMessage + ': expected EInvalidArgument');
  except
    on E: EInvalidArgument do
      ;
  end;
end;

procedure TestCreateAndBasic;
var
  V: TStringView;
begin
  V := TStringView.Create(PAnsiChar('hello'), 5);
  Check(not V.IsEmpty, 'not empty');
  CheckEqual(Int64(5), Int64(V.Len), 'len=5');
  Check(V.Data[0] = 'h', 'data[0]=h');

  V := TStringView.Empty;
  Check(V.IsEmpty, 'empty');
  CheckEqual(Int64(0), Int64(V.Len), 'len=0');
end;

procedure TestRejectNilDataWithNonZeroLength;
var
  V: TStringView;
  S: TByteSpan;
begin
  V := TStringView.Create(nil, 0);
  Check(V.IsEmpty, 'nil+zero create is empty');
  CheckInvalidViewCreateRaises('nil+nonzero create');

  S := TByteSpan.Create(nil, 0);
  V := TStringView.FromSpan(S);
  Check(V.IsEmpty, 'nil+zero span is empty');

  try
    S := TByteSpan.Create(nil, 1);
    Fail('nil+nonzero span create: expected EArgumentNil');
  except
    on E: EArgumentNil do
      ;
  end;
end;

procedure TestFromStr;
var
  V: TStringView;
  S: string;
begin
  S := 'world';
  V := TStringView.FromStr(S);
  CheckEqual(Int64(5), Int64(V.Len), 'len');
  Check(V.Data[0] = 'w', 'data[0]');
end;

procedure TestSlice;
var
  V, S: TStringView;
begin
  V := TStringView.Create(PAnsiChar('abcdef'), 6);
  S := V.Slice(2, 3);
  CheckEqual(Int64(3), Int64(S.Len), 'slice len');
  Check(S.Data[0] = 'c', 'slice[0]=c');

  S := V.Slice(4, 100);
  CheckEqual(Int64(2), Int64(S.Len), 'slice clamped');

  S := V.Slice(10, 1);
  Check(S.IsEmpty, 'slice past end');
end;

procedure TestSliceClampsOverflowedLength;
var
  V, S: TStringView;
begin
  V := TStringView.Create(PAnsiChar('abcdef'), 6);
  S := V.Slice(1, High(SizeUInt));
  CheckEqual(Int64(5), Int64(S.Len), 'overflowed length clamps to remaining bytes');
  Check(S.Data[0] = 'b', 'clamped slice starts at offset');
end;

procedure TestLeftRight;
var
  V: TStringView;
begin
  V := TStringView.Create(PAnsiChar('abcdef'), 6);
  Check(V.Left(3).Equals(TStringView.Create(PAnsiChar('abc'), 3)), 'left 3');
  Check(V.Right(2).Equals(TStringView.Create(PAnsiChar('ef'), 2)), 'right 2');
  Check(V.Left(100).Equals(V), 'left overflow');
  Check(V.Right(100).Equals(V), 'right overflow');
end;

procedure TestTrim;
var
  V: TStringView;
begin
  V := TStringView.Create(PAnsiChar('  hi  '), 6);
  Check(V.TrimLeft.Equals(TStringView.Create(PAnsiChar('hi  '), 4)), 'trim left');
  V := TStringView.Create(PAnsiChar('  hi  '), 6);
  Check(V.TrimRight.Equals(TStringView.Create(PAnsiChar('  hi'), 4)), 'trim right');
  V := TStringView.Create(PAnsiChar('  hi  '), 6);
  Check(V.Trim.Equals(TStringView.Create(PAnsiChar('hi'), 2)), 'trim both');
end;

procedure TestEquals;
var
  A, B: TStringView;
begin
  A := TStringView.Create(PAnsiChar('abc'), 3);
  B := TStringView.Create(PAnsiChar('abc'), 3);
  Check(A.Equals(B), 'equal');
  B := TStringView.Create(PAnsiChar('abd'), 3);
  Check(not A.Equals(B), 'not equal');
  B := TStringView.Create(PAnsiChar('ab'), 2);
  Check(not A.Equals(B), 'diff len');
end;

procedure TestEqualsIgnoreCase;
var
  A, B: TStringView;
begin
  A := TStringView.Create(PAnsiChar('Hello'), 5);
  B := TStringView.Create(PAnsiChar('hELLO'), 5);
  Check(A.EqualsIgnoreCase(B), 'case insensitive');
  B := TStringView.Create(PAnsiChar('world'), 5);
  Check(not A.EqualsIgnoreCase(B), 'different');
end;

procedure TestStartsEndsWith;
var
  V, P: TStringView;
begin
  V := TStringView.Create(PAnsiChar('hello world'), 11);
  P := TStringView.Create(PAnsiChar('hello'), 5);
  Check(V.StartsWith(P), 'starts with');
  P := TStringView.Create(PAnsiChar('world'), 5);
  Check(V.EndsWith(P), 'ends with');
  P := TStringView.Create(PAnsiChar('xyz'), 3);
  Check(not V.StartsWith(P), 'not starts');
  Check(not V.EndsWith(P), 'not ends');
end;

procedure TestIndexOf;
var
  V: TStringView;
begin
  V := TStringView.Create(PAnsiChar('hello world'), 11);
  CheckEqual(Int64(4), Int64(V.IndexOf('o')), 'first o');
  CheckEqual(Int64(-1), Int64(V.IndexOf('z')), 'z not found');
  CheckEqual(Int64(0), Int64(V.IndexOf('h')), 'h at 0');
  Check(V.Contains('w'), 'contains w');
  Check(not V.Contains('z'), 'not contains z');
end;

procedure TestIndexOfStr;
var
  V, N: TStringView;
begin
  V := TStringView.Create(PAnsiChar('hello world'), 11);
  N := TStringView.Create(PAnsiChar('world'), 5);
  CheckEqual(Int64(6), Int64(V.IndexOfStr(N)), 'world at 6');
  N := TStringView.Create(PAnsiChar('xyz'), 3);
  CheckEqual(Int64(-1), Int64(V.IndexOfStr(N)), 'xyz not found');
  N := TStringView.Empty;
  CheckEqual(Int64(0), Int64(V.IndexOfStr(N)), 'empty needle');
end;

procedure TestStringIndexOfHelpers;
begin
  CheckEqual(Int64(2), Int64(IndexOfStr('hello', 'llo')), 'substring index');
  CheckEqual(Int64(0), Int64(IndexOfStr('hello', '')), 'empty substring');
  CheckEqual(Int64(-1), Int64(IndexOfStr('hello', 'xyz')), 'missing substring');

  CheckEqual(Int64(3), Int64(LastIndexOfStr('abcabc', 'abc')), 'last substring');
  CheckEqual(Int64(0), Int64(LastIndexOfStr('abcdef', 'abc')), 'only substring');
  CheckEqual(Int64(-1), Int64(LastIndexOfStr('hello', '')), 'empty last substring');
end;

procedure TestAdvanceCursor;
var
  V: TStringView;
  B: Byte;
begin
  V := TStringView.Create(PAnsiChar('abc'), 3);
  Check(V.PeekByte = Ord('a'), 'peek a');
  Check(V.TryConsumeByte(B), 'consume');
  Check(B = Ord('a'), 'consumed a');
  CheckEqual(Int64(2), Int64(V.Len), 'len after consume');
  V.Advance(1);
  CheckEqual(Int64(1), Int64(V.Len), 'len after advance');
  Check(V.PeekByte = Ord('c'), 'peek c');
  V.Advance(100);
  Check(V.IsEmpty, 'advance past end');
end;

procedure TestToString;
var
  V: TStringView;
  S: string;
begin
  V := TStringView.Create(PAnsiChar('test'), 4);
  S := V.ToString;
  CheckEqual('test', S, 'to string');
  V := TStringView.Empty;
  S := V.ToString;
  CheckEqual('', S, 'empty to string');
end;

{ SliceToStr：string→string 一致切片（即时拷贝版 Slice）。 }
procedure TestSliceToStr;
var
  S: string;
begin
  S := 'abcdef';
  CheckEqual('cde', nextpas.core.text.view.SliceToStr(S, 2, 3), 'basic');
  CheckEqual('bcdef', nextpas.core.text.view.SliceToStr(S, 1, High(SizeUInt)),
    'overflowed length clamps to end');
  CheckEqual('', nextpas.core.text.view.SliceToStr(S, 6, 1), 'offset past end');
  CheckEqual('', nextpas.core.text.view.SliceToStr(S, 0, 0), 'zero length');
  CheckEqual('', nextpas.core.text.view.SliceToStr('', 0, 5), 'empty source');

  { 自赋值安全锁（FPC -19195：view 链自赋值产出短一字符尾随 #0 坏串；
    本函数一步 SetString，源=目标必须保持正确——回归不可删）。 }
  S := '''val''';
  S := nextpas.core.text.view.SliceToStr(S, 1, Length(S) - 2);
  CheckEqual(Int64(3), Int64(Length(S)), 'self-assign length');
  CheckEqual('val', S, 'self-assign content');

end;

procedure TestTextFacadeSlice;
var
  S: string;
begin
  { 门面 TextSlice 同语义；自赋值场景同权锁定。 }
  S := 'abcdef';
  CheckEqual('cde', TextSlice(S, 2, 3), 'facade basic');
  S := 'abcdef';
  S := TextSlice(S, 2, 3);
  CheckEqual('cde', S, 'facade self-assign');
end;

procedure TestCountChar;
var
  V: TStringView;
begin
  V := TStringView.Create(PAnsiChar('abracadabra'), 11);
  CheckEqual(Int64(5), Int64(V.CountChar('a')), 'count a');
  CheckEqual(Int64(0), Int64(V.CountChar('z')), 'count z');
end;

procedure TestLastIndexOf;
var
  V: TStringView;
begin
  V := TStringView.Create(PAnsiChar('hello world'), 11);
  CheckEqual(Int64(7), Int64(V.LastIndexOf('o')), 'last o');
  CheckEqual(Int64(-1), Int64(V.LastIndexOf('z')), 'z not found');
  CheckEqual(Int64(0), Int64(V.LastIndexOf('h')), 'h at 0');
  V := TStringView.Empty;
  CheckEqual(Int64(-1), Int64(V.LastIndexOf('x')), 'empty');
end;

procedure TestSplitFirst;
var
  V, L, R: TStringView;
begin
  V := TStringView.Create(PAnsiChar('key:value'), 9);
  Check(V.SplitFirst(':', L, R), 'split found');
  Check(L.Equals(TStringView.Create(PAnsiChar('key'), 3)), 'left=key');
  Check(R.Equals(TStringView.Create(PAnsiChar('value'), 5)), 'right=value');

  V := TStringView.Create(PAnsiChar('nosep'), 5);
  Check(not V.SplitFirst(':', L, R), 'split not found');
  Check(L.Equals(V), 'left=whole');
  Check(R.IsEmpty, 'right=empty');

  V := TStringView.Create(PAnsiChar(':start'), 6);
  Check(V.SplitFirst(':', L, R), 'split at start');
  Check(L.IsEmpty, 'left empty');
  Check(R.Equals(TStringView.Create(PAnsiChar('start'), 5)), 'right=start');
end;

procedure TestEqualsIgnoreCaseEmpty;
var
  A, B: TStringView;
begin
  A := TStringView.Empty;
  B := TStringView.Empty;
  Check(A.EqualsIgnoreCase(B), 'both empty');
  B := TStringView.Create(PAnsiChar('x'), 1);
  Check(not A.EqualsIgnoreCase(B), 'empty vs non-empty');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.view');
  T.Test('create and basic', @TestCreateAndBasic);
  T.Test('reject nil data with non-zero length', @TestRejectNilDataWithNonZeroLength);
  T.Test('from string', @TestFromStr);
  T.Test('slice', @TestSlice);
  T.Test('slice clamps overflowed length', @TestSliceClampsOverflowedLength);
  T.Test('left/right', @TestLeftRight);
  T.Test('trim', @TestTrim);
  T.Test('equals', @TestEquals);
  T.Test('equals ignore case', @TestEqualsIgnoreCase);
  T.Test('starts/ends with', @TestStartsEndsWith);
  T.Test('indexOf char', @TestIndexOf);
  T.Test('indexOf string', @TestIndexOfStr);
  T.Test('string index helpers', @TestStringIndexOfHelpers);
  T.Test('advance cursor', @TestAdvanceCursor);
  T.Test('toString', @TestToString);
  T.Test('slice to str', @TestSliceToStr);
  T.Test('text facade slice', @TestTextFacadeSlice);
  T.Test('countChar', @TestCountChar);
  T.Test('lastIndexOf', @TestLastIndexOf);
  T.Test('splitFirst', @TestSplitFirst);
  T.Test('equalsIgnoreCase empty', @TestEqualsIgnoreCaseEmpty);
  if not T.Run then Halt(1);
end.
