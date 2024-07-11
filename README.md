Important Definitions :-

-> MAC (Media Access Controller) - It is the part of the system which converts a packet from the OS into a stream of bytes to put on the fibre(wire).

-> PHY (Physical Layer) - Converts the signals from MAC into signals on one or more wires/fibres.

-> MII (Media Independent Interface) - Set of standard pins between MAC and PHY so that the MAC doesn't have to be customised according to the PHY and 
   vice-versa.

-> RMII (Reduced Media Independent Interface) - Uses less no. of pins than standard MAC. Visit - https://en.wikipedia.org/wiki/Media-independent_interface#RMII

-> RGMII (Reduced Gigabit MII) - RGMII is the most common interface because it supports 10 Mbps, 100 Mbps, and 1000 Mbps connection speeds at the PHY layer. RGMII uses four-bit wide transmit and receive data paths, each with its own source-synchronous clock. All transmit data and control signals are source synchronous to TX_CLK, and all receive data and control signals are source synchronous to RX_CLK.For all speed modes, TX_CLK is sourced by the MAC, and RX_CLK is sourced by the PHY. In 1000 Mbps mode, TX_CLK and RX_CLK are 125 MHz, and Dual Data Rate (DDR) signaling is used. In 10 Mbps and 100 Mbps modes, TX_CLK and RX_CLK are 2.5 MHz and 25 MHz, respectively, and rising edge Single Data Rate (SDR) signaling is used.

P.S -> Check out the difference betweem rmii and rgmii further down this file.

-> MDIO (Management Data Input/Output) - It is a serial bus which is a subset of yhe MII that is used to transfer management information between 
   MAC and PHY(bidirectional).

-> Baud Rate - unit for symbol rate or modulation rate in symbols per second or pulses per second. Symbol duration time , Ts = 1/fs.
   where 'fs' is the symbol rate, eg:- 1000 Bd => 1000 symbols/sec.

-> UART (Universal Asynchronous Receiver-Transmitter) - It is the communication protocol we will use in this project. It is based on the "Ad-Hoc/Peer-to-Peer" topology
   i.e. there is no master or slave. Each component in this protocol has a TX(transmission line) and RX(receive line). Since this is an asynchronous protocol, the clock
   modules of both the devices should be synchronized manually to match the baud rate or it will result in data loss.
   <> Structure of the data - [Start-bit]...[8-bit data]...[parity-bit]...[stop-bit]

                                      ( D0 D1 D2 D3 D4 D5 D6 D7 D8 )
                                      
                                        MSB ----------------->> LSB		


  Youtube link for UART - https://www.youtube.com/watch?v=JuvWbRhhpdI   

-> VRAM (Video RAM) - RAM from the GPU, from where the graphics module extracts data and displays over the VGA.

-> Pixel Clock - Rate at which pixels are transmitted in order for a full frame of pixels to fit within a single refresh cycle.

-> RS232 (Recommended Standard 232) - In RS-232, user data is sent as a time-series of bits. Both synchronous and asynchronous transmissions are supported by the standard.
   In addition to the data circuits, the standard defines a number of control circuits used to manage the connection between the DTE and DCE. Each data or control circuit 
   only operates in one direction, that is, signaling from a DTE to the attached DCE or the reverse. Because transmit data and receive data are separate circuits, the 
   interface can operate in a full duplex manner, supporting concurrent data flow in both directions. The standard does not define character framing within the data stream 
   or character encoding. RS232 has two main components :-

    <> DTE (Data Terminal Equipment) -  is an end instrument that converts user information into signals or reconverts received signals.
	
 <> DCE (Data Circuit-Terminating Equipment) - It sits between the DTE and data transmiision circuit. Usually the DTE is the terminal(or computer) and DCE is the modem.
 
     ***Data and Control Signals ->
     
        DTR (Data Terminal Ready) - DTE is ready to receive ,initiate or continue a call.
        
        DCD (Data Carrier Detect) - DTE is receiving a carrier from DCE.
        
        DSR (Data Set Ready) - DCE is ready to receive abd send data.		
		
  CTS (Clear to Send) ; RTS (Request to Send) 
	
  <> When CTS is high , indicate s receiver is ready to accept data from transmitter. When low => buffer is full. // see UART Drivers(Mark) in  given pdf
	
  <> When RTS is high , indicates transmitter is ready to send data to receiver. If RTS is low => buffer is full.

   RS-232 logic and voltage levels

Data circuits	Control circuits	Voltage
0 (space)	      Asserted	       +3 to +15 V

1 (mark)	     Deasserted	       −15 to −3 V

-> Clock Domain Crossing (CDC) Synchronization - Whenn data needs to be transferred between different clock domains , it is essential to ensure that the receiving clock 
   captures the data correctly. Here FIFO acts as a buffer.

-> Clock Domain Asynchronous Interface - enanbles data to be written into the FIFO in one clock domain and read from another.

## Ethernet
-> It is the most widely used LAN (Local Area Network) technology. It operates within the data link layer and physical layer and supports data bandwidths of 10,100,1000
   10^4,4*10^4 Mbps and 100 Gbps.

<> Ethernet Standards - Defined by Layer 2 protocols and Layer 1 technologies. It should have 2 different sublayers of the data link layer to operate :-
   Logic Link Control(LLC) and the MAC sublayers. 

<> Structure of Ethernet - 

              {   Preamble  }...{  SFD  }....[Destination Address]....[Source Address]....[Length/Type]....[Data and Padding]....[CRC]

		   7 Bytes         1 Byte        6 Bytes                 6 Bytes           2 Bytes         Max 1500 Bytes        4 Bytes  
 
                                                                                                           Min 46 Bytes 
													   
             |<--Physical Layer	Header-->|  |<------------------------------Ethernet Frame-------------------------------------->|											    

## FGPA Graphics Protocol (FGP)
-> It is designed to facilitate the generation of frames within a network communication system. Components :- 

   1.) Offset Field - idicates the offset or starting position within the frame where the FGP data should be inserted. It defines the position within the frame where payload
       generated by the FGP should be placed.
   
   2.) Data Field - contains the actual payload generated by the FGP protocol.

