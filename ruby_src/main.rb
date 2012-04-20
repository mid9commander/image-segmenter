require './image_segmenter'
require './ppm_image_segmenter'
require './tree'

if ARGV[0] =~ /.ppm/
  PPMImageSegmenter.new(ARGV[0]).segment
elsif ARGV[0] =~ /.pgm/
  ImageSegmenter.new(ARGV[0]).segment
end



