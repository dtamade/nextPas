unit nextpas.core.git.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.git.base;

type
  // Optional authentication and certificate callbacks. Backends that cannot wire
  // them safely must report unsupported instead of silently ignoring handlers.
  TCredentialAcquireEvent = function(const Url, UserFromURL: string; AllowedTypes: Cardinal): Boolean of object;
  TCertificateCheckEvent = function(const Host: string; Valid: Boolean): Boolean of object;

  IGitCommit = interface;
  IGitReference = interface;
  IGitRemote = interface;

  IGitRepository = interface
    ['{B3A3D3E7-7A20-4D59-8A71-1B8A4E2B2B6E}']
    function Path: string;
    function WorkDir: string;
    function IsBare: Boolean;
    function IsEmpty: Boolean;

    function Head: IGitReference;
    function CurrentBranch: string;
    function ListBranches(Kind: TGitBranchKind = gbLocal): TStringArray;

    function CommitByHash(const Hash: string): IGitCommit;
    function HeadCommit: IGitCommit;

    function Remote(const Name: string = 'origin'): IGitRemote;
    function Fetch(const RemoteName: string = 'origin'): Boolean;
    function CheckoutBranch(const Branch: string): Boolean;
    // Optional: force checkout (overwrite working directory conflicts), default False
    function CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;


    // Simple list (compatible with old interface)
    function Status: TStringArray;
    // Detailed status and filtering
    function StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
    function IsClean: Boolean;
    function HasUncommittedChanges: Boolean;
  end;

  // Optional extended operations (implemented by the libgit2 adapter).
  // Keep these out of IGitRepository to preserve binary compatibility of the base interface.
  IGitRepositoryExt = interface
    ['{4E3F24A0-2F2B-4C62-8C9E-2C0D7E4A3A61}']
    function ListRemotes: TStringArray;
    function PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
  end;

  IGitCommit = interface
    ['{5F1B0C6E-9E4C-4E67-9B83-21C0B7E676B7}']
    function Message: string;
    function ShortMessage: string;
    function AuthorString: string;  // "Name <email> time"
    function CommitterString: string;
    function Time: TDateTime;
    function ParentCount: Integer;
    function OIDString: string;     // 40-byte hex
  end;

  IGitReference = interface
    ['{0A8D4D72-9F56-4B1E-9C9B-3F3A0B7B98E1}']
    function Name: string;
    function ShortName: string;
    function TargetOIDString: string;
    function IsBranch: Boolean;
    function IsRemote: Boolean;
    function IsTag: Boolean;
  end;

  IGitRemote = interface
    ['{BE8C1C63-6F18-4A1A-8C8C-EA0E5B8F2E7A}']
    function Name: string;
    function URL: string;
    function Fetch: Boolean;
  end;

  IGitManager = interface
    ['{DECE8C92-7891-4831-A0C2-7D1A2FA8B9C1}']
    function Initialize: Boolean;
    procedure Finalize;

    function OpenRepository(const APath: string): IGitRepository;
    function CloneRepository(const AURL, ALocalPath: string): IGitRepository;
    function InitRepository(const APath: string; ABare: Boolean = False): IGitRepository;
    function IsRepository(const APath: string): Boolean;
    function DiscoverRepository(const AStartPath: string): string;

    function GetGlobalConfig(const AKey: string): string;
    function SetGlobalConfig(const AKey, AValue: string): Boolean;
    function Version: string;

    procedure SetVerifySSL(AEnabled: Boolean);
    procedure SetCredentialAcquireHandler(AHandler: TCredentialAcquireEvent);
    procedure SetCertificateCheckHandler(AHandler: TCertificateCheckEvent);

    function Initialized: Boolean;
    function VerifySSL: Boolean;
  end;

implementation

end.