<> FGP Offset Length - determines how accurately the position within the frame can be controlled.

<> FGP Data Length - length of the payload generated by the FGP and determines the size of data field in each FGP frame.

## FPGA Flow Control Protocol (FFCP)

-> It is used to flow control to prevent data loss, ensure data integrity, and regulate data transmission rates.

 ***Packet Structure -> 
 
    1.) Header - contains metadata for controlling data flow and includes files such as :-  type of packet (eg: SYN,MSG,ACK) 
                                                                                        :-  Index - indentifies the sequence number or index of the packet 
    
    2.) Data - FFCP packets may also include a data section for transmitting payload information.
 
 ***Packet Types ->
    
    1.) SYN(Synchronization) - initiates a connection between receiver and sender. Also contains information about sender's capabilities and settings.
    
    2.) MSG(Message) - carries payload data to be transmitted. May include application specific data or commands.
    
    3.) ACK(Acknowledgment) - confirms the successful receipt of a packet. Includes sequence no. of the acknowledged packet.

Structure of header byte - 8'b10xxxxxx // first 2 MSB decide ACK,SYN,MSG(10,00,01 respectively) and the next 6 LSB is the sequence number.
    
                             (ACK)
   
   **Study the Windowing process of FFCP in detail for better understanding**
   
## Pseudo Steps for the Networking System
 
 **Step-1** -> Header Extraction - When a packet is received for transmiision the FGP processing module extracts only the header portion of the packet.
 
 **Step-2** -> Payload Handling - The payload of the packet , which contains graphics data remains encrypted during the FGP process.
 
 **Step-3** -> Encryption - Done before FGP.
 
 **Step-4** -> Combination - The header and the encrypted payload are combined again into a single packet for transmission.
 
 **Step-5** -> Decryption at Receiver - Before decryption header is again seperated from payload , then the payload is decrypted.

##RMII Driver 

crsdv - Carrier Sense/Data Valid

-> CRS (Carrier Sense) - The 'crs' signal indicates the presence/absence of a carrier signal on the ethrnet.

                                                         (high)   (low)

-> DV (Data Valid) - 'crsdv' also serves as an indicator of the validity of the received data. When a frame is beign received 'crsdv' is asserted to signal that 
   the data beign received is valid and should be processed. When no valid data is beign received then 'crsdv' is deasserted.
   
##Ethernet Implementation 

-> CRC (Cyclic Redundancy Check) - This is a type of error checking in ethernet to detect errors in transmitted data. It is added to the ethernet frame as a trailer 
   following the payload, and is used to verify the integrity of the data. 
   
   ***Procedure*** - The CRC algorith generates a fixed size checksum based on the data content of the frame. When transmitting data, the CRC is calculated based 
     on the payload and appended to the frame. Upon reception , the CRC is recalculated based on the received data , excluding the CRC itself. If the calculated 
	 and received CRC match then the data was transmitted without errors or else it is discarded or retransmitted.
	 
-> Preamble - It consists of a specific bit pattern that helps in sync and detection of the beginning of the frame. Here it is 2'b01.   

   MAC_dst (MAC Destination) - 6 byte address that uniquely identifies the recepient address.
   
   MAC_src (MAC Source) - 6 byte source address of the sender of the frame. 
   
UART 
														 
This Verilog code implements a UART (Universal Asynchronous Receiver-Transmitter) module for fast data transmission and reception, designed for a baud rate of 12MBaud. 

### uart_rx_fast_driver Module:
- **Inputs**:
  - `clk`: Clock signal.
  - `clk_120mhz`: Clock signal at 120MHz.
  - `rst`: Reset signal.
  - `rxd`: Received data signal.

- **Outputs**:
  - `out`: Output data.
  - `outclk`: Clock signal for output data.

- **Functionality**:
  - Detects the start bit, receives subsequent bits, and constructs bytes from the received bits.
  - Uses a shift register to convert received bits into bytes.
  - Synchronizes the output data with the clock boundary using FIFOs.

### uart_tx_fast_driver Module:
- **Inputs**:
  - `clk`: Clock signal.
  - `clk_120mhz`: Clock signal at 120MHz. // 
  - `rst`: Reset signal.
  - `inclk`: Input clock signal.
  - `in`: Input data.

- **Outputs**:
  - `txd`: Transmitted data signal.
  - `rdy`: Ready signal indicating availability to transmit.

- **Functionality**:
  - Transmits data asynchronously.
  - Synchronizes input data with the clock boundary using FIFOs.
  - Uses a clock divider to control the timing of transmitted bits.
  - Prepends start and appends stop bits to transmitted data.

### uart_tx_fast_stream_driver Module:
- **Inputs**:
  - `clk`: Clock signal.
  - `clk_120mhz`: Clock signal at 120MHz.
  - `rst`: Reset signal.
  - `start`: Start signal.

- **Outputs**:
  - `txd`: Transmitted data signal.
  - `upstream_readclk`: Upstream read clock signal.

- **Functionality**:
  - Coordinates data transmission with the upstream module.
  - Utilizes the `uart_tx_fast_driver` module for actual data transmission.


Various parameters and constants related to video processing and communication protocols. 

1. `SYNC_DELAY_LEN`: Represents the length of synchronization delay, possibly used for synchronizing signals or processes.

2. `BYTE_LEN`: Specifies the length of a byte in bits, commonly used in digital communication protocols like UART.

3. `COLOR_CHANNEL_LEN`: Indicates the number of bits used to represent each color channel (e.g., red, green, blue) in a pixel.

4. `COLOR_LEN`: Defines the total number of bits required to represent a color, calculated as the product of `COLOR_CHANNEL_LEN` and 3 (for three color channels).

5. `BLOCK_LEN`: Specifies the length of a block, possibly used in data processing or memory allocation.

6. `PACKET_BUFFER_SIZE`: Defines the size of a packet buffer, likely used for storing incoming data packets before processing.

7. `PACKET_BUFFER_READ_LATENCY`: Represents the latency associated with reading data from the packet buffer.(here 2 clock cycles)

8. `PACKET_SYNTH_ROM_SIZE`: Specifies the size of a synthesizable ROM used for packet processing.

