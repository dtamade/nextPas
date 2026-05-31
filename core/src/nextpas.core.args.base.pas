unit nextpas.core.args.base;
{**
 * @desc 命令行解析器公共类型定义（enum、异常、spec record）。
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

  TArgPositionalSpec = record
    Name: string;
    Help: string;
    Required: Boolean;
  end;

implementation

end.
