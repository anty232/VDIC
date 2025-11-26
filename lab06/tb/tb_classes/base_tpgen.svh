virtual class base_tpgen extends uvm_component;



    //------------------------------------------------------------------------------
    // local variables
    //------------------------------------------------------------------------------
    protected virtual bfm_if bfm;

    uvm_blocking_put_port #(driver_command_t) command_port;

    //------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        if(!uvm_config_db#(virtual bfm_if)::get(null, "*", "bfm", bfm))
            `uvm_fatal("TPGEN", "Failed to get BFM")

        command_port = new("command_port", this);
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // function prototypes
    //------------------------------------------------------------------------------
    pure virtual protected task drive_stimulus();


    //------------------------------------------------------------------------------
    // random data helper
    //------------------------------------------------------------------------------
    protected function automatic logic [7:0] generate_random_data();
        return $random & 'hFF;
    endfunction : generate_random_data
    
    protected function automatic int get_expected_port(input logic [7:0] addr);
        foreach (routing_table[i]) begin
            if (routing_table[i].addr == addr)
                return routing_table[i].port;
        end
        return -1;
    endfunction : get_expected_port

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
        driver_command_t cmd;

        cmd.addr            = b0;
        cmd.data            = b1;
        cmd.use_custom_bits = 0;

        command_port.put(cmd);

        if (bfm.prog)
            add_routing_entry(b0, b1);
    endtask : send_uart_packet

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
        //bfm.prog = 0;
    endtask : program_all_addresses

    
    protected task run_uart_packet_case(
        input string test_name,
        input logic [7:0] addr,
        input logic [7:0] data,
        input bit verbose = 1
    );
        int port;
        port = get_expected_port(addr);
        if (port == -1)
            return;

        if (verbose) begin
            $display("[%0t] %s  addr=0x%0h data=0x%0h (port%0d)",
                     $time, test_name, addr, data, port);
        end

        send_uart_packet(addr, data);
        
    endtask : run_uart_packet_case

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

endclass : base_tpgen