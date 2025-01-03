timing = 5000 -- Sending timer
srv = nil -- TCP client
uid = '' -- MAC UID
dhtpin = 1 -- DHT11 pin
sda, scl = 3, 4 -- BME280 pins
alt = 320 -- altitude of the measurement place

-- Weather vars

T = - 300 -- BME temp 
P = - 300 -- BME pressure
curAlt = - 300 -- BME altitude
TB = - 300 -- DHT temp
TH = - 300 -- DHT humidity
UF = 0 -- UF index

-- Read the solar sensor

function adc_read()
    UF = adc.read(0)
    print('UF index: '..UF)
end

-- Read the BME280 sensor

function bme_read()
	T, P, H, QNH = bme280.read(alt)
	local Tsgn = (T < 0 and -1 or 1); T = Tsgn*T
	print(string.format("T=%s%d.%02d", Tsgn<0 and "-" or "", T/100, T%100))
	print(string.format("QFE=%d.%03d", P/1000, P%1000))
	print(string.format("QNH=%d.%03d", QNH/1000, QNH%1000))
	P = bme280.baro()
	curAlt = bme280.altitude(P, QNH)
	local curAltsgn = (curAlt < 0 and -1 or 1); curAlt = curAltsgn*curAlt
	print(string.format("altitude=%s%d.%02d", curAltsgn<0 and "-" or "", curAlt/100, curAlt%100))
end

-- Read the DHT11 sensor

function dht_read()
	status, temp, humi, temp_dec, humi_dec = dht.read(dhtpin)
	if status == dht.OK then
		TB = temp
		TH = humi
		print("DHT Temperature:"..temp..";".."Humidity:"..humi)
	elseif status == dht.ERROR_CHECKSUM then
		print( "DHT Checksum error." )
	elseif status == dht.ERROR_TIMEOUT then
		print( "DHT timed out." )
	end
end

-- Prepare data for TCP server

function data_out()
    local pack = {}
    pack['id'] = uid 
    pack['bme'] = {['temp'] = T,['press'] = P,['alt'] = curAlt}    
    pack['dht'] = {['temp'] = TB,['humi'] = TH} 
    pack['solar'] = {['uf'] = UF}
    pack['uf'] = UF -- backport
    return encoder.toBase64(sjson.encode(pack))
end

-- Exchange data with server

function tcp()
    srv:connect(4999,"meteo.ulgrad.ru")
    srv:on("connection", function(sck, c)
    print('connection')
        sck:send(data_out().."\r\n")
    end)  
    srv:on("disconnection", function(sck,c)
        print('disconnection')
    end)  
end

-- On Internet connect

function on_connect()   
    -- Generate UID from MAC address
    uid = string.gsub(wifi.ap.getmac(),':','')
    print("Connected to wifi as: " .. wifi.sta.getip())
    ssid,password,bssid_set,bssid = wifi.sta.getconfig()  
    print(
        "\nCurrent Station configuration:"
        .."\nSSID : "..ssid
        .."\nPassword  : "..password
        .."\nBSSID_set  : "..bssid_set
        .."\nBSSID: "..bssid
        .."\nUID:"..uid
        .."\nClient IP:"..wifi.sta.getip().."\n"
    )
    srv = net.createConnection(net.TCP, 0)    
    if srv then 
        print('TCP Connection start')       
        tcptimer:start()       
    else 
        print('Error connect to TCP') 
    end
end

-- Setup ADC

if adc.force_init_mode(adc.INIT_ADC)
then
  node.restart()
  return -- don't bother continuing, the restart is scheduled
end

-- Setup sensors

i2c.setup(0, sda, scl, i2c.SLOW) -- call i2c.setup() only once
bme280.setup()

-- Setup timers

tcptimer = tmr.create()
tcptimer:register(12000, tmr.ALARM_AUTO,tcp)
    
inittimer = tmr.create()
inittimer:register(5000, tmr.ALARM_SINGLE, function()    
	adc_read()
	bme_read()
	dht_read()
    enduser_setup.start('meteo',on_connect)   
end)

inittimer:start()