9. `PACKET_SYNTH_ROM_LATENCY`: Indicates the latency associated with accessing data from the synthesizable ROM.(here 2 clock cycles)

10. `VIDEO_CACHE_RAM_SIZE`: Defines the size of a video cache RAM, likely used for buffering video data during processing.

11. `VIDEO_CACHE_RAM_LATENCY`: Represents the latency associated with accessing data from the video cache RAM.

12. `VGA_WIDTH` and `VGA_HEIGHT`: Specify the width and height, respectively, of a VGA (Video Graphics Array) display, used in video rendering and output.

These parameters provide flexibility and configurability to the design, allowing the adjustment of buffer sizes, latency requirements, and other system parameters according to the specific needs of the application or hardware platform. They are crucial for dimensioning memory resources, optimizing performance, and ensuring compatibility with external interfaces or standards like VGA.


These Verilog modules implement the transmission (TX) and reception (RX) of Ethernet frames.

### `eth_body_tx` Module:
- **Purpose**: This module generates an Ethernet frame body on the byte level.
- **Inputs**:
  - `clk`: Clock signal.
  - `rst`: Reset signal.
  - `start`: Signal indicating the start of frame generation.
  - `in_done`: Signal indicating the completion of input data transmission.
  - `inclk`: Clock signal for input data.
  - `in`: Input data byte.
  - `readclk`: Clock signal for read operations.
  - `ram_outclk`: Clock signal for RAM output.
  - `ram_out`: Output data from RAM.
- **Outputs**:
  - `ram_readclk`: Clock signal for RAM read operations.
  - `outclk`: Clock signal for output data.
  - `out`: Output data byte.
  - `upstream_readclk`: Clock signal for upstream read operations.
  - `done`: Signal indicating completion of frame generation.

### `eth_tx` Module:
- **Purpose**: This module converts the Ethernet frame body into a continuous dibit stream.
- **Inputs**:
  - `clk`: Clock signal.
  - `rst`: Reset signal.
  - `start`: Signal indicating the start of frame transmission.
  - `in_done`: Signal indicating the completion of input data transmission.
  - `inclk`: Clock signal for input data.
  - `in`: Input data byte.
  - `ram_outclk`: Clock signal for RAM output.
  - `ram_out`: Output data from RAM.
- **Outputs**:
  - `ram_readclk`: Clock signal for RAM read operations.
  - `ram_raddr`: RAM read address.
  - `outclk`: Clock signal for output data.
  - `out`: Output dibit.
  - `upstream_readclk`: Clock signal for upstream read operations.
  - `done`: Signal indicating completion of frame transmission.

### `eth_rx` Module:
- **Purpose**: This module receives and processes Ethernet frames.
- **Inputs**:
  - `clk`: Clock signal.
  - `rst`: Reset signal.
  - `inclk`: Clock signal for input data.
  - `in`: Input dibit.
  - `in_done`: Signal indicating completion of input data transmission.
  - `downstream_done`: Signal indicating completion of downstream processing.
- **Outputs**:
  - `outclk`: Clock signal for output data.
  - `out`: Output data byte.
  - `ethertype_outclk`: Clock signal for ethertype output.
  - `ethertype_out`: Ethertype output data.
  - `err`: Error signal.
  - `done`: Signal indicating completion of frame reception.

These modules collectively implement the transmission and reception of Ethernet frames, handling tasks such as data generation, synchronization, and error checking.


These parameters define various constants and configurations related to Ethernet frame formatting and packet handling. 

1. **ETH_PREAMBLE_LEN**: Length of the Ethernet preamble in bytes/octets. The preamble is a sequence of alternating 1s and 0s used for synchronization and signaling the start of a frame.

2. **ETH_CRC_LEN**: Length of the Ethernet CRC (Cyclic Redundancy Check) in bytes. The CRC is used for error detection in Ethernet frames.

3. **ETH_GAP_LEN**: Length of the Ethernet inter-frame gap in bytes. This gap separates consecutive Ethernet frames to ensure proper frame delineation.

4. **ETH_MAC_LEN**: Length of the Ethernet MAC (Media Access Control) address in bytes. The MAC address uniquely identifies a device on a network.

5. **ETH_ETHERTYPE_LEN**: Length of the Ethernet Ethertype field in bytes. The Ethertype field specifies the protocol type of the encapsulated payload within the Ethernet frame.

6. **ETHERTYPE_FGP**: Ethertype value for the FGP (Frame Generation Protocol).

7. **ETHERTYPE_FFCP**: Ethertype value for the FFCP (Flow and Framing Control Protocol).

8. **FGP_OFFSET_LEN**: Length of the FGP offset field in bytes.

9. **FGP_DATA_LEN**: Length of FGP data in bytes.

10. **FGP_DATA_LEN_COLORS**: Length of FGP data in terms of color channels.

11. **FGP_LEN**: Total length of the FGP packet in bytes.

12. **FFCP_TYPE_LEN**: Length of the FFCP packet type field in bits.

13. **FFCP_INDEX_LEN**: Length of the FFCP packet index field in bits.

14. **FFCP_METADATA_LEN**: Length of the FFCP packet metadata in bytes.

15. **FFCP_DATA_LEN**: Length of the FFCP packet data in bytes.

16. **FFCP_LEN**: Total length of the FFCP packet in bytes.

17. **FFCP_TYPE_SYN**, **FFCP_TYPE_MSG**, **FFCP_TYPE_ACK**: Types of FFCP packets (SYN, MSG, ACK) represented by their respective values.

18. **FFCP_BUFFER_LEN**: Length of the FFCP buffer.

19. **FFCP_WINDOW_LEN**: Length of the FFCP window.

20. **PB_PARTITION_LEN**: Length of each partition in the packet buffer queue.

21. **PB_QUEUE_LEN**: Number of partitions in the packet buffer queue.

22. **PB_QUEUE_ALMOST_FULL_THRES**: Threshold value indicating the packet buffer queue is almost full.

These parameters are crucial for configuring the sizes, lengths, and types of various fields and protocols used in Ethernet frames and packet handling processes. They facilitate efficient data transmission and flow control in network communication.

