{ Linux epoll types and constants - ported from FPC rtl/linux/linux.pp }

const
  EPOLLIN      = $01;
  EPOLLPRI     = $02;
  EPOLLOUT     = $04;
  EPOLLERR     = $08;
  EPOLLHUP     = $10;
  EPOLLRDNORM  = $40;
  EPOLLRDBAND  = $80;
  EPOLLWRNORM  = $100;
  EPOLLWRBAND  = $200;
  EPOLLMSG     = $400;
  EPOLLRDHUP   = $2000;
  EPOLLEXCLUSIVE = $10000000;
  EPOLLWAKEUP  = $20000000;
  EPOLLONESHOT = $40000000;
  EPOLLET      = cuint32($80000000);

  EPOLL_CTL_ADD = 1;
  EPOLL_CTL_DEL = 2;
  EPOLL_CTL_MOD = 3;

  EPOLL_CLOEXEC = $80000;

type
  epoll_data = record
    case Integer of
      0: (ptr: Pointer);
      1: (fd: cint);
      2: (u32: cuint32);
      3: (u64: cuint64);
  end;
  TEpoll_Data = epoll_data;
  pepoll_data = ^epoll_data;

  epoll_event = packed record
    events: cuint32;
    data: epoll_data;
  end;
  TEpoll_Event = epoll_event;
  pepoll_event = ^epoll_event;
