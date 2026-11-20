#!/usr/bin/env python3
"""Generate stimulus for sim/tb_net_top.v.

Two vector sets, written into OUT_DIR:
  echo_*   for net_top with ECHO_MODE = 1 (pkt_echo): SLIP framing edge cases;
           every valid frame comes back unchanged.
  ping_*   for net_top with ip_icmp: valid pings get ping_reply(request),
           everything else is dropped.

Files per set:
  <set>in.hex    bytes to send on RsRx, one per line. The token "100" means
                 "wait until the FPGA's output goes quiet".
  <set>exp.hex   bytes expected back on RsTx
  <set>meta.txt  "<frames rx'd> <frames tx'd> <bad SLIP frames> <IP drops>"
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from netpkt import (END, ESC, check_ipv4, icmp_echo, ipv4,  # noqa: E402
                    ping_reply, ping_request, slip_encode)

MAX_LEN = 1500
WAIT = "100"


class Vectors:
    def __init__(self):
        self.tokens, self.expected = [], bytearray()
        self.n_rx = self.n_tx = self.n_slip_bad = self.n_ip_drop = 0

    def raw(self, data: bytes):
        self.tokens.extend(f"{b:02x}" for b in data)

    def wait(self):
        self.tokens.append(WAIT)

    def reply(self, pkt: bytes, reply: bytes):
        """Frame that should produce `reply`."""
        self.raw(slip_encode(pkt))
        self.expected.extend(slip_encode(reply))
        self.n_rx += 1
        self.n_tx += 1

    def ip_drop(self, pkt: bytes):
        """Valid SLIP frame that the IP/ICMP layer should drop."""
        self.raw(slip_encode(pkt))
        self.n_rx += 1
        self.n_ip_drop += 1

    def slip_bad(self, raw: bytes):
        """Malformed SLIP frame, dropped by slip_rx."""
        self.raw(raw)
        self.n_slip_bad += 1

    def write(self, out_dir, prefix):
        with open(os.path.join(out_dir, prefix + "in.hex"), "w") as f:
            f.write("\n".join(self.tokens) + "\n")
        with open(os.path.join(out_dir, prefix + "exp.hex"), "w") as f:
            f.write("\n".join(f"{b:02x}" for b in self.expected) + "\n")
        with open(os.path.join(out_dir, prefix + "meta.txt"), "w") as f:
            f.write(f"{self.n_rx} {self.n_tx} {self.n_slip_bad} {self.n_ip_drop}\n")
        n_in = sum(1 for t in self.tokens if t != WAIT)
        print(f"  {prefix}*: {self.n_tx} replies, {self.n_ip_drop} IP drops, "
              f"{self.n_slip_bad} SLIP drops; {n_in} bytes in, {len(self.expected)} out")


def rand_bytes(rng, n, specials=True):
    if specials:
        return bytes(rng.choice([END, ESC, rng.randrange(256)]) for _ in range(n))
    return bytes(rng.randrange(256) for _ in range(n))


# ======================= echo set (pkt_echo) =======================
def echo_vectors(rng):
    v = Vectors()
    echo = lambda p: v.reply(p, p)  # noqa: E731

    echo(ping_request(seq=1)); v.wait()
    # Packets full of SLIP special bytes; bare DC/DD are plain data
    for p in ([END], [ESC], [END, ESC, END, ESC, ESC, END], [0x01, END, 0x02, ESC, 0x03, 0xDC, 0xDD]):
        echo(bytes(p)); v.wait()
    # Empty frames are ignored; extra ENDs between packets are harmless
    v.raw(bytes([END, END, END])); v.wait()
    echo(bytes([0xAA, 0x55])); v.raw(bytes([END, END])); v.wait()
    # Malformed frames are dropped; the next good one still gets through
    v.slip_bad(bytes([END, 0x11, 0x22, ESC, 0x41, 0x33, END]))     # ESC + invalid code
    echo(b"after bad escape"); v.wait()
    v.slip_bad(bytes([END, 0x11, 0x22, ESC, END]))                  # ESC then END
    echo(b"after ESC END"); v.wait()
    v.slip_bad(bytes([END]) + bytes(MAX_LEN + 1) + bytes([END]))    # one byte too long
    echo(b"after too long"); v.wait()
    # Exactly MAX_LEN is allowed
    echo(rand_bytes(rng, MAX_LEN, specials=False)); v.wait()
    # Random packets of varied size
    for _ in range(20):
        echo(rand_bytes(rng, rng.randrange(1, 300))); v.wait()
    # Back-to-back pings, no pauses (like ping -f)
    for seq in range(2, 12):
        echo(ping_request(seq=seq))
    v.wait()
    # Small packets arriving while a big reply is still going out: needs both
    # buffer slots on each side (with one slot, two of these pings are lost)
    echo(rand_bytes(rng, 1000, specials=False))
    for seq in range(12, 15):
        echo(ping_request(seq=seq))
    v.wait()
    return v


# ======================= ping set (ip_icmp) =======================
def first_fold_carries(data: bytes) -> bool:
    """True if folding the 32-bit word sum once still leaves a carry.

    The hardware must fold twice; these packets catch a design that folds once.
    """
    if len(data) % 2:
        data += b"\x00"
    s = sum(int.from_bytes(data[i:i + 2], "big") for i in range(0, len(data), 2))
    return (s & 0xFFFF) + (s >> 16) > 0xFFFF


def zero_csum(data: bytes, at: int) -> bytes:
    return data[:at] + b"\x00\x00" + data[at + 2:]


def carry_pings(rng):
    """Find pings whose reply checksums need the second fold.

    Only the checksums the hardware *generates* can hit this. For a valid
    request the folded sum is FFFF, which a once-folded sum of < 64K words
    can only reach without a carry, so verification is safe either way.
    """
    found = {}
    checks = {
        "reply ICMP sum": lambda q, r: first_fold_carries(zero_csum(r[20:], 2)),
        "reply IP sum":   lambda q, r: first_fold_carries(zero_csum(r[:20], 10)),
    }
    for _ in range(200000):
        big = rng.random() < 0.5
        req = ping_request(seq=rng.randrange(65536), ident=rng.randrange(65536),
                           src=f"10.{rng.randrange(256)}.{rng.randrange(256)}.{rng.randrange(256)}",
                           data=bytes(rng.randrange(0xE0, 0x100) for _ in range(1400)) if big else b"",
                           ttl=rng.randrange(256), tos=rng.randrange(256))
        rep = ping_reply(req)
        for name, hit in checks.items():
            if name not in found and hit(req, rep):
                found[name] = req
        if len(found) == len(checks):
            break
    missing = set(checks) - set(found)
    assert not missing, f"no carry case found for {missing}"
    return list(found.values())


def flip(pkt: bytes, i: int) -> bytes:
    b = bytearray(pkt)
    b[i] ^= 0x01
    return bytes(b)


def ping_vectors(rng):
    v = Vectors()

    def ping(req):
        rep = ping_reply(req)
        assert not check_ipv4(req) and not check_ipv4(rep)
        v.reply(req, rep)

    # --- Valid pings ---
    ping(ping_request(seq=1)); v.wait()                                  # plain `ping 10.0.0.2`
    ping(ping_request(seq=2, data=b"")); v.wait()                        # ping -s 0 (28 bytes)
    ping(ping_request(seq=3, data=b"\x7f")); v.wait()                    # odd-length ICMP
    ping(ping_request(seq=4, data=b"abc")); v.wait()
    ping(ping_request(seq=5, data=bytes([END, ESC] * 20))); v.wait()     # SLIP specials in data
    ping(ping_request(seq=6, data=rand_bytes(rng, MAX_LEN - 28, specials=False))); v.wait()  # 1500 bytes
    ping(ping_request(seq=7, ttl=1, tos=0x10, flags_frag=0)); v.wait()   # odd TTL/TOS, DF clear
    ping(ping_request(seq=8, src="192.168.7.33")); v.wait()              # other source address
    for seq in range(9, 29):                                             # random sizes / ids / data
        ping(ping_request(seq=rng.randrange(65536), ident=rng.randrange(65536),
                          data=rand_bytes(rng, rng.randrange(0, 300)),
                          ttl=rng.randrange(1, 256)))
        v.wait()
    for req in carry_pings(rng):                                         # checksum fold carries
        ping(req)
        v.wait()

    # --- Dropped by IPv4/ICMP checks; each followed by a good ping ---
    good = ping_request(seq=100)
    drops = [
        ping_request(dst="10.0.0.3"),                                    # not for us
        ping_request(dst="10.0.0.255"),                                  # broadcast
        flip(good, 10),                                                  # bad IP checksum
        flip(good, 22),                                                  # bad ICMP checksum
        flip(good, 40),                                                  # corrupted data -> ICMP checksum
        ipv4("10.0.0.1", "10.0.0.2", 1, icmp_echo(0, 1, 1, b"hi")),      # echo *reply*
        ipv4("10.0.0.1", "10.0.0.2", 1, icmp_echo(13, 1, 1, bytes(12))), # timestamp request
        ipv4("10.0.0.1", "10.0.0.2", 1, b"\x08\x01" + icmp_echo(8, 1, 1, b"x")[2:]),  # code 1
        ipv4("10.0.0.1", "10.0.0.2", 17, bytes(16)),                     # UDP
        ipv4("10.0.0.1", "10.0.0.2", 6, bytes(20)),                      # TCP (not yet)
        ipv4("10.0.0.1", "10.0.0.2", 1, icmp_echo(8, 1, 1, b"opt"),
             options=b"\x01\x01\x01\x00"),                               # IP options (IHL 6)
        ipv4("10.0.0.1", "10.0.0.2", 1, icmp_echo(8, 1, 1, bytes(32)),
             flags_frag=0x2000),                                         # more-fragments set
        ipv4("10.0.0.1", "10.0.0.2", 1, icmp_echo(8, 1, 1, bytes(32)),
             flags_frag=0x0004),                                         # fragment offset != 0
        good[:-4],                                                       # truncated (length mismatch)
        good + b"\x00\x00",                                              # padded (length mismatch)
        good[:24],                                                       # shorter than IP + ICMP headers
        good[:12],                                                       # shorter than an IP header
        bytes([0x60]) + rand_bytes(rng, 39, specials=False),             # IPv6
    ]
    for i, pkt in enumerate(drops):
        v.ip_drop(pkt)
        ping(ping_request(seq=200 + i))
        v.wait()

    # --- Back-to-back stream (ping -f) ---
    for seq in range(300, 310):
        ping(ping_request(seq=seq))
    v.wait()
    # --- Small pings arriving while a big reply is going out ---
    ping(ping_request(seq=400, data=rand_bytes(rng, 1000, specials=False)))
    for seq in range(401, 404):
        ping(ping_request(seq=seq))
    v.wait()
    # --- Drops mixed into a back-to-back stream ---
    for seq in range(500, 506):
        ping(ping_request(seq=seq))
        v.ip_drop(ping_request(seq=seq, dst="10.0.0.9"))
    v.wait()
    return v


if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out_dir, exist_ok=True)
    print("gen_net_vectors:")
    echo_vectors(random.Random(152)).write(out_dir, "echo_")
    ping_vectors(random.Random(152)).write(out_dir, "ping_")
