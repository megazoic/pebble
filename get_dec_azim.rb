require 'Date'
require 'sinatra'
require 'sinatra/json'
require 'json'
require 'net/http'


=begin
  Formulas in row 3:
  D3 -> =[.$B$7]
  E3 -> =[.E2]+0.1/24
  F3 -> =[.D3]+2415018.5+[.E3]-[.$B$5]/24
  G3 -> =([.F3]-2451545)/36525
  K3 -> =0.016708634-[.G3]*(0.000042037+0.0000001267*[.G3])
  L3 -> =SIN(RADIANS([.J3]))*(1.914602-[.G3]*(0.004817+0.000014*[.G3]))+SIN(RADIANS(2*[.J3]))*(0.019993-0.000101*[.G3])+SIN(RADIANS(3*[.J3]))*0.000289
  M3 -> =[.I3]+[.L3]
  N3 -> =[.J3]+[.L3]
  O3 -> =(1.000001018*(1-[.K3]*[.K3]))/(1+[.K3]*COS(RADIANS([.N3])))
  P3 -> =[.M3]-0.00569-0.00478*SIN(RADIANS(125.04-1934.136*[.G3]))
  Q3 -> =23+(26+((21.448-[.G3]*(46.815+[.G3]*(0.00059-[.G3]*0.001813))))/60)/60
  R3 -> =[.Q3]+0.00256*COS(RADIANS(125.04-1934.136*[.G3]))
  S3 -> =DEGREES(ATAN2(COS(RADIANS([.P3]));COS(RADIANS([.R3]))*SIN(RADIANS([.P3]))))
  T3 -> =DEGREES(ASIN(SIN(RADIANS([.R3]))*SIN(RADIANS([.P3]))))
  U3 -> =TAN(RADIANS([.R3]/2))*TAN(RADIANS([.R3]/2))
  V3 -> =4*DEGREES([.U3]*SIN(2*RADIANS([.I3]))-2*[.K3]*SIN(RADIANS([.J3]))+4*[.K3]*[.U3]*SIN(RADIANS([.J3]))*COS(2*RADIANS([.I3]))-0.5*[.U3]*[.U3]*SIN(4*RADIANS([.I3]))-1.25*[.K3]*[.K3]*SIN(2*RADIANS([.J3])))
  W3 -> =DEGREES(ACOS(COS(RADIANS(90.833))/(COS(RADIANS([.$B$3]))*COS(RADIANS([.T3])))-TAN(RADIANS([.$B$3]))*TAN(RADIANS([.T3]))))
  X3 -> =(720-4*[.$B$4]-[.V3]+[.$B$5]*60)/1440
  Y3 -> =[.X3]-[.W3]*4/1440
  Z3 -> =[.X3]+[.W3]*4/1440
  AA3 -> =8*[.W3]
  AB3 -> =MOD([.E3]*1440+[.V3]+4*[.$B$4]-60*[.$B$5];1440)
  AC3 -> =IF([.AB3]/4<0;[.AB3]/4+180;[.AB3]/4-180)
  AD3 -> =DEGREES(ACOS(SIN(RADIANS([.$B$3]))*SIN(RADIANS([.T3]))+COS(RADIANS([.$B$3]))*COS(RADIANS([.T3]))*COS(RADIANS([.AC3]))))
  AE3 -> =90-[.AD3]
  AF3 -> =IF([.AE3]>85;0;IF([.AE3]>5;58.1/TAN(RADIANS([.AE3]))-0.07/POWER(TAN(RADIANS([.AE3]));3)+0.000086/POWER(TAN(RADIANS([.AE3]));5);IF([.AE3]>-0.575;1735+[.AE3]*(-518.2+[.AE3]*(103.4+[.AE3]*(-12.79+[.AE3]*0.711)));-20.772/TAN(RADIANS([.AE3])))))/3600
  AG3 -> =[.AE3]+[.AF3]
  AH3 -> =IF([.AC3]>0;MOD(DEGREES(ACOS(((SIN(RADIANS([.$B$3]))*COS(RADIANS([.AD3])))-SIN(RADIANS([.T3])))/(COS(RADIANS([.$B$3]))*SIN(RADIANS([.AD3])))))+180;360);MOD(540-DEGREES(ACOS(((SIN(RADIANS([.$B$3]))*COS(RADIANS([.AD3])))-SIN(RADIANS([.T3])))/(COS(RADIANS([.$B$3]))*SIN(RADIANS([.AD3])))));360))

  longitude = 0.0 #$B$4
  latitude = 0.0 #$B$3
  timezone = 0 #$B$5
  target_time = Time.now
  julian_day = 0.0 #F3
  julian_cent = 0.0 #G3
  long_sun = 0.0 #I3
  anom_sun = 0.0 #J3
  eccent_earth_orbit = 0.0 #K3
  sun_eq_of_center = 0.0 #L3
  sun_true_long = 0.0 #M3
  sun_true_anom = 0.0 #N3
  sun_radian_vector = 0.0 #O3
  apparent_sun_long = 0.0 #P3
  mean_obliq_ecliptic = 0.0 #Q3
  obliq_corr = 0.0 #R3
  sun_rt_ascension = 0.0 #S3
  declination_sun = 0.0 #T3
  var_y = 0.0 #U3
  eq_of_time = 0.0 #V3
  hour_angle_sunrise = 0.0 #W3
  solar_noon = 0.0 #X3
  sunrise_time = 0.0 #Y3
  sunset_time = 0.0 #Z3
  sunlight_duration = 0.0 #AA3
  true_solar_time = 0.0 #AB3
  hour_angle = 0.0 #AC3
  solar_zenith_angle = 0.0 #AD3
  solar_elevation_angle = 0.0 #AE3
  atmospheric_refraction = 0.0 #AF3
  declination = 0 #AG3
  azimuth = 0 #AH3
