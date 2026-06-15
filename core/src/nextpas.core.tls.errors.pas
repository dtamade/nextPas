{
  nextpas.core.tls.errors - SSL Error Handling Helpers
  
  Purpose:
    Provides helper functions for consistent error raising across the fafafa.ssl library.
    Centralizes error message formatting and error code selection.
    
  VersionStep: Phase 4 - Professional Error Handling Refactor
}

unit nextpas.core.tls.errors;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.tls.base;

// ============================================================================
// General Error Raising Functions
// ============================================================================

{ Raise SSL exception with specified error code }
procedure RaiseSSLError(const AMessage: string; ACode: TSSLErrorCode); inline;

{ Raise SSL exception with formatted message }
procedure RaiseSSLErrorFmt(const ATemplate: string; const AArgs: array of const; 
  ACode: TSSLErrorCode);

// ============================================================================
// Common Error Helpers
// ============================================================================

{ Raise function not available error }
procedure RaiseFunctionNotAvailable(const AFuncName: string);

{ Raise invalid parameter error }
procedure RaiseInvalidParameter(const AParamName: string);

{ Raise invalid data error  }
procedure RaiseInvalidData(const AContext: string);

{ Raise not initialized error }
procedure RaiseNotInitialized(const AComponent: string);

{ Raise memory allocation error }
procedure RaiseMemoryError(const AOperation: string);

{ Raise unsupported feature error }
procedure RaiseUnsupported(const AFeature: string);

// ============================================================================
// Cryptography Error Helpers
// ============================================================================

{ Raise encryption error }
procedure RaiseEncryptionError(const ADetails: string);

{ Raise decryption error }
procedure RaiseDecryptionError(const ADetails: string);

{ Raise key derivation error }
procedure RaiseKeyDerivationError(const ADetails: string);

// ============================================================================
// Certificate Error Helpers
// ============================================================================

{ Raise certificate error }
procedure RaiseCertificateError(const ADetails: string);

{ Raise certificate expired error }
procedure RaiseCertificateExpired(const ACertName: string);

{ Raise certificate verification error }
procedure RaiseCertificateVerifyError(const ADetails: string);

// ============================================================================
// I/O Error Helpers
// ============================================================================

{ Raise load error }
procedure RaiseLoadError(const AFileName: string);

{ Raise parse error }
procedure RaiseParseError(const AContext: string);

{ Raise connection error }
procedure RaiseConnectionError(const ADetails: string);

{ Raise invalid format error }
procedure RaiseInvalidFormat(const AContext: string);

// ============================================================================
// Extended Error Helpers (Phase 2.1 - Coverage Enhancement)
// ============================================================================

{ Raise initialization error }
procedure RaiseInitializationError(const AComponent, ADetails: string);

{ Raise configuration error }
procedure RaiseConfigurationError(const AOption, AReason: string);

{ Raise resource exhausted error }
procedure RaiseResourceExhausted(const AResource: string);

{ Raise buffer error }
procedure RaiseBufferError(const AOperation, AReason: string);

// ============================================================================
// Utility Functions
// ============================================================================

{ Format error message template with arguments }
function FormatErrorMessage(const ATemplate: string; const AArgs: array of const): string;

{ Get error message in specified language }
function GetErrorMessage(ACode: TSSLErrorCode; const ALang: string = 'zh'): string;

implementation

uses
  nextpas.core.tls.exceptions;  // Phase 3.3 P0 - 统一异常定义（修复重复定义问题）

// ============================================================================
// General Error Raising Functions
// ============================================================================

procedure RaiseSSLError(const AMessage: string; ACode: TSSLErrorCode);
begin
  raise ESSLException.Create(AMessage, ACode);
end;

procedure RaiseSSLErrorFmt(const ATemplate: string; const AArgs: array of const;
  ACode: TSSLErrorCode);
begin
  raise ESSLException.Create(Format(ATemplate, AArgs), ACode);
end;

// ============================================================================
// Common Error Helpers
// ============================================================================

procedure RaiseFunctionNotAvailable(const AFuncName: string);
begin
  raise ESSLException.Create(
    Format('%s is not available. Ensure OpenSSL library is properly loaded ' +
      'and the function exists in your OpenSSL version.', [AFuncName]),
    sslErrFunctionNotFound
  );
end;

procedure RaiseInvalidParameter(const AParamName: string);
begin
  raise ESSLInvalidArgument.Create(
    Format('Invalid parameter "%s": value is nil, empty, or out of valid range', [AParamName]),
    sslErrInvalidParam
  );
end;

procedure RaiseInvalidData(const AContext: string);
begin
  raise ESSLInvalidArgument.Create(
    Format('Invalid or corrupted data in %s. Check data format and integrity.', [AContext]),
    sslErrInvalidData
  );
