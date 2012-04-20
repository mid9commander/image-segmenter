require './ruby_extension'
require 'tempfile'

class Image
  attr_accessor :data, :width, :height, :max_val, :raster, :mask, :type

  def initialize
    self.type = :pgm
  end

  def length
    data.length
  end

  def each_byte
    data.each_byte do |c|
      yield c
    end
  end

  def [](index)
    data[index]
  end

  def pixel_at(x,y)
    yield @raster[x][y]
  end

  def self.deep_copy(one)
    another = Image.new
    another.width = one.width
    another.height = one.height
    another.max_val = one.max_val
    another.raster = Array.new(one.height).map{ Array.new(one.width,0) }
    another.mask = Array.new(one.height).map{ Array.new(one.width, 0) }
    another
  end

  def build
    @raster = Array.new(@height).map{ Array.new(@width) }
    @mask = Array.new(@height).map{ Array.new(@width) }
    puts @height
    puts @width
    for i in 0..(@height-1) do
      for j in 0..(@width-1) do
        @raster[i][j] = @data[i*width+j]
      end
    end
  end

  def write_to_file(file_name)
    header = "P5 #{@width} #{@height} #{@max_val}"
    File.open(file_name, "wb") do |file|
      file.puts(header)

      @raster.flatten.each do |byte|
        file.print byte.chr
      end
    end
  end

  def to_rle file
    file.puts("R4 #{@width} #{@height}")
    @raster.flatten.each do |byte|
      file.print byte.chr
    end
  end


  def to_ppm file
    file.puts("P6 #{@width} #{@height} #{@max_val}")
    @raster.flatten.each do |byte|
      file.print byte.chr
    end
  end
end

class PPMImage < Image
  SIZE = 3
  def initialize
    super
    self.type = :ppm
  end

  def self.deep_copy(one)
    another = PPMImage.new
    another.width = one.width
    another.height = one.height
    another.max_val = one.max_val
    another.raster = Array.new(one.height).map{ Array.new(one.width,0) }
    another.mask = Array.new(one.height).map{ Array.new(one.width, 0) }
    another
  end

  def build
    @raster = Array.new(@height).map{ Array.new(@width).map{ Array.new(SIZE)} }
    @mask = Array.new(@height).map{ Array.new(@width).map{ Array.new(SIZE)} }
    for i in 0..(@height-1) do
      for j in 0..(@width-1) do
        pixel = Array.new(SIZE)
        for x in 0..(pixel.length-1)
          pixel[x] = @data[(i*width+j)*SIZE + x]
        end

        @raster[i][j] = pixel
      end
    end
  end

  # override super to write a ppm file
  def write_to_file(file_name)
    header = "P6 #{@width} #{@height} #{@max_val}"
    File.open(file_name, "wb") do |file|
      file.puts(header)
      @raster.flatten!
      @raster.each_with_index do |byte, index|
        file.print byte.chr
      end
    end
  end

  def to_rle file
    file.puts("R4 #{@width} #{@height}")
    @raster.flatten.each do |byte|
      file.print byte.chr
    end
  end


  def to_ppm file
    file.puts("P6 #{@width} #{@height} #{@max_val}")
    @raster.flatten.each do |byte|
      file.print byte.chr
    end
  end
end
