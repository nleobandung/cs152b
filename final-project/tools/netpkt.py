"""Packet helpers for testbenches and board tests (standard library only).

SLIP (RFC 1055), IPv4 (RFC 791) and ICMP echo (RFC 792).
"""
import struct

END, ESC, ESC_END, ESC_ESC = 0xC0, 0xDB, 0xDC, 0xDD

PC_IP = "10.0.0.1"
FPGA_IP = "10.0.0.2"


# ---------------- SLIP ----------------
def slip_encode(pkt: bytes) -> bytes:
    """END + escaped packet + END (what both Linux and our slip_tx send)."""
    out = bytearray([END])
    for b in pkt:
        if b == END:
            out += bytes([ESC, ESC_END])
        elif b == ESC:
            out += bytes([ESC, ESC_ESC])
        else:
            out.append(b)
    out.append(END)
    return bytes(out)


def slip_decode(stream: bytes) -> list:
    """Split a byte stream into packets. Empty and malformed frames are skipped."""
    pkts, cur, esc, bad = [], bytearray(), False, False
    for b in stream:
        if b == END:
            if cur and not esc and not bad:
                pkts.append(bytes(cur))
            cur, esc, bad = bytearray(), False, False
        elif bad:
            pass
        elif esc:
            esc = False
            if b == ESC_END:
                cur.append(END)
            elif b == ESC_ESC:
                cur.append(ESC)
            else:
                bad = True
        elif b == ESC:
            esc = True
        else:
            cur.append(b)
    return pkts


# ---------------- Checksums ----------------
def inet_checksum(data: bytes) -> int:
    """16-bit ones'-complement checksum used by IPv4, ICMP, TCP."""
    if len(data) % 2:
        data += b"\x00"
    s = sum(struct.unpack(f"!{len(data) // 2}H", data))
    while s >> 16:
        s = (s & 0xFFFF) + (s >> 16)
    return ~s & 0xFFFF


def ip_aton(ip: str) -> bytes:
    return bytes(int(x) for x in ip.split("."))


# ---------------- IPv4 / ICMP ----------------
def ipv4(src: str, dst: str, proto: int, payload: bytes, ident=0x1234, ttl=64,
         tos=0, flags_frag=0x4000, options=b"") -> bytes:
    """flags_frag 0x4000 = DF set, like Linux. options must be a multiple of 4 bytes."""
    ihl = 5 + len(options) // 4
    hdr = struct.pack("!BBHHHBBH4s4s",
                      0x40 | ihl, tos, ihl * 4 + len(payload), ident, flags_frag,
                      ttl, proto, 0, ip_aton(src), ip_aton(dst)) + options
    csum = inet_checksum(hdr)
    return hdr[:10] + struct.pack("!H", csum) + hdr[12:] + payload


def icmp_echo(typ: int, ident: int, seq: int, data: bytes) -> bytes:
    msg = struct.pack("!BBHHH", typ, 0, 0, ident, seq) + data
    csum = inet_checksum(msg)
    return msg[:2] + struct.pack("!H", csum) + msg[4:]


def ping_request(seq=1, ident=0x4242, data=None, src=PC_IP, dst=FPGA_IP, **ip_kw) -> bytes:
    """Like `ping 10.0.0.2`: 56 data bytes, 84-byte IP packet."""
    if data is None:
        data = bytes(range(56))
    ip_kw.setdefault("ident", (0x1000 + seq) & 0xFFFF)
    return ipv4(src, dst, 1, icmp_echo(8, ident, seq, data), **ip_kw)


def ping_reply(request: bytes) -> bytes:
    """The exact reply rtl/ip_icmp.v sends for a given request.

    IP: TOS 0, same total length / ID / DF flag, TTL 64, addresses swapped.
    ICMP: type 8 -> 0, everything else copied. Both checksums recomputed.
    """
    ip_hdr, icmp = bytearray(request[:20]), bytearray(request[20:])
    ip_hdr[1] = 0                                   # TOS
    ip_hdr[8] = 64                                  # TTL
    ip_hdr[12:16], ip_hdr[16:20] = request[16:20], request[12:16]
    ip_hdr[10:12] = b"\x00\x00"
    ip_hdr[10:12] = struct.pack("!H", inet_checksum(bytes(ip_hdr)))
    icmp[0] = 0
    icmp[2:4] = b"\x00\x00"
    icmp[2:4] = struct.pack("!H", inet_checksum(bytes(icmp)))
    return bytes(ip_hdr + icmp)


def check_ipv4(pkt: bytes) -> list:
    """Return a list of problems with an IPv4/ICMP packet (empty = OK)."""
    problems = []
    if len(pkt) < 20 or pkt[0] >> 4 != 4:
        return ["not IPv4"]
    ihl = (pkt[0] & 0x0F) * 4
    if inet_checksum(pkt[:ihl]) != 0:
        problems.append("bad IP header checksum")
    total = struct.unpack("!H", pkt[2:4])[0]
    if total != len(pkt):
        problems.append(f"IP total length {total} != packet length {len(pkt)}")
    if pkt[9] == 1 and inet_checksum(pkt[ihl:]) != 0:
        problems.append("bad ICMP checksum")
    return problems
