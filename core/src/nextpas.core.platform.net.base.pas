unit nextpas.core.platform.net.base;

{$I nextpas.core.settings.inc}

interface

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base;
{$ELSE}
uses
  nextpas.core.platform.posix.base;
{$ENDIF}

type
  TPlatformSocket = record
  {$IFDEF NEXTPAS_WINDOWS}
    Value: TSocket;
  {$ELSE}
    Value: Int32;
  {$ENDIF}
  end;

  TPlatformAddressFamily = (afInet4, afInet6, afUnix);
  TPlatformSocketType = (stStream, stDgram);
  TPlatformProtocol = (spTCP, spUDP, spDefault);
  TPlatformShutdownHow = (shRead, shWrite, shBoth);

  TPlatformSockAddr = record
    Storage: sockaddr_storage;
    Len: Int32;
  end;

const
  PLATFORM_INVALID_SOCKET: TPlatformSocket = (
  {$IFDEF NEXTPAS_WINDOWS}
    Value: TSocket(not PtrUInt(0))
  {$ELSE}
    Value: -1
  {$ENDIF}
  );

implementation

end.
