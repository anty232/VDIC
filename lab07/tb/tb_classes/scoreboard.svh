class scoreboard extends uvm_subscriber #(result_packet_t);

    `uvm_component_utils(scoreboard)

    protected int unsigned passed_tests = 0;
    protected int unsigned failed_tests = 0;

    

    uvm_tlm_analysis_fifo #(input_transaction_t) cmd_fifo;


    
    // Pending commands keyed by port number
    input_transaction_t pending_cmds[int][$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        cmd_fifo    = new("cmd_fifo", this);
    endfunction : build_phase


    function void write(result_packet_t t);
        input_transaction_t tx;

        if (pending_cmds.exists(t.port) && pending_cmds[t.port].size() > 0)
            tx = pending_cmds[t.port].pop_front();
        else begin
            forever begin
                if (!cmd_fifo.try_get(tx))
                    `uvm_fatal("SCBD", $sformatf("Brak komendy odpowiadajacej wynikowi z port%0d", t.port))

                if (!tx.valid)
                    continue;

                tx.port = (tx.port == -1) ? get_expected_port(tx.addr) : tx.port;

                if (tx.port == -1) begin
                    record_test_result(
                        tx.expect_no_output ? TEST_PASSED : TEST_FAILED,
                        $sformatf(
                            "[%0t] %s  brak wpisu routingu dla addr=0x%0h%s",
                            $time,
                            tx.test_name,
                            tx.addr,
                            tx.expect_no_output ? " (oczekiwano)" : ""
                        )
                    );
                    continue;
                end

                if (tx.port == t.port)
                    break;

                pending_cmds[tx.port].push_back(tx);
            end
        end

        $display(
            "[%0t] SCOREBOARD: tx.valid=%0b addr=0x%0h port=%0d expect_no_output=%0b name=%s",
            $time, tx.valid, tx.addr, tx.port, tx.expect_no_output, tx.test_name
        );

        if (tx.expect_no_output)
            expect_no_frames(tx.test_name, tx.addr, tx.port, t);
        else
            compare_expected_data(tx, t);
    endfunction : write


    protected function automatic int get_expected_port(input logic [7:0] addr);
        foreach (routing_table[i]) begin
            if (routing_table[i].addr == addr)
                return routing_table[i].port;
        end
        return -1;
    endfunction : get_expected_port

    protected function automatic void record_test_result(
        input test_result_t result,
        input string        message
    );
        case (result)
            TEST_PASSED: begin
                passed_tests++;
                set_print_color(COLOR_BOLD_BLACK_ON_GREEN);
                $display(message);
            end
            TEST_FAILED: begin
                failed_tests++;
                set_print_color(COLOR_BOLD_BLACK_ON_RED);
                $display(message);
            end
        endcase
        set_print_color(COLOR_DEFAULT);
    endfunction : record_test_result

    protected function automatic void compare_frames(
        input uart_frame_t captured_frames[$],
        input uart_frame_t expected_frames[$]
    );
        int mismatches = 0;
        int diff = 0;
        int min_len;

        min_len = (captured_frames.size() < expected_frames.size())
                  ? captured_frames.size() : expected_frames.size();

        if (min_len == 0) begin
            set_print_color(COLOR_BOLD_BLACK_ON_YELLOW);
            $display("Brak ramek do porownania");
            set_print_color(COLOR_DEFAULT);
        end

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
            set_print_color(COLOR_BOLD_BLACK_ON_YELLOW);
            $display("Rozna liczba ramek  recv=%0d exp=%0d", captured_frames.size(), expected_frames.size());
            set_print_color(COLOR_DEFAULT);
        end

        if (mismatches == 0)
            record_test_result(
                TEST_PASSED,
                "TEST PASSED  ramki na wyjsciu zgodne z wejsciem"
            );
        else
            record_test_result(
                TEST_FAILED,
                $sformatf("TEST FAILED  %0d roznic w ramkach", mismatches)
            );
        $write("\n\n");
    endfunction : compare_frames



    protected function automatic void expect_no_frames(
        input string           test_name,
        input logic [7:0]      addr,
        input int              expected_port,
        input result_packet_t  pkt
    );
        

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
    endfunction : expect_no_frames

    protected function automatic void compare_expected_data(
        input input_transaction_t tx,
        input result_packet_t     pkt
    );
        $display("--- EXPECTED (tx.frames) ---");
        foreach (tx.frames[i])
            $display("  TX[%0d] %s", i, frame_to_string(tx.frames[i]));

        $display("--- RECEIVED (pkt.frames) ---");
        foreach (pkt.frames[i])
            $display("  RX[%0d] %s", i, frame_to_string(pkt.frames[i]));

        if (pkt.timed_out) begin
            set_print_color(COLOR_BOLD_BLACK_ON_YELLOW);
            $display(
                "[%0t] Timeout raportowany przez monitor dla port%0d",
                $time, pkt.port
            );
            set_print_color(COLOR_DEFAULT);
        end

        compare_frames(pkt.frames, tx.frames);
    endfunction : compare_expected_data



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