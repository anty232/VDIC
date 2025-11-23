class scoreboard extends uvm_component;

    `uvm_component_utils(scoreboard)

    protected int unsigned passed_tests = 0;
    protected int unsigned failed_tests = 0;

    uvm_analysis_imp_cmd #(input_transaction_t, scoreboard)    cmd_imp;
    uvm_analysis_imp_result #(result_packet_t, scoreboard) result_imp;

    uvm_tlm_analysis_fifo #(input_transaction_t) cmd_fifo;
    uvm_tlm_analysis_fifo #(result_packet_t)     result_fifo;

    // Pending results keyed by port number
    result_packet_t pending_results[int][$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        cmd_imp    = new("cmd_imp", this);
        result_imp = new("result_imp", this);

        cmd_fifo    = new("cmd_fifo", this);
        result_fifo = new("result_fifo", this);
    endfunction : build_phase

    function void write_cmd(input_transaction_t tx);
        cmd_fifo.write(tx);
        

    endfunction : write_cmd

    function void write_result(result_packet_t pkt);
        result_fifo.write(pkt);
    endfunction : write_result


    protected function automatic int get_expected_port(input logic [7:0] addr);
        foreach (routing_table[i]) begin
            if (routing_table[i].addr == addr)
                return routing_table[i].port;
        end
        return -1;
    endfunction : get_expected_port

    protected task automatic record_test_result(
        input test_result_t result,
        input string        message
    );
        case (result)
            TEST_PASSED: begin
                passed_tests++;
                print_colored(message, "green");
            end
            TEST_FAILED: begin
                failed_tests++;
                print_colored(message, "red");
            end
        endcase
    endtask : record_test_result

    protected task automatic compare_frames(
        input uart_frame_t captured_frames[$],
        input uart_frame_t expected_frames[$]
    );
        int mismatches = 0;
        int diff = 0;
        int min_len;

        min_len = (captured_frames.size() < expected_frames.size())
                  ? captured_frames.size() : expected_frames.size();

        if (min_len == 0)
            print_colored("Brak ramek do porownania", "yellow");

        for (int i = 0; i < min_len; i++) begin
            if (captured_frames[i] !== expected_frames[i]) begin
                $display("Frame mismatch at index %0d", i);
                if (captured_frames[i].start_bit !== expected_frames[i].start_bit)
                    $display("  start: exp=%0b recv=%0b",
                             expected_frames[i].start_bit, captured_frames[i].start_bit);
                if (captured_frames[i].data !== expected_frames[i].data)
                    $display("  data : exp=0x%02h recv=0x%02h",
                             expected_frames[i].data, captured_frames[i].data);
                if (captured_frames[i].parity !== expected_frames[i].parity)
                    $display("  parity: exp=%0b recv=%0b",
                             expected_frames[i].parity, captured_frames[i].parity);
                if (captured_frames[i].stop_bit !== expected_frames[i].stop_bit)
                    $display("  stop : exp=%0b recv=%0b",
                             expected_frames[i].stop_bit, captured_frames[i].stop_bit);
                mismatches++;
            end
        end

        if (captured_frames.size() != expected_frames.size()) begin
            diff = (captured_frames.size() > expected_frames.size())
                       ? (captured_frames.size() - expected_frames.size())
                       : (expected_frames.size() - captured_frames.size());
            mismatches += diff;
            print_colored($sformatf("Rozna liczba ramek  recv=%0d exp=%0d",
                                   captured_frames.size(), expected_frames.size()), "yellow");
        end

        if (mismatches == 0)
            record_test_result(TEST_PASSED,
                                "TEST PASSED  ramki na wyjsciu zgodne z wejsciem");
        else
            record_test_result(TEST_FAILED,
                                $sformatf("TEST FAILED  %0d roznic w ramkach", mismatches));
        $write("\n\n");
    endtask : compare_frames

    protected task automatic pull_result_for_port(
        input int               port,
        output result_packet_t  pkt
    );
        result_packet_t temp;

        if (pending_results.exists(port) && pending_results[port].size() > 0) begin
            pkt = pending_results[port].pop_front();
            return;
        end

        forever begin
            result_fifo.get(temp);
            if (temp.port == port) begin
                pkt = temp;
                return;
            end

            pending_results[temp.port].push_back(temp);
        end
    endtask : pull_result_for_port

    protected task automatic expect_no_frames(
        input string            test_name,
        input logic [7:0]       addr,
        input int               expected_port
    );
        result_packet_t pkt;

        pull_result_for_port(expected_port, pkt);

        if (pkt.frames.size() == 0) begin
            record_test_result(
                TEST_PASSED,
                $sformatf(
                    "TEST PASSED  ramka dla addr=0x%0h nie dotarla na %s (oczekiwano odrzucenia)",
                    addr,
                    expected_port == 0 ? "sout0" : "sout1"
                )
            );
        end
        else begin
            record_test_result(
                TEST_FAILED,
                $sformatf(
                    "TEST FAILED  addr=0x%0h otrzymano %0d ramek na %s mimo oczekiwanego odrzucenia",
                    addr,
                    pkt.frames.size(),
                    expected_port == 0 ? "sout0" : "sout1"
                )
            );
            foreach (pkt.frames[i])
                $display("    Frame %0d: %s", i, frame_to_string(pkt.frames[i]));
            $write("\n");
        end

        $write("\n");
    endtask : expect_no_frames

    protected task automatic compare_expected_data(input input_transaction_t tx);
        result_packet_t pkt;

        pull_result_for_port(tx.port, pkt);

        if (pkt.timed_out) begin
            print_colored($sformatf(
                "[%0t] Timeout raportowany przez monitor dla port%0d",
                $time, pkt.port
            ), "yellow");
        end

        compare_frames(pkt.frames, tx.frames);
    endtask : compare_expected_data

    protected task automatic process_transaction(input input_transaction_t tx);
        
        if (!tx.valid)
            return;


        tx.port = (tx.port == -1) ? get_expected_port(tx.addr) : tx.port;

        $display("[%0t] SCOREBOARD: tx.valid=%0b addr=0x%0h port=%0d expect_no_output=%0b name=%s",
                $time, tx.valid, tx.addr, tx.port, tx.expect_no_output, tx.test_name);

        if (tx.port == -1) begin
            if (tx.expect_no_output) begin
                record_test_result(TEST_PASSED,
                    $sformatf("[%0t] %s  brak wpisu routingu dla addr=0x%0h (oczekiwano)",
                              $time, tx.test_name, tx.addr));
            end
            else begin
                record_test_result(TEST_FAILED,
                    $sformatf("[%0t] %s  brak wpisu routingu dla addr=0x%0h",
                              $time, tx.test_name, tx.addr));
            end
            return;
        end

        $display("[%0t] %s  addr=0x%0h (port%0d)", $time, tx.test_name, tx.addr, tx.port);

        if (tx.expect_no_output)
            expect_no_frames(tx.test_name, tx.addr, tx.port);
        else
            compare_expected_data(tx);
    endtask : process_transaction

    task run_phase(uvm_phase phase);
        fork
            begin : process_cmds
                input_transaction_t tx;

                forever begin
                    cmd_fifo.get(tx);
                    process_transaction(tx);
                end
            end : process_cmds
        join
    endtask : run_phase

    function void report_phase(uvm_phase phase);
        static string green_esc = "\033[1;32m";
        static string red_esc   = "\033[1;31m";
        static string reset_esc = "\033[0m";

        $display("TEST SUMMARY");
        $display("%sPASSED=%0d%s", green_esc, passed_tests, reset_esc);
        $display("%sFAILED=%0d%s", red_esc, failed_tests, reset_esc);
        $write("\n");
    endfunction : report_phase

endclass : scoreboard