The `fgp_tx` and `fgp_rx` modules implement the FPGA Graphics Protocol (FGP), a simple DMA protocol used to transmit graphics information. Here's a breakdown of each module:

### `fgp_tx` Module:
- **Inputs**:
  - `clk`, `rst`: Clock and reset signals.
  - `start`: Indicates the start of transmission.
  - `in_done`: Indicates the completion of data input.
  - `inclk`: Clock signal for the input data.
  - `in`: Input data to be transmitted.
  - `offset`: Offset field written into the FGP header.
  - `readclk`: Clock signal for reading data.

- **Outputs**:
  - `outclk`: Clock signal for transmitting data.
  - `out`: Output data stream.
  - `upstream_readclk`: Clock signal for upstream reading.
  - `done`: Indicates the completion of transmission.

- **Description**:
  - The module operates similarly to `eth_tx` but is tailored for the FGP protocol.
  - It takes input data and transmits it with a specified offset, as indicated by the `offset` input.
  - The transmission is divided into two stages: offset transmission and data transmission.
  - The offset is transmitted first, followed by the data.
  - Clock signals are generated for output transmission and upstream reading based on the current state.

### `fgp_rx` Module:
- **Inputs**:
  - `clk`, `rst`: Clock and reset signals.
  - `inclk`: Clock signal for incoming data.
  - `in`: Input data stream.
  

- **Outputs**:
  - `done`: Indicates the completion of packet reception.
  - `offset_outclk`: Clock signal for the offset output.
  - `offset_out`: Offset from the FGP header.
  - `outclk`: Clock signal for the output data.
  - `out`: Output data stream.

- **Description**:
  - This module receives and parses incoming FGP packets.
  - It operates similarly to `eth_rx` but is tailored for the FGP protocol.
  - The received packet is parsed into the offset and data sections.
  - Clock signals are generated for offset and data output based on the current state.

In summary, `fgp_tx` and `fgp_rx` modules provide functionality for transmitting and receiving graphics information using the FPGA Graphics Protocol, respectively. They handle the transmission of offset and data fields within FGP packets, ensuring proper synchronization and parsing of the transmitted data.


The FFCP (FPGA Flow Control Protocol) is a simple protocol designed for flow control in FPGA-based systems. Let's break down the key components and functionality of the FFCP protocol:

### 1. Packet Structure:
- FFCP packets consist of three main components:
  - **Type (2 bits)**: Indicates the type of packet (SYN, MSG, or ACK).
  - **Index (6 bits)**: Represents the sequence number or index of the packet.
  - **FGP Data (769 bytes)**: Payload data transmitted using the FPGA Graphics Protocol (FGP).

### 2. Flow Control Mechanism:
- **Fixed Window Size**: FFCP uses a fixed window size approach for flow control. Data flows in only one direction.
- **Window Management**: The protocol maintains a transmit window that defines the maximum number of unacknowledged packets allowed.
- **Acknowledgments (ACKs)**: Upon receiving packets, the receiver sends acknowledgments to the sender. ACKs confirm the successful receipt of packets and inform the sender about the next expected sequence number.
- **Retransmission**: If packets are not acknowledged within a specified timeout period, the sender retransmits the unacknowledged packets.

### 3. Packet Types:
- **SYN (Synchronization)**: Initiates a connection between sender and receiver. Contains information about the sender's capabilities and settings.
- **MSG (Message)**: Carries payload data to be transmitted. May include application-specific data or commands.
- **ACK (Acknowledgment)**: Confirms the successful receipt of a packet. Typically includes the sequence number of the acknowledged packet.

### 4. Implementation Components:
- **ffcp_tx**: Transmits FFCP packets with specified type and index.
- **ffcp_rx**: Receives FFCP packets, extracts type and index information, and processes the payload data.
- **ffcp_rx_server**: Manages flow control at the receiving end, handles ACKs, and advances the receive window.
- **ffcp_queue**: Manages the packet buffer queue used in conjunction with the flow control mechanism.
- **ffcp_tx_server**: Manages flow control at the transmitting end, handles packet transmission, and advances the transmit window.

### 5. Error Handling and Resynchronization:
- **Timeouts**: FFCP includes timeout mechanisms to detect lost packets or communication failures.
- **Resynchronization**: If no ACKs are received within a specified timeout period, the protocol may trigger a resynchronization process to re-establish the connection.

Overall, the FFCP protocol provides a basic yet effective mechanism for flow control in FPGA-based communication systems, ensuring reliable data transmission and efficient resource utilization.



This module, `rmii_driver`, is responsible for receiving Ethernet frames from the RMII (Reduced Media Independent Interface) interface. Let's break down its functionality:

### RMII Interface Signals:
- **crsdv_in**: Carrier Sense/Data Valid (CRS_DV) signal from the RMII interface. This signal indicates the presence of valid data.
- **rxd_in[1:0]**: Receive Data (RXD) signals from the RMII interface, representing the data being received.
- **rxerr**: Receive Error signal indicating errors in reception.
- **intn**: Interrupt signal from the PHY (Physical Layer) indicating events such as link status changes.

### Operation:
1. **Reset Handling**:
   - During reset, the module initializes internal states and asserts the reset signal to the PHY (`rstn`) for a specific duration.
   
2. **RMII Configuration**:
   - After reset, the module configures the RMII interface signals (`crsdv_in`, `rxd_in`) based on default settings, such as speed and duplex mode.
   
3. **State Machine**:
   - The module operates using a state machine with the following states:
     - **STATE_IDLE**: Initial state waiting for the CRS_DV signal.
     - **STATE_WAITING**: Waiting for the RMII interface to become active.
     - **STATE_PREAMBLE**: Detecting the Ethernet preamble (alternating ones and zeroes).
     - **STATE_RECEIVING**: Receiving Ethernet frame data.
   
4. **Preamble Detection**:
   - Upon detecting the Ethernet preamble, the module transitions to the receiving state.
   
5. **Data Reception**:
   - While in the receiving state, the module captures the RXD signals representing Ethernet frame data.
   
6. **Output Generation**:
   - The received Ethernet frame data is provided on the `out` output port.
   - An `outclk` signal indicates the availability of new data on the `out` port.
   
