class result_monitor extends uvm_component;
    `uvm_component_utils(result_monitor)

    //------------------------------------------------------------------------------
    // local variables
    //------------------------------------------------------------------------------
    protected virtual bfm_if bfm;
    protected time            timeout_cycles = TIMEOUT_CYCLES;

    uvm_analysis_port #(result_packet_t) ap;

    //------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // build phase
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        if(!uvm_config_db#(virtual bfm_if)::get(null, "*", "bfm", bfm))
            `uvm_fatal("RMON", "Failed to get BFM from config DB")

        ap = new("ap", this);
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // helper tasks
    //------------------------------------------------------------------------------
    protected task automatic wait_for_next_start_bit(
        ref logic serial_line,
        input string port_name,
        output bit start_found
    );
        longint wait_limit = timeout_cycles;
        start_found = 0;


        while (wait_limit > 0) begin
            bit prev_local = serial_line;
            @(posedge bfm.clk);
            wait_limit--;
            if (prev_local === 1 && serial_line === 0) begin
                start_found = 1;
                return;
            end
        end

        print_colored($sformatf("[%0t] Nie wykryto kolejnego bitu start na %s",
                                $time, port_name), "yellow");
    endtask

    protected task automatic collect_uart_frames(
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
                repeat (CLKS_PER_BIT) @(posedge bfm.clk);
                frame.data[bit_index] = serial_line;
            end

            repeat (CLKS_PER_BIT) @(posedge bfm.clk);
            frame.parity = serial_line;

            repeat (CLKS_PER_BIT) @(posedge bfm.clk);
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

    protected task automatic monitor_uart_output(
        input string port_name,
        ref logic serial_line,
        input int port
    );
        forever begin
            result_packet_t pkt;
            uart_frame_t    frames[$];
            bit             start_found;

            if (bfm.prog) begin
                wait (!bfm.prog);
            end

            wait_for_next_start_bit(serial_line, port_name, start_found);
            

            if (!start_found) begin
                pkt.port      = port;
                pkt.frames    = frames;
                pkt.timed_out = 1'b1;
                ap.write(pkt);
                continue;
            end

            
            collect_uart_frames(serial_line, port_name, frames, 1'b1);

            pkt.port      = port;
            pkt.frames    = frames;
            pkt.timed_out = 1'b0;

            //if(!bfm.prog)
            ap.write(pkt);
        end
    endtask

    //------------------------------------------------------------------------------
    // run phase
    //------------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        fork
            monitor_uart_output("sout0", bfm.sout0, 0);
            monitor_uart_output("sout1", bfm.sout1, 1);
        join
    endtask : run_phase

endclass : result_monitor