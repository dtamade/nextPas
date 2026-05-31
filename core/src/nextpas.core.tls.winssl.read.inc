{ 
  优化的Read和ProcessDecrypt实现
  使用环形缓冲区，减少内存复制
}

function TWinSSLConnection.Read(var aBuffer; aCount: Integer): Integer;
var
  BytesAvailable: Integer;
  BytesToCopy: Integer;
  BytesReceived: Integer;
  BytesDecrypted: Integer;
  CurrentPtr: PByte;
  TotalRead: Integer;
  EncBuffer: PByte;
  EncSpace: Integer;
begin
  Result := 0;
  
  if not IsHandshakeComplete then
    Exit;
  
  TotalRead := 0;
  CurrentPtr := @aBuffer;
  
  // 主读取循环
  while TotalRead < aCount do
  begin
    // 步骤1: 从解密缓冲区读取已有数据
    BytesAvailable := FDecryptedBuffer.Available;
    if BytesAvailable > 0 then
    begin
      BytesToCopy := aCount - TotalRead;
      if BytesToCopy > BytesAvailable then
        BytesToCopy := BytesAvailable;
      
      // 直接从环形缓冲区读取到用户缓冲区
      BytesToCopy := FDecryptedBuffer.Read(CurrentPtr^, BytesToCopy);
      Inc(CurrentPtr, BytesToCopy);
      Inc(TotalRead, BytesToCopy);
      
      // 如果已满足请求，直接返回
      if TotalRead >= aCount then
      begin
        Result := TotalRead;
        Exit;
      end;
    end;
    
    // 步骤2: 尝试解密已缓存的加密数据
    if FEncryptedBuffer.Available > 0 then
    begin
      BytesDecrypted := ProcessDecrypt;
      if BytesDecrypted > 0 then
        Continue;  // 有新数据，回到循环开始读取
    end;
    
    // 步骤3: 从socket接收新数据（零拷贝优化）
    FEncryptedBuffer.GetWriteBuffer(EncBuffer, EncSpace);
    if EncSpace = 0 then
      Break;  // 加密缓冲区满，这不应该发生
    
    // 限制单次读取大小，避免阻塞太久
    if EncSpace > 16384 then
      EncSpace := 16384;
    
    BytesReceived := ReceiveData(EncBuffer, EncSpace);
    
    if BytesReceived > 0 then
    begin
      // 确认写入的数据
      FEncryptedBuffer.ConfirmWrite(BytesReceived);
      
      // 立即尝试解密
      repeat
        BytesDecrypted := ProcessDecrypt;
      until BytesDecrypted <= 0;  // 解密所有可能的记录
    end
    else if BytesReceived < 0 then
    begin
      // 错误发生
      if TotalRead > 0 then
        Result := TotalRead
      else
        Result := -1;
      Break;
    end
    else // BytesReceived = 0
    begin
      // 没有数据可用
      if TotalRead > 0 then
        Result := TotalRead
      else
        Result := 0;
      Break;
    end;
  end;
  
  if (Result = 0) and (TotalRead > 0) then
    Result := TotalRead;
end;

function TWinSSLConnection.ProcessDecrypt: Integer;
var
  Status: SECURITY_STATUS;
  Buffers: array[0..3] of SecBuffer;
  BufferDesc: SecBufferDesc;
  EncBuffer: PByte;
  EncSize: Integer;
  DecBuffer: PByte;
  DecSpace: Integer;
  ExtraBytes: Integer;
  i: Integer;
begin
  Result := 0;
  
  // 获取可用的加密数据
  FEncryptedBuffer.GetReadBuffer(EncBuffer, EncSize);
  if EncSize = 0 then
    Exit;
  
  // 准备解密缓冲区
  Buffers[0].cbBuffer := EncSize;
  Buffers[0].BufferType := SECBUFFER_DATA;
  Buffers[0].pvBuffer := EncBuffer;
  
  Buffers[1].cbBuffer := 0;
  Buffers[1].BufferType := SECBUFFER_EMPTY;
  Buffers[1].pvBuffer := nil;
  
  Buffers[2].cbBuffer := 0;
  Buffers[2].BufferType := SECBUFFER_EMPTY;
  Buffers[2].pvBuffer := nil;
  
  Buffers[3].cbBuffer := 0;
  Buffers[3].BufferType := SECBUFFER_EMPTY;
  Buffers[3].pvBuffer := nil;
  
  BufferDesc.ulVersion := SECBUFFER_VERSION;
  BufferDesc.cBuffers := 4;
  BufferDesc.pBuffers := @Buffers[0];
  
  // 调用解密函数
  Status := FContext.FLibrary.FDecryptMessage(@FCtxtHandle, @BufferDesc, 0, nil);
  
  case Status of
    SEC_E_OK:
      begin
        // 解密成功，查找解密后的数据
        for i := 0 to 3 do
        begin
          if Buffers[i].BufferType = SECBUFFER_DATA then
          begin
            // 将解密的数据写入解密缓冲区
            if Buffers[i].cbBuffer > 0 then
            begin
              Result := FDecryptedBuffer.Write(Buffers[i].pvBuffer^, Buffers[i].cbBuffer);
            end;
            Break;
          end;
        end;
        
        // 查找EXTRA数据（未处理的额外SSL记录）
        ExtraBytes := 0;
        for i := 0 to 3 do
        begin
          if Buffers[i].BufferType = SECBUFFER_EXTRA then
          begin
            ExtraBytes := Buffers[i].cbBuffer;
            Break;
          end;
        end;
        
        // 确认已处理的数据
        if ExtraBytes > 0 then
        begin
          // 有额外数据，只确认已处理的部分
          FEncryptedBuffer.ConfirmRead(EncSize - ExtraBytes);
        end
        else
        begin
          // 所有数据都已处理
          FEncryptedBuffer.ConfirmRead(EncSize);
        end;
      end;
      
    SEC_E_INCOMPLETE_MESSAGE:
      begin
        // 需要更多数据才能解密
        Result := 0;
      end;
      
    else
      begin
        // 解密失败，清除错误数据
        FEncryptedBuffer.ConfirmRead(EncSize);
        Result := -1;
      end;
  end;
end;