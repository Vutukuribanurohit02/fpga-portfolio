`define FORMAL

module alu_formal_top (
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [3:0]  alu_op
);

    logic [31:0] result;
    logic        zero;

    alu #(.WIDTH(32)) dut (
        .a(a), .b(b), .alu_op(alu_op), .result(result), .zero(zero)
    );

    alu_formal #(.WIDTH(32)) props (
        .a(a), .b(b), .alu_op(alu_op), .result(result), .zero(zero)
    );

endmodule
