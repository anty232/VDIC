

module simple_uart_switch_tb;

    //------------------------------------------------------------------------------
    // Local param
    //------------------------------------------------------------------------------
    
    
        localparam CLK_PERIOD = 10;       // 100 MHz
        localparam CLKS_PER_BIT = 16;
        localparam NUM_ADDRS    = 256;
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
    
    
        bit sent_bits[$];
        bit capture_done_sout1 = 0;       // flaga: 1 po zakończeniu akwizycji
        bit capture_done_sout0 = 0;
        bit bits_queue_sout0[$]; 
        bit bits_queue_sout1[$];
    
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
            begin
              parity = ^data; // even parity → parity bit = parity of data (XOR)
              // start bit
              sin = 0; #(CLK_PERIOD*CLKS_PER_BIT);
              sent_bits.push_back(0);
              // data bits LSB first
              for (i = 0; i < 8; i++) begin
                sin = data[i];
                sent_bits.push_back(data[i]);
                #(CLK_PERIOD*CLKS_PER_BIT);
              end
              // parity bit (even parity)
              sin = parity;
              sent_bits.push_back(parity);
              #(CLK_PERIOD*CLKS_PER_BIT);
              // stop bit
              sin = 1;
              sent_bits.push_back(1);
              #(CLK_PERIOD*CLKS_PER_BIT);
            end
        endtask
    
        task send_uart_packet(input [7:0] b0, input [7:0] b1);
            begin
              send_uart_byte(b0);
              send_uart_byte(b1);
            end
        endtask
    
        task send_uart_byte_test(input start_bit, input [7:0] data, input parity_bit, input end_bit);
            integer i;
            
            begin
    
              // start bit
              sin = start_bit; #(CLK_PERIOD*CLKS_PER_BIT);
              sent_bits.push_back(start_bit);
              // data bits LSB first
              for (i = 0; i < 8; i++) begin
                sin = data[i];
                sent_bits.push_back(data[i]);
                #(CLK_PERIOD*CLKS_PER_BIT);
              end
              // parity bit (even parity)
              sin = parity_bit;
              sent_bits.push_back(parity_bit);
              #(CLK_PERIOD*CLKS_PER_BIT);
              // stop bit
              sin = end_bit;
              sent_bits.push_back(end_bit);
              #(CLK_PERIOD*CLKS_PER_BIT);
            end
        endtask
    
        task compere_data(input bits_queue_sout1[$], input sent_bits[$]);
            integer i;
            static int min_len = 22;
            automatic int mismatches = 0;
            begin
                for (int i = 0; i < min_len; i++) begin
                    if (sent_bits[i] !== bits_queue_sout1[i]) begin
                        $display("Bit mismatch at %0d: sent=%0d, recv=%0d", i, sent_bits[i], bits_queue_sout1[i]);
                        mismatches++;
                    end
                end
        
                if (mismatches == 0)
                    print_colored("TEST PASSED  pakiet na sout zgodny z sin", "green");
                else
                    print_colored($sformatf("TEST FAILED  %0d bitow roznicy", mismatches), "red");
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
        
        task compare_expected_data(input logic [7:0] addr, input bit sent_bits[$]);
            logic [7:0] port_exp;
            begin
                port_exp = get_expected_port(addr);
                if (port_exp == -1) begin
                    print_colored($sformatf("Brak wpisu routingu dla addr=0x%0h", addr), "yellow");
                    return;
                end
        
                if (port_exp == 0) begin
                    wait (capture_done_sout0 == 1);
                    compere_data(bits_queue_sout0, sent_bits);
                end
                else if (port_exp == 1) begin
                    wait (capture_done_sout1 == 1);
                    compere_data(bits_queue_sout1, sent_bits);
                end
                else begin
                    print_colored("Niepoprawny port w tablicy routingu", "red");
                end
            end
        endtask
        
    
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
    
    
    
    // ---------------------------
    // Monitor wyjścia sout1 
    // ---------------------------
          bit sout1_prev;
          int bit_index_sout1;
          time TIMEOUT_CYCLES_SOUT1 = 20000; // liczba cykli zegara do timeoutu
          
          initial begin
              sout1_prev = 1'b1; // UART idle
              bits_queue_sout1.delete();
              capture_done_sout1 = 0;
          
              forever begin
                  time start_time;
                  automatic bit timeout_triggered = 0;
          
                  @(posedge clk);
                  start_time = $time;
          
                  // czekaj na start bit (1 -> 0), ale z ograniczeniem czasowym
                  fork
                      // --- Wątek główny: wykrywanie start bitu ---
                      begin : WAIT_START_SOUT1
                          forever begin
                              @(posedge clk);
                              if (sout1_prev === 1 && sout1 === 0) begin
                                  disable TIMEOUT_SOUT1;
                                  $display("[%0t] Start bit wykryty na sout1", $time);
          
                                  bits_queue_sout1.delete();
                                  bits_queue_sout1.push_back(sout1);
          
                                  // próbkuj po 16 cykli zegara każdy bit
                                  for (bit_index_sout1 = 0; bit_index_sout1 < 22; bit_index_sout1++) begin
                                      repeat (CLKS_PER_BIT) @(posedge clk);
                                      bits_queue_sout1.push_back(sout1);
                                  end
          
                                  capture_done_sout1 = 1;
                                  $display("[%0t] Akwizycja zakonczona, zebrano %0d bitow", 
                                           $time, bits_queue_sout1.size());
          
                                  $display("[%0t] Zebrane bity z sout1 (%0d bitow):", 
                                           $time, bits_queue_sout1.size());
                                  foreach (bits_queue_sout1[i])
                                      $write("%0d", bits_queue_sout1[i]);
                                  $write("\n\n");
          
                                  disable TIMEOUT_SOUT1;
                                  disable WAIT_START_SOUT1;
                              end
                              sout1_prev = sout1;
                          end
                      end
          
                      // --- Wątek timeoutu ---
                      begin : TIMEOUT_SOUT1
                          repeat (TIMEOUT_CYCLES_SOUT1) @(posedge clk);
                          timeout_triggered = 1;
                          capture_done_sout1 = 1; // zakończ oczekiwanie, żeby test nie wisiał
                          print_colored($sformatf("[%0t] Timeout na sout1  brak start bitu w ciagu %0d cykli",
                                                  $time, TIMEOUT_CYCLES_SOUT1), "yellow");
                          disable WAIT_START_SOUT1;
                      end
                  join
              end
          end
          
    
    
    
    // ---------------------------
    // Monitor wyjścia sout0 
    // ---------------------------
          bit sout0_prev;
          int bit_index_sout0;
     
          
          initial begin
              sout0_prev = 1'b1; // UART idle
              bits_queue_sout0.delete();
              capture_done_sout0 = 0;
          
              forever begin
                  time start_time;
                  automatic bit timeout_triggered = 0;
          
                  @(posedge clk);
                  start_time = $time;
          
                  // czekaj na start bit (1->0) z ograniczeniem czasowym
                  fork
                      begin : WAIT_START
                          forever begin
                              @(posedge clk);
                              if (sout0_prev === 1 && sout0 === 0) begin
                                  disable TIMEOUT; // anuluj timeout
                                  $display("[%0t] Start bit wykryty na sout0", $time);
          
                                  bits_queue_sout0.delete();
                                  bits_queue_sout0.push_back(sout0);
          
                                  // próbkuj po 16 cykli zegara każdy bit
                                  for (bit_index_sout0 = 0; bit_index_sout0 < 22; bit_index_sout0++) begin
                                      repeat(CLKS_PER_BIT) @(posedge clk);
                                      bits_queue_sout0.push_back(sout0);
                                  end
          
                                  capture_done_sout0 = 1;
                                  $display("[%0t] Akwizycja zakonczona, zebrano %0d bitow", 
                                           $time, bits_queue_sout0.size());
          
                                  $display("[%0t] Zebrane bity z sout0 (%0d bitow):", 
                                           $time, bits_queue_sout0.size());
                                  foreach (bits_queue_sout0[i])
                                      $write("%0d", bits_queue_sout0[i]);
                                  $write("\n\n");
          
                                  disable TIMEOUT;
                                  disable WAIT_START;
                              end
                              sout0_prev = sout0;
                          end
                      end
          
                      begin : TIMEOUT
                          repeat (TIMEOUT_CYCLES) @(posedge clk);
                          timeout_triggered = 1;
                          capture_done_sout0 = 1; // zakończ czekanie, żeby test nie wisiał
                          print_colored($sformatf("[%0t] Timeout na sout0  brak start bitu w ciagu %0d cykli",
                                                  $time, TIMEOUT_CYCLES), "yellow");
                          disable WAIT_START;
                      end
                  join
              end
          end
          
    
    
    
    
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
    
            // --- Programowanie wszystkich 128 adresów ---
            for (int i = 0; i < NUM_ADDRS; i++) begin
                automatic logic [7:0] addr = i[7:0];
                automatic logic [7:0]  port = (i < NUM_ADDRS/2) ? 0 : 1; // połowa do sout0, reszta do sout1
                send_uart_packet(addr, port);
                add_routing_entry(addr, port);
                #(5*CLK_PERIOD);
            end
    
            print_colored("Programowanie zakonczone  przejscie do testu forwarding\n", "yellow");
            print_routing_table();
            /*
            $display("[%0t] Programowanie: addr=0x88 -> port1", $time);
            prog = 1;
    
    
            send_uart_packet(addr, 8'h01);
            add_routing_entry(addr, 1);
            #(10*CLK_PERIOD);
            
            $display("[%0t] Programowanie: addr=0xAB -> port0", $time);
    
            send_uart_packet(addr_sout0, 8'h00);
            add_routing_entry(addr_sout0, 0);
            #(10*CLK_PERIOD);
            */
    
            sent_bits.delete();
    
            $write ("---------------------------------------------\n");
            $write ("----------- Faza testowa --------------------\n");
            $write ("---------------------------------------------\n");
    
            $display("[%0t] Test forwarding", $time);
            prog = 0;
    
            capture_done_sout1 = 0;
            send_uart_packet(addr, data);               
            compare_expected_data(addr, sent_bits);
            sent_bits.delete();
    
    
            capture_done_sout0 = 0;
            send_uart_packet(addr_sout0, data);               
            compare_expected_data(addr_sout0, sent_bits);
            sent_bits.delete();
    
            // uszkodzony bit parzystści w data dla sout0
            capture_done_sout0 = 0;
            send_uart_byte_test(0,addr_sout0,0,1);
            send_uart_byte_test(0,data,0,1);               
            compare_expected_data(addr_sout0, sent_bits);
            sent_bits.delete();
    
            
            // uszkodzony start bit
            capture_done_sout0 = 0;
            send_uart_byte_test(0,addr_sout0,0,1);
            send_uart_byte_test(1,data,0,1);               
            compare_expected_data(addr_sout0, sent_bits);
            sent_bits.delete();
            
    
            $display("[%0t] Test zakonczony", $time);
    
    
    
            repeat(10000)
                @(posedge clk);
            $finish();
        end
    
    
    endmodule
    