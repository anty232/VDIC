class add_transaction extends command_transaction;
    `uvm_object_utils(add_transaction)

    constraint add_addrs {
        addr inside {8'hFF, 8'h00};
        data == 8'h99;
        verbose == 1;
        set_prog_valid == 0;
        request_reset == 0;
        request_wait  == 0;
    }

    function new(string name = "add_transaction");
        super.new(name);
    endfunction : new

endclass : add_transaction