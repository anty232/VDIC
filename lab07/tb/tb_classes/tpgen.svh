class tpgen extends uvm_component;

    `uvm_component_utils(tpgen)

    bit prog_mode;

    uvm_put_port #(command_transaction) command_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        command_port = new("command_port", this);
    endfunction : build_phase

    function automatic logic [7:0] generate_random_data();
        return $urandom();
    endfunction : generate_random_data

    function automatic int get_expected_port(input logic [7:0] addr);
        foreach (routing_table[i]) begin
            if (routing_table[i].addr == addr)
                return routing_table[i].port;
        end
        return -1;
    endfunction : get_expected_port

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        request_reset();
        wait_clock_cycles(10);

        clear_routing_table();
        program_all_addresses(0);
        print_colored("Programowanie zakonczone  przejscie do testu ramek uszkodzonych\n", "yellow");
        set_prog_mode(0);
        wait_clock_cycles(10000);

        repeat (NUM_ADDRS) begin
            command_transaction cmd;
            cmd = command_transaction::type_id::create("cmd");

            if (!cmd.randomize() with {
                    request_reset == 0;
                    request_wait  == 0;
                    set_prog_valid == 0;
                    use_custom_bits == 0;
                    addr inside {[0:255]};
                }) begin
                `uvm_error(get_name(), "Randomizacja command_transaction nie powiodla sie")
                continue;
            end

            cmd.data = generate_random_data();

            run_uart_packet_case($sformatf("pkt_%0t", $time), cmd.addr, cmd.data, cmd.verbose);
            wait_clock_cycles(5);
        end

        wait_clock_cycles(10000);
        phase.drop_objection(this);
    endtask : run_phase

    protected function automatic command_transaction make_default_command(string name="cmd");
        command_transaction cmd;
        cmd = command_transaction::type_id::create(name);
        cmd.set_defaults();
        return cmd;
    endfunction : make_default_command

    protected task request_reset();
        command_transaction cmd;

        cmd = make_default_command();
        cmd.request_reset = 1;
        command_port.put(cmd);
    endtask : request_reset

    protected task wait_clock_cycles(input int unsigned cycles);
        command_transaction cmd;

        cmd = make_default_command();
        cmd.request_wait = 1;
        cmd.wait_cycles  = cycles;
        command_port.put(cmd);
    endtask : wait_clock_cycles

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

    protected task set_prog_mode(bit progset);
        command_transaction cmd;

        cmd                = make_default_command();
        cmd.set_prog_valid  = 1;
        cmd.prog_value      = progset;

        command_port.put(cmd);
        prog_mode = progset;
    endtask : set_prog_mode

    protected task clear_routing_table();
        routing_table.delete();
    endtask : clear_routing_table

    protected task send_uart_packet(input logic [7:0] b0, input logic [7:0] b1);
        command_transaction cmd;

        cmd      = make_default_command();
        cmd.addr = b0;
        cmd.data = b1;

        command_port.put(cmd);

        if (prog_mode)
            add_routing_entry(b0, b1);
    endtask : send_uart_packet

    protected task program_all_addresses(input bit reverse_order = 0);
        if (reverse_order)
            print_colored("Start programowania tras (ODWRÓCONE przypisanie)", "yellow");
        else
            print_colored("Start programowania tras (standardowe przypisanie)", "yellow");

        clear_routing_table();
        set_prog_mode(1);

        for (int i = 0; i < NUM_ADDRS; i++) begin
            logic [7:0] addr_local = i[7:0];
            logic [7:0] port_local;

            if (!reverse_order)
                port_local = (i < NUM_ADDRS/2) ? 8'h00 : 8'h01;
            else
                port_local = (i < NUM_ADDRS/2) ? 8'h01 : 8'h00;

            send_uart_packet(addr_local, port_local);
            wait_clock_cycles(5);
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

endclass : tpgen