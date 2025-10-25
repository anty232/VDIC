module coverage(bfm_if bfm);
    import uartswitch_tb_pkg::*;

    covergroup forwarding_cov with function sample();
        option.name = "cg_forwarding";

        addr_cp : coverpoint bfm.cov_addr {
            bins all_addr[] = {[0:255]};
        }

        data_cp : coverpoint bfm.cov_data {
            bins all_data[] = {[0:255]};
        }

        port_cp : coverpoint bfm.cov_port {
            bins sout0 = {0};
            bins sout1 = {1};
        }

        addr_by_port : cross addr_cp, port_cp;
        data_by_port : cross data_cp, port_cp;
        addr_by_data : cross addr_cp, data_cp;
    endgroup

    covergroup async_reset_cov with function sample();
        option.name = "cg_async_reset";

        port_cp : coverpoint bfm.cov_rst_port {
            bins sout0 = {0};
            bins sout1 = {1};
        }
    endgroup

    covergroup error_frame_cov with function sample();
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
    endgroup

    forwarding_cov fwd_cov;
    async_reset_cov rst_cov;
    error_frame_cov err_cov;

    initial begin
        fwd_cov = new();
        forever begin
            @bfm.forwarding_sample_ev;
            fwd_cov.sample();
        end
    end

    initial begin
        rst_cov = new();
        forever begin
            @bfm.reset_sample_ev;
            rst_cov.sample();
        end
    end

    initial begin
        err_cov = new();
        forever begin
            @bfm.error_sample_ev;
            err_cov.sample();
        end
    end

endmodule : coverage