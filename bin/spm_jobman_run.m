try
  jobfile = inputs{1};
  fprintf('running job: %s\n',jobfile);

  %load job cell array, convert2cell in order to circumvent inconsistent job variable naming
  job = load(jobfile);
  job = struct2cell(job);
  job = job{1};
  spm('defaults','fmri');
  spm_jobman('initcfg');

  spm_jobman('run',job);

catch ME
  %print error messages
  fprintf('MATLAB code threw an exception:\n')
  fprintf('%s\n',ME.message);
  if length(ME.stack) ~= 0
    for i = 1:length(ME.stack)
      fprintf('File:%s\nName:%s\nLine:%d\n',ME.stack(i).file,...
        ME.stack(i).name,ME.stack(i).line);
    end
  end
end
