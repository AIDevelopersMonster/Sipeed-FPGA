"""One UI entry per logical .bin name. No file deletion or modification."""
from pathlib import Path

def make_catalog(firmware: Path, generated: Path, *, demo: Path,
                 pinned=(), hidden=()):
    """Prefer verified demo; generated candidates; explicit user selection.

    Duplicate basenames in separate PC folders are not duplicated FPGA files.
    File selection is keyed by canonical path in the existing Treeview API.
    """
    hidden = {x.casefold() for x in hidden}
    items = {}
    if demo.is_file():
        items['demo.bin'] = demo.resolve()
    for folder in (firmware, generated):
        if folder.is_dir():
            for f in sorted(folder.glob('*.bin')):
                if f.is_file() and f.name.casefold() not in ('monitor.bin', 'demo.bin'):
                    items[f.name.casefold()] = f.resolve()
    for f in pinned:
        f = Path(f)
        if f.is_file() and f.suffix.lower() == '.bin' and f.name.casefold() not in ('monitor.bin','demo.bin'):
            items[f.name.casefold()] = f.resolve()
    return {str(f): f for name,f in items.items() if name not in hidden}


def find_generated(folder: Path) -> Path:
    """Keep old candidates visible during migration, but never edit or copy them."""
    local = folder / 'generated'
    if local.is_dir() and any(local.glob('*.bin')):
        return local
    previous = folder.parent / 'PiKoSoL_TP20_FileManager_CANDIDATE_v0.1.2' / 'generated'
    return previous if previous.is_dir() else local


def catalog_row_for_download(files: dict[str, Path], downloaded: Path) -> str | None:
    """Choose the Treeview ID that actually exists for the downloaded BIN.

    The verified local firmware/demo.bin intentionally supersedes a downloaded
    demo.bin. In that case, selecting Downloads/demo.bin is a TclError.
    """
    downloaded = Path(downloaded).resolve()
    if str(downloaded) in files:
        return str(downloaded)
    for row_id, local_file in files.items():
        if local_file.name.casefold() == downloaded.name.casefold():
            return row_id
    return None
