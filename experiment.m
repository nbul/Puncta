%% Processing experimental files and getting averages
%% Memory allocation
cd(tif16_dir_exp);
exp_files = dir(['*',fileext]);

unmasked_total = zeros(numel(exp_files),1);

Parea_av = zeros(numel(exp_files),1);
Pareastd_av = zeros(numel(exp_files),1);
Pmean_av = zeros(numel(exp_files),1);
Pmeanstd_av = zeros(numel(exp_files),1);
Pmax_av = zeros(numel(exp_files),1);
Pmaxstd_av = zeros(numel(exp_files),1);
Pmin_av = zeros(numel(exp_files),1);
Pminstd_av = zeros(numel(exp_files),1);
Pareatotal_av = zeros(numel(exp_files),1);
Pn = zeros(numel(exp_files),1);
Pn2 = zeros(numel(exp_files),1);
PPC = zeros(numel(control_files),1);

Carea_av = zeros(numel(exp_files),1);
Careastd_av = zeros(numel(exp_files),1);
Cmean_av = zeros(numel(exp_files),1);
Cmeanstd_av = zeros(numel(exp_files),1);
Cmax_av = zeros(numel(exp_files),1);
Cmaxstd_av = zeros(numel(exp_files),1);
Cmin_av = zeros(numel(exp_files),1);
Cminstd_av = zeros(numel(exp_files),1);
Cn = zeros(numel(exp_files),1);

Marea_av = zeros(numel(exp_files),1);
Mareastd_av = zeros(numel(exp_files),1);
Mmean_av = zeros(numel(exp_files),1);
Mmeanstd_av = zeros(numel(exp_files),1);
Mmax_av = zeros(numel(exp_files),1);
Mmaxstd_av = zeros(numel(exp_files),1);
Mmin_av = zeros(numel(exp_files),1);
Mminstd_av = zeros(numel(exp_files),1);
Mn = zeros(numel(exp_files),1);
tolerance_achieved = zeros(numel(exp_files),1);
Mmean_nonpuncta = zeros(numel(exp_files),1);

relative_puncta_area2 = zeros(numel(exp_files),1);

