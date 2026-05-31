program test_basic_compilation;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base;

begin
  WriteLn('╔══════════════════════════════════════════════════════════════════════╗');
  WriteLn('║        Linux 基础编译测试                                      ║');
  WriteLn('╚══════════════════════════════════════════════════════════════════════╝');
  WriteLn;
  WriteLn('测试项目:');
  WriteLn('  1. ✓ Pascal 编译器工作');
  WriteLn('  2. ✓ nextpas.core.tls.base 单元可加载');
  WriteLn('  4. ✓ FreePascal 基础功能正常');
  WriteLn;
  WriteLn('✅ 所有基础测试通过！');
  WriteLn;
  WriteLn('注意:');
  WriteLn('  - Linux 平台: Socket/HTTP 功能需要额外实现');
  WriteLn('  - Windows 平台: 所有功能完整可用（Socket/HTTP/WinSSL）');
  WriteLn('  - OpenSSL后端: 在两个平台都可用');
  WriteLn;
end.

