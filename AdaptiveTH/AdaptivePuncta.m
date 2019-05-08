%% Clear all and initial parameters
clc
clear variables
close all

%% Determening paths and setting folders
currdir = pwd;
addpath(pwd);
filedir = uigetdir();
cd(filedir);
%Folders with images
tif8_dir =[filedir, '/borders'];
tif16_dir = [filedir, '/tifs_original'];

%Folder to save information about cells
if exist([filedir, '/Summary'],'dir') == 0
    mkdir(filedir,'/Summary');
end
result_dir = [filedir, '/Summary'];

%Folder to save information about cells
if exist([filedir, '/Mask'],'dir') == 0
    mkdir(filedir,'/Mask');
end
mask_dir = [filedir, '/Mask'];

%Reading 16-bit average intensity projection files
cd(tif16_dir);
files_tif = dir('*.tif');

Punctapercell = zeros(numel(files_tif),1);
PunctaArea = zeros(numel(files_tif),1);
PunctaIntensity = zeros(numel(files_tif),1);
punctaAll = zeros(1,2);

for g=1:numel(files_tif)
    %% Open images and modify
    cd(tif16_dir);
    Cad = [num2str(g),'.tif'];
    cd(tif16_dir);
    Cad_im = imread(Cad);
    Cad_im2 = imgaussfilt(Cad_im,2);
    Cad_im3 = imbinarize(Cad_im2, adaptthresh(Cad_im2,0.4));
    Cad_thr = im2double(Cad_im2) .* Cad_im3;
    
    bd_dir = [tif8_dir,'/', num2str(g)];
    cd(bd_dir);   
    I=imread('handCorrection.tif');
    I2=imbinarize(rgb2gray(I),0);
    I2(:,1) = 0;
    I2(:,end) = 0;
    I2(1,:) = 0;
    I2(end,:) = 0;
    I3 = imcomplement(I2);
    I3 = imclearborder(I3,4);
    [im_x, im_y] = size(I2);
    
    %% Cell shape from regionprops
    cc_all=bwconncomp(I3);
    cc_cells=bwconncomp(I3,4);
    mask = uint16(zeros(size(I2))); 
    mask(cc_all.PixelIdxList{1}) = 1;
    mask = imfill( mask ,'holes');
    mask = bwareaopen(Cad_im3 .* double(mask),10);
    cd(mask_dir);
    imwrite(mask, [num2str(g),'.tif']);
    
    cc_puncta = bwconncomp(mask);
    puncta_all = regionprops(cc_puncta, Cad_im2, 'Area', 'MeanIntensity');
    Num_puncta = zeros(cc_cells.NumObjects,1);
    for k=1:cc_cells.NumObjects
        mask2 = uint16(zeros(size(I2)));
        mask2(cc_cells.PixelIdxList{k}) = 1;
        mask2 = bwareaopen(Cad_im3 .* double(mask2),10);
        cc_puncta2 = bwconncomp(mask2);
        Num_puncta(k) = cc_puncta2.NumObjects;
    end
    
    Punctapercell(g) = mean(Num_puncta);
    PunctaArea(g) = mean([puncta_all.Area]);
    PunctaIntensity(g) = mean([puncta_all.MeanIntensity]);
    
    punctaAll = [punctaAll; [[puncta_all.Area]', [puncta_all.MeanIntensity]']];
    
end

cd(result_dir);

headers = {'wing', 'Number_per_cell', 'Area', 'Intensity'};
csvwrite_with_headers('Summary.csv',[(1:numel(files_tif))',Punctapercell,PunctaArea,PunctaIntensity], headers);
headers2 = {'Area', 'Intensity'};
punctaAll(punctaAll(:,1) == 0,:) = [];
csvwrite_with_headers('Puncta.csv', punctaAll, headers2);
cd(currdir);
clc;
clear variables;