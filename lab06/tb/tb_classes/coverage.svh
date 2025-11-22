`ifndef COVERAGE_SVH
`define COVERAGE_SVH



class coverage extends uvm_component;
    `uvm_component_utils(coverage)

    //----------------------------------------------------------------------------
    // TLM połączenia
    //----------------------------------------------------------------------------

    // Z command_monitor_h dostajemy input_transaction_t
    uvm_analysis_imp_cmd    #(input_transaction_t, coverage) cmd_imp;

    // Z result_monitor_h dostajemy result_packet_t
    uvm_analysis_imp_result #(result_packet_t,   coverage)   result_imp;

    //----------------------------------------------------------------------------
    // Zmienne pomocnicze do covergroup
    //----------------------------------------------------------------------------

    // Forwarding
    logic [7:0] cov_addr;
    logic [7:0] cov_data;
    int         cov_port;

    // Timeout
    bit         cov_timed_out;

    //----------------------------------------------------------------------------
    // Covergroups
    //----------------------------------------------------------------------------

    // Forwarding: adres / dane / port na podstawie input_transaction_t
    covergroup fwd_cov with function sample();
        option.name = "cg_forwarding";

        addr_cp : coverpoint cov_addr  { bins all_addr[] = {[0:255]}; }
        data_cp : coverpoint cov_data  { bins all_data[] = {[0:255]}; }
        port_cp : coverpoint cov_port  {
            bins sout0 = {0};
            bins sout1 = {1};
            
        }

        addr_by_port : cross addr_cp, port_cp;
        data_by_port : cross data_cp, port_cp;
        addr_by_data : cross addr_cp, data_cp;
    endgroup : fwd_cov

    
    covergroup timeout_cov with function sample();
        option.name = "cg_timeout";

        port_cp : coverpoint cov_port {
            bins sout0 = {0};
            bins sout1 = {1};
        }

        timeout_cp : coverpoint cov_timed_out {
            bins no_timeout = {0};
            bins timeout    = {1};
        }

        timeout_by_port : cross port_cp, timeout_cp;
    endgroup : timeout_cov

    //----------------------------------------------------------------------------
    // Konstruktor
    //----------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        fwd_cov     = new();
        timeout_cov = new();
    endfunction : new

    //----------------------------------------------------------------------------
    // build_phase  żadnego bfm, tylko tworzymy impy
    //----------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        cmd_imp    = new("cmd_imp",    this);
        result_imp = new("result_imp", this);
    endfunction : build_phase

    //----------------------------------------------------------------------------
    // write_cmd  wywoływane z command_monitor_h.ap.write(tx)
    //----------------------------------------------------------------------------
    function void write_cmd(input_transaction_t tx);
        
        if (!tx.valid)
            return;

        cov_addr = tx.addr;

        
        if (tx.frames.size() >= 2)
            cov_data = tx.frames[1].data;
        else if (tx.frames.size() >= 1)
            cov_data = tx.frames[0].data;
        else
            cov_data = '0;

        cov_port = tx.port;

        fwd_cov.sample();
    endfunction : write_cmd

    //----------------------------------------------------------------------------
    // write_result  wywoływane z result_monitor_h.ap.write(pkt)
    //----------------------------------------------------------------------------
    function void write_result(result_packet_t pkt);
        cov_port       = pkt.port;
        cov_timed_out  = pkt.timed_out;

        timeout_cov.sample();
    endfunction : write_result

    //----------------------------------------------------------------------------
    // run_phase  nic tu nie robimy, wszystko w write_*()
    //----------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        // brak aktywnego zachowania  czysta pasywna coverage
        #0;
    endtask : run_phase

endclass : coverage

`endif // COVERAGE_SVH
