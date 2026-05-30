unit nextpas.core.toml.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

type
  TTomlNodeKind = (
    tnkString,
    tnkInt,
    tnkFloat,
    tnkBool,
    tnkDateTime,
    tnkArray,
    tnkTable
  );

  TTomlDateTimeKind = (
    tdkOffsetDateTime,
    tdkLocalDateTime,
    tdkLocalDate,
    tdkLocalTime
  );

  { Packed 14-byte datetime with Flags byte encoding HasDate/HasTime/HasOffset/Kind. }
  TTomlDateTime = packed record
    Year: UInt16;
    Month: Byte;
    Day: Byte;
    Hour: Byte;
    Minute: Byte;
    Second: Byte;
    Flags: Byte;
    Nanosecond: UInt32;
    OffsetMinutes: Int16;
    function HasDate: Boolean; inline;
    function HasTime: Boolean; inline;
    function HasOffset: Boolean; inline;
    function Kind: TTomlDateTimeKind; inline;
  end;

  TTomlNode = record
    Kind: TTomlNodeKind;
    Flags: Byte;
    Next: UInt32;
    Key: TStringView;
    case Byte of
      0: (BoolVal: Boolean);
      1: (IntVal: Int64);
      2: (FloatVal: Double);
      3: (Str: TStringView);
      4: (DT: TTomlDateTime);
      5: (Container: record
            FirstChild: UInt32;
            LastChild: UInt32;
            Count: UInt32;
          end);
  end;
  PTomlNode = ^TTomlNode;

  TTomlError = record
    Message: TStringView;
    Line: UInt32;
    Col: UInt32;
    Offset: SizeUInt;
  end;

const
  TOML_NODE_NONE = UInt32($FFFFFFFF);

  TOML_DT_FLAG_HAS_DATE   = Byte(1);
  TOML_DT_FLAG_HAS_TIME   = Byte(2);
  TOML_DT_FLAG_HAS_OFFSET = Byte(4);
  TOML_DT_KIND_SHIFT      = 4;

  TOML_NODE_FLAG_INLINE   = Byte(1);
  TOML_NODE_FLAG_EXPLICIT = Byte(2);

function TomlDateTime(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32): TTomlDateTime;
function TomlDateTimeWithOffset(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32; AOffsetMinutes: Int16): TTomlDateTime;
function TomlDate(AYear: UInt16; AMonth, ADay: Byte): TTomlDateTime;
function TomlTime(AHour, AMinute, ASecond: Byte; ANanosecond: UInt32): TTomlDateTime;

implementation

function TTomlDateTime.HasDate: Boolean;
begin
  Result := (Flags and TOML_DT_FLAG_HAS_DATE) <> 0;
end;

function TTomlDateTime.HasTime: Boolean;
begin
  Result := (Flags and TOML_DT_FLAG_HAS_TIME) <> 0;
end;

function TTomlDateTime.HasOffset: Boolean;
begin
  Result := (Flags and TOML_DT_FLAG_HAS_OFFSET) <> 0;
end;

function TTomlDateTime.Kind: TTomlDateTimeKind;
begin
  Result := TTomlDateTimeKind((Flags shr TOML_DT_KIND_SHIFT) and $03);
end;

function TomlDateTime(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32): TTomlDateTime;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Year := AYear;
  Result.Month := AMonth;
  Result.Day := ADay;
  Result.Hour := AHour;
  Result.Minute := AMinute;
  Result.Second := ASecond;
  Result.Nanosecond := ANanosecond;
  Result.Flags := TOML_DT_FLAG_HAS_DATE or TOML_DT_FLAG_HAS_TIME
    or (Byte(Ord(tdkLocalDateTime)) shl TOML_DT_KIND_SHIFT);
  Result.OffsetMinutes := 0;
end;

function TomlDateTimeWithOffset(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32; AOffsetMinutes: Int16): TTomlDateTime;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Year := AYear;
  Result.Month := AMonth;
  Result.Day := ADay;
  Result.Hour := AHour;
  Result.Minute := AMinute;
  Result.Second := ASecond;
  Result.Nanosecond := ANanosecond;
  Result.OffsetMinutes := AOffsetMinutes;
  Result.Flags := TOML_DT_FLAG_HAS_DATE or TOML_DT_FLAG_HAS_TIME or TOML_DT_FLAG_HAS_OFFSET
    or (Byte(Ord(tdkOffsetDateTime)) shl TOML_DT_KIND_SHIFT);
end;

function TomlDate(AYear: UInt16; AMonth, ADay: Byte): TTomlDateTime;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Year := AYear;
  Result.Month := AMonth;
  Result.Day := ADay;
  Result.Flags := TOML_DT_FLAG_HAS_DATE
    or (Byte(Ord(tdkLocalDate)) shl TOML_DT_KIND_SHIFT);
end;

function TomlTime(AHour, AMinute, ASecond: Byte; ANanosecond: UInt32): TTomlDateTime;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Hour := AHour;
  Result.Minute := AMinute;
  Result.Second := ASecond;
  Result.Nanosecond := ANanosecond;
  Result.Flags := TOML_DT_FLAG_HAS_TIME
    or (Byte(Ord(tdkLocalTime)) shl TOML_DT_KIND_SHIFT);
end;

end.
