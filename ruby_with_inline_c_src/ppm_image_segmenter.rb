class PPMImageSegmenter < ImageSegmenter
  DEFAULT_PPM_BACKGROUND = [255, 255,255]
  DEFAULT_PPM_FOREGROUND = [0, 0, 0]

  # parameter image is optional, if an image is passed in, it gets used
  # otherwise it will take the one in this class
  # def segment
  #   build_tree(@image)
  #   visit_k_means(@tree.root, @image, [0, 0, 0], [255,255,255])
  #   construct_files(@tree.root, @image)
  # end

  def process
    visit_k_means(@tree.root, @image, [0, 0, 0], [255,255,255])
  end

  def default_foreground; DEFAULT_PPM_FOREGROUND; end
  def default_background; DEFAULT_PPM_BACKGROUND; end


  # parameter image is optional, if an image is passed in, it gets used
  # otherwise it will take the one in this class
  def recompute_prototypes node, image, fore_ground, back_ground
    foreground_sum =[0,0,0]
    background_sum = [0,0,0]
    background_counter = foreground_counter = 0
    raise "image must not be null" unless image
    mask = node.mask

    for i in (0..node.height-1)
      for j in (0..node.width-1)
        flag = mask[i][j]
        if flag == 0 #foreground
          foreground_sum = array_add_c(foreground_sum, image.raster[node.offset_x+i][node.offset_y+j])
          #foreground_sum.component_add(image.raster[node.offset_x+i][node.offset_y+j])
          foreground_counter = foreground_counter + 1
        else
#          background_sum.component_add(image.raster[node.offset_x+i][node.offset_y+j])
          background_sum = array_add_c(background_sum, image.raster[node.offset_x+i][node.offset_y+j])
          background_counter = background_counter + 1
        end
      end
    end
    foreground_counter = (foreground_counter == 0) ? 1 : foreground_counter
    background_counter = (background_counter == 0) ? 1 : background_counter
    return [foreground_sum.divide_by_scalar(foreground_counter), background_sum.divide_by_scalar(background_counter)]
  end

  def construct_files(root, image)
    fg_image = PPMImage.deep_copy(image)
    bg_image = PPMImage.deep_copy(image)
    mask_image = Image.deep_copy(image)
    result_image = PPMImage.deep_copy(image)

    #raster[node.offset_x+i][node.offset_y+j]
    root.visit(root, :inorder) do |node|
      unless node.left || node.right
        for i in (0..node.height-1)
          for j in (0..node.width-1)
            fg_image.raster[node.offset_x+i][node.offset_y+j] = if node.mask[i][j] == 0
                                                                  node.fg
                                                                else
                                                                  DEFAULT_PPM_FOREGROUND
                                                                end

            bg_image.raster[node.offset_x+i][node.offset_y+j] = if node.mask[i][j] == 1
                                                                  node.bg
                                                                else
                                                                  DEFAULT_PPM_BACKGROUND
                                                                end
            result_image.raster[node.offset_x+i][node.offset_y+j] = node.bg if node.mask[i][j] == 1
            result_image.raster[node.offset_x+i][node.offset_y+j] = node.fg if node.mask[i][j] == 0
            raise "problem" unless node.mask[i][j]
            mask_image.raster[node.offset_x+i][node.offset_y+j] = node.mask[i][j]
          end
        end
      end
    end

    [fg_image, bg_image, mask_image, result_image]
  end

end
