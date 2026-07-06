{ objfpc}{+}
program comprehensive_ackermann_pass;
function Ack(M,N: Integer): Integer;
begin
  if M=0 then Ack:=N+1
  else if N=0 then Ack:=Ack(M-1,1)
  else Ack:=Ack(M-1,Ack(M,N-1));
end;
begin
  if Ack(0,0)<>1 then Halt(1);
  if Ack(1,1)<>3 then Halt(2);
  if Ack(2,1)<>5 then Halt(3);
  if Ack(3,1)<>13 then Halt(4);
end.
