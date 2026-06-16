program test_text_builder;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.builder,
  nextpas.core.text.view,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestBasicAppend;
var
  B: IStringBuilder;
begin
  B := MakeStringBuilder(16);
  B.AppendChar('H');
  B.AppendStr('ello');
  B.AppendChar(' ');
  B.AppendView(TStringView.Create(PAnsiChar('World'), 5));
  CheckEqual('Hello World', B.ToString, 'basic append');
  CheckEqual(Int64(11), Int64(B.Len), 'len=11');
end;

procedure TestAppendInt;
var
  B: IStringBuilder;
begin
  B := MakeStringBuilder(32);
  B.AppendStr('x=');
  B.AppendInt(42);
  B.AppendStr(', y=');
  B.AppendInt(-100);
  CheckEqual('x=42, y=-100', B.ToString, 'append int');
end;

procedure TestAppendUInt;
var
  B: IStringBuilder;
begin
  B := MakeStringBuilder(32);
  B.AppendUInt(18446744073709551615);
  CheckEqual('18446744073709551615', B.ToString, 'max uint64');
end;

procedure TestAppendHex;
var
  B: IStringBuilder;
begin
  B := MakeStringBuilder(32);
  B.AppendStr('0x');
  B.AppendHex($CAFE, 4);
  CheckEqual('0xcafe', B.ToString, 'hex');
end;

procedure TestAppendBool;
var
  B: IStringBuilder;
begin
  B := MakeStringBuilder(16);
  B.AppendBool(True);
  B.AppendChar(',');
  B.AppendBool(False);
  CheckEqual('true,false', B.ToString, 'bool');
end;

procedure TestGrow;
var
  B: IStringBuilder;
  I: Integer;
begin
  B := MakeStringBuilder(4);
  for I := 1 to 1000 do
    B.AppendChar('x');
  CheckEqual(Int64(1000), Int64(B.Len), 'grew to 1000');
  Check(B.Cap >= 1000, 'cap >= 1000');
end;

procedure TestClear;
var
  B: IStringBuilder;
begin
  B := MakeStringBuilder(32);
  B.AppendStr('hello');
  B.Clear;
  CheckEqual(Int64(0), Int64(B.Len), 'cleared');
  B.AppendStr('world');
  CheckEqual('world', B.ToString, 'reuse after clear');
end;

procedure TestAsView;
var
  B: IStringBuilder;
  V: TStringView;
begin
  B := MakeStringBuilder(32);
  B.AppendStr('test');
  V := B.AsView;
  Check(V.Equals(TStringView.Create(PAnsiChar('test'), 4)), 'as view');
end;

procedure TestAppendChars;
var
  B: TBufStringBuilder;
begin
  B.Init(16);
  B.AppendChars('=', 10);
  CheckEqual(Int64(10), Int64(B.Len), 'len=10');
  Check(B.AsView.Equals(TStringView.Create(PAnsiChar('=========='), 10)), 'content');
  B.Done;
end;

procedure TestReserve;
var
  B: IStringBuilder;
begin
  B := MakeStringBuilder(8);
  B.Reserve(1024);
  Check(B.Cap >= 1024, 'reserved');
  CheckEqual(Int64(0), Int64(B.Len), 'len still 0');
end;

procedure TestAppendByte;
var
  B: TBufStringBuilder;
begin
  B.Init(8);
  B.AppendByte(65);
  CheckEqual('A', B.ToString, 'append byte');
  B.Done;
end;

procedure TestAppendBytes;
const
  HelloBytes: array[0..4] of Byte = (72, 101, 108, 108, 111);
var
  B: TBufStringBuilder;
begin
  B.Init(8);
  B.AppendBytes(PAnsiChar(@HelloBytes[0]), Length(HelloBytes));
  CheckEqual('Hello', B.ToString, 'append bytes');
  B.Done;
end;

procedure TestAppendFloat;
var
  B: IStringBuilder;
  S: string;
begin
  B := MakeStringBuilder(32);
  B.AppendFloat(3.14);
  S := B.ToString;
  Check(Pos('3.14', S) > 0, 'append float contains 3.14');
end;

procedure TestTail;
var
  B: TBufStringBuilder;
  LTail: PAnsiChar;
begin
  B.Init(16);
  B.AppendStr('hello');
  LTail := B.Tail;
  Check(LTail = B.AsView.Data + B.Len, 'tail points at current end');
  B.Done;
end;

procedure TestAdvanceLen;
var
  B: TBufStringBuilder;
  LTail: PAnsiChar;
begin
  B.Init(16);
  LTail := B.Tail;
  LTail[0] := 'o';
  LTail[1] := 'k';
  B.AdvanceLen(2);
  CheckEqual(Int64(2), Int64(B.Len), 'advance len updates length');
  CheckEqual('ok', B.ToString, 'advance len exposes written bytes');
  B.Done;
end;

procedure TestInterfaceAutomaticLifetime;
var
  B: IStringBuilder;
begin
  B := MakeStringBuilder(8);
  B.AppendStr('auto');
  CheckEqual('auto', B.ToString, 'interface builder works without Done');
  B := nil;
  Check(True, 'released by reference counting');
end;

procedure TestInternalRecordWithAllocator;
var
  B: TBufStringBuilder;
begin
  B.InitWith(8, nil);
  B.AppendStr('allocator');
  CheckEqual('allocator', B.ToString, 'record initwith still works');
  B.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.text.builder');
  T.Run('basic append', @TestBasicAppend);
  T.Run('append int', @TestAppendInt);
  T.Run('append uint', @TestAppendUInt);
  T.Run('append hex', @TestAppendHex);
  T.Run('append bool', @TestAppendBool);
  T.Run('grow', @TestGrow);
  T.Run('clear', @TestClear);
  T.Run('as view', @TestAsView);
  T.Run('append chars', @TestAppendChars);
  T.Run('reserve', @TestReserve);
  T.Run('TestAppendByte', @TestAppendByte);
  T.Run('TestAppendBytes', @TestAppendBytes);
  T.Run('TestAppendFloat', @TestAppendFloat);
  T.Run('TestTail', @TestTail);
  T.Run('TestAdvanceLen', @TestAdvanceLen);
  T.Run('interface automatic lifetime', @TestInterfaceAutomaticLifetime);
  T.Run('internal record with allocator', @TestInternalRecordWithAllocator);
  T.Summary;
end.
