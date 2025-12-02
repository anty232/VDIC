class random_tpgen extends base_tpgen;
    `uvm_component_utils(random_tpgen)

    //------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // transaction generators
    //------------------------------------------------------------------------------
    protected function int unsigned get_transaction_count();
        return NUM_ADDRS;
    endfunction : get_transaction_count

    protected function tpgen_txn_t get_transaction(int unsigned idx);
        tpgen_txn_t txn;

        txn.test_name = "Losowe dane forwarding";
        txn.addr      = idx[7:0];
        txn.data      = generate_random_data();
        txn.verbose   = 0;

        return txn;
    endfunction : get_transaction

endclass : random_tpgen