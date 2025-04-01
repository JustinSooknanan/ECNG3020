SNRrange = -8:2:6; % Range of SNRs/dB considered
SFrange = [1 2 4 8]; % Different spread factors supported by HBC

cnt = 1; % Iterator for SNR
numErrors = zeros(4,1000); % Holds num of errors for all 4 SFs (SF = 1 (R1), SF = 2 (R2) etc.)

totErrors = zeros(4, length(SNRrange)); % Holds total num of errors for all 4 SFs (SF = 1 (R1), SF = 2 (R2) etc.)

% Thermal Noise (Pn = kTB)
Pn = pow2db((1.38E-23)*(310)*(5.25E6));

% Pass-band of the bandpass filter used at the transmitter and receiver
Fpass1 = 18.375E6; 
Fpass2 = 23.625E6; 

% Initializes the FSC mapping code and the reference code for correlation
% decoding based on the spread factor selected. 
for k = 1:1:length(SFrange)
    if SFrange(k) == 1
        code0 = -1; 
        FSCmap0 = 0; 
    elseif SFrange(k) == 2
        code0 = [1 -1]; 
        FSCmap0 = [1 0]; 
    elseif SFrange(k) == 4
        code0 = [1 -1 1 -1]; 
        FSCmap0 = [1 0 1 0]; 
    elseif SFrange(k) == 8
        code0 = [1 -1 1 -1 1 -1 1 -1];
        FSCmap0 = [1 0 1 0 1 0 1 0]; 
    end

