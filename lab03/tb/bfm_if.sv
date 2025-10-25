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
    task automatic wait_clock_cycles(input int cycles);
        repeat (cycles) @(posedge clk);
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

    task automatic monitor_uart_output(
        input string port_name,
        ref logic serial_line,
        ref bit capture_done,
        ref uart_frame_t frame_queue[$]
    );
        bit prev;
        longint wait_limit;

        forever begin
            prev = 1'b1;

            fork
                begin : WAIT_START
                    forever begin
                        @(posedge clk);
                        if (prev === 1 && serial_line === 0) begin
                            disable TIMEOUT;
                            $display("[%0t] Start bit wykryty na %s", $time, port_name);

                            frame_queue.delete();
                            capture_done = 0;

                            for (int frame_idx = 0; frame_idx < MONITOR_FRAMES; frame_idx++) begin
                                uart_frame_t frame;
                                bit start_found = 1'b1;

                                if (frame_idx == 0) begin
                                    frame.start_bit = serial_line;
                                end
                                else begin
                                    start_found = 0;
                                    wait_limit = timeout_cycles;
                                    while (wait_limit > 0) begin
                                        bit prev_local = serial_line;
                                        @(posedge clk);
                                        wait_limit--;
                                        if (prev_local === 1 && serial_line === 0) begin
                                            start_found = 1;
                                            break;
                                        end
                                    end

                                    if (!start_found) begin
                                        print_colored($sformatf("[%0t] Nie wykryto kolejnego bitu start na %s",
                                                                $time, port_name), "yellow");
                                        break;
                                    end

                                    frame.start_bit = serial_line;
                                end

                                for (int bit_index = 0; bit_index < 8; bit_index++) begin
                                    repeat (CLKS_PER_BIT) @(posedge clk);
                                    frame.data[bit_index] = serial_line;
                                end

                                repeat (CLKS_PER_BIT) @(posedge clk);
                                frame.parity = serial_line;

                                repeat (CLKS_PER_BIT) @(posedge clk);
                                frame.stop_bit = serial_line;

                                frame_queue.push_back(frame);
                            end

                            capture_done = 1;
                            $display("[%0t] Akwizycja zakonczona, zebrano %0d ramek",
                                     $time, frame_queue.size());

                            foreach (frame_queue[i])
                                $display("    Frame %0d: %s", i, frame_to_string(frame_queue[i]));
                            if (frame_queue.size() < MONITOR_FRAMES)
                                print_colored($sformatf("[%0t] Ostrzezenie  oczekiwano %0d ramek, zebrano %0d",
                                                        $time, MONITOR_FRAMES, frame_queue.size()), "yellow");
                            $write("\n");

                            disable TIMEOUT;
                            disable WAIT_START;
                        end
                        prev = serial_line;
                    end
                end

                begin : TIMEOUT
                    repeat (timeout_cycles) @(posedge clk);
                    capture_done = 1;
                    print_colored($sformatf("[%0t] Timeout na %s  brak start bitu w ciagu %0d cykli",
                                            $time, port_name, timeout_cycles), "yellow");
                    disable WAIT_START;
                end
            join
        end
    endtask

    initial begin
        fork
            monitor_uart_output("sout0", sout0, capture_done_sout0, captured_frames_sout0);
            monitor_uart_output("sout1", sout1, capture_done_sout1, captured_frames_sout1);
        join_none
    end

endinterface : bfm_if