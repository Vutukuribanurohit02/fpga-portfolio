// sim_main.cpp — Direct Instruction Injection harness for rv32i_cpu.
//
// Instead of fetching from a memory image, the core's fetch response is
// answered from a queue of instructions supplied on the command line. That is
// what "direct instruction injection" means: no linker script, no ELF, no
// memory layout — just a sequence of 32-bit words fed straight into the
// fetch path, one per retirement.
//
// Each retired instruction is printed as one JSON line carrying the full RVFI
// payload, so the trace can be diffed field-by-field against a reference model.
//
// Usage:  ./dii_sim <hexfile>          one 8-digit hex instruction per line
//         ./dii_sim -                  read the same from stdin

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include <fstream>
#include <iostream>

#include "Vrv32i_cpu.h"
#include "verilated.h"

// ---------------------------------------------------------------- data memory
// A flat 64 KB array. Loads are combinational (the core expects same-cycle
// visibility); stores are applied on the clock edge, byte-strobed.
static const uint32_t DMEM_BYTES = 1u << 16;
static uint8_t dmem[DMEM_BYTES];

static inline uint32_t dmem_read(uint32_t addr) {
    uint32_t a = addr & (DMEM_BYTES - 4);
    return (uint32_t)dmem[a]
         | ((uint32_t)dmem[a + 1] << 8)
         | ((uint32_t)dmem[a + 2] << 16)
         | ((uint32_t)dmem[a + 3] << 24);
}

static inline void dmem_write(uint32_t addr, uint32_t data, uint8_t strb) {
    uint32_t a = addr & (DMEM_BYTES - 4);
    if (strb & 0x1) dmem[a]     = (uint8_t)(data);
    if (strb & 0x2) dmem[a + 1] = (uint8_t)(data >> 8);
    if (strb & 0x4) dmem[a + 2] = (uint8_t)(data >> 16);
    if (strb & 0x8) dmem[a + 3] = (uint8_t)(data >> 24);
}

// ------------------------------------------------------------- instruction in
static std::vector<uint32_t> load_instructions(const char *path) {
    std::vector<uint32_t> v;
    std::istream *in = &std::cin;
    std::ifstream f;
    if (strcmp(path, "-") != 0) {
        f.open(path);
        if (!f) { fprintf(stderr, "cannot open %s\n", path); exit(2); }
        in = &f;
    }
    std::string line;
    while (std::getline(*in, line)) {
        // strip comments and whitespace
        size_t h = line.find('#');
        if (h != std::string::npos) line = line.substr(0, h);
        size_t b = line.find_first_not_of(" \t\r\n");
        if (b == std::string::npos) continue;
        size_t e = line.find_last_not_of(" \t\r\n");
        std::string tok = line.substr(b, e - b + 1);
        v.push_back((uint32_t)strtoul(tok.c_str(), nullptr, 16));
    }
    return v;
}

// ------------------------------------------------------------------ trace out
static void emit(Vrv32i_cpu *dut) {
    // One JSON object per retired instruction. Field names match the RVFI
    // signal names exactly so the Python differ needs no translation table.
    printf("{"
           "\"order\":%llu,"
           "\"insn\":\"%08x\","
           "\"trap\":%u,"
           "\"pc_rdata\":\"%08x\",\"pc_wdata\":\"%08x\","
           "\"rs1_addr\":%u,\"rs1_rdata\":\"%08x\","
           "\"rs2_addr\":%u,\"rs2_rdata\":\"%08x\","
           "\"rd_addr\":%u,\"rd_wdata\":\"%08x\","
           "\"mem_addr\":\"%08x\","
           "\"mem_rmask\":%u,\"mem_wmask\":%u,"
           "\"mem_rdata\":\"%08x\",\"mem_wdata\":\"%08x\""
           "}\n",
           (unsigned long long)dut->rvfi_order,
           (unsigned)dut->rvfi_insn,
           (unsigned)dut->rvfi_trap,
           (unsigned)dut->rvfi_pc_rdata, (unsigned)dut->rvfi_pc_wdata,
           (unsigned)dut->rvfi_rs1_addr, (unsigned)dut->rvfi_rs1_rdata,
           (unsigned)dut->rvfi_rs2_addr, (unsigned)dut->rvfi_rs2_rdata,
           (unsigned)dut->rvfi_rd_addr,  (unsigned)dut->rvfi_rd_wdata,
           (unsigned)dut->rvfi_mem_addr,
           (unsigned)dut->rvfi_mem_rmask, (unsigned)dut->rvfi_mem_wmask,
           (unsigned)dut->rvfi_mem_rdata, (unsigned)dut->rvfi_mem_wdata);
}

// ----------------------------------------------------------------------- main
int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    if (argc < 2) {
        fprintf(stderr, "usage: %s <hexfile|->\n", argv[0]);
        return 2;
    }

    std::vector<uint32_t> prog = load_instructions(argv[1]);
    if (prog.empty()) { fprintf(stderr, "no instructions\n"); return 2; }

    memset(dmem, 0, sizeof(dmem));
    Vrv32i_cpu *dut = new Vrv32i_cpu;

    // ---- reset: hold low for two full clocks -------------------------------
    dut->rst_n = 0;
    dut->instr_data = 0x00000013;   // NOP (addi x0, x0, 0)
    dut->data_rdata = 0;
    for (int i = 0; i < 4; i++) {
        dut->clk = i & 1;
        dut->eval();
    }
    dut->rst_n = 1;

    // Warm-up: rvfi_valid rises one cycle after reset deasserts, so run a
    // single NOP first. Without this the core executes prog[0] on that edge
    // while valid is still low, the queue index doesn't advance, and prog[0]
    // gets injected a second time.
    dut->instr_data = 0x00000013;   // addi x0, x0, 0
    dut->clk = 0; dut->eval();
    dut->data_rdata = dmem_read(dut->data_addr);
    dut->eval();
    dut->clk = 1; dut->eval();

    // ---- run ---------------------------------------------------------------
    // Single-cycle core: one instruction retires per clock. The injection
    // index advances with rvfi_order rather than with the PC, which is the
    // defining property of DII — control flow does not select the next
    // instruction, the queue does.
    size_t idx = 0;
    const size_t limit = prog.size();

    while (idx < limit) {
        // --- present fetch and load data before the low phase settles -------
        dut->instr_data = prog[idx];
        dut->clk = 0;
        dut->eval();
        dut->data_rdata = dmem_read(dut->data_addr);
        dut->eval();

        // capture the store request decided in this cycle
        uint32_t st_addr  = dut->data_addr;
        uint32_t st_data  = dut->data_wdata;
        uint8_t  st_strb  = (uint8_t)dut->data_wstrb;

        // Sample here, in the low phase: rvfi_valid was registered on the
        // previous edge, and pc/insn still describe the instruction executing
        // now. Sampling after the rising edge reports the *next* PC.
        bool retired = dut->rvfi_valid;
        if (retired) { emit(dut); idx++; }

        // --- rising edge: state commits ------------------------------------
        dut->clk = 1;
        dut->eval();

        if (st_strb) dmem_write(st_addr, st_data, st_strb);
    }

    dut->final();
    delete dut;
    return 0;
}
