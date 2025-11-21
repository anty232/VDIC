`ifndef COVERAGE_SVH
`define COVERAGE_SVH

class coverage extends uvm_component;
    `uvm_component_utils(coverage)

    // BFM z TB
    protected virtual bfm_if bfm;

    // === Instancje covergroupów jako pola klasy (bez 'protected' przy deklaracji) ===
    // Uwaga: w Xcelium kwalifikatory dostępu przy 'covergroup' potrafią wywołać błąd parsera,
    // dlatego nie poprzedzamy ich 'protected'. Dostęp kontrolujemy konwencją.
    covergroup fwd_cov with function sample();
        option.name = "cg_forwarding";

        addr_cp : coverpoint bfm.cov_addr  { bins all_addr[] = {[0:255]}; }
        data_cp : coverpoint bfm.cov_data  { bins all_data[] = {[0:255]}; }
        port_cp : coverpoint bfm.cov_port  {
            bins sout0 = {0};
            bins sout1 = {1};
        }

        addr_by_port : cross addr_cp, port_cp;
        data_by_port : cross data_cp, port_cp;
        addr_by_data : cross addr_cp, data_cp;
    endgroup : fwd_cov

    covergroup rst_cov with function sample();
        option.name = "cg_async_reset";
        port_cp : coverpoint bfm.cov_rst_port {
            bins sout0 = {0};
            bins sout1 = {1};
        }
    endgroup : rst_cov

    covergroup err_cov with function sample();
        option.name = "cg_error_frames";

        frame_kind_cp : coverpoint bfm.cov_err_frame_kind {
            bins addr = {FRAME_KIND_ADDR};
            bins data = {FRAME_KIND_DATA};
        }

        error_type_cp : coverpoint bfm.cov_err_error_type {
            bins start_bit  = {ERR_START_BIT};
            bins parity_bit = {ERR_PARITY_BIT};
            bins stop_bit   = {ERR_STOP_BIT};
        }

        frame_error_cross : cross frame_kind_cp, error_type_cp;
    endgroup : err_cov

    // --- Konstruktor ---
    function new(string name, uvm_component parent);
        super.new(name, parent);
        fwd_cov = new();
        rst_cov = new();
        err_cov = new();
    endfunction : new

    // --- Build ---
    function void build_phase(uvm_phase phase);
        if(!uvm_config_db#(virtual bfm_if)::get(null, "*", "bfm", bfm))
            `uvm_fatal("COV", "Failed to get BFM from config DB")
    endfunction : build_phase

    // --- Zadania próbkowania ---
    protected task sample_forwarding();
        forever begin
            @bfm.forwarding_sample_ev;
            fwd_cov.sample();
        end
    endtask : sample_forwarding

    protected task sample_reset();
        forever begin
            @bfm.reset_sample_ev;
            rst_cov.sample();
        end
    endtask : sample_reset

    protected task sample_error();
        forever begin
            @bfm.error_sample_ev;
            err_cov.sample();
        end
    endtask : sample_error

    // --- Start pokrycia ---
    task run_phase(uvm_phase phase);
        fork
            sample_forwarding();
            sample_reset();
            sample_error();
        join_none
    endtask : run_phase

endclass : coverage

`endif // COVERAGE_SVH