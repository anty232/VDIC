interface bfm_if;
    import uartswitch_tb_pkg::*;

    //------------------------------------------------------------------------------
    // DUT connections
    //------------------------------------------------------------------------------
    logic clk;
    logic rst_n;
    logic prog;
    logic sin;
    logic sout0;
    logic sout1;

 /*
    //------------------------------------------------------------------------------
    // Coverage signaling
    //------------------------------------------------------------------------------
    logic [7:0]    cov_addr;
    logic [7:0]    cov_data;
    int            cov_port;
    frame_kind_t   cov_err_frame_kind;
    frame_error_t  cov_err_error_type;
    int            cov_rst_port;
*/

    //------------------------------------------------------------------------------
    // Clock generator and default values
    //------------------------------------------------------------------------------
    initial begin
        clk   = '0;
        rst_n = 1'b0;
        prog  = 1'b0;
        sin   = 1'b1;
        forever begin
            #(CLK_PERIOD/2) clk = ~clk;
        end
    end

    //------------------------------------------------------------------------------
    // UART driving utilities
    //------------------------------------------------------------------------------
    task automatic wait_clock_cycles(input int cycles);
        repeat (cycles) @(posedge clk);
    endtask

    task automatic set_prog(input bit progset);
        prog = progset;
    endtask

    task automatic reset_switch();
        rst_n = 1'b0;
        prog  = 1'b1;
        sin   = 1'b1;
        wait_clock_cycles(10);
        rst_n = 1'b1;
    endtask

    task automatic apply_async_reset(input string reason);
        $display("[%0t] ASYNC RESET start  %s", $time, reason);
        #(CLK_PERIOD/4);
        rst_n = 0;
        wait_clock_cycles(3);
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        $display("[%0t] ASYNC RESET koniec  %s", $time, reason);
    endtask

    task automatic send_uart_byte(input logic [7:0] data);
        uart_frame_t frame;
        bit parity;
        parity = ^data;

        frame.start_bit = 1'b0;
        frame.data      = data;
        frame.parity    = parity;
        frame.stop_bit  = 1'b1;

        sin = frame.start_bit; #(CLK_PERIOD*CLKS_PER_BIT);
        for (int i = 0; i < 8; i++) begin
            sin = frame.data[i];
            #(CLK_PERIOD*CLKS_PER_BIT);
        end
        sin = frame.parity; #(CLK_PERIOD*CLKS_PER_BIT);
        sin = frame.stop_bit; #(CLK_PERIOD*CLKS_PER_BIT);

        //sent_frames.push_back(frame);
    endtask

    task automatic send_uart_byte_custom(
        input bit start_bit,
        input logic [7:0] data,
        input bit parity_bit,
        input bit stop_bit
    );
        uart_frame_t frame;

        frame.start_bit = start_bit;
        frame.data      = data;
        frame.parity    = parity_bit;
        frame.stop_bit  = stop_bit;

        sin = frame.start_bit; #(CLK_PERIOD*CLKS_PER_BIT);
        for (int i = 0; i < 8; i++) begin
            sin = frame.data[i];
            #(CLK_PERIOD*CLKS_PER_BIT);
        end
        sin = frame.parity; #(CLK_PERIOD*CLKS_PER_BIT);
        sin = frame.stop_bit; #(CLK_PERIOD*CLKS_PER_BIT);

        //sent_frames.push_back(frame);
    endtask
    
endinterface : bfm_if