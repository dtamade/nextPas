program bench_sysutils_facade;
{**
 * @desc Facade-hop cost probe: FPC RTL SysUtils vs nextpas.core.system.sysutils
 *       facade vs direct owner-module implementations.
 *
 *       The facade column should track the direct column closely once facade
 *       forwarders carry inline (design-conventions: facades aggregate public
 *       API via type aliases and inline forwarding functions). The RTL column
 *       is the parity baseline required by the benchmark conventions.
 *}
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses
  nextpas.core.bench, nextpas.core.bench.intf,
  SysUtils,
  nextpas.core.base,
  nextpas.core.path,
  nextpas.core.text.conv,
  nextpas.core.system.sysutils;

var
  GSink: UInt64;

{ IntToStr, small magnitude }

procedure BIntToStrTinyRtl(const ACtx: IBenchContext);
var LS: string;
begin LS := SysUtils.IntToStr(-42); GSink := GSink xor UInt64(Length(LS)); end;

procedure BIntToStrTinyFacade(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.system.sysutils.IntToStr(-42); GSink := GSink xor UInt64(Length(LS)); end;

procedure BIntToStrTinyDirect(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.text.conv.IntToStr(-42); GSink := GSink xor UInt64(Length(LS)); end;

{ IntToStr, full Int64 range }

procedure BIntToStrBigRtl(const ACtx: IBenchContext);
var LS: string;
begin LS := SysUtils.IntToStr(-1234567890123456789); GSink := GSink xor UInt64(Length(LS)); end;

procedure BIntToStrBigFacade(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.system.sysutils.IntToStr(-1234567890123456789); GSink := GSink xor UInt64(Length(LS)); end;

procedure BIntToStrBigDirect(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.text.conv.IntToStr(-1234567890123456789); GSink := GSink xor UInt64(Length(LS)); end;

{ StrToInt }

procedure BStrToIntRtl(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(SysUtils.StrToInt('-123456789')); end;

procedure BStrToIntFacade(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(nextpas.core.system.sysutils.StrToInt('-123456789')); end;

procedure BStrToIntDirect(const ACtx: IBenchContext);
begin GSink := GSink xor UInt64(nextpas.core.text.conv.StrToInt('-123456789')); end;

{ FloatToStr }

procedure BFloatToStrRtl(const ACtx: IBenchContext);
var LS: string;
begin LS := SysUtils.FloatToStr(1234567.89012345); GSink := GSink xor UInt64(Length(LS)); end;

procedure BFloatToStrFacade(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.system.sysutils.FloatToStr(1234567.89012345); GSink := GSink xor UInt64(Length(LS)); end;

procedure BFloatToStrDirect(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.text.conv.FloatToStr(1234567.89012345); GSink := GSink xor UInt64(Length(LS)); end;

{ Trim }

procedure BTrimRtl(const ACtx: IBenchContext);
var LS: string;
begin LS := SysUtils.Trim('  payload  '); GSink := GSink xor UInt64(Length(LS)); end;

procedure BTrimFacade(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.system.sysutils.Trim('  payload  '); GSink := GSink xor UInt64(Length(LS)); end;

procedure BTrimDirect(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.text.conv.Trim('  payload  '); GSink := GSink xor UInt64(Length(LS)); end;

{ UpperCase }

procedure BUpperRtl(const ACtx: IBenchContext);
var LS: string;
begin LS := SysUtils.UpperCase('hotpath'); GSink := GSink xor UInt64(Length(LS)); end;

procedure BUpperFacade(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.system.sysutils.UpperCase('hotpath'); GSink := GSink xor UInt64(Length(LS)); end;

procedure BUpperDirect(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.text.conv.UpperCase('hotpath'); GSink := GSink xor UInt64(Length(LS)); end;

{ SameText }

procedure BSameTextRtl(const ACtx: IBenchContext);
begin if SysUtils.SameText('Header', 'header') then GSink := GSink xor 1; end;

procedure BSameTextFacade(const ACtx: IBenchContext);
begin if nextpas.core.system.sysutils.SameText('Header', 'header') then GSink := GSink xor 1; end;

procedure BSameTextDirect(const ACtx: IBenchContext);
begin if nextpas.core.text.conv.SameText('Header', 'header') then GSink := GSink xor 1; end;

{ ExtractFileExt }

procedure BFileExtRtl(const ACtx: IBenchContext);
var LS: string;
begin LS := SysUtils.ExtractFileExt('/srv/assets/photo.tar.gz'); GSink := GSink xor UInt64(Length(LS)); end;

procedure BFileExtFacade(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.system.sysutils.ExtractFileExt('/srv/assets/photo.tar.gz'); GSink := GSink xor UInt64(Length(LS)); end;

procedure BFileExtDirect(const ACtx: IBenchContext);
var LS: string;
begin LS := nextpas.core.path.ExtractFileExt('/srv/assets/photo.tar.gz'); GSink := GSink xor UInt64(Length(LS)); end;

var
  LSuite: IBenchSuite;
begin
  GSink := 0;
  LSuite := TBenchSuite.Create('sysutils-facade');
  LSuite.Add('IntToStr.tiny/rtl', @BIntToStrTinyRtl)
    .Add('IntToStr.tiny/facade', @BIntToStrTinyFacade)
    .Add('IntToStr.tiny/direct', @BIntToStrTinyDirect)
    .Add('IntToStr.big/rtl', @BIntToStrBigRtl)
    .Add('IntToStr.big/facade', @BIntToStrBigFacade)
    .Add('IntToStr.big/direct', @BIntToStrBigDirect)
    .Add('StrToInt/rtl', @BStrToIntRtl)
    .Add('StrToInt/facade', @BStrToIntFacade)
    .Add('StrToInt/direct', @BStrToIntDirect)
    .Add('FloatToStr/rtl', @BFloatToStrRtl)
    .Add('FloatToStr/facade', @BFloatToStrFacade)
    .Add('FloatToStr/direct', @BFloatToStrDirect)
    .Add('Trim/rtl', @BTrimRtl)
    .Add('Trim/facade', @BTrimFacade)
    .Add('Trim/direct', @BTrimDirect)
    .Add('UpperCase/rtl', @BUpperRtl)
    .Add('UpperCase/facade', @BUpperFacade)
    .Add('UpperCase/direct', @BUpperDirect)
    .Add('SameText/rtl', @BSameTextRtl)
    .Add('SameText/facade', @BSameTextFacade)
    .Add('SameText/direct', @BSameTextDirect)
    .Add('ExtractFileExt/rtl', @BFileExtRtl)
    .Add('ExtractFileExt/facade', @BFileExtFacade)
    .Add('ExtractFileExt/direct', @BFileExtDirect);
  WriteLn(LSuite.Run.PrintToConsole);
end.
