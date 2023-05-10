# Copyright © Mapotempo, 2015
# Copyright © Frédéric Rodrigo, 2023
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
require './wrappers/wrapper'
require './lib/flexible_polyline'

module Wrappers
  class Here8 < Wrapper

    def initialize(cache, hash = {})
      super(cache, hash)
      @url_router = 'https://router.hereapi.com'
      @url_matrix = 'https://matrix.router.hereapi.com'
      @url_isoline = 'https://isoline.route.api.here.com/routing'
      @url_tce = 'https://tce.api.here.com'
      @apikey = hash[:apikey]
      @mode = hash[:mode]
    end

    # Declare available router options for capability operation
    # Here api supports most of options... remove unsupported options below
    (OPTIONS - [:speed_multiplier_area, :max_walk_distance, :approach, :snap, :with_summed_by_area]).each do |s|
      define_method("#{s}?") do
        ![:trailers, :weight, :weight_per_axle, :height, :width, :length, :hazardous_goods, :strict_restriction].include?(s) || @mode == 'truck'
      end
    end

    # def toll_costs(link_ids, departure_time, options = {})
    #   # https://developer.here.com/platform-extensions/documentation/toll-cost/topics/example-tollcost.html
    #   params = {
    #     # https://developer.here.com/platform-extensions/documentation/toll-cost/topics/resource-tollcost-input-param-vspec.html
    #     tollVehicleType: 3,
    #     trailerType: options[:trailers] ? 2 : nil,
    #     'vehicle[trailerCount]': options[:trailers],
    #     vehicleNumberAxles: 2, # Not including trailer axles
    #     trailerNumberAxles: options[:trailers] ? 2 * options[:trailers] : nil,
    #     # hybrid:
    #     emissionType: 6,
    #     'vehicle[height]': options[:height] ? options[:height] * 100 : nil,
    #     trailerHeight: options[:trailers] ? "#{options[:height] || 3}m" : nil,
    #     vehicleWeight: options[:weight] ? "#{options[:weight]}t" : nil,
    #     'vehicle[grossWeight]': options[:weight] ? options[:weight] * 1000 : nil,
    #     # disabledEquipped:
    #     passengersCount: 1,
    #     # tiresCount: 8, # Default 4
    #     # commercial:
    #     'vehicle[shippedHazardousGoods]': [here_hazardous_map[options[:hazardous_goods]] == :explosive ? 1 : here_hazardous_map[options[:hazardous_goods]] ? 2 : nil].compact,
    #     # heightAbove1stAxle:
    #     # departureTime:
    #     # If departure_time is given, then each route detail is a comma separated struct of link id,seconds left to destination. Otherwise, each route detail is only a link id.
    #     route: link_ids.join(';'), # FIXME add seconds if departure_time
    #     detail: 1,
    #     rollup: 'total,tollsys,country', # none(per_links),total,tollsys(toll_system_summary),country(per_contries),country;tollsys(per_contries_and_toll_sys)
    #     currency: options[:currency],
    #   }.delete_if{ |k, v| v.nil? }
    #   response = get(@url_tce, '2/tollcost', params)

    #   if response && response['totalCost']
    #     response['totalCost']['amountInTargetCurrency']
    #   end
    # end

    def route_dimension
      [:time, :time_distance, :distance, :distance_time]
    end

    def route(locs, dimension, departure_time, arrival_time, lang, with_geometry, options = {})
      # Cache defined inside private get method
      params = {
        routingMode: here_routing_mode(dimension.to_s.split('_').collect(&:to_sym)),
        transportMode: @mode,
        'avoid[features]': here_avoid_features(options).join(','),
        departureTime: !departure_time.nil? ? departure_time : options[:traffic] ? nil : 'any', # At HERE, traffic is default, `any` to disable traffic
        arrivalTime: arrival_time,
        'avoid[areas]': here_avoid_areas(options[:speed_multiplier_area]),
        alternatives: 0,
        lang: lang,
        'vehicle[type]': @mode == 'truck' ? 'straightTruck' : nil,
        'vehicle[trailerCount]': options[:trailers], # Truck routing only, number of trailers.
        'vehicle[grossWeight]': options[:weight] ? options[:weight] * 1000 : nil, # Truck routing only, vehicle weight including trailers and shipped goods, in kg.
        'vehicle[weightPerAxle]': options[:weight_per_axle] ? options[:weight_per_axle] * 1000 : nil, # Truck routing only, vehicle weight per axle in kg.
        'vehicle[height]': options[:height] ? options[:height] * 100 : nil, # Truck routing only, vehicle height in centimeters.
        'vehicle[width]': options[:width] ? options[:width] * 100 : nil, # Truck routing only, vehicle width in centimeters.
        'vehicle[length]': options[:length] ? options[:length] * 100 : nil, # Truck routing only, vehicle length in centimeters.
        'vehicle[shippedHazardousGoods]': [here_hazardous_map[options[:hazardous_goods]]].compact, # Truck routing only, list of hazardous materials.
        #tunnelCategory : # Specifies the tunnel category to restrict certain route links. The route will pass only through tunnels of a les
        return: ['summary', with_geometry ? 'polyline': nil].compact.join(',')
        # options[:toll_costs]
      }.delete_if { |k, v| v.nil? }
      params["origin"] = "#{locs[0][0]},#{locs[0][1]}"
      locs.each_with_index.to_a[1..-2].each{ |loc, index|
        raise 'Via point Not implemented'
        # TODO Support via parameter, requires multiple `via` paramters, not supported by RestClient
        params["via"] = "#{loc[0]},#{loc[1]}"
      }
      params["destination"] = "#{locs[-1][0]},#{locs[-1][1]}"

      request = get(@url_router, 'v8/routes', params)

      ret = {
        type: 'FeatureCollection',
        router: {
          licence: 'HERE',
          attribution: 'HERE'
        },
        features: []
      }

      if request && request['routes'] && request['routes'][0] && request['routes'][0]['sections'] && request['routes'][0]['sections'][0]
        r = request['routes'][0]['sections'][0]
        s = r['summary']
        infos = {
          total_distance: s['length'],
          total_time: (s['duration'] * 1.0 / (options[:speed_multiplier] || 1)).round(1),
          start_point: [r['departure']['place']['location']['lng'], r['departure']['place']['location']['lat']],
          end_point: [r['arrival']['place']['location']['lng'], r['arrival']['place']['location']['lat']],
        }
        if options[:toll_costs]
          raise 'toll_costs Not implemented'
          # TODO
          # infos[:total_toll_costs] = toll_costs(r['leg'].flat_map{ |l|
          #   l['link'].map{ |ll| ll['linkId'] }
          # }.compact, departure_time, options)
        end

        ret[:features] = [{
          type: 'Feature',
          properties: {
            router: infos
          }
        }]

        if with_geometry
          decode = FlexiblePolyline::Decoder.decode(r['polyline'])
          ret[:features][0][:geometry] = {
            type: 'LineString',
            coordinates: decode[:positions].collect{ |point| point.reverse },
          } if decode[:positions]
        end
      end

      ret
    end

    def matrix_dimension
      [:time, :time_distance, :distance, :distance_time]
    end

    def matrix(srcs, dsts, dimension, departure_time, arrival_time, lang, options = {})
      srcs = srcs.collect{ |r| [r[0].round(5), r[1].round(5)] }
      dsts = dsts.collect{ |c| [c[0].round(5), c[1].round(5)] }

      dim = dimension.to_s.split('_').collect(&:to_sym)

      # In addition of cache defined inside private get method
      key = Digest::MD5.hexdigest(Marshal.dump([srcs, dsts, dimension, departure_time, arrival_time, lang, options.except(:speed_multiplier)]))
      result = @cache.read(key)
      if !result

        # From Here "Matrix Routing API Developer's Guide" V7
        # Recommendations for Splitting Matrixes
        # The best way to split a matrix request is to split it into parts with only few start positions and many
        # destinations. The number of the start positions should be between 3 and 15, depending on the size
        # of the area covered by the matrix. The matrices should be split into requests sufficiently small to
        # ensure a response time of 60 seconds each. The number of the destinations in one request is limited
        # to 100.

        # Request should not contain more than 15 starts per request / 100 combinaisons

        lats = (srcs + dsts).minmax_by{ |p| p[0] }
        lons = (srcs + dsts).minmax_by{ |p| p[1] }
        dist_km = RouterWrapper::Earth.distance_between(lons[1][1], lats[1][0], lons[0][1], lats[0][0]) / 1000.0
        dsts_split = dsts_max = [100, dsts.size].min
        srcs_split = max_srcs(dist_km)

        params = {
          regionDefinition: { type: 'world' },
          routingMode: here_routing_mode(dimension.to_s.split('_').collect(&:to_sym)),
          transportMode: @mode,
          departureTime: !departure_time.nil? ? departure_time : options[:traffic] ? nil : 'any', # At HERE, traffic is default, `any` to disable traffic
          avoid: {
            features: here_avoid_features(options),
            areas: here_avoid_areas(options[:speed_multiplier_area]),
          }.select { |_, value| !value.nil? },
          matrixAttributes: dim.collect{ |d| d == :time ? 'travelTimes' : d == :distance ? 'distances' : nil }.compact,
          vehicle: {
            type: @mode == 'truck' ? 'straightTruck' : nil,
            trailerCount: options[:trailers], # Truck routing only, number of trailers.
            grossWeight: options[:weight] ? options[:weight] * 1000 : nil, # Truck routing only, vehicle weight including trailers and shipped goods, in kg.
            weightPerAxle: options[:weight_per_axle] ? options[:weight_per_axle] * 1000 : nil, # Truck routing only, vehicle weight per axle in kg.
            height: options[:height] ? options[:height] * 100 : nil, # Truck routing only, vehicle height in centimeters.
            width: options[:width] ? options[:width] * 100 : nil, # Truck routing only, vehicle width in centimeters.
            length: options[:length] ? options[:length] * 100 : nil, # Truck routing only, vehicle length in centimeters.
            shippedHazardousGoods: [here_hazardous_map[options[:hazardous_goods]]].compact, # Truck routing only, list of hazardous materials.
          }.select { |_, value| !value.nil? },
        }

        result = split_matrix(srcs_split, dsts_split, dsts_max, srcs, dsts, params, options[:strict_restriction])

        @cache.write(key, result)
      end

      ret = {
        router: {
          licence: 'HERE',
          attribution: 'HERE',
        },
        matrix_time: result[:time].collect { |r|
          r.collect { |rr|
            rr ? (rr / (options[:speed_multiplier] || 1)).round : nil
          }
        }
      }

      ret[:matrix_distance] = result[:distance] if dim.include?(:distance)

      ret
    end

    # def isoline_dimension
    #   [:time, :distance]
    # end

    # def isoline(loc, dimension, size, departure_time, _lang, options = {})
    #   # Cache defined inside private get method
    #   params = {
    #     start: "#{loc[0]},#{loc[1]}",
    #     range: dimension == :time ? (size * (options[:speed_multiplier] || 1)).round : size,
    #     rangeType: dimension,
    #     routingMode: here_routing_mode(dimension.to_s.split('_').collect(&:to_sym)),
    #     transportMode: @mode,
    #     'avoid[features]': here_avoid_features(options).join(','),
    #     departureTime: departure_time,
    #     # arrivalTime: arrival_time,
    #     # 'avoid[areas]': here_avoid_areas(options[:speed_multiplier_area]),
    #     # quality: 2,
    #     'vehicle[type]': @mode == 'truck' ? 'straightTruck' : nil,
    #     'vehicle[trailerCount]': options[:trailers], # Truck routing only, number of trailers.
    #     'vehicle[grossWeight]': options[:weight] ? options[:weight] * 1000 : nil, # Truck routing only, vehicle weight including trailers and shipped goods, in kg.
    #     'vehicle[weightPerAxle]': options[:weight_per_axle] ? options[:weight_per_axle] * 1000 : nil, # Truck routing only, vehicle weight per axle in kg.
    #     'vehicle[height]': options[:height] ? options[:height] * 100 : nil, # Truck routing only, vehicle height in centimeters.
    #     'vehicle[width]': options[:width] ? options[:width] * 100 : nil, # Truck routing only, vehicle width in centimeters.
    #     'vehicle[length]': options[:length] ? options[:length] * 100 : nil, # Truck routing only, vehicle length in centimeters.
    #     'vehicle[shippedHazardousGoods]': [here_hazardous_map[options[:hazardous_goods]]].compact, # Truck routing only, list of hazardous materials.
    #     #tunnelCategory : # Specifies the tunnel category to restrict certain route links. The route will pass only through tunnels of a les
    #   }.delete_if { |k, v| v.nil? }

    #   request = get(@url_isoline, '7.2/calculateisoline', params)

    #   ret = {
    #     type: 'FeatureCollection',
    #     router: {
    #       licence: 'HERE',
    #       attribution: 'HERE'
    #     },
    #     features: []
    #   }

    #   if request && request['response'] && request['response']['isoline']
    #     isoline = request['response']['isoline'][0]
    #     ret[:features] = isoline['component'].map{ |component|
    #       {
    #         type: 'Feature',
    #         properties: {},
    #         geometry: {
    #           type: 'Polygon',
    #           coordinates: [component['shape'].map{ |s|
    #             s.split(',').map(&:to_f).reverse
    #           }]
    #         }
    #       }
    #     }
    #     ret
    #   end
    # end

    private

    def here_routing_mode(dimension)
      dimension[0] == :time ? 'fast' : 'short'
    end

    def here_avoid_features(options)
      [
        !options[:motorway] ? 'controlledAccessHighway' : nil,
        !options[:toll] ? 'tollRoad' : nil,
      ].compact
    end

    def here_avoid_areas(areas)
      areas.select{ |k, v|
        # Keep only avoid area
        v == 0
      }.collect{ |area, _v|
        area.pop if area[0] == area[-1]
        area
      }.select{ |area|
        area.size > 2
      }.collect{ |area|
        'polygon:' + area.collect{ |point|
          point.join(',')
        }.join(';')
      }.join('|') if !areas.nil? && areas.size > 0
    end

    def http(url, params = {})
      key = [:here, :request, Digest::MD5.hexdigest(Marshal.dump([url, params.to_a.sort_by{ |i| i[0].to_s }]))]
      request = @cache.read(key)

      unless request
        begin
          response = yield
          request = JSON.parse(response)
          if request['notices'] && !request['notices'].empty?
            request['notices'].select{ |notice|
              # TODO implement support of non `strict_restriction`.
              # Skip some `critical` to make it non strict
              # No notice to skip found in the doc.
              notice['severity'] == 'critical'
            }.collect{ |notice|
              if notice['code'] == 'couldNotMatchOrigin' || notice['code'] == 'couldNotMatchDestination'
                raise UnreachablePointError
              # elsif notice['code'] == 'noRouteFound'
              #   raise RouterWrapper::NoRouteFound
              end
            }.collect{ |notice|
              # Still here ? So there is no route.
              return
            }
          end

        rescue RestClient::Exception => e
          error = JSON.parse(e.response)
          Api::Root.logger.info [url, params]
          Api::Root.logger.info error.inspect
          if error['code'] == 'E605001' # Malformed request
            raise RouterWrapper::InvalidArgumentError.new(error), ['Here', error['code'], error['title'], error['cause'], error['action']].compact.join(', ')
          end
          raise ['Here', error['code'], error['title'], error['cause'], error['action']].compact.join(', ') if error['code']
          raise ['Here', error['error'], error['error_description']].compact.join(', ')
        end

        @cache.write(key, request)
      end

      request
    end

    def get(url_base, object, params = {})
      url = "#{url_base}/#{object}"
      http(url, params) {
        params = {apikey: @apikey}.merge(params).delete_if{ |_k, v| v.blank? }
        RestClient.get(url, params: params)
      }
    end

    def post(url_base, object, params = {})
      url = "#{url_base}/#{object}"
      http(url, params) {
        params = params.delete_if{ |_k, v| v.blank? }
        RestClient.post(url + "?apiKey=#{@apikey}&async=false", params.to_json, content_type: :json, accept: :json)
      }
    end

    def split_matrix(srcs_split, dsts_split, dsts_max, srcs, dsts, params, strict_restriction)
      result = {
        time: Array.new(srcs.size) { Array.new(dsts.size) },
        distance: Array.new(srcs.size) { Array.new(dsts.size) }
      }

      srcs_start = 0
      while srcs_start < srcs.size do
        srcs_end = [srcs_start + srcs_split - 1, srcs.size - 1].min
        origins = srcs_start.upto(srcs_end).collect{ |i|
          {lat: srcs[i][0], lng: srcs[i][1] }
        }
        dsts_start = 0
        dsts_split = [dsts_split * 2, dsts_max].min
        while dsts_start < dsts.size do
          dsts_end = [dsts_start + dsts_split - 1, dsts.size - 1].min
          destinations = dsts_start.upto(dsts_end).collect{ |i|
            {lat: dsts[i][0], lng: dsts[i][1] }
          }
          request = post(@url_matrix, 'v8/matrix', params.dup.merge({origins: origins, destinations: destinations}))

          if request['matrix'] && request['matrix'].key?('travelTimes') || request['matrix'].key?('distances')
            s = request['matrix']
            if s['errorCodes']
              s['errorCodes'].each_with_index{ |v, i|
                if v != 0 && (v != 3 || strict_restriction) # 0 (success) or 3 (violated options)
                  if s.key?('travelTimes')
                    s['travelTimes'][i] = nil
                  end
                  if s.key?('distances')
                    s['distances'][i] = nil
                  end
                end
              }
            end

            srcs_start.upto(srcs_end).each { |i|
              dsts_start.upto(dsts_end).each { |j|
                if s.key?('travelTimes')
                  result[:time][i][j] = s['travelTimes'][(i - srcs_start) * destinations.size + (j - dsts_start)]
                end
                if s.key?('distances')
                  result[:distance][i][j] = s['travelTimes'][(i - srcs_start) * destinations.size + (j - dsts_start)]
                end
              }
            }
          else
            request = nil
          end

          # in some cases, matrix cannot be computed (cancelled) or is incomplete => try to decrease matrix size
          if !request && dsts_split > 2
            dsts_start = [dsts_start - dsts_split, 0].max
            dsts_split = (dsts_split / 2).ceil
          else
            dsts_start += dsts_split
          end
        end

        srcs_start += srcs_split
      end

      result
    end

    def here_hazardous_map
      {
        explosive: :explosive,
        gas: :gas,
        flammable: :flammable,
        combustible: :combustible,
        organic: :organic,
        poison: :poison,
        radio_active: :radioactive,
        corrosive: :corrosive,
        poisonous_inhalation: :poisonousInhalation,
        harmful_to_water: :harmfulToWater,
        other: :other
      }
    end

    ##
    # < 1000km: 15, 1500km: 10, 2000km : 5
    def max_srcs(dist_km)
      if dist_km <= 1_000
        15
      else
        [25 - (dist_km / 100).floor, 1].max
      end
    end
  end
end
