{ Windows Winsock2 types and constants - ported from FPC packages/rtl-extra/src/win/winsock2.pp }

const
  WSADESCRIPTION_LEN = 256;
  WSASYS_STATUS_LEN  = 128;
  FD_SETSIZE         = 64;

  INVALID_SOCKET = UINT_PTR(not UINT_PTR(0));
  SOCKET_ERROR   = -1;

  AF_UNSPEC     = 0;
  AF_UNIX       = 1;
  AF_INET       = 2;
  AF_IPX        = 6;
  AF_APPLETALK  = 16;
  AF_NETBIOS    = 17;
  AF_INET6      = 23;
  AF_IRDA       = 26;
  AF_BTH        = 32;

  PF_UNSPEC     = AF_UNSPEC;
  PF_INET       = AF_INET;
  PF_INET6      = AF_INET6;

  SOCK_STREAM    = 1;
  SOCK_DGRAM     = 2;
  SOCK_RAW       = 3;
  SOCK_RDM       = 4;
  SOCK_SEQPACKET = 5;

  SOL_SOCKET    = $FFFF;

  SO_DEBUG       = $0001;
  SO_ACCEPTCONN  = $0002;
  SO_REUSEADDR   = $0004;
  SO_KEEPALIVE   = $0008;
  SO_DONTROUTE   = $0010;
  SO_BROADCAST   = $0020;
  SO_USELOOPBACK = $0040;
  SO_LINGER      = $0080;
  SO_OOBINLINE   = $0100;
  SO_SNDBUF      = $1001;
  SO_RCVBUF      = $1002;
  SO_SNDLOWAT    = $1003;
  SO_RCVLOWAT    = $1004;
  SO_SNDTIMEO    = $1005;
  SO_RCVTIMEO    = $1006;
  SO_ERROR       = $1007;
  SO_TYPE        = $1008;
  SO_EXCLUSIVEADDRUSE = LongInt(not $0004);

  IPPROTO_IP   = 0;
  IPPROTO_ICMP = 1;
  IPPROTO_TCP  = 6;
  IPPROTO_UDP  = 17;
  IPPROTO_IPV6 = 41;
  IPPROTO_RAW  = 255;

  TCP_NODELAY  = $0001;

  IPV6_V6ONLY  = 27;

  MSG_OOB      = $1;
  MSG_PEEK     = $2;
  MSG_DONTROUTE = $4;
  MSG_WAITALL  = $8;

  SHUT_RD   = 0;
  SHUT_WR   = 1;
  SHUT_RDWR = 2;
  SD_RECEIVE = SHUT_RD;
  SD_SEND    = SHUT_WR;
  SD_BOTH    = SHUT_RDWR;

  INADDR_ANY       = DWORD(0);
  INADDR_LOOPBACK  = DWORD($7F000001);
  INADDR_BROADCAST = DWORD($FFFFFFFF);
  INADDR_NONE      = DWORD($FFFFFFFF);

  SOMAXCONN = $7FFFFFFF;

  AI_PASSIVE     = $0001;
  AI_CANONNAME   = $0002;
  AI_NUMERICHOST = $0004;
  AI_NUMERICSERV = $0008;
  AI_ADDRCONFIG  = $0400;
  AI_V4MAPPED    = $0800;
  AI_ALL         = $0100;

  NI_MAXHOST     = 1025;
  NI_MAXSERV     = 32;
  NI_NUMERICHOST = $01;
  NI_NUMERICSERV = $02;
  NI_NOFQDN      = $04;
  NI_NAMEREQD    = $08;
  NI_DGRAM       = $10;

  WSAEWOULDBLOCK     = 10035;
  WSAEINPROGRESS     = 10036;
  WSAEALREADY        = 10037;
  WSAENOTSOCK        = 10038;
  WSAEDESTADDRREQ    = 10039;
  WSAEMSGSIZE        = 10040;
  WSAEPROTOTYPE      = 10041;
  WSAENOPROTOOPT     = 10042;
  WSAEPROTONOSUPPORT = 10043;
  WSAESOCKTNOSUPPORT = 10044;
  WSAEOPNOTSUPP      = 10045;
  WSAEAFNOSUPPORT    = 10047;
  WSAEADDRINUSE      = 10048;
  WSAEADDRNOTAVAIL   = 10049;
  WSAENETDOWN        = 10050;
  WSAENETUNREACH     = 10051;
  WSAENETRESET       = 10052;
  WSAECONNABORTED    = 10053;
  WSAECONNRESET      = 10054;
  WSAENOBUFS         = 10055;
  WSAEISCONN         = 10056;
  WSAENOTCONN        = 10057;
  WSAESHUTDOWN       = 10058;
  WSAETIMEDOUT       = 10060;
  WSAECONNREFUSED    = 10061;
  WSAEHOSTDOWN       = 10064;
  WSAEHOSTUNREACH    = 10065;
  WSASYSNOTREADY     = 10091;
  WSAVERNOTSUPPORTED = 10092;
  WSANOTINITIALISED  = 10093;
  WSAEDISCON         = 10101;
  WSAHOST_NOT_FOUND  = 11001;
  WSATRY_AGAIN       = 11002;
  WSANO_RECOVERY     = 11003;
  WSANO_DATA         = 11004;
  WSA_IO_PENDING     = ERROR_IO_PENDING;

  IOC_IN   = DWORD($80000000);
  IOC_OUT  = DWORD($40000000);
  IOC_WS2  = DWORD($08000000);
  FIONBIO  = DWORD(IOC_IN or $04 shl 16 or 126);
  FIONREAD = DWORD(IOC_OUT or $04 shl 16 or 127);
  SIO_GET_EXTENSION_FUNCTION_POINTER = DWORD(IOC_IN or IOC_OUT or IOC_WS2 or 6);

type
  TSocket = UINT_PTR;

  TWSAData = record
    wVersion: WORD;
    wHighVersion: WORD;
{$IFDEF NEXTPAS_X86_64}
    iMaxSockets: WORD;
    iMaxUdpDg: WORD;
    lpVendorInfo: PAnsiChar;
    szDescription: array[0..WSADESCRIPTION_LEN] of AnsiChar;
    szSystemStatus: array[0..WSASYS_STATUS_LEN] of AnsiChar;
{$ELSE}
    szDescription: array[0..WSADESCRIPTION_LEN] of AnsiChar;
    szSystemStatus: array[0..WSASYS_STATUS_LEN] of AnsiChar;
    iMaxSockets: WORD;
    iMaxUdpDg: WORD;
    lpVendorInfo: PAnsiChar;
{$ENDIF}
  end;
  PWSAData = ^TWSAData;

  TWinSockFDSet = record
    fd_count: UINT;
    fd_array: array[0..FD_SETSIZE - 1] of TSocket;
  end;
  PWinSockFDSet = ^TWinSockFDSet;

  WSABUF = record
    len: DWORD;
    buf: PAnsiChar;
  end;
  LPWSABUF = ^WSABUF;

  WSAOVERLAPPED = OVERLAPPED;
  LPWSAOVERLAPPED = LPOVERLAPPED;

  LPWSAOVERLAPPED_COMPLETION_ROUTINE = procedure(
    dwError: DWORD;
    cbTransferred: DWORD;
    lpOverlapped: LPWSAOVERLAPPED;
    dwFlags: DWORD); stdcall;
