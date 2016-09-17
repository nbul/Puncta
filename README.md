# Puncta
Script to quantify protein accumulation in puncta

This version doesn't stretch the histogram before doing the thresholding
It thresholds a control sample (control images) and obtain the average
theshold from them, so that puncta cover a defined area, then applies the
same threshold to a second sample (experiment images).

It can calculate protein accumulation either using a binary mask from 
Packing Analyser, or the entiry field. It can be selected at the beginning
which option to use.

After setting the parameters it asks to choose first a folder with
control samples, which should contain tifs_8bit (with segmented images),
and tifs_original (with original non-modified projections) subfolders.
Then, it asks to select a folder with experiment images, which should
be organised in the same way as the folder with control images. In both
folders images should be named by sequencial numbers starting with 1
(i.e. 1,2,3,4...). The files do not have to be '.tif' as the script
uses bfopen to open images. The format can be selected at the beginning.

Ouputs: the script record settings, which were used for analysis in
"settings. txt" file in the folder with control images. In the same
folder it records "summary_control.csv" file with information about
average punctas measurements from the control images. Similar information
from experiment images is recordered as "summary_experiment.csv" in the
folder that contains experiment images.