function [model, newPtot]  = updateProtPool(model, Ptot, modelAdapter)
% updateProtPool
%   Updates the protein pool to compensate for measured proteomics data (in
%   model.ec.concs).
%
% Input:
%   model           an ecModel in GECKO 3 format (with ecModel.ec structure)
%   Ptot            total protein content, overwrites modelAdapter value
%   modelAdapter    a loaded model adapter (Optional,
%
% Output:
%   model           an ecModel where model.ec.concs is populated with
%                   protein concentrations
%   newPtot         new Ptot
% Usage:
%   [model, newPtot]  = updateProtPool(model, Ptot, modelAdapter)

if nargin < 3 || isempty(modelAdapter)
    modelAdapter = ModelAdapterManager.getDefaultAdapter();
    if isempty(modelAdapter)
        error('Either send in a modelAdapter or set the default model adapter in the ModelAdapterManager.')
    end
end
params = modelAdapter.params;

if nargin < 2 || isempty(Ptot)
    Ptot = params.Ptot;
end

originalLB = model.lb(strcmp(model.rxns,'prot_pool_exchange'));
PmeasEnz = sum(model.ec.concs,'omitnan');
PtotEnz = Ptot * 1000 * params.f;
PdiffEnz = PtotEnz - PmeasEnz;
if PdiffEnz > 0
    Pdiff = (PdiffEnz / params.f)/1000; % Convert back to g protein/gDCW
    model = setProtPoolSize(model, Pdiff, params.f, params.sigma, modelAdapter);
    sol = solveLP(model);
    if isempty(sol.x)
        error(['Changing protein pool to ' num2str(Pdiff*params.f, params.sigma) ' resuls in a non-functional model'])
    end
else
    error('The total measured protein mass exceeds the total protein content.')
end
newPtot = PdiffEnz / 1000 / params.f
end
