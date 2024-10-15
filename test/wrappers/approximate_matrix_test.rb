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
require './test/wrappers/approximate_matrix_test_data'

class Wrappers::ApproximateMatrixTest < Minitest::Test
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

  def compute_error(m1, m2)
    errors = m1.each_with_index.collect { |row, i|
      row.each_with_index.collect { |v, j|
        (v.nil? || v == 0 || m2[i][j].nil? ? 0 : ((v - m2[i][j]) / v).abs) if i != j
      }
    }.flatten.compact

    sum = errors.sum
    mean = sum / errors.size
    s = errors.sum { |e| (e - mean)**2 }
    variance = s / (errors.size - 1)
    std_dev = Math.sqrt(variance)

    [mean, std_dev]
  end

  def test_benchmark_cluster_size
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

    router = RouterWrapper::CROW
    starting = Time.now
    router_result = router.matrix(SUPERMARKET_URBAN_89, SUPERMARKET_URBAN_89, :time, nil, nil, 'en', {motorway: true, toll: true})
    time_router = Time.now - starting
    puts "Full matrix computation duration: #{time_router}"

    stats = clusterers.to_h{ |clusterer|
      puts clusterer
      clusterer_stats = sizes.collect { |max_size|
        approx = Wrappers::ApproximateMatrix.new(RouterWrapper::CACHE, router, clusterer, max_size) # Max matrix size is 2

        starting = Time.now
        approx_result = approx.matrix(SUPERMARKET_URBAN_89, SUPERMARKET_URBAN_89, :time, nil, nil, 'en', {motorway: true, toll: true})
        time_approx = Time.now - starting

        compute_error(router_result[:matrix_time], approx_result[:matrix_time]) + [time_approx]
      }.flatten
      a = clusterer_stats.each_slice(3).to_a.transpose
      [clusterer, a]
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
    puts 'comput duration'
    puts (['clusterer'] + sizes).join(',') + "\n"
    clusterers.each{ |clusterer|
      puts ([clusterer] + stats[clusterer][2]).join(',') + "\n"
    }
  end

  def test_benchmark_points_number
    sizes = [10, 50, 100, 500, 1000, 3500]
    clusterers = [
      Ai4r::Clusterers::AverageLinkage,
      # Ai4r::Clusterers::BisectingKMeans, # Too slow
      Ai4r::Clusterers::CentroidLinkage,
      Ai4r::Clusterers::CompleteLinkage,
      # Ai4r::Clusterers::Diana, # Too slow
      Ai4r::Clusterers::KMeans,
      Ai4r::Clusterers::MedianLinkage,
      Ai4r::Clusterers::SingleLinkage,
      Ai4r::Clusterers::WardLinkage,
      Ai4r::Clusterers::WardLinkageHierarchical,
      Ai4r::Clusterers::WeightedAverageLinkage
    ]

    router = RouterWrapper::GRAPHHOPPER
    router_results = sizes.to_h { |size|
      starting = Time.now
      router_result = router.matrix(SHOPS_MIX_3576[..size], SHOPS_MIX_3576[..size], :time, nil, nil, 'en', {motorway: true, toll: true})
      time_router = Time.now - starting
      puts "Full matrix computation duration for size #{size}: #{time_router}"
      [size, router_result]
    }

    stats = clusterers.to_h{ |clusterer|
      puts clusterer
      clusterer_stats = sizes.collect { |size|
        approx = Wrappers::ApproximateMatrix.new(RouterWrapper::CACHE, router, clusterer, size / 4) # Cluster size 50 %
        starting = Time.now
        approx_result = approx.matrix(SHOPS_MIX_3576[..size], SHOPS_MIX_3576[..size], :time, nil, nil, 'en', {motorway: true, toll: true})
        time_approx = Time.now - starting

        compute_error(router_results[size][:matrix_time], approx_result[:matrix_time]) + [time_approx]
      }.flatten
      a = clusterer_stats.each_slice(3).to_a.transpose
      [clusterer, a]
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
    puts 'comput duration'
    puts (['clusterer'] + sizes).join(',') + "\n"
    clusterers.each{ |clusterer|
      puts ([clusterer] + stats[clusterer][2]).join(',') + "\n"
    }
  end
end
