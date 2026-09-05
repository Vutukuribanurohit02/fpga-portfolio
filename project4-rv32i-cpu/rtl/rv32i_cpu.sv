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
    output logic [2:0]  data_funct3,
    output logic        data_read,
    output logic        data_write,
    output logic [31:0] data_wdata,
    input  logic [31:0] data_rdata
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

    // ---- Register file ----
    logic [31:0] rs1_data, rs2_data, rd_data;

    regfile u_regfile (
        .clk(clk), .rst_n(rst_n),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .we(reg_write), .rd_addr(rd_addr), .rd_data(rd_data)
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

    // ---- Data memory interface ----
    logic [31:0] mem_rdata;
    assign data_addr   = alu_result;
    assign data_funct3 = funct3;
    assign data_read   = mem_read;
    assign data_write  = mem_write;
    assign data_wdata  = rs2_data;
    assign mem_rdata   = data_rdata;

    // ---- Writeback mux ----
    always_comb begin
        if (is_lui)         rd_data = imm;
        else if (is_auipc)  rd_data = pc + imm;
        else if (jump)      rd_data = pc_plus4;         // JAL/JALR: link register
        else if (mem_to_reg) rd_data = mem_rdata;        // load
        else                rd_data = alu_result;         // ALU op
    end


endmodule
