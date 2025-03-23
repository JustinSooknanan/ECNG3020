function [WAVE, FRAME, FRAME_NOFSC] = HBC_PHYWaveformGeneration(data, cfg)
%   HBC_PHYWaveformGeneration, creates the IEEE802.15.6 HBC-PHY frame and  
%   and its associated bipolar signal. The PHY layer functions performed 
%   are, preamble generation, start frame delimiter (SFD) generation, PLCP 
%   header generation and PSDU scrambling. 
% 

%   [WAVE, FRAME, FRAME_NOFSC] = HBC_PHYWaveformGeneration(DATA, CFG)
%   creates the HBC-PHY frame where DATA is a column vector representing 
%   data from the MAC layer which in this case is user-defined and CFG 
%   represents a configuration object from the related function, 
%   HBC_PHYFrameConfig. 
%   WAVE is the bipolar FSC-coded signal, FRAME is the FSC-coded PHY frame,
%   and FRAME_NOFSC is the PHY frame without FSC applied.  
    
%
%   Example 1: 
%      % Create an HBC-PHY waveform.
%      DATA = [0 1 0 1]';
%      CFG = HBC_PHYFrameConfig(DataRate = '328Kbps', PilotInfo = '128', PSDULength = 254); 
%      [WAVE, FRAME, FRAME_NOFSC] = HBC_PHYWaveformGeneration(DATA, CFG)

%% Validation:

% Ensures the payload data is a column vector
validateattributes(data,{'double','int8'},{'column','binary'},'','DATA');

% Ensures the cfg object is of type 'HBC_PHYFrameConfig'
validateattributes(cfg, {'HBC_PHYFrameConfig', 'HBC_PHYFrameConfig_SysObj'}, {'scalar'}, '','CFG')

% FSC mapping for 0-bit. 
FSCmap0 = [1 0 1 0 1 0 1 0]; 

%Scramblerseed 
scramblerseed = zeros(1,32); 

%% 10.4 Preamble Generation

% Gold code generation for Preamble 
% Taken from Table 76 (Codeset for PLCP preamble)
preamble_goldseq = [1 1 0 0 0 1 0 0 1 1 0 0 1 0 1 0 ...
                    0 1 0 1 0 0 0 0 0 0 0 1 1 0 0 0 ...
                    1 1 1 1 1 0 1 0 1 1 1 0 0 1 0 0 ...
                    1 0 1 1 1 0 0 1 1 0 0 0 0 0 1 0];

% Gold Code generation using PN-sequences 
% preamble_goldseq = comm.GoldSequence( ...
%     "FirstInitialConditions",[0 0 1 0 0 1 0 0 0 1], ...
%     "FirstPolynomial", "x^10 + x^3 + 1", ...
%     "SecondInitialConditions", [0 0 1 1 1 1 1 0 1 0], ...
%     "SecondPolynomial", "x^10 + x^8 + x^3 + x^2 + 1", ...
%     "SamplesPerFrame", 64);

