/* Quartus Prime Version 23.1std.1 Build 993 05/14/2024 SC Lite Edition */
JedecChain;
	FileRevision(JESD32A);
	DefaultMfr(6E);

	P ActionCode(Cfg)
		Device PartName(10M50DAF484ES) Path("C:/Users/harry/OneDrive - University of Bath/VibeAI/1dcnn/quartus/cnn_vibration_monitor_example_design_10M50/output_files/") File("cnn_vibration_monitor_10M50.sof") MfrSpec(OpMask(1));
	P ActionCode(Ign)
		Device PartName(1_BIT_TAP) MfrSpec(OpMask(0));
	P ActionCode(Ign)
		Device PartName(VTAP10) MfrSpec(OpMask(0));

ChainEnd;

AlteraBegin;
	ChainType(JTAG);
AlteraEnd;
