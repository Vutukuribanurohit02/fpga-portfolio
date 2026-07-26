// control.sv - RV32I control unit: opcode/funct3/funct7 -> datapath control signals
module control (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,

    output logic [3:0] alu_op,      // matches rv32i_alu.sv op encoding
    output logic       alu_src_b,   // 0 = rs2, 1 = immediate
    output logic       reg_write,
    output logic       mem_read,
    output logic       mem_write,
    output logic       mem_to_reg,  // 0 = ALU result, 1 = memory data
    output logic       branch,
    output logic       jump,        // JAL/JALR: unconditional PC change
    output logic       jalr,        // 1 = JALR (PC = rs1 + imm), 0 = JAL (PC = PC + imm)
    output logic       is_lui,      // 1 = write immediate directly, bypass ALU
    output logic       is_auipc     // 1 = write PC + immediate, bypass ALU
);

    localparam logic [6:0]
        OP_LUI    = 7'b0110111,
        OP_AUIPC  = 7'b0010111,
        OP_JAL    = 7'b1101111,
        OP_JALR   = 7'b1100111,
        OP_BRANCH = 7'b1100011,
        OP_LOAD   = 7'b0000011,
        OP_STORE  = 7'b0100011,
        OP_IMM    = 7'b0010011,
        OP_REG    = 7'b0110011;

    // ALU op encoding (matches Project 3 rv32i_alu.sv)
    // Must match rv32i_alu.sv (module `alu`) exactly.
    localparam logic [3:0]
        ALU_ADD  = 4'b0000, ALU_SUB  = 4'b0001, ALU_AND  = 4'b0010, ALU_OR   = 4'b0011,
        ALU_XOR  = 4'b0100, ALU_SLT  = 4'b0101, ALU_SLTU = 4'b0110, ALU_SLL  = 4'b0111,
        ALU_SRL  = 4'b1000, ALU_SRA  = 4'b1001;

    always_comb begin
        // Safe defaults
        alu_op     = ALU_ADD;
        alu_src_b  = 1'b0;
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        is_lui     = 1'b0;
        is_auipc   = 1'b0;

        case (opcode)
            OP_REG: begin
                reg_write = 1'b1;
                alu_src_b = 1'b0;
                case ({funct7[5], funct3})
                    4'b0_000: alu_op = ALU_ADD;
                    4'b1_000: alu_op = ALU_SUB;
                    4'b0_001: alu_op = ALU_SLL;
                    4'b0_010: alu_op = ALU_SLT;
                    4'b0_011: alu_op = ALU_SLTU;
                    4'b0_100: alu_op = ALU_XOR;
                    4'b0_101: alu_op = ALU_SRL;
                    4'b1_101: alu_op = ALU_SRA;
                    4'b0_110: alu_op = ALU_OR;
                    4'b0_111: alu_op = ALU_AND;
                    default:  alu_op = ALU_ADD;
                endcase
            end

            OP_IMM: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;   // ADDI
                    3'b010: alu_op = ALU_SLT;   // SLTI
                    3'b011: alu_op = ALU_SLTU;  // SLTIU
                    3'b100: alu_op = ALU_XOR;   // XORI
                    3'b110: alu_op = ALU_OR;    // ORI
                    3'b111: alu_op = ALU_AND;   // ANDI
                    3'b001: alu_op = ALU_SLL;   // SLLI
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL;  // SRAI/SRLI
                    default: alu_op = ALU_ADD;
                endcase
            end

            OP_LOAD: begin
                reg_write  = 1'b1;
                alu_src_b  = 1'b1;
                alu_op     = ALU_ADD;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
            end

            OP_STORE: begin
                alu_src_b = 1'b1;
                alu_op    = ALU_ADD;
                mem_write = 1'b1;
            end

            OP_BRANCH: begin
                alu_src_b = 1'b0;
                branch    = 1'b1;
                case (funct3)
                    3'b000, 3'b001: alu_op = ALU_SUB;   // BEQ/BNE
                    3'b100, 3'b101: alu_op = ALU_SLT;   // BLT/BGE
                    3'b110, 3'b111: alu_op = ALU_SLTU;  // BLTU/BGEU
                    default:        alu_op = ALU_SUB;
                endcase
            end

            OP_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                jalr      = 1'b0;
            end

            OP_JALR: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1;
                alu_op    = ALU_ADD;
                jump      = 1'b1;
                jalr      = 1'b1;
            end

            OP_LUI: begin
                reg_write = 1'b1;
                is_lui    = 1'b1;
            end

            OP_AUIPC: begin
                reg_write = 1'b1;
                is_auipc  = 1'b1;
            end

            default: ; // NOP / unimplemented opcode: all defaults hold
        endcase
    end

endmodule
