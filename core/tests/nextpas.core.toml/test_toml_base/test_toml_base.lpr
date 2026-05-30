program test_toml_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.toml.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestNodeKindEnum;
begin
  CheckEqual(Int64(0), Int64(Ord(tnkString)), 'tnkString = 0');
  CheckEqual(Int64(1), Int64(Ord(tnkInt)), 'tnkInt = 1');
  CheckEqual(Int64(2), Int64(Ord(tnkFloat)), 'tnkFloat = 2');
  CheckEqual(Int64(3), Int64(Ord(tnkBool)), 'tnkBool = 3');
  CheckEqual(Int64(4), Int64(Ord(tnkDateTime)), 'tnkDateTime = 4');
  CheckEqual(Int64(5), Int64(Ord(tnkArray)), 'tnkArray = 5');
  CheckEqual(Int64(6), Int64(Ord(tnkTable)), 'tnkTable = 6');
end;

procedure TestDateTimeKindEnum;
begin
  CheckEqual(Int64(0), Int64(Ord(tdkOffsetDateTime)), 'tdkOffsetDateTime = 0');
  CheckEqual(Int64(1), Int64(Ord(tdkLocalDateTime)), 'tdkLocalDateTime = 1');
  CheckEqual(Int64(2), Int64(Ord(tdkLocalDate)), 'tdkLocalDate = 2');
  CheckEqual(Int64(3), Int64(Ord(tdkLocalTime)), 'tdkLocalTime = 3');
end;

procedure TestDateTimeLocalDateTime;
var
  LDT: TTomlDateTime;
begin
  LDT := TomlDateTime(2024, 1, 15, 10, 30, 45, 123456789);
  CheckEqual(Int64(2024), Int64(LDT.Year), 'year');
  CheckEqual(Int64(1), Int64(LDT.Month), 'month');
  CheckEqual(Int64(15), Int64(LDT.Day), 'day');
  CheckEqual(Int64(10), Int64(LDT.Hour), 'hour');
  CheckEqual(Int64(30), Int64(LDT.Minute), 'minute');
  CheckEqual(Int64(45), Int64(LDT.Second), 'second');
  CheckEqual(Int64(123456789), Int64(LDT.Nanosecond), 'nanosecond');
  Check(LDT.HasDate, 'has date');
  Check(LDT.HasTime, 'has time');
  Check(not LDT.HasOffset, 'no offset');
  Check(LDT.Kind = tdkLocalDateTime, 'kind = local datetime');
end;

procedure TestDateTimeOffset;
var
  LDT: TTomlDateTime;
begin
  LDT := TomlDateTimeWithOffset(2024, 6, 15, 14, 0, 0, 0, 540);
  CheckEqual(Int64(2024), Int64(LDT.Year), 'year');
  CheckEqual(Int64(6), Int64(LDT.Month), 'month');
  CheckEqual(Int64(15), Int64(LDT.Day), 'day');
  CheckEqual(Int64(14), Int64(LDT.Hour), 'hour');
  CheckEqual(Int64(0), Int64(LDT.Minute), 'minute');
  Check(LDT.HasDate, 'has date');
  Check(LDT.HasTime, 'has time');
  Check(LDT.HasOffset, 'has offset');
  CheckEqual(Int64(540), Int64(LDT.OffsetMinutes), 'offset +09:00');
  Check(LDT.Kind = tdkOffsetDateTime, 'kind = offset datetime');
end;

procedure TestDateTimeOffsetNegative;
var
  LDT: TTomlDateTime;
begin
  LDT := TomlDateTimeWithOffset(2024, 12, 31, 23, 59, 59, 0, -300);
  Check(LDT.HasOffset, 'has offset');
  CheckEqual(Int64(-300), Int64(LDT.OffsetMinutes), 'offset -05:00');
  Check(LDT.Kind = tdkOffsetDateTime, 'kind = offset datetime');
end;

procedure TestDateTimeOffsetZulu;
var
  LDT: TTomlDateTime;
begin
  LDT := TomlDateTimeWithOffset(1979, 5, 27, 7, 32, 0, 0, 0);
  Check(LDT.HasOffset, 'has offset');
  CheckEqual(Int64(0), Int64(LDT.OffsetMinutes), 'offset Z = 0');
  Check(LDT.Kind = tdkOffsetDateTime, 'kind = offset datetime');
end;

procedure TestDateOnly;
var
  LDT: TTomlDateTime;
begin
  LDT := TomlDate(2024, 1, 15);
  CheckEqual(Int64(2024), Int64(LDT.Year), 'year');
  CheckEqual(Int64(1), Int64(LDT.Month), 'month');
  CheckEqual(Int64(15), Int64(LDT.Day), 'day');
  Check(LDT.HasDate, 'has date');
  Check(not LDT.HasTime, 'no time');
  Check(not LDT.HasOffset, 'no offset');
  Check(LDT.Kind = tdkLocalDate, 'kind = local date');
end;

procedure TestTimeOnly;
var
  LDT: TTomlDateTime;
begin
  LDT := TomlTime(10, 30, 0, 500000000);
  CheckEqual(Int64(10), Int64(LDT.Hour), 'hour');
  CheckEqual(Int64(30), Int64(LDT.Minute), 'minute');
  CheckEqual(Int64(0), Int64(LDT.Second), 'second');
  CheckEqual(Int64(500000000), Int64(LDT.Nanosecond), 'nanosecond');
  Check(not LDT.HasDate, 'no date');
  Check(LDT.HasTime, 'has time');
  Check(not LDT.HasOffset, 'no offset');
  Check(LDT.Kind = tdkLocalTime, 'kind = local time');
