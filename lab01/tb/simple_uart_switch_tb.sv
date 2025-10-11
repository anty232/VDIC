

module simple_uart_switch_tb;

//------------------------------------------------------------------------------
// Local param
//------------------------------------------------------------------------------


    localparam CLK_PERIOD = 10;       // 100 MHz
    localparam CLKS_PER_BIT = 16;

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
          // data bits LSB first
          for (i = 0; i < 8; i++) begin
            sin = data[i];
            #(CLK_PERIOD*CLKS_PER_BIT);
          end
          // parity bit (even parity)
          sin = parity;
          #(CLK_PERIOD*CLKS_PER_BIT);
          // stop bit
          sin = 1;
          #(CLK_PERIOD*CLKS_PER_BIT);
        end
      endtask

      task send_uart_packet(input [7:0] b0, input [7:0] b1);
        begin
          send_uart_byte(b0);
          send_uart_byte(b1);
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

//------------------------------------------------------------------------------
// Sekwencja testowa
//------------------------------------------------------------------------------

    initial begin

        test_result_t result;
        bit expected_port, actual_port;
        bit activity0, activity1;

        reset_SWITCH();
        #(10*CLK_PERIOD);

        $display("[%0t] Start testu", $time);

        $display("[%0t] Programowanie: addr=0xAA -> port1", $time);
        prog = 1;
        send_uart_packet(8'hAA, 8'h01);
        #(1000);
        
        $display("[%0t] Test forwarding", $time);
        prog = 0;
        send_uart_packet(8'hAA, 8'h55);

        // Step 3: Detect activity on outputs

        activity0 = 0;
        activity1 = 0;
        repeat (CLKS_PER_BIT*30) begin
          @(posedge clk);
          if (sout0 === 0) activity0 = 1;
          if (sout1 === 0) activity1 = 1;
        end
    
        expected_port = 1'b1;                                       // we programmed addr 0xAA -> port1 type what you expect
        actual_port   = (activity1 && !activity0) ? 1'b1 :
                        (activity0 && !activity1) ? 1'b0 : 1'bx;
    
        // Step 4: Check result
        if (actual_port === expected_port) begin
          print_colored("TEST PASSED", "green");
        end else begin
          print_colored("TEST FAILED", "red");
          $display("Expected port: %0d, got: %0d", expected_port, actual_port);
        end


        $display("[%0t] Test zakonczony", $time);

        repeat(1000)
            @(posedge clk);
        $finish();
    end


endmodule
