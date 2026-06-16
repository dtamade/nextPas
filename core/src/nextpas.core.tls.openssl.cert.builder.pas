{
  nextpas.core.tls.openssl.cert.builder - OpenSSL 专用证书构建扩展接口命名空间

  说明:
    ICertificateEx / IPrivateKeyEx 暴露 OpenSSL 原生句柄（PX509 / PEVP_PKEY），
    因此它们本质上是 OpenSSL-only API。

  建议:
    - 通用代码优先使用 nextpas.core.tls.cert.builder 中的 ICertificate / IPrivateKey。
    - 需要 OpenSSL 句柄时，使用本单元中的 ICertificateEx / IPrivateKeyEx。

  版本: 1.0
  创建: 2025-12-31
}

unit nextpas.core.tls.openssl.cert.builder;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}
{$WARN 5066 off}  // Symbol is deprecated - self-referencing deprecated symbols

interface

uses
  nextpas.core.base,
  nextpas.core.tls.cert.builder;

type
  { OpenSSL-only handle access }
  ICertificateEx = nextpas.core.tls.cert.builder.ICertificateEx;
  IPrivateKeyEx = nextpas.core.tls.cert.builder.IPrivateKeyEx;

implementation

end.
