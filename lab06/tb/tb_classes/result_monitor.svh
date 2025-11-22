class result_monitor extends uvm_component;
    `uvm_component_utils(result_monitor)

    //------------------------------------------------------------------------------
    // local variables
    //------------------------------------------------------------------------------
    protected virtual bfm_if bfm;
    uvm_analysis_port #(result_packet_t) ap;

    //------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // monitoring function called from BFM
    //------------------------------------------------------------------------------
    function void write_to_monitor(result_packet_t pkt);
        ap.write(pkt);
    endfunction : write_to_monitor

    //------------------------------------------------------------------------------
    // build phase
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        if(!uvm_config_db#(virtual bfm_if)::get(null, "*", "bfm", bfm))
            `uvm_fatal("RES_MON", "Failed to get BFM")

        bfm.result_monitor_h = this;
        ap                   = new("ap", this);
    endfunction : build_phase

endclass : result_monitor