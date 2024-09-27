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
    clusterer = Ai4r::Clusterers::SingleLinkage
    approx = Wrappers::ApproximateMatrix.new(RouterWrapper::CACHE, crow, clusterer, 2) # Max matrix size is 2

    ps = [[49.610710, 18.237305], [47.010226, 2.900391]]
    crow_result = crow.matrix(ps, ps, :time, nil, nil, 'en', {motorway: true, toll: true})
    crow_result[:router].delete(:attribution)
    approx_result = approx.matrix(ps, ps, :time, nil, nil, 'en', {motorway: true, toll: true})
    approx_result[:router].delete(:attribution)

    assert_equal crow_result, approx_result
  end

  def test_small_approx_matrix
    crow = RouterWrapper::CROW
    clusterer = Ai4r::Clusterers::SingleLinkage
    approx = Wrappers::ApproximateMatrix.new(RouterWrapper::CACHE, crow, clusterer, 2) # Max matrix size is 2

    ps = [[49.610710, 18.237305], [47.010226, 2.900391], [49.7559, 18.9768]]
    crow_result = crow.matrix(ps, ps, :time, nil, nil, 'en', {motorway: true, toll: true})
    crow_result[:router].delete(:attribution)
    approx_result = approx.matrix(ps, ps, :time, nil, nil, 'en', {motorway: true, toll: true})
    approx_result[:router].delete(:attribution)

    puts compute_error(crow_result[:matrix_time], approx_result[:matrix_time])

    # # Points 2 and 3 merged
    d = approx_result[:matrix_time][0][2]
    crow_result[:matrix_time][1][2] = d
    crow_result[:matrix_time][2][1] = d

    assert_equal crow_result, approx_result
  end

  SHOPS_URBAN = [
    # lat, lon
    [28.095722, -15.457344],
    [28.143829, -15.431295],
    [28.137481, -15.43631],
    [28.136789, -15.431255],
    [28.130365, -15.444167],
    [28.141957, -15.433686],
    [28.139768, -15.435664],
    [28.13589, -15.438862],
    [28.140008, -15.434508],
    [28.089352, -15.416771],
    [28.114597, -15.424854],
    [28.117272, -15.425356],
    [28.114972, -15.421719],
    [28.11412, -15.429916],
    [28.109441, -15.431449],
    [28.126227, -15.437905],
    [28.100631, -15.442868],
    [28.097144, -15.417862],
    [28.136963, -15.434514],
    [28.137676, -15.433557],
    [28.142148, -15.432407],
    [28.142206, -15.427245],
    [28.090858, -15.415842],
    [28.116302, -15.42612],
    [28.104487, -15.417849],
    [28.105364, -15.41525],
    [28.104738, -15.413957],
    [28.139325, -15.434246],
    [28.105707, -15.419796],
    [28.109406, -15.42099],
    [28.112355, -15.421828],
    [28.110831, -15.42248],
    [28.110627, -15.418643],
    [28.103725, -15.45398],
    [28.115605, -15.421607],
    [28.115426, -15.42145],
    [28.115509, -15.420988],
    [28.115993, -15.421418],
    [28.132476, -15.440557],
    [28.139381, -15.435631],
    [28.11364, -15.447231],
    [28.132552, -15.431473],
    [28.097271, -15.44706],
    [28.129618, -15.432552],
    [28.131314, -15.442007],
    [28.130902, -15.439735],
    [28.14129, -15.43433],
    [28.140433, -15.431832],
    [28.135683, -15.434294],
    [28.136807, -15.431647],
    [28.133174, -15.43386],
    [28.133009, -15.432576],
    [28.132074, -15.433999],
    [28.129454, -15.432399],
    [28.104926, -15.414362],
    [28.133565, -15.436421],
    [28.133966, -15.436301],
    [28.096156, -15.414185],
    [28.102835, -15.435243],
    [28.135746, -15.430142],
    [28.132713, -15.438886],
    [28.132705, -15.439164],
    [28.108717, -15.418186],
    [28.12831, -15.442854],
    [28.100894, -15.419223],
    [28.113258, -15.44947],
    [28.100937, -15.473477],
    [28.094404, -15.473972],
    [28.100606, -15.473616],
    [28.127681, -15.448752],
    [28.111638, -15.43949],
    [28.111333, -15.418489],
    [28.126781, -15.425146],
    [28.103838, -15.418764],
    [28.113313, -15.429172],
    [28.114024, -15.420593],
    [28.118595, -15.422841],
    [28.106533, -15.415477],
    [28.095178, -15.448178],
    [28.114405, -15.445842],
    [28.118548, -15.445504],
    [28.093283, -15.4621],
    [28.099252, -15.443139],
    [28.106493, -15.43982],
    [28.106029, -15.453907],
    [28.101525, -15.447517],
    [28.105114, -15.431814],
    [28.096492, -15.442372],
    [28.099746, -15.442018],
  ]

  def compute_error(m1, m2)
    errors = m1.each_with_index.collect { |row, i|
      row.each_with_index.collect { |v, j|
        (v == 0 ? 0 : ((v - m2[i][j]) / v).abs) if i != j
      }
    }.flatten.compact

    sum = errors.sum
    mean = sum / errors.size
    s = errors.sum { |e| (e - mean)**2 }
    variance = s / (errors.size - 1)
    std_dev = Math.sqrt(variance)

    [mean, std_dev]
  end

  def test_benchmark_approx_matrix
    sizes = [10, 20, 30, 40, 50, 60, 70, 80, 89]
    clusterers = [
      Ai4r::Clusterers::AverageLinkage,
      # Ai4r::Clusterers::BisectingKMeans, # Too slow
      Ai4r::Clusterers::CentroidLinkage,
      Ai4r::Clusterers::CompleteLinkage,
      Ai4r::Clusterers::Diana,
      Ai4r::Clusterers::KMeans,
      Ai4r::Clusterers::MedianLinkage,
      Ai4r::Clusterers::SingleLinkage,
      Ai4r::Clusterers::WardLinkage,
      Ai4r::Clusterers::WardLinkageHierarchical,
      Ai4r::Clusterers::WeightedAverageLinkage
    ]
    stats = clusterers.to_h{ |clusterer|
      puts clusterer
      clusterer_stats = sizes.collect { |max_size|
        router = RouterWrapper::CROW
        approx = Wrappers::ApproximateMatrix.new(RouterWrapper::CACHE, router, clusterer, max_size) # Max matrix size is 2

        router_result = router.matrix(SHOPS_URBAN, SHOPS_URBAN, :time, nil, nil, 'en', {motorway: true, toll: true})
        router_result[:router].delete(:attribution)
        approx_result = approx.matrix(SHOPS_URBAN, SHOPS_URBAN, :time, nil, nil, 'en', {motorway: true, toll: true})
        approx_result[:router].delete(:attribution)

        compute_error(router_result[:matrix_time], approx_result[:matrix_time])
      }.flatten
      a = clusterer_stats.each_slice(2).to_a.transpose
      [clusterer, [a[0], a[1]]]
    }
    puts 'error %, mean'
    puts (['clusterer'] + sizes).join(',') + "\n"
    clusterers.each{ |clusterer|
      puts ([clusterer] + stats[clusterer][0]).join(',') + "\n"
    }
    puts 'error %, std_dev'
    puts (['clusterer'] + sizes).join(',') + "\n"
    clusterers.each{ |clusterer|
      puts ([clusterer] + stats[clusterer][1]).join(',') + "\n"
    }
  end
end
