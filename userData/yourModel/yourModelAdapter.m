classdef yourModelAdapter < ModelAdapter
    methods
        function obj = yourModelAdapter()
            %Set initial values of the obj.params - they can be changed by the user
            
            %Directory where all model-specific files and scripts are kept.
            %Is assumed to follow the GECKO-defined folder structure. The
            %code below refers to userData/ecYeastGEM in the GECKO path.
            geckoPath = findGECKOroot;
            obj.params.path = fullfile(geckoPath,'userData','yourModel');

			%Path to the conventional GEM that this ecModel will be based on.
			obj.params.convGEM = fullfile(obj.params.path,'models','yourModel.xml');

			%Average enzyme saturation factor
			obj.params.sigma = 0.5;

			%Total protein content in the cell [g protein/gDw]
			obj.params.Ptot = 0.5;

			%Fraction of enzymes in the model [g enzyme/g protein]
			obj.params.f = 0.5;
            
            %Growth rate the model should be able to reach when not
            %constraint by nutrient uptake (e.g. max growth rate) [1/h]
			obj.params.gR_exp = 0.41;

			%Provide your organism scientific name
			obj.params.org_name = 'saccharomyces cerevisiae';
            
            %Matching name for Complex Portal
            obj.params.complex_org_name = 'Saccharomyces cerevisiae';

			%Provide your organism KEGG ID, selected at
			%https://www.genome.jp/kegg/catalog/org_list.html
			obj.params.keggID = 'sce';
            % Field for KEGG gene identifier; should match the gene
            % identifiers used in the model. With 'kegg', it takes the
            % default KEGG Entry identifier (for example YER023W here:
            % https://www.genome.jp/dbget-bin/www_bget?sce:YER023W).
            % Alternatively, gene identifiers from the "Other DBs" section
            % of the KEGG page can be selected. For example "NCBI-GeneID",
            % "UniProt", or "Ensembl". Not all DB entries are available for
            % all organisms and/or genes.
            obj.params.keggGeneIdentifier = 'kegg';

			%Provide what identifier should be used to query UniProt.
            %Select proteome IDs at https://www.uniprot.org/proteomes/
            %or taxonomy IDs at https://www.uniprot.org/taxonomy.
            obj.params.uniprotIDtype = 'taxonomy_id'; % 'proteome' or 'taxonomy_id'
			obj.params.uniprotID = '559292'; % should match the ID type
            %Field for Uniprot gene ID - should match the gene ids used in the 
            %model. It should be one of the "Returned Field" entries under
            %"Names & Taxonomy" at this page: https://www.uniprot.org/help/return_fields
            obj.params.uniprotGeneIdField = 'gene_oln';
            %Whether only reviewed data from UniProt should be considered.
            %Reviewed data has highest confidence, but coverage might be (very)
            %low for non-model organisms
            obj.params.uniprotReviewed = true;

			%Reaction ID for glucose exchange reaction (or other preferred carbon source)
			obj.params.c_source = 'r_1714'; 

			%Reaction ID for biomass pseudoreaction
			obj.params.bioRxn = 'r_4041';

			%Reaction ID for non-growth associated maitenance pseudoreaction
			obj.params.NGAM = 'r_4046';

			%Compartment name in which the added enzymes should be located
			obj.params.enzyme_comp = 'cytoplasm';

			%Rxn names for the most common experimentally measured "exchange" fluxes
			%For glucose and o2 uptakes add the substring: " (reversible)" at the end
			%of the corresponding rxn name. This is due to the irreversible model
			%nature of ecModels. NOTE: This parameter is only used by fitGAM.m, so if
			%you do not use said function you don not need to define it.
			obj.params.exch_names{1} = 'growth';
			obj.params.exch_names{2} = 'D-glucose exchange (reversible)';
			obj.params.exch_names{3} = 'oxygen exchange (reversible)';
			obj.params.exch_names{4} = 'carbon dioxide exchange';

			%Biomass components pseudoreactions (proteins, carbs and lipids lumped
			%pools). NOTE: This parameter is only used by scaleBioMass.m, so if you do
			%not use said function you don not need to define it. (optional)
			obj.params.bio_comp{1} = 'protein';
			obj.params.bio_comp{2} = 'carbohydrate';
			obj.params.bio_comp{3} = 'lipid backbone';
			obj.params.bio_comp{4} = 'lipid chain';

			%Polymerization costs from Forster et al 2003 - table S8. NOTE: This
			%parameter is only used by scaleBioMass.m, so if you do not use said
			%function you don not need to define it. (optional)
			obj.params.pol_cost(1) = 37.7; %Ptot 
			obj.params.pol_cost(2) = 12.8; %Ctot
			obj.params.pol_cost(3) = 26.0; %RNA 
			obj.params.pol_cost(4) = 26.0; %DNA

			%Rxn IDs for reactions in the oxidative phosphorylation pathway (optional)
			obj.params.oxPhos{1} = 'r_1021';
			obj.params.oxPhos{2} = 'r_0439';
			obj.params.oxPhos{3} = 'r_0438';
			obj.params.oxPhos{4} = 'r_0226';


			%TODO: I'm not sure why this param exists for Human-GEM but not for Yeast-GEM - investigate.
			%Experimental carbon source uptake (optional)
			%obj.params.c_UptakeExp = 0.641339301; %[mmol/gDw h]/Average across NCI60 cell lines
        end
		
        function result = getFilePath(obj, filename)
			result = filename; % TODO: Look at how this should be solved - look at the GeckoLight solution below
			%result = strcat(GeckoLightInstall.getGeckoLightMainPath(), 'data/humanGEM/', filename);
		end
		
		function [spont,spontRxnNames] = getSpontaneousReactions(obj,model)
			%TODO: I'm not sure if this information exists in Yeast-GEM - if it does, it should be returned in this function
			%For now, we say none of them are spontaneous.
			spont = contains(model.rxnNames,'spontaneous');
            spontRxnNames = {''};%rxns_tsv.rxns; For now, create an empty cell
			%rxns_tsv = importTsvFile(strcat(getHumanGEMRootPath(),'model/reactions.tsv'));
			%spont = rxns_tsv.spontaneous;
		end
	end
end