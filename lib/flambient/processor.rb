require 'chunky_png'
require 'oily_png'

module Flambient
  class Processor

    attr_reader :tile_size, :image

    def initialize(image, tile_size = 32)
      @image = image
      @tile_size = tile_size
    end

    def process
      # Round the size of the image down to the nearest tile
      width = (image.width / tile_size) * tile_size
      height = (image.height / tile_size) * tile_size
      new_image = ChunkyPNG::Canvas.new(width, height, ChunkyPNG::Color::TRANSPARENT)

      (0...width).step(tile_size) do |x|
        (0...height).step(tile_size) do |y|
          process_tile(new_image, x, y)
        end
      end

      new_image
    end

    private

    def process_tile(new_image, x, y)
      top, left, bottom, right = quad_colours(x, y)

      p_top_left = [x, y]
      p_top_right = [x + tile_size, y]
      p_bottom_left = [x, y + tile_size]
      p_bottom_right = [x + tile_size, y + tile_size]

      # Change the angle of the triangle depending on the closest matching
      # colour.
      if color_distance(top, left) > color_distance(top, right)
        c1 = average_color([top, left])
        c2 = average_color([bottom, right])

        new_image.polygon([p_top_left, p_top_right, p_bottom_left], c1, c1)
        new_image.polygon([p_top_right, p_bottom_left, p_bottom_right], c2, c2)
      else
        c1 = average_color([top, right])
        c2 = average_color([bottom, left])

        new_image.polygon([p_top_left, p_top_right, p_bottom_right], c1, c1)
        new_image.polygon([p_top_left, p_bottom_left, p_bottom_right], c2, c2)
      end
    end

    # Returns the average colours for different portions of the tile.
    def quad_colours(tile_x, tile_y)
      [:top, :left, :bottom, :right].map do |side|
        average_color(triangle_pixels(tile_x, tile_y, side))
      end
    end

    # This is meant to return the pixels for a triangle in a tile, but instead
    # does a simple rectangle, because I couldn't be bothered to think about
    # the maths.
    def triangle_pixels(tile_x, tile_y, side)
      quad_size = tile_size / 2

      case side
      when :top
        p1 = [tile_x, tile_y]
        p2 = [tile_x + tile_size, tile_y + quad_size]
      when :left
        p1 = [tile_x, tile_y]
        p2 = [tile_x + quad_size, tile_y + tile_size]
      when :bottom
        p1 = [tile_x, tile_y + quad_size]
        p2 = [tile_x + tile_size, tile_y + tile_size]
      when :right
        p1 = [tile_x + quad_size, tile_y]
        p2 = [tile_x + tile_size, tile_y + tile_size]
      end

      p1 = ChunkyPNG.Point(p1)
      p2 = ChunkyPNG.Point(p2)

      [].tap do |pixels|
        (p1.x...p2.x).each do |x|
          (p1.y...p2.y).each do |y|
            pixels << image.get_pixel(x, y)
          end
        end
      end
    end

    # Calculates the average colour of an array of pixels
    def average_color(pixels)
      r_avg = 0; g_avg = 0; b_avg = 0
      count = pixels.length

      pixels.each do |pixel|
        r, g, b = ChunkyPNG::Color.to_truecolor_bytes(pixel)
        r_avg += r
        g_avg += g
        b_avg += b
      end

      r_avg = r_avg / count
      g_avg = g_avg / count
      b_avg = b_avg / count

      ChunkyPNG::Color.rgb(r_avg, g_avg, b_avg)
    end
  
    # See http://en.wikipedia.org/wiki/Hue#Computing_hue_from_RGB
    def color_hue(pixel)
      r, g, b = ChunkyPNG::Color.to_truecolor_bytes(pixel)
      return 0 if r == b and b == g 
      ((180 / Math::PI * Math.atan2((2 * r) - g - b, Math.sqrt(3) * (g - b))) - 90) % 360
    end
   
    # The modular distance, as the hue is circular
    def color_distance(pixel, poxel)
      hue_pixel, hue_poxel = color_hue(pixel), color_hue(poxel)
      [(hue_pixel - hue_poxel) % 360, (hue_poxel - hue_pixel) % 360].min
    end
  end
end
