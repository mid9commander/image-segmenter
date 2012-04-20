image-segmenter
===============
DjVuLibre is the open source version of the DjVu system. It currently lacks a good segmenter
that can separate the text and drawings from the backgrounds and continous-tone images
in a scanned document. The objective of our project is to build a foreground/background
segmenter by using various clustering methods, which are based on the same methods used
for DjVu [Bottou et al., 1998]. Ideally, the program will produce a “sepfile” that can be fed
to the command csepdjvu which takes the sepfile and compresses it into a composite DjVu
file. A sepfile consists of a foreground image, a background image, and a bitonal mask image
in a simple run-length-encoded format (RLE).
