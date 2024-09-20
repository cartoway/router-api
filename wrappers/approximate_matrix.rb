# Copyright © Cartoway, 2024
# AGPL v3
require 'ai4r'

require './wrappers/wrapper'
require './lib/earth'

# ai4r use Fixnum
Fixnum = Integer

module Wrappers
  class ApproximateMatrix < Wrapper
    def initialize(cache, proxified, max_size, hash = {})
      @proxified = proxified
      @max_size = max_size
      super(cache, hash)
    end

    def method_missing(method_name, *args)
      @proxified.send(method_name, *args)
    end

    def matrix(src, dst, dimension, departure, arrival, language, options = {})
      if src.size <= @max_size && dst.size <= @max_size || src != dst
        return @proxified.matrix(src, dst, dimension, departure, arrival, language, options)
      end

      data_set = Ai4r::Data::DataSet.new(data_items: Array.new(src.size) { |i| [i] })
      c = Ai4r::Clusterers::BisectingKMeans.new
      c.set_parameters(max_iterations: 10)
      c.distance_function = lambda { |a, b|
        a = a[0]
        b = b[0]

        # Math.sqrt((src[a][0] - src[b][0])**2 + (src[a][1] - src[b][1])**2)
        RouterWrapper::Earth.distance_between(src[a][0], src[a][1], src[b][0], src[b][1])
      }

      c.build(data_set, @max_size) # Number of cluster

      clusters_index = c.clusters.each_with_index.flat_map{ |cluster, cluster_index|
        cluster.data_items.collect{ |data_item|
          [data_item[0], cluster_index]
        }
      }.sort

      cluster_centroids = c.clusters.collect{ |cluster|
        cluster.data_items.inject([0, 0]) { |sum, a|
          [
            sum[0] + src[a[0]][0],
            sum[1] + src[a[0]][1],
          ]
        }.collect{ |i| i.to_f / cluster.data_items.size }
      }

      m = @proxified.matrix(cluster_centroids, cluster_centroids, dimension, departure, arrival, language, options)

      matrix_time = m[:matrix_time]
      matrix_distance = m[:matrix_distance]

      m[:router][:attribution] = "Approximated values using #{m[:router][:attribution]}"
      m[:matrix_time] = [] if matrix_time
      m[:matrix_distance] = [] if matrix_distance
      clusters_index.collect{ |src_index, src_cluster_index|
        m[:matrix_time][src_index] = [] if matrix_time
        m[:matrix_distance][src_index] = [] if matrix_distance

        clusters_index.collect{ |dst_index, dst_cluster_index|
          m[:matrix_time][src_index][dst_index] = matrix_time[src_cluster_index][dst_cluster_index] if matrix_time
          m[:matrix_distance][src_index][dst_index] = matrix_distance[src_cluster_index][dst_cluster_index] if matrix_distance
        }
      }
      m
    end
  end
end
