classdef KalmanFilterX < FilterX 
% KalmanFilterX class
%
% Summary of KalmanFilterX:
% This is a class implementation of a standard Kalman Filter.
%
% KalmanFilterX Properties: (**)
%   + StateMean            A (xDim x 1) vector used to store the last computed/set filtered state mean  
%   + StateCovar      A (xDim x xDim) matrix used to store the last computed/set filtered state covariance
%   + PredStateMean        A (xDim x 1) vector used to store the last computed prediicted state mean  
%   + PredStateCovar  A (xDim x xDim) matrix used to store the last computed/set predicted state covariance
%   + PredMeasMean         A (yDim x 1) vector used to store the last computed predicted measurement mean
%   + InnovErrCovar   A (yDim x yDim) matrix used to store the last computed innovation error covariance
%   + CrossCovar      A (xDim x yDim) matrix used to store the last computed cross-covariance Cov(X,Y)
%   + KalmanGain           A (xDim x yDim) matrix used to store the last computed Kalman gain%   
%   + Measurement          A (yDim x 1) matrix used to store the received measurement
%   + ControlInput         A (uDim x 1) matrix used to store the last received control input
%   + Model                An object handle to StateSpaceModelX object
%       + Dyn (*)  = Object handle to DynamicModelX SubClass     | (TO DO: LinearGaussDynModelX) 
%       + Obs (*)  = Object handle to ObservationModelX SubClass | (TO DO: LinearGaussObsModelX)
%       + Ctr (*)  = Object handle to ControlModelX SubClass     | (TO DO: LinearCtrModelX)
%
%   (*)  Signifies properties necessary to instantiate a class object
%   (**) xDim, yDim and uDim denote the dimentionality of the state, measurement
%        and control vectors respectively.
%
% KalmanFilterX Methods:
%   + KalmanFilterX  - Constructor method
%   + predict        - Performs KF prediction step
%   + update         - Performs KF update step
%
% (+) denotes puplic properties/methods
% 
% See also DynamicModelX, ObservationModelX and ControlModelX template classes
    
    properties
        StateMean 
        StateCovar     
        PredStateMean        
        PredStateCovar  
        PredMeasMean         
        InnovErrCovar   
        CrossCovar 
        KalmanGain       
        ControlInput     
    end
    
    methods
        function this = KalmanFilterX(varargin)
        % KALMANFILTER Constructor method
        %   
        % DESCRIPTION: 
        % * kf = KalmanFilterX() returns an unconfigured object handle. Note
        %   that the object will need to be configured at a later instance
        %   before any call is made to it's methods.
        % * kf = KalmanFilterX(ssm) returns an object handle, preconfigured
        %   with the provided StateSpaceModelX object handle ssm.
        % * kf = KalmanFilterX(ssm,priorStateMean,priorStateCov) returns an 
        %   object handle, preconfigured with the provided StateSpaceModel 
        %   object handle ssm and the prior information about the state,  
        %   provided in the form of the prorStateMean and priorStateCov 
        %   variables.
        % * kf = KalmanFilterX(___,Name,Value) instantiates an object handle, 
        %   configured with the options specified by one or more Name,Value 
        %   pair arguments. 
        %
        %  See also predict, update, smooth.   
           
            
            % Call SuperClass method
            this@FilterX(varargin{:});
            
            if(nargin==0)
                return;
            end
            
            % First check to see if a structure was received
            if(nargin==1)
                if(isstruct(varargin{1}))
                    if (isfield(varargin{1},'priorStateMean'))
                        this.StateMean = varargin{1}.priorStateMean;
                        %this.StateMean  = this.priorStateMean;
                    end
                    if (isfield(varargin{1},'priorStateCovar'))
                        this.StateCovar  = varargin{1}.priorStateCovar;
                        %this.filtStateCov   = this.priorStateCov;
                    end
                end
                return;
            end
            
            % Otherwise, fall back to input parser
            parser = inputParser;
            parser.KeepUnmatched = true;
            parser.addParameter('priorStateMean',NaN);
            parser.addParameter('priorStateCovar',NaN);
            parser.parse(varargin{:});
            
            if(~isnan(parser.Results.priorStateMean))
                this.StateMean = parser.Results.priorStateMean;
            end
            
            if(~isnan(parser.Results.priorStateCov))
                this.StateCovar  = parser.Results.priorStateCovar;
            end
        end
        
        function initialise(this,varargin)
        % INITIALISE Initialise the KalmanFilter with a certain set of
        % parameters. 
        %   
        % DESCRIPTION: 
        % * initialise(kf, ssm) initialises the KalmanFilterX object kf
        %   with the provided StateSpaceModelX object ssm.
        % * initialise(kf,ssm,priorStateMean,priorStateCov) initialises 
        %   the KalmanFilterX object kf with the provided StateSpaceModelX 
        %   object ssm and the prior information about the state, provided  
        %   in the form of the prorStateMean and priorStateCov variables.
        % * initialise(kf,___,Name,Value,___) initialises the KalmanFilterX 
        %   object kf with the options specified by one or more Name,Value 
        %   pair arguments. 
        %
        %  See also predict, update, smooth.   
           
            if(nargin==0)
                error("Not enough input arguments.");
            end
            
            initialise@FilterX(this);
            
            % First check to see if a structure was received
            if(nargin==1)
                if(isstruct(varargin{1}))
                    if (isfield(varargin{1},'Model'))
                        this.Model = varargin{1}.Model;
                    end
                    if (isfield(varargin{1},'PriorStateMean'))
                        this.StateMean = varargin{1}.priorStateMean;
                        %this.filtStateMean  = this.priorStateMean;
                    end
                    if (isfield(varargin{1},'PriorStateCovar'))
                        this.StateCovar  = varargin{1}.priorStateCovar;
                        %this.filtStateCov   = this.priorStateCovar;
                    end
                end
                return;
            end
            
            % Otherwise, fall back to input parser
            parser = inputParser;
            parser.KeepUnmatched = true;
            parser.addParameter('Model',NaN);
            parser.addParameter('PriorStateMean',NaN);
            parser.addParameter('PriorStateCovar',NaN);
            parser.parse(varargin{:});
            
            if(~isnan(parser.Results.Model))
                this.Model = parser.Results.Model;
            end
            
            if(~isnan(parser.Results.PriorStateMean))
                this.StateMean = parser.Results.PriorStateMean;
            end
            
            if(~isnan(parser.Results.PriorStateCovar))
                this.StateCovar  = parser.Results.PriorStateCovar;
            end
        end
        
        function predict(this)
        % PREDICT Perform Kalman Filter prediction step
        %   
        % DESCRIPTION: 
        % * predict(this) calculates the predicted system state and measurement,
        %   as well as their associated uncertainty covariances.
        %
        % MORE DETAILS:
        % * KalmanFilterX uses the Model class property, which should be an
        %   instance of the TrackingX.Models.StateSpaceModel class, in order
        %   to extract information regarding the underlying state-space model.
        % * State prediction is performed using the Model.Dyn property,
        %   which must be a subclass of TrackingX.Abstract.DynamicModel and
        %   provide the following interface functions:
        %   - Model.Dyn.feval(): Returns the model transition matrix
        %   - Model.Dyn.covariance(): Returns the process noise covariance
        % * Measurement prediction and innovation covariance calculation is
        %   performed usinf the Model.Obs class property, which should be
        %   a subclass of TrackingX.Abstract.DynamicModel and provide the
        %   following interface functions:
        %   - Model.Obs.heval(): Returns the model measurement matrix
        %   - Model.Obs.covariance(): Returns the measurement noise covariance
        %
        %  See also update, smooth.
            
            % Extract model parameters
            F = this.Model.Dyn.feval();
            Q = this.Model.Dyn.covariance();
            H = this.Model.Obs.heval();
            R = this.Model.Obs.covariance();
            if(~isempty(this.Model.Ctr))
                B   = this.Model.Ctr.beval();
                Qu  = this.Model.Ctr.covariance();
            else
                this.ControlInput   = 0;
                B   = 0;
                Qu  = 0;
            end
            % Perform prediction
            [this.PredStateMean, this.PredStateCovar, this.PredMeasMean, this.InnovErrCovar, this.CrossCovar] = ...
                KalmanFilterX_Predict(this.StateMean, this.StateCovar, F, Q, H, R, this.ControlInput, Qu); 
            
            predict@FilterX(this);
        end
        
        
        function update(this)
        % UPDATE Perform Kalman Filter update step
        %   
        % DESCRIPTION: 
        % * update(this) calculates the corrected sytem state and the 
        %   associated uncertainty covariance.
        %
        %   See also KalmanFilterX, predict, iterate, smooth.
        
            if(size(this.Measurement,2)>1)
                error('[KF] More than one measurement have been provided for update. Use KalmanFilterX.UpdateMulti() function instead!');
            elseif size(this.Measurement,2)==0
                warning('[KF] No measurements have been supplied to update track! Skipping Update step...');
                this.StateMean = this.PredStateMean;
                this.StateCovar = this.PredStateCovar;
                return;
            end
        
            % Perform single measurement update
            [this.StateMean, this.StateCovar, this.KalmanGain] = ...
                KalmanFilterX_Update(this.PredStateMean,this.PredStateCovar,...
                                     this.Measurement,this.PredMeasMean,this.InnovErrCovar,this.CrossCovar);
                                 
            update@FilterX(this);
        end
        
        function updatePDA(this, assocWeights)
        % UPDATEPDA - Performs KF update step, for multiple measurements
        %             Update is performed according to the generic (J)PDAF equations [1] 
        % 
        % DESCRIPTION:
        %  * updatePDA(assocWeights) Performs KF-PDA update step for multiple 
        %    measurements based on the provided (1-by-Nm+1) association weights 
        %    matrix assocWeights.
        %
        %   [1] Y. Bar-Shalom, F. Daum and J. Huang, "The probabilistic data association filter," in IEEE Control Models, vol. 29, no. 6, pp. 82-100, Dec. 2009.
        %
        %   See also KalmanFilterX, Predict, Iterate, Smooth, resample.
        
            NumData = size(this.Measurement,2);  
            
            if(~NumData)
                warning('[KF] No measurements have been supplied to update track! Skipping Update step...');
                this.StateMean = this.PredStateMean;
                this.StateCovar = this.PredStateCovar;
                return;
            end
            
            if(~exist('assocWeights','var'))
                warning('[KF] No association weights have been supplied to update track! Applying default "assocWeights = [0, ones(1,nData)/nData];"...');
                assocWeights = [0, ones(1,NumData)/NumData]; % (1 x Nm+1)
            end
            
            [this.StateMean,this.StateCovar,this.KalmanGain] = ...
                KalmanFilterX_UpdatePDA(this.PredStateMean,this.PredStateCovar,this.Measurement,...
                                        assocWeights,this.PredMeasMean,this.InnovErrCovar,this.CrossCovar);
        end
        
        function smoothedEstimates = smooth(this, filteredEstimates, interval)
        % Smooth - Performs KF smoothing on a provided set of estimates
        %   
        %   Inputs:
        %       filteredEstimates: a (1 x N) cell array, where N is the total filter iterations and each cell is a copy of this.Params after each iteration
        %                            
        %   (NOTE: The filtered_estimates array can be computed by running "filtered_estimates{k} = kf.Params" after each iteration of the filter recursion) 
        %   
        %   Usage:
        %       kf.Smooth(filteredEstimates);
        %
        %   See also KalmanFilterX, Predict, Update, Iterate.
        
            if(nargin==2)
                smoothedEstimates = KalmanFilterX_SmoothRTS(filteredEstimates);
            else
                smoothedEstimates = KalmanFilterX_SmoothRTS(filteredEstimates,interval);
            end     
        end 
    end
end