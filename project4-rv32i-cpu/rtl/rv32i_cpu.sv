// rv32i_cpu.sv - Single-cycle RV32I CPU, Von Neumann unified memory
module rv32i_cpu #(
    parameter int MEM_BYTES = 8192,
    parameter logic [31:0] RESET_PC = 32'h0
)(
    input  logic clk,
    input  logic rst_n,

    // Instruction fetch
    output logic [31:0] instr_addr,
    input  logic [31:0] instr_data,

    // Data memory
    output logic [31:0] data_addr,
    output logic [3:0]  data_wstrb,
    output logic [31:0] data_wdata,
    input  logic [31:0] data_rdata

`ifdef RISCV_FORMAL
    ,
    output wire         rvfi_valid,
    output logic [63:0] rvfi_order,
    output logic [31:0] rvfi_insn,
    output logic        rvfi_trap,
    output logic        rvfi_halt,
    output logic        rvfi_intr,
    output logic [1:0]  rvfi_mode,
    output logic [1:0]  rvfi_ixl,
    output logic [4:0]  rvfi_rs1_addr,
    output logic [4:0]  rvfi_rs2_addr,
    output logic [31:0] rvfi_rs1_rdata,
    output logic [31:0] rvfi_rs2_rdata,
    output logic [4:0]  rvfi_rd_addr,
    output logic [31:0] rvfi_rd_wdata,
    output logic [31:0] rvfi_pc_rdata,
    output logic [31:0] rvfi_pc_wdata,
    output logic [31:0] rvfi_mem_addr,
    output logic [3:0]  rvfi_mem_rmask,
    output logic [3:0]  rvfi_mem_wmask,
    output logic [31:0] rvfi_mem_rdata,
    output logic [31:0] rvfi_mem_wdata
`endif

`ifdef FORMAL
    // Formal-only observation ports. Wired by same-scope assigns below so
    // proofs bind without hierarchical dot-paths.
    ,
    output logic [2:0]  dbg_funct3,
    output logic        dbg_branch,
    output logic        dbg_jump,
    output logic        dbg_jalr,
    output logic [31:0] dbg_alu_result,
    output logic [31:0] dbg_pc,
    output logic [31:0] dbg_imm,
    output logic [31:0] dbg_rs1_data,
    output logic        dbg_branch_taken,
    output logic [31:0] dbg_pc_next
`endif
);

    // ---- Program Counter ----
    logic [31:0] pc, pc_next, pc_plus4;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= RESET_PC;
        else        pc <= pc_next;
    end
    assign pc_plus4 = pc + 32'd4;

    // ---- Fetch ----
    logic [31:0] instr;
    assign instr_addr = pc;
    assign instr      = instr_data;

    // ---- Decode ----
    logic [6:0]  opcode, funct7;
    logic [4:0]  rd_addr, rs1_addr, rs2_addr;
    logic [2:0]  funct3;
    logic [31:0] imm;

    decoder u_decoder (
        .instr(instr), .opcode(opcode), .rd(rd_addr), .funct3(funct3),
        .rs1(rs1_addr), .rs2(rs2_addr), .funct7(funct7), .imm(imm)
    );

    // ---- Control ----
    logic [3:0] alu_op;
    logic       alu_src_b, reg_write, mem_read, mem_write, mem_to_reg;
    logic       branch, jump, jalr, is_lui, is_auipc;

    control u_control (
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .alu_op(alu_op), .alu_src_b(alu_src_b), .reg_write(reg_write),
        .mem_read(mem_read), .mem_write(mem_write), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump), .jalr(jalr),
        .is_lui(is_lui), .is_auipc(is_auipc)
    );

    logic [31:0] mem_vaddr;
    logic        trap_insn_addr, trap_load_addr, trap_store_addr, trap;

    // ---- Register file ----
    logic [31:0] rs1_data, rs2_data, rd_data;

    regfile u_regfile (
        .clk(clk), .rst_n(rst_n),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .we(reg_write && !trap), .rd_addr(rd_addr), .rd_data(rd_data)
    );

    // ---- ALU ----
    logic [31:0] alu_b, alu_result;

    assign alu_b = alu_src_b ? imm : rs2_data;

    logic alu_zero;  // unused by control logic; branch_taken derives its own comparisons

    alu u_alu (
        .a(rs1_data), .b(alu_b), .alu_op(alu_op), .result(alu_result), .zero(alu_zero)
    );

    // ---- Branch decision ----
    logic branch_taken;
    always_comb begin
        branch_taken = 1'b0;
        if (branch) begin
            case (funct3)
                3'b000: branch_taken = (alu_result == 32'b0);   // BEQ (sub==0)
                3'b001: branch_taken = (alu_result != 32'b0);   // BNE (sub!=0)
                3'b100: branch_taken = alu_result[0];           // BLT  (slt result)
                3'b101: branch_taken = ~alu_result[0];          // BGE  (!slt)
                3'b110: branch_taken = alu_result[0];           // BLTU (sltu result)
                3'b111: branch_taken = ~alu_result[0];          // BGEU (!sltu)
                default: branch_taken = 1'b0;
            endcase
        end
    end

    // ---- Next PC ----
    logic [31:0] branch_target, jalr_target;
    assign branch_target = pc + imm;
    assign jalr_target   = (rs1_data + imm) & 32'hFFFFFFFE;  // clear LSB per spec

    always_comb begin
        if (jump)
            pc_next = jalr ? jalr_target : (pc + imm);
        else if (branch_taken)
            pc_next = branch_target;
        else
            pc_next = pc_plus4;
    end

    // ---- Trap detection (RV32I: misaligned instruction and data addresses) ----
    assign mem_vaddr      = alu_result;
    assign trap_insn_addr = (jump || branch_taken) && (pc_next[1:0] != 2'b00);
    assign trap_load_addr = mem_read && (
                              (funct3 == 3'b001 || funct3 == 3'b101) ? mem_vaddr[0] :
                              (funct3 == 3'b010)                     ? |mem_vaddr[1:0] : 1'b0);
    assign trap_store_addr = mem_write && (
                              (funct3 == 3'b001) ? mem_vaddr[0] :
                              (funct3 == 3'b010) ? |mem_vaddr[1:0] : 1'b0);
    assign trap = trap_insn_addr || trap_load_addr || trap_store_addr;

    // ---- Data memory interface ----
    logic [31:0] mem_rdata;
    logic [1:0] byte_off;
    assign data_addr = {alu_result[31:2], 2'b00};
    assign byte_off  = alu_result[1:0];

    // Store: byte strobes and lane-shifted write data
    always_comb begin
        data_wstrb = 4'b0000;
        data_wdata = 32'b0;
        if (mem_write && !trap) begin
            case (funct3)
                3'b000: begin
                    data_wstrb = 4'b0001 << byte_off;
                    data_wdata = {24'b0, rs2_data[7:0]} << (8*byte_off);
                end
                3'b001: begin
                    data_wstrb = 4'b0011 << byte_off;
                    data_wdata = {16'b0, rs2_data[15:0]} << (8*byte_off);
                end
                3'b010: begin
                    data_wstrb = 4'b1111;
                    data_wdata = rs2_data;
                end
                default: ;
            endcase
        end
    end

    // Load: byte/half select from the raw word, then extend per funct3
    logic [7:0]  ld_b;
    logic [15:0] ld_h;
    logic [31:0] load_ext;
    always_comb begin
        ld_b = data_rdata[8*byte_off +: 8];
        ld_h = byte_off[1] ? data_rdata[31:16] : data_rdata[15:0];
        case (funct3)
            3'b000:  load_ext = {{24{ld_b[7]}},  ld_b};   // LB
            3'b001:  load_ext = {{16{ld_h[15]}}, ld_h};   // LH
            3'b010:  load_ext = data_rdata;               // LW
            3'b100:  load_ext = {24'b0, ld_b};            // LBU
            3'b101:  load_ext = {16'b0, ld_h};            // LHU
            default: load_ext = 32'b0;
        endcase
    end
    assign mem_rdata = mem_read ? load_ext : 32'b0;

    // ---- Writeback mux ----
    always_comb begin
        if (is_lui)         rd_data = imm;
        else if (is_auipc)  rd_data = pc + imm;
        else if (jump)      rd_data = pc_plus4;         // JAL/JALR: link register
        else if (mem_to_reg) rd_data = mem_rdata;        // load
        else                rd_data = alu_result;         // ALU op
    end


`ifdef FORMAL
    assign dbg_funct3       = funct3;
    assign dbg_branch       = branch;
    assign dbg_jump         = jump;
    assign dbg_jalr         = jalr;
    assign dbg_alu_result   = alu_result;
    assign dbg_pc           = pc;
    assign dbg_imm          = imm;
    assign dbg_rs1_data     = rs1_data;
    assign dbg_branch_taken = branch_taken;
    assign dbg_pc_next      = pc_next;
`endif

`ifdef RISCV_FORMAL
    // Single-cycle: exactly one instruction retires per clock once out of
    // reset, so rvfi_valid is simply "not in reset" and order is a counter.
    logic [3:0] ld_rmask;
    always_comb begin
        case (funct3)
            3'b000, 3'b100: ld_rmask = 4'b0001 << byte_off;  // LB / LBU
            3'b001, 3'b101: ld_rmask = 4'b0011 << byte_off;  // LH / LHU
            3'b010:         ld_rmask = 4'b1111;              // LW
            default:        ld_rmask = 4'b0000;
        endcase
    end

    // Single-cycle: the instruction at `pc` retires this cycle, so valid is
    // combinational and every payload field describes the same instruction.
    logic rvfi_out_of_reset;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvfi_out_of_reset <= 1'b0;
            rvfi_order        <= 64'd0;
        end else begin
            rvfi_out_of_reset <= 1'b1;
            if (rvfi_valid) rvfi_order <= rvfi_order + 64'd1;
        end
    end
    assign rvfi_valid = rvfi_out_of_reset;

    assign rvfi_insn      = instr;
    assign rvfi_trap      = trap;
    assign rvfi_halt      = 1'b0;
    assign rvfi_intr      = 1'b0;
    assign rvfi_mode      = 2'd3;
    assign rvfi_ixl       = 2'd1;

    assign rvfi_rs1_addr  = rs1_addr;
    assign rvfi_rs2_addr  = rs2_addr;
    assign rvfi_rs1_rdata = rs1_data;
    assign rvfi_rs2_rdata = rs2_data;
    assign rvfi_rd_addr   = (reg_write && !trap) ? rd_addr : 5'd0;
    assign rvfi_rd_wdata  = (reg_write && !trap && rd_addr != 5'd0) ? rd_data : 32'd0;

    assign rvfi_pc_rdata  = pc;
    assign rvfi_pc_wdata  = pc_next;

    assign rvfi_mem_addr  = data_addr;
    assign rvfi_mem_rmask = (mem_read && !trap) ? ld_rmask : 4'b0000;
    assign rvfi_mem_wmask = trap ? 4'b0000 : data_wstrb;
    assign rvfi_mem_rdata = data_rdata;
    assign rvfi_mem_wdata = data_wdata;
`endif

endmodule
