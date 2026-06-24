unit ctypes;

{$mode objfpc}{$H+}

interface

type
  cint = LongInt;
  cuint = LongWord;
  cshort = SmallInt;
  cushort = Word;
  clong = LongInt;
  culong = LongWord;
  cchar = Char;
  cschar = ShortInt;
  cuchar = Byte;
  cfloat = Single;
  cdouble = Double;
  cbool = Boolean;
  cint64 = Int64;
  cuint64 = UInt64;
  pchar = System.PChar;
  pcint = ^cint;
  pcuint = ^cuint;
  pcchar = ^cchar;
  pcuchar = ^cuchar;
  pvoid = Pointer;
  size_t = SizeUInt;
  ssize_t = SizeInt;
  csize_t = size_t;

implementation

end.
