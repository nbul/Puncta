% This version doesn't stretch the histogram before doing the thresholding
% It thresholds a control sample (control images) and obtain the average
% theshold from them, so that puncta cover a defined area, then applies the
% same threshold to a second sample (experiment images).

% After setting the parameters it asks to choose first a folder with
% control samples, which should contain tifs_8bit (with segmented images),
% and tifs_original (with original non-modified projections) subfolders.
% Then, it asks to select a folder with experiment images, which should
% be organised in the same way as the folder with control images. In both
% folders images should be named by sequencial numbers starting with 1
% (i.e. 1,2,3,4...).

% Ouputs: the script record settings, which were used for analysis in
% "settings. txt" file in the folder with control images. In the same
% folder it records "summary_control.csv" file with information about
% average punctas measurements from the control images. Similar information
% from experiment images is recordered as "summary_experiment.csv" in the
% folder that contains experiment images.


%% Clear workspace.
clear variables;
close all;
clc;
%% Default parameters
% *** DEFINE PIXEL AREA ***
pixelarea = 1;

% *** DEFINE MINIMAL OBJECT SIZE IN PIXELS ***
minobjectsize = 9;

% *** DEFINE DESIRED RADIUS OF MEMBRANE MASK IN PIXELS***
maskradius = 4;

% *** DEFINE FILE EXTENSION OF IMAGE FILES FOR PROCESSING ***
fileext = '.tif';

% *** DEFINE USE OF MEMBRANE MASK ***
usemask = 'No';

% *** DEFINE DEFAULT STARTING THRESHOLD VALUE ***
thresh_D = 0.5;

% *** DEFINE DEFAULT TARGET PUNCTA AREA ***
target_area = 0.02;

% *** DEFINE ACCEPTABLE TOLERANCE IN PUNCTA AREA ***
area_tolerance = 0.001;

%% *** ASK WHETHER SHOULD USE DEFAULT PARAMETERS ***
usedefault = questdlg(strcat('Use default settings (no membrane mask, pixelarea = ',num2str(pixelarea),...
    ', minobjectsize = ', num2str(minobjectsize), 'px, maskradius = ', num2str(maskradius),...
    'px, fileext = ', fileext,'?)'),'Settings','Yes','No','Yes');

if strcmp(usedefault, 'No');
    parameters = inputdlg({'Enter pixel area:', 'Enter minimum object size (in pixels)',...
        'Enter membrane mask radius (in pixels):', 'Enter file extension:'},'Parameters',1,...
        {num2str(pixelarea),num2str(minobjectsize),num2str(maskradius),fileext});
    % *** REDEFINE PIXEL AREA ***
    pixelarea = str2double(parameters{1});
    % *** REDEFINE MINIMAL OBJECT SIZE IN PIXELS ***
    minobjectsize = str2double(parameters{2});
    % *** REDEFINE DESIRED RADIUS OF MEMBRANE MASK ***
    maskradius = str2double(parameters{3});
    % *** REDEFINE FILE EXTENSION OF IMAGE FILES FOR PROCESSING ***
    fileext = parameters{4};
    % *** ASK WHETHER WANT TO USE MEMBRANE MASK ***
    usemask = questdlg('Use membrane mask?','Mask','Yes','No','Yes');
    parameters{5} = usemask;
    
    parameters = parameters';
else
    parameters{1} = num2str(pixelarea);
    parameters{2} = num2str(minobjectsize);
    parameters{3} = num2str(maskradius);
    parameters{4} = fileext;
    parameters{5} = usemask;
end

% *** GET TARGET PUNCTA AREA AND TOLERANCE ***
targets = inputdlg({'Enter target pixel area (%):', 'Enter acceptable tolerance (± %):'},...
    'Targets',1,{num2str(target_area*100),num2str(area_tolerance*100)});
parameters{6} = targets{1};
parameters{7} = targets{2};
target_area = str2double(targets{1})/100;
area_tolerance = str2double(targets{2})/100;

% Headers for output files

