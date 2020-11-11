function L1_spm_modelspec(varargin)

try
  % parse inputs
  p = inputParser;

  addParameter(p,'inFunc','');
  addParameter(p,'inEvent','');
  addParameter(p,'inReg','');
  addParameter(p,'L1Dir','');
  addParameter(p,'bidsConfig','');
  addParameter(p,'spmConfig','config/spm_config.json');
  addParameter(p,'outFile','');

  parse(p,varargin{:});

  %read bidsConfig into workspace
  bidsCfg = jsondecode(fileread(p.Results.bidsConfig));

  %read spmConfig into workspace
  spmCfg = jsondecode(fileread(p.Results.spmConfig));
  spmCfg = spmCfg.(mfilename());

  % snakemake will submit in* variables as space-delimited filenames. We need to
  % make sure the right number of files were provided and then set up our loops
  funcs = split(p.Results.inFunc,' ');
  events = split(p.Results.inEvent,' ');
  regs = split(p.Results.inReg,' ');

  nRuns = [length(funcs),length(events),length(regs)];
  if any(nRuns ~= max(nRuns))
    error('Error: number of input files not consistent between inFunc, inEvents, and inReg:\n%s\n%s\n%s\nAborting\n', ...
        funcs,events,regs);
  end
  nRuns = max(nRuns);

  %delete previous SPM.mat if exists (causes matlab to hang)
  if exist(fullfile(p.Results.L1Dir,'SPM.mat'))
    delete(fullfile(p.Results.L1Dir,'SPM.mat'));
  end

  %batch configuration
  mbatch{1}.spm.stats.fmri_spec.dir = {p.Results.L1Dir}; %output folder
  mbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
  mbatch{1}.spm.stats.fmri_spec.timing.RT = bidsCfg.RepetitionTime;
  mbatch{1}.spm.stats.fmri_spec.timing.fmri_t = spmCfg.fmri_t;
  mbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = spmCfg.fmri_t0;
  mbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
  mbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = spmCfg.hrf_derivs;
  mbatch{1}.spm.stats.fmri_spec.volt = spmCfg.volt;
  mbatch{1}.spm.stats.fmri_spec.global = spmCfg.global;
  mbatch{1}.spm.stats.fmri_spec.mthresh = spmCfg.mthresh;
  mbatch{1}.spm.stats.fmri_spec.mask = {''};
  mbatch{1}.spm.stats.fmri_spec.cvi = spmCfg.cvi;

  %loop through sessions and populate values
  for i = 1:nRuns
    %get number of volumes
    nVols = length(spm_vol(funcs{i}));

    %create matrix of functional volumes (e.g., 'func.nii,1'; 'func.nii,2'; ...)
    volumes = cell(nVols,1);
    for j = 1:nVols
      volumes{j,1} = strcat(funcs{i},',',num2str(j));
    end

    mbatch{1}.spm.stats.fmri_spec.sess(i).scans = volumes; %smoothed volumes to be included in model

    %read events into workspace, reformat
    e = struct2table(tdfread(events{i}));
    e.trial_type = categorical(cellstr(e.trial_type));

    %get condition names
    condNames = unique(e.trial_type);

    for j = 1:length(condNames)
        %add info from results table to condition structure
        mbatch{1}.spm.stats.fmri_spec.sess(i).cond(j).name = char(condNames(j)); %name of block
        mbatch{1}.spm.stats.fmri_spec.sess(i).cond(j).onset = e{...
            e.trial_type == condNames(j),'onset'};
        mbatch{1}.spm.stats.fmri_spec.sess(i).cond(j).duration = e{...
            e.trial_type == condNames(j),'duration'};

        mbatch{1}.spm.stats.fmri_spec.sess(i).cond(j).tmod = 0;
        % if pmod columns exist in the task events file, then add in parametric
        % modulators
        iPmod = contains(e.Properties.VariableNames,'pmod');
        nPmod = sum(iPmod);

        % loop through parametric modulators if they exist
        if nPmod >= 1
          pmod = {e.Properties.VariableNames{iPmod}};
          for k = 1:nPmod
            %get name of pmod
            mbatch{1}.spm.stats.fmri_spec.sess(i).cond(j).pmod(k).name = strrep(pmod{k},'pmod_','');
            mbatch{1}.spm.stats.fmri_spec.sess(i).cond(j).pmod(k).param = e{...
              e.trial_type == condNames(j),pmod{k}};
            mbatch{1}.spm.stats.fmri_spec.sess(i).cond(j).pmod(k).poly = 1;
          end
        else
          mbatch{1}.spm.stats.fmri_spec.sess(i).cond(j).pmod = struct('name', {}, 'param', {}, 'poly', {});
        end
        mbatch{1}.spm.stats.fmri_spec.sess(i).cond(j).orth = 1;
    end

    %the rest of these are standard settings
    mbatch{1}.spm.stats.fmri_spec.sess(i).multi = {''};
    mbatch{1}.spm.stats.fmri_spec.sess(i).regress = struct('name', {}, 'val', {});
    mbatch{1}.spm.stats.fmri_spec.sess(i).multi_reg = {regs{i}}; %location of rp_trun file
    mbatch{1}.spm.stats.fmri_spec.sess(i).hpf = 128;
  end

  %save job to run in container
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

end
