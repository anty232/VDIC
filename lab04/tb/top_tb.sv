
module simple_uart_switch_tb;
    import uartswitch_tb_pkg::*;

    bfm_if bfm();

    coverage  coverage_i (bfm);
    scoreboard scoreboard_i(bfm);
    tpgen      tpgen_i     (bfm);

    simple_switch_uart u_simple_switch_uart (
        .clk  (bfm.clk),
        .prog (bfm.prog),
        .rst_n(bfm.rst_n),
        .sin  (bfm.sin),
        .sout0(bfm.sout0),
        .sout1(bfm.sout1)
    );

endmodule : simple_uart_switch_tb