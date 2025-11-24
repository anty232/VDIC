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
    // Monitor callbacks
    //------------------------------------------------------------------------------
    command_monitor command_monitor_h;
    result_monitor  result_monitor_h;

    //------------------------------------------------------------------------------
    // Configuration
    //------------------------------------------------------------------------------
    time timeout_cycles = TIMEOUT_CYCLES;

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

    //------------------------------------------------------------------------------
    // Helper routines for monitoring
    //------------------------------------------------------------------------------
    function automatic int get_expected_port(input logic [7:0] addr);
        foreach (routing_table[i]) begin
            if (routing_table[i].addr == addr)
                return routing_table[i].port;
        end
        return -1;
    endfunction : get_expected_port

    task automatic wait_for_next_start_bit(
        ref logic serial_line,
        input string port_name,
        output bit start_found
    );
        longint wait_limit = timeout_cycles;
        start_found = 0;

        while (wait_limit > 0) begin
            bit prev_local = serial_line;
            @(posedge clk);
            wait_limit--;
            if (prev_local === 1 && serial_line === 0) begin
                start_found = 1;
                return;
            end
        end

        print_colored($sformatf("[%0t] Nie wykryto kolejnego bitu start na %s",
                                $time, port_name), "yellow");
    endtask

    task automatic collect_uart_frames(
        ref logic serial_line,
        input string port_name,
        ref uart_frame_t frame_queue[$],
        input bit warn_incomplete
    );
        bit start_found;

        frame_queue.delete();

        for (int frame_idx = 0; frame_idx < MONITOR_FRAMES; frame_idx++) begin
            uart_frame_t frame;

            if (frame_idx == 0) begin
                frame.start_bit = serial_line;
            end
            else begin
                wait_for_next_start_bit(serial_line, port_name, start_found);
                if (!start_found)
                    break;

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

        if (frame_queue.size() < MONITOR_FRAMES && warn_incomplete) begin
            print_colored($sformatf(
                                "[%0t] Ostrzezenie  oczekiwano %0d ramek, zebrano %0d na %s",
                                $time, MONITOR_FRAMES, frame_queue.size(), port_name),
                          "yellow");
        end
    endtask

    //------------------------------------------------------------------------------
    // Monitor threads
    //------------------------------------------------------------------------------
    task automatic monitor_uart_input();
        if (prog === 1'b1) begin
            @(negedge prog);  // koniec programowania
        end
        else begin
            @(posedge prog);  // start programowania
            @(negedge prog);  // koniec programowania
        end
        
        forever begin
            input_transaction_t tx;
            uart_frame_t        frames[$];
            bit                 start_found;




            wait_for_next_start_bit(sin, "sin", start_found);

            if (!start_found) begin
                tx.valid = 0;
                command_monitor_h.write_to_monitor(tx);
                continue;
            end

            collect_uart_frames(sin, "sin", frames, 1'b0);

            tx.frames           = frames;
            tx.addr             = (frames.size() > 0) ? frames[0].data : '0;
            tx.port             = get_expected_port(tx.addr);
            tx.test_name        = $sformatf("captured_tx_%0t", $time);
            tx.valid            = (frames.size() > 0);
            tx.expect_no_output = (tx.port == -1);

            command_monitor_h.write_to_monitor(tx);
        end
    endtask : monitor_uart_input

    task automatic monitor_uart_output(
        input string port_name,
        ref logic serial_line,
        input int port
    );
        forever begin
            result_packet_t pkt;
            uart_frame_t    frames[$];
            bit             start_found;


            if (prog) begin
                wait (!prog);
            end

            wait_for_next_start_bit(serial_line, port_name, start_found);

            if (!start_found) begin
                pkt.port      = port;
                pkt.frames    = frames;
                pkt.timed_out = 1'b1;
                result_monitor_h.write_to_monitor(pkt);
                continue;
            end

            collect_uart_frames(serial_line, port_name, frames, 1'b1);

            pkt.port      = port;
            pkt.frames    = frames;
            pkt.timed_out = 1'b0;

            
            result_monitor_h.write_to_monitor(pkt);
        end
    endtask : monitor_uart_output

    initial begin : command_monitor_thread
        wait (command_monitor_h != null);
        monitor_uart_input();
    end

    initial begin : result_monitor_threads
        wait (result_monitor_h != null);
        fork
            monitor_uart_output("sout0", sout0, 0);
            monitor_uart_output("sout1", sout1, 1);
        join_none
    end  
endinterface : bfm_if