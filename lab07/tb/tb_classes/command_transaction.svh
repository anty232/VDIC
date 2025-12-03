class command_transaction extends uvm_sequence_item;

    rand logic [7:0]  addr;
    rand logic [7:0]  data;

    // Observed/metadata fields used by monitors and scoreboard
    string        test_name;
    bit           expect_no_output;
    bit           from_programming;
    int           port;
    uart_frame_t  frames[$];
    bit           valid;

    rand bit          set_prog_valid;
    rand bit          prog_value;
    rand bit          use_custom_bits;
    rand bit          addr_start_bit;
    rand bit          data_start_bit;
    rand bit          addr_parity_bit;
    rand bit          data_parity_bit;
    rand bit          addr_stop_bit;
    rand bit          data_stop_bit;

    rand bit          request_reset;
    rand bit          request_wait;
    rand int unsigned wait_cycles;

    rand bit          verbose;

    `uvm_object_utils_begin(command_transaction)
        `uvm_field_int(addr,             UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(data,             UVM_ALL_ON | UVM_DEC)
        `uvm_field_string(test_name,     UVM_ALL_ON)
        `uvm_field_int(expect_no_output, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(from_programming, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(port,             UVM_ALL_ON | UVM_DEC)
        `uvm_field_queue_int(frames,     UVM_ALL_ON)
        `uvm_field_int(valid,            UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(set_prog_valid,   UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(prog_value,       UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(use_custom_bits,  UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(addr_start_bit,   UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(data_start_bit,   UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(addr_parity_bit,  UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(data_parity_bit,  UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(addr_stop_bit,    UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(data_stop_bit,    UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(request_reset,    UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(request_wait,     UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(wait_cycles,      UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(verbose,          UVM_ALL_ON | UVM_DEC)
    `uvm_object_utils_end

    constraint sane_defaults {
        request_reset == 0;
        request_wait  == 0;
        set_prog_valid == 0;
        use_custom_bits == 0;
        wait_cycles inside {[0:TIMEOUT_CYCLES]};
    }

    function new(string name = "command_transaction");
        super.new(name);
        test_name        = "";
        expect_no_output = 0;
        from_programming = 0;
        port             = -1;
        valid            = 0;
    endfunction : new

    function void set_defaults();
        addr           = '0;
        data           = '0;
        test_name      = "";
        expect_no_output = 0;
        from_programming = 0;
        port             = -1;
        frames.delete();
        valid            = 0;
        set_prog_valid = 0;
        prog_value     = 0;
        use_custom_bits = 0;
        addr_start_bit = 0;
        data_start_bit = 0;
        addr_parity_bit = 0;
        data_parity_bit = 0;
        addr_stop_bit  = 0;
        data_stop_bit  = 0;
        request_reset  = 0;
        request_wait   = 0;
        wait_cycles    = 0;
        verbose        = 0;
    endfunction : set_defaults

    function string convert2string();
        return $sformatf(
            "addr=0x%0h data=0x%0h prog_valid=%0b prog=%0b reset=%0b wait=%0b(%0d) custom=%0b",
            addr, data, set_prog_valid, prog_value, request_reset, request_wait, wait_cycles, use_custom_bits
        );
    endfunction : convert2string

    function void do_copy(uvm_object rhs);
        command_transaction rhs_tx;

        if (rhs == null)
            `uvm_fatal("CMD_COPY", "Tried to copy from a null pointer")

        super.do_copy(rhs);

        if (!$cast(rhs_tx, rhs))
            `uvm_fatal("CMD_COPY", "Tried to copy wrong type")

        addr             = rhs_tx.addr;
        data             = rhs_tx.data;
        test_name        = rhs_tx.test_name;
        expect_no_output = rhs_tx.expect_no_output;
        from_programming = rhs_tx.from_programming;
        port             = rhs_tx.port;
        frames           = rhs_tx.frames;
        valid            = rhs_tx.valid;

        set_prog_valid   = rhs_tx.set_prog_valid;
        prog_value       = rhs_tx.prog_value;
        use_custom_bits  = rhs_tx.use_custom_bits;
        addr_start_bit   = rhs_tx.addr_start_bit;
        data_start_bit   = rhs_tx.data_start_bit;
        addr_parity_bit  = rhs_tx.addr_parity_bit;
        data_parity_bit  = rhs_tx.data_parity_bit;
        addr_stop_bit    = rhs_tx.addr_stop_bit;
        data_stop_bit    = rhs_tx.data_stop_bit;

        request_reset    = rhs_tx.request_reset;
        request_wait     = rhs_tx.request_wait;
        wait_cycles      = rhs_tx.wait_cycles;
        verbose          = rhs_tx.verbose;
    endfunction : do_copy

    function command_transaction clone_me();
        uvm_object tmp;
        command_transaction clone;

        tmp = this.clone();
        $cast(clone, tmp);
        return clone;
    endfunction : clone_me

endclass : command_transaction