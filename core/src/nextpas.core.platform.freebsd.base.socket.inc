{ FreeBSD socket constants - values differ from Linux }
{ Ported from FPC rtl/darwin/unxconst.inc + packages/rtl-extra }

const
  SOCK_STREAM    = 1;
  SOCK_DGRAM     = 2;
  SOCK_RAW       = 3;
  SOCK_RDM       = 4;
  SOCK_SEQPACKET = 5;

  AF_UNSPEC     = 0;
  AF_UNIX       = 1;
  AF_LOCAL      = 1;
  AF_INET       = 2;
  AF_INET6      = 30;
  AF_ROUTE      = 17;
  AF_LINK       = 18;
  AF_SYSTEM     = 32;

  PF_UNSPEC     = AF_UNSPEC;
  PF_UNIX       = AF_UNIX;
  PF_LOCAL      = AF_LOCAL;
  PF_INET       = AF_INET;
  PF_INET6      = AF_INET6;

  SOL_SOCKET    = $FFFF;
  SOL_IP        = 0;
  SOL_TCP       = 6;
  SOL_UDP       = 17;
  SOL_IPV6      = 41;

  SO_DEBUG       = $0001;
  SO_ACCEPTCONN  = $0002;
  SO_REUSEADDR   = $0004;
  SO_KEEPALIVE   = $0008;
  SO_DONTROUTE   = $0010;
  SO_BROADCAST   = $0020;
  SO_USELOOPBACK = $0040;
  SO_LINGER      = $0080;
  SO_OOBINLINE   = $0100;
  SO_REUSEPORT   = $0200;
  SO_TIMESTAMP   = $0400;
  SO_SNDBUF      = $1001;
  SO_RCVBUF      = $1002;
  SO_SNDLOWAT    = $1003;
  SO_RCVLOWAT    = $1004;
  SO_SNDTIMEO    = $1005;
  SO_RCVTIMEO    = $1006;
  SO_ERROR       = $1007;
  SO_TYPE        = $1008;
  SO_NOSIGPIPE   = $1022;

  IPPROTO_IP   = 0;
  IPPROTO_ICMP = 1;
  IPPROTO_TCP  = 6;
  IPPROTO_UDP  = 17;
  IPPROTO_IPV6 = 41;
  IPPROTO_RAW  = 255;

  TCP_NODELAY    = $01;
  TCP_KEEPALIVE  = $10;

  IPV6_V6ONLY    = 27;

  MSG_OOB       = $1;
  MSG_PEEK      = $2;
  MSG_DONTROUTE = $4;
  MSG_EOR       = $8;
  MSG_TRUNC     = $10;
  MSG_CTRUNC    = $20;
  MSG_WAITALL   = $40;
  MSG_DONTWAIT  = $80;
  MSG_NOSIGNAL  = $20000;

  SHUT_RD   = 0;
  SHUT_WR   = 1;
  SHUT_RDWR = 2;

  INADDR_ANY       = UInt32(0);
  INADDR_BROADCAST = UInt32($FFFFFFFF);
  INADDR_LOOPBACK  = UInt32($7F000001);
  INADDR_NONE      = UInt32($FFFFFFFF);

  SOMAXCONN = 128;

  AI_PASSIVE     = $0001;
  AI_CANONNAME   = $0002;
  AI_NUMERICHOST = $0004;
  AI_NUMERICSERV = $1000;
  AI_V4MAPPED    = $0800;
  AI_ALL         = $0100;
  AI_ADDRCONFIG  = $0400;

  NI_MAXHOST     = 1025;
  NI_MAXSERV     = 32;
  NI_NUMERICHOST = $02;
  NI_NUMERICSERV = $08;
  NI_NOFQDN      = $01;
  NI_NAMEREQD    = $04;
  NI_DGRAM       = $10;

  SCM_RIGHTS = $01;
