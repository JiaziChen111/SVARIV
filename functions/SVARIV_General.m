function [Plugin, InferenceMSW, Chol, RForm] = SVARIV_General(p,confidence, ydata, z, NWlags, norm, scale, horizons, savdir, columnnames, IRFselect, time)
% Implements standard and weak-IV robust SVAR-IV inference.
%-Syntax:
%       [Plugin, InferenceMSW, Chol] = SVARIV_Luigi(p,confidence, ydata, z, NWlags, norm, scale, horizons, savdir)
% -Inputs:
%       p:           Number of lags in the VAR model                                                (1 times 1)                                          
%       confidence:  Value for the standard and weak-IV robust confidence set                       (1 times 1) 
%       ydata:       Endogenous variables from the VAR model                                        (T times n) 
%       z:           External instrumental variable                                                 (T times 1)
%       NWlags:      Newey-West lags                                                                (1 times 1)
%       norm:        Variable used for normalization                                                (1 times 1)
%       scale:       Scale of the shock                                                             (1 times 1)
%       horizons:    Number of horizons for the Impulse Response Functions(IRFs)                    (1 times 1)
%       savdir:      Directory where the figures generated will be saved                            (String)
%       columnnames: Vector with the names for the endogenous variables, in the same order as ydata (1 times n)
%       IRFselect:   Indices for the variables that the user wants separate IRF plots for           (1 times q)
%       time:        Time unit for the dataset (e.g. year, month, etc.)                             (String)
%
% -Output:
%       PLugin:       Structure containing standard plug-in inference
%       InferenceMSW: Structure containing the MSW weak-iv robust confidence interval
%       Chol:         Cholesky IRFs
%       RForm:        Structure containing the reduced form parameters
%
% This version: August 14th, 2018
% Comment: We have tested this function on a Macbook Pro 
%         @2.4 GHz Intel Core i7 (8 GB 1600 MHz DDR3)
%         Running Matlab R2016b.
%         This script runs in about 10 seconds.


%% section 1
olddir = pwd; % Save user's dir in order to return to the user with the same dir

currentcd = mfilename('fullpath');

currentcd = extractBetween(currentcd, '' , '/SVARIV_General');

currentcd = currentcd{1};

cd(currentcd);

cd ..  %Now we are back to the SVARIV folder

main_d = pwd;

cd(main_d);   %the main dir is the SVARIV folder

disp('This function reports confidence intervals for IRFs estimated using the SVAR-IV approach described in MSW(18)')
 
disp('(created by Karel Mertens and Jose Luis Montiel Olea)')
 
disp('-')
 
disp('This version: August 2018')
 
disp('-')
 
disp('(We would like to thank Qifan Han and Jianing Zhai for excellent research assistance)')
 
%% 2) Least-squares, reduced-form estimation

addpath(strcat(main_d,'/functions/RForm'));

SVARinp.ydata = ydata;

SVARinp.Z = z;

SVARinp.n        = size(ydata,2); %number of columns(variables)

RForm.p          = p; %RForm.p is the number of lags in the model

%a) Estimation of (AL, Sigma) and the reduced-form innovations
 
[RForm.mu, ...
 RForm.AL, ...
 RForm.Sigma,...
 RForm.eta,...
 RForm.X,...
 RForm.Y]        = RForm_VAR(SVARinp.ydata, p);

%b) Estimation of Gammahat (n times 1)
 
RForm.Gamma      = RForm.eta*SVARinp.Z(p+1:end,1)/(size(RForm.eta,2));   %sum(u*z)/T. Used for the computation of impulse response.
%(We need to take the instrument starting at period (p+1), because
%we there are no reduced-form errors for the first p entries of Y.)

%c) Add initial conditions and the external IV to the RForm structure
    
RForm.Y0         = SVARinp.ydata(1:p,:);
    
RForm.externalIV = SVARinp.Z(p+1:end,1);
    
RForm.n          = SVARinp.n;

%d) Definitions for next section
 
n            = RForm.n; % Number of endogenous variables

T            = (size(RForm.eta,2)); % Number of observations (time periods)

d            = ((n^2)*p)+(n);     %This is the size of (vec(A)',Gamma')'

dall         = d+ (n*(n+1))/2;    %This is the size of (vec(A)',vec(Sigma), Gamma')'

%% 4) Estimation of the asymptotic variance of A,Gamma
 
%a) Covariance matrix for vec(A,Gammahat). Used
%to conduct frequentist inference about the IRFs. 
 
[RForm.WHatall,RForm.WHat,RForm.V] = ...
    CovAhat_Sigmahat_Gamma(p,RForm.X,SVARinp.Z(p+1:end,1),RForm.eta,NWlags);                
 
%NOTES:
%The matrix RForm.WHatall is the covariance matrix of 
% vec(Ahat)',vech(Sigmahat)',Gamma')'
 
%The matrix RForm.WHat is the covariance matrix of only
% vec(Ahat)',Gamma')' 
 
% The latter is all we need to conduct inference about the IRFs,
% but the former is needed to conduct inference about FEVDs.

%% 5) Compute standard and weak-IV robust confidence set suggested in MSW
 
disp('-')
 
disp('The fifth section in SVAR-IV general reports standard and weak-IV robust confidence sets ');
 
