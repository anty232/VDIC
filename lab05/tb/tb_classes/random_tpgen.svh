class random_tpgen extends base_tpgen;
    `uvm_component_utils(random_tpgen)

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
         
        program_all_addresses();
        print_colored("Programowanie zakonczone  przejscie do testu ramek uszkodzonych\n", "yellow");
        //print_routing_table();
        bfm.set_prog(0);

        for (int addr_idx = 0; addr_idx < NUM_ADDRS; addr_idx++) begin
            logic [7:0] addr_local = addr_idx[7:0];
            logic [7:0] random_data = generate_random_data();

            run_uart_packet_case("Losowe dane forwarding", addr_local, random_data, 0);
            bfm.wait_clock_cycles(5);
        end

        bfm.wait_clock_cycles(1000);
    endtask : drive_stimulus

endclass : random_tpgen