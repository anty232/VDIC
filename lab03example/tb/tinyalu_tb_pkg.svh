/******************************************************************************
 * (C) Copyright 2024 AGH University All Rights Reserved
 *
 * MODULE:    tinyalu_tb_pkg
 * DEVICE:
 * PROJECT:
 * AUTHOR:    szczygie
 * DATE:      2024 12:20:30
 *
 *******************************************************************************/

package tinyalu_tb_pkg;

    typedef enum bit[2:0] {
        no_op  = 3'b000,
        add_op = 3'b001,
        and_op = 3'b010,
        xor_op = 3'b011,
        mul_op = 3'b100,
        rst_op = 3'b111
    } operation_t;

endpackage
