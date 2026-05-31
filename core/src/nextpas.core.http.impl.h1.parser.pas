unit nextpas.core.http.impl.h1.parser;
{**
 * @desc HTTP/1.1 request parser interface.
 *       Implementation will be filled by llhttp translation via c2pas888.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TH1ParserEvent = (
    peMessageBegin,
    peUrl,
    peHeaderField,
    peHeaderValue,
    peHeadersComplete,
    peBody,
    peMessageComplete
  );

  TH1ParserCallback = procedure(const AParser: Pointer;
    const AData: PAnsiChar; const ALen: SizeUInt) of object;

  IH1Parser = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-500000000001}']
    function Execute(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeUInt;
    function GetMethod: THttpMethod;
    function GetStatusCode: THttpStatus;
    function GetHttpVersion: THttpVersion;
    function HasError: Boolean;
    function ErrorMessage: string;
    procedure Reset;
  end;

  { Will be implemented after llhttp translation }
  // function NewH1RequestParser(...): IH1Parser;
  // function NewH1ResponseParser(...): IH1Parser;

implementation

end.
