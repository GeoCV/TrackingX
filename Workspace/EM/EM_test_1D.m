% Plot settings
ShowPlots = 1;
SkipSimFrames = 5;
ShowUpdate = 0;
ShowArena = 0;
ShowPredict = 0;
SimNum = 50000;
V_bounds = [0 250 0 70];

% Recording Settings
Record = 0;
clear Frames
clear M

% Instantiate a Tracklist to store each filter
FilterList = [];
FilterNum = 1;

% Containers
Logs = cell(1,FilterNum); 
N = 1000;
for i=1:FilterNum
    Logs{i}.xV = zeros(1,N);          %estmate        % allocate memory
    Logs{i}.exec_time = 0;
    Logs{i}.filtered_estimates = cell(1,N);
end

% Create figure windows
if(ShowPlots)
    figure('units','normalized','outerposition',[0.5 0 .5 1])
    ax(1) = gca;
end
Params_dyn.xDim = 1;
Params_dyn.q = .1;
DynModel = GenericDynamicModelX(Params_dyn);
DynModel.Params.F = @(~) 1;
DynModel.Params.Q = @(~) Params_dyn.q^2;

Params_obs.xDim = 1;
Params_obs.yDim = 1;
Params_obs.r = .5;
ObsModel = GenericObservationModelX(Params_obs);

Q_old = DynModel.Params.Q(1);
F_old = DynModel.Params.F(1);
R_old = ObsModel.Params.R(1);
% Generate ground truth and measurements


sV = 5;
zV = ObsModel.sample(0, sV(1),1);
mErr = zV - sV;
for k = 2:N
    % Generate new measurement from ground truth
    sV(:,k) = DynModel.sys(1,sV(:,k-1),DynModel.sys_noise(1,1));     % save ground truth
    pErr(k) = sV(k) - sV(k-1);
    zV(:,k) = ObsModel.sample(0, sV(:,k),1);     % generate noisy measurment
    mErr(k) = zV(k) - sV(k);
    
end

Q_true = std(pErr)^2;
R_true = std(mErr)^2;
DynModel.Params.F = @(~) 10;
%ObsModel.Params.H = @(~) 100;
ObsModel.Params.R = @(~) ObsModel.Params.R(1)*1000;
DynModel.Params.Q = @(~) 1;

FilterList = cell(1,FilterNum);    
% Initiate Kalman Filter
Params_kf.k = 1;
Params_kf.x_init = sV(1)-DynModel.sys_noise(1,1);
Params_kf.P_init = DynModel.Params.Q(1);
Params_kf.DynModel = DynModel;
Params_kf.ObsModel = ObsModel;


