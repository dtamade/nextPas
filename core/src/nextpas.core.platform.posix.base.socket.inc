{ POSIX socket types - shared struct shapes across Linux/Darwin/FreeBSD }
{ Ported from FPC packages/rtl-extra/src/inc/socketsh.inc }

type
  sa_family_t = cushort;

  in_addr = packed record
    case Boolean of
      True: (s_addr: cuint32);
      False: (s_bytes: packed array[1..4] of Byte);
  end;
  pin_addr = ^in_addr;
  TInAddr = in_addr;
  PInAddr = pin_addr;

  in6_addr = packed record
    case Byte of
      0: (u6_addr8: array[0..15] of Byte);
      1: (u6_addr16: array[0..7] of Word);
      2: (u6_addr32: array[0..3] of Cardinal);
      3: (s6_addr: array[0..15] of Byte);
  end;
  pin6_addr = ^in6_addr;
  TIn6Addr = in6_addr;
  PIn6Addr = pin6_addr;

  sockaddr = packed record
    sa_family: sa_family_t;
    sa_data: packed array[0..13] of cuint8;
  end;
  TSockAddr = sockaddr;

  sockaddr_in = packed record
    sin_family: sa_family_t;
    sin_port: cushort;
    sin_addr: in_addr;
    xpad: array[0..7] of AnsiChar;
  end;
  psockaddr_in = ^sockaddr_in;
  TInetSockAddr = sockaddr_in;
  PInetSockAddr = psockaddr_in;

  sockaddr_in6 = packed record
    sin6_family: sa_family_t;
    sin6_port: cuint16;
    sin6_flowinfo: cuint32;
    sin6_addr: in6_addr;
    sin6_scope_id: cuint32;
  end;
  psockaddr_in6 = ^sockaddr_in6;
  TInetSockAddr6 = sockaddr_in6;
  PInetSockAddr6 = psockaddr_in6;

  sockaddr_un = packed record
    sun_family: sa_family_t;
    sun_path: array[0..107] of AnsiChar;
  end;
  psockaddr_un = ^sockaddr_un;
  TSockAddrUn = sockaddr_un;

  sockaddr_storage = packed record
    ss_family: sa_family_t;
    __ss_padding: array[0..117] of cuint8;
    __ss_align: cuint64;
  end;
  psockaddr_storage = ^sockaddr_storage;

  linger = packed record
    l_onoff: cint;
    l_linger: cint;
  end;
  plinger = ^linger;
  TLinger = linger;

  msghdr = record
    msg_name: Pointer;
    msg_namelen: socklen_t;
    msg_iov: piovec;
    msg_iovlen: size_t;
    msg_control: Pointer;
    msg_controllen: size_t;
    msg_flags: cint;
  end;
  pmsghdr = ^msghdr;
  TMsgHdr = msghdr;

  cmsghdr = record
    cmsg_len: size_t;
    cmsg_level: cint;
    cmsg_type: cint;
  end;
  pcmsghdr = ^cmsghdr;
  TCMsgHdr = cmsghdr;

  ucred = record
    pid: cuint32;
    uid: cuint32;
    gid: cuint32;
  end;
  pucred = ^ucred;

  PAddrInfo = ^addrinfo;
  PPAddrInfo = ^PAddrInfo;
  addrinfo = record
    ai_flags: cint;
    ai_family: cint;
    ai_socktype: cint;
    ai_protocol: cint;
    ai_addrlen: socklen_t;
    ai_addr: ^sockaddr;
    ai_canonname: PAnsiChar;
    ai_next: PAddrInfo;
  end;
  TAddrInfo = addrinfo;
