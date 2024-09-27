# Copyright © Cartoway, 2024
# AGPL v3
require 'ai4r'

require './wrappers/wrapper'
require './lib/earth'

# ai4r use Fixnum
Fixnum = Integer

module Wrappers
  class ApproximateMatrix < Wrapper
    def initialize(cache, proxified, clusterer, max_size, hash = {})
      @proxified = proxified
      @clusterer = clusterer
      @max_size = max_size
      super(cache, hash)

      @crow = Wrappers::Crow.new(nil)
    end

    def method_missing(method_name, *args)
      @proxified.send(method_name, *args)
    end

    def matrix(src, dst, dimension, departure, arrival, language, options = {})
      if src.size <= @max_size && dst.size <= @max_size || src != dst
        return @proxified.matrix(src, dst, dimension, departure, arrival, language, options)
      end

      data_set = Ai4r::Data::DataSet.new(data_items: Array.new(src.size) { |i| [i] })
      c = @clusterer.new
      c.set_parameters(max_iterations: 1)
      c.distance_function = lambda { |a, b|
        a = a[0]
        b = b[0]

        # Math.sqrt((src[a][0] - src[b][0])**2 + (src[a][1] - src[b][1])**2)
        RouterWrapper::Earth.distance_between(src[a][1], src[a][0], src[b][1], src[b][0])
      }

      c.build(data_set, @max_size) # Number of cluster

      clusters_index = c.clusters.each_with_index.flat_map{ |cluster, cluster_index|
        cluster.data_items.each_with_index.collect{ |data_item, index_in_cluster|
          [data_item[0], cluster_index, index_in_cluster]
        }
      }.sort

      cluster_centroids = c.clusters.collect{ |cluster|
        centroid = cluster.data_items.inject([0, 0]) { |sum, a|
          [
            sum[0] + src[a[0]][0],
            sum[1] + src[a[0]][1],
          ]
        }.collect{ |i| i.to_f / cluster.data_items.size }

        # Return the closest point to the centroid
        min_index = cluster.data_items.min_by{ |data_item|
          RouterWrapper::Earth.distance_between(src[data_item[0]][1], src[data_item[0]][0], centroid[1], centroid[0])
        }
        src[min_index[0]]
      }

      m = @proxified.matrix(cluster_centroids, cluster_centroids, dimension, departure, arrival, language, options)

      crow_matrix = @crow.matrix(cluster_centroids, cluster_centroids, dimension, departure, arrival, language, options)
      if m[:matrix_time]
        coef_matrix_time = cluster_centroids.size.times.collect{ |i|
        cluster_centroids.size.times.collect{ |j|
            crow_matrix[:matrix_time][i][j] == 0 ? 0.0 : m[:matrix_time][i][j] / crow_matrix[:matrix_time][i][j]
          }
        }
      end
      if m[:matrix_distance]
        coef_matrix_distance = cluster_centroids.size.times.collect{ |i|
        cluster_centroids.size.times.collect{ |j|
            crow_matrix[:matrix_distance][i][j] == 0 ? 0.0 : m[:matrix_distance][i][j] / crow_matrix[:matrix_distance][i][j]
          }
        }
      end

      cluster_matrices = c.clusters.collect{ |cluster|
        cluster_points = cluster.data_items.collect{ |data_item|
          src[data_item[0]]
        }

        @proxified.matrix(cluster_points, cluster_points, dimension, departure, arrival, language, options)
      }

      matrix_time = m[:matrix_time]
      matrix_distance = m[:matrix_distance]

      m[:router][:attribution] = "Approximated values using #{m[:router][:attribution]}"
      m[:matrix_time] = [] if matrix_time
      m[:matrix_distance] = [] if matrix_distance
      clusters_index.collect{ |src_index, src_cluster_index, src_index_in_cluster|
        m[:matrix_time][src_index] = [] if matrix_time
        m[:matrix_distance][src_index] = [] if matrix_distance

        clusters_index.collect{ |dst_index, dst_cluster_index, dst_index_in_cluster|
          if src_cluster_index == dst_cluster_index
            # Same cluster, use exact values
            m[:matrix_time][src_index][dst_index] = cluster_matrices[src_cluster_index][:matrix_time][src_index_in_cluster][dst_index_in_cluster] if matrix_time
            m[:matrix_distance][src_index][dst_index] = cluster_matrices[src_cluster_index][:matrix_distance][src_index_in_cluster][dst_index_in_cluster] if matrix_distance
          else
            # Approximate values
            m[:matrix_time][src_index][dst_index] = crow_matrix[:matrix_time][src_cluster_index][dst_cluster_index] * coef_matrix_time[src_cluster_index][dst_cluster_index] if matrix_time
            m[:matrix_distance][src_index][dst_index] = crow_matrix[:matrix_time][src_cluster_index][dst_cluster_index] * coef_matrix_distance[src_cluster_index][dst_cluster_index] if matrix_distance
          end
        }
      }
      m
    end
  end
end
