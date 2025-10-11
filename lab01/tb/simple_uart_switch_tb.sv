

module simple_uart_switch_tb;

    bit clk;
    bit rst_n;
    wire prog;
    wire sin;
    wire sout0;
    wire sout1;
    
    simple_switch_uart u_simple_switch_uart (
        .clk  (clk), //posedge active clock
        .prog (prog), //1=programming, 0=functional
        .rst_n(rst_n), //async active-low
        .sin  (sin), //serial input
        .sout0(sout0), //serial output port 0
        .sout1(sout1) //serial output port 1
    );
    
    initial begin
        clk = '0;
        forever begin
            #10 clk = ~clk;
        end
    end


    initial begin

        repeat(4)
            @(posedge clk);
        $finish();
    end


endmodule
