function batch_check_coverage(niiPath,maskPath,outDir)

try
  % if any of the inputs are snakemake expands, then the inputs will be space
  % delimited strings, which we can separate by into a cell array. If they aren't
  % expand statements, then it'll just put the string as a single element of a
  % cell array. Of course, this doesn't work if people put spaces in their paths,
  % but hey, I'm an optimist (and also too lazy to deal with that for now).
  niiFiles = split(niiPath,' ');
  maskFiles = split(maskPath,' ');
  outDirs = split(outDir,' ');

  % some logic to handle different combinations of expands
  nOutDirs=length(outDirs);
  nNiiFiles=length(niiFiles);
  if nOutDirs == 1 & nNiiFiles ~= 1
    outDirs=repmat(outDirs,nNiiFiles,1)
  elseif nOutDirs ~= 1 & nOutDirs ~= nNiiFiles
    error('Error: Ambiguous number of output directories (%i) specified.',nOutDirs)
    exit;
  end
  %loop through niiFiles and masks, generate each coverage txt file
  for i = 1:length(niiFiles)
    for j = 1:length(maskFiles)
      %get name of mask and append to outDir
      [~,maskName,~] = fileparts(maskFiles{j});
      outFile = fullfile(outDirs{i},strcat(maskName,'.txt'));
      if ~exist(outDirs{i},'dir')
        mkdir(outDirs{i});
      end
    %calculate coverage
    fprintf('nii: %s\nmask: %s\noutput: %s\n',niiFiles{i},maskFiles{j},outFile);
    check_coverage(niiFiles{i},maskFiles{j},outFile);
    end
  end
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