disp('(output saved in the "Inference.MSW" structure)')

 
%Apply the MSW function
 
tic;
 
addpath(strcat(main_d,'/functions'));
 
[InferenceMSW,Plugin,Chol] = MSWfunction(confidence,norm,scale,horizons,RForm,1);

%% 6) Plot Results
 
addpath(strcat(main_d,'/functions/figuresfun'));
 
figure(1)
 
plots.order     = [1:SVARinp.n];
 
caux            = norminv(1-((1-confidence)/2),0,1);


 
for iplot = 1:SVARinp.n
        
    if SVARinp.n > ceil(sqrt(SVARinp.n)) * floor(sqrt(SVARinp.n))
            
        subplot(ceil(sqrt(SVARinp.n)),ceil(sqrt(SVARinp.n)),plots.order(1,iplot));
    
    else
        
        subplot(ceil(sqrt(SVARinp.n)),floor(sqrt(SVARinp.n)),plots.order(1,iplot));
        
    end
    
    plot(0:1:horizons,Plugin.IRF(iplot,:),'b'); hold on
    
    [~,~] = jbfill(0:1:horizons,InferenceMSW.MSWubound(iplot,:),...
        InferenceMSW.MSWlbound(iplot,:),[204/255 204/255 204/255],...
        [204/255 204/255 204/255],0,0.5); hold on
    
    dmub  =  Plugin.IRF(iplot,:) + (caux*Plugin.IRFstderror(iplot,:));
    
    lmub  =  Plugin.IRF(iplot,:) - (caux*Plugin.IRFstderror(iplot,:));
    
    h1 = plot(0:1:horizons,dmub,'--b'); hold on
    
    h2 = plot(0:1:horizons,lmub,'--b'); hold on
    
    clear dmub lmub
    
    h3 = plot([0 horizons],[0 0],'black'); hold off
    
    xlabel(time)
    
    title(columnnames(iplot));
        
    xlim([0 horizons-1]);

    
    if iplot == 1
        
        legend('SVAR-IV Estimator',strcat('MSW C.I (',num2str(100*confidence),'%)'),...
            'D-Method C.I.')
        
        set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        set(get(get(h3,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        legend boxoff
        
        legend('location','southeast')
     
    end
        
end

%% 7) Save the output and plots in ./Output/Mat and ./Output/Figs
 
%Check if the Output File exists, and if not create one.
 
if exist(savdir,'dir')==0
    
    mkdir('savdir')
        
end

mat = strcat(savdir,'/Mat');

if exist(mat,'dir')==0
    
    mkdir(mat)
        
end

figs = strcat(savdir, '/Figs'); 

if exist(figs,'dir')==0
    
    mkdir(figs)
        
end
 
cd(strcat(main_d,'/Output/Mat'));
 
output_label = strcat('_p=',num2str(p),'_ALL(PS2003)_',...
               num2str(100*confidence));
 
save(strcat('IRF_SVAR',output_label,'.mat'),...
     'InferenceMSW','Plugin','RForm','SVARinp');
 
figure(1)
 
cd(strcat(main_d,'/Output/Figs'));
 
print(gcf,'-depsc2',strcat('IRF_SVAR',output_label,'.eps'));
 
cd(main_d);
 
clear plots output_label main_d labelstrs dtype

cd(olddir);

%% 8) Select the Impulse Response Functions 

figure(2)
 
plots.order     = 1:length(IRFselect);
 
caux            = norminv(1-((1-confidence)/2),0,1);

for i = 1:length(IRFselect) 

    iplot = IRFselect(i);
    
    if length(IRFselect) > ceil(sqrt(length(IRFselect))) * floor(sqrt(length(IRFselect)))
            
        subplot(ceil(sqrt(length(IRFselect))),ceil(sqrt(length(IRFselect))),plots.order(1,i));
    
    else
        
        subplot(ceil(sqrt(length(IRFselect))),floor(sqrt(length(IRFselect))),plots.order(1,i));
        
    end
    
    plot(0:1:horizons,Plugin.IRF(iplot,:),'b'); hold on
    
    [~,~] = jbfill(0:1:horizons,InferenceMSW.MSWubound(iplot,:),...
        InferenceMSW.MSWlbound(iplot,:),[204/255 204/255 204/255],...
        [204/255 204/255 204/255],0,0.5); hold on
    
    dmub  =  Plugin.IRF(iplot,:) + (caux*Plugin.IRFstderror(iplot,:));
    
    lmub  =  Plugin.IRF(iplot,:) - (caux*Plugin.IRFstderror(iplot,:));
    
    h1 = plot(0:1:horizons,dmub,'--b'); hold on
    
    h2 = plot(0:1:horizons,lmub,'--b'); hold on
    
    clear dmub lmub
    
    h3 = plot([0 horizons],[0 0],'black'); hold off
    
    xlabel(time)
    
    title(columnnames(iplot));
    
    xlim([0 horizons-1]);
    
    if iplot == 1
        
        legend('SVAR-IV Estimator',strcat('MSW C.I (',num2str(100*confidence),'%)'),...
            'D-Method C.I.')
        
        set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        set(get(get(h3,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        legend boxoff
        
        legend('location','southeast')
     
    end
    
    
end

end