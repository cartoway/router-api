# Copyright © Cartoroute, 2026
#
# This file is part of Cartoroute.
#
# Cartoroute is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoroute is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoroute. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
require './wrappers/wrapper'

module Wrappers
  class Proxy < Wrapper
    def initialize(cache, hash = {})
      super(cache, hash)
      @wrapper = hash[:wrapper]
      @speed_multiplier = hash[:speed_multiplier] || 1
    end

    def area
      @wrapper.area
    end

    def route_dimension
      @wrapper.route_dimension
    end

    def route?(start, stop, dimension)
      @wrapper.route?(start, stop, dimension)
    end

    def route(locs, dimension, departure, arrival, language, with_geometry, options = {})
      ret = @wrapper.route(locs, dimension, departure, arrival, language, with_geometry, options)
      if @speed_multiplier != 1
        ret[:features].each{ |feature|
          router = feature[:properties][:router]
          router[:total_time] = router[:total_time] * 1.0 / @speed_multiplier if router[:total_time]
        }
      end
      ret
    end

    def matrix_dimension
      @wrapper.matrix_dimension
    end

    def matrix?(src, dst, dimension)
      @wrapper.matrix?(src, dst, dimension)
    end

    def matrix(srcs, dsts, dimension, departure, arrival, language, options = {})
      ret = @wrapper.matrix(srcs, dsts, dimension, departure, arrival, language, options)
      if @speed_multiplier != 1 && ret[:matrix_time]
        ret[:matrix_time] = ret[:matrix_time].collect{ |row|
          row.collect{ |value|
            value && value * 1.0 / @speed_multiplier
          }
        }
      end
      ret
    end

    def isoline_dimension
      @wrapper.isoline_dimension
    end

    def isoline?(loc, dimension)
      @wrapper.isoline?(loc, dimension)
    end

    def isoline(loc, dimension, size, departure, language, options = {})
      size *= @speed_multiplier if dimension == :time && @speed_multiplier != 1
      @wrapper.isoline(loc, dimension, size, departure, language, options)
    end

    # Declare available router options for capability operation
    Wrapper::OPTIONS.each do |s|
      define_method("#{s}?") do
        @wrapper.send("#{s}?")
      end
    end

    def method_missing(method, *args, &block)
      if @wrapper.respond_to?(method)
        @wrapper.public_send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @wrapper.respond_to?(method, include_private) || super
    end
  end
end
