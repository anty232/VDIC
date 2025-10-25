module scoreboard(bfm_if bfm);
    import uartswitch_tb_pkg::*;

    //------------------------------------------------------------------------------
    // Comparison helpers
    //------------------------------------------------------------------------------
    task automatic compare_frames(
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
            print_colored("TEST PASSED  ramki na wyjsciu zgodne z wejsciem", "green");
        else
            print_colored($sformatf("TEST FAILED  %0d roznic w ramkach", mismatches), "red");
        $write("\n\n");
    endtask

    task automatic prepare_capture_for_addr(
        input logic [7:0] addr,
        input string test_name,
        output int port
    );
        port = bfm.get_expected_port(addr);
        if (port == -1) begin
            print_colored($sformatf("[%0t] %s  brak wpisu routingu dla addr=0x%0h",
                                    $time, test_name, addr), "yellow");
            return;
        end

        case (port)
            0: begin
                bfm.capture_done_sout0 = 0;
                bfm.captured_frames_sout0.delete();
            end
            1: begin
                bfm.capture_done_sout1 = 0;
                bfm.captured_frames_sout1.delete();
            end
            default: begin
                print_colored($sformatf("[%0t] %s  niepoprawny port=%0d w tablicy routingu",
                                        $time, test_name, port), "red");
                port = -1;
            end
        endcase
    endtask

    task automatic compare_expected_data(
        input logic [7:0] addr,
        input uart_frame_t expected_frames[$]
    );
        int port_exp;
        port_exp = bfm.get_expected_port(addr);
        if (port_exp == -1) begin
            print_colored($sformatf("Brak wpisu routingu dla addr=0x%0h", addr), "yellow");
            return;
        end

        if (port_exp == 0) begin
            wait (bfm.capture_done_sout0 == 1);
            compare_frames(bfm.captured_frames_sout0, expected_frames);
        end
        else if (port_exp == 1) begin
            wait (bfm.capture_done_sout1 == 1);
            compare_frames(bfm.captured_frames_sout1, expected_frames);
        end
        else begin
            print_colored("Niepoprawny port w tablicy routingu", "red");
        end
    endtask

    task automatic expect_no_frames(
        input logic [7:0] addr,
        input string test_name,
        input int port
    );
        uart_frame_t frames_to_report[$];

        case (port)
            0: begin
                wait (bfm.capture_done_sout0 == 1);
                frames_to_report = bfm.captured_frames_sout0;
            end
            1: begin
                wait (bfm.capture_done_sout1 == 1);
                frames_to_report = bfm.captured_frames_sout1;
            end
            default: begin
                print_colored($sformatf(
                    "[%0t] %s  niepoprawny port=%0d w expect_no_frames",
                    $time, test_name, port
                ), "red");
                return;
            end
        endcase

        if (frames_to_report.size() == 0) begin
            print_colored($sformatf(
                "TEST PASSED  ramka dla addr=0x%0h nie dotarla na %s (oczekiwano odrzucenia)",
                addr,
                port == 0 ? "sout0" : "sout1"
            ), "green");
        end
        else begin
            print_colored($sformatf(
                "TEST FAILED  addr=0x%0h otrzymano %0d ramek na %s mimo oczekiwanego odrzucenia",
                addr,
                frames_to_report.size(),
                port == 0 ? "sout0" : "sout1"
            ), "red");
            foreach (frames_to_report[i])
                $display("    Frame %0d: %s", i, frame_to_string(frames_to_report[i]));
            $write("\n");
        end

        $write("\n");
    endtask

    task automatic sample_error_coverage(
        input frame_kind_t frame_kind,
        input frame_error_t error_type
    );
        bfm.trigger_error_cov(frame_kind, error_type);
    endtask

endmodule : scoreboard