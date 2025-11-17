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
        static logic [7:0] addr_sout1 = 8'hFA;
        static logic [7:0] addr_sout0 = 8'h11;
        static logic [7:0] data       = 8'hAA;

        program_all_addresses();
        print_colored("Programowanie zakonczone  przejscie do testu ramek uszkodzonych\n", "yellow");
        //print_routing_table();
        bfm.set_prog(0);

        run_uart_manual_case(
            "Bledny bit parzystosci danych na sout0",
            addr_sout0,
            data,
            .data_parity_bit(~(^data)),
            .expect_no_output(1),
            .data_error(ERR_PARITY_BIT)
        );

        run_uart_manual_case(
            "Bledny start bit danych na sout0",
            addr_sout0,
            data,
            .data_start_bit(1),
            .expect_no_output(1),
            .data_error(ERR_START_BIT)
        );

        run_uart_manual_case(
            "Bledny stop bit danych na sout0",
            addr_sout0,
            data,
            .data_stop_bit(0),
            .expect_no_output(1),
            .data_error(ERR_STOP_BIT)
        );

        run_uart_manual_case(
            "Bledny bit parzystosci adresu na sout0",
            addr_sout0,
            data,
            .addr_parity_bit(~(^addr_sout0)),
            .expect_no_output(1),
            .addr_error(ERR_PARITY_BIT)
        );

        run_uart_manual_case(
            "Bledny start bit adresu na sout0",
            addr_sout0,
            data,
            .addr_start_bit(1),
            .expect_no_output(1),
            .addr_error(ERR_START_BIT)
        );

        run_uart_manual_case(
            "Bledny stop bit adresu na sout0",
            addr_sout0,
            data,
            .addr_stop_bit(0),
            .expect_no_output(1),
            .addr_error(ERR_STOP_BIT)
        );

        run_uart_manual_case(
            "Bledny bit parzystosci danych na sout1",
            addr_sout1,
            data,
            .data_parity_bit(~(^data)),
            .expect_no_output(1),
            .data_error(ERR_PARITY_BIT)
        );

        run_uart_manual_case(
            "Bledny start bit danych na sout1",
            addr_sout1,
            data,
            .data_start_bit(1),
            .expect_no_output(1),
            .data_error(ERR_START_BIT)
        );

        run_uart_manual_case(
            "Bledny stop bit danych na sout1",
            addr_sout1,
            data,
            .data_stop_bit(0),
            .expect_no_output(1),
            .data_error(ERR_STOP_BIT)
        );

        run_uart_manual_case(
            "Bledny bit parzystosci adresu na sout1",
            addr_sout1,
            data,
            .addr_parity_bit(~(^addr_sout1)),
            .expect_no_output(1),
            .addr_error(ERR_PARITY_BIT)
        );

        run_uart_manual_case(
            "Bledny start bit adresu na sout1",
            addr_sout1,
            data,
            .addr_start_bit(1),
            .expect_no_output(1),
            .addr_error(ERR_START_BIT)
        );

        run_uart_manual_case(
            "Bledny stop bit adresu na sout1",
            addr_sout1,
            data,
            .addr_stop_bit(0),
            .expect_no_output(1),
            .addr_error(ERR_STOP_BIT)
        );

        run_async_reset_case(
            "Async reset podczas forwarding na sout0",
            addr_sout0,
            data
        );

        bfm.wait_clock_cycles(1000);

        run_async_reset_case(
            "Async reset podczas forwarding na sout1",
            addr_sout1,
            data
        );

        bfm.wait_clock_cycles(1000);
    endtask : drive_stimulus

endclass : add_tpgen