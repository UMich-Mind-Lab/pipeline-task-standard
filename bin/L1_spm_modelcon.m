function L1_spm_modelcon(varargin)

try
  % parse inputs
  p = inputParser;

  addParameter(p,'SPM','');
  addParameter(p,'task','');
  addParameter(p,'outFile','');
  addParameter(p,'spmCfg','config/spm_modelcon_config.json')

  parse(p,varargin{:});

  %load SPM file into workspace
  load(p.Results.SPM);

  % extract condition names from SPM.mat
  nSess = length(SPM.Sess);
  for i = 1:nSess
    allConditions{i} = vertcat(SPM.Sess(i).U.name);
  end

  %read SPM config file
  spmCfg = jsondecode(fileread(p.Results.spmCfg));

  task = p.Results.task;
  cons = fields(spmCfg.(task));
  nCons = length(cons);

  %% generate matlabbatch
  % loop through each contrast in config
  for i = 1:nCons
    %first, we need to access the spmCfg file and get conditions, then right-pad
    %each individual cell array so that they are all of the same length
    iCon = sprintf('con%i',i);
    maxNConditions = max(cellfun(@length,spmCfg.(task).(iCon).conditions));

    %% If
    %     a) the condition names match for each session in spmCfg
    %     b) the condition weights match for each session in spmCfg
    %     c) each condition exists in SPM.mat for at least one session, AND
    %     d) there is at least one condition missing for at least one session
    % Then
    %     we're going to redistribute the weight of that condition so that
    %     we can still get a contrast

    %loop through con config, pad if needed, then test if each contrast exists
    clear condExist;
    for j = 1:nSess
      nPad = maxNConditions - length(spmCfg.(task).(iCon).conditions{j});
      spmCfg.(task).(iCon).conditions{j} = vertcat(spmCfg.(task).(iCon).conditions{j},repmat({''},nPad,1));
      condExist(j,:) = ismember(spmCfg.(task).(iCon).conditions{j},vertcat(allConditions{j},{''}));
    end

    condNamesMatch = all(cellfun(@(x) isequal(x,spmCfg.(task).(iCon).conditions{1}),spmCfg.(task).(iCon).conditions));
    condWeightsMatch = all(all(spmCfg.(task).(iCon).weights(1,:) == spmCfg.(task).(iCon).weights));
    condAnySesExist = all(any(condExist,1));
    condAllSesExist = all(all(condExist,1));

    if condNamesMatch && condWeightsMatch && condAnySesExist && ~condAllSesExist
      % 1. get total weight per condition
      % 2. get nSess for each condition
      % 3. element-wise division
      % 4. replace missing condition weights with 0
      % 5. replace missing condition names with empty string
      sumSesWeights = sum(spmCfg.(task).(iCon).weights);
      numSesConditions = sum(condExist);
      newSesWeights = sumSesWeights ./ numSesConditions;
      spmCfg.(task).(iCon).weights = repmat(newSesWeights,nSess,1);
      spmCfg.(task).(iCon).weights(~condExist) = 0;
      warning('At least one condition specified for contrast %s is missing from the events.tsv file. We will still make the contrast by redistributing the weights across the different sessions',spmCfg.(task).(iCon).name);
    end

    %% only make contrast if requirements met.
    if (condNamesMatch && condWeightsMatch && condAnySesExist) || condAllSesExist
      % Reformat weights array to go into conn. The array needs to be the sum
      % of the number of conditions present in each session, and all conditions
      % not used in this contrast need to have a value set to 0
      w = zeros(1,length(vertcat(allConditions{:})));

      % loop through sessions
      for j = 1:nSess
        %extract conditions for current session
        c = spmCfg.(task).(iCon).conditions{j,:};

        % remove conditions that don't exist or are empty (if applicable)
        c = c(condExist(j,:));
        c = c(~cellfun(@isempty,c));

        %if not first session, then all condition indices need to be shifted
        %based on how many total conditions existed in the prior session
        nShift=0;
        if j > 1
          nShift=length(vertcat(allConditions{1:j-1}));
        end

        %now loop through conditions for current session
        for k = 1:length(c)
          %get index for condition within session condition list
          idx = find(strcmp(allConditions{j},c{k})) + nShift;
          %add appropriate value to weights array
          w(idx) = spmCfg.(task).(iCon).weights(j,k);
        end
      end

      %populate mbatch for current contrast
      mbatch{1}.spm.stats.con.consess{i}.tcon.name = spmCfg.(task).(iCon).name;
      mbatch{1}.spm.stats.con.consess{i}.tcon.weights = w;
      mbatch{1}.spm.stats.con.consess{i}.tcon.sessrep = 'none';

    %% otherwise, we can't make the contrast
    else
      warning('Cannot make contrast %s. Expected condition names not adequately present in their events.tsv file.',spmCfg.(task).(iCon).name);
    end
  end
  %populate rest of batch info
  mbatch{1}.spm.stats.con.spmmat = {p.Results.SPM};
  mbatch{1}.spm.stats.con.delete = 1;

  %% save matlabbatch to run in container
  save(p.Results.outFile,'mbatch');

catch ME
  fprintf('MATLAB code threw an exception:\n')
  fprintf('%s\n',ME.message);
  if length(ME.stack) ~= 0
    for i = 1:length(ME.stack)
      fprintf('File:%s\nName:%s\nLine:%d\n',ME.stack(i).file,...
        ME.stack(i).name,ME.stack(i).line);
    end
  end
end
