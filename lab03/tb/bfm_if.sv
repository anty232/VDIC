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

    //------------------------------------------------------------------------------
    // Shared data structures
    //------------------------------------------------------------------------------
    uart_frame_t sent_frames[$];
    uart_frame_t captured_frames_sout0[$];
    uart_frame_t captured_frames_sout1[$];

    bit capture_done_sout0 = 0;
    bit capture_done_sout1 = 0;

    routing_entry_t routing_table[$];

    time timeout_cycles = TIMEOUT_CYCLES;

    //------------------------------------------------------------------------------
    // Coverage signaling
    //------------------------------------------------------------------------------
    logic [7:0]    cov_addr;
    logic [7:0]    cov_data;
    int            cov_port;
    frame_kind_t   cov_err_frame_kind;
    frame_error_t  cov_err_error_type;
    int            cov_rst_port;

    event forwarding_sample_ev;
    event reset_sample_ev;
    event error_sample_ev;

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
    // Routing helpers
    //------------------------------------------------------------------------------
    function int get_expected_port(input logic [7:0] addr);
        foreach (routing_table[i]) begin
            if (routing_table[i].addr == addr)
                return routing_table[i].port;
        end
        return -1;
    endfunction

    task automatic add_routing_entry(input logic [7:0] addr, input logic [7:0] port);
        int found = 0;
        foreach (routing_table[i]) begin
            if (routing_table[i].addr == addr) begin
                routing_table[i].port = port;
                found = 1;
            end
        end
        if (!found)
            routing_table.push_back('{addr, port});
    endtask

    task automatic clear_routing_table();
        routing_table.delete();
    endtask

    //------------------------------------------------------------------------------
    // UART driving utilities
    //------------------------------------------------------------------------------
    task automatic reset_switch();
        rst_n = 1'b0;
        prog  = 1'b1;
        sin   = 1'b1;
        #(10*CLK_PERIOD);
        rst_n = 1'b1;
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

        sent_frames.push_back(frame);
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

        sent_frames.push_back(frame);
    endtask

    task automatic send_uart_packet(input logic [7:0] b0, input logic [7:0] b1);
        send_uart_byte(b0);
        send_uart_byte(b1);
    endtask

    //------------------------------------------------------------------------------
    // Coverage triggers
    //------------------------------------------------------------------------------
    task automatic trigger_forwarding_cov(
        input logic [7:0] addr,
        input logic [7:0] data,
        input int port
    );
        cov_addr = addr;
        cov_data = data;
        cov_port = port;
        -> forwarding_sample_ev;
    endtask

    task automatic trigger_reset_cov(input int port);
        cov_rst_port = port;
        -> reset_sample_ev;
    endtask

    task automatic trigger_error_cov(
        input frame_kind_t frame_kind,
        input frame_error_t error_type
    );
        if (error_type != ERR_NONE) begin
            cov_err_frame_kind = frame_kind;
            cov_err_error_type = error_type;
            -> error_sample_ev;
        end
    endtask

endinterface : bfm_if