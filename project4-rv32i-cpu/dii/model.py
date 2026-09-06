#!/usr/bin/env python3
"""
model.py — an RV32I reference model for differential testing.

Written from the RISC-V unprivileged specification, not from the RTL. That
distinction is the whole point: a model derived from the design under test
would share any misreading of the spec and the differ would report agreement.

It is still weaker than an independent implementation such as Sail or Spike,
because it shares an author with the RTL. State that limitation out loud rather
than claiming independence it doesn't have. riscv-formal covers the
conformance question properly; this model exists to drive the DII/shrink
infrastructure.

Emits one JSON line per retired instruction, in the same shape as the
Verilator harness, so the two traces diff field-by-field.
"""

import json
import sys

XLEN = 32
MASK = 0xFFFFFFFF
DMEM_BYTES = 1 << 16

RESET_PC = 0x4          # the harness burns one NOP after reset; see sim_main.cpp


def s32(x):
    """Interpret a 32-bit pattern as signed."""
    x &= MASK
    return x - (1 << 32) if x & 0x80000000 else x


def u32(x):
    return x & MASK


class Model:
    def __init__(self, pc=RESET_PC):
        self.x = [0] * 32
        self.pc = pc
        self.mem = bytearray(DMEM_BYTES)
        self.order = 0

    # ---------------------------------------------------------------- memory
    def load_word(self, addr):
        a = addr & (DMEM_BYTES - 4)
        return (self.mem[a]
                | (self.mem[a + 1] << 8)
                | (self.mem[a + 2] << 16)
                | (self.mem[a + 3] << 24))

    def store_word(self, addr, data, strb):
        a = addr & (DMEM_BYTES - 4)
        for i in range(4):
            if strb & (1 << i):
                self.mem[a + i] = (data >> (8 * i)) & 0xFF

    # ---------------------------------------------------------------- decode
    @staticmethod
    def decode(insn):
        d = {
            "opcode": insn & 0x7F,
            "rd":     (insn >> 7) & 0x1F,
            "funct3": (insn >> 12) & 0x7,
            "rs1":    (insn >> 15) & 0x1F,
            "rs2":    (insn >> 20) & 0x1F,
            "funct7": (insn >> 25) & 0x7F,
        }
        op = d["opcode"]
        # Immediate reconstruction, per instruction format.
        if op in (0x13, 0x03, 0x67):                      # I-type
            imm = insn >> 20
            d["imm"] = u32(imm - (1 << 12) if imm & 0x800 else imm)
        elif op == 0x23:                                   # S-type
            imm = ((insn >> 25) << 5) | ((insn >> 7) & 0x1F)
            d["imm"] = u32(imm - (1 << 12) if imm & 0x800 else imm)
        elif op == 0x63:                                   # B-type
            imm = (((insn >> 31) & 1) << 12) | (((insn >> 7) & 1) << 11) \
                | (((insn >> 25) & 0x3F) << 5) | (((insn >> 8) & 0xF) << 1)
            d["imm"] = u32(imm - (1 << 13) if imm & 0x1000 else imm)
        elif op in (0x37, 0x17):                            # U-type
            d["imm"] = u32(insn & 0xFFFFF000)
        elif op == 0x6F:                                    # J-type
            imm = (((insn >> 31) & 1) << 20) | (((insn >> 12) & 0xFF) << 12) \
                | (((insn >> 20) & 1) << 11) | (((insn >> 21) & 0x3FF) << 1)
            d["imm"] = u32(imm - (1 << 21) if imm & 0x100000 else imm)
        else:
            d["imm"] = 0
        return d

    # ------------------------------------------------------------------- alu
    @staticmethod
    def alu(op, a, b):
        sh = b & 0x1F
        if op == "add":  return u32(a + b)
        if op == "sub":  return u32(a - b)
        if op == "and":  return a & b
        if op == "or":   return a | b
        if op == "xor":  return a ^ b
        if op == "slt":  return 1 if s32(a) < s32(b) else 0
        if op == "sltu": return 1 if u32(a) < u32(b) else 0
        if op == "sll":  return u32(a << sh)
        if op == "srl":  return u32(a) >> sh
        if op == "sra":  return u32(s32(a) >> sh)
        return 0

    # ------------------------------------------------------------------ step
    def step(self, insn):
        """Execute one instruction. Returns the RVFI record."""
        d = self.decode(insn)
        op, f3, f7 = d["opcode"], d["funct3"], d["funct7"]
        rs1_v = self.x[d["rs1"]]
        rs2_v = self.x[d["rs2"]]
        pc = self.pc

        rd_addr = 0
        rd_wdata = 0
        pc_next = u32(pc + 4)
        alu_result = 0
        mem_rmask = 0
        mem_wmask = 0
        mem_rdata = 0
        mem_wdata = 0
        trap = 0

        # ---- R-type -------------------------------------------------------
        if op == 0x33:
            name = {
                (0x0, 0x00): "add", (0x0, 0x20): "sub",
                (0x1, 0x00): "sll", (0x2, 0x00): "slt",
                (0x3, 0x00): "sltu", (0x4, 0x00): "xor",
                (0x5, 0x00): "srl", (0x5, 0x20): "sra",
                (0x6, 0x00): "or",  (0x7, 0x00): "and",
            }.get((f3, f7), "add")
            alu_result = self.alu(name, rs1_v, rs2_v)
            rd_addr, rd_wdata = d["rd"], alu_result

        # ---- I-type arithmetic -------------------------------------------
        elif op == 0x13:
            if f3 == 0x5:
                name = "sra" if (f7 == 0x20) else "srl"
                alu_result = self.alu(name, rs1_v, d["imm"] & 0x1F)
            elif f3 == 0x1:
                alu_result = self.alu("sll", rs1_v, d["imm"] & 0x1F)
            else:
                name = {0x0: "add", 0x2: "slt", 0x3: "sltu",
                        0x4: "xor", 0x6: "or", 0x7: "and"}[f3]
                alu_result = self.alu(name, rs1_v, d["imm"])
            rd_addr, rd_wdata = d["rd"], alu_result

        # ---- LUI / AUIPC --------------------------------------------------
        elif op == 0x37:
            alu_result = d["imm"]
            rd_addr, rd_wdata = d["rd"], d["imm"]
        elif op == 0x17:
            alu_result = u32(pc + d["imm"])
            rd_addr, rd_wdata = d["rd"], alu_result

        # ---- jumps --------------------------------------------------------
        elif op == 0x6F:                                    # JAL
            alu_result = u32(pc + d["imm"])
            pc_next = alu_result
            rd_addr, rd_wdata = d["rd"], u32(pc + 4)
            if pc_next & 0x3:
                trap = 1
        elif op == 0x67:                                    # JALR
            alu_result = u32(rs1_v + d["imm"])
            pc_next = alu_result & 0xFFFFFFFE
            rd_addr, rd_wdata = d["rd"], u32(pc + 4)
            if pc_next & 0x3:
                trap = 1

        # ---- branches -----------------------------------------------------
        elif op == 0x63:
            taken = {
                0x0: s32(rs1_v) == s32(rs2_v),
                0x1: s32(rs1_v) != s32(rs2_v),
                0x4: s32(rs1_v) < s32(rs2_v),
                0x5: s32(rs1_v) >= s32(rs2_v),
                0x6: u32(rs1_v) < u32(rs2_v),
                0x7: u32(rs1_v) >= u32(rs2_v),
            }.get(f3, False)
            # ALU result mirrors what the datapath computes for the compare,
            # because mem_addr is driven from it.
            alu_result = self.alu(
                {0x0: "sub", 0x1: "sub", 0x4: "slt", 0x5: "slt",
                 0x6: "sltu", 0x7: "sltu"}.get(f3, "sub"), rs1_v, rs2_v)
            if taken:
                pc_next = u32(pc + d["imm"])
            # The spec raises the misaligned-target trap on the branch's
            # computed next PC whether or not the branch is taken: a not-taken
            # branch's pc+4 inherits misalignment from an already-misaligned PC.
            if pc_next & 0x3:
                trap = 1

        # ---- loads --------------------------------------------------------
        elif op == 0x03:
            vaddr = u32(rs1_v + d["imm"])
            alu_result = vaddr
            off = vaddr & 0x3
            misaligned = ((f3 in (0x1, 0x5)) and (off & 1)) or \
                         ((f3 == 0x2) and off)
            if misaligned:
                trap = 1
            else:
                word = self.load_word(vaddr & ~0x3)
                mem_rdata = word
                if f3 in (0x0, 0x4):
                    mem_rmask = 0x1 << off
                    b = (word >> (8 * off)) & 0xFF
                    val = (b - 256 if (f3 == 0x0 and b & 0x80) else b)
                elif f3 in (0x1, 0x5):
                    mem_rmask = 0x3 << off
                    h = (word >> 16) & 0xFFFF if (off & 2) else word & 0xFFFF
                    val = (h - 65536 if (f3 == 0x1 and h & 0x8000) else h)
                else:
                    mem_rmask = 0xF
                    val = word
                rd_addr, rd_wdata = d["rd"], u32(val)

        # ---- stores -------------------------------------------------------
        elif op == 0x23:
            vaddr = u32(rs1_v + d["imm"])
            alu_result = vaddr
            off = vaddr & 0x3
            misaligned = ((f3 == 0x1) and (off & 1)) or ((f3 == 0x2) and off)
            if misaligned:
                trap = 1
            else:
                if f3 == 0x0:
                    mem_wmask = 0x1 << off
                    mem_wdata = u32((rs2_v & 0xFF) << (8 * off))
                elif f3 == 0x1:
                    mem_wmask = 0x3 << off
                    mem_wdata = u32((rs2_v & 0xFFFF) << (8 * off))
                elif f3 == 0x2:
                    mem_wmask = 0xF
                    mem_wdata = u32(rs2_v)
                mem_rdata = self.load_word(vaddr & ~0x3)
                self.store_word(vaddr & ~0x3, mem_wdata, mem_wmask)

        # ---- commit -------------------------------------------------------
        # A trapping instruction commits neither a register write nor a store.
        if trap:
            rd_addr, rd_wdata = 0, 0
            mem_rmask = mem_wmask = 0
        if rd_addr == 0:
            rd_wdata = 0
        else:
            self.x[rd_addr] = rd_wdata
        self.x[0] = 0

        rec = {
            "order": self.order,
            "insn": "%08x" % insn,
            "trap": trap,
            "pc_rdata": "%08x" % pc,
            "pc_wdata": "%08x" % pc_next,
            "rs1_addr": d["rs1"], "rs1_rdata": "%08x" % rs1_v,
            "rs2_addr": d["rs2"], "rs2_rdata": "%08x" % rs2_v,
            "rd_addr": rd_addr,   "rd_wdata": "%08x" % rd_wdata,
            "mem_addr": "%08x" % (alu_result & ~0x3),
            "mem_rmask": mem_rmask, "mem_wmask": mem_wmask,
            "mem_rdata": "%08x" % mem_rdata,
            "mem_wdata": "%08x" % mem_wdata,
        }
        self.pc = pc_next
        self.order += 1
        return rec


def run(instructions, pc=RESET_PC):
    m = Model(pc)
    return [m.step(i) for i in instructions]


def read_hex(path):
    src = sys.stdin if path == "-" else open(path)
    out = []
    for line in src:
        line = line.split("#")[0].strip()
        if line:
            out.append(int(line, 16))
    return out


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: model.py <hexfile|->", file=sys.stderr)
        sys.exit(2)
    for rec in run(read_hex(sys.argv[1])):
        print(json.dumps(rec, separators=(",", ":")))
