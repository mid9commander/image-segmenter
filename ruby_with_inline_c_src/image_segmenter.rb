require 'ruby_extension'
require 'image'
require 'tempfile'
require 'rubygems'
require 'inline'


class ImageSegmenter
  DEFAULT_BACKGROUND = 255
  DEFAULT_FOREGROUND = 0
  attr_accessor :image, :tree, :input_file_name, :input_file_type

  def initialize(file_name)
    @input_file_name, @input_file_type = file_name.split('.').first, file_name.split('.').last

    if file_name =~ /.ppm/
      from_ppm(File.read(file_name))
    elsif file_name =~ /.pgm/
      from_pgm(File.read(file_name))
    end
  end


  # Instantiates an Image given raw PPM data.
  #
  # PPM takes 3 bytes to represent 1 pixel, so our smaller unit of measure here
  # is an array of 3 bytes, as opposed to 1 byte
  def from_ppm(io)
    @image ||= PPMImage.new
    @image.data = io.gsub(/^(P6)\s([0-9]+)\s([0-9]+)\s([0-9]+)\s|^(P6)\n#.+\s{1,10}([0-9]+)\s([0-9]+)\s([0-9]+)/, '')
    if $1 != 'P6'
      @image.data = io.gsub(/^(P5)\n#.+\s{1,10}([0-9]+)\s([0-9]+)\s([0-9]+)/, '')
      if $1 != 'P6'
        raise ArgumentError, "input must be a PPM file"
      end
    end

    @image.width, @image.height, @image.max_val = $2.to_i, $3.to_i, $4.to_i
    if @image.max_val != 255
      raise ArgumentError, "We only handle 1 byte PPM for now"
    end

    @image.build
  end


  # Instantiates an Image given raw PGM data.
  #
  # PGM is a NetPBM format, encoding width, height, and greyscale data, one byte
  # per pixel. It is therefore ideally suited for loading into ZBar, which
  # operates natively on Y800 pixel data--identical to the data section of a PGM
  # file.
  #
  # The data is described in greater detail at
  # http://netpbm.sourceforge.net/doc/pgm.html.
  def from_pgm(io)
    @image ||= Image.new
    @image.data = io.gsub(/^(P5)\s([0-9]+)\s([0-9]+)\s([0-9]+)\s|^(P5)\n#.+\s{1,10}([0-9]+)\s([0-9]+)\s([0-9]+)/, '')
    if $1 != 'P5'
      @image.data = io.gsub(/^(P5)\n#.+\s{1,10}([0-9]+)\s([0-9]+)\s([0-9]+)/, '')
      if $1 != 'P5'
        raise ArgumentError, "input must be a PGM file"
      end
    end

    @image.width, @image.height, @image.max_val = $2.to_i, $3.to_i, $4.to_i
    if @image.max_val != 255
      raise ArgumentError, "maximum value must be 255"
    end

    @image.build
  end

  # parameter image is optional, if an image is passed in, it gets used
  # otherwise it will take the one in this class
  def segment
    pre_process
    process
    post_process
  end

  def process
    visit_k_means(@tree.root, @image, 0, 255)
  end

  def pre_process
    build_tree(@image)
  end

  def post_process
    fg_image, bg_image, mask_image, result_image = construct_files(@tree.root, @image)

#    sep_file = make_sep_file(fg_image, bg_image, mask_image)


    File.delete("#{input_file_name}-fg.#{input_file_type}") if File.exist?("#{input_file_name}-fg.#{input_file_type}")
    File.delete("#{input_file_name}-bg.#{input_file_type}") if File.exist?("#{input_file_name}-bg.#{input_file_type}")
    File.delete("#{input_file_name}-mask.pgm") if File.exist?("#{input_file_name}-mask.pgm")
    File.delete("#{input_file_name}-reconstruction.#{input_file_type}") if File.exist?("#{input_file_name}-reconstruction.#{input_file_type}")

    fg_image.write_to_file("#{input_file_name}-fg.#{input_file_type}")
    puts "#{input_file_name}-fg.#{input_file_type} has been created"

    bg_image.write_to_file("#{input_file_name}-bg.#{input_file_type}")
    puts "#{input_file_name}-bg.#{input_file_type} has been created"

    mask_image.write_to_file("#{input_file_name}-mask.pgm")
    puts "#{input_file_name}-mask.pgm has been created"

    result_image.write_to_file("#{input_file_name}-reconstruction.#{input_file_type}")
    puts "#{input_file_name}-reconstruction.#{input_file_type} has been created"


 #   puts "sep file created at #{sep_file.path}"
  end

  def make_sep_file(fg_image, bg_image, mask_image)
    fg_path = bg_path = nil
    Tempfile.open('temp.ppm') do |file|
      bg_image.to_ppm(file)
      bg_path = file.path
    end
    fg = Tempfile.open('temp.rle') do |file|
      fg_image.to_rle(file)
      fg_path = file.path
    end

    a = File.open("temp.sep", "wb") do |file|
      system("cat #{fg_path} #{bg_path} > #{file.path}")
      file
    end
    a
  end


  def build_tree(image)
    @tree = Tree.new
    @tree.root = Node.new([0,0], [image.width, image.height])

    tree_recursive(@tree.root)
  end

  def test_k_mean(node, image, fg, bg)
    node.ran_kmean = true
    mask = node.mask
    return [0,0,0], [255, 255,255]
  end

  inline(:C) do |builder|
    builder.add_compile_flags '-x c++', '-lstdc++'
    builder.include '<algorithm>'
    builder.include '<vector>'
    builder.include '<cmath>'

    builder.c '
      // component wise subtraction followed by a sum operation
      int distance_for_array(VALUE a, VALUE b){
        VALUE *this_array = RARRAY(a)->ptr;
        VALUE *that_array = RARRAY(b)->ptr;
        long int distance = 0;

        long int size = RARRAY(a)->len;
        long int i;
        for (i=0; i<size; i++){
          long int x = rb_num2long(*this_array);
          long int y = rb_num2long(*that_array);
          long int diff = x -y;
          distance += fabs(diff);
        }
        return distance;
      }'

    builder.c '
      int sum_c(int a, int b){
        return (a + b);
      }
     '

    builder.c '
      // disance between 2 integers
      int distance(int a, int b){
        return fabs((a-b));
      }
     '

    builder.c '
      static VALUE array_add_c(VALUE ary1, VALUE ary2){
        VALUE ary3 = rb_ary_new();
        VALUE *this_array = RARRAY(ary1)->ptr;
        VALUE *that_array = RARRAY(ary2)->ptr;

        long i;
        for (i=0; i<RARRAY(ary1)->len; i++){
          long int x = NUM2LONG(*this_array);
          long int y = NUM2LONG(*that_array);
          long int z = x + y;
          rb_ary_push(ary3, LONG2NUM(z));
          this_array ++;
          that_array ++;
        }
        return ary3;
      }'

    end


  def k_mean(node, image, fg, bg)
    converged = false
    mask = node.mask
    iter = 0
    while !converged
      converged = true
      width, height = node.width, node.height
      for i in (0..node.height-1)
        for j in (0..node.width-1)
          distance_fg = 0
          distance_bg = 0
          image.pixel_at(node.offset_x+i, node.offset_y+j) do |pixel|
            #TODO move the calculation of distance of a pixel into a method so that it is easier to read
            if pixel.class == Array #image that use more than 1 byte to represent a pixel

              distance_fg = distance_for_array(pixel, fg)
              distance_bg = distance_for_array(pixel, bg)
            else
              if pixel.class == Fixnum
                distance_fg = distance(pixel, fg)
                distance_bg = distance(pixel, bg)
              end
            end

            # puts "distance to fg = #{distance_fg}"
            # puts "distance to bg = #{distance_bg}"

            if distance_fg > distance_bg
              if(mask[i][j] != 0x01)
                mask[i][j] = 0x01 and converged = false
              end
            else
              if(mask[i][j] != 0x00)
                mask[i][j] = 0x00 and converged = false
              end
            end
          end
        end
      end

      if !converged
        fg, bg = recompute_prototypes(node, image, fg, bg)
      end
      iter = iter + 1

    end # end of while

    # puts 'converged'
    # puts "foreground = #{fg}"
    # puts "background = #{bg}"
    node.ran_kmean = true
    [fg, bg]
  end


  # parameter image is optional, if an image is passed in, it gets used
  # otherwise it will take the one in this class
  def recompute_prototypes node, image, fore_ground, back_ground
    foreground_sum = background_sum = background_counter = foreground_counter = 0
    raise "image must not be null" unless image

    mask = node.mask

    for i in (0..node.height-1)
      for j in (0..node.width-1)
        byte = mask[i][j]
        if byte == 0 #foreground
          foreground_sum = sum_c(foreground_sum, image.raster[node.offset_x+i][node.offset_y+j])
          foreground_counter = sum_c(foreground_counter, 1)
        else
          background_sum = sum_c(background_sum, image.raster[node.offset_x+i][node.offset_y+j])
          background_counter = sum_c(background_counter,1)
        end
      end
    end
    foreground_counter = (foreground_counter == 0) ? 1 : foreground_counter
    background_counter = (background_counter == 0) ? 1 : background_counter
    return (foreground_sum/foreground_counter), (background_sum/background_counter)
  end

  # ok, we made a non-trivial assumption that impacts the performance
  # we build a binary tree, which turns out to be big waste in terms resource
  # and it makes the program quite slow, since it has to do a lot more k-means computation
  # but all is not lost, we just need to -not- compute k-means for some of the intermediate
  # nodes and just pass down the foreground, background value from its parent to its children
  def visit_k_means(node, image, fg=0, bg=255)
    if node.left.nil? || node.right.nil?  # run k-mean if this is one the leaf regardless
      new_fg, new_bg = k_mean(node, image, fg, bg)
    else
      if (node.parent && node.parent.ran_kmean)
        new_fg, new_bg = node.parent.fg, node.parent.bg
      else
        if ((node.parent && node.parent.parent) && node.parent.parent.ran_kmean)
          new_fg, new_bg = node.parent.fg, node.parent.bg
        else
          if ((node.parent && node.parent.parent && node.parent.parent.parent) && node.parent.parent.parent.ran_kmean)
            new_fg, new_bg = node.parent.fg, node.parent.bg
          else
            new_fg, new_bg = k_mean(node, image, fg, bg)
          end
        end
      end
    end

    node.fg = new_fg
    node.bg = new_bg
    visit_k_means(node.left, image, new_fg, new_bg) if node.left
    visit_k_means(node.right, image, new_fg, new_bg) if node.right
  end


  # offset, dimension are contained in parent
  def tree_recursive(parent)
    threshold ||= 2 * 12 # 8x8 by default

    parent.get_info do |offset_x, offset_y, width, height|
      if (width >= threshold || height >= threshold)
        child_1 = nil
        child_2 = nil
        if (height >= threshold) # cut horizontally
          child_1 = Node.new(parent.offset.clone, [width, height/2])
          child_2 = Node.new([(parent.offset[0] + height/2),parent.offset[1]], [width, height - height/2])
        else
          child_1 = Node.new(parent.offset.clone, [width/2, height])
          child_2 = Node.new([parent.offset[0], (parent.offset[1] + width/2)], [width - width/2, height])
        end
        parent.left = child_1
        parent.right = child_2
        child_1.parent = child_2.parent = parent

        tree_recursive(child_1)
        tree_recursive(child_2)
      end
    end
  end

  def default_foreground; DEFAULT_FOREGROUND; end
  def default_background; DEFAULT_BACKGROUND; end


  def construct_files(root, image)
    fg_image = Image.deep_copy(image)
    bg_image = Image.deep_copy(image)
    mask_image = Image.deep_copy(image)
    result_image = Image.deep_copy(image)

    #raster[node.offset_x+i][node.offset_y+j]
    root.visit(root, :inorder) do |node|
      unless node.left || node.right
        for i in (0..node.height-1)
          for j in (0..node.width-1)
            fg_image.raster[node.offset_x+i][node.offset_y+j] = if node.mask[i][j] == 0
                                                                  node.fg
                                                                else
                                                                  default_foreground
                                                                end

            bg_image.raster[node.offset_x+i][node.offset_y+j] = if node.mask[i][j] == 1
                                                                  node.bg
                                                                else
                                                                  default_background
                                                                end
            result_image.raster[node.offset_x+i][node.offset_y+j] = node.bg if node.mask[i][j] == 1
            result_image.raster[node.offset_x+i][node.offset_y+j] = node.fg if node.mask[i][j] == 0
            mask_image.raster[node.offset_x+i][node.offset_y+j] = node.mask[i][j]
          end
        end
      end
    end
    [fg_image, bg_image, mask_image, result_image]
  end

end
