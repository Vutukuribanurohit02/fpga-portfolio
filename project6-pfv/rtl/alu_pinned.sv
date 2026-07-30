// alu_pinned.sv -- opcode-pinned wrappers, one module per ALU operation.
//
// Each wrapper ties alu_op to a constant so Yosys constant propagation can
// delete the nine unselected datapaths, leaving that instruction's
// sub-circuit alone. `zero` is left unconnected so only the 32 result bits
// are primary outputs, matching the scope of the paper's Table III.
//
// Generated to match the encoding in alu.sv -- do not hand-edit the opcodes.

module alu_add (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0000), .result(result), .zero());
endmodule

module alu_sub (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0001), .result(result), .zero());
endmodule

module alu_and (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0010), .result(result), .zero());
endmodule

module alu_or (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0011), .result(result), .zero());
endmodule

module alu_xor (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0100), .result(result), .zero());
endmodule

module alu_slt (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0101), .result(result), .zero());
endmodule

module alu_sltu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0110), .result(result), .zero());
endmodule

module alu_sll (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0111), .result(result), .zero());
endmodule

module alu_srl (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b1000), .result(result), .zero());
endmodule

module alu_sra (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b1001), .result(result), .zero());
endmodule
