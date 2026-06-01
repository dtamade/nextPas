unit nextpas.core.hash.intf;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf;

type
  IHasher = interface(IWriter)
    ['{A7E3F1B2-C4D5-6789-ABCD-000048415348}']
    procedure Sum(out ADst; const ASize: SizeUInt);
    function SumBytes: TBytes;
    procedure Reset;
    function DigestSize: SizeUInt;
    function BlockSize: SizeUInt;
    function Clone: IHasher;
  end;

implementation

end.
