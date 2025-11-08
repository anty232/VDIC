module tpgen(bfm_if bfm);
    import uartswitch_tb_pkg::*;

    //------------------------------------------------------------------------------
    // Routing helpers moved from the BFM
    //------------------------------------------------------------------------------
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

    task automatic send_uart_packet(input logic [7:0] b0, input logic [7:0] b1);
        bfm.send_uart_byte(b0);
        bfm.send_uart_byte(b1);
        if (bfm.prog) begin
            add_routing_entry(b0, b1);
        end
    endtask

    //------------------------------------------------------------------------------
    // Utility functions and tasks
    //------------------------------------------------------------------------------
    task automatic print_routing_table();
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
    endtask

    task automatic program_all_addresses(input bit reverse_order = 0);
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
    endtask

    task automatic run_uart_packet_case(
        input string test_name,
        input logic [7:0] addr,
        input logic [7:0] data,
        input bit verbose = 1
    );
        int port;
        simple_uart_switch_tb.scoreboard_i.begin_transaction(test_name, addr, 0, port);
        if (port == -1)
            return;

        if (verbose) begin
            $display("[%0t] %s  addr=0x%0h data=0x%0h (port%0d)",
                     $time, test_name, addr, data, port);
        end

        send_uart_packet(addr, data);
        bfm.trigger_forwarding_cov(addr, data, port);
    endtask

    task automatic run_full_forwarding_sweep();
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
    endtask

    task automatic run_async_reset_case(
        input string test_name,
        input logic [7:0] addr,
        input logic [7:0] data
    );
        int port;
        simple_uart_switch_tb.scoreboard_i.begin_transaction(test_name, addr, 1, port);
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
    endtask

    task automatic run_uart_manual_case(
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
        simple_uart_switch_tb.scoreboard_i.begin_transaction(test_name, addr, expect_no_output, port);
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
    endtask

    //------------------------------------------------------------------------------
    // Test sequence
    //------------------------------------------------------------------------------
    initial begin
        static logic [7:0] addr_sout1 = 8'hFA;
        static logic [7:0] addr_sout0 = 8'h11;
        static logic [7:0] data       = 8'hAA;

        bfm.reset_switch();
        bfm.wait_clock_cycles(10);

        $write ("---------------------------------------------\n");
        $write ("----------- Programowanie adresow -----------\n");
        $write ("---------------------------------------------\n");

        program_all_addresses(1);

        sent_frames.delete();

        print_colored("Programowanie zakonczone  przejscie do testu forwarding\n", "yellow");
        print_routing_table();

        $write ("---------------------------------------------\n");
        $write ("----------- Faza testowa --------------------\n");
        $write ("---------------------------------------------\n");

        $display("[%0t] Test forwarding", $time);
        
        bfm.set_prog(0);

        run_full_forwarding_sweep();
        
        bfm.wait_clock_cycles(1000);

        bfm.reset_switch();
        bfm.wait_clock_cycles(10);

        program_all_addresses();
        print_colored("Programowanie zakonczone  przejscie do testu forwarding\n", "yellow");
        print_routing_table();
        sent_frames.delete();
        bfm.set_prog(0);

        run_full_forwarding_sweep();


        $write ("---------------------------------------------\n");
        $write ("----------- TEST uszkodzonych ramek ---------\n");
        $write ("---------------------------------------------\n");

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

        $display("[%0t] Test zakonczony", $time);
        print_colored($sformatf("Pokrycie laczne: %.2f%%", $get_coverage()), "yellow");

        repeat(10000)
            @(posedge bfm.clk);
        $finish();
    end

endmodule : tpgen