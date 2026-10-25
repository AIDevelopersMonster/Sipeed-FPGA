"""SD-06 offline ONLY: validates a proposed one-sector CMD24 transaction.

No serial port, no device I/O, no filesystem changes. Operates exclusively
on an in-memory card model with a single pre-authorized scratch LBA.
"""
import hashlib
from dataclasses import dataclass

class WriteRejected(ValueError):
    pass

def sha(data):
    return hashlib.sha256(data).hexdigest().upper()

@dataclass(frozen=True)
class WritePlan:
    target_lba: int
    preimage_sha256: str
    payload_sha256: str
    card_id: str

class MockCard:
    def __init__(self, card_id, scratch_lba, preimage):
        if not card_id or not 0 < scratch_lba < 0x100000000 or len(preimage)!=512:
            raise ValueError("invalid isolated mock card")
        self.card_id=card_id
        self.scratch_lba=scratch_lba
        self.sector=bytes(preimage)
        self.write_count=0

    def read(self,lba):
        if lba!=self.scratch_lba:
            raise WriteRejected("LBA not allowlisted")
        return self.sector

    def plan(self,lba,payload):
        if lba!=self.scratch_lba or len(payload)!=512:
            raise WriteRejected("invalid LBA/payload")
        return WritePlan(lba,sha(self.sector),sha(payload),self.card_id)

    def commit(self,plan,payload,*,acknowledged=False):
        if not acknowledged:
            raise WriteRejected("explicit authorization required")
        if plan.card_id!=self.card_id or plan.target_lba!=self.scratch_lba:
            raise WriteRejected("card identity or LBA mismatch")
        if len(payload)!=512 or sha(payload)!=plan.payload_sha256:
            raise WriteRejected("payload hash mismatch")
        if sha(self.sector)!=plan.preimage_sha256:
            raise WriteRejected("preimage changed since plan")
        self.sector=bytes(payload) # IN-MEMORY ONLY, not real SD
        self.write_count+=1
        if sha(self.read(plan.target_lba))!=plan.payload_sha256:
            raise WriteRejected("mock CMD17 verification mismatch")
        return sha(self.sector)