% Repetion of the 64-bit gold sequence 4 times to form preamble. Ensures
% result is in column vector form.
%temp_preamble = repmat(preamble_goldseq()', 1, 4)';
temp_preamble = repmat(preamble_goldseq, 1, 4)';

%Store un-FSC preamble
frame_nofsc = temp_preamble'; 

% Repeating every bit of data 8 times to enable 8-bit xor to accomplish FSC
% coding 
temp_preamble = repmat(temp_preamble, 1,8);

% Effectively replaces 0 with 10101010 and 1 with 01010101. The preamble is
% now FSC coded with every column representing a bit of data starting from
% col. 1
preamble = xor(FSCmap0,temp_preamble)'; 

% Output of the preamble generation in a column vector form (LSB starting from row 1). 
preamble = preamble(:); 

%% 10.5 SFD/RI Generation
% Gold code generation for SFD
% SFD_goldseq = comm.GoldSequence( ...
%     "FirstInitialConditions",[0 1 0 1 1 0 0 0 0 0], ...
%     "FirstPolynomial", "x^10 + x^3 + 1", ...
%     "SecondInitialConditions", [0 0 0 0 1 0 0 0 1 0], ...
%     "SecondPolynomial", "x^10 + x^8 + x^3 + x^2 + 1", ...
%     "Index", 10, "SamplesPerFrame", 64);

% SFD code set
SFD_goldseq = [0 1 0 1 0 1 1 0 0 1 0 1 1 1 0 1 ...
               1 1 0 1 1 0 1 1 1 1 0 0 1 0 1 0 ...
               0 1 0 1 1 0 0 0 0 0 1 0 0 1 1 0 ...
               0 1 1 1 1 0 1 0 1 1 0 0 1 1 0 1]; 

% Select RI Multiplexing functionality
switch cfg.SelectRI
    case 0
        SFD_temp = SFD_goldseq; % 64-bit gold's code
    case 1 % Rate indication using Toffset bits
        SFD_temp = cat(2, zeros(1,2*(cfg.Toffset-1)), SFD_goldseq, zeros(1,12 - 2*(cfg.Toffset-1))); % 64-bit gold's code + 12 bit zeros
end 

% Repeating the SFD eight times
temp_SFD1 = repmat(SFD_temp, 1, 8)';

%Store un-FSC SFD
frame_nofsc = [frame_nofsc temp_SFD1']; 

% Repeating every bit of data 8 times to enable 8-bit xor to accomplish FSC
% coding
temp_SFD2 = repmat(temp_SFD1, 1, 8); 

% Effectively replaces 0 with 10101010 and 1 with 01010101. The preamble is
% now FSC coded with every column representing a bit of data starting from
% col. 1
SFD = xor(FSCmap0,temp_SFD2)';

%Output of the SFD generation (LSB starting from row 1). 
SFD = SFD(:);

%% 10.6 PHY Header
% Initializing memory for the PHYHeader 
% [b0 b1 b2 b3 b4 ... b31]
% [m1 m2 m3 m4 m5 ... m32]
PLCPHeader = zeros(1,32);

% Data rate
switch cfg.DataRate
    case '164Kbps'
        PLCPHeader(1:3) = [0 0 0];
    case '328Kbps'
        PLCPHeader(1:3) = [0 0 1];
    case '656Kbps'
        PLCPHeader(1:3) = [0 1 0];
    case '1.3125Mbps'
        PLCPHeader(1:3) = [0 1 1];
    case 'RI'
        PLCPHeader(1:3) = [1 1 1];
    case 'Reserved'
        PLCPHeader(1:3) = [1 0 0];
end 

% Pilot Info
switch cfg.PilotInfo
    case '64'
        PLCPHeader(4:6) = [0 1 0];
    case '128'
        PLCPHeader(4:6) = [0 1 1];
    case 'Reserved'
        PLCPHeader(4:6) = [0 0 0];
    case 'NA' % No insertion
        PLCPHeader(4:6) = [1 1 0];
end 

% Bits 7-8 reserved

% Burst Mode (bit-9)
switch cfg.BurstMode
    case true
        PLCPHeader(9) = 1;
    case false
        PLCPHeader(9) = 0;
end

% Bits 10-11 Reserved

% Scrambler Seed (bit-12)
switch cfg.ScramblerSeed
    case true
        PLCPHeader(12) = 1;
        scramblerseed = [1 0 0 0 1 0 1 0 0 1 0 1 1 1 1 1 0 1 1 0 0 0 1 0 0 0 0 1 1 1 1 1]; 
    case false
        PLCPHeader(12) = 0;
        scramblerseed = [0 1 1 0 1 0 0 1 0 1 0 1 0 1 0 0 0 0 0 0 0 0 0 1 0 1 0 1 0 0 1 0]; 
end

% Bits 13-16 Reserved

% PSDU Length (bits 17:24)
PSDUlength  = dec2bin(cfg.PSDULength);
PLCPHeader(17:24) = PSDUlength(1:8) - 48; 

% CRC Generation
PLCPHeader(25:32) = zeros(1,8);

% CRC8 (bits 24-32)
message = PLCPHeader(1:24)';
% HBC PHY CRC configuration
cfgObj = crcConfig(Polynomial='z^8 + z^7 + z^3 + z^2 + 1', ChecksumsPerFrame= 1); 
PLCPHeader = crcGenerate(message,cfgObj)';

% 10.6: In both DRF (RI = 0) and RI mode the S2P and 16-Walsh Code is used
% to generate the PHY Header.

% S2P 1:4 - reshape PHYHeader into 4 rows 32/4 columns
S2P_output= reshape(PLCPHeader,4,length(PLCPHeader)/4); 

% According to IEEE802.15.6 (Table 85) 4 bits of the S2P correspond to a
% 16-bit Walsh code. This is implemented using a look-up table type function. 
Walsh_input = bit2int(S2P_output,4,false)'; %Converting each 4 bit pattern into a decimal number for processing
Walsh_output = Walsh_16_Mod(Walsh_input)'; % Applying the 16-bit Walsh code to the 4-bit representations. N.B. each code word is stored as its own column

% Stacks each code (i.e., each code word to create a single column vector w/ the LSB of the PHYHeader first)
PLCPHeader_Walshed = Walsh_output(:);

%Store un-FSC PLCP Header
frame_nofsc = [frame_nofsc PLCPHeader_Walshed']; 

% Applying the FSC for each bit.
%FSC = [1 0 1 0 1 0 1 0];
FSCy = repmat(PLCPHeader_Walshed,1,8);
FSC_output = xor(FSCmap0,FSCy)'; % Thus, every 16 columns of 8 bits represents a 4-bit pattern from line 158

% Output of the FSC encoder.
PLCPHeader = FSC_output(:);


%% 10.7 PSDU 
% 10.7.1 Scrambler
% The PSDU (frame from the MAC layer, 'data') is scrambled.

% Generator polynomial, this is inverted when compared to the polynomial in
% IEEE802.15.6.
pnSeq = comm.PNSequence( ...
    Polynomial='x32 + x21 + x1 + 1', ...
    InitialConditionsSource="Input Port", ...
    Mask=0, ...
    SamplesPerFrame=length(data), ...
    OutputDataType="logical");

pnsequence = pnSeq(scramblerseed);
scrambledPSDU = xor(data,pnsequence); % Outputs as a column vector (LSB to MSB)

% Perform FSDT on the scrambled data

% S2P 1:4 - reshape PHYHeader into 4 rows 32/4 columns
S2P_output= reshape(scrambledPSDU,4,length(scrambledPSDU)/4); 

% According to IEEE802.15.6 (Table 85) 4 bits of the S2P correspond to a
% 16-bit Walsh code. This is implemented using a look-up table type function. 
Walsh_input = bit2int(S2P_output,4,false)'; %Converting each 4 bit pattern into a decimal number for processing
Walsh_output = Walsh_16_Mod(Walsh_input)'; % Applying the 16-bit Walsh code to the 4-bit representations. N.B. each code word is stored as its own column

% Stacks each code (i.e., each code word to create a single column vector w/ the LSB of the PHYHeader first)
PSDU_Walshed = Walsh_output(:);

%Store un-FSC PSDU 
frame_nofsc = [frame_nofsc PSDU_Walshed']; 

% Applying the FSC for each bit.
%FSC = [1 0 1 0 1 0 1 0];
FSCy = repmat(PSDU_Walshed,1,8);
FSC_output = xor(FSCmap0,FSCy)'; % Thus, every 16 columns of 8 bits represents a 4-bit pattern from line 158

% Output of the FSC encoder.
PSDU = FSC_output(:);
%% PHY Frame
% PHYFrame = [LSB....MSB] (Row vector)
PHYFrame = [preamble' SFD' PLCPHeader' PSDU'];

FRAME_NOFSC = frame_nofsc;
FRAME = PHYFrame; % Output PHYFrame
WAVE = 2*PHYFrame - 1; % Generates a bipolar signal that represents a 0 as -1 V and 1 as 1 V

end