headers1 = {'File','Target_Area', 'Tolerance', 'Threshold','New_Threshold', 'Puncta_area', 'Mask_area',...
    'Actual_area', 'Tolerance_achieved', 'Iterations', 'Parea', 'Pareastd', 'Pmean',...
    'Pmeanstd', 'Pmax', 'Pmaxstd', 'Pmin', 'Pminstd', 'Pn', 'Carea', 'Careastd',...
    'Cmean', 'Cmeanstd', 'Cmax', 'Cmaxstd', 'Cmin', 'Cminstd', 'Cn', 'Marea', 'Mareastd', 'Mmean',...
    'Mmeanstd','Mmax','Mmaxstd', 'Mmin','Mminstd', 'Mn','MMean_puncta'};

headers2 = {'File','Target_Area', 'Tolerance', 'Threshold','New_Threshold', 'Puncta_area', 'Mask_area',...
    'Actual_area', 'Tolerance_achieved', 'Iterations', 'Parea', 'Pareastd', 'Pmean',...
    'Pmeanstd', 'Pmax', 'Pmaxstd', 'Pmin', 'Pminstd', 'Pn'};

headers3 = {'File','Target_Area', 'Tolerance', 'New_Threshold', 'Puncta_area', 'Mask_area',...
    'Actual_area', 'Tolerance_achieved', 'Parea', 'Pareastd', 'Pmean',...
    'Pmeanstd', 'Pmax', 'Pmaxstd', 'Pmin', 'Pminstd', 'Pn', 'Carea', 'Careastd',...
    'Cmean', 'Cmeanstd', 'Cmax', 'Cmaxstd', 'Cmin', 'Cminstd', 'Cn', 'Marea', 'Mareastd', 'Mmean',...
    'Mmeanstd','Mmax','Mmaxstd', 'Mmin','Mminstd', 'Mn','MMean_puncta'};

headers4 = {'File','Target_Area', 'Tolerance', 'New_Threshold', 'Puncta_area', 'Mask_area',...
    'Actual_area', 'Tolerance_achieved', 'Parea', 'Pareastd', 'Pmean',...
    'Pmeanstd', 'Pmax', 'Pmaxstd', 'Pmin', 'Pminstd', 'Pn'};


% Record input parameters to output array

settings = strcat('Using settings: membrane mask = ',usemask, ' , pixelarea = ',num2str(pixelarea),...
    ', minobjectsize = ', num2str(minobjectsize), 'px, maskradius = ', num2str(maskradius),...
    'px, fileext = ', fileext,', Target pixel area (%)= ', num2str(target_area*100),...
    ', Tolerance (%)= ', num2str(area_tolerance*100));
disp(settings);

%% Fetting experimental and control files
currdir = pwd;
addpath(pwd);
controldir = uigetdir(currdir,'Select a foleder with control images');
tif16_dir_control = [controldir, '/tifs_original'];
tif8_dir_control = [controldir, '/tifs_8bit'];

cd(controldir);
fid = fopen( 'settings.txt', 'wt' );
fprintf( fid, '%s\n', settings);
fclose(fid);
mkdir(controldir,'/binary');
im1_dir = [controldir, '/binary'];

cd(controldir);
mkdir(controldir,'/mask');
im2_dir = [controldir, '/mask'];

expdir = uigetdir(currdir,'Select a foleder with experiment images');
tif16_dir_exp = [expdir, '/tifs_original'];
tif8_dir_exp = [expdir, '/tifs_8bit'];

cd(expdir);
mkdir(expdir,'/binary');
im1_dir_exp = [expdir, '/binary'];

cd(expdir);
mkdir(expdir,'/mask');
im2_dir_exp = [expdir, '/mask'];

cd(tif16_dir_control);
control_files = dir(['*',fileext]);

% Time the processing
tic;


%% Average threshold

averageTH;
thresh_new = sum(thresh)/length(thresh);



control;


%% Writing data for control


