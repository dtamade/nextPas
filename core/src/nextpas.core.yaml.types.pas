unit nextpas.core.yaml.types;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

type
  TYamlNodeKind = (
    ynkNull,
    ynkBool,
    ynkInt,
    ynkFloat,
    ynkString,
    ynkSequence,
    ynkMapping,
    ynkAlias
  );

  TYamlScalarStyle = (
    yssPlain,
    yssSingleQuoted,
    yssDoubleQuoted,
    yssLiteral,
    yssFolded
  );

  TYamlCollectionStyle = (
    ycsBlock,
    ycsFlow
  );

  TYamlNode = record
    Kind: TYamlNodeKind;
    Next: UInt32;
    Anchor: TStringView;
    case Byte of
      0: (BoolVal: Boolean);
      1: (IntVal: Int64);
      2: (RealVal: Double);
      3: (Str: TStringView);
      4: (Container: record
            FirstChild: UInt32;
            Count: UInt32;
          end);
      5: (AliasTarget: UInt32);
  end;
  PYamlNode = ^TYamlNode;

  TYamlTokenKind = (
    ytkStreamStart,
    ytkStreamEnd,
    ytkDocStart,
    ytkDocEnd,
    ytkBlockSeqStart,
    ytkBlockMapStart,
    ytkBlockEnd,
    ytkFlowSeqStart,
    ytkFlowSeqEnd,
    ytkFlowMapStart,
    ytkFlowMapEnd,
    ytkFlowEntry,
    ytkKey,
    ytkValue,
    ytkScalar,
    ytkAlias,
    ytkAnchor,
    ytkError
  );

  TYamlToken = record
    Kind: TYamlTokenKind;
    Value: TStringView;
    Style: TYamlScalarStyle;
    Line: UInt32;
    Col: UInt32;
    Offset: SizeUInt;
  end;

  TYamlError = record
    Message: TStringView;
    Line: UInt32;
    Col: UInt32;
    Offset: SizeUInt;
  end;

const
  YAML_NODE_NONE = UInt32($FFFFFFFF);

implementation

end.