7. **Error Handling**:
   - Errors in reception are indicated by the `rxerr` signal.
   
8. **Interrupt Handling**:
   - Interrupt events from the PHY are indicated by the `intn` signal.

9. **Done Signal**:
   - The `done` signal indicates the completion of Ethernet frame reception.

### Reset Configuration:
- The module ensures proper timing for asserting and de-asserting the reset signal to the PHY (`rstn`) according to specifications.

### Clock Domain Crossing:
- Synchronization of RMII interface signals (`crsdv_in` and `rxd_in`) with the internal clock (`clk`) is performed using delay elements (`crsdv_sync` and `rxd_sync`) to avoid metastability issues.

### Output:
- The received Ethernet frame data is provided on the `out` output port along with the corresponding clock signal `outclk`.

IMPORTANT
The `rmii_driver` module serves as the interface between the physical layer (PHY) and the system's internal logic for receiving Ethernet frames. Here's the role of the `rmii_driver` module in the context of the code:

1. **Interface with RMII Interface**:
   - The `rmii_driver` module interfaces with the PHY through the RMII (Reduced Media Independent Interface) interface.
   - It receives signals from the PHY, including `crsdv_in` (Carrier Sense/Data Valid), `rxd_in` (Receive Data), `rxerr` (Receive Error), and `intn` (Interrupt) signals.
   - The `rmii_driver` module handles the RMII signals to receive Ethernet frame data from the physical medium.
     According to RMII specification :-
	 
     i) If 'crsdv' toggles every clock cycle then this indicates that either the 'crs' or 'dv' signal is asserted each clock cycle but not simultaneously.
	    This behaviour implies that data is valid (dv) when 'crsdv' is asserted, and carrier sense 'crs' is asserted when 'crsdv' is not.
    ii) Otherwise (If 'crsdv' doesn't toggle every clock cycle) this means that both 'crs' and 'dv'	signals are both assesrted/deasserted simultaneously 
        as determined by the value of 'crsdv'.

       Here is a sample code for the above specification for reference :-
  
	module rmii_behavior(

    input clk,            // Clock input

    input rst,            // Reset input

   input crsdv,          // Carrier Sense/Data Valid input

    output reg crs,       // Carrier Sense output

    output reg dv         // Data Valid output
   
);

// Internal signals to track previous crsdv value

reg prev_crsdv;

// Synchronize crsdv signal

reg crsdv_sync;

// Assign previous crsdv value

always @(posedge clk) begin

    prev_crsdv <= crsdv;

end

// Synchronize crsdv signal with clock

always @(posedge clk) begin

    if (rst) begin
    
        crsdv_sync <= 0;
    
    end else begin
    
        crsdv_sync <= crsdv;
    
    end

end

// Determine CRS and DV signals based on crsdv behavior

always @(posedge clk) begin

    if (rst) begin
    
        crs <= 0;
        
        dv <= 0;
    
    end else begin
    
        if (prev_crsdv != crsdv_sync) begin
        
            // crsdv toggles every clock cycle
            
            // DV is asserted when crsdv is asserted
            
            // CRS is asserted when crsdv is not
            
            crs <= ~crsdv_sync;
            
            dv <= crsdv_sync;
        
        end else begin
        
            // crsdv does not toggle every clock cycle
            
            // CRS and DV are both asserted or both deasserted
            
            crs <= crsdv_sync;
            
            dv <= crsdv_sync;
        
        end
    
    end

end

endmodule

	
 2. **Signal Synchronization and Handling**:
   - It synchronizes the incoming RMII signals (`crsdv_in` and `rxd_in`) with the internal clock (`clk`) to ensure proper operation in the system.
   - The module detects and handles different states of the RMII signals, such as carrier sense, data validity, and error conditions.
   - It detects the Ethernet preamble and begins capturing data when a valid frame is detected.

3. **State Machine Operation**:
   - The module operates using a state machine to manage the reception process.
   - It transitions between states based on the received signals and internal conditions.
   - States include idle state, waiting for data, preamble detection, and receiving data.

4. **Data Reception**:
   - Upon detecting the start of an Ethernet frame (preamble), the module captures the subsequent data bits (`rxd_in`) representing the Ethernet frame.
   - It processes the received data bits to reconstruct the Ethernet frame, excluding the preamble.

5. **Output Generation**:
   - The received Ethernet frame data is provided as output (`out`) from the module.
   - An accompanying clock signal (`outclk`) indicates the availability of new data on the output port.

6. **Error Handling and Interrupts**:
   - The module detects and handles errors in reception (`rxerr` signal).
   - It responds to interrupt events from the PHY (`intn` signal) to handle various conditions and events.

7. **Reset Handling**:
   - During initialization and reset conditions, the module ensures proper configuration and timing for asserting and de-asserting reset signals to the PHY.

Overall, the `rmii_driver` module acts as the interface and controller for receiving Ethernet frames from the physical layer, providing processed frame data to the system's internal logic for further processing or transmission.

VGA

This Verilog module is for generating VGA timing signals for a specific display resolution. Let's break down the key components and their functionalities:

1. **Input**:
   - `clk`: Clock input.

2. **Outputs**:
   - `vga_x`: Horizontal pixel coordinate.
   - `vga_y`: Vertical pixel coordinate.
   - `vsync`, `hsync`: Synchronized vertical and horizontal sync signals.
   - `vga_vsync`, `vga_hsync`: Polarity-adjusted vertical and horizontal sync signals.
   - `blank`: Indicates whether the display is in a blanking interval.

3. **Parameters**:
   - `VGA_WIDTH`, `VGA_HEIGHT`: Resolution of the VGA display.
   - Timing parameters such as front/back porch and sync lengths for both horizontal and vertical synchronization.

4. **Signal Generation**:
   - `hcount` and `vcount`: Counters for horizontal and vertical positions.
   - `hsyncon`, `hsyncoff`, `hreset`, `hblankon`: Signals for horizontal synchronization and blanking.
   - `vsyncon`, `vsyncoff`, `vreset`, `vblankon`: Signals for vertical synchronization and blanking.

5. **Sync and Blanking**:
   - `next_hblank`, `next_vblank`: Signals for the next horizontal and vertical blanking intervals.
   - Updates to `hcount`, `hblank`, `hsync`, `vcount`, `vblank`, `vsync`, and `blank` based on the current state of horizontal and vertical synchronization, and blanking intervals.
     
	Breaking down the sync and blanking part of the Verilog module:

i). **Horizontal Sync and Blanking**:
   - `hsyncon`: Indicates the start of the horizontal sync pulse, occurring at the end of the horizontal front porch.
   - `hsyncoff`: Indicates the end of the horizontal sync pulse, occurring at the end of the horizontal sync period.
   - `hreset`: Indicates the end of the horizontal blanking interval, occurring at the end of the horizontal total period.
   - `hblankon`: Indicates the horizontal blanking interval, starting at the end of the last visible pixel line and extending through the front/back porches and sync pulse periods.

