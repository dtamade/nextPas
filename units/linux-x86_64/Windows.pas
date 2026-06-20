unit Windows;

{$mode delphi}{$H+}

interface

const
  INVALID_HANDLE_VALUE = Pointer(-1);
  FILE_ATTRIBUTE_DIRECTORY = $10;
  ERROR_SUCCESS = 0;
  CP_UTF8 = 65001;

type
  HANDLE = System.THandle;
  DWORD = LongWord;
  BOOL = LongBool;
  HMODULE = HANDLE;
  THandle = HANDLE;

implementation

end.
