
module top;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import uartswitch_tb_pkg::*;

    bfm_if bfm();

    simple_switch_uart u_simple_switch_uart (
        .clk  (bfm.clk),
        .prog (bfm.prog),
        .rst_n(bfm.rst_n),
        .sin  (bfm.sin),
        .sout0(bfm.sout0),
        .sout1(bfm.sout1)
    );

    initial begin
        uvm_config_db#(virtual bfm_if)::set(null, "*", "bfm", bfm);
        run_test();
    end

endmodule : top