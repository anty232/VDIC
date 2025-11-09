class testbench;

    protected virtual bfm_if bfm;

    protected tpgen tpgen_h;
    protected coverage coverage_h;
    protected scoreboard scoreboard_h;

    function new(virtual bfm_if b);
        bfm          = b;
        scoreboard_h = new(bfm);
        coverage_h   = new(bfm);
        tpgen_h      = new(bfm, scoreboard_h);
    endfunction : new

    task execute();
        fork
            coverage_h.execute();
            scoreboard_h.execute();
        join_none
        tpgen_h.execute();
        scoreboard_h.print_result();
    endtask : execute

endclass : testbench