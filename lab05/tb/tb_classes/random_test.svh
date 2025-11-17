class random_test extends uvm_test;
    `uvm_component_utils(random_test)

    //------------------------------------------------------------------------------
    // local variables
    //------------------------------------------------------------------------------
    env env_h;

    //------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name,parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // build phase
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        env_h = env::type_id::create("env_h",this);
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // start-of-simulation-phase
    //------------------------------------------------------------------------------
    virtual function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        // Print the test topology
        uvm_top.print_topology();
    endfunction : start_of_simulation_phase

endclass