ii). **Vertical Sync and Blanking**:
   - `vsyncon`: Indicates the start of the vertical sync pulse, occurring at the end of the vertical front porch.
   - `vsyncoff`: Indicates the end of the vertical sync pulse, occurring at the end of the vertical sync period.
   - `vreset`: Indicates the end of the vertical blanking interval, occurring at the end of the vertical total period.
   - `vblankon`: Indicates the vertical blanking interval, starting at the end of the last visible pixel row and extending through the front/back porches and sync pulse periods.

iii). **Next Blanking States**:
   - `next_hblank`: Determines whether the next state of the horizontal blanking signal should be active.
   - `next_vblank`: Determines whether the next state of the vertical blanking signal should be active.

iv). **Updates**:
   - `hcount` and `vcount` are incremented based on the clock signal.
   - `hblank` and `vblank` are updated based on whether the current state is within the blanking interval.
   - `hsync` and `vsync` are updated based on whether the current state is within the sync pulse period.

Overall, this part of the module manages the timing signals responsible for synchronizing the horizontal and vertical components of the VGA display and ensuring proper blanking intervals to maintain display integrity.
This module generates the necessary timing signals required for displaying graphics on a VGA monitor, ensuring proper synchronization and blanking intervals to maintain display integrity. The specific timing parameters provided in the module are tailored to a particular display resolution, and can be adjusted for different resolutions as needed.

ETHERNET

These Verilog modules are part of an Ethernet packet transmission and reception system. Let's break down each module:

### `eth_body_tx`:
- **Inputs**:
  - `clk`, `rst`: Clock and reset signals.
  - `start`: Indicates the start of packet transmission.
  - `in_done`: Indicates the completion of input data transmission.
  - `inclk`, `in`: Input clock and data.
  - `ram_outclk`, `ram_out`: Clock and data from RAM.
- **Outputs**:
  - `ram_readclk`, `ram_raddr`: RAM read clock and address.
  - `outclk`, `out`: Output clock and data.
  - `upstream_readclk`: Clock for upstream reads.
  - `done`: Indicates the completion of packet transmission.

This module generates an Ethernet frame body, including MAC addresses, EtherType, and payload. It interfaces with RAM to retrieve MAC addresses and EtherType. The packet transmission is synchronized with the provided clock signals.

### `crc32`:
- **Inputs**:
  - `clk`, `rst`: Clock and reset signals.
  - `shift`, `inclk`, `in`: Shift signal, input clock, and data.
- **Outputs**:
  - `out`: CRC output.

This module calculates the CRC-32 checksum for the Ethernet frame.

### `eth_tx`:
- **Inputs**:
  - `clk`, `rst`: Clock and reset signals.
  - `start`: Indicates the start of packet transmission.
  - `in_done`: Indicates the completion of input data transmission.
  - `inclk`, `in`: Input clock and data.
  - `ram_outclk`, `ram_out`: Clock and data from RAM.
- **Outputs**:
  - `ram_readclk`, `ram_raddr`: RAM read clock and address.
  - `outclk`, `out`: Output clock and data.
  - `upstream_readclk`: Clock for upstream reads.
  - `done`: Indicates the completion of packet transmission.

This module interfaces between the Ethernet frame body generator (`eth_body_tx`) and the CRC calculator (`crc32`). It handles the transmission of preamble, body, and CRC parts of the Ethernet frame.

### `eth_rx`:
- **Inputs**:
  - `clk`, `rst`: Clock and reset signals.
  - `inclk`, `in`: Input clock and data.
  - `in_done`: Indicates the completion of input data transmission.
- **Outputs**:
  - `outclk`, `out`: Output clock and data.
  - `ethertype_outclk`, `ethertype_out`: Clock and data for the EtherType field.
  - `err`, `done`: Indicates errors and completion of packet reception.

This module receives Ethernet frames, retrieves MAC addresses and EtherType, and calculates CRC-32 for error detection.

These modules collectively enable the transmission and reception of Ethernet frames, ensuring data integrity and compliance with Ethernet standards.


***GRAPHICS***

Module for generating pixel data to be displayed on a graphics output device, such as a VGA monitor.

### Inputs:
- `clk`: Clock signal.
- `rst`: Reset signal.
- `blank`: Indicates whether the screen is currently blanked (not displaying any content).
- `vga_x`, `vga_y`: Current pixel coordinates on the VGA display.
- `vga_hsync_in`, `vga_vsync_in`: Horizontal and vertical sync signals from the VGA display.

### Outputs:
- `vga_col`: Output pixel color.
- `vga_hsync_out`, `vga_vsync_out`: Output horizontal and vertical sync signals for the VGA display.
- `ram_readclk`: Clock signal for reading from RAM.
- `ram_raddr`: RAM read address.

### Internal Logic:
- Delays the VGA sync signals (`vga_hsync_in`, `vga_vsync_in`) to synchronize with the module's internal operations.
- Calculates the position of the image to be displayed on the screen based on VGA coordinates (`vga_x`, `vga_y`) and image size.
- Determines whether to read from RAM based on the screen position and blanking status.
- Reads pixel color data from RAM and outputs it (`vga_col`), or outputs white if the screen is blanked.
  
### Parameters and Constants:
- `RESOLUTION`: Number of pixels per image pixel in each direction.
- `IMAGE_SIZE`: Size of the image in pixels.
  
