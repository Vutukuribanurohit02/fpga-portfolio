// Opcode-pinned wrappers. `zero` left unconnected so only the
// 32 result bits are primary outputs, matching Table III's ALU scope.

module alu_add (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0000), .result(result), .zero());
endmodule

module alu_and (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0010), .result(result), .zero());
endmodule

module alu_xor (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);
    alu #(.WIDTH(32)) u (.a(a), .b(b), .alu_op(4'b0100), .result(result), .zero());
endmodule
