// alu_tb.sv - Self-checking testbench for the RV32I ALU
// Directed test vectors covering each of the 10 operations, including
// edge cases (overflow wraparound, shift-by-zero, shift-by-31, negative
// numbers for signed compare/shift), plus a randomized sweep.

`timescale 1ns/1ps

module alu_tb;

    localparam int WIDTH = 32;

    logic [WIDTH-1:0] a, b;
    logic [3:0]        alu_op;
    logic [WIDTH-1:0] result;
    logic              zero;

    alu #(.WIDTH(WIDTH)) dut (
        .a(a), .b(b), .alu_op(alu_op), .result(result), .zero(zero)
    );

    localparam logic [3:0]
        ALU_ADD  = 4'b0000, ALU_SUB  = 4'b0001, ALU_AND  = 4'b0010,
        ALU_OR   = 4'b0011, ALU_XOR  = 4'b0100, ALU_SLT  = 4'b0101,
        ALU_SLTU = 4'b0110, ALU_SLL  = 4'b0111, ALU_SRL  = 4'b1000,
        ALU_SRA  = 4'b1001;

    int errors = 0;
    int checks = 0;
    logic [WIDTH-1:0] ra, rb, rexp;
    logic [3:0] rop;
    logic [4:0] rshamt;

    task automatic check(input logic [WIDTH-1:0] a_in, input logic [WIDTH-1:0] b_in,
                          input logic [3:0] op_in, input logic [WIDTH-1:0] expected,
                          input string name);
        a = a_in; b = b_in; alu_op = op_in;
        #1;
        checks++;
        if (result !== expected) begin
            $display("[FAIL] %s: a=%h b=%h op=%b -> got %h, expected %h",
                      name, a_in, b_in, op_in, result, expected);
            errors++;
        end
    endtask

    initial begin
        // ADD
        check(32'd5, 32'd3, ALU_ADD, 32'd8, "ADD basic");
        check(32'hFFFFFFFF, 32'd1, ALU_ADD, 32'd0, "ADD overflow wraparound");
        check(32'h7FFFFFFF, 32'd1, ALU_ADD, 32'h80000000, "ADD signed overflow");

        // SUB
        check(32'd10, 32'd3, ALU_SUB, 32'd7, "SUB basic");
        check(32'd0, 32'd1, ALU_SUB, 32'hFFFFFFFF, "SUB underflow wraparound");

        // AND / OR / XOR
        check(32'hF0F0F0F0, 32'h0FF00FF0, ALU_AND, 32'h00F000F0, "AND");
        check(32'hF0F0F0F0, 32'h0FF00FF0, ALU_OR,  32'hFFF0FFF0, "OR");
        check(32'hF0F0F0F0, 32'h0FF00FF0, ALU_XOR, 32'hFF00FF00, "XOR");

        // SLT (signed)
        check(32'd5, 32'd10, ALU_SLT, 32'd1, "SLT true (positive)");
        check(32'd10, 32'd5, ALU_SLT, 32'd0, "SLT false (positive)");
        check(32'hFFFFFFFF, 32'd0, ALU_SLT, 32'd1, "SLT true (-1 < 0, signed)");
        check(32'h80000000, 32'h7FFFFFFF, ALU_SLT, 32'd1, "SLT true (min_int < max_int)");

        // SLTU (unsigned)
        check(32'hFFFFFFFF, 32'd0, ALU_SLTU, 32'd0, "SLTU false (0xFFFFFFFF is huge unsigned)");
        check(32'd0, 32'hFFFFFFFF, ALU_SLTU, 32'd1, "SLTU true");

        // SLL
        check(32'd1, 32'd4, ALU_SLL, 32'd16, "SLL basic");
        check(32'd1, 32'd0, ALU_SLL, 32'd1, "SLL by zero");
        check(32'd1, 32'd31, ALU_SLL, 32'h80000000, "SLL by 31");
        check(32'd1, 32'd32, ALU_SLL, 32'd1, "SLL shamt masks to 5 bits (32 -> 0)");

        // SRL (logical, zero-fill)
        check(32'h80000000, 32'd4, ALU_SRL, 32'h08000000, "SRL basic zero-fill");
        check(32'hFFFFFFFF, 32'd31, ALU_SRL, 32'd1, "SRL by 31");

        // SRA (arithmetic, sign-extend)
        check(32'h80000000, 32'd4, ALU_SRA, 32'hF8000000, "SRA sign-extends negative");
        check(32'h7FFFFFFF, 32'd4, ALU_SRA, 32'h07FFFFFF, "SRA positive behaves like SRL");
        check(32'hFFFFFFFF, 32'd31, ALU_SRA, 32'hFFFFFFFF, "SRA of -1 stays -1 regardless of shift");

        // zero flag
        check(32'd5, 32'd5, ALU_SUB, 32'd0, "zero flag via SUB equal operands");
        if (zero !== 1'b1) begin
            $display("[FAIL] zero flag not asserted when result==0");
            errors++;
        end
        checks++;

        check(32'd5, 32'd3, ALU_SUB, 32'd2, "zero flag stays low on nonzero result");
        if (zero !== 1'b0) begin
            $display("[FAIL] zero flag incorrectly asserted on nonzero result");
            errors++;
        end
        checks++;

        // Randomized sweep against a reference model
        for (int i = 0; i < 500; i++) begin
            ra = $urandom();
            rb = $urandom();
            rop = $urandom_range(0, 9);
            rshamt = rb[4:0];
            case (rop)
                ALU_ADD:  rexp = ra + rb;
                ALU_SUB:  rexp = ra - rb;
                ALU_AND:  rexp = ra & rb;
                ALU_OR:   rexp = ra | rb;
                ALU_XOR:  rexp = ra ^ rb;
                ALU_SLT:  rexp = {{(WIDTH-1){1'b0}}, ($signed(ra) < $signed(rb))};
                ALU_SLTU: rexp = {{(WIDTH-1){1'b0}}, (ra < rb)};
                ALU_SLL:  rexp = ra << rshamt;
                ALU_SRL:  rexp = ra >> rshamt;
                ALU_SRA:  rexp = $signed(ra) >>> rshamt;
                default:  rexp = '0;
            endcase
            check(ra, rb, rop, rexp, $sformatf("random[%0d] op=%0d", i, rop));
        end

        $display("--------------------------------------------------");
        $display("Checks run : %0d", checks);
        $display("Errors     : %0d", errors);
        if (errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
