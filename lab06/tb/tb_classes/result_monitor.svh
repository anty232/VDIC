class result_monitor extends uvm_component;
    `uvm_component_utils(result_monitor)

    //------------------------------------------------------------------------------
    // local variables
    //------------------------------------------------------------------------------

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
        ap                   = new("ap", this);
    endfunction : build_phase

endclass : result_monitor