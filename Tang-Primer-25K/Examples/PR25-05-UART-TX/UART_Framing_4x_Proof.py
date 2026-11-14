#!/usr/bin/env python3
"""PR25-05: reproduce the exact COM25 corruption motif using 4x UART RX sampling.

No third-party dependencies or hardware writes. This shows that *an effective*
RX/TX baud ratio of four is consistent with the captured 44-byte motif; it does
not identify which of FPGA, BL616, driver or stale buffering causes the mismatch.
"""
PAYLOAD = b"PR25 UART TX TEST\r\n"
OBSERVED = bytes.fromhex(
    "00 78 80 80 78 80 80 80 78 F8 80 00 "
    "80 78 78 78 00 78 80 78 00 78 78 80 "
    "00 78 78 78 00 80 00 78 78 78 78 80 "
    "78 00 78 78 F8 00 80 78"
)
TX_TICKS = 64


def waveform(payload):
    bits = [1] * 10
    for c in payload:
        bits += [0] + [(c >> i) & 1 for i in range(8)] + [1]
    return bits + [1] * 10


def decode(bits, ratio):
    rx_ticks = TX_TICKS // ratio
    step = rx_ticks // 4
    end = len(bits) * TX_TICKS

    def line(t):
        k = t // TX_TICKS
        return bits[k] if k < len(bits) else 1

    t, last = 0, 1
    output = []
    while t < end:
        value = line(t)
        if value == 0 and last == 1:
            start = t
            decoded = 0
            for i in range(8):
                decoded |= line(start + 3 * rx_ticks // 2 + i * rx_ticks) << i
            output.append(decoded)
            t = start + 19 * rx_ticks // 2
            while t < end and line(t) == 0:
                t += step
            last = line(t)
            continue
        last = value
        t += step
    return bytes(output)


def main():
    bits = waveform(PAYLOAD)
    normal = decode(bits, 1)
    incorrect = decode(bits, 4)
    assert normal == PAYLOAD, (normal.hex(), PAYLOAD.hex())
    assert incorrect == OBSERVED, (incorrect.hex(), OBSERVED.hex())
    print("PASS: 1:1 samples reconstruct exact 19-byte ASCII payload")
    print("PASS: 4:1 effective RX/TX sampling reconstructs exact 44-byte garbage motif")
    print("Corrupted motif:", incorrect.hex(" ").upper())
    print("Scope: software framing demonstration only, not a physical BL616 diagnosis")


if __name__ == "__main__":
    main()
