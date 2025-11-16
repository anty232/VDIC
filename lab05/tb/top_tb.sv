
module simple_uart_switch_tb;
    import uartswitch_tb_pkg::*;

    bfm_if bfm();
    testbench tb_h;

    simple_switch_uart u_simple_switch_uart (
        .clk  (bfm.clk),
        .prog (bfm.prog),
        .rst_n(bfm.rst_n),
        .sin  (bfm.sin),
        .sout0(bfm.sout0),
        .sout1(bfm.sout1)
    );

    initial begin
        tb_h = new(bfm);
        tb_h.execute();
    end

endmodule : simple_uart_switch_tb