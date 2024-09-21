# Copyright © Mapotempo, 2015
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
require './wrappers/crow'

class Wrappers::CrowTest < Minitest::Test
  def test_proxy_method_route
    crow = RouterWrapper::CROW
    approx = RouterWrapper::APPROXIMATE_MATRIX_CROW

    crow_result = crow.route([[49.610710, 18.237305], [47.010226, 2.900391]], :time, nil, nil, 'en', true, {motorway: true, toll: true})
    approx_result = approx.route([[49.610710, 18.237305], [47.010226, 2.900391]], :time, nil, nil, 'en', true, {motorway: true, toll: true})

    assert_equal crow_result, approx_result
  end

  def test_without_approx_matrix
    crow = RouterWrapper::CROW
    approx = RouterWrapper::APPROXIMATE_MATRIX_CROW

    ps = [[49.610710, 18.237305], [47.010226, 2.900391]]
    crow_result = crow.matrix(ps, ps, :time, nil, nil, 'en', {motorway: true, toll: true})
    crow_result[:router].delete(:attribution)
    approx_result = approx.matrix(ps, ps, :time, nil, nil, 'en', {motorway: true, toll: true})
    approx_result[:router].delete(:attribution)

    assert_equal crow_result, approx_result
  end

  def test_approx_matrix
    crow = RouterWrapper::CROW
    approx = RouterWrapper::APPROXIMATE_MATRIX_CROW # Max matrix size is 2

    ps = [[49.610710, 18.237305], [47.010226, 2.900391], [49.7559, 18.9768]]
    crow_result = crow.matrix(ps, ps, :time, nil, nil, 'en', {motorway: true, toll: true})
    crow_result[:router].delete(:attribution)
    approx_result = approx.matrix(ps, ps, :time, nil, nil, 'en', {motorway: true, toll: true})
    approx_result[:router].delete(:attribution)

    # Points 2 and 3 merged
    d = approx_result[:matrix_time][0][2]
    crow_result[:matrix_time][1][2] = d
    crow_result[:matrix_time][2][1] = d

    assert_equal crow_result, approx_result
  end
end
