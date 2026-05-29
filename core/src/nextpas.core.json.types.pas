unit nextpas.core.json.types;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

type
  TJsonNodeKind = (
    jnkNull,
    jnkBool,
    jnkInt,
    jnkReal,
    jnkString,
    jnkArray,
    jnkObject
  );

  TJsonNode = record
    Kind: TJsonNodeKind;
    Next: UInt32;
    case Byte of
      0: (BoolVal: Boolean);
      1: (IntVal: Int64);
      2: (RealVal: Double);
      3: (Str: TStringView);
      4: (Container: record
            FirstChild: UInt32;
            Count: UInt32;
          end);
  end;
  PJsonNode = ^TJsonNode;

  TJsonTokenKind = (
    jtkNone,
    jtkBeginObject,
    jtkEndObject,
    jtkBeginArray,
    jtkEndArray,
    jtkKey,
    jtkString,
    jtkInt,
    jtkFloat,
    jtkBool,
    jtkNull,
    jtkError
  );

  TJsonError = record
    Message: TStringView;
    Offset: SizeUInt;
  end;

const
  JSON_NODE_NONE = UInt32($FFFFFFFF);

implementation

end.
