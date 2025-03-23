IEEE802.15.6 HBC Functions: 

The pair of Matlab functions, "HBC_PHYFrameConfig" and "HBC_PHYWaveformGeneration" are used to configure an HBC frame and generate its respective frame and waveforms from that configuration (respectively). 

HBC Channel Filters: 

The Matlab script in, "ChannelModelsFilters", uses the Comsol channel simulation data to construct Matlab filters that mimic the channel response of the HBC channel. Some additonal code is used to compare other filter topologies to ensure the optimal (lowest error) filter design is selected. This ensures the Matlab filter equivalent is consistent with the Comsol channel responses. 
