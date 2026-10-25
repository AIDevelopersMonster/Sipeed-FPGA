# Repository consolidation — Tang Nano 9K / PiKoSoL (2026-10-25)

**Policy:** The only maintained branch is `main`. Twenty-one historic working branches were consolidated into a single merge-ancestry commit. New source/document paths were adopted without overwriting existing files in `main`.

## What is preserved

- 254 previously absent source or documentation files, including SD-04–SD-08, HOST-00–02, UART, FIFO/LIFO and PicoRV32 materials.
- All **existing** 240 file blobs of the working `main` tree remain **byte-for-byte unchanged**, including `docs/lab04/web-loader/{index.html,app.js}`, the WebUSB/WASM engine, and PiKoSoL v0.2.0 bitstream.
- Historic branch commits are parents/ancestors of this consolidation commit. Conflicting earlier implementations remain available via their commit SHA, rather than silently replacing known-good `main` files.
- Branch-specific GitHub Actions workflows are preserved in history but were **not activated** in `main` automatically; they require separate review.
- No claim of hardware acceptance is inferred from the presence of experimental source code.

## Archived branch head registry

- `agent/host00-modular-uart-fifo-lifo` — `d2119deee74edef2c6405c9cafa20d9324b28026`
- `agent/host01-uart-sdhc-readonly` — `783b465e01a43dc1b5c4a762e2f2e2c02f2cd525`
- `agent/host02-fat32-reader` — `d8edf63958b53b62a26b802e9583b7676735d866`
- `agent/lab05-sd02-multilba` — `73b73ee51c90a5e300a0dd58d748b7f810e1921a`
- `agent/lab05-sd-spi-bringup` — `c393b4b813bbe0af4193fa126ca0c71c98d96a32`
- `agent/sd03-mbr-fat32-parser` — `640ff1a6126e78eb4771b04c0f8fc1df58f96d8b`
- `agent/sd04-fat32-directory` — `1171d6f63bbf205edc9f5cf4d51430e047786c61`
- `agent/uart-8n1-standalone-core` — `3436822162cda07f1636e332cdb43e3ea7480a30`
- `docs/english-spi-sd-v0.1` — `d5066b755e7cbe2cdc16b6e02ceb03e88384398f`
- `docs/picorv32-student-quickstart` — `4c6f1ff7d6641b82f18955cc7169c1dc243b3995`
- `docs/pikosol-sd08-video-20261025` — `d3d58bd4bb1ce5f86ff9907defeba045c2a6aa23`
- `docs/zenodo-spi-sd-dois-20261024` — `a70bd260857e984169f5469d9154837de6785658`
- `feature/picorv32-lab03-uart-trace` — `1a8143477f139d14d9a3c9b92acf0e82f17e392b`
- `feature/pikosol-3firmware-public-demo-20261025` — `d3d58bd4bb1ce5f86ff9907defeba045c2a6aa23`
- `feature/pikosol-public-firmware-catalog-20261025` — `d3d58bd4bb1ce5f86ff9907defeba045c2a6aa23`
- `feature/pikosol-web-sd08-release` — `cfd327d133edabab095b5ff72506bb7a5bfbc143`
- `feature/sd04-root-directory-reader` — `ed762c783e388a30c355598493492568ddc5d0f2`
- `feature/sd06-cmd24-offline` — `c4f8d8f28396bb3cc3a015f188be432a50344108`
- `feature/sd07-pikosol-mmio-fit` — `0f85f49a2afd81bfa75bab1d682ec052ebbe07ab`
- `publish/picorv32-led1-html-v1` — `a8727a776f64a633795fbdab1eced18fb4f61e87`
- `publish/sd01-fpga-education` — `4062547fe8927b06836fde41b96c5aa5370f6e6c`

## Future work

Develop only on `main`; preserve working functionality before each change. SD-08 binary publishing, vendor PicoSoc/PicoTiny recovery and local-file WebUSB acceptance are separate experiments and must not be represented as already hardware-verified if not tested.

