//
// - Issue memory reads and writes to data cache
// - Aligns small write values correctly
//
module memory_access_stage
	#(parameter				CORE_ID = 30'd0)

	(input					clk,
	output reg [511:0]		ddata_o = 0,
	output 					dwrite_o,
	output [63:0] 			write_mask_o,
	input [31:0]			instruction_i,
	output reg[31:0]		instruction_o = 0,
	input[1:0]				strand_id_i,
	output reg[1:0]			strand_id_o = 0,
	input					flush_i,
	input [31:0]			pc_i,
	output reg[31:0]		pc_o = 0,
	input[511:0]			store_value_i,
	input					has_writeback_i,
	input[6:0]				writeback_reg_i,
	input					writeback_is_vector_i,	
	output reg 				has_writeback_o = 0,
	output reg[6:0]			writeback_reg_o = 0,
	output reg				writeback_is_vector_o = 0,
	input [15:0]			mask_i,
	output reg[15:0]		mask_o = 0,
	input [511:0]			result_i,
	output reg [511:0]		result_o = 0,
	input					dstbuf_full_i,
	input [3:0]				reg_lane_select_i,
	output reg[3:0]			reg_lane_select_o = 0,
	output reg[3:0]			cache_lane_select_o = 0,
	output wire				rollback_request_o,
	output [31:0]			rollback_address_o,
	output reg[3:0]			strand_enable_o = 4'b1111,
	output [3:0]			resume_strand_o,
	input wire[3:0]			load_complete_strands_i,
	output reg[31:0]		daddress_o = 0,
	output reg				daccess_o = 0,
	output reg				was_access_o = 0,
	output [1:0]			dstrand_o,
	input [31:0]			strided_offset_i,
	output reg[31:0]		strided_offset_o = 0,
	input [31:0]			base_addr_i,
	output 					suspend_request_o);
	
	reg[511:0]				result_nxt = 0;
	reg[31:0]				_test_cr7 = 0;
	reg[3:0]				byte_write_mask = 0;
	reg[15:0]				word_write_mask = 0;
	wire[31:0]				lane_value;
	reg[3:0]				store_wait_strands = 0;
	wire[31:0]				strided_ptr;
	wire[31:0]				scatter_gather_ptr;
	reg[3:0]				cache_lane_select_nxt = 0;
	
	wire[3:0] c_op_type = instruction_i[28:25];
	wire is_load = instruction_i[29];
	wire is_fmt_c = instruction_i[31:30] == 2'b10;	
	assign dstrand_o = strand_id_i;

	assign rollback_request_o = daccess_o && !is_load && dstbuf_full_i;
	assign rollback_address_o = pc_i - 4;
	assign resume_strand_o = load_complete_strands_i | (!dstbuf_full_i & store_wait_strands);
	assign suspend_request_o = rollback_request_o;
	
	always @(posedge clk)
	begin
		if (daccess_o && !is_load && dstbuf_full_i)
		begin
			// If we have suspended a strand on a store, record that here
			store_wait_strands <= store_wait_strands | (1 << strand_id_i);
		end
		else if (!dstbuf_full_i && store_wait_strands)
		begin
			// Resume strands
			store_wait_strands <= 0;
		end
	end

	wire is_control_register_transfer = instruction_i[31:30] == 2'b10
		&& instruction_i[28:25] == 4'b0110;

	// Note that we still assert write even if the store buffer is full
	// to indicate that it shouldn't do a cache load.  It will ignore
	// the write in that case.
	assign dwrite_o = instruction_i[31:29] == 3'b100 
		&& !is_control_register_transfer && !flush_i;

	// word_write_mask
	always @*
	begin
		case (c_op_type)
			4'b0111, 4'b1000, 4'b1001:	// Block vector access
				word_write_mask = mask_i;
			
			4'b1010, 4'b1011, 4'b1100,	// Strided vector access 
			4'b1101, 4'b1110, 4'b1111:	// Scatter/Gather access
			begin
				if (mask_i & (16'h8000 >> reg_lane_select_i))
					word_write_mask = (16'h8000 >> cache_lane_select_nxt);
				else
					word_write_mask = 0;
			end

			default:	// Scalar access
				word_write_mask = 16'h8000 >> cache_lane_select_nxt;
		endcase
	end

	wire[511:0] endian_twiddled_data = {
		store_value_i[487:480], store_value_i[495:488], store_value_i[503:496], store_value_i[511:504], 
		store_value_i[455:448], store_value_i[463:456], store_value_i[471:464], store_value_i[479:472], 
		store_value_i[423:416], store_value_i[431:424], store_value_i[439:432], store_value_i[447:440], 
		store_value_i[391:384], store_value_i[399:392], store_value_i[407:400], store_value_i[415:408], 
		store_value_i[359:352], store_value_i[367:360], store_value_i[375:368], store_value_i[383:376], 
		store_value_i[327:320], store_value_i[335:328], store_value_i[343:336], store_value_i[351:344], 
		store_value_i[295:288], store_value_i[303:296], store_value_i[311:304], store_value_i[319:312], 
		store_value_i[263:256], store_value_i[271:264], store_value_i[279:272], store_value_i[287:280], 
		store_value_i[231:224], store_value_i[239:232], store_value_i[247:240], store_value_i[255:248], 
		store_value_i[199:192], store_value_i[207:200], store_value_i[215:208], store_value_i[223:216], 
		store_value_i[167:160], store_value_i[175:168], store_value_i[183:176], store_value_i[191:184], 
		store_value_i[135:128], store_value_i[143:136], store_value_i[151:144], store_value_i[159:152], 
		store_value_i[103:96], store_value_i[111:104], store_value_i[119:112], store_value_i[127:120], 
		store_value_i[71:64], store_value_i[79:72], store_value_i[87:80], store_value_i[95:88], 
		store_value_i[39:32], store_value_i[47:40], store_value_i[55:48], store_value_i[63:56], 
		store_value_i[7:0], store_value_i[15:8], store_value_i[23:16], store_value_i[31:24] 	
	};

	lane_select_mux stval_mux(
		.value_i(store_value_i),
		.value_o(lane_value),
		.lane_select_i(reg_lane_select_i));

	// byte_write_mask and ddata_o
	always @*
	begin
		case (instruction_i[28:25])
			4'b0000, 4'b0001: // Byte
			begin
				case (result_i[1:0])
					2'b00:
					begin
						byte_write_mask = 4'b1000;
						ddata_o = {16{ store_value_i[7:0], 24'd0 }};
					end

					2'b01:
					begin
						byte_write_mask = 4'b0100;
						ddata_o = {16{ 8'd0, store_value_i[7:0], 16'd0 }};
					end

					2'b10:
					begin
						byte_write_mask = 4'b0010;
						ddata_o = {16{ 16'd0, store_value_i[7:0], 8'd0 }};
					end

					2'b11:
					begin
						byte_write_mask = 4'b0001;
						ddata_o = {16{ 24'd0, store_value_i[7:0] }};
					end
				endcase
			end

			4'b0010, 4'b0011: // 16 bits
			begin
				if (result_i[1] == 1'b0)
				begin
					byte_write_mask = 4'b1100;
					ddata_o = {16{store_value_i[7:0], store_value_i[15:8], 16'd0 }};
				end
				else
				begin
					byte_write_mask = 4'b0011;
					ddata_o = {16{16'd0, store_value_i[7:0], store_value_i[15:8] }};
				end
			end

			4'b0100, 4'b0101, 4'b0110: // 32 bits
			begin
				byte_write_mask = 4'b1111;
				ddata_o = {16{store_value_i[7:0], store_value_i[15:8], store_value_i[23:16], 
					store_value_i[31:24] }};
			end

			4'b1101, 4'b1110, 4'b1111,	// Scatter
			4'b1010, 4'b1011, 4'b1100:	// Strided
			begin
				byte_write_mask = 4'b1111;
				ddata_o = {16{lane_value[7:0], lane_value[15:8], lane_value[23:16], 
					lane_value[31:24] }};
			end

			default: // Vector
			begin
				byte_write_mask = 4'b1111;
				ddata_o = endian_twiddled_data;
			end
		endcase
	end

	assign strided_ptr = base_addr_i[31:0] + strided_offset_i;
	lane_select_mux ptr_mux(
		.value_i(result_i),
		.lane_select_i(reg_lane_select_i),
		.value_o(scatter_gather_ptr));

	// We issue the tag request in parallel with the memory access stage, so these
	// are not registered.
	always @*
	begin
		case (c_op_type)
			4'b1010, 4'b1011, 4'b1100:	// Strided vector access 
			begin
				daddress_o = { strided_ptr[31:6], 6'd0 };
				cache_lane_select_nxt = strided_ptr[5:2];
			end

			4'b1101, 4'b1110, 4'b1111:	// Scatter/Gather access
			begin
				daddress_o = { scatter_gather_ptr[31:6], 6'd0 };
				cache_lane_select_nxt = scatter_gather_ptr[5:2];
			end
		
			default: // Block vector access or Scalar transfer
			begin
				daddress_o = { result_i[31:6], 6'd0 };
				cache_lane_select_nxt = result_i[5:2];
			end
		endcase
	end

	always @*
	begin
		if (flush_i)
			daccess_o = 0;
		else if (is_fmt_c)
		begin
			// Note that we check the mask bit for this lane.
			if (c_op_type == 4'b0111 || c_op_type ==  4'b1000
				|| c_op_type == 4'b1001)
			begin
				daccess_o = 1;		
			end
			else
			begin
				daccess_o = !is_control_register_transfer
					&& (mask_i & (16'h8000 >> reg_lane_select_i)) != 0;
			end
		end
		else
			daccess_o =0;
	end
	
	assign write_mask_o = {
		word_write_mask[15] & byte_write_mask[3],
		word_write_mask[15] & byte_write_mask[2],
		word_write_mask[15] & byte_write_mask[1],
		word_write_mask[15] & byte_write_mask[0],
		word_write_mask[14] & byte_write_mask[3],
		word_write_mask[14] & byte_write_mask[2],
		word_write_mask[14] & byte_write_mask[1],
		word_write_mask[14] & byte_write_mask[0],
		word_write_mask[13] & byte_write_mask[3],
		word_write_mask[13] & byte_write_mask[2],
		word_write_mask[13] & byte_write_mask[1],
		word_write_mask[13] & byte_write_mask[0],
		word_write_mask[12] & byte_write_mask[3],
		word_write_mask[12] & byte_write_mask[2],
		word_write_mask[12] & byte_write_mask[1],
		word_write_mask[12] & byte_write_mask[0],
		word_write_mask[11] & byte_write_mask[3],
		word_write_mask[11] & byte_write_mask[2],
		word_write_mask[11] & byte_write_mask[1],
		word_write_mask[11] & byte_write_mask[0],
		word_write_mask[10] & byte_write_mask[3],
		word_write_mask[10] & byte_write_mask[2],
		word_write_mask[10] & byte_write_mask[1],
		word_write_mask[10] & byte_write_mask[0],
		word_write_mask[9] & byte_write_mask[3],
		word_write_mask[9] & byte_write_mask[2],
		word_write_mask[9] & byte_write_mask[1],
		word_write_mask[9] & byte_write_mask[0],
		word_write_mask[8] & byte_write_mask[3],
		word_write_mask[8] & byte_write_mask[2],
		word_write_mask[8] & byte_write_mask[1],
		word_write_mask[8] & byte_write_mask[0],
		word_write_mask[7] & byte_write_mask[3],
		word_write_mask[7] & byte_write_mask[2],
		word_write_mask[7] & byte_write_mask[1],
		word_write_mask[7] & byte_write_mask[0],
		word_write_mask[6] & byte_write_mask[3],
		word_write_mask[6] & byte_write_mask[2],
		word_write_mask[6] & byte_write_mask[1],
		word_write_mask[6] & byte_write_mask[0],
		word_write_mask[5] & byte_write_mask[3],
		word_write_mask[5] & byte_write_mask[2],
		word_write_mask[5] & byte_write_mask[1],
		word_write_mask[5] & byte_write_mask[0],
		word_write_mask[4] & byte_write_mask[3],
		word_write_mask[4] & byte_write_mask[2],
		word_write_mask[4] & byte_write_mask[1],
		word_write_mask[4] & byte_write_mask[0],
		word_write_mask[3] & byte_write_mask[3],
		word_write_mask[3] & byte_write_mask[2],
		word_write_mask[3] & byte_write_mask[1],
		word_write_mask[3] & byte_write_mask[0],
		word_write_mask[2] & byte_write_mask[3],
		word_write_mask[2] & byte_write_mask[2],
		word_write_mask[2] & byte_write_mask[1],
		word_write_mask[2] & byte_write_mask[0],
		word_write_mask[1] & byte_write_mask[3],
		word_write_mask[1] & byte_write_mask[2],
		word_write_mask[1] & byte_write_mask[1],
		word_write_mask[1] & byte_write_mask[0],
		word_write_mask[0] & byte_write_mask[3],
		word_write_mask[0] & byte_write_mask[2],
		word_write_mask[0] & byte_write_mask[1],
		word_write_mask[0] & byte_write_mask[0]
	};
	
	// Transfer from control register
	always @*
	begin
		if (is_control_register_transfer)
		begin
			if (instruction_i[4:0] == 0)	// Strand ID register
				result_nxt = { CORE_ID, strand_id_i };
			else if (instruction_i[4:0] == 7)
				result_nxt = _test_cr7;	
			else if (instruction_i[4:0] == 31)
				result_nxt = strand_enable_o;
			else
				result_nxt = 0;
		end
		else
			result_nxt = result_i;
	end

	// Transfer to control register
	always @(posedge clk)
	begin
		if (!flush_i && is_control_register_transfer && instruction_i[29] == 1'b0)
		begin
			if (instruction_i[4:0] == 7)
				_test_cr7 <= #1 store_value_i[31:0];
			else if (instruction_i[4:0] == 31)
				strand_enable_o <= #1 store_value_i[3:0];
		end
	end
	
	always @(posedge clk)
	begin
		if (flush_i)
		begin
			strand_id_o					<= #1 0;
			instruction_o 				<= #1 0;
			writeback_reg_o 			<= #1 0;
			writeback_is_vector_o 		<= #1 0;
			has_writeback_o 			<= #1 0;
			mask_o 						<= #1 0;
			result_o 					<= #1 0;
			reg_lane_select_o			<= #1 0;
			cache_lane_select_o			<= #1 0;
			was_access_o				<= #1 0;
			pc_o						<= #1 0;
			strided_offset_o			<= #1 0;
		end
		else
		begin	
			strand_id_o					<= #1 strand_id_i;
			instruction_o 				<= #1 instruction_i;
			writeback_reg_o 			<= #1 writeback_reg_i;
			writeback_is_vector_o 		<= #1 writeback_is_vector_i;
			has_writeback_o 			<= #1 has_writeback_i;
			mask_o 						<= #1 mask_i;
			result_o 					<= #1 result_nxt;
			reg_lane_select_o			<= #1 reg_lane_select_i;
			cache_lane_select_o			<= #1 cache_lane_select_nxt;
			was_access_o				<= #1 daccess_o;
			pc_o						<= #1 pc_i;
			strided_offset_o			<= #1 strided_offset_i;
		end
	end
endmodule
