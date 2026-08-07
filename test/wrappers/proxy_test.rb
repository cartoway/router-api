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
require './test/test_helper'
require './wrappers/crow'
require './wrappers/proxy'

class Wrappers::ProxyTest < Minitest::Test
  def test_route
    crow = Wrappers::Crow.new(nil)
    proxy = Wrappers::Proxy.new(nil, wrapper: crow, speed_multiplier: 2)
    crow_result = crow.route([[49.610710, 18.237305], [47.010226, 2.900391]], :time, nil, nil, 'en', true)
    proxy_result = proxy.route([[49.610710, 18.237305], [47.010226, 2.900391]], :time, nil, nil, 'en', true)
    assert_equal crow_result[:features][0][:properties][:router][:total_distance], proxy_result[:features][0][:properties][:router][:total_distance]
    assert_equal crow_result[:features][0][:properties][:router][:total_time] / 2, proxy_result[:features][0][:properties][:router][:total_time]
  end

  def test_matrix
    crow = Wrappers::Crow.new(nil)
    proxy = Wrappers::Proxy.new(nil, wrapper: crow, speed_multiplier: 2)
    crow_result = crow.matrix([[49.610710, 18.237305]], [[47.010226, 2.900391]], :time, nil, nil, 'en')
    proxy_result = proxy.matrix([[49.610710, 18.237305]], [[47.010226, 2.900391]], :time, nil, nil, 'en')
    assert_equal crow_result[:matrix_time][0][0] / 2, proxy_result[:matrix_time][0][0]
  end

  def test_isoline
    crow = Wrappers::Crow.new(nil)
    proxy = Wrappers::Proxy.new(nil, wrapper: crow, speed_multiplier: 2)
    result = proxy.isoline([49.610710, 18.237305], :time, 2, nil, 'en')
    assert !result[:features].empty?
    assert !result[:features][0][:geometry].empty?
  end

  def test_capability
    crow = Wrappers::Crow.new(nil)
    proxy = Wrappers::Proxy.new(nil, wrapper: crow, speed_multiplier: 2)
    assert_equal crow.route_dimension, proxy.route_dimension
    assert_equal crow.matrix_dimension, proxy.matrix_dimension
    assert_equal crow.isoline_dimension, proxy.isoline_dimension
    assert_equal crow.speed_multiplier?, proxy.speed_multiplier?
  end

  def test_passthrough_with_speed_multiplier_of1
    crow = Wrappers::Crow.new(nil)
    proxy = Wrappers::Proxy.new(nil, wrapper: crow)
    crow_result = crow.route([[49.610710, 18.237305], [47.010226, 2.900391]], :time, nil, nil, 'en', true)
    proxy_result = proxy.route([[49.610710, 18.237305], [47.010226, 2.900391]], :time, nil, nil, 'en', true)
    assert_equal crow_result[:features][0][:properties][:router][:total_time], proxy_result[:features][0][:properties][:router][:total_time]
  end
end
