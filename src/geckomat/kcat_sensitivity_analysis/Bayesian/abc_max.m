function [rmse_final,exp,simulated,growthdata,max_growth]=abc_max(ecModel,kcat_random_all,growthdata,max_growth,proc,sample_generation,j,rxn2block)
% setProtPoolSize
%   Internal function in BayesianSensitivityTuning. Gets the average RMSE for 
%   a certain set of growth data and kcats.
%
% Input:
%   ecModel         ecModel that was generated by makeEcModel, or loaded from
%                   an earlier run. Not compatible with ecModels generated by
%                   earlier GECKO versions (pre 3.0).
%   kcat_random_all Sampled kcat values
%   growthdata      Growth data loaded from file.
%   max_growth      Max growth data loaded from file.
%   proc            Number of experiments with data
%   sample_generation Total number of randomly generated kcat sets in this iteration
%   j               Which experiment to use
%   rxn2block       List of reactions to block, could be read from file.
%
% Output:
%   rmse_final      The average RMSE
%   exp             Metabolite export
%   simulated       Result from simulation
%   growthdata      The growth data
%   max_growth      The max growth data (without input constraints)

nstep = sample_generation/proc;
rmse_final = zeros(1,nstep);
kcat_sample = kcat_random_all(:,(j-1)*nstep+1:j*nstep);


% get carbonnum for each exchange rxn to further calculation of error
if ~isfield(ecModel,'excarbon')
    ecModel = addCarbonNum(ecModel);
end

for k = 1:nstep
    %disp(['nstep:',num2str(k),'/',num2str(nstep)])
    kcat_random  = kcat_sample(:,k);
    ecModel.ec.kcat = kcat_random;
    ecModel = applyKcatConstraints(ecModel);
    
    %% first search with substrate constraints
    objective = 'r_2111';
    if ~isempty(growthdata)
        [rmse_1,exp_1,simulated_1] = rmsecal(ecModel,growthdata,true,objective,rxn2block);
    else
        rmse_1 = [];
        exp_1 = [];
        simulated_1 = [];
    end
    %% second search for maxmial growth rate without constraints
    if ~isempty(max_growth)  % simulate the maximal growth rate
        [rmse_2,exp_2,simulated_2] = rmsecal(ecModel,max_growth,false,objective,rxn2block);
    else
        rmse_2 = [];
        exp_2 = [];
        simulated_2 = [];
    end
    exp = [exp_1;exp_2];
    simulated = [simulated_1;simulated_2];
    rmse_final(1,k) = mean([rmse_1,rmse_2],'omitnan');
    
    %% only output simulated result for one generation
    if nstep ~= 1 || sample_generation ~= 1
        simulated = [];
        exp = [];
    end
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [rmse,exp,simulated] = rmsecal(ecModel,data,constrain,objective,rxn2block)

    simulated = zeros(length(data(:,1)),9);
    
    for i = 1:length(data(:,1))
        exp = cell2mat(data(:,3:11)); % u sub ace eth gly pyr ethyl_acetate co2 o2
        exp = exp.*[1,-1,1,1,1,1,1,1,-1];
        ex_mets = {'growth',[data{i,2},' exchange'],'acetate exchange','ethanol exchange','glycerol exchange','pyruvate exchange','ethyl acetate exchange','carbon dioxide exchange','oxygen exchange'};
        [~,idx] = ismember(ex_mets,ecModel.rxnNames);
        model_tmp = ecModel;

        model_tmp = changeMedia(model_tmp,'D-glucose',data(i,16));%TODO: These are currently hard-coded for yeast-GEM, add to adapter
        %Stop import/export of acetate and acetaldehyde
        model_tmp = changeRxnBounds(model_tmp,'r_1634',0,'b'); %TODO: These are currently hard-coded for yeast-GEM, add to adapter
        model_tmp = changeRxnBounds(model_tmp,'r_1631',0,'b');

        if strcmp(data(i,14),'anaerobic') ||strcmp(data(i,14),'limited') 
            model_tmp = anaerobicModel(model_tmp);
        end
        if strcmp(data(i,14),'limited') 
             model_tmp.lb(strcmp(model_tmp.rxnNames,'oxygen exchange')) = -5;%TODO: Currently hard-coded for yeast
        end
        if ~constrain
            %No export of glucose
            model_tmp.lb(strcmp(model_tmp.rxns,'r_1714')) = 0; %TODO: Currently hard-coded for yeast
            model_tmp.lb(strcmp(model_tmp.rxns,ecModel.rxns(idx(2)))) = -1000; % not constrain the substrate usage
        else
            %No export of glucose
            model_tmp.lb(strcmp(model_tmp.rxns,'r_1714')) = 0;%TODO: Currently hard-coded for yeast
            if isnan(exp(i,2))
                model_tmp.lb(idx(2)) = -1000;
            else
                model_tmp.lb(idx(2)) = exp(i,2);
            end
        end


        model_tmp.c = double(strcmp(model_tmp.rxns, objective));
        sol_tmp = solveLP(model_tmp);%,objective,osenseStr,prot_cost_info,tot_prot_weight,'ibm_cplex');
        if checkSolution(sol_tmp)
            sol(:,i) = sol_tmp.x;

            tmp = ~isnan(exp(i,:));
            excarbon = ecModel.excarbon(idx);
            excarbon(excarbon == 0) = 1;
            exp_tmp = exp(i,tmp).*excarbon(tmp);
            simulated_tmp = sol(idx(tmp),i)'.*excarbon(tmp); % normalize the growth rate issue by factor 10

            exp_block = zeros(1,length(setdiff(rxn2block,model_tmp.rxns(idx(2))))); % all zeros for blocked exchange mets exchange
            rxnblockidx = ismember(model_tmp.rxns,setdiff(rxn2block,model_tmp.rxns(idx(2))));
            simulated_block = sol(rxnblockidx,i)'.* ecModel.excarbon(rxnblockidx); %
            exp_block = exp_block(simulated_block~=0);
            simulated_block = simulated_block(simulated_block~=0);
            if constrain
                rmse_tmp(i) = sqrt(immse([exp_tmp,exp_block], [simulated_tmp,simulated_block]));
            else
                if length(exp_tmp) >= 2
                    rmse_tmp(i) = sqrt(immse(exp_tmp(1:2), simulated_tmp(1:2)));
                else
                    rmse_tmp(i) = sqrt(immse(exp_tmp(1), simulated_tmp(1)));
                end

            end
            simulated(i,:) = sol(idx,i)';
        else
            simulated(i,:) = NaN;
            rmse_tmp(i) = NaN;
        end
    end
    rmse_tmp(isnan(rmse_tmp)) = []; %we just skip any case without solution, they are pretty rare, but exist
    rmse = sum(rmse_tmp)/length(data(:,1));
end