filenames = 1:numel(control_files);
TA = zeros(numel(control_files),1) + target_area;
AT = zeros(numel(control_files),1) + area_tolerance;
TN = zeros(numel(control_files),1) + thresh_new;
message2 = cell2table(message);
message2 = message2{1,:}';
if  strcmp(usemask, 'Yes')
    output = [num2cell(filenames'), num2cell(TA), num2cell(AT), num2cell(thresh),...
        num2cell(TN), num2cell(Pareatotal_av), num2cell(unmasked_total), num2cell(relative_puncta_area2),...
        num2cell(tolerance_achieved), message2, num2cell(Parea_av), num2cell(Pareastd_av),...
        num2cell(Pmean_av), num2cell(Pmeanstd_av), num2cell(Pmax_av)...
        num2cell(Pmaxstd_av), num2cell(Pmin_av), num2cell(Pminstd_av), num2cell(Pn),...
        num2cell(Carea_av), num2cell(Careastd_av),num2cell(Cmean_av), num2cell(Cmeanstd_av),...
        num2cell(Cmax_av), num2cell(Cmaxstd_av), num2cell(Cmin_av), num2cell(Cminstd_av), num2cell(Cn),...
        num2cell(Marea_av), num2cell(Mareastd_av),num2cell(Mmean_av), num2cell(Mmeanstd_av),...
        num2cell(Mmax_av), num2cell(Mmaxstd_av), num2cell(Mmin_av), num2cell(Mminstd_av), num2cell(Mn),...
        num2cell(Mmean_nonpuncta)];
        output = cell2table(output);
        output.Properties.VariableNames = headers1;
else
      output = [num2cell(filenames'), num2cell(TA), num2cell(AT), num2cell(thresh),...
        num2cell(TN), num2cell(Pareatotal_av), num2cell(unmasked_total), num2cell(relative_puncta_area2),...
        num2cell(tolerance_achieved), message2, num2cell(Parea_av), num2cell(Pareastd_av),...
        num2cell(Pmean_av), num2cell(Pmeanstd_av), num2cell(Pmax_av)...
        num2cell(Pmaxstd_av), num2cell(Pmin_av), num2cell(Pminstd_av), num2cell(Pn)];  
        output = cell2table(output);
        output.Properties.VariableNames = headers2;
end

cd(controldir);
writetable(output,'summary_control.csv');

% *** Save binary thresholded image to image folder ***


cd(tif16_dir_exp);
exp_files = dir(['*',fileext]);

clear output filenames;
filenames = 1:numel(exp_files);

experiment;
TA = zeros(numel(exp_files),1) + target_area;
AT = zeros(numel(exp_files),1) + area_tolerance;
TN = zeros(numel(exp_files),1) + thresh_new;
if  strcmp(usemask, 'Yes')
    output = [num2cell(filenames'), num2cell(TA), num2cell(AT),...
        num2cell(TN), num2cell(Pareatotal_av), num2cell(unmasked_total), num2cell(relative_puncta_area2),...
        num2cell(tolerance_achieved), num2cell(Parea_av), num2cell(Pareastd_av),...
        num2cell(Pmean_av), num2cell(Pmeanstd_av), num2cell(Pmax_av)...
        num2cell(Pmaxstd_av), num2cell(Pmin_av), num2cell(Pminstd_av), num2cell(Pn),...
        num2cell(Carea_av), num2cell(Careastd_av),num2cell(Cmean_av), num2cell(Cmeanstd_av),...
        num2cell(Cmax_av), num2cell(Cmaxstd_av), num2cell(Cmin_av), num2cell(Cminstd_av), num2cell(Cn),...
        num2cell(Marea_av), num2cell(Mareastd_av),num2cell(Mmean_av), num2cell(Mmeanstd_av),...
        num2cell(Mmax_av), num2cell(Mmaxstd_av), num2cell(Mmin_av), num2cell(Mminstd_av), num2cell(Mn),...
        num2cell(Mmean_nonpuncta)];
        output = cell2table(output);
        output.Properties.VariableNames = headers3;
else
      output = [num2cell(filenames'), num2cell(TA), num2cell(AT),...
        num2cell(TN), num2cell(Pareatotal_av), num2cell(unmasked_total), num2cell(relative_puncta_area2),...
        num2cell(tolerance_achieved), num2cell(Parea_av), num2cell(Pareastd_av),...
        num2cell(Pmean_av), num2cell(Pmeanstd_av), num2cell(Pmax_av)...
        num2cell(Pmaxstd_av), num2cell(Pmin_av), num2cell(Pminstd_av), num2cell(Pn)];  
        output = cell2table(output);
        output.Properties.VariableNames = headers4;
end

cd(expdir);
writetable(output,'summary_experiment.csv');

cd(currdir);
% End timer.
toc

clear variables;
close all;
clc