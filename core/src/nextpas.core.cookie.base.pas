unit nextpas.core.cookie.base;
{$I nextpas.core.settings.inc}

interface

type
  TCookieSameSite = (cssUnspecified, cssNone, cssLax, cssStrict);

  TCookie = record
    Name: string;
    Value: string;
  end;
  TCookieArray = array of TCookie;

  TSetCookie = record
    Name: string;
    Value: string;
    Domain: string;
    Path: string;
    MaxAge: Int64;
    HasMaxAge: Boolean;
    Secure: Boolean;
    HttpOnly: Boolean;
    SameSite: TCookieSameSite;
  end;

implementation

end.