end;

procedure TestTimeMidnight;
var
  LDT: TTomlDateTime;
begin
  LDT := TomlTime(0, 0, 0, 0);
  CheckEqual(Int64(0), Int64(LDT.Hour), 'hour = 0');
  CheckEqual(Int64(0), Int64(LDT.Minute), 'minute = 0');
  CheckEqual(Int64(0), Int64(LDT.Second), 'second = 0');
  Check(LDT.HasTime, 'has time');
  Check(LDT.Kind = tdkLocalTime, 'kind = local time');
end;

procedure TestNodeSize;
begin
  Check(SizeOf(TTomlDateTime) <= 16, 'TTomlDateTime <= 16 bytes');
  Check(SizeOf(TTomlNode) <= 48, 'TTomlNode <= 48 bytes');
end;

procedure TestNodeNoneConstant;
begin
  CheckEqual(Int64($FFFFFFFF), Int64(TOML_NODE_NONE), 'TOML_NODE_NONE = $FFFFFFFF');
end;

procedure TestNodeLayout;
var
  LNode: TTomlNode;
begin
  FillChar(LNode, SizeOf(LNode), 0);
  LNode.Kind := tnkInt;
  LNode.Next := TOML_NODE_NONE;
  LNode.Key := TStringView.Create(PAnsiChar('test'), 4);
  LNode.IntVal := 42;
  CheckEqual(Int64(42), LNode.IntVal, 'int value');
  Check(LNode.Key.Len = 4, 'key len');
  Check(LNode.Next = TOML_NODE_NONE, 'next = none');
end;

procedure TestNodeBoolVariant;
var
  LNode: TTomlNode;
begin
  FillChar(LNode, SizeOf(LNode), 0);
  LNode.Kind := tnkBool;
  LNode.BoolVal := True;
  Check(LNode.BoolVal, 'bool true');
  LNode.BoolVal := False;
  Check(not LNode.BoolVal, 'bool false');
end;

procedure TestNodeFloatVariant;
var
  LNode: TTomlNode;
begin
  FillChar(LNode, SizeOf(LNode), 0);
  LNode.Kind := tnkFloat;
  LNode.FloatVal := 3.14;
  Check(Abs(LNode.FloatVal - 3.14) < 1e-10, 'float value');
end;

procedure TestNodeContainerVariant;
var
  LNode: TTomlNode;
begin
  FillChar(LNode, SizeOf(LNode), 0);
  LNode.Kind := tnkTable;
  LNode.Container.FirstChild := 1;
  LNode.Container.Count := 5;
  CheckEqual(Int64(1), Int64(LNode.Container.FirstChild), 'first child');
  CheckEqual(Int64(5), Int64(LNode.Container.Count), 'count');
end;

procedure TestNodeStringVariant;
var
  LNode: TTomlNode;
  LView: TStringView;
begin
  FillChar(LNode, SizeOf(LNode), 0);
  LNode.Kind := tnkString;
  LNode.Str := TStringView.Create(PAnsiChar('hello'), 5);
  LView := LNode.Str;
  Check(LView.Len = 5, 'str len');
  Check(LView.Equals(TStringView.Create(PAnsiChar('hello'), 5)), 'str value');
end;

procedure TestFlagsEncoding;
var
  LFlags: Byte;
begin
  LFlags := TOML_DT_FLAG_HAS_DATE or TOML_DT_FLAG_HAS_TIME or TOML_DT_FLAG_HAS_OFFSET
    or (Byte(Ord(tdkOffsetDateTime)) shl TOML_DT_KIND_SHIFT);
  Check((LFlags and TOML_DT_FLAG_HAS_DATE) <> 0, 'flag has date');
  Check((LFlags and TOML_DT_FLAG_HAS_TIME) <> 0, 'flag has time');
  Check((LFlags and TOML_DT_FLAG_HAS_OFFSET) <> 0, 'flag has offset');
  CheckEqual(Int64(Ord(tdkOffsetDateTime)),
    Int64((LFlags shr TOML_DT_KIND_SHIFT) and $03), 'kind from flags');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml.base');
  T.Run('node kind enum', @TestNodeKindEnum);
  T.Run('datetime kind enum', @TestDateTimeKindEnum);
  T.Run('datetime local', @TestDateTimeLocalDateTime);
  T.Run('datetime offset +', @TestDateTimeOffset);
  T.Run('datetime offset -', @TestDateTimeOffsetNegative);
  T.Run('datetime offset Z', @TestDateTimeOffsetZulu);
  T.Run('date only', @TestDateOnly);
  T.Run('time only', @TestTimeOnly);
  T.Run('time midnight', @TestTimeMidnight);
  T.Run('node size', @TestNodeSize);
  T.Run('node none constant', @TestNodeNoneConstant);
  T.Run('node layout', @TestNodeLayout);
  T.Run('node bool variant', @TestNodeBoolVariant);
  T.Run('node float variant', @TestNodeFloatVariant);
  T.Run('node container variant', @TestNodeContainerVariant);
  T.Run('node string variant', @TestNodeStringVariant);
  T.Run('flags encoding', @TestFlagsEncoding);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