=end
get '/' do
  'Solar Position Calculation Service'
end
get '/sun_posit' do
  latitude = params['lat'].to_f
  longitude = params['long'].to_f
  user = params['user'] || 'demo'
  tz_data = {}
  tz_data = get_geo_names_timezone(latitude, longitude, user)
  puts "Timezone Data Retrieved: #{tz_data}"
  timezone = 0
  if tz_data.key?('dstOffset')
    timezone = tz_data['dstOffset'].to_i
    puts "Using DST Offset for Timezone: #{timezone}"
  end
  if tz_data.key?('lat')
    latitude = tz_data['lat'].to_f
    puts "Using Latitude from GeoNames: #{latitude}"
  end
  if tz_data.key?('lng')
    longitude = tz_data['lng'].to_f
    puts "Using Longitude from GeoNames: #{longitude}"
  end
  if tz_data.key?('time')
    target_time = Time.parse(tz_data['time'])
    puts "Using Local Time from GeoNames: #{target_time}"
  end
  calculate_solar_position(latitude, longitude, timezone, target_time)
end
def get_geo_names_timezone(lat, long, user)
  uri = URI("http://api.geonames.org/timezoneJSON?lat=#{lat}&lng=#{long}&username=#{user}")

  puts "Fetching GeoNames Timezone Data from: #{uri}\n\n"

  res = Net::HTTP.get_response(uri)
  json_data = JSON.parse(res.body)
  puts "GeoNames Timezone Data: #{json_data}\n\n"
  return json_data
