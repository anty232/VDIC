class command_monitor extends uvm_component;
    `uvm_component_utils(command_monitor)

    //------------------------------------------------------------------------------
    // local variables
    //------------------------------------------------------------------------------

    uvm_analysis_port #(input_transaction_t) ap;

    //------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // monitoring function called from BFM
    //------------------------------------------------------------------------------
    function void write_to_monitor(input_transaction_t tx);
        ap.write(tx);
    endfunction : write_to_monitor

    //------------------------------------------------------------------------------
    // build phase
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        ap                    = new("ap", this);
    endfunction : build_phase

endclass : command_monitor

