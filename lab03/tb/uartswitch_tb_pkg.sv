package uartswitch_tb_pkg;

    //------------------------------------------------------------------------------
    // Testbench configuration
    //------------------------------------------------------------------------------
    localparam time CLK_PERIOD      = 10;       // 100 MHz
    localparam int  CLKS_PER_BIT    = 16;
    localparam int  NUM_ADDRS       = 256;
    localparam int  MONITOR_FRAMES  = 2;
    localparam time TIMEOUT_CYCLES  = 20000;

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

    typedef enum bit {
        TEST_PASSED,
        TEST_FAILED
    } test_result_t;

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

endpackage : uartswitch_tb_pkg