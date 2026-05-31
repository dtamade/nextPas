unit nextpas.core.args.base;
{**
 * @desc 命令行解析器基础类型定义。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

type
  TArgKind = (akFlag, akString, akInt, akStringList, akChoice);

  { EArgParseError - 参数解析错误 }
  EArgParseError = class(ENextPasError);

  { EArgHelp - --help 触发，Message 包含帮助文本 }
  EArgHelp = class(ENextPasError);

  { EArgVersion - --version 触发，Message 包含版本号 }
  EArgVersion = class(ENextPasError);

  TStringArray = array of string;

  TArgOption = record
    Name: string;
    Short: AnsiChar;
    Help: string;
    Kind: TArgKind;
    Required: Boolean;
    DefaultStr: string;
    DefaultInt: Int64;
    Choices: TStringArray;
    ValueStr: string;
    ValueInt: Int64;
    ValueBool: Boolean;
    ValueList: TStringArray;
    Present: Boolean;
  end;

  TArgPositionalSpec = record
    Name: string;
    Help: string;
    Required: Boolean;
  end;

implementation

end.
