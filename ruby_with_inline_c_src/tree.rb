class Tree
  attr_accessor :root
end

class Node
  # binary tree representation
  attr_accessor :parent, :left, :right, :ran_kmean

  # the node maintains its own mask, foreground, background
  attr_accessor :mask, :fg, :bg

  # the coordinate that we need to access the image
  # obvious these should have been a different class, but that is quite expensive
  # considering that we will have so many of these nodes. So it is put here
  # purely for performance sake
  attr_accessor :offset, :dimension

  def initialize(offset =[], dimension = [], left=nil, right=nil)
    @offset, @dimension, @left, @right = offset, dimension, left, right
    @ran_kmean = false
  end

  # lazy initialization of mask
  def mask
    @mask ||= Array.new(dimension[1]).map{Array.new(dimension[0], 0) }
  end

  def width; dimension[0]; end
  def height; dimension[1]; end
  def offset_x; offset[0]; end
  def offset_y; offset[1]; end

  def visit(n, order=:preorder, &block)
    # visit nodes in a binary tree, order can be determinied
    # block performs visit action
    return false unless (n != nil)

    case order
    when :preorder

#      yield n.offset[0], n.offset[1], n.dimension[0], n.dimension[1]
      yield n
      visit(n.left, order, &block)
      visit(n.right, order, &block)
    when :inorder
      visit(n.left, order, &block)
      yield n
#      yield n.offset[0], n.offset[1], n.dimension[0], n.dimension[1]
      visit(n.right, order, &block)
    when :postorder
      visit(n.left, order, &block)
      visit(n.right, order, &block)
#      yield n.offset[0], n.offset[1], n.dimension[0], n.dimension[1]
      yield n
    end
  end

  def insert(node, v, &block)
    # binary tree insert without balancing,
    # block performs the comparison operation
    return Node.new(v) if not node
    case block[v, node.value]
        when -1
            node.left = insert(node.left, v, &block)
        when 1
            node.right = insert(node.right, v, &block)
    end
    return node
  end

  def get_info
    yield offset[0], offset[1], dimension[0], dimension[1]
  end

end


