

module simple_uart_switch_tb;

//------------------------------------------------------------------------------
// Local param
//------------------------------------------------------------------------------


    localparam CLK_PERIOD = 10;       // 100 MHz
    localparam CLKS_PER_BIT = 16;
    localparam BIT_TIME  = CLK_PERIOD * CLKS_PER_BIT; // czas trwania jednego bitu
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
    bit capture_done = 0;       // flaga: 1 po zakończeniu akwizycji


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
          // data bits LSB first
          for (i = 0; i < 8; i++) begin
            sin = data[i];
            #(CLK_PERIOD*CLKS_PER_BIT);
          end
          // parity bit (even parity)
          sin = parity_bit;
          #(CLK_PERIOD*CLKS_PER_BIT);
          // stop bit
          sin = end_bit;
          #(CLK_PERIOD*CLKS_PER_BIT);
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
      bit bits_queue[$]; // dynamiczna kolejka na zapisane bity
      int bit_index;
      int sample_count_per_bit = 16; // czas trwania jednego bitu w cyklach zegara
      int total_bits = 21;           // liczba bitów do zebrania po starcie
      
      
      initial begin
          sout1_prev = 1'b1; // UART idle
          bits_queue.delete();

          capture_done = 0;
          forever begin
              @(posedge clk);
      
              // wykrycie start bitu (1 -> 0)
              if (sout1_prev === 1 && sout1 === 0) begin
                  $display("[%0t] Start bit wykryty na sout1", $time);
      
                  bits_queue.delete();
      
                  // próbkuj po 16 cykli zegara każdy bit
                  for (bit_index = 0; bit_index < total_bits; bit_index++) begin
                      repeat(sample_count_per_bit) @(posedge clk);
                      bits_queue.push_back(sout1);
                  end
                  bits_queue.push_front(0);

                  // zakończone próbkowanie
                  capture_done = 1;
                  $display("[%0t] Akwizycja zakończona, zebrano %0d bitów", $time, bits_queue.size());
                  // zakończone próbkowanie  wypisz wynik

                  $display("[%0t] Zebrane bity z sout1 (%0d bitów):", $time, bits_queue.size());
                  foreach (bits_queue[i])
                      $write("%0d", bits_queue[i]);
                  $write("\n\n");
              end
      
              sout1_prev = sout1;
          end
      end

//------------------------------------------------------------------------------
// Sekwencja testowa
//------------------------------------------------------------------------------

    initial begin

        test_result_t result;
        static logic [7:0] addr = 8'h88;
        static logic [7:0] data = 8'h99;
  
        int mismatches = 0;
        int min_len;
 


        reset_SWITCH();
        #(10*CLK_PERIOD);

        $display("[%0t] Start testu port sout1", $time);

        $display("[%0t] Programowanie: addr=0xAB -> port1", $time);
        prog = 1;
        capture_done = 0;

        send_uart_packet(addr, 8'h01);
        #(10*CLK_PERIOD);
        
        sent_bits.delete();

        $display("[%0t] Test forwarding", $time);
        prog = 0;

        
        send_uart_packet(addr, data);               // wysyłamy pakiet
        
        wait (capture_done == 1);    

         
        min_len = 22;

        for (int i = 0; i < min_len; i++) begin
            if (sent_bits[i] !== bits_queue[i]) begin
                $display("Bit mismatch at %0d: sent=%0d, recv=%0d", i, sent_bits[i], bits_queue[i]);
                mismatches++;
            end
        end

        if (mismatches == 0)
            print_colored("TEST PASSED  pakiet na sout1 zgodny z sin", "green");
        else
            print_colored($sformatf("TEST FAILED  %0d bitów różnicy", mismatches), "red");

        $display("[%0t] Test zakonczony", $time);

        //Diagnostyka

        $write("Wyslane bity (sin): ");
        foreach (sent_bits[i]) $write("%0d", sent_bits[i]);
        $write("\n");

        $write("Odebrane bity (sout1): ");
        foreach (bits_queue[i]) $write("%0d", bits_queue[i]);
        $write("\n");



        repeat(10000)
            @(posedge clk);
        $finish();
    end


endmodule
