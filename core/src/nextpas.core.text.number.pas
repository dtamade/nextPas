unit nextpas.core.text.number;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

function IntToBuffer(const AValue: Int64; const ADst: PAnsiChar): Int32;
function UIntToBuffer(const AValue: UInt64; const ADst: PAnsiChar): Int32;
function IntToHexBuffer(const AValue: UInt64; const ADst: PAnsiChar;
  const AMinDigits: Int32 = 1): Int32;
function ParseInt64(const AData: PAnsiChar; const ALen: SizeUInt;
  out AValue: Int64): Boolean;
function ParseUInt64(const AData: PAnsiChar; const ALen: SizeUInt;
  out AValue: UInt64): Boolean;
function FloatToBuffer(const AValue: Double; const ADst: PAnsiChar): Int32;
function FloatToJsonBuffer(const AValue: Double; const ADst: PAnsiChar): Int32;
function ParseDouble(const AData: PAnsiChar; const ALen: SizeUInt;
  out AValue: Double): Boolean;
function ViewToInt64(const AView: TStringView; out AValue: Int64): Boolean; inline;
function ViewToUInt64(const AView: TStringView; out AValue: UInt64): Boolean; inline;
function ViewToDouble(const AView: TStringView; out AValue: Double): Boolean; inline;

implementation

uses
  nextpas.core.text.char;

const
  DIGIT_PAIRS: array[0..99] of array[0..1] of AnsiChar = (
    '00','01','02','03','04','05','06','07','08','09',
    '10','11','12','13','14','15','16','17','18','19',
    '20','21','22','23','24','25','26','27','28','29',
    '30','31','32','33','34','35','36','37','38','39',
    '40','41','42','43','44','45','46','47','48','49',
    '50','51','52','53','54','55','56','57','58','59',
    '60','61','62','63','64','65','66','67','68','69',
    '70','71','72','73','74','75','76','77','78','79',
    '80','81','82','83','84','85','86','87','88','89',
    '90','91','92','93','94','95','96','97','98','99'
  );

  HEX_CHARS: array[0..15] of AnsiChar = '0123456789abcdef';
