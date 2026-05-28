{ nextpas.core.platform.ctypes.inc - C type aliases compatible with FPC ctypes }

type
  cint8                  = ShortInt;           pcint8                 = ^cint8;
  cuint8                 = Byte;               pcuint8                = ^cuint8;
  cchar                  = cint8;              pcchar                 = ^cchar;
  cschar                 = cint8;              pcschar                = ^cschar;
  cuchar                 = cuint8;             pcuchar                = ^cuchar;

  cint16                 = SmallInt;           pcint16                = ^cint16;
  cuint16                = Word;               pcuint16               = ^cuint16;
  cshort                 = cint16;             pcshort                = ^cshort;
  csshort                = cint16;             pcsshort               = ^csshort;
  cushort                = cuint16;            pcushort               = ^cushort;

  cint32                 = LongInt;            pcint32                = ^cint32;
  cuint32                = LongWord;           pcuint32               = ^cuint32;

  cint64                 = Int64;              pcint64                = ^cint64;
  cuint64                = QWord;              pcuint64               = ^cuint64;
  clonglong              = cint64;             pclonglong             = ^clonglong;
  cslonglong             = cint64;             pcslonglong            = ^cslonglong;
  culonglong             = cuint64;            pculonglong            = ^culonglong;

  cbool                  = LongBool;           pcbool                 = ^cbool;

{$IF defined(NEXTPAS_X86_64) or defined(NEXTPAS_AARCH64)}
  cint                   = cint32;             pcint                  = ^cint;
  csint                  = cint32;             pcsint                 = ^csint;
  cuint                  = cuint32;            pcuint                 = ^cuint;
  clong                  = Int64;              pclong                 = ^clong;
  cslong                 = Int64;              pcslong                = ^cslong;
  culong                 = QWord;              pculong                = ^culong;
{$ELSE}
  cint                   = cint32;             pcint                  = ^cint;
  csint                  = cint32;             pcsint                 = ^csint;
  cuint                  = cuint32;            pcuint                 = ^cuint;
  clong                  = LongInt;            pclong                 = ^clong;
  cslong                 = LongInt;            pcslong                = ^cslong;
  culong                 = Cardinal;           pculong                = ^culong;
{$ENDIF}

  csigned                = cint;               pcsigned               = ^csigned;
  cunsigned              = cuint;              pcunsigned             = ^cunsigned;

  csize_t                = PtrUInt;            pcsize_t               = ^csize_t;

  cfloat                 = Single;             pcfloat                = ^cfloat;
  cdouble                = Double;             pcdouble               = ^cdouble;
