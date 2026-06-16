{**
 * Unit: nextpas.core.tls.freepascal.context.material
 * Purpose: 纯 FreePascal 后端上下文材料访问扩展接口（可选）
 *
 * 说明：
 * - 仅供 FreePascal 后端内部握手实现读取已加载证书/私钥原始数据
 * - 不修改全局 ISSLContext 标准接口，保持跨后端兼容
 *}

unit nextpas.core.tls.freepascal.context.material;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.session;

type
  TFreePascalCipherSuiteList = array of Word;

  IFreePascalContextMaterial = interface
    ['{6B661525-EA6C-4D8F-8307-3AA51866FC71}']
    function HasCertificateMaterial: Boolean;
    function HasPrivateKeyMaterial: Boolean;
    function GetCertificateMaterial: TBytes;
    function GetPrivateKeyMaterial: TBytes;
  end;

  IFreePascalContextTrustStore = interface
    ['{54F5C1AC-2D4C-4A2C-A6E9-4B5953E4A7D1}']
    function BuildVerificationStore: ISSLCertificateStore;
  end;

  IFreePascalContextVerifyCallback = interface
    ['{5AB38D7E-D77B-4F68-9F06-8C9C237570C1}']
    function GetVerifyCallback: TSSLVerifyCallback;
  end;

  IFreePascalContextCipherSuites = interface
    ['{0B88F337-08F1-4C0E-A2B9-9878A77A122B}']
    function GetConfiguredCipherSuites13: TFreePascalCipherSuiteList;
    function GetConfiguredCipherSuites12: TFreePascalCipherSuiteList;
  end;

  IFreePascalContextPinValidation = interface
    ['{A8D3F2E1-7B4C-4E9A-B1C6-3D5F8A2E9C7B}']
    function ValidateCertificatePin(const ACertFingerprint: TBytes): Boolean;
  end;

  IFreePascalContextRevocationMaterial = interface
    ['{0ED2CC0C-5A69-4A77-AB60-894F17AA2C6D}']
    procedure ClearCRLMaterial;
    procedure AddCRLPEM(const APEM: string);
    procedure AddCRLFile(const AFileName: string);
    function BuildCRLStore: TStringArray;
  end;

  IFreePascalContextServerStaplingMaterial = interface(ISSLServerOCSPStaplingContext)
    ['{B60E1D7D-5C98-48D7-9AFB-0FA7DAD934B3}']
  end;

  IFreePascalContextEarlyDataReplayProviderInstaller = interface
    ['{7C3E6876-E80C-4A25-90C1-D9AF1C05803F}']
    function InstallReplayProviderBackedLedger(
      AProvider: IFreePascalEarlyDataReplayProvider
    ): Boolean;
  end;

  IFreePascalContextEarlyDataReplayInstaller = interface
    ['{53F77AA1-47D8-4AF6-A06A-7F55086FF5A7}']
    function InstallFileBackedReplayLedger(const AFileName: string): Boolean;
  end;

  IFreePascalContextEarlyDataReplayDirectoryInstaller = interface
    ['{CAFC624D-75D0-4C30-84B2-52336D3FA59A}']
    function InstallDirectoryBackedReplayLedger(
      const ADirectoryName: string
    ): Boolean;
  end;

implementation

uses
  nextpas.core.text.strings;


end.
