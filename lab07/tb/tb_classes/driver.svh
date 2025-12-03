class driver extends uvm_component;
    `uvm_component_utils(driver)

    //------------------------------------------------------------------------------
    // local variables
    //------------------------------------------------------------------------------
    protected virtual bfm_if bfm;
    uvm_get_port #(command_transaction) command_port;

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
            `uvm_fatal("DRV", "Failed to get BFM")

        command_port = new("command_port", this);
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // run phase
    //------------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        command_transaction cmd;

        forever begin
            command_port.get(cmd);
            if (cmd.request_reset) begin
                bfm.reset_switch();
                continue;
            end

            if (cmd.request_wait) begin
                bfm.wait_clock_cycles(cmd.wait_cycles);
                continue;
            end
            
            if (cmd.set_prog_valid)
                bfm.set_prog(cmd.prog_value);

            if (cmd.set_prog_valid && !cmd.use_custom_bits && cmd.addr === '0 && cmd.data === '0)
                continue;

            if (cmd.use_custom_bits) begin
                bfm.send_uart_byte_custom(cmd.addr_start_bit, cmd.addr, cmd.addr_parity_bit, cmd.addr_stop_bit);
                bfm.send_uart_byte_custom(cmd.data_start_bit, cmd.data, cmd.data_parity_bit, cmd.data_stop_bit);
            end
            else begin
                bfm.send_uart_byte(cmd.addr);
                bfm.send_uart_byte(cmd.data);
            end
        end
    endtask : run_phase

endclass : driver