class result_transaction extends uvm_sequence_item;

    int          port;
    uart_frame_t frames[$];
    bit          timed_out;

    `uvm_object_utils_begin(result_transaction)
        `uvm_field_int(port,       UVM_ALL_ON | UVM_DEC)
        `uvm_field_queue_int(frames, UVM_ALL_ON)
        `uvm_field_int(timed_out,  UVM_ALL_ON | UVM_DEC)
    `uvm_object_utils_end

    function new(string name = "result_transaction");
        super.new(name);
        port      = -1;
        timed_out = 0;
    endfunction : new

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        result_transaction other;
        bit same;

        if (!$cast(other, rhs)) begin
            `uvm_fatal("RES_CMP", "Failed to cast rhs to result_transaction")
        end

        same = super.do_compare(rhs, comparer);
        same &= (port == other.port);

        if (frames.size() != other.frames.size())
            same = 0;
        else begin
            foreach (frames[i]) begin
                if (frames[i] !== other.frames[i])
                    same = 0;
            end
        end

        // Ignore timed_out when both expected and actual have no frames
        if (!(frames.size() == 0 && other.frames.size() == 0))
            same &= (timed_out == other.timed_out);

        return same;
    endfunction : do_compare

    function string convert2string();
        return $sformatf(
            "port=%0d frames=%0d timed_out=%0b",
            port, frames.size(), timed_out
        );
    endfunction : convert2string

    function void do_copy(uvm_object rhs);
        result_transaction rhs_tx;

        if (rhs == null)
            `uvm_fatal("RES_COPY", "Tried to copy from a null pointer")

        super.do_copy(rhs);

        if (!$cast(rhs_tx, rhs))
            `uvm_fatal("RES_COPY", "Tried to copy wrong type")

        port      = rhs_tx.port;
        frames    = rhs_tx.frames;
        timed_out = rhs_tx.timed_out;
    endfunction : do_copy

    function result_transaction clone_me();
        uvm_object tmp;
        result_transaction clone;

        tmp = this.clone();
        $cast(clone, tmp);
        return clone;
    endfunction : clone_me

endclass : result_transaction