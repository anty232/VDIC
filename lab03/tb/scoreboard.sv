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

    task automatic compare_expected_data(
        input input_transaction_t tx
    );
        case (tx.port)
            0: begin
                bfm.wait_for_output_capture(0);
                compare_frames(bfm.captured_frames_sout0, tx.frames);
            end
            1: begin
                bfm.wait_for_output_capture(1);
                compare_frames(bfm.captured_frames_sout1, tx.frames);
            end
            default: begin
                print_colored("Niepoprawny port w tablicy routingu", "red");
            end
        endcase
    endtask

    task automatic expect_no_frames(
        input input_transaction_t tx
    );
        uart_frame_t frames_to_report[$];

        case (tx.port)
            0: begin
                bfm.wait_for_output_capture(0);
                frames_to_report = bfm.captured_frames_sout0;
            end
            1: begin
                bfm.wait_for_output_capture(1);
                frames_to_report = bfm.captured_frames_sout1;
            end
            default: begin
                print_colored($sformatf(
                    "[%0t] %s  niepoprawny port=%0d w expect_no_frames",
                    $time, tx.test_name, tx.port
                ), "red");
                return;
            end
        endcase

        if (frames_to_report.size() == 0) begin
            print_colored($sformatf(
                "TEST PASSED  ramka dla addr=0x%0h nie dotarla na %s (oczekiwano odrzucenia)",
                tx.addr,
                tx.port == 0 ? "sout0" : "sout1"
            ), "green");
        end
        else begin
            print_colored($sformatf(
                "TEST FAILED  addr=0x%0h otrzymano %0d ramek na %s mimo oczekiwanego odrzucenia",
                tx.addr,
                frames_to_report.size(),
                tx.port == 0 ? "sout0" : "sout1"
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

    task automatic process_transaction(input input_transaction_t tx);
        if (!tx.valid) begin
            bfm.complete_transaction();
            return;
        end

        if (tx.port == -1) begin
            print_colored($sformatf(
                "[%0t] %s  brak wpisu routingu dla addr=0x%0h",
                $time,
                tx.test_name,
                tx.addr
            ), "yellow");
            bfm.complete_transaction();
            return;
        end

        $display("[%0t] %s  addr=0x%0h (port%0d)", $time, tx.test_name, tx.addr, tx.port);

        if (tx.expect_no_output)
            expect_no_frames(tx);
        else
            compare_expected_data(tx);

        bfm.complete_transaction();
    endtask

    initial begin
        input_transaction_t tx;

        forever begin
            bfm.wait_for_input_transaction();
            bfm.get_last_input_transaction(tx);
            process_transaction(tx);
        end
    end

endmodule : scoreboard