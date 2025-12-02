class add_tpgen extends random_tpgen;
    `uvm_component_utils(add_tpgen)

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
        return 6;
    endfunction : get_transaction_count

    protected function tpgen_txn_t get_transaction(int unsigned idx);
        tpgen_txn_t txn;

        static logic [7:0] addr_max = 8'hBB;
        static logic [7:0] addr_min = 8'hAA;
        static logic [7:0] data     = 8'h99;

        case (idx)
            0, 2, 4: begin
                txn.test_name = "edge_addres_max";
                txn.addr      = addr_max;
            end
            default: begin
                txn.test_name = "edge_addres_min";
                txn.addr      = addr_min;
            end
        endcase

        txn.data    = data;
        txn.verbose = 1;

        return txn;
    endfunction : get_transaction

endclass : add_tpgen