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
  ActiveSupport::Cache.lookup_store :redis_store
  CACHE = CacheManager.new(ActiveSupport::Cache::RedisStore.new(host: ENV['REDIS_HOST'] || 'localhost', namespace: 'router', expires_in: 60 * 60 * 24 * 1, raise_errors: true))

  CROW = Wrappers::Crow.new(CACHE)
  OSRM = Wrappers::Osrm.new(CACHE, url_time: 'http://router.project-osrm.org', url_distance: 'http://router.project-osrm.org', url_isochrone: 'http://localhost:1723', url_isodistance: 'http://localhost:1723', licence: 'ODbL', attribution: '© OpenStreetMap contributors')
  OSRM_CAR_ICELAND = Wrappers::Osrm.new(CACHE, url_time: 'http://osrm-car-iceland:5000', url_distance: nil, url_isochrone: 'http://osrm-car-iceland:6000', url_isodistance: nil, licence: 'ODbL', attribution: '© OpenStreetMap contributors')
  OTP_BORDEAUX = Wrappers::Otp.new(CACHE, url: 'http://otp:7001', router_id: 'bordeaux', licence: 'ODbL', attribution: 'Bordeaux Métropole', area: 'Bordeaux', crs: 'EPSG:2154')
  HERE8_CAR = Wrappers::Here8.new(CACHE, apikey: ENV['HERE8_APIKEY'], mode: 'car', over_400km: false)
  GRAPHHOPPER = Wrappers::GraphHopper.new(CACHE, url: 'http://gh-car-iceland:8989', profile: 'car', licence: 'ODbL', attribution: '© OpenStreetMap contributors')

  PARAMS_LIMIT = { locations: 1000 }.freeze
  REDIS_COUNT = ENV['REDIS_COUNT_HOST'] && Redis.new(host: ENV['REDIS_COUNT_HOST'])
  QUOTAS = [{ daily: 100000, monthly: 1000000 }].freeze # Only taken into account if REDIS_COUNT

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
        route_default: :osrm,
        params_limit: PARAMS_LIMIT,
        quotas: QUOTAS, # Only taken into account if REDIS_COUNT
        route: {
          osrm: [OSRM_CAR_ICELAND, OSRM],
          otp: [OTP_BORDEAUX],
          here8: [HERE8_CAR],
        },
        matrix: {
          osrm: [OSRM_CAR_ICELAND, OSRM],
          otp: [OTP_BORDEAUX],
          here8: [HERE8_CAR],
        },
        isoline: {
          osrm: [OSRM_CAR_ICELAND, OSRM],
          otp: [OTP_BORDEAUX],
          here8: [HERE8_CAR],
        }
      }
    },
    redis_count: REDIS_COUNT,
  }
end