### Timing Considerations:
- The module considers the timing latency of the VGA sync signals and delays them appropriately.
- It ensures synchronization with RAM access by controlling the RAM read clock (`ram_readclk`) and read address (`ram_raddr`).

Overall, this module is responsible for generating pixel data to display an image on a VGA monitor, centered on the screen. 
It reads pixel data from RAM and outputs it based on the VGA coordinates and timing signals. Additionally, it handles blanking
 to ensure proper display synchronization.
 
***Wrapper for BRAM cores***
They provide a standardized interface for accessing these memory cores with separate read and write clock domains, abstracting away the latency introduced by the memory accesses.

**Read latency** -> refers to the delay or the number of clock cycles it takes for data to be available after a read operation is initiated. In the context of memory modules like RAM or ROM, read latency indicates the time it takes for the requested data to be accessed and presented at the output after providing the read address.

For example, let's say we have a RAM module with a read latency of 4 clock cycles. When you provide a read address to this RAM and initiate a read operation, the data won't be available immediately. Instead, it will take 4 clock cycles (assuming each clock cycle is a unit of time) for the data to appear at the output of the RAM.

In the provided Verilog code, the `READ_LATENCY` parameter in each module definition specifies the read latency of the corresponding memory module. This parameter is then used to configure a delay module (`delay_inst`) within each wrapper module to handle the read latency. This delay ensures that the output data is synchronized with the appropriate clock signal after the specified latency.

### 1. `video_cache_ram_driver`
This module acts as a wrapper around a video cache RAM module (`video_cache_ram`). It provides an interface for reading and writing data to the RAM while abstracting away the latency of the RAM access. Here's a breakdown of its components:

- **Parameters:**
  - `RAM_SIZE`: Specifies the size of the RAM.
  - `READ_LATENCY`: Specifies the read latency of the RAM.

- **Ports:**
  - `clk`, `rst`: Clock and reset signals.
  - `readclk`: Clock signal for reading from the RAM.
  - `raddr`: Read address.
  - `we`: Write enable signal.
  - `waddr`: Write address.
  - `win`: Input data for writing.
  - `outclk`: Clock signal for the output.
  - `out`: Output data from the RAM.

- **Internal Components:**
  - `delay_inst`: Delay module to handle the read latency.
  - `video_cache_ram_inst`: Instance of the video cache RAM module.

### 2. `packet_synth_rom_driver`
This module serves as a wrapper around a packet synthesis ROM module (`packet_synth_rom`). It provides an interface for reading data from the ROM while abstracting away its latency. Here's a breakdown:

- **Parameters:**
  - `RAM_SIZE`: Specifies the size of the ROM.
  - `READ_LATENCY`: Specifies the read latency of the ROM.

- **Ports:**
  - `clk`, `rst`: Clock and reset signals.
  - `readclk`: Clock signal for reading from the ROM.
  - `raddr`: Read address.
  - `outclk`: Clock signal for the output.
  - `out`: Output data from the ROM.

- **Internal Components:**
  - `delay_inst`: Delay module to handle the read latency.
  - `packet_synth_rom_inst`: Instance of the packet synthesis ROM module.

### 3. `packet_buffer_ram_driver`
This module is a wrapper around a packet buffer RAM module (`packet_buffer_ram`). It provides an interface for reading and writing data to the RAM while abstracting away its latency. Here's a detailed breakdown:

- **Parameters:**
  - `RAM_SIZE`: Specifies the size of the RAM.
  - `READ_LATENCY`: Specifies the read latency of the RAM.

- **Ports:**
  - `clk`, `rst`: Clock and reset signals.
  - `readclk`: Clock signal for reading from the RAM.
  - `raddr`: Read address.
  - `we`: Write enable signal.
  - `waddr`: Write address.
  - `win`: Input data for writing.
  - `outclk`: Clock signal for the output.
  - `out`: Output data from the RAM.

- **Internal Components:**
  - `delay_inst`: Delay module to handle the read latency.
  - `packet_buffer_ram_inst`: Instance of the packet buffer RAM module.

Each of these modules abstracts the details of their respective memory modules and provides a simplified interface for interaction while handling the latency internally.

***IPv4 Checksum***

It is responsible for calculating the Internet Protocol version 4 (IPv4) checksum. 

### Inputs:
- `clk`: Clock signal.
- `rst`: Reset signal.
- `inclk`: Input clock signal for data (`in`).
- `in`: Input data, typically representing the IPv4 header.

### Outputs:
- `out`: Output checksum value.

### Internal Signals and Logic:
- `cnt`: Counter used to track the number of bytes processed.
- `curr_dibyte`: Current dibyte (two bytes) being processed.
- `prev_sum`: Previous sum of dibytes.
- `curr_sum`: Current sum of dibytes (including the carry).
- `next_sum`: One's complement sum of `curr_sum`.
- Checksum calculation:
  - The module adds the current dibyte to the previous sum to calculate the current sum (`curr_sum`).
  - Then, it calculates the one's complement of the `curr_sum` to get the final checksum (`out`).

### Operation:
- Upon reset (`rst`), the counters and internal registers are reset to their initial states.
- On each rising edge of the `inclk` signal, the module processes the input data.
  - It alternates between two states:
    1. Storing the current dibyte (`in`) and updating the previous sum (`prev_sum`).
    2. Storing the next byte of the current dibyte.
- The process continues until all bytes have been processed.

### Considerations:
- The checksum calculation is typically performed on the IPv4 header, excluding the checksum field itself.
- This module calculates the one's complement checksum, which is a standard method used in IPv4 checksum calculation.

This module efficiently calculates the IPv4 checksum, ensuring data integrity in IPv4 packets.

