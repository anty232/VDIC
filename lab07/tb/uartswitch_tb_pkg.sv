

package uartswitch_tb_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `uvm_analysis_imp_decl(_cmd)
    `uvm_analysis_imp_decl(_result)

    //------------------------------------------------------------------------------
    // Testbench configuration
    //------------------------------------------------------------------------------
    localparam time CLK_PERIOD      = 10;       // 100 MHz
    localparam int  CLKS_PER_BIT    = 16;
    localparam int  NUM_ADDRS       = 256;
    localparam int  MONITOR_FRAMES  = 2;
    localparam time TIMEOUT_CYCLES  = 500000;

    //------------------------------------------------------------------------------
    // Type definitions
    //------------------------------------------------------------------------------
    typedef struct packed {
        bit        start_bit;
        bit [7:0]  data;
        bit        parity;
        bit        stop_bit;
    } uart_frame_t;

    typedef enum int {
        FRAME_KIND_ADDR,
        FRAME_KIND_DATA
    } frame_kind_t;

    typedef enum int {
        ERR_NONE,
        ERR_START_BIT,
        ERR_PARITY_BIT,
        ERR_STOP_BIT
    } frame_error_t;

    typedef struct {
        logic [7:0] addr;
        logic [7:0] port; // 0 = sout0, 1 = sout1
    } routing_entry_t;

    routing_entry_t routing_table[$];

    typedef struct {
        logic [7:0] addr;
        logic [7:0] data;
        bit         set_prog_valid;
        bit         prog_value;
        bit         use_custom_bits;
        bit         addr_start_bit;
        bit         data_start_bit;
        bit         addr_parity_bit;
        bit         data_parity_bit;
        bit         addr_stop_bit;
        bit         data_stop_bit;
        bit         request_reset;
        bit         request_wait;
        int unsigned wait_cycles;
    } driver_command_t;


    //------------------------------------------------------------------------------
    // Shared stimulus bookkeeping
    //------------------------------------------------------------------------------


    //uart_frame_t sent_frames[$];


    typedef struct {
        string        test_name;
        logic [7:0]   addr;
        bit           expect_no_output;
        bit           from_programming;
        int           port;
        uart_frame_t  frames[$];
        bit           valid;
    } input_transaction_t;

    typedef struct {
        int          port;
        uart_frame_t frames[$];
        bit          timed_out;
    } result_packet_t;

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
    } print_color;

    //------------------------------------------------------------------------------
    // Utility routines
    //------------------------------------------------------------------------------
    function string frame_to_string(input uart_frame_t frame);
        return $sformatf("start=%0b data=0x%02h parity=%0b stop=%0b",
                         frame.start_bit, frame.data, frame.parity, frame.stop_bit);
    endfunction

    task automatic print_colored(input string msg, input string color);
        string esc;
        case (color)
            "green" : esc = "\033[1;32m";
            "red"   : esc = "\033[1;31m";
            "yellow": esc = "\033[1;33m";
            default : esc = "\033[0m";
        endcase
        $display("%s%s\033[0m", esc, msg);
    endtask

    function void set_print_color ( print_color c );
        string ctl;
        case(c)
            COLOR_BOLD_BLACK_ON_GREEN : ctl  = "\033\[1;30m\033\[102m";
            COLOR_BOLD_BLACK_ON_RED : ctl    = "\033\[1;30m\033\[101m";
            COLOR_BOLD_BLACK_ON_YELLOW : ctl = "\033\[1;30m\033\[103m";
            COLOR_BOLD_BLUE_ON_WHITE : ctl   = "\033\[1;34m\033\[107m";
            COLOR_BLUE_ON_WHITE : ctl        = "\033\[0;34m\033\[107m";
            COLOR_DEFAULT : ctl              = "\033\[0m\n";
            default : begin
                $error("set_print_color: bad argument");
                ctl                          = "";
            end
        endcase
        $write(ctl);
    endfunction

    //------------------------------------------------------------------------------
    // Testbench classes
    //------------------------------------------------------------------------------
    `include "tb_classes/command_monitor.svh"
    `include "tb_classes/result_monitor.svh"
    `include "tb_classes/scoreboard.svh"
    `include "tb_classes/coverage.svh"
    `include "tb_classes/base_tpgen.svh"
    `include "tb_classes/random_tpgen.svh"
    `include "tb_classes/add_tpgen.svh"
    `include "tb_classes/driver.svh"
    `include "tb_classes/env.svh"

    //------------------------------------------------------------------------------
    // Test classes
    //------------------------------------------------------------------------------
    `include "tb_classes/random_test.svh"
    `include "tb_classes/add_test.svh"

endpackage : uartswitch_tb_pkg