function [model, foundComplex, proposedComplex] = applyComplexData(model, complexInfo, modelAdapter, verbose)
% applyComplexData
%   Apply stochiometry for complex in an ecModel
%
% Input:
%   model           an ecModel in GECKO 3 format (with ecModel.ec structure)
%   complexInfo     structure as generated by getComplexData. If nothing
%                   is provided, an attempt will be made to read
%                   data/ComplexPortal.json from the obj.params.path folder
%                   specified in the modelAdapter.
%   modelAdapter    a loaded model adapter (Optional, will otherwise use the
%                   default model adapter).
%   verbose         logical if a summary should be shown in the Command
%                   Window (Optional, default true)
%
% Output:
%   model           ecModel where model.ec.rxnEnzMat is populated with
%                   subunit stochiometries
%   foundComplex    complexes that fully matched between the model and the
%                   complex data
%   proposedComplex complexes where the model contained >75% but <100% of
%                   the proteins indicated by Complex Portal, or where the
%                   model contained more proteins than indicated for that
%                   complex in Complex Portal.
%
% Usage:
%   [model, foundComplex, proposedComplex] = applyComplexData(ecModel, complexInfo, modelAdapter);

if nargin < 4 || isempty(verbose)
    verbose = true;
end

if nargin < 3 || isempty(modelAdapter)
    modelAdapter = ModelAdapterManager.getDefaultAdapter();
    if isempty(modelAdapter)
        error('Either send in a modelAdapter or set the default model adapter in the ModelAdapterManager.')
    end
end
params = modelAdapter.params;

if nargin<2 || isempty(complexInfo)
    complexInfo = fullfile(params.path,'data','ComplexPortal.json');
    if ~isfile(complexInfo)
        complexInfo = getComplexData([], modelAdapter);
    end
end

if ischar(complexInfo) || isstring(complexInfo)
    jsonStr = fileread(complexInfo);
    complexData = jsondecode(jsonStr);
else
    complexData = complexInfo;
end


foundComplex = cell(0,7);
proposedComplex = cell(0,8);

%Remove prefixes on rxn names for gecko light
if ~model.ec.geckoLight
    rxnNames = model.ec.rxns;
else
    rxnNames = extractAfter(model.ec.rxns,4);
end

for i = 1:numel(rxnNames)
    bestComplexIdx = 0;
    bestMatch = 0;
    protIdsComplex = [];

    %if numel(genes) > 1
    idxProts = model.ec.rxnEnzMat(i,:) ~= 0;

    if any(idxProts)
        protIdsModel = model.ec.enzymes(idxProts);

        for j = 1:size(complexData, 1)

            protIdsComplex = complexData(j).protID;

            C = intersect(protIdsModel, protIdsComplex);

            % Determine the match percentage bewteen the proteins in the
            % model and the proteins in complex data
            if numel(C) == numel(protIdsModel) && numel(C) == numel(protIdsComplex)
                match = 1;
            else
                if numel(protIdsModel) < numel(protIdsComplex)
                    match = numel(C) / numel(protIdsComplex);
                else
                    match = numel(C) / numel(protIdsModel);
                end
            end

            % Check if the protID match with the complex data based on match % higher than
            % 75%. Pick the highest match.
            if match >= 0.75 && match > bestMatch
                bestComplexIdx = j;
                bestMatch = match*100;
                % In some cases all the model proteins are in the
                % complex data, but they are less than those in the
                % complex data.
                if match == 1 && numel(protIdsModel) == numel(protIdsComplex)
                    break
                end
            end
        end

        if bestMatch >= 75
            % Only get data with full match in the model and the
            % complex data. In some cases all the model proteins are in
            % the complex data, but they are less than those in complex data
            if bestMatch == 100 && numel(complexData(bestComplexIdx).protID) == numel(protIdsComplex)
                foundComplex(end+1,1) = {model.ec.rxns{i}};
                foundComplex(end,2) = {complexData(bestComplexIdx).complexID};
                foundComplex(end,3) = {complexData(bestComplexIdx).name};
                foundComplex(end,4) = {complexData(bestComplexIdx).geneName};
                foundComplex(end,5) = {protIdsModel};
                foundComplex(end,6) = {complexData(bestComplexIdx).protID};
                foundComplex(end,7) = {complexData(bestComplexIdx).stochiometry};

                % Some complex match in 100% but there is not stochiometry
                % reported. In this case, assign a value of 1.
                assignS = [complexData(bestComplexIdx).stochiometry];
                assignS(assignS == 0) = 1;
                model.ec.rxnEnzMat(i,idxProts) = assignS;
            else
                proposedComplex(end+1,1) = {model.ec.rxns{i}};
                proposedComplex(end,2) = {complexData(bestComplexIdx).complexID};
                proposedComplex(end,3) = {complexData(bestComplexIdx).name};
                proposedComplex(end,4) = {complexData(bestComplexIdx).geneName};
                proposedComplex(end,5) = {protIdsModel};
                proposedComplex(end,6) = {complexData(bestComplexIdx).protID};
                proposedComplex(end,7) = {complexData(bestComplexIdx).stochiometry};
                proposedComplex(end,8) = {bestMatch};
            end

        end
    end
%    end
    
end

rowHeadings = {'rxn', 'complexID','name','genes','protID_model','protID_complex','stochiometry'};

foundComplex = cell2table(foundComplex, 'VariableNames', rowHeadings);

proposedComplex = cell2table(proposedComplex, 'VariableNames', [rowHeadings 'match']);
if verbose
    disp(['A total of ' int2str(numel(foundComplex(:,1))) ' complex have full match, and ' int2str(numel(proposedComplex(:,1))) ' proposed.'])
end
end
