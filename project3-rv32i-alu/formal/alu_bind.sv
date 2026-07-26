// alu_bind.sv - Formal properties for the RV32I ALU
// Combinational design -- properties are checked at every timestep with
// no notion of "previous state" needed, since there are no registers.
`ifdef FORMAL
module alu_formal #(
    parameter int WIDTH = 32
)(
    input logic [WIDTH-1:0] a,
    input logic [WIDTH-1:0] b,
    input logic [3:0]       alu_op,
    input logic [WIDTH-1:0] result,
    input logic              zero
);

    localparam logic [3:0]
        ALU_ADD  = 4'b0000, ALU_SUB  = 4'b0001, ALU_AND  = 4'b0010,
        ALU_OR   = 4'b0011, ALU_XOR  = 4'b0100, ALU_SLT  = 4'b0101,
        ALU_SLTU = 4'b0110, ALU_SLL  = 4'b0111, ALU_SRL  = 4'b1000,
        ALU_SRA  = 4'b1001;

    logic [4:0] shamt;
    assign shamt = b[4:0];

    logic [WIDTH-1:0] sra_expected;
    assign sra_expected = ({{WIDTH{a[WIDTH-1]}}, a} >> shamt);

    // Each property checks result against the operation's mathematical
    // definition directly (not against the RTL's own case statement --
    // that would be tautological and prove nothing). This is what makes
    // it a real correctness proof rather than a restatement of the design.
    always_comb begin
        if (alu_op == ALU_ADD)  assert (result == a + b);
        if (alu_op == ALU_SUB)  assert (result == a - b);
        if (alu_op == ALU_AND)  assert (result == (a & b));
        if (alu_op == ALU_OR)   assert (result == (a | b));
        if (alu_op == ALU_XOR)  assert (result == (a ^ b));
        if (alu_op == ALU_SLT)  assert (result == {{(WIDTH-1){1'b0}}, ($signed(a) < $signed(b))});
        if (alu_op == ALU_SLTU) assert (result == {{(WIDTH-1){1'b0}}, (a < b)});
        if (alu_op == ALU_SLL)  assert (result == (a << shamt));
        if (alu_op == ALU_SRL)  assert (result == (a >> shamt));
        // SRA property rewritten to avoid a Boolector/SymbiYosys quirk where
        // `$signed(a) >>> shamt` with a variable (non-constant) shamt produced
        // a false counterexample against this exact same RTL expression,
        // despite direct simulation confirming the RTL is correct for that
        // input. This formulation is mathematically equivalent (sign-extend
        // to 64 bits, shift logically, truncate back to 32) but structured
        // differently at the AST level, sidestepping whatever translation
        // issue affects the direct >>> form.
        if (alu_op == ALU_SRA)
            assert (result == sra_expected);

        // Zero flag must always correctly reflect result, regardless of op
        assert (zero == (result == '0));
    end

endmodule
`endif
