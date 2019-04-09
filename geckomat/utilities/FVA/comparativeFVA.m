function [FVA_Dists,indexes,blocked,stats] = comparativeFVA(model,ecModel,c_source,chemostat,tol)
% comparativeFVA
%  
% This function goes through each of the rxns in a metabolic model and
% gets its flux variability range, then the rxn is mapped into an EC
% version of it to perform the correspondent variability analysis and
% finally compares and plots the cumulative flux variability distributions. 
%
%   model       MATLAB GEM structure (reversible model), constrained with 
%               the desired culture medium constrains
%   ecModel     MATLAB ecGEM structure, constrained with the desired culture
%               medium
%   c_source    rxn ID (in model) for the main carbon source uptake reaction.
%               The rxn ID should not contain the substring "_REV" in order
%               to avoid any confusion when mapping it to the ecModel
%   chemostat   TRUE if chemostat conditions are desired
%   tol         numerical tolerance for a flux and variability range 
%               to be considered as zero (default 1E-12) 
%   FVAdists    cell containing the distributions of variability ranges for
%               the original GEM and ecGEM
%   rangeEC     Distribution of variability ranges for the original ecGEM
%   indexes     Indexes (in the original model) of the reactions for which 
%               a feasible variability range was obtained in both models
%   stats       Some statistics of the variability distributions
% 
% usage: [FVA_Dists,indexes,stats] = comparativeFVA(model,ecModel,c_source,chemostat,tol,blockedMets)
% 
% Ivan Domenzain.      Last edited: 2019-04-09
if nargin<5
    tol = 1E-12;
end
rangeGEM = [];
indexes  = [];
blocked  = [];
range_EC = [];
%Get the index for all the non-objective rxns in the original irrevModel
rxnsIndxs = find(model.c~=1);
%Set minimal media for ecModel
pos        = find(strcmpi(ecModel.rxns,[c_source '_REV']));
%Constraint all rxns in ecModel to the positive domain
ecModel.lb = zeros(length(ecModel.lb),1);
%Gets the optimal value for the objective rxn in ecirrevModel and fixes its
%value in both models
if chemostat
    gRate   = 0.1;
    %Fix dilution rate in ecModel
    [~,~, ecModel] = fixObjective(ecModel,true,gRate);
    %Fix minimal carbon source uptake rate in ecModel
    ecModel        = setParam(ecModel,'obj', pos, -1);
    [~,~,ecModel]  = fixObjective(ecModel,false);
    %Fix minimal total protein usage in ecModel
    index          = find(contains(ecModel.rxnNames,'prot_pool'));
    ecModel        = setParam(ecModel,'obj', index, -1);
else
    %Optimize growth for ecModel
    [gRate,~, ecModel] = fixObjective(ecModel,true);
    %Fix minimal total protein usage in ecModel
    index              = find(contains(ecModel.rxnNames,'prot_pool'));
    ecModel            = setParam(ecModel,'obj', index, -1);
end
%Get an optimal flux distribution for the ecModel
[~,ecFluxDist,ecModel] = fixObjective(ecModel,false);
%Fix optimal carbon source uptake for the ecModel in the original model 
%(Convention: GEMs represent uptake fluxes as negative values)
carbonUptake           = ecFluxDist(pos);
c_source               = strcmpi(model.rxns,c_source);
model.lb(c_source)     = -carbonUptake;
disp([c_source ': ' num2str(carbonUptake)])
%Fix optimal gRate (from ecModel) in the model and get an optimal flux 
%distribution
[~,FluxDist,model]     = fixObjective(model,true,gRate);
%Get the variability range for each of the non-objective reactions in the
%original model
for i=1:length(rxnsIndxs) 
    indx    = rxnsIndxs(i);
    fluxVal = FluxDist(indx);
    rxnID   = model.rxns(indx);
    rev     = false;
    if model.rev(indx) ==1
        rev = true;
    end
    bounds = [];
    range  = MAXmin_Optimizer(model,indx,bounds,tol);
    %If max and min were feasible then the optimization proceeds with
    %the ecModel
    relative = 0;
    if ~isempty(range)
        %MAX-min proceeds for the ecModel if the FV range and optimal flux
        %value are non-zero for the original model
        if ~(range<tol & abs(fluxVal)<tol) 
            %Get the correspondent index(es) for the i-th reaction in the
            %ecModel
            mappedIndxs = rxnMapping(rxnID,ecModel,rev);
            %Get bounds from the optimal distribution to avoid artificially
            %induced variability
            bounds      = ecFluxDist(mappedIndxs);
            rangeEC     = MAXmin_Optimizer(ecModel,mappedIndxs,bounds,tol);
            if ~isempty(rangeEC)
                rangeGEM = [rangeGEM; range];
                range_EC = [range_EC; rangeEC];
                indexes  = [indexes; indx];
                relative = (rangeEC-range)/range; 
                disp(['ready with #' num2str(i) ' // model Variability: ' num2str(range) ' // ecModel variability: ' num2str(rangeEC)])
            end

        else
            blocked  = [blocked; indx];
        end
    end
    %disp(['ready with #' num2str(i) ', relative variability reduction:' num2str(relative*100) '%'])
end
%Plot FV cumulative distributions
FVA_Dists  = {rangeGEM, range_EC};
legends    = {'model', 'ecModel'};
titleStr   = 'Flux variability cumulative distribution';
[~, stats] = plotCumDist(FVA_Dists,legends,titleStr);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [OptimalValue, optFluxDist, irrevModel] = fixObjective(irrevModel,fixed,priorValue)
% Optimize and fixes objective value for GEM
objIndx  = find(irrevModel.c~=0);
if fixed 
    factor = 0.99999;
else
    factor = 0;
end

if nargin == 3
    irrevModel.lb(objIndx) = factor*priorValue;
    irrevModel.ub(objIndx) = priorValue;
else
    sol = solveLP(irrevModel);
    irrevModel.lb(objIndx) = factor*sol.x(objIndx);
    irrevModel.ub(objIndx) = sol.x(objIndx);
end
sol = solveLP(irrevModel);
if ~isempty(sol.f)
    OptimalValue = sol.x(objIndx);
    optFluxDist  = sol.x;
end
disp(['The optimal value is ' num2str(OptimalValue)])
end