

module simple_uart_switch_tb;

    //------------------------------------------------------------------------------
    // Local param
    //------------------------------------------------------------------------------
    
        localparam CLK_PERIOD = 10;       // 100 MHz
        localparam CLKS_PER_BIT = 16;
        localparam NUM_ADDRS    = 256;
        localparam int MONITOR_BITS = 22;
        localparam int MONITOR_FRAMES = 2;
        time TIMEOUT_CYCLES = 20000;
    //------------------------------------------------------------------------------
    // Local variables
    //------------------------------------------------------------------------------
    
        logic clk;
        logic rst_n;
        logic prog;
        logic sin;
        logic sout0;
        logic sout1;
    
    //------------------------------------------------------------------------------
    // Global queque and variables
    //------------------------------------------------------------------------------
        typedef struct packed {
            bit        start_bit;
            bit [7:0]  data;
            bit        parity;
            bit        stop_bit;
        } uart_frame_t;

        uart_frame_t sent_frames[$];
        bit capture_done_sout1 = 0;       
        bit capture_done_sout0 = 0;
        uart_frame_t captured_frames_sout0[$];
        uart_frame_t captured_frames_sout1[$];
        
    
    //------------------------------------------------------------------------------
    // Routing table for expected forwarding
    //------------------------------------------------------------------------------
    
        typedef struct {
            logic [7:0] addr;
            logic [7:0] port; // 0 = sout0, 1 = sout1
        } routing_entry_t;
        
        routing_entry_t routing_table[$]; // dynamic array
        
    
    //------------------------------------------------------------------------------
    // Type definitions
    //------------------------------------------------------------------------------
    
        typedef enum bit {
            TEST_PASSED,
            TEST_FAILED
        } test_result_t;
        
        typedef enum {
            COLOR_BOLD_BLACK_ON_GREEN,
            COLOR_BOLD_BLACK_ON_RED,
            COLOR_BOLD_BLACK_ON_YELLOW,
            COLOR_BOLD_BLUE_ON_WHITE,
            COLOR_BLUE_ON_WHITE,
            COLOR_DEFAULT
        } print_color_t;
        
    //------------------------------------------------------------------------------
    // DUT instantiation
    //------------------------------------------------------------------------------
    
    
        simple_switch_uart u_simple_switch_uart (
            .clk  (clk), //posedge active clock
            .prog (prog), //1=programming, 0=functional
            .rst_n(rst_n), //async active-low
            .sin  (sin), //serial input
            .sout0(sout0), //serial output port 0
            .sout1(sout1) //serial output port 1
        );
        
    //------------------------------------------------------------------------------
    // Clock generator
    //------------------------------------------------------------------------------
    
        initial begin
            clk = '0;
            forever begin
                #(CLK_PERIOD/2) clk = ~clk;
            end
        end
    
    
    //------------------------------------------------------------------------------
    // Functions
    //------------------------------------------------------------------------------
    
        function logic [7:0] get_expected_port(input logic [7:0] addr);
            foreach (routing_table[i]) begin
                if (routing_table[i].addr == addr)
                    return routing_table[i].port;
            end
            // jeśli brak wpisu
            return -1;
        endfunction
    
    //------------------------------------------------------------------------------
    // Debug: Print current routing table
    //------------------------------------------------------------------------------
        function void print_routing_table();
            static string esc_green = "\033[1;32m";
            static string esc_yellow = "\033[1;33m";
            static string esc_reset = "\033[0m";
        
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
        endfunction
        
    
    //------------------------------------------------------------------------------
    // Utility for color printing
    //------------------------------------------------------------------------------
    
        function void print_colored(input string msg, input string color);
            string esc;
            begin
              case (color)
                "green": esc = "\033[1;32m";
                "red"  : esc = "\033[1;31m";
                "yellow": esc = "\033[1;33m";
                default: esc = "\033[0m";
              endcase
              $display("%s%s\033[0m", esc, msg);
            end
          endfunction


    //------------------------------------------------------------------------------
    // Taks
    //------------------------------------------------------------------------------
    
        task reset_SWITCH();
            rst_n = 1'b0;
            prog  = 1; // zaczynamy w trybie programowania
            sin   = 1; // linia UART idle = 1
            #(10*CLK_PERIOD);
            rst_n = 1;
        endtask
    
        
        task send_uart_byte(input [7:0] data);
            integer i;
            bit parity;
            uart_frame_t frame;
            begin
              parity = ^data; // even parity → parity bit = parity of data (XOR)

              frame.start_bit = 1'b0;
              frame.data      = data;
              frame.parity    = parity;
              frame.stop_bit  = 1'b1;

              // start bit
              sin = frame.start_bit; #(CLK_PERIOD*CLKS_PER_BIT);
              // data bits LSB first
              for (i = 0; i < 8; i++) begin
                sin = frame.data[i];
                #(CLK_PERIOD*CLKS_PER_BIT);
              end
              // parity bit (even parity)
              sin = frame.parity;
              #(CLK_PERIOD*CLKS_PER_BIT);
              // stop bit
              sin = frame.stop_bit;
              #(CLK_PERIOD*CLKS_PER_BIT);

              sent_frames.push_back(frame);
            end
        endtask

        task send_uart_byte_test(input bit start_bit, input [7:0] data, input bit parity_bit, input bit end_bit);
            integer i;
            uart_frame_t frame;

            begin
              frame.start_bit = start_bit;
              frame.data      = data;
              frame.parity    = parity_bit;
              frame.stop_bit  = end_bit;

              // start bit
              sin = frame.start_bit; #(CLK_PERIOD*CLKS_PER_BIT);
              // data bits LSB first
              for (i = 0; i < 8; i++) begin
                sin = frame.data[i];
                #(CLK_PERIOD*CLKS_PER_BIT);
              end
              // parity bit (even parity)
              sin = frame.parity;
              #(CLK_PERIOD*CLKS_PER_BIT);
              // stop bit
              sin = frame.stop_bit;
              #(CLK_PERIOD*CLKS_PER_BIT);

              sent_frames.push_back(frame);
            end
        endtask
    
        task send_uart_packet(input [7:0] b0, input [7:0] b1);
            begin
              send_uart_byte(b0);
              send_uart_byte(b1);
            end
        endtask
    
        function string frame_to_string(input uart_frame_t frame);
            return $sformatf("start=%0b data=0x%02h parity=%0b stop=%0b",
                             frame.start_bit, frame.data, frame.parity, frame.stop_bit);
        endfunction

        task program_all_addresses();
            begin
                print_colored("Start programowania wszystkich tras", "yellow");
                routing_table.delete();
                prog = 1;
                sin  = 1;
                for (int i = 0; i < NUM_ADDRS; i++) begin
                    automatic logic [7:0] addr_local = i[7:0];
                    automatic logic [7:0] port_local = (i < NUM_ADDRS/2) ? 8'h00 : 8'h01;
                    send_uart_packet(addr_local, port_local);
                    add_routing_entry(addr_local, port_local);
                    #(5*CLK_PERIOD);
                end
                print_colored("Programowanie tras zakonczone", "yellow");
            end
        endtask

        task run_full_forwarding_sweep();
            begin
                print_colored("Start pelnego testu forwarding dla kazdego adresu i danej", "yellow");
                for (int addr_idx = 0; addr_idx < NUM_ADDRS; addr_idx++) begin
                    automatic logic [7:0] addr_local = addr_idx[7:0];
                    $display("[%0t] Forwarding sweep  addr=0x%0h", $time, addr_local);
                    for (int data_idx = 0; data_idx < 256; data_idx++) begin
                        automatic logic [7:0] data_local = data_idx[7:0];
                        run_uart_packet_case("Forwarding sweep", addr_local, data_local, 0);
                    end
                end
                print_colored("Pelny test forwarding zakonczony", "yellow");
            end
        endtask

        task apply_async_reset(input string reason);
            begin
                $display("[%0t] ASYNC RESET start  %s", $time, reason);
                #(CLK_PERIOD/4);
                rst_n = 0;
                #(3*CLK_PERIOD);
                @(posedge clk);
                rst_n = 1;
                @(posedge clk);
                $display("[%0t] ASYNC RESET koniec  %s", $time, reason);
            end
        endtask

        task run_async_reset_case(
            input string test_name,
            input logic [7:0] addr,
            input logic [7:0] data
        );
            int port;
            begin
                prepare_capture_for_addr(addr, test_name, port);
                if (port == -1)
                    return;

                sent_frames.delete();
                $display("[%0t] %s  addr=0x%0h data=0x%0h (port%0d)",
                         $time, test_name, addr, data, port);

                fork
                    begin
                        send_uart_packet(addr, data);
                    end
                    begin
                        #(CLKS_PER_BIT*CLK_PERIOD*5);
                        apply_async_reset({test_name, " (async)"});
                    end
                join

                expect_no_frames(addr, test_name, port);
                sent_frames.delete();
            end
        endtask

        task prepare_capture_for_addr(
            input logic [7:0] addr,
            input string test_name,
            output int port
        );
            begin
                port = get_expected_port(addr);
                if (port == -1) begin
                    print_colored($sformatf(
                        "[%0t] %s  brak wpisu routingu dla addr=0x%0h",
                        $time, test_name, addr
                    ), "yellow");
                    return;
                end

                case (port)
                    0: begin
                        capture_done_sout0 = 0;
                        captured_frames_sout0.delete();
                    end
                    1: begin
                        capture_done_sout1 = 0;
                        captured_frames_sout1.delete();
                    end
                    default: begin
                        print_colored($sformatf(
                            "[%0t] %s  niepoprawny port=%0d w tablicy routingu",
                            $time, test_name, port
                        ), "red");
                        port = -1;
                    end
                endcase
            end
        endtask


        task run_uart_packet_case(
            input string test_name,
            input logic [7:0] addr,
            input logic [7:0] data,
            input bit verbose = 1
        );
            int port;
            begin
                prepare_capture_for_addr(addr, test_name, port);
                if (port == -1)
                    return;

                sent_frames.delete();
                if (verbose) begin
                    $display(
                        "[%0t] %s  addr=0x%0h data=0x%0h (port%0d)",
                        $time, test_name, addr, data, port
                    );
                end

                send_uart_packet(addr, data);
                compare_expected_data(addr, sent_frames);
                sent_frames.delete();
            end
        endtask

        task run_uart_manual_case(
            input string test_name,
            input logic [7:0] addr,
            input logic [7:0] data,
            input bit addr_start_bit = 0,
            input bit data_start_bit = 0,
            input bit addr_parity_bit = ^addr,
            input bit data_parity_bit = ^data,
            input bit addr_stop_bit = 1,
            input bit data_stop_bit = 1,
            input bit expect_no_output = 0
        );
            int port;
            begin
                prepare_capture_for_addr(addr, test_name, port);
                if (port == -1)
                    return;
    
                sent_frames.delete();
                $display(
                    "[%0t] %s  addr=0x%0h data=0x%0h (port%0d)",
                    $time, test_name, addr, data, port
                );
    
                send_uart_byte_test(addr_start_bit, addr, addr_parity_bit, addr_stop_bit);
                send_uart_byte_test(data_start_bit, data, data_parity_bit, data_stop_bit);
                if (expect_no_output)
                    expect_no_frames(addr, test_name, port);
                else
                    compare_expected_data(addr, sent_frames);
                sent_frames.delete();
            end
        endtask

        task compare_frames(input uart_frame_t captured_frames[$], input uart_frame_t expected_frames[$]);
            automatic int mismatches = 0;
            automatic int diff = 0;
            int min_len;
            begin
                min_len = (captured_frames.size() < expected_frames.size())
                          ? captured_frames.size() : expected_frames.size();

                if (min_len == 0) begin
                    print_colored("Brak ramek do porownania", "yellow");
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
                    print_colored($sformatf("Rozna liczba ramek  recv=%0d exp=%0d",
                                           captured_frames.size(), expected_frames.size()), "yellow");
                end

                if (mismatches == 0)
                    print_colored("TEST PASSED  ramki na wyjsciu zgodne z wejsciem", "green");
                else
                    print_colored($sformatf("TEST FAILED  %0d roznic w ramkach", mismatches), "red");
                $write("\n\n");
            end
        endtask

        

        task add_routing_entry(input logic [7:0] addr, input logic [7:0] port);
            static int found = 0;
            foreach (routing_table[i]) begin
                if (routing_table[i].addr == addr) begin
                    routing_table[i].port = port;
                    found = 1;
                end
            end
            if (!found)
                routing_table.push_back('{addr, port});
            $display("[%0t] ROUTE: addr=0x%0h -> port%d zapisano", $time, addr, port);
        endtask
    
        
        task compare_expected_data(input logic [7:0] addr, input uart_frame_t expected_frames[$]);
            logic [7:0] port_exp;
            begin
                port_exp = get_expected_port(addr);
                if (port_exp == -1) begin
                    print_colored($sformatf("Brak wpisu routingu dla addr=0x%0h", addr), "yellow");
                    return;
                end

                if (port_exp == 0) begin
                    wait (capture_done_sout0 == 1);
                    compare_frames(captured_frames_sout0, expected_frames);
                end
                else if (port_exp == 1) begin
                    wait (capture_done_sout1 == 1);
                    compare_frames(captured_frames_sout1, expected_frames);
                end
                else begin
                    print_colored("Niepoprawny port w tablicy routingu", "red");
                end
            end
        endtask

        task expect_no_frames(
            input logic [7:0] addr,
            input string test_name,
            input int port
        );
            uart_frame_t frames_to_report[$];
            begin
                case (port)
                    0: begin
                        wait (capture_done_sout0 == 1);
                        frames_to_report = captured_frames_sout0;
                    end
                    1: begin
                        wait (capture_done_sout1 == 1);
                        frames_to_report = captured_frames_sout1;
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
            end
        endtask


        
        task automatic monitor_uart_output(
            input string port_name,
            ref logic serial_line,
            ref bit capture_done,
            ref uart_frame_t frame_queue[$],
            input time timeout_cycles
        );
            bit prev;
            longint wait_limit;
    
            forever begin
                prev = 1'b1;
    
                fork
                    begin : WAIT_START
                        forever begin
                            @(posedge clk);
                            if (prev === 1 && serial_line === 0) begin
                                disable TIMEOUT;
                                $display("[%0t] Start bit wykryty na %s", $time, port_name);
    
                                frame_queue.delete();
                                capture_done = 0;
    
                                for (int frame_idx = 0; frame_idx < MONITOR_FRAMES; frame_idx++) begin
                                    uart_frame_t frame;
                                    bit start_found = 1'b1;
    
                                    if (frame_idx == 0) begin
                                        frame.start_bit = serial_line;
                                    end
                                    else begin
                                        start_found = 1'b0;
                                        wait_limit = timeout_cycles;
                                        while (wait_limit > 0) begin
                                            bit prev_local = serial_line;
                                            @(posedge clk);
                                            wait_limit--;
                                            if (prev_local === 1 && serial_line === 0) begin
                                                start_found = 1'b1;
                                                break;
                                            end
                                        end
    
                                        if (!start_found) begin
                                            print_colored($sformatf("[%0t] Nie wykryto kolejnego bitu start na %s",
                                                                    $time, port_name), "yellow");
                                            break;
                                        end
    
                                        frame.start_bit = serial_line;
                                    end
    
                                    for (int bit_index = 0; bit_index < 8; bit_index++) begin
                                        repeat (CLKS_PER_BIT) @(posedge clk);
                                        frame.data[bit_index] = serial_line;
                                    end
    
                                    repeat (CLKS_PER_BIT) @(posedge clk);
                                    frame.parity = serial_line;
    
                                    repeat (CLKS_PER_BIT) @(posedge clk);
                                    frame.stop_bit = serial_line;
    
                                    frame_queue.push_back(frame);
                                end
    
                                capture_done = 1;
                                $display("[%0t] Akwizycja zakonczona, zebrano %0d ramek",
                                         $time, frame_queue.size());
    
                                foreach (frame_queue[i])
                                    $display("    Frame %0d: %s", i, frame_to_string(frame_queue[i]));
                                if (frame_queue.size() < MONITOR_FRAMES)
                                    print_colored($sformatf("[%0t] Ostrzezenie  oczekiwano %0d ramek, zebrano %0d",
                                                            $time, MONITOR_FRAMES, frame_queue.size()), "yellow");
                                $write("\n");
    
                                disable TIMEOUT;
                                disable WAIT_START;
                            end
                            prev = serial_line;
                        end
                    end
    
                    begin : TIMEOUT
                        repeat (timeout_cycles) @(posedge clk);
                        capture_done = 1;
                        print_colored($sformatf("[%0t] Timeout na %s  brak start bitu w ciagu %0d cykli",
                                                $time, port_name, timeout_cycles), "yellow");
                        disable WAIT_START;
                    end
                join
            end
        endtask

        initial
            monitor_uart_output("sout1", sout1, capture_done_sout1, captured_frames_sout1,
                             TIMEOUT_CYCLES);

        initial
            monitor_uart_output("sout0", sout0, capture_done_sout0, captured_frames_sout0,
                               TIMEOUT_CYCLES);
       
    
    
    
    //------------------------------------------------------------------------------
    // Sekwencja testowa
    //------------------------------------------------------------------------------
    
        initial begin
    
            test_result_t result;
            static logic [7:0] addr = 8'h88;
            static logic [7:0] addr_sout0 = 8'h77;
            static logic [7:0] data = 8'hAA;
            
    
    
            reset_SWITCH();
            #(10*CLK_PERIOD);
    
            $display("[%0t] Start testu port sout1\n", $time);
    
            $write ("---------------------------------------------\n");
            $write ("----------- Programowanie adresow -----------\n");
            $write ("---------------------------------------------\n");
    
            program_all_addresses();

            sent_frames.delete();


            print_colored("Programowanie zakonczone  przejscie do testu forwarding\n", "yellow");
            print_routing_table();

    

    
            $write ("---------------------------------------------\n");
            $write ("----------- Faza testowa --------------------\n");
            $write ("---------------------------------------------\n");
    
            $display("[%0t] Test forwarding", $time);
            prog = 0;
    
            

            run_uart_packet_case("Forwarding do sout1", addr, data);

            run_uart_packet_case("Forwarding do sout0", addr_sout0, data);

            run_full_forwarding_sweep();

            // uszkodzony bit parzystści w data dla sout0
            run_uart_manual_case(
                "Bledny bit parzystosci danych na sout0",
                addr_sout0,
                data,
                .data_parity_bit(~(^data)),
                .expect_no_output(1)
            );

            // uszkodzony start bit
            run_uart_manual_case(
                "Bledny start bit danych na sout1",
                addr,
                data,
                .data_start_bit(1),
                .expect_no_output(1)
            );
            
            run_async_reset_case(
                "Async reset podczas forwarding na sout0",
                addr_sout0,
                data
            );



    
            $display("[%0t] Test zakonczony", $time);
    
    
    
            repeat(10000)
                @(posedge clk);
            $finish();
        end
    
    
    endmodule
    