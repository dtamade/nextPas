unit nextpas.core.http.pool.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.pool.base,
  nextpas.core.net.intf;

type
  IHttpPool = interface
    ['{8F7C1A2B-3D4E-4F5A-9B6C-1234567890AB}']
    function Acquire(const AHost: string; const APort: UInt16): ITcpStream;
    procedure Release(const AHost: string; const APort: UInt16; const AConn: ITcpStream);
    procedure CloseIdle;
    function Count: Int32;
  end;

  IHttpPoolH2 = interface
    ['{8F7C1A2B-3D4E-4F5A-9B6C-1234567890AC}']
    procedure CloseIdle;
    function Count: Int32;
  end;

implementation

end.
