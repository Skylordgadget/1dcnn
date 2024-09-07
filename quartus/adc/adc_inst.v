	adc u0 (
		.altpll_0_c1_clk                      (<connected-to-altpll_0_c1_clk>),                      //                  altpll_0_c1.clk
		.altpll_0_pll_slave_read              (<connected-to-altpll_0_pll_slave_read>),              //           altpll_0_pll_slave.read
		.altpll_0_pll_slave_write             (<connected-to-altpll_0_pll_slave_write>),             //                             .write
		.altpll_0_pll_slave_address           (<connected-to-altpll_0_pll_slave_address>),           //                             .address
		.altpll_0_pll_slave_readdata          (<connected-to-altpll_0_pll_slave_readdata>),          //                             .readdata
		.altpll_0_pll_slave_writedata         (<connected-to-altpll_0_pll_slave_writedata>),         //                             .writedata
		.clk_clk                              (<connected-to-clk_clk>),                              //                          clk.clk
		.modular_adc_0_clock_clk              (<connected-to-modular_adc_0_clock_clk>),              //          modular_adc_0_clock.clk
		.modular_adc_0_command_valid          (<connected-to-modular_adc_0_command_valid>),          //        modular_adc_0_command.valid
		.modular_adc_0_command_channel        (<connected-to-modular_adc_0_command_channel>),        //                             .channel
		.modular_adc_0_command_startofpacket  (<connected-to-modular_adc_0_command_startofpacket>),  //                             .startofpacket
		.modular_adc_0_command_endofpacket    (<connected-to-modular_adc_0_command_endofpacket>),    //                             .endofpacket
		.modular_adc_0_command_ready          (<connected-to-modular_adc_0_command_ready>),          //                             .ready
		.modular_adc_0_reset_sink_reset_n     (<connected-to-modular_adc_0_reset_sink_reset_n>),     //     modular_adc_0_reset_sink.reset_n
		.modular_adc_0_response_valid         (<connected-to-modular_adc_0_response_valid>),         //       modular_adc_0_response.valid
		.modular_adc_0_response_channel       (<connected-to-modular_adc_0_response_channel>),       //                             .channel
		.modular_adc_0_response_data          (<connected-to-modular_adc_0_response_data>),          //                             .data
		.modular_adc_0_response_startofpacket (<connected-to-modular_adc_0_response_startofpacket>), //                             .startofpacket
		.modular_adc_0_response_endofpacket   (<connected-to-modular_adc_0_response_endofpacket>),   //                             .endofpacket
		.reset_reset_n                        (<connected-to-reset_reset_n>),                        //                        reset.reset_n
		.altpll_0_locked_conduit_export       (<connected-to-altpll_0_locked_conduit_export>),       //      altpll_0_locked_conduit.export
		.modular_adc_0_adc_pll_locked_export  (<connected-to-modular_adc_0_adc_pll_locked_export>)   // modular_adc_0_adc_pll_locked.export
	);

