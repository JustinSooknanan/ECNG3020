classdef HBC_PHYFrameConfig < comm.internal.ConfigBase
%   HBC_PHYFrameConfig: The function creates a configuration object for 
%   IEEE 802.15.6 HBC PHY layer frame.

%   cfg = HBC_PHYFrameConfig(Name,Value) creates an HBC IEEE 802.15.6
%   PHY frame configuration object with various Values associated with a 
%   particular properity, Name. You can specify additional name-value pair
%   arguments in any order as (Name1,Value1,...,NameN,ValueN).
%
%   HBC_PHYFrameConfig properties:
%
%   Datarate        - Datarate of transmission
%   PilotInfo       - Length of the pilot insertion interval
%   BurstMode       - Selection of burst mode transmission
%   ScramblerSeed   - Selection of the scrambling seed used for scrambling
%   PSDULength      - Length of PHY service data unit (in bytes)
%   SelectRI        - Determines whether the SFD field will be used
%   Toffset         - Controls the zero-padding in SFD mode
%
%   Example:
%      cfg = HBC_PHYFrameConfig(DataRate = '328Kbps', PilotInfo = '128', PSDULength = 254); 

  properties
    % PSDU Data rate
    % Specify the data rate of transmission
    DataRate = 'Reserved'; 
    
    % Pilot Info (Pilot Insertion Period)
    % Pilot insertion interval
    PilotInfo = 'Reserved';

    %Burst Mode
    % Information about the next packet—whether it is being sent in a burst mode.
    BurstMode = false; % Default to 0 

    % Scrambler Seed
    % The MAC shall set the scrambler seed to 0 when the PHY is initialized 
    % and the scrambler seed shall be incremented, using a 1-bit rollover 
    % counter, for each frame sent by the PHY.
    ScramblerSeed = false; % Default to 0 

    % PSDU Length
    % Length of the PSDU in octets
    PSDULength = 'Reserved'; 

    % Select RI
    % Determines whether the SFD field will be used to indicate rate using
    % an additional 12-bits of zeros
    SelectRI = false; 

    % Toffset
    % Determines the position of the 12-bits. 
    Toffset = 1; 

  end
  properties(Constant, Hidden)
    % Set of fixed values each property can take
    DataRateValues    = {'164Kbps', '328Kbps', '656Kbps', '1.3125Mbps', 'RI', 'Reserved'}
    PilotInfoValues   = {'64', '128', 'Reserved', 'NA'}    
  end

  methods
    function obj = HBC_PHYFrameConfig(varargin)
      obj@comm.internal.ConfigBase(varargin{:}); % call base constructor
    end
    
    % Validation of each Name-Value pair
    function obj = set.DataRate(obj, value)
      obj.DataRate = validatestring(value, obj.DataRateValues, '', 'DataRate');
    end

    function obj = set.PilotInfo(obj, value)
      obj.PilotInfo = validatestring(value, obj.PilotInfoValues, '', 'PilotInfo');
    end

    function obj = set.BurstMode(obj, value)
      validateattributes(value, {'logical'}, {'scalar'}, '', 'BurstMode');
      obj.BurstMode = value; 
    end

    function obj = set.ScramblerSeed(obj, value)
      validateattributes(value, {'logical'}, {'scalar'}, '', 'ScramblerSeed');
      obj.ScramblerSeed = value; 
    end

    function obj = set.PSDULength(obj, value)
      validateattributes(value, {'numeric'}, {'scalar', 'integer', 'nonnegative', 'real','<',256}, '', 'PSDULength')
      obj.PSDULength = value; 
    end
    
    function obj = set.SelectRI(obj, value)
      validateattributes(value, {'logical'}, {'scalar'}, '', 'SelectRI');
      obj.SelectRI = value; 
    end
    
    %For HBC only 4 options for Toffset are presented (1 - 4)
    function obj = set.Toffset(obj, value)
      validateattributes(value, {'numeric'}, {'scalar', 'integer', 'nonnegative', 'real','<',5}, '', 'Toffset')
      obj.Toffset = value; 
    end
  end
end

