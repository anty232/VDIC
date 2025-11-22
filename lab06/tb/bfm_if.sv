interface bfm_if;
    import uartswitch_tb_pkg::*;

    //------------------------------------------------------------------------------
    // Monitor handles
    //------------------------------------------------------------------------------
    command_monitor command_monitor_h;
    result_monitor  result_monitor_h;


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
    // Data structures
    //------------------------------------------------------------------------------

    time timeout_cycles = TIMEOUT_CYCLES;
    uartswitch_tb_pkg::input_transaction_t current_tx;


    //------------------------------------------------------------------------------
    // Coverage signaling
    //------------------------------------------------------------------------------
    logic [7:0]    cov_addr;
    logic [7:0]    cov_data;
    int            cov_port;
    frame_kind_t   cov_err_frame_kind;
    frame_error_t  cov_err_error_type;
    int            cov_rst_port;


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

    task automatic wait_for_output_capture(input int port);
        case (port)
            0: begin
                if (!capture_done_sout0)
                    @(sout0_capture_done_ev);
            end
            1: begin
                if (!capture_done_sout1)
                    @(sout1_capture_done_ev);
            end
            default: ;
        endcase
    endtask


    task automatic wait_for_input_transaction();
        @(input_capture_done_ev);
    endtask

    //------------------------------------------------------------------------------
    // Monitor helpers
    //------------------------------------------------------------------------------

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


    task automatic monitor_uart_output(
        input string port_name,
        ref logic serial_line,
        ref bit capture_done,
        ref uart_frame_t frame_queue[$]
    );
        bit prev;
        bit timed_out;

        forever begin
            prev = 1'b1;
            

            fork
                begin : WAIT_START
                    forever begin
                        @(posedge clk);
                        if (prev === 1 && serial_line === 0) begin
                            disable TIMEOUT;
                            $display("[%0t] Start bit wykryty na %s", $time, port_name);

                            capture_done = 0;
                            collect_uart_frames(serial_line, port_name, frame_queue, 1'b1);

                            capture_done = 1;
                            if (port_name == "sout0")
                                -> sout0_capture_done_ev;
                            else if (port_name == "sout1")
                                -> sout1_capture_done_ev;
                            $display("[%0t] Akwizycja zakonczona, zebrano %0d ramek",
                                     $time, frame_queue.size());

                            foreach (frame_queue[i])
                                $display("    Frame %0d: %s", i, frame_to_string(frame_queue[i]));
                            $write("\n");

                            timed_out = 0;
                            disable TIMEOUT;
                            disable WAIT_START;
                        end
                        prev = serial_line;
                    end
                end

                begin : TIMEOUT
                    repeat (timeout_cycles) @(posedge clk);
                    capture_done = 1;
                    if (port_name == "sout0")
                        -> sout0_capture_done_ev;
                    else if (port_name == "sout1")
                        -> sout1_capture_done_ev;
                    print_colored($sformatf("[%0t] Timeout na %s  brak start bitu w ciagu %0d cykli",
                                            $time, port_name, timeout_cycles), "yellow");
                    timed_out = 1;
                    disable WAIT_START;
                end

                if (result_monitor_h != null) begin
                    result_packet_t pkt;
    
                    pkt.port      = (port_name == "sout0") ? 0 : 1;
                    pkt.frames    = frame_queue;
                    pkt.timed_out = timed_out;
    
                    result_monitor_h.write_to_monitor(pkt);
                end
            join
        end
    endtask

    task automatic monitor_uart_input();
        bit prev;

        forever begin
            wait (input_capture_enable);

            prev = 1'b1;

            fork
                begin : WAIT_START_SIN
                    forever begin
                        @(posedge clk);

                        if (!input_capture_enable)
                            disable WAIT_START_SIN;

                        if (prev === 1 && sin === 0) begin
                            disable TIMEOUT_SIN;

                            collect_uart_frames(sin, "sin", captured_frames_sin, 1'b0);

                            capture_done_sin     = 1;
                            input_capture_enable = 0;

                            current_tx.frames = captured_frames_sin;
                            current_tx.valid  = 1;

                            -> input_capture_done_ev;

                            if (command_monitor_h != null)
                                command_monitor_h.write_to_monitor(current_tx);


                            disable WAIT_START_SIN;
                        end

                        prev = sin;
                    end
                end

                begin : TIMEOUT_SIN
                    repeat (timeout_cycles) @(posedge clk);
                    if (input_capture_enable) begin
                        capture_done_sin     = 1;
                        captured_frames_sin.delete();
                        current_tx.frames = captured_frames_sin;
                        current_tx.valid  = 1;
                        input_capture_enable = 0;
                        print_colored($sformatf(
                            "[%0t] Timeout na sin  brak start bitu w ciagu %0d cykli",
                            $time,
                            timeout_cycles
                        ), "yellow");
                        -> input_capture_done_ev;

                        if (command_monitor_h != null)
                        command_monitor_h.write_to_monitor(current_tx);

                    end
                    disable WAIT_START_SIN;
                end
            join
        end
    endtask

    initial begin
        fork
            monitor_uart_output("sout0", sout0, capture_done_sout0, captured_frames_sout0);
            monitor_uart_output("sout1", sout1, capture_done_sout1, captured_frames_sout1);
            monitor_uart_input();
        join_none
    end

endinterface : bfm_if