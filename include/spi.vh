`ifndef SPI_VH
`define SPI_VH

package spi_pkg;
    typedef enum logic [3:0]
        { NONE
        , READ
        , WRITE
        , ERASE
        , END
        } cmd_t;
endpackage

`endif
