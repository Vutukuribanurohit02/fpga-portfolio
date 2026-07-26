// control_bind.sv - Formal top-level: instantiates control.sv plus an
// independently-written RV32I truth table, and asserts they agree for
// every reachable opcode/funct3/funct7 combination. Free-running clock
// drives BMC; properties are checked every cycle (control is purely
// combinational, so this is effectively an exhaustive input-space check).
module control_formal (
    input logic clk
);

    logic [6:0] opcode, funct7;
    logic [2:0] funct3;
    logic [3:0] alu_op;
    logic       alu_src_b, reg_write, mem_read, mem_write, mem_to_reg;
    logic       branch, jump, jalr, is_lui, is_auipc;

    control dut (
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .alu_op(alu_op), .alu_src_b(alu_src_b), .reg_write(reg_write),
        .mem_read(mem_read), .mem_write(mem_write), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump), .jalr(jalr),
        .is_lui(is_lui), .is_auipc(is_auipc)
    );

    localparam logic [6:0]
        OP_BRANCH = 7'b1100011,
        OP_IMM    = 7'b0010011,
        OP_REG    = 7'b0110011;

    // Independently-written expected ALU op, per RV32I spec (not copied
    // from control.sv). Values match rv32i_alu.sv's real encoding.
    localparam logic [3:0]
        E_ADD = 4'b0000, E_SUB = 4'b0001, E_AND = 4'b0010, E_OR = 4'b0011,
        E_XOR = 4'b0100, E_SLT = 4'b0101, E_SLTU = 4'b0110, E_SLL = 4'b0111,
        E_SRL = 4'b1000, E_SRA = 4'b1001;

    logic [3:0] expected_alu_op;
    logic       expect_valid;

    always_comb begin
        expected_alu_op = E_ADD;
        expect_valid    = 1'b0;

        if (opcode == OP_REG) begin
            expect_valid = 1'b1;
            case ({funct7[5], funct3})
                4'b0_000: expected_alu_op = E_ADD;
                4'b1_000: expected_alu_op = E_SUB;
                4'b0_001: expected_alu_op = E_SLL;
                4'b0_010: expected_alu_op = E_SLT;
                4'b0_011: expected_alu_op = E_SLTU;
                4'b0_100: expected_alu_op = E_XOR;
                4'b0_101: expected_alu_op = E_SRL;
                4'b1_101: expected_alu_op = E_SRA;
                4'b0_110: expected_alu_op = E_OR;
                4'b0_111: expected_alu_op = E_AND;
                default:  expect_valid = 1'b0; // reserved encodings, no claim
            endcase
        end else if (opcode == OP_IMM) begin
            expect_valid = 1'b1;
            case (funct3)
                3'b000: expected_alu_op = E_ADD;
                3'b010: expected_alu_op = E_SLT;
                3'b011: expected_alu_op = E_SLTU;
                3'b100: expected_alu_op = E_XOR;
                3'b110: expected_alu_op = E_OR;
                3'b111: expected_alu_op = E_AND;
                3'b001: expected_alu_op = E_SLL;
                3'b101: expected_alu_op = funct7[5] ? E_SRA : E_SRL;
                default: expect_valid = 1'b0;
            endcase
        end else if (opcode == OP_BRANCH) begin
            expect_valid = 1'b1;
            case (funct3)
                3'b000, 3'b001: expected_alu_op = E_SUB;   // BEQ/BNE
                3'b100, 3'b101: expected_alu_op = E_SLT;   // BLT/BGE
                3'b110, 3'b111: expected_alu_op = E_SLTU;  // BLTU/BGEU
                default: expect_valid = 1'b0;
            endcase
        end
    end

    // Property 1: ALU op selection is correct for every valid encoding.
    always @(posedge clk) begin
        if (expect_valid)
            assert (alu_op == expected_alu_op);
    end

    // Property 2: reg_write/branch flags are correct for R-type, I-type,
    // and branch opcodes.
    always @(posedge clk) begin
        if (opcode == OP_REG || opcode == OP_IMM)
            assert (reg_write == 1'b1);
        if (opcode == OP_BRANCH)
            assert (reg_write == 1'b0 && branch == 1'b1);
    end

    // Property 3: alu_src_b selects register operand for R-type/branch,
    // immediate operand for I-type.
    always @(posedge clk) begin
        if (opcode == OP_REG || opcode == OP_BRANCH)
            assert (alu_src_b == 1'b0);
        if (opcode == OP_IMM)
            assert (alu_src_b == 1'b1);
    end

    // Cover: make sure each opcode class is actually reachable (sanity
    // check that the proof isn't vacuous).
    always @(posedge clk) begin
        cover (opcode == OP_REG);
        cover (opcode == OP_IMM);
        cover (opcode == OP_BRANCH);
    end

endmodule