end;

procedure RaiseNotInitialized(const AComponent: string);
begin
  raise ESSLInitializationException.Create(
    Format('%s not initialized. Call the appropriate initialization function first.', [AComponent]),
    sslErrNotInitialized
  );
end;

procedure RaiseMemoryError(const AOperation: string);
begin
  raise ESSLOutOfMemoryException.Create(
    Format('Memory allocation failed during %s. System may be low on memory.', [AOperation]),
    sslErrMemory
  );
end;

procedure RaiseUnsupported(const AFeature: string);
begin
  raise ESSLConfigurationException.Create(
    Format('%s is not supported by the current OpenSSL build or version.', [AFeature]),
    sslErrUnsupported
  );
end;

// ============================================================================
// Cryptography Error Helpers
// ============================================================================

procedure RaiseEncryptionError(const ADetails: string);
begin
  raise ESSLEncryptionException.Create(
    Format('Encryption failed: %s', [ADetails]),
    sslErrEncryptionFailed
  );
end;

procedure RaiseDecryptionError(const ADetails: string);
begin
  raise ESSLDecryptionException.Create(
    Format('Decryption failed: %s', [ADetails]),
    sslErrDecryptionFailed
  );
end;

procedure RaiseKeyDerivationError(const ADetails: string);
begin
  raise ESSLKeyDerivationException.Create(
    Format('Key derivation failed: %s', [ADetails]),
    sslErrKeyDerivationFailed
  );
end;

// ============================================================================
// Certificate Error Helpers
// ============================================================================

procedure RaiseCertificateError(const ADetails: string);
begin
  raise ESSLCertificateException.Create(
    Format('Certificate error: %s', [ADetails]),
    sslErrCertificate
  );
end;

procedure RaiseCertificateExpired(const ACertName: string);
begin
  raise ESSLCertificateExpiredException.Create(
    Format('Certificate expired: %s', [ACertName]),
    sslErrCertificateExpired
  );
end;

procedure RaiseCertificateVerifyError(const ADetails: string);
begin
  raise ESSLCertificateVerificationException.Create(
    Format('Certificate verification failed: %s', [ADetails]),
    sslErrVerificationFailed
  );
end;

// ============================================================================
// I/O Error Helpers
// ============================================================================

procedure RaiseLoadError(const AFileName: string);
begin
  raise ESSLFileNotFoundException.Create(
    Format('Failed to load "%s". Verify the file exists and is readable.', [AFileName]),
    sslErrLoadFailed
  );
end;

procedure RaiseParseError(const AContext: string);
begin
  raise ESSLCertificateParseException.Create(
    Format('Failed to parse %s. Ensure the data is in the correct format (PEM or DER).', [AContext]),
    sslErrParseFailed
  );
end;

procedure RaiseConnectionError(const ADetails: string);
begin
  raise ESSLConnectionException.Create(
    Format('SSL/TLS connection error: %s. Check network connectivity and server availability.', [ADetails]),
    sslErrConnection
  );
end;

procedure RaiseInvalidFormat(const AContext: string);
begin
  raise ESSLInvalidArgument.Create(
    Format('Invalid format in %s. Expected PEM-encoded or DER-encoded data.', [AContext]),
    sslErrInvalidFormat
  );
end;

// ============================================================================
// Extended Error Helpers Implementation (Phase 2.1)
// ============================================================================

procedure RaiseInitializationError(const AComponent, ADetails: string);
begin
  raise ESSLInitializationException.Create(
    Format('%s initialization failed: %s', [AComponent, ADetails]),
    sslErrNotInitialized
  );
end;

procedure RaiseConfigurationError(const AOption, AReason: string);
begin
  raise ESSLConfigurationException.Create(
    Format('Configuration error for %s: %s', [AOption, AReason]),
    sslErrConfiguration
  );
end;

procedure RaiseResourceExhausted(const AResource: string);
begin
  raise ESSLResourceException.Create(
    Format('Resource exhausted: %s', [AResource]),
    sslErrResourceExhausted
  );
end;

procedure RaiseBufferError(const AOperation, AReason: string);
begin
  raise ESSLResourceException.Create(
    Format('Buffer error during %s: %s', [AOperation, AReason]),
    sslErrBufferTooSmall
  );
end;

// ============================================================================
// Utility Functions
// ============================================================================

function FormatErrorMessage(const ATemplate: string; const AArgs: array of const): string;
begin
  Result := Format(ATemplate, AArgs);
end;

function GetErrorMessage(ACode: TSSLErrorCode; const ALang: string): string;
begin
  if (ALang = 'en') or (ALang = 'EN') then
    Result := SSL_ERROR_MESSAGES_EN[ACode]
  else
    Result := SSL_ERROR_MESSAGES[ACode];
end;

end.