%% Processing control files and getting average
for i=1:numel(exp_files)
    cd(tif16_dir_exp);
    filename = [num2str(i), fileext];
    imdata = bfopen(filename);
    
    % Image and filepath is in first cell
    imdata = imdata{1};
    % Image is in first array
    originalimage = imdata{1};


 %crop edges since packing analyzer leaves a white border on the mask
    %note: I2=imcrop(I,rect) crops image I, rect is position vector [xmin,
    %ymin, width, height] which defines the crop area
    
    [image_height, image_width, ~] = size(originalimage);
    rect = [2,2,image_width-4, image_height-4];
    originalimage = imcrop(originalimage, rect);
    
    %add a black border of size 'border' to image
    border = 10;
    originalimage = padarray(originalimage,[border, border]);
    
    % 2) Gentle Gaussian smoothing to even out the noise:
    filteredimage = imfilter(originalimage, fspecial('Gaussian', 5, 0.75));
    % 3) Median filter to further reduce noise while preserving edges:
    filteredimage = medfilt2(filteredimage, [5 5]);
    
    % *** Apply membrane mask, if specified, otherwise mask just "black" regions ***
    
    if  strcmp(usemask, 'Borders')
        
        % Specify path for Packing Analyzer hand-corrected membrane mask.
        maskpath = [tif8_dir_exp, '/', num2str(i), '/handCorrection.tif'];
        
        % Need open membrane skeleton file and process before use
        skel = imread(maskpath);
        % dilate, erode to clean up. "radius" is half final thickness
        skel = imcrop(skel(:,:,1), rect); %crop edges of mask file
        skel = padarray(skel,[border, border]); %add border to mask fileskel = imclearborder(skel);
        skel = imclearborder(skel);
        skel = imdilate(skel, strel('disk', maskradius, 0));
        skel = bwmorph(skel, 'diag');
        skel = bwmorph(skel, 'thin', Inf);
        skel = bwmorph(skel, 'spur', Inf);
        % final dilation to create membrane mask
        mask = imdilate(skel, strel('disk', maskradius, 0));
        % mask filtered image, n.b. converts to binary
        unmasked_regions = filteredimage & mask;
        
    elseif strcmp(usemask, 'Cytoplasm')
        maskpath = [tif8_dir_exp, '/', num2str(i), '/handCorrection.tif'];
        
        % Need open membrane skeleton file and process before use
        skel = imread(maskpath);
        % dilate, erode to clean up. "radius" is half final thickness
        skel = imcrop(skel(:,:,1), rect); %crop edges of mask file
        skel = padarray(skel,[border, border]); %add border to mask fileskel = imclearborder(skel);
        skel = imclearborder(skel);
        skel = imdilate(skel, strel('disk', maskradius, 0));
        skel = bwmorph(skel, 'diag');
        skel = bwmorph(skel, 'thin', Inf);
        skel = bwmorph(skel, 'spur', Inf);
        % final dilation to create membrane mask
        mask = imdilate(skel, strel('disk', maskradius, 0));
        mask = imcomplement(mask);
        mask = imclearborder(mask);
        mask = imerode(mask, strel('disk', 4, 0));
        mask = bwareaopen(mask, 50);
        % mask filtered image, n.b. converts to binary
        unmasked_regions = filteredimage & mask;
    else    
        % mask off any completely black regions (assuming image has been cropped)
        unmasked_regions = imbinarize(filteredimage,0);
        
    end
    
    % Get area of unmasked regions of filtered image
    OBJECTS = bwconncomp(unmasked_regions);
    unmasked_area = regionprops(OBJECTS, 'Area');
    unmasked_area = cell2mat(struct2cell(unmasked_area));
    unmasked_total(i) = sum(unmasked_area(:));
    
    if strcmp(usemask, 'Borders') || strcmp(usemask, 'No mask')
        binaryimage = imbinarize(filteredimage, thresh_new);
        binaryimage = binaryimage & unmasked_regions;
        
        % Next lines tidy up remaining puncta map and remove objects below minobjectsize
        binaryimage = bwmorph(binaryimage, 'bridge');
        binaryimage = bwmorph(binaryimage, 'clean');
        binaryimage = imfill(binaryimage, 'holes');
        binaryimage = bwmorph(binaryimage, 'close');
        binaryimage = imfill(binaryimage, 'holes');
        binaryimage = bwareaopen(binaryimage, minobjectsize);
    else
        binaryimage = imbinarize(im2double(filteredimage), 'adaptive');
        binaryimage = binaryimage .* unmasked_regions;
    end
    
    % *** Get Puncta Stats ***
    
    if   strcmp(usemask, 'Borders') || strcmp(usemask, 'Cytoplasm')
        
        % Create inverse cytoplasmic mask
        cyto = imcomplement(unmasked_regions);
        cyto = imclearborder(cyto);
        
        % Get Puncta stats
        
        PUNCTA = bwconncomp(binaryimage);
        
        Pdata = regionprops(PUNCTA, originalimage, 'Area', 'MeanIntensity','MaxIntensity', 'MinIntensity');
        Parea = [Pdata.Area];
        Pmean = [Pdata.MeanIntensity];
        Pmax = [Pdata.MaxIntensity];
        Pmin = [Pdata.MinIntensity];
        
        Parea_av(i) = pixelarea * mean(Parea);
        Pareastd_av(i) = std(im2double(Parea));
        Pareatotal_av(i) = pixelarea * sum(Parea);
        Pmeanstd_av(i) = std(Pmean);
        Pmean_av(i) = mean(Pmean);
        Pmaxstd_av(i) = std(im2double(Pmax));
        Pmax_av(i) = mean(Pmax);
        Pminstd_av(i) = std(im2double(Pmin));
        Pmin_av(i) = mean(Pmin);
        
        Pn(i) = PUNCTA.NumObjects;
        Pn2(i) = PUNCTA.NumObjects/unmasked_total(i);
        
        % *** Cytoplasm stats: ***
        
        CYTO = bwconncomp(cyto);
        
        Cdata = regionprops(CYTO, originalimage, 'Area', 'MeanIntensity','MaxIntensity', 'MinIntensity');
        Carea = [Cdata.Area];
        Cmean = [Cdata.MeanIntensity];
        Cmax = [Cdata.MaxIntensity];
        Cmin = [Cdata.MinIntensity];
        
        Carea_av(i) = pixelarea * mean(Carea);
        Careastd_av(i) = std(im2double(Carea));
        Cmeanstd_av(i) = std(Cmean);
        Cmean_av(i) = mean(Cmean);
        Cmaxstd_av(i) = std(im2double(Cmax));
        Cmax_av(i) = mean(Cmax);
        Cminstd_av(i) = std(im2double(Cmin));
        Cmin_av(i) = mean(Cmin);
        
        Cn(i) = CYTO.NumObjects;
        
        % *** Membrane stats ***
        % Membrane is a single fused object.
        
        % Create mask for total area of cells and membrane, based on Packing
        % Analyzer skeleton (ensures outer cells only include half shared membrane)
        % membrane = imclearborder(~skel, 4);
        
        % Substract cytoplasm to give final membrane mask
        % membrane = membrane - cyto;
        
        MEMBRANE = bwconncomp(unmasked_regions);
        
        Mdata = regionprops(MEMBRANE, originalimage, 'Area', 'MeanIntensity','MaxIntensity', 'MinIntensity');
        Marea = [Mdata.Area];
        Mmean = [Mdata.MeanIntensity];
        Mmax = [Mdata.MaxIntensity];
        Mmin = [Mdata.MinIntensity];
        
        Marea_av(i) = pixelarea * mean(Marea);
        Mareastd_av(i) = std(im2double(Marea));
        Mmeanstd_av(i) = std(Mmean);
        Mmean_av(i) = mean(Mmean);
        Mmaxstd_av(i) = std(im2double(Mmax));
        Mmax_av(i) = mean(Mmax);
        Mminstd_av(i) = std(im2double(Mmin));
        Mmin_av(i) = mean(Mmin);
        
        Mn(i) = MEMBRANE.NumObjects;
        
        Mmean_nonpuncta(i) = ((Marea_av(i) * Mmean_av(i)) - (Pareatotal_av(i) * Pmean_av(i)))/(Marea_av(i)-Pareatotal_av(i));
        PPC(i) = Pn(i)/Mn(i);

    else
        
        % Get Puncta stats
        
        PUNCTA = bwconncomp(binaryimage);
        
        Pdata = regionprops(PUNCTA, originalimage, 'Area', 'MeanIntensity','MaxIntensity', 'MinIntensity');
        Parea = [Pdata.Area];
        Pmean = [Pdata.MeanIntensity];
        Pmax = [Pdata.MaxIntensity];
        Pmin = [Pdata.MinIntensity];
        
        Parea_av(i) = pixelarea * mean(Parea);
        Pareastd_av(i) = std(im2double(Parea));
        Pareatotal_av(i) = pixelarea * sum(Parea);
        Pmeanstd_av(i) = std(Pmean);
        Pmean_av(i) = mean(Pmean);
        Pmaxstd_av(i) = std(im2double(Pmax));
        Pmax_av(i) = mean(Pmax);
        Pminstd_av(i) = std(im2double(Pmin));
        Pmin_av(i) = mean(Pmin);
        
        Pn(i) = PUNCTA.NumObjects;
        Pn2(i) = PUNCTA.NumObjects/unmasked_total(i);
    end
    
    % *** Add stats to output array, including filename and data on threshold ***
    relative_puncta_area2(i) = Pareatotal/unmasked_total(i);
    tolerance_achieved(i) = abs(target_area - relative_puncta_area2(i));
    
    cd(im1_dir_exp);
    imwrite(binaryimage, [num2str(i), '_binary.tif'], 'tif');
    cd(im2_dir_exp);
    % *** Save mask used to image folder ***
    imwrite(unmasked_regions,[num2str(i), '_mask.tif'], 'tif');

end