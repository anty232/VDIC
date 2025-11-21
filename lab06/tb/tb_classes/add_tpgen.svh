class add_tpgen extends random_tpgen;
    `uvm_component_utils(add_tpgen)

    //------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // stimulus body
    //------------------------------------------------------------------------------
    protected task drive_stimulus();
        static logic [7:0] addr_max = 8'hFF;
        static logic [7:0] addr_min = 8'h00;
        static logic [7:0] data     = 8'hAA;

        program_all_addresses(1);
        sent_frames.delete();
        print_colored("Programowanie zakonczone  przejscie do testu max_min\n", "yellow");
        //print_routing_table();

        bfm.set_prog(0);
        //run_full_forwarding_sweep();

        run_uart_packet_case("edge_addres_max", addr_max, data, 0);
        run_uart_packet_case("edge_addres_min", addr_min, data, 0);

        bfm.wait_clock_cycles(1000);

        //bfm.reset_switch();
        //bfm.wait_clock_cycles(10);

        //program_all_addresses();
        //print_colored("Programowanie zakonczone  przejscie do testu forwarding\n", "yellow");
        //print_routing_table();
        //sent_frames.delete();
        //bfm.set_prog(0);

        //run_full_forwarding_sweep();

    endtask : drive_stimulus

endclass : add_tpgen