The IPv4 checksum, unlike CRC, is used at the network layer of the TCP/IP protocol stack.
It is calculated specifically over the IPv4 header (excluding options) and payload (data) fields.
The IPv4 header includes fields such as source and destination IP addresses, protocol number, and header length.
Similar to CRC, the IPv4 checksum is a means of detecting errors during packet transmission.
However, unlike CRC, the IPv4 checksum is recalculated at each router hop in the network to ensure the integrity of the packet header. This is necessary because routers may modify certain fields in the header (e.g., TTL) as they forward packets.
If the IPv4 checksum fails at any router, the router typically drops the packet and may generate an ICMP error message back to the source indicating a checksum error.
In summary, while both CRC and the IPv4 checksum serve error detection purposes in networking, they operate at different layers of the protocol stack and have different scopes of calculation.
CRC is used at the data link layer to verify the integrity of entire frames, while the IPv4 checksum is used at the network layer to verify the integrity of IPv4 packet headers and payloads.

Clocking 

This Verilog module, `reset_stream_fifo`, synchronizes a reset signal (`rsta`) from one clock domain (`clka`) to another clock domain (`clkb`) using an IP FIFO. 

### Inputs:
- `clka`: Clock signal of the source clock domain (`clka`).
- `clkb`: Clock signal of the destination clock domain (`clkb`).
- `rsta`: Reset signal from the source clock domain (`clka`).

### Outputs:
- `rstb`: Synchronized reset signal for the destination clock domain (`clkb`).

### Internal Signals and Logic:
- `fifo_empty`: Indicates whether the FIFO is empty.
- `fifo_out`: Output of the FIFO, representing the value read from it.
- `fifo_rden`: Read enable signal for the FIFO.
- `fifo_prev_rden`: Delayed version of `fifo_rden`, synchronized with `clkb`.
- `reset_fifo`: Instance of the bit stream FIFO module, synchronizing `rsta`.
- `reset_fifo_read_delay`: Delays the read enable signal to align with `clkb`.

### Operation:
1. The module uses a bit stream FIFO (`reset_fifo`) to synchronize the reset signal (`rsta`) from `clka` to `clkb`.
2. The FIFO is written to (`wr_en`) with `rsta` on the rising edge of `clka`.
3. The read enable signal for the FIFO (`fifo_rden`) is asserted when the FIFO is not empty (`!fifo_empty`).
4. The read enable signal is delayed by one clock cycle using the `reset_fifo_read_delay` module to align with `clkb`.
5. The synchronized reset signal (`rstb`) is asserted (`1'b1`) when the delayed read enable signal was asserted the previous clock cycle and the FIFO output (`fifo_out`) is valid.

### Considerations:
- Synchronizing signals between different clock domains is essential to prevent metastability and ensure reliable operation.
- The FIFO ensures that the reset signal is safely transferred between clock domains, preventing any timing violations.
- Delaying the read enable signal ensures that `rstb` aligns with the destination clock domain (`clkb`) for proper synchronization.

This module is commonly used in designs where a reset signal needs to be synchronized across different clock domains, ensuring that the system initializes reliably regardless of clock domain differences.

Code for ceiling log function: 

// gives the minimum number of bits required to store 0 to size-1
// e.g. clog2(7) = 3, clog2(11) = clog2(16) = 4
function integer clog2(input integer size);
begin
	size = size - 1;
	for (clog2 = 1; size > 1; clog2 = clog2 + 1)
		size = size >> 1;
	end
endfunction

These Verilog modules are designed to manipulate data streams of various widths efficiently. 

### `stream_pack`:
- Converts a stream of words of size `S_LEN` to a stream of words of size `L_LEN`.
- Packs smaller words into larger ones in little-endian order.
- `inclk` is the input clock, and `outclk` is the output clock.
- `in_done` indicates the end of the input stream.
- `done` indicates the end of the output stream.
- Utilizes a shift buffer to pack small words into large ones efficiently.

### `stream_unpack`:
- The opposite of `stream_pack`.
- Converts a stream of words of size `L_LEN` to a stream of words of size `S_LEN`.
- Unpacks larger words into smaller ones in little-endian order.
- `inclk` is the input clock, and `outclk` is the output clock.
- `in_done` indicates the end of the input stream.
- `done` indicates the end of the output stream.
- Utilizes a shift buffer to unpack large words into small ones efficiently.

### `dibits_to_bytes` and `bytes_to_dibits`:
- Convert a stream of dibits (2-bit data) to bytes and vice versa.
- `inclk` is the input clock, and `outclk` is the output clock.
- `in_done` indicates the end of the input stream.
- `done` indicates the end of the output stream.
- `bytes_to_dibits` uses a shift buffer to handle synchronization between clocks.

### `bytes_to_colors`:
- Converts a stream of bytes to a stream of 12-bit colors.
- Assumes three bytes represent two colors.
- Output clock is delayed by one cycle.
- Utilizes a state machine to manage byte processing.

### `stream_from_memory` and `stream_to_memory`:
- Stream data into and out of memory.
- `start` initiates streaming.
- `read_start` and `read_end` define the range of memory to read.
- `setoff_req` and `setoff_val` set the offset for writing to memory.
- `inclk` controls the input clock.
- `outclk` controls the output clock.
- `done` signals the end of the operation.

### `stream_coord` and `stream_coord_buf`:
- Coordinate data flow between modules.
- Ensure upstream data is requested only after downstream has received the previous word.
- `downstream_rdy` indicates when the downstream module is ready for data.
- `upstream_readclk` controls when the upstream module reads data.

### `stream_unpack_coord_buf` and `bytes_to_dibits_coord_buf`:
- Coordinated, buffered versions of `stream_unpack` and `bytes_to_dibits`.
- Ensure data is passed out immediately when downstream is ready.
- Synchronize clocks and manage data flow between modules.


Key differences between RMII and RGMII:

Clock Rate: RGMII operates at a higher clock rate compared to RMII. Therefore, adjustments are made in the clocking domain.

Signal Width: RGMII uses wider data paths for both transmit and receive signals. In this example, rgmii_txd and rgmii_rxd are 4-bit wide.

Clock Skew: RGMII may have clock skew between transmit and receive clocks. Adjustments for clock skew are implemented in the module.

Signal Control: RGMII has separate control signals for transmit and receive (rgmii_tx_ctl and rgmii_rx_ctl). These signals are used to control the state machine transitions.

Preamble Detection: The preamble pattern detection is modified to match the RGMII preamble pattern.

Frame Completion: The done signal is asserted when a complete frame is received, indicating reception completion.
