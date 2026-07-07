{**
 * @desc String types for the nextPas system kernel.
 *
 * Defines ShortString, AnsiString, WideString, UnicodeString.
 * Depends on base.inc for SizeInt and other basic types.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, types are re-exported from FPC System via fpc.inc.
 *}

type
  { String types }
  ShortString = System.ShortString;
  AnsiString = System.AnsiString;
  WideString = System.WideString;
  UnicodeString = System.UnicodeString;

  { Character types }
  Char = System.Char;
  AnsiChar = System.AnsiChar;
  WideChar = System.WideChar;

  { String pointer types }
  PAnsiChar = System.PAnsiChar;
  PWideChar = System.PWideChar;
  PUnicodeChar = System.PUnicodeChar;
  PPAnsiChar = System.PPAnsiChar;
  PPWideChar = System.PPWideChar;
