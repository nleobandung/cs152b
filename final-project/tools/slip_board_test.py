#!/usr/bin/env python3
"""Board test for net_top over the USB-UART, without Linux/slattach.

  --mode ping  (default; net_top as built)
      Sends SLIP-framed ping requests to 10.0.0.2 and checks each reply is
      exactly what ip_icmp should send (netpkt.ping_reply) with valid checksums.
  --mode echo  (net_top built with ECHO_MODE = 1)
      Sends pings and packets full of C0/DB bytes; each must come back unchanged.

    pip install pyserial
    python3 tools/slip_board_test.py                     # auto-detects the port
    python3 tools/slip_board_test.py /dev/tty.usbserial-XXXXB --count 500
"""
import argparse
import os
import random
import sys
import time

import serial

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from netpkt import (END, ESC, check_ipv4, ping_reply, ping_request,  # noqa: E402
                    slip_decode, slip_encode)
from uart_stress import find_port  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port", nargs="?")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--count", type=int, default=200)
    ap.add_argument("--mode", choices=["ping", "echo"], default="ping")
    args = ap.parse_args()

    port = args.port or find_port()
    ser = serial.Serial(port, args.baud, timeout=0.5)
    ser.reset_input_buffer()
    rng = random.Random()
    print(f"{port} @ {args.baud}, mode {args.mode}")

    ok = bad = lost = 0
    t0 = time.time()
    for i in range(args.count):
        if args.mode == "echo" and i % 4 == 3:
            pkt = bytes(rng.choice([END, ESC, rng.randrange(256)])
                        for _ in range(rng.randrange(1, 300)))
        else:
            data = bytes(rng.randrange(256) for _ in range(rng.choice([0, 1, 56, 56, 200, 1000])))
            pkt = ping_request(seq=i & 0xFFFF, data=data)
        expect = ping_reply(pkt) if args.mode == "ping" else pkt

        ser.write(slip_encode(pkt))
        echo = ser.read(len(slip_encode(expect)))
        pkts = slip_decode(echo)
        if not pkts:
            lost += 1
            print(f"  #{i}: no reply ({len(echo)} bytes back)")
            ser.reset_input_buffer()
        elif pkts[0] != expect:
            bad += 1
            problems = check_ipv4(pkts[0]) if args.mode == "ping" else []
            print(f"  #{i}: reply differs from expected {problems or ''}")
        else:
            ok += 1

    dt = time.time() - t0
    print(f"{ok}/{args.count} correct, {bad} wrong, {lost} lost ({dt:.1f} s)")
    sys.exit(0 if ok == args.count else 1)


if __name__ == "__main__":
    main()
