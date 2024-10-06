# Copyright © Mapotempo, 2016
# Copyright © Cartoroute, 2024
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
require './test/test_helper'

require './wrappers/graphhopper'

class Wrappers::GraphHopperTest < Minitest::Test
  def test_router
    gh = RouterWrapper::GRAPHHOPPER
    result = gh.route([[64.146447, -21.872459], [64.135515, -21.918807]], :time, nil, nil, 'en', true)
    assert 0 < result[:features].size
  end

  def test_router_no_route
    gh = RouterWrapper::GRAPHHOPPER
    assert_raises RouterWrapper::UnreachablePointError do
      result = gh.route([[63.940992, -21.627960], [64.1373477, -21.8590164]], :time, nil, nil, 'en', true)
    end
  end

  def test_matrix_square
    gh = RouterWrapper::GRAPHHOPPER
    vector = [[64.146447, -21.872459], [64.135515, -21.918807]]
    result = gh.matrix(vector, vector, :time, nil, nil, 'en')
    assert_equal vector.size, result[:matrix_time].size
    assert_equal vector.size, result[:matrix_time][0].size
  end

  def test_matrix_square_with_area_options
    gh = RouterWrapper::GRAPHHOPPER
    vector = [[64.0512, -21.996], [64.0596, -21.5456]]
    area = [[63.9729, -21.9191], [64.1555, -21.6211], [64.2106, -22.0372]]
    result = {
      true => gh.matrix(vector, vector, :time, nil, nil, 'en'),
      false => gh.matrix(vector, vector, :time, nil, nil, 'en', area: [area], speed_multiplier_area: [0]),
    }
    assert result[true][:matrix_time][0][1] < result[false][:matrix_time][0][1]
    assert result[true][:matrix_time][1][0] < result[false][:matrix_time][1][0]
  end

  def test_matrix_rectangular_time
    gh = RouterWrapper::GRAPHHOPPER
    src = [[64.146447, -21.872459], [64.135515, -21.918807]]
    dst = [[64.146447, -21.872459]]
    result = gh.matrix(src, dst, :time, nil, nil, 'en')
    assert_equal src.size, result[:matrix_time].size
    assert_equal dst.size, result[:matrix_time][0].size
  end

  def test_matrix_1x1
    gh = RouterWrapper::GRAPHHOPPER
    src = [[64.146447, -21.872459]]
    dst = [[64.146447, -21.872459]]
    result = gh.matrix(src, dst, :time_distance, nil, nil, 'en')
    assert_equal src.size, result[:matrix_time].size
    assert_equal dst.size, result[:matrix_time][0].size
    assert_equal src.size, result[:matrix_distance].size
    assert_equal dst.size, result[:matrix_distance][0].size
  end

  def test_matrix_rectangular_time_distance
    gh = RouterWrapper::GRAPHHOPPER
    src = [[64.146447, -21.872459], [64.135515, -21.918807]]
    dst = [[64.146447, -21.872459]]
    result = gh.matrix(src, dst, :time_distance, nil, nil, 'en')
    assert_equal src.size, result[:matrix_time].size
    assert_equal src.size, result[:matrix_distance].size
    assert_equal dst.size, result[:matrix_time][0].size
    assert_equal dst.size, result[:matrix_distance][0].size
  end

  def test_isoline
    gh = RouterWrapper::GRAPHHOPPER
    result = gh.isoline([64.146447, -21.872459], :time, 100, nil, 'en')
    assert 0 < result[:features].size
  end

  def test_geom_geojson
    gh = RouterWrapper::GRAPHHOPPER
    result = gh.route([[64.146447, -21.872459], [64.135515, -21.918807]], :time, nil, nil, 'en', true, format: 'geojson')
    assert result[:features][0][:geometry][:coordinates]
    assert !result[:features][0][:geometry][:polylines]
  end

  def test_geom_polylines
    gh = RouterWrapper::GRAPHHOPPER
    result = gh.route([[64.146447, -21.872459], [64.135515, -21.918807]], :time, nil, nil, 'en', true, format: 'polyline', precision: 5)
    assert !result[:features][0][:geometry][:coordinates]
    assert result[:features][0][:geometry][:polylines]

    result = gh.route([[64.146447, -21.872459], [64.135515, -21.918807]], :time, nil, nil, 'en', true, format: 'polyline', precision: 6)
    assert result[:features][0][:geometry][:coordinates]
    assert !result[:features][0][:geometry][:polylines]
  end

  def test_large_matrix_split
    gh = RouterWrapper::GRAPHHOPPER
    # 101 points inside south-west(50.0,1.0) and north-east(51.0,2.0)
    vector = (0..100).collect{ |i| [50 + Float(i) / 100, 1 + Float(i) / 100] }
    result = gh.matrix(vector, vector, :time_distance, nil, nil, 'en', strict_restriction: true)
    assert_equal vector.size, result[:matrix_time]&.size
    assert_equal vector.size, result[:matrix_time][0].size
    assert_equal vector.size, result[:matrix_distance]&.size
    assert_equal vector.size, result[:matrix_distance][0].size
  end
end
