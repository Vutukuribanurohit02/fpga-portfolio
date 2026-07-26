// decoder.sv - RV32I instruction field decoder and immediate generator
module decoder (
    input  logic [31:0] instr,

    output logic [6:0]  opcode,
    output logic [4:0]  rd,
    output logic [2:0]  funct3,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [6:0]  funct7,
    output logic [31:0] imm
);

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    // RV32I opcode map (bits [6:0])
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

    always_comb begin
        case (opcode)
            OP_IMM, OP_LOAD, OP_JALR:
                // I-type: sign-extend instr[31:20]
                imm = {{20{instr[31]}}, instr[31:20]};

            OP_STORE:
                // S-type: sign-extend {instr[31:25], instr[11:7]}
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            OP_BRANCH:
                // B-type: sign-extend {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

            OP_LUI, OP_AUIPC:
                // U-type: instr[31:12] << 12
                imm = {instr[31:12], 12'b0};

            OP_JAL:
                // J-type: sign-extend {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            default:
                imm = 32'b0;
        endcase
    end

endmodule
