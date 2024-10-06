# Copyright © Cartoroute, 2024
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

require 'rest-client'
require 'json'
require 'polylines'
# RestClient.log = $stdout

module Wrappers
  class GraphHopper < Wrapper
    def initialize(cache, hash = {})
      super(cache, hash)
      @url = hash[:url]
      @key = hash[:key]
      @licence = hash[:licence]
      @attribution = hash[:attribution]

      @profile = hash[:profile] || 'car'
    end

    def speed_multiplier?
      true
    end

    def area?
      true
    end

    def speed_multiplier_area?
      true
    end

    def track?
      true
    end

    def motorway?
      true
    end

    def toll?
      true
    end

    # optional :low_emission_zone, type: Boolean, default: true, desc: 'Go into Low Emission Zone or not.'
    # optional :large_light_vehicle, type: Boolean, default: true, desc: 'Large Light Vehicule.'
    # optional :trailers, type: Integer, desc: 'Number of trailers.'

    def weight?
      true
    end

    # optional :weight_per_axle, type: Float, desc: 'Weight per axle, in tons.'

    def height?
      true
    end

    def width?
      true
    end

    def length?
      true
    end

    # optional :hazardous_goods, type: Symbol, values: [:explosive, :gas, :flammable, :combustible, :organic, :poison, :radio_active, :corrosive, :poisonous_inhalation, :harmful_to_water, :other], desc: 'List of hazardous materials in the vehicle.'

    def approach?
      true
    end

    # optional :strict_restriction, type: Boolean, default: true, desc: 'Strict compliance with truck limitations.'

    def route_dimension
      [:time, :time_distance, :distance, :distance_time]
    end

    def route(locs, dimension, _departure_time, _arrival_time, language, with_geometry, options = {})
      key = [:osrm, :route, Digest::MD5.hexdigest(Marshal.dump([@url, @profile, with_geometry, locs, language]))]

      geojson = options[:format] == 'geojson' || (options[:precision] || 6) != 5
      json = @cache.read(key)
      if !json
        params = graphhopper_params(dimension, language, options)
        params[:snap_prevention] = %w[motorway trunk ferry tunnel bridge ford]
        params[:curbside] = options[:approach] == :curb ? ['right'] * locs.size : nil # Wrong side on left driving countries ?
        params[:points] = locs.collect(&:reverse)
        # details
        params[:instructions] = false
        params[:points_encoded] = !geojson
        params = params.delete_if { |_k, v| v.nil? || v == '' }

        json = post('route', @key, params)
      end

      ret = {
        type: 'FeatureCollection',
        router: {
          licence: @licence,
          attribution: @attribution,
        },
        features: []
      }

      ret[:features] = (json && json['paths'] || []).collect{ |route|
        snapped_waypoints = geojson ?
          route['snapped_waypoints']['coordinates'] :
          Polylines::Decoder.decode_polyline(route['snapped_waypoints'], Math.log10(route['points_encoded_multiplier']).to_i).collect(&:reverse)
        {
          type: 'Feature',
          properties: {
            router: {
              total_distance: route['distance'],
              total_time: (route['time'].to_f / 60 / 60).round,
              start_point: snapped_waypoints[0],
              end_point: snapped_waypoints[-1],
            }
          }
        }
      }

      if with_geometry
        (json && json['paths'] || []).each_with_index{ |route, index|
          ret[:features][index][:geometry] = {
            type: 'LineString',
            coordinates: geojson ? route['points']['coordinates'] : nil,
            polylines: !geojson ? route['points'] : nil,
          }
        }
      end

      ret
    end

    def matrix_dimension
      [:time, :time_distance, :distance, :distance_time]
    end

    def matrix(srcs, dsts, dimension, _departure, _arrival, language, options = {})
      dim1, dim2 = dimension.to_s.split('_').collect(&:to_sym)
      key = [:osrm, :matrix, Digest::MD5.hexdigest(Marshal.dump([@url, @profile, dim1, dim2, srcs, dsts, options]))]

      json = @cache.read(key)
      if !json
        params = graphhopper_params(dimension, language, options)
        params[:snap_preventions] = %w[motorway trunk ferry tunnel bridge ford]
        if srcs == dsts
          # params[:curbside] = options[:approach] == :curb ? ['right'] * srcs.size : nil # Wrong side on left driving countries ?
          params[:points] = srcs.collect(&:reverse)
        else
          # params[:from_curbside] = options[:approach] == :curb ? ['right'] * srcs.size : nil # Wrong side on left driving countries ?
          # params[:to_curbside] = options[:approach] == :curb ? ['right'] * dsts.size : nil # Wrong side on left driving countries ?
          params[:from_points] = srcs.collect(&:reverse)
          params[:to_points] = dsts.collect(&:reverse)
        end
        params[:out_arrays] = [
          dim1 == :time ? 'times' : 'distances',
          if dim2.nil?
            nil
          else
            dim2 == :time ? 'times' : 'distances'
          end
        ].compact
        params[:fail_fast] = false
        params = params.delete_if { |_k, v| v.nil? || v == '' }

        json = post('matrix', @key, params)
      end

      {
        router: {
          licence: @licence,
          attribution: @attribution,
        },
        matrix_time: json['times']&.collect{ |row| row.collect{ |i| i == 10000000.0 ? nil : (i.to_f / 60 / 60).round } },
        matrix_distance: json['distances']&.collect{ |row| row.collect{ |i| i == 10000000.0 ? nil : i.round } },
      }
    end

    def isoline_dimension
      [:time, :distance]
    end

    def isoline(loc, dimension, size, _departure, _language, options = {})
      key = [:osrm, :isoline, Digest::MD5.hexdigest(Marshal.dump([@url, dimension, loc, size, @exclude, options]))]

      json = @cache.read(key)
      if !json
        params = {
          profile: @profile,
          point: loc.join(','),
          time_limit: dimension == :time ? (size * (options[:speed_multiplier] || 1)).round(1) : nil,
          distance_limit: dimension == :distance ? size : nil,
          # buckets:
        }.delete_if { |_k, v| v.nil? || v == '' }

        json = get('isochrone', @key, params)
      end

      ret = {
        type: 'FeatureCollection',
        router: {
          licence: @licence,
          attribution: @attribution,
        },
        features: []
      }

      if json
        ret[:features] = [{
          type: 'Feature',
          geometry: {
            type: 'Polygon',
            coordinates: json.dig('polygons', 0, 'geometry', 'coordinates')
          }
        }]
      end

      ret
    end

    private

    def graphhopper_params(dimension, language, options)
      params = {
        profile: @profile,
        locale: language,
        elevation: false,
        # pass_through: If true, u-turns are avoided at via-points
      }

      params[:custom_model] = {
        speed: [],
      }
      if dimension == :distance
        params[:custom_model][:distance_influence] = 20000
      end
      if ![nil, 1, 1.0].include?(options[:speed_multiplier])
        params[:custom_model][:speed] << { if: 'true', multiply_by: options[:speed_multiplier] }
      end

      if options[:speed_multiplier_area]
        params[:custom_model][:areas] = {
          type: 'FeatureCollection',
          features: options[:speed_multiplier_area].each_with_index.collect{ |area_speed, index|
            area, _speed = area_speed
            {
              type: 'Feature',
              id: "area#{index}",
              geometry: {
                type: 'Polygon',
                coordinates: [area.collect(&:reverse)]
              }
            }
          }
        }

        params[:custom_model][:speed] += options[:speed_multiplier_area].each_with_index.collect{ |area_speed, index|
          _area, speed = area_speed
          { if: "in_area#{index}", multiply_by: speed }
        }
      end

      if options[:track] == false
        params[:custom_model][:speed] << { "if": 'road_class == TRACK', multiply_by: 0 }
      end

      if options[:motorway] == false
        params[:custom_model][:speed] << { "if": 'road_class == MOTORWAY', multiply_by: 0 }
      end

      if options[:toll] == false
        params[:custom_model][:speed] << { "if": 'toll == ALL', multiply_by: 0 }
      end

      if options[:weight]
        params[:custom_model][:speed] << { "if": "max_width < #{options[:weight]}", multiply_by: 0 }
      end

      if options[:height]
        params[:custom_model][:speed] << { "if": "max_height < #{options[:height]}", multiply_by: 0 }
      end

      if options[:width]
        params[:custom_model][:speed] << { "if": "max_width < #{options[:width]}", multiply_by: 0 }
      end

      if options[:length]
        params[:custom_model][:speed] << { "if": "max_length < #{options[:length]}", multiply_by: 0 }
      end

      params[:custom_model] = params[:custom_model].compact_blank
      if !params[:custom_model][:speed].nil?
        params['ch.disable'] = true
      end

      params.compact_blank
    end

    def request(_path, _key)
      request = RestClient::Request.execute(yield) { |response, _request, _result|
        case response.code
        when 200
          response
        when 400
          json = JSON.parse(response)
          case json.dig('hints', 0, 'details')
          when 'com.graphhopper.util.exceptions.PointOutOfBoundsException'
            return nil
          when 'com.graphhopper.util.exceptions.PointNotFoundException'
            raise RouterWrapper::UnreachablePointError.new
          else
            raise json['message'] || json
          end
        else
          begin
            raise JSON.parse(response)['message']
          rescue
            raise response.to_s
          end
        end
      }

      JSON.parse(request)
    end

    def get(path, key, params)
      request(path, key) do
        {
          method: :get,
          url: "#{@url}/#{path}",
          # open_timeout: TIMEOUT_DEFAULT_OPEN,
          # read_timeout: TIMEOUT_DEFAULT,
          headers: { params: params.merge(key: key) },
        }
      end
    end

    def post(path, key, params)
      request(path, key) do
        {
          method: :post,
          url: "#{@url}/#{path}?key=#{key}",
          # open_timeout: TIMEOUT_DEFAULT_OPEN,
          # read_timeout: TIMEOUT_DEFAULT,
          headers: {'Content-Type' => 'application/json'},
          payload: params.to_json,
        }
      end
    end
  end
end
