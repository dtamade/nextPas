unit nextpas.core.multipart.base;
{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

type
  TMultipartHeader = record
    Name: string;
    Value: string;
  end;
  TMultipartHeaderArray = array of TMultipartHeader;

  TMultipartPart = record
    Name: string;
    FileName: string;
    ContentType: string;
    Headers: TMultipartHeaderArray;
    Body: TBytes;
  end;
  TMultipartPartArray = array of TMultipartPart;

implementation

end.
