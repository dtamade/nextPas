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

function DeleteFileA(lpFileName: PAnsiChar): BOOL; stdcall; external 'kernel32.dll' name 'DeleteFileA';
function GetFullPathNameA(lpFileName: PAnsiChar; nBufferLength: DWORD; lpBuffer: PAnsiChar; lpFilePart: PPAnsiChar): DWORD; stdcall; external 'kernel32.dll' name 'GetFullPathNameA';

implementation

end.