FilterList{1}.Filter = KalmanFilterX(Params_kf);
%FilterList{1}.Filter.DynModel.Params.F = @(~)F;
%FilterList{1}.Filter.DynModel.Params.Q = @(~)Q;
%FilterList{1}.Filter.ObsModel.Params.R = @(~)R;
for SimIter = 1:SimNum
    fprintf('\nSimIter: %d/%d\n', SimIter, SimNum);

    % FILTERING
    % ===================>
    tic;
    for k = 1:N
        
        % Update measurements
        for i=1:FilterNum
            FilterList{i}.Filter.Params.y = zV(:,k);
        end

        % Iterate all filters
        for i=1:FilterNum
            tic;
            FilterList{i}.Filter.Iterate();
            Logs{i}.exec_time = Logs{i}.exec_time + toc;
        end

        % Store Logs
        for i=1:FilterNum
            Logs{i}.xV(:,k) = FilterList{i}.Filter.Params.x;
            Logs{i}.filtered_estimates{k} = FilterList{i}.Filter.Params;
        end

      % Plot update step results
        if(ShowPlots && ShowUpdate)
            % Plot data
            cla(ax(1));

            if(ShowArena)
                 % Flip the image upside down before showing it
                imagesc(ax(1),[min_x max_x], [min_y max_y], flipud(img));
            end

            % NOTE: if your image is RGB, you should use flipdim(img, 1) instead of flipud.
            hold on;
            h2 = plot(ax(1), k, zV(k),'k*','MarkerSize', 10);
            set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
            h2 = plot(ax(1), 1:k, sV(1:k),'b.-','LineWidth',1);
            set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
            h2 = plot(ax(1), k, sV(k),'bo','MarkerSize', 10);
            set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend

            for i=1:FilterNum
                h2 = plot(k, Logs{i}.xV(k), 'o', 'MarkerSize', 10);
                set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
                %plot(pf.Params.particles(1,:), pf.Params.particles(2,:), 'b.', 'MarkerSize', 10);
                plot(1:k, Logs{i}.xV(1:k), '.-', 'MarkerSize', 10);
            end
            legend('KF','EKF', 'UKF', 'PF', 'EPF', 'UPF')

            if(ShowArena)
                % set the y-axis back to normal.
                set(ax(1),'ydir','normal');
            end

            str = sprintf('Robot positions (Update)');
            title(ax(1),str)
            xlabel('X position (m)')
            ylabel('Y position (m)')
            axis(ax(1),V_bounds)
            pause(0.01);
        end
      %s = f(s) + q*randn(3,1);                % update process 
    end
    
    filtered_estimates = Logs{1}.filtered_estimates;
    
    % SMOOTHING
    % ===================>
    smoothed_estimates = FilterList{i}.Filter.Smooth(filtered_estimates);
    xV_smooth = zeros(1,N);
    PV_smooth = zeros(1,N);
    for i=1:N
        xV_smooth(:,i) = smoothed_estimates{i}.x;          %estmate        % allocate memory
        PV_smooth(:,i) = smoothed_estimates{i}.P;
    end
    
    xV_filt = cell2mat(cellfun(@(x)x.x,filtered_estimates,'un',0)); 
    meanRMSE_filt   = mean(abs(xV_filt - sV))
    meanRMSE_smooth = mean(abs(xV_smooth - sV))
    
    [F,Q,H,R] = KalmanFilterX_LearnEM_Mstep(filtered_estimates, smoothed_estimates,FilterList{1}.Filter.DynModel.sys(),FilterList{1}.Filter.ObsModel.obs());
    
    % Reset KF
    F = F
    Q = Q
    R = R
    H = H
    FilterList{1}.Filter = KalmanFilterX(Params_kf);
    FilterList{1}.Filter.DynModel.Params.F = @(~)F;
    FilterList{1}.Filter.DynModel.Params.Q = @(~)Q;
    %FilterList{1}.Filter.ObsModel.Params.H = @(~)H;
    FilterList{1}.Filter.ObsModel.Params.R = @(~)R; %diag(diag(R));
    
    if(Record || (ShowPlots && (SimIter==1 || rem(SimIter,SkipSimFrames)==0)))
        
        clf;
        sp1 = subplot(3,1,1);
        % NOTE: if your image is RGB, you should use flipdim(img, 1) instead of flipud.
        % Flip the image upside down before showing it
        % Plot data
         % Flip the image upside down before showing it

        % NOTE: if your image is RGB, you should use flipdim(img, 1) instead of flipud.
        hold on;
        h2 = plot(sp1,1:k,zV(1:k),'k*','MarkerSize', 10);
        h3 = plot(sp1,1:k,sV(1:k),'b.-','LineWidth',1);
        plot(sp1,k,sV(k),'bo','MarkerSize', 10);
        plot(sp1,k, Logs{1}.xV(k), 'ro', 'MarkerSize', 10);
        h4 = plot(sp1,1:k, Logs{1}.xV(1:k), 'r.-', 'MarkerSize', 10);
        plot(sp1,k, xV_smooth(k), 'go', 'MarkerSize', 10);
        h5 = plot(sp1,1:k, xV_smooth(1:k), 'g.-', 'MarkerSize', 10);
        %for ki = 1:k
        h6 = errorbar(sp1,1:k,xV_smooth,PV_smooth);
            %plot_gaussian_ellipsoid(xV_smooth(1:2,ki), PV_smooth(1:2,1:2,ki), 1, [], ax(1));
        %end
        % set the y-axis back to normal.
        %str = sprintf();
        title(sp1,'\textbf{State evolution}','Interpreter','latex')
        xlabel(sp1,'Time (s)','Interpreter','latex')
        ylabel(sp1,'x (m)','Interpreter','latex')
        legend(sp1,[h2 h3 h4 h5 h6], 'Measurements', 'Ground truth', 'Filtered state', 'Smoothed state', 'Smoothed variance','Interpreter','latex');
        %axis(ax(1),V_bounds)
        
        sp2 = subplot(3,1,2);
        x = -1:0.01:1;
        y = mvnpdf(x',0,Q_true);
        plot(sp2,x,y);
        hold on;
        y = mvnpdf(x',0,FilterList{1}.Filter.DynModel.Params.Q());
        plot(sp2,x,y);
        xlabel(sp2,'\textbf{Process noise $w_k \sim \mathcal{N}(0,Q)$}','Interpreter','latex');
        ylabel(sp2,'pdf($w_k$)','Interpreter','latex');
        title(sp2,'\textbf{True vs Estimated process noise pdf}','Interpreter','latex');
        
        sp3 = subplot(3,1,3);
        x = -10:0.01:10;
        y = mvnpdf(x',0,R_true);
        plot(sp3,x,y);
        hold on;
        y = mvnpdf(x',0,FilterList{1}.Filter.ObsModel.Params.R());
        plot(sp3,x,y);
        xlabel(sp3,'\textbf{Measurement noise $v_k \sim \mathcal{N}(0,R)$}','Interpreter','latex');
        ylabel(sp3,'pdf($v_k$)','Interpreter','latex');
        title(sp3,'\textbf{True vs Estimated measurement noise pdf}','Interpreter','latex');
        
        pause(1);
    end
end

% figure
% for i=1:FilterNum
%     hold on;
%     plot(sqrt(Logs{i}.pos_err(1,:)/SimNum), '.-');
% end
% legend('KF','EKF', 'UKF', 'PF', 'EPF', 'UPF');%, 'EPF', 'UPF')

% figure
% bars = zeros(1, FilterNum);
% c = {'KF','EKF', 'UKF', 'PF', 'EPF', 'UPF'};
% c = categorical(c, {'KF','EKF', 'UKF', 'PF', 'EPF', 'UPF'},'Ordinal',true); %, 'EPF', 'UPF'
% for i=1:FilterNum
%     bars(i) =  Logs{i}.exec_time;
% end
% bar(c, bars);
%smoothed_estimates = pf.Smooth(filtered_estimates);
% toc;
% END OF SIMULATION
% ===================>

if(Record)
    Frames = Frames(2:end);
    vidObj = VideoWriter(sprintf('em_test.avi'));
    vidObj.Quality = 100;
    vidObj.FrameRate = 100;
    open(vidObj);
    writeVideo(vidObj, Frames);
    close(vidObj);
end