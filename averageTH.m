%% Getting average TH and processing control files

%% Asigning memory
thresh = zeros(numel(control_files),1)+thresh_D; % reset threshold to 0.5
unmasked_total = zeros(numel(control_files),1);
message = struct([]);
% message = reshape(message,1,numel(control_files));
for i = 1:numel(control_files)
    % Open control image _1.tif
    % Open original image: use bfopen function from Loci Bioformats.
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
    
    % Extract filename, path and extension
    % filepath = imdata{2};
    % [pathstr, filename, ext] = fileparts(filepath);
    
    % *** FILTERIMAGE: clean-up image ***
    % 2) Gentle Gaussian smoothing to even out the noise:
    filteredimage = imfilter(originalimage, fspecial('Gaussian', 5, 0.75));
    % 3) Median filter to further reduce noise while preserving edges:
    filteredimage = medfilt2(filteredimage, [5 5]);
    
    % *** Apply membrane mask, if specified, otherwise mask just "black" regions ***
    
   if  strcmp(usemask, 'Borders')
        
        % Specify path for Packing Analyzer hand-corrected membrane mask.
        maskpath = [tif8_dir_control, '/', num2str(i), '/handCorrection.tif'];
        
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
      maskpath = [tif8_dir_control, '/', num2str(i), '/handCorrection.tif'];
        
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
    
    
    % *** Now search for threshold, based on target puncta area ***
    
    % Define variables
    
    iterations = 1; % count search cycles
    limit = 100; % stop searching if go on too long
    up_or_down = 1; % flag for whether to search above or below
    last_search = 0; % flag to remember direction of previous increment
    increment = 0.2; % size of next search step, set to 2x first step
    outcome = 0; % flag for whether found threshold
    message{i} = ''; % output message to record result
    
    % Get area of unmasked regions of filtered image
    OBJECTS = bwconncomp(unmasked_regions);
    unmasked_area = regionprops(OBJECTS, 'Area');
    unmasked_area = cell2mat(struct2cell(unmasked_area));
    unmasked_total(i) = sum(unmasked_area(:));
    
    while up_or_down ~= 0
        
        % ** Apply current threshold, mask and get relative puncta area **
        
        binaryimage = imbinarize(filteredimage, thresh(i));
        
        binaryimage = binaryimage & unmasked_regions;
        
        % Next lines tidy up remaining puncta map and remove objects below minobjectsize
        binaryimage = bwmorph(binaryimage, 'bridge');
        binaryimage = bwmorph(binaryimage, 'clean');
        binaryimage = imfill(binaryimage, 'holes');
        binaryimage = bwmorph(binaryimage, 'close');
        binaryimage = imfill(binaryimage, 'holes');
        binaryimage = bwareaopen(binaryimage, minobjectsize);
        
        % Find objects and get total area
        PUNCTA = bwconncomp(binaryimage);
        Parea = regionprops(PUNCTA, 'Area');
        Parea = cell2mat(struct2cell(Parea));
        Pareatotal = sum(Parea(:));
        
        % Get ratio of puncta area to unmasked image area
        relative_puncta_area = Pareatotal/unmasked_total(i);
        
        % ** Test if above, below or on target
        
        if relative_puncta_area > (target_area + area_tolerance)
            up_or_down = 1; % Need to raise threshold to reduce puncta area
        elseif relative_puncta_area < (target_area - area_tolerance)
            up_or_down = -1; % Need to lower threshold to reduce puncta area
        else
            up_or_down = 0; % Have hit target
            outcome = 1; % set flag to indicate success
            message{i} = strcat('Identified threshold (', num2str(iterations), ' iterations)');
            continue % jump back to start of loop to exit
        end
        
        % ** If first search, or have overshot, halve increment size **
        if up_or_down ~= last_search
            increment = increment/2;
        end
        
        % ** Adjust theshold **
        thresh(i) = thresh(i) + (increment * up_or_down);
        
        % ** Test new threshold within sensible bounds
        if (thresh(i) < (0-increment)), or (thresh(i) > (1+increment))
            up_or_down = 0; % stop searching
            outcome = 0; % failed to find threshold
            message{i} = 'Failed to find threshold in range 0-1';
            continue
        end
        
        % ** set last_search flag **
        last_search = up_or_down;
        
        % ** Increment counter **
        iterations = iterations + 1;
        
        % Need to test if have been searching too long
        if iterations>limit
            up_or_down = 0; % stop searching
            outcome = 0; % failed to find threshold
            message{i} = strcat('Failed to find threshold (', num2str(increment), ' iterations)');
            continue
        end
        
    end
    
    disp(message{i});
end