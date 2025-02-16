# Copyright © Mapotempo, 2015-2016
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
require 'active_support'
require 'active_support/core_ext'
require 'byebug'
require 'dotenv'
require 'tmpdir'

require './wrappers/crow'
require './wrappers/osrm'
require './wrappers/otp'
require './wrappers/here8'
require './wrappers/graphhopper'

require './lib/cache_manager'

module RouterWrapper
  Dotenv.load('local.env', 'default.env')
  whitelist_classes = %w[toll motorway track]

  area_mapping = [
    {
      mask: %w[l1 l2],
      mapping: {
        [true, true] => 'urban_dense',
        [true, false] => 'urban',
        [false, false] => 'interurban',
        [false, true] => 'water_body'
      }
    },
    {
      mask: %w[w1 w2 w3],
      mapping: {
        [true, true, true] => 'trunk',
        [true, true, false] => 'primary',
        [true, false, true] => 'secondary',
        [true, false, false] => 'tertiary',
        [false, true, true] => 'residential',
        [false, true, false] => 'minor',
        [false, false, true] => nil,
        [false, false, false] => nil
      }
    }
  ]

  CACHE = CacheManager.new(ActiveSupport::Cache::NullStore.new)
  CROW = Wrappers::Crow.new(CACHE, boundary: 'poly/france-marseille.kml')
  OSRM = Wrappers::Osrm.new(CACHE, url_time: 'http://localhost:5000', url_distance: 'http://localhost:5000', url_isochrone: 'http://localhost:1723', url_isodistance: 'http://localhost:1723', track: true, toll: true, motorway: true, area_mapping: area_mapping, whitelist_classes: whitelist_classes, with_summed_by_area: true, licence: 'ODbL', attribution: '© OpenStreetMap contributors', area: 'Europe', boundary: 'poly/europe.kml')
  OTP_BORDEAUX = Wrappers::Otp.new(CACHE, url: 'http://localhost:7001', router_id: 'bordeaux', licence: 'ODbL', attribution: 'Bordeaux Métropole', area: 'Bordeaux', crs: 'EPSG:2154')
  # Use a cache for HERE event in test to avoid to pay requests
  CACHE_HERE = ActiveSupport::Cache::FileStore.new(File.join(Dir.tmpdir, 'router'), namespace: 'router', expires_in: 60 * 10)
  HERE8_CAR = Wrappers::Here8.new(CACHE_HERE, apikey: ENV['HERE8_APIKEY'], mode: 'car', over_400km: false)
  GRAPHHOPPER = Wrappers::GraphHopper.new(CACHE, url: 'http://localhost:8989', profile: 'car', licence: 'ODbL', attribution: '© OpenStreetMap contributors')

  PARAMS_LIMIT = { locations: 10000 }.freeze
  REDIS_COUNT = Redis.new # Fake redis
  QUOTAS = [{ daily: 10, monthly: 1000000, yearly: 10000000 }].freeze # Only taken into account if REDIS_COUNT

  @@c = {
    product_title: 'Router API',
    access_by_api_key: {
      file: './config/access.rb'
    },
    profiles: {
      light: {
        route_default: :crow,
        params_limit: PARAMS_LIMIT,
        quotas: QUOTAS, # Only taken into account if REDIS_COUNT
        route: {
          crow: [CROW],
        },
        matrix: {
          crow: [CROW],
        },
        isoline: {
          crow: [CROW],
        }
      },
      standard: {
        route_default: :crow,
        params_limit: PARAMS_LIMIT,
        quotas: QUOTAS, # Only taken into account if REDIS_COUNT
        route: {
          crow: [CROW],
          osrm: [OSRM],
          otp: [OTP_BORDEAUX],
          here8: [HERE8_CAR],
          graphhopper: [GRAPHHOPPER],
        },
        matrix: {
          crow: [CROW],
          osrm: [OSRM],
          otp: [OTP_BORDEAUX],
          here8: [HERE8_CAR],
          graphhopper: [GRAPHHOPPER],
        },
        isoline: {
          crow: [CROW],
          osrm: [OSRM],
          otp: [OTP_BORDEAUX],
          here8: [HERE8_CAR],
          graphhopper: [GRAPHHOPPER],
        }
      }
    },
    redis_count: REDIS_COUNT,
  }
end
