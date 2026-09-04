program test_winssl_handshake_debug;

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.socket,
  nextpas.core.system.sysutils, nextpas.core.system.classes,

  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.api,
  nextpas.core.tls.winssl.utils;

var
  SSLLib: ISSLLibrary;
  Context: ISSLContext;
  Socket: TPlatformSocket;
  Host: string;
  Port: Word;

  // 手动握手变量
  CredHandle: TSecHandle;
  CtxtHandle: TSecHandle;
  SchannelCred: SCHANNEL_CRED;
  OutBuffers: array[0..0] of TSecBuffer;
  OutBufferDesc: TSecBufferDesc;
  InBuffers: array[0..1] of TSecBuffer;
  InBufferDesc: TSecBufferDesc;
  Status: SECURITY_STATUS;
  dwSSPIFlags, dwSSPIOutFlags: DWORD;
  ServerName: PWideChar;
  cbData, cbIoBuffer: DWORD;
  IoBuffer: array[0..16384-1] of Byte;
  TimeStamp: TTimeStamp;

function CreateAndConnectSocket: Boolean;
var
  LAddr: TPlatformSockAddr;
  LIP: UInt32;
begin
  Result := False;

  WriteLn('Creating TCP socket...');
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    Socket) <> 0 then
  begin
    WriteLn('  ERROR: Failed to create socket');
    Exit;
  end;
  WriteLn('  Socket created: ', Socket.Value);

  WriteLn('Resolving host: ', Host);
  if platform_socket_resolve_ipv4(PAnsiChar(AnsiString(Host)), LIP) <> 0 then
  begin
    WriteLn('  ERROR: Failed to resolve host');
    platform_socket_close(Socket);
    Exit;
  end;

  WriteLn('  Resolved to: ', platform_ipv4_to_string(LIP));

  platform_sockaddr_ipv4(Port, LIP, LAddr);
  WriteLn('Connecting to ', Host, ':', Port, '...');
  if platform_socket_connect(Socket, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    WriteLn('  ERROR: Failed to connect');
    platform_socket_close(Socket);
    Exit;
  end;

  WriteLn('  TCP connection established');
  Result := True;
end;

function InitializeSchannel: Boolean;
begin
  Result := False;

  WriteLn;
  WriteLn('Initializing Schannel credentials...');

  InitSecHandle(CredHandle);
  InitSecHandle(CtxtHandle);

  FillChar(SchannelCred, SizeOf(SchannelCred), 0);
  SchannelCred.dwVersion := SCHANNEL_CRED_VERSION;
  SchannelCred.grbitEnabledProtocols := SP_PROT_TLS1_2_CLIENT or SP_PROT_TLS1_3_CLIENT;
  SchannelCred.dwFlags := SCH_CRED_NO_DEFAULT_CREDS or SCH_CRED_MANUAL_CRED_VALIDATION;

  WriteLn('  Acquiring credentials handle...');
  Status := AcquireCredentialsHandleW(
    nil,
    PWideChar(WideString('Microsoft Unified Security Protocol Provider')),
    SECPKG_CRED_OUTBOUND,
    nil,
    @SchannelCred,
    nil,
    nil,
    @CredHandle,
    @TimeStamp
  );

  if not IsSuccess(Status) then
  begin
    WriteLn('  ERROR: AcquireCredentialsHandleW failed with status: 0x', IntToHex(Status, 8));
    WriteLn('  Error: ', GetSchannelErrorString(Status));
    Exit;
  end;

  WriteLn('  Credentials handle acquired successfully');
  Result := True;
end;

function PerformHandshake: Boolean;
var
  i: Integer;
  LSent, LRecvd: Int32;
begin
  Result := False;

  WriteLn;
  WriteLn('Starting TLS handshake...');

  dwSSPIFlags := ISC_REQ_SEQUENCE_DETECT or
                 ISC_REQ_REPLAY_DETECT or
                 ISC_REQ_CONFIDENTIALITY or
                 ISC_RET_EXTENDED_ERROR or
                 ISC_REQ_ALLOCATE_MEMORY or
                 ISC_REQ_STREAM;

  ServerName := StringToPWideChar(Host);
  try
    // 初始化输出缓冲区
    OutBuffers[0].pvBuffer := nil;
    OutBuffers[0].BufferType := SECBUFFER_TOKEN;
    OutBuffers[0].cbBuffer := 0;

    OutBufferDesc.cBuffers := 1;
    OutBufferDesc.pBuffers := @OutBuffers[0];
    OutBufferDesc.ulVersion := SECBUFFER_VERSION;

    WriteLn('  Calling InitializeSecurityContextW (initial call)...');
    Status := InitializeSecurityContextW(
      @CredHandle,
      nil,
      ServerName,
      dwSSPIFlags,
      0,
      0,
      nil,
      0,
      @CtxtHandle,
      @OutBufferDesc,
      @dwSSPIOutFlags,
      nil
    );

    WriteLn('  Status: 0x', IntToHex(Status, 8), ' - ', GetSchannelErrorString(Status));

    if not ((Status = SEC_I_CONTINUE_NEEDED) or IsSuccess(Status)) then
    begin
      WriteLn('  ERROR: Initial handshake failed');
      Exit;
    end;

    // 发送客户端 hello
    if (OutBuffers[0].cbBuffer > 0) and (OutBuffers[0].pvBuffer <> nil) then
    begin
      WriteLn('  Sending Client Hello (', OutBuffers[0].cbBuffer, ' bytes)...');
      LSent := 0;
      if platform_socket_send(Socket, OutBuffers[0].pvBuffer,
        Int32(OutBuffers[0].cbBuffer), 0, LSent) <> 0 then
        LSent := 0;
      FreeContextBuffer(OutBuffers[0].pvBuffer);
      cbData := DWORD(LSent);

      if cbData = 0 then
      begin
        WriteLn('  ERROR: Failed to send client hello');
        Exit;
      end;
      WriteLn('  Sent ', cbData, ' bytes');
    end;

    // 继续握手循环
    cbIoBuffer := 0;
    i := 0;
    while (Status = SEC_I_CONTINUE_NEEDED) or (Status = SEC_E_INCOMPLETE_MESSAGE) do
    begin
      Inc(i);
      WriteLn;
      WriteLn('  === Handshake iteration ', i, ' ===');

      // 如果需要更多数据，接收服务器数据
      if (Status = SEC_E_INCOMPLETE_MESSAGE) or (cbIoBuffer = 0) then
      begin
        if cbIoBuffer > 0 then
          WriteLn('  Incomplete message - appending more data to existing ', cbIoBuffer, ' bytes')
        else
          WriteLn('  Receiving server data...');

        // 在现有数据后面追加新数据
        LRecvd := 0;
        if platform_socket_recv(Socket, @IoBuffer[cbIoBuffer],
          SizeOf(IoBuffer) - Int32(cbIoBuffer), 0, LRecvd) <> 0 then
          LRecvd := 0;
        cbData := DWORD(LRecvd);

        if cbData = 0 then
        begin
          WriteLn('  ERROR: Failed to receive data');
          Exit;
        end;

        WriteLn('  Received ', cbData, ' bytes (total in buffer: ', cbIoBuffer + cbData, ')');
        cbIoBuffer := cbIoBuffer + cbData;
      end;

      // 设置输入缓冲区
      InBuffers[0].pvBuffer := @IoBuffer[0];
      InBuffers[0].cbBuffer := cbIoBuffer;
      InBuffers[0].BufferType := SECBUFFER_TOKEN;

      InBuffers[1].pvBuffer := nil;
      InBuffers[1].cbBuffer := 0;
      InBuffers[1].BufferType := SECBUFFER_EMPTY;

      InBufferDesc.cBuffers := 2;
      InBufferDesc.pBuffers := @InBuffers[0];
      InBufferDesc.ulVersion := SECBUFFER_VERSION;

      // 设置输出缓冲区
      OutBuffers[0].pvBuffer := nil;
      OutBuffers[0].BufferType := SECBUFFER_TOKEN;
      OutBuffers[0].cbBuffer := 0;

      OutBufferDesc.cBuffers := 1;
      OutBufferDesc.pBuffers := @OutBuffers[0];
      OutBufferDesc.ulVersion := SECBUFFER_VERSION;

      WriteLn('  Calling InitializeSecurityContextW (loop iteration ', i, ')...');
      Status := InitializeSecurityContextW(
        @CredHandle,
        @CtxtHandle,
        ServerName,
        dwSSPIFlags,
        0,
        0,
        @InBufferDesc,
        0,
        nil,
        @OutBufferDesc,
        @dwSSPIOutFlags,
        nil
      );

      WriteLn('  Status: 0x', IntToHex(Status, 8), ' - ', GetSchannelErrorString(Status));

      // 处理额外数据 - 将 extra data 移到缓冲区开头
      if (InBuffers[1].BufferType = SECBUFFER_EXTRA) and (InBuffers[1].cbBuffer > 0) then
      begin
        WriteLn('  Extra data: ', InBuffers[1].cbBuffer, ' bytes - moving to buffer start');
        Move(IoBuffer[cbIoBuffer - InBuffers[1].cbBuffer], IoBuffer[0], InBuffers[1].cbBuffer);
        cbIoBuffer := InBuffers[1].cbBuffer;
      end
      else if (Status <> SEC_E_INCOMPLETE_MESSAGE) and (Status <> SEC_I_CONTINUE_NEEDED) then
        cbIoBuffer := 0  // 握手完成或失败，清空缓冲区
      else if Status <> SEC_E_INCOMPLETE_MESSAGE then
        cbIoBuffer := 0;  // Continue needed 但没有 extra data，清空缓冲区

      // 发送响应数据
      if (OutBuffers[0].cbBuffer > 0) and (OutBuffers[0].pvBuffer <> nil) then
      begin
        WriteLn('  Sending response (', OutBuffers[0].cbBuffer, ' bytes)...');
        LSent := 0;
        if platform_socket_send(Socket, OutBuffers[0].pvBuffer,
          Int32(OutBuffers[0].cbBuffer), 0, LSent) <> 0 then
          LSent := 0;
        FreeContextBuffer(OutBuffers[0].pvBuffer);
        cbData := DWORD(LSent);

        if cbData = 0 then
        begin
          WriteLn('  ERROR: Failed to send response');
          Exit;
        end;
        WriteLn('  Sent ', cbData, ' bytes');
      end;

      // 检查状态
      if Status = SEC_E_INCOMPLETE_MESSAGE then
      begin
        WriteLn('  Incomplete message, will receive more data in next iteration');
        Continue;  // 继续循环接收更多数据
      end;

      if not ((Status = SEC_I_CONTINUE_NEEDED) or IsSuccess(Status)) then
      begin
        WriteLn('  ERROR: Handshake failed at iteration ', i);
        WriteLn('  Final status: 0x', IntToHex(Status, 8), ' - ', GetSchannelErrorString(Status));
        Exit;
      end;

      if i > 10 then
      begin
        WriteLn('  ERROR: Too many handshake iterations');
        Exit;
      end;
    end;

    WriteLn;
    if IsSuccess(Status) then
    begin
      WriteLn('*** TLS HANDSHAKE COMPLETED SUCCESSFULLY ***');
      Result := True;
    end
    else
    begin
      WriteLn('ERROR: Handshake ended with status: 0x', IntToHex(Status, 8));
    end;

  finally
    if ServerName <> nil then
      FreePWideCharString(ServerName);
  end;
end;

begin
  WriteLn('=== WinSSL Handshake Debug Test ===');
  WriteLn;

  try
    Host := 'www.google.com';
    Port := 443;

    WriteLn('Target: ', Host, ':', Port);
    WriteLn;

    if not CreateAndConnectSocket then
    begin
      WriteLn;
      WriteLn('FAILED: Could not create TCP connection');
      Halt(1);
    end;

    if not InitializeSchannel then
    begin
      WriteLn;
      WriteLn('FAILED: Could not initialize Schannel');
      platform_socket_close(Socket);
      Halt(1);
    end;

    if not PerformHandshake then
    begin
      WriteLn;
      WriteLn('FAILED: TLS handshake failed');
      platform_socket_close(Socket);
      DeleteSecurityContext(@CtxtHandle);
      FreeCredentialsHandle(@CredHandle);
      Halt(1);
    end;

    WriteLn;
    WriteLn('SUCCESS! Cleaning up...');

    platform_socket_close(Socket);
    DeleteSecurityContext(@CtxtHandle);
    FreeCredentialsHandle(@CredHandle);

    WriteLn;
    WriteLn('All operations completed successfully!');

  finally
  end;

  ExitCode := 0;
end.
