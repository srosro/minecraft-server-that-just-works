#!/usr/bin/env python3
"""Ping a Minecraft server the way a real client does, for Java (TCP) and Bedrock (UDP).

Usage: scripts/mcping.py <host> java|bedrock

Run it from OUTSIDE your network. A LAN test can succeed via router hairpinning
even when port forwarding is broken, which is exactly the case you want to catch.
"""
import socket, struct, json, sys, time

def varint(n):
    b=b''
    while True:
        x=n&0x7F; n>>=7
        b+=bytes([x|(0x80 if n else 0)])
        if not n: return b

def rvarint(s):
    n=0; shift=0
    while True:
        d=s.recv(1)
        if not d: raise EOFError
        n|=(d[0]&0x7F)<<shift
        if not d[0]&0x80: return n
        shift+=7

def java(host, port, timeout=6):
    s=socket.create_connection((host,port),timeout); s.settimeout(timeout)
    addr=host.encode()
    hs=b'\x00'+varint(769)+varint(len(addr))+addr+struct.pack('>H',port)+varint(1)
    s.sendall(varint(len(hs))+hs); s.sendall(varint(1)+b'\x00')
    rvarint(s); pid=rvarint(s); ln=rvarint(s)
    buf=b''
    while len(buf)<ln:
        c=s.recv(ln-len(buf))
        if not c: break
        buf+=c
    s.close()
    d=json.loads(buf.decode('utf-8',errors='replace'))
    motd=d.get('description')
    if isinstance(motd,dict): motd=motd.get('text') or ''.join(e.get('text','') for e in motd.get('extra',[]))
    return f"MOTD={motd!r} players={d.get('players',{}).get('online')}/{d.get('players',{}).get('max')} version={d.get('version',{}).get('name')}"

MAGIC=bytes.fromhex('00ffff00fefefefefdfdfdfd12345678')
def bedrock(host, port, timeout=6):
    s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.settimeout(timeout)
    pkt=b'\x01'+struct.pack('>Q',int(time.time()*1000))+MAGIC+struct.pack('>Q',2)
    s.sendto(pkt,(host,port))
    data,_=s.recvfrom(4096); s.close()
    if data[0]!=0x1c: raise ValueError('bad reply')
    ln=struct.unpack('>H',data[33:35])[0]
    return data[35:35+ln].decode('utf-8',errors='replace').split(';')[1:3]

if __name__=='__main__':
    host,which=sys.argv[1],sys.argv[2]
    print(java(host,29565) if which=='java' else bedrock(host,29132))