% Iterates across all the SNRs in the range
for j = 1:1:length(SNRrange)

    % For a frame of length 10,000 bits a loop of 1000 must be created to
    % generate 10^7 possible outcomes.
    for i= 1:1:1000
        RXseq=[];
        CS=[];
        

        % ------ PHY LAYER -----------------------------------------------
        data = randi([0,1],1,10000); % Reduce size for faster simulation
        cfg = HBC_PHYFrameConfig(DataRate = '328Kbps', PilotInfo = '128', PSDULength = 254); % Configures a PHY Frame
        [wave_SF8, frame_SF8, frame_SF1] = HBC_PHYWaveformGeneration(data', cfg); % Generating bipolar signal and PHY frame
        
        % Apply FSC coding based on the SF under study
        % Repeating every bit of data SF times to enable SF-bit FSC coding
        temp_frame = repmat(frame_SF1', 1, SFrange(k));
        % Effectively replaces 0 with 10101010 and 1 with 01010101. The preamble is
        % now FSC coded with every column representing a bit of data starting from
        % col. 1
        frame = xor(FSCmap0,temp_frame)';
        % Output of the preamble generation in a column vector form (LSB starting from row 1).
        frame = frame(:)';
        wave = 2*frame - 1;
        
        % ------ UPSAMPLING  -----------------------------------------------
        % Upsample the output waveform to realize the pulse-like shape
        chiprate = 42E6; % Center frequency of the HBC protocol this ensures that 1 bit is transmitted every (1/42M) seconds
        sampleFactor = 8; % Upsampling factor to generate a sharp step-like input waveform
        Fs = sampleFactor*chiprate;
        rep_wave = repmat(wave,sampleFactor,1); % Repeat each sample of data by the upsampling factor
        rep_frame = repmat(frame_SF8, sampleFactor,1); % Repeat each bit of data by the upsampling factor
        frame_new = rep_frame(:)'; % Upsampled frame
        wave_new = rep_wave(:)'; % Upsampled bipolar signal magnitudes
        samples = length(wave_new);
        % Defining new times that correspond to the upsampled signals
        t = 0 : 1/(sampleFactor*chiprate) : (samples-1)*(1/(sampleFactor*chiprate));
        nFpass1 = 2*Fpass1/Fs; 
        nFpass2 = 2*Fpass2/Fs; 
        
        % ------ Calculate total group delay ------------------------------
        % Compensating for the total group delay of TX Filter, Channel and
        % RX Filter
        % Calculate the group delay of the channel model and filters
        TXgrpdelay  = grpdelay(Butter_O6); %Group delay of the TX Butterworth filter
        TXgrpdelayHBC = TXgrpdelay(round(nFpass1*length(TXgrpdelay)): round(nFpass2*length(TXgrpdelay))); % Isolates the group delays at the HBC band. 
        TXdelay = round(mean(TXgrpdelayHBC)); % Obtains the mean delay at the HBC band
        CMx_filter = CM1_filter;
        CMx_filter_num = CMx_filter.Numerator(); % Extracting the numerator for CMx
        CMxgrpdelay  = grpdelay(CMx_filter); %Group delay of the TX Butterworth filter
        CMxgrpdelayHBC = CMxgrpdelay(round(nFpass1*length(CMxgrpdelay)): round(nFpass2*length(CMxgrpdelay))); % Isolates the group delays at the HBC band. 
        CMxdelay = round(mean(CMxgrpdelayHBC)); % Obtains the mean delay at the HBC band
        
        % Calculate the total group delay TX filter, RX filter and channel filter
        totalGroupDelay = 2*TXdelay + CMxdelay; 
        % Append totalGroupDelay zeros to the input
        inputSig = [wave_new, zeros(1, totalGroupDelay)]; 


        % ---------------  COMMUNICATION CHAIN ----------------------------
        % TX Bandpass Filter the result     
        TXfilteredSig = filter(Butter_O6, inputSig); % Time-shifted TX filtered signal
       
        % Send through Channel
        Received_Signal = filter(CMx_filter_num, 1, TXfilteredSig); % Time-shifted TX filtered signal
          
        % Adding thermal noise to channel
        sigPower = pow2db(mean(Received_Signal.^2)); 
        SNRthermal = sigPower - Pn; 
        ThermalNoise_wave = awgn(Received_Signal,SNRthermal, sigPower);        
        
        % Adding noise to the recieved signal
        sigPower = pow2db(mean(ThermalNoise_wave.^2)); % Calculating the power of the signal from CMx in dB
        SNR = SNRrange(j);
        AWGN_wave = awgn(ThermalNoise_wave,SNR, sigPower);
        
        % Receiver Filtering w/ Bandpass Filter
        RXfilteredSig = filter(Butter_O6, AWGN_wave); % Time-shifted TX filtered signal

        % Amplification of RX filtered signal (worst case channel attenuation is approx -65 dB)
        % Amplify signal by 10^(6.5)
        G = sqrt(10^(65/10)); % Linear gain for a 65 dB gain in power
        ReceivedSigAmplified = RXfilteredSig.*G; 

        % Compensate for the group delay by skipping the first
        % totalGroupDelay samples
        RXSignal = ReceivedSigAmplified(totalGroupDelay+1 : end); 
        

        % Correlation Detection of entire FSC codes :
        tempcode = repmat(code0', 1, sampleFactor); 
        temp1code = tempcode'; 
        corrcode0 = temp1code(:)';
        for n=1:1:length(frame_SF1)
            temp= RXSignal((n-1)*(sampleFactor*SFrange(k))+1 : 1 : n*(sampleFactor*SFrange(k)));
            % Normalized Correlation
            Cxy = sum(temp.*corrcode0); % Correlation function for x and y
            Cxx = sum(corrcode0.*corrcode0); % Correlation of x and x
            Cyy = sum(temp.*temp); % Correlation of y and y
            normCorr = Cxy/(sqrt(Cxx*Cyy)); % Normalized Correlation
            % normCorr = sum(temp.*1); % Normalized Correlation
            CS=[CS normCorr]; % Append correlation of that sample to the array of correlations.
            if(normCorr>0) % Positive correlation with code for logic 0 implies a 0 was sent
                RXseq=[RXseq 0];
            else % Negative correlation with code for logic 0 implies a 1 was sent
                RXseq=[RXseq 1];
            end
        end

        % Checking the errors that occured between the receievd frame and sent
        % frame 
        errorChecker = (frame_SF1==RXseq);
        numErrors(k,i) = sum(~(frame_SF1==RXseq)); % num of erros in length(frame)
        
    end
    totErrors(k,j) = sum(numErrors(k,:)); % num of erros in length(frame)*ith-loopsize
end
end 

BER = totErrors./(length(frame_SF1)*1000); 
