class command_monitor extends uvm_component;
    `uvm_component_utils(command_monitor)

    //------------------------------------------------------------------------------
    // local variables
    //------------------------------------------------------------------------------
    protected virtual bfm_if bfm;

    uvm_analysis_port #(input_transaction_t) ap;

    //------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // build phase
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        if(!uvm_config_db#(virtual bfm_if)::get(null, "*", "bfm", bfm))
            `uvm_fatal("CMON", "Failed to get BFM from config DB")

        bfm.command_monitor_h = this;
        ap = new("ap", this);
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // monitoring function called from BFM
    //------------------------------------------------------------------------------
    function void write_to_monitor(input_transaction_t tx);
        ap.write(tx);
    endfunction : write_to_monitor

endclass : command_monitor