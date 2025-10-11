;; -*-Compilation-*-
;; In Emacs: Click on warnings to get to their sources
;; This file has been generated because constant object marking
;; feature was enabled through the coverage configuration file.
/home/student/kligeza/VDIC2/lab01/tb/simple_uart_switch_tb.sv:7:Toggle object 'prog' evaluates to constant 'X' and will be excluded from coverage (simple_uart_switch_tb)
/home/student/kligeza/VDIC2/lab01/tb/simple_uart_switch_tb.sv:8:Toggle object 'sin' evaluates to constant 'X' and will be excluded from coverage (simple_uart_switch_tb)
/home/student/kligeza/VDIC2/common/simple_uart_switch.svp:28:Toggle object 'prog' evaluates to constant 'X' and will be excluded from coverage (simple_uart_switch_tb.u_simple_switch_uart)
/home/student/kligeza/VDIC2/common/simple_uart_switch.svp:29:Toggle object 'sin' evaluates to constant 'X' and will be excluded from coverage (simple_uart_switch_tb.u_simple_switch_uart)