end
def calculate_solar_position(latitude, longitude, timezone, target_time)
  # Implement the solar position calculations here
  # Return declination and azimuth
  puts "Calculating Solar Position for Latitude: #{latitude}, Longitude: #{longitude}, Timezone: #{timezone}, Target Time: #{target_time}\n\n"
  declination = 0.0
  azimuth = 0.0
  convert1 = Date.parse(target_time.to_s)
  julian_day = convert1.ajd.to_f
  julian_cent = (julian_day - 2451545.0) / 36525.0
  #  I3 -> =MOD(280.46646+[.G3]*(36000.76983+[.G3]*0.0003032);360)
  long_sun = (280.46646 + julian_cent * (36000.76983 + julian_cent * 0.0003032)) % 360
  #  J3 -> =357.52911+[.G3]*(35999.05029-0.0001537*[.G3])
  anom_sun = 357.52911 + julian_cent * (35999.05029 - 0.0001537 * julian_cent)
  #  K3 -> =0.016708634-[.G3]*(0.000042037+0.0000001267*[.G3])
  eccent_earth_orbit = 0.016708634 - julian_cent * (0.000042037 + 0.0000001267 * julian_cent)
  #  L3 -> =SIN(RADIANS([.J3]))*(1.914602-[.G3]*(0.004817+0.000014*[.G3]))+SIN(RADIANS(2*[.J3]))*(0.019993-0.000101*[.G3])+SIN(RADIANS(3*[.J3]))*0.000289
  sun_eq_of_center = Math.sin(deg2rad(anom_sun)) * (1.914602 - julian_cent * (0.004817 + 0.000014 * julian_cent)) + Math.sin(deg2rad(2 * anom_sun)) * (0.019993 - 0.000101 * julian_cent) + Math.sin(deg2rad(3 * anom_sun)) * 0.000289
  #  M3 -> =[.I3]+[.L3]
  sun_true_long = long_sun + sun_eq_of_center
  #  N3 -> =[.J3]+[.L3]
  #sun_true_anom = anom_sun + sun_eq_of_center
  #  O3 -> =(1.000001018*(1-[.K3]*[.K3]))/(1+[.K3]*COS(RADIANS([.N3])))
  #sun_radian_vector = (1.000001018 * (1 - eccent_earth_orbit * eccent_earth_orbit)) / (1 + eccent_earth_orbit * Math.cos(deg2rad(sun_true_anom)))
  #  P3 -> =[.M3]-0.00569-0.00478*SIN(RADIANS(125.04-1934.136*[.G3]))
  apparent_sun_long = sun_true_long - 0.00569 - 0.00478 * Math.sin(deg2rad(125.04 - 1934.136 * julian_cent))
  #  Q3 -> =23+(26+((21.448-[.G3]*(46.815+[.G3]*(0.00059-[.G3]*0.001813))))/60)/60
  mean_obliq_ecliptic = 23 + (26 + ((21.448 - julian_cent * (46.815 + julian_cent * (0.00059 - julian_cent * 0.001813)))) / 60) / 60
  #  R3 -> =[.Q3]+0.00256*COS(RADIANS(125.04-1934.136*[.G3]))
  obliq_corr = mean_obliq_ecliptic + 0.00256 * Math.cos(deg2rad(125.04 - 1934.136 * julian_cent))
  #  S3 -> =DEGREES(ATAN2(COS(RADIANS([.P3]));COS(RADIANS([.R3]))*SIN(RADIANS([.P3]))))
  #sun_rt_ascension = rad2deg(Math.atan2(Math.cos(deg2rad(apparent_sun_long)), Math.cos(deg2rad(obliq_corr)) * Math.sin(deg2rad(apparent_sun_long))))
  #  T3 -> =DEGREES(ASIN(SIN(RADIANS([.R3]))*SIN(RADIANS([.P3]))))
  declination_sun = rad2deg(Math.asin(Math.sin(deg2rad(obliq_corr)) * Math.sin(deg2rad(apparent_sun_long))))
  #  U3 -> =TAN(RADIANS([.R3]/2))*TAN(RADIANS([.R3]/2))
  var_y = Math.tan(deg2rad(obliq_corr) / 2) * Math.tan(deg2rad(obliq_corr) / 2)
  #  V3 -> =4*DEGREES([.U3]*SIN(2*RADIANS([.I3]))-2*[.K3]*SIN(RADIANS([.J3]))+4*[.K3]*[.U3]*SIN(RADIANS([.J3]))*COS(2*RADIANS([.I3]))-0.5*[.U3]*[.U3]*SIN(4*RADIANS([.I3]))-1.25*[.K3]*[.K3]*SIN(2*RADIANS([.J3])))
  eq_of_time = 4 * rad2deg(var_y * Math.sin(2 * deg2rad(long_sun)) - 2 * eccent_earth_orbit * Math.sin(deg2rad(anom_sun)) + 4 * eccent_earth_orbit * var_y * Math.sin(deg2rad(anom_sun)) * Math.cos(2 * deg2rad(long_sun)) - 0.5 * var_y * var_y * Math.sin(4 * deg2rad(long_sun)) - 1.25 * eccent_earth_orbit * eccent_earth_orbit * Math.sin(2 * deg2rad(anom_sun)))
  #  W3 -> =DEGREES(ACOS(COS(RADIANS(90.833))/(COS(RADIANS([.$B$3]))*COS(RADIANS([.T3])))-TAN(RADIANS([.$B$3]))*TAN(RADIANS([.T3]))))
  #hour_angle_sunrise = rad2deg(Math.acos(Math.cos(deg2rad(90.833)) / (Math.cos(deg2rad(latitude)) * Math.cos(deg2rad(declination_sun))) - Math.tan(deg2rad(latitude)) * Math.tan(deg2rad(declination_sun))))
  #  X3 -> =(720-4*[.$B$4]-[.V3]+[.$B$5]*60)/1440
  #solar_noon = (720 - 4 * longitude - eq_of_time + timezone * 60) / 1440
  #  Y3 -> =[.X3]-[.W3]*4/1440
  #sunrise_time = solar_noon - hour_angle_sunrise * 4 / 1440
  #  Z3 -> =[.X3]+[.W3]*4/1440
  #sunset_time = solar_noon + hour_angle_sunrise * 4 / 1440
  #  AA3 -> =8*[.W3]
  #sunlight_duration = 8 * hour_angle_sunrise
  #  AB3 -> =MOD([.E3]*1440+[.V3]+4*[.$B$4]-60*[.$B$5];1440)
  true_solar_time = (target_time.hour * 60 + target_time.min + target_time.sec / 60 + eq_of_time + 4 * longitude - 60 * timezone) % 1440
  #  AC3 -> =IF([.AB3]/4<0;[.AB3]/4+180;[.AB3]/4-180)
  if true_solar_time / 4 < 0
    hour_angle = true_solar_time / 4 + 180
  else
    hour_angle = true_solar_time / 4 - 180
  end
  #  AD3 -> =DEGREES(ACOS(SIN(RADIANS([.$B$3]))*SIN(RADIANS([.T3]))+COS(RADIANS([.$B$3]))*COS(RADIANS([.T3]))*COS(RADIANS([.AC3]))))
  solar_zenith_angle = rad2deg(Math.acos(Math.sin(deg2rad(latitude)) * Math.sin(deg2rad(declination_sun)) + Math.cos(deg2rad(latitude)) * Math.cos(deg2rad(declination_sun)) * Math.cos(deg2rad(hour_angle))))
  #  AE3 -> =90-[.AD3]
  solar_elevation_angle = 90 - solar_zenith_angle
  #  AF3 -> =IF([.AE3]>85;0;IF([.AE3]>5;58.1/TAN(RADIANS([.AE3]))-0.07/POWER(TAN(RADIANS([.AE3]));3)+0.000086/POWER(TAN(RADIANS([.AE3]));5);IF([.AE3]>-0.575;1735+[.AE3]*(-518.2+[.AE3]*(103.4+[.AE3]*(-12.79+[.AE3]*0.711)));-20.772/TAN(RADIANS([.AE3])))))/3600
  if solar_elevation_angle > 85
    atmospheric_refraction = 0
  elsif solar_elevation_angle > 5
    atmospheric_refraction = (58.1 / Math.tan(deg2rad(solar_elevation_angle)) - 0.07 / (Math.tan(deg2rad(solar_elevation_angle))**3) + 0.000086 / (Math.tan(deg2rad(solar_elevation_angle))**5)) / 3600
  elsif solar_elevation_angle > -0.575
    atmospheric_refraction = (1735 + solar_elevation_angle * (-518.2 + solar_elevation_angle * (103.4 + solar_elevation_angle * (-12.79 + solar_elevation_angle * 0.711)))) / 3600
  else
    atmospheric_refraction = -20.772 / Math.tan(deg2rad(solar_elevation_angle)) / 3600
  end
  #  AG3 -> =[.AE3]+[.AF3]
  declination = solar_elevation_angle + atmospheric_refraction
  #  AH3 -> =IF([.AC3]>0;MOD(DEGREES(ACOS(((SIN(RADIANS([.$B$3]))*COS(RADIANS([.AD3])))-SIN(RADIANS([.T3])))/(COS(RADIANS([.$B$3]))*SIN(RADIANS([.AD3])))))+180;360);
  #  #MOD(540-DEGREES(ACOS(((SIN(RADIANS([.$B$3]))*COS(RADIANS([.AD3])))-SIN(RADIANS([.T3])))/(COS(RADIANS([.$B$3]))*SIN(RADIANS([.AD3])))));360))
  if hour_angle > 0
    azimuth = (rad2deg(Math.acos(((Math.sin(deg2rad(latitude)) * Math.cos(deg2rad(solar_zenith_angle))) - Math.sin(deg2rad(declination_sun))) / (Math.cos(deg2rad(latitude)) * Math.sin(deg2rad(solar_zenith_angle))))) + 180) % 360
  else
    azimuth = (540 - rad2deg(Math.acos(((Math.sin(deg2rad(latitude)) * Math.cos(deg2rad(solar_zenith_angle))) - Math.sin(deg2rad(declination_sun))) / (Math.cos(deg2rad(latitude)) * Math.sin(deg2rad(solar_zenith_angle)))))) % 360
  end
  json declination: declination, azimuth: azimuth
end
def deg2rad(degrees)
  degrees * Math::PI / 180.0
end

def rad2deg(radians)
  radians * 180.0 / Math::PI
end
