#!/usr/bin/env python3
"""Stress-test the UART loopback on the Basys3.

Sends random bytes in chunks and checks that each chunk is echoed back exactly.
Chunks stay at or below the FPGA's FIFO depth, which is how real SLIP traffic
looks (one packet, then a pause).

    pip install pyserial
    python3 tools/uart_stress.py                      # auto-detects the port
    python3 tools/uart_stress.py /dev/tty.usbserial-XXXXB --bytes 100000

On macOS the Basys3 shows two ports; the UART is the one ending in "B"
(the "A" channel is JTAG). On Linux it is usually /dev/ttyUSB1.
"""
import argparse
import glob
import os
import sys
import time

import serial


def find_port():
    candidates = sorted(glob.glob("/dev/tty.usbserial-*B")) or sorted(glob.glob("/dev/ttyUSB1"))
    if not candidates:
        sys.exit("No Basys3 UART found; pass the port explicitly.")
    return candidates[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port", nargs="?", help="serial port (default: auto-detect)")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--bytes", type=int, default=20000, help="total bytes to send")
    ap.add_argument("--chunk", type=int, default=64, help="bytes per chunk (<= FIFO depth)")
    args = ap.parse_args()

    port = args.port or find_port()
    ser = serial.Serial(port, args.baud, timeout=1.0)
    ser.reset_input_buffer()
    print(f"{port} @ {args.baud}: sending {args.bytes} bytes in {args.chunk}-byte chunks")

    sent = errors = 0
    t0 = time.time()
    while sent < args.bytes:
        n = min(args.chunk, args.bytes - sent)
        data = os.urandom(n)
        ser.write(data)
        echo = ser.read(n)
        if echo != data:
            errors += 1
            if len(echo) != n:
                print(f"  chunk at byte {sent}: sent {n}, got {len(echo)} back")
            else:
                bad = next(i for i in range(n) if echo[i] != data[i])
                print(f"  chunk at byte {sent}: first mismatch at +{bad}: "
                      f"sent {data[bad]:02x}, got {echo[bad]:02x}")
            if errors >= 10:
                print("  too many errors, stopping")
                break
            time.sleep(0.05)
            ser.reset_input_buffer()
        sent += n

    dt = time.time() - t0
    rate = sent / dt if dt else 0
    print(f"{sent} bytes in {dt:.2f} s ({rate:.0f} B/s round trip, "
          f"line max {args.baud // 10} B/s); {errors} bad chunks")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
