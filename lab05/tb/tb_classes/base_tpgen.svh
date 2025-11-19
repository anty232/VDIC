virtual class base_tpgen extends uvm_component;

    // The macro is not there as we never instantiate/use the base_tpgen

    //------------------------------------------------------------------------------
    // local variables
    //------------------------------------------------------------------------------
    protected virtual bfm_if bfm;
    protected scoreboard scoreboard_h;

    //------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        if(!uvm_config_db#(virtual bfm_if)::get(null, "*", "bfm", bfm))
            `uvm_fatal("TPGEN", "Failed to get BFM")

        // Fetch the scoreboard published by the environment. Using "this" as the
        // accessor scope ensures we look relative to the current component's path
        // (env.env_h.tpgen_h) instead of relying on a global search, which could
        // fail if wildcard resolution differs between tools.
        if(!uvm_config_db#(scoreboard)::get(this, "", "scoreboard", scoreboard_h))
            `uvm_fatal("TPGEN", "Failed to get scoreboard handle")
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // function prototypes
    //------------------------------------------------------------------------------
    pure virtual protected task drive_stimulus();


    //------------------------------------------------------------------------------
    // random data helper
    //------------------------------------------------------------------------------
    protected function automatic logic [7:0] generate_random_data();
        return $urandom_range(8'h00, 8'hFF);
    endfunction : generate_random_data
    
    //------------------------------------------------------------------------------
    // run phase
    //------------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        bfm.reset_switch();
        bfm.wait_clock_cycles(10);

        drive_stimulus();

        phase.drop_objection(this);
    endtask : run_phase

    //------------------------------------------------------------------------------
    // helper tasks shared by generators
    //------------------------------------------------------------------------------
    protected task add_routing_entry(input logic [7:0] addr, input logic [7:0] port);
        int found = 0;
        foreach (routing_table[i]) begin
            if (routing_table[i].addr == addr) begin
                routing_table[i].port = port;
                found = 1;
            end
        end
        if (!found)
            routing_table.push_back('{addr, port});
    endtask : add_routing_entry

    protected task clear_routing_table();
        routing_table.delete();
    endtask : clear_routing_table

    protected task send_uart_packet(input logic [7:0] b0, input logic [7:0] b1);
        bfm.send_uart_byte(b0);
        bfm.send_uart_byte(b1);
        if (bfm.prog) begin
            add_routing_entry(b0, b1);
        end
    endtask : send_uart_packet

    protected task print_routing_table();
        static string esc_yellow = "\033[1;33m";
        static string esc_green  = "\033[1;32m";
        static string esc_reset  = "\033[0m";

        $display("\n%s==============================", esc_yellow);
        $display("   ROUTING TABLE DUMP (%0d entries)", routing_table.size());
        $display("==============================%s", esc_reset);
        $display(" Index | Address | Port ");
        $display("--------+----------+------");

        foreach (routing_table[i]) begin
            string port_str;
            if (routing_table[i].port == 0)
                port_str = {esc_green, "sout0", esc_reset};
            else if (routing_table[i].port == 1)
                port_str = {esc_green, "sout1", esc_reset};
            else
                port_str = {esc_yellow, "???", esc_reset};

            $display("  %3d   |  0x%02h    |  %s",
                     i, routing_table[i].addr, port_str);
        end

        $display("%s==============================%s\n", esc_yellow, esc_reset);
    endtask : print_routing_table

    protected task program_all_addresses(input bit reverse_order = 0);
        if (reverse_order)
            print_colored("Start programowania tras (ODWRÓCONE przypisanie)", "yellow");
        else
            print_colored("Start programowania tras (standardowe przypisanie)", "yellow");

        clear_routing_table();
        bfm.prog = 1;
        bfm.sin  = 1;

        for (int i = 0; i < NUM_ADDRS; i++) begin
            logic [7:0] addr_local = i[7:0];
            logic [7:0] port_local;

            if (!reverse_order)
                port_local = (i < NUM_ADDRS/2) ? 8'h00 : 8'h01;
            else
                port_local = (i < NUM_ADDRS/2) ? 8'h01 : 8'h00;

            send_uart_packet(addr_local, port_local);
            bfm.wait_clock_cycles(5);
        end
        print_colored("Programowanie tras zakonczone", "yellow");
    endtask : program_all_addresses

    protected task run_uart_packet_case(
        input string test_name,
        input logic [7:0] addr,
        input logic [7:0] data,
        input bit verbose = 1
    );
        int port;
        scoreboard_h.begin_transaction(test_name, addr, 0, port);
        if (port == -1)
            return;

        if (verbose) begin
            $display("[%0t] %s  addr=0x%0h data=0x%0h (port%0d)",
                     $time, test_name, addr, data, port);
        end

        send_uart_packet(addr, data);
        bfm.trigger_forwarding_cov(addr, data, port);
    endtask : run_uart_packet_case

    protected task run_full_forwarding_sweep();
        print_colored("Start pelnego testu forwarding dla kazdego adresu i danej", "yellow");
        for (int addr_idx = 0; addr_idx < NUM_ADDRS; addr_idx++) begin
            logic [7:0] addr_local = addr_idx[7:0];
            $display("[%0t] Forwarding sweep  addr=0x%0h", $time, addr_local);
            for (int data_idx = 0; data_idx < 256; data_idx++) begin
                logic [7:0] data_local = data_idx[7:0];
                run_uart_packet_case("Forwarding sweep", addr_local, data_local, 0);
            end
        end
        print_colored("Pelny test forwarding zakonczony", "yellow");
    endtask : run_full_forwarding_sweep

    protected task run_async_reset_case(
        input string test_name,
        input logic [7:0] addr,
        input logic [7:0] data
    );
        int port;
        scoreboard_h.begin_transaction(test_name, addr, 1, port);
        if (port == -1)
            return;

        $display("[%0t] %s  addr=0x%0h data=0x%0h (port%0d)",
                 $time, test_name, addr, data, port);

        fork
            begin
                send_uart_packet(addr, data);
            end
            begin
                bfm.wait_clock_cycles(CLKS_PER_BIT*5);
                bfm.apply_async_reset({test_name, " (async)"});
            end
        join

        bfm.trigger_reset_cov(port);
    endtask : run_async_reset_case

    protected task run_uart_manual_case(
        input string test_name,
        input logic [7:0] addr,
        input logic [7:0] data,
        input bit addr_start_bit = 0,
        input bit data_start_bit = 0,
        input bit addr_parity_bit = ^addr,
        input bit data_parity_bit = ^data,
        input bit addr_stop_bit = 1,
        input bit data_stop_bit = 1,
        input bit expect_no_output = 0,
        input frame_error_t addr_error = ERR_NONE,
        input frame_error_t data_error = ERR_NONE
    );
        int port;
        scoreboard_h.begin_transaction(test_name, addr, expect_no_output, port);
        if (port == -1)
            return;

        $display("[%0t] %s  addr=0x%0h data=0x%0h (port%0d)",
                 $time, test_name, addr, data, port);

        bfm.send_uart_byte_custom(addr_start_bit, addr, addr_parity_bit, addr_stop_bit);
        bfm.send_uart_byte_custom(data_start_bit, data, data_parity_bit, data_stop_bit);

        if (!expect_no_output) begin
            bfm.trigger_forwarding_cov(addr, data, port);
        end

        if (expect_no_output) begin
            bfm.trigger_error_cov(FRAME_KIND_ADDR, addr_error);
            bfm.trigger_error_cov(FRAME_KIND_DATA, data_error);
        end
    endtask : run_uart_manual_case

endclass : base_tpgen