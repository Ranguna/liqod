local liquid = {}


local dist = function(x1,y1,x2,y2) 
	if x2 and y2 then --two points
		return math.sqrt((x1-x2)^2 + (y1-y2)^2) 
	else --vector
		return math.sqrt(x1^2 + y1^2)
	end
end

liquid._vars = {}
liquid._vars.touch = love.system.getOS() == 'Android' and {}
liquid._vars.maxParticles = 1000
liquid._vars.radius = 0.6
liquid._vars.viscosity = 0.0004 --.0004 water, .004 blobish, .04 elastic
-----
liquid._vars.scale = 32
liquid._vars.idealRadius = 50
liquid._vars.idealRadiusSQ = liquid._vars.idealRadius*liquid._vars.idealRadius
liquid._vars.multiplier = liquid._vars.idealRadius/liquid._vars.radius
liquid._vars.delta = {} --vec2[]
liquid._vars.scaledPositions = {}
liquid._vars.scaledVelocity = {}
liquid._vars.numActiveParticles = 0
liquid._vars.liquid = {}
liquid._vars.activeParticles = {}
liquid._vars.maxNeighbors = 75
-----
liquid._vars.debug = {}

liquid._vars.grid = {}
--liquid._vars.grid.count = 0
liquid._vars.grid.cellSize = 0.5
liquid._vars.grid.transformCoord = function(v)
	return math.floor(v/liquid._vars.grid.cellSize)
end
liquid._vars.grid.getValue = function(k1,k2,i) --x,y or {x,y}
	if type(k1) == 'table' then
		k2 = k1[2]
		k1 = k1[1]
	end
		
	if liquid._vars.grid[k1] then
		if liquid._vars.grid[k1][k2] then
			return liquid._vars.grid[k1][k2]
		end
	end
	return false
end
liquid._vars.grid.add = function(k1,k2,v) --x,y,v or {x,y},v
	if type(k1) == 'table' then
		v=k2
		k2 = k1[2]
		k1 = k1[1]
	end
	--print('going to create '.. k1,k2,v)
	if not liquid._vars.grid[k1] then
		--render specific
		--for i = 1,k1 do
		--	if not liquid._vars.grid[i] then
		--		liquid._vars.grid[i] = {}
		--		liquid._vars.grid[i].count = 0
		--	end
		--end
		liquid._vars.grid[k1] = {}
		liquid._vars.grid[k1].count = 0
	end
	if not liquid._vars.grid[k1][k2] then
		--render specific
		--for i = 1,k2 do
		--	if not liquid._vars.grid[k1][i] then
		--		liquid._vars.grid[k1][i] = {}
		--		liquid._vars.grid[k1][i].count = 0
		--	end
		--	liquid._vars.grid[k1].count = liquid._vars.grid[k1].count +1
		--end
		liquid._vars.grid[k1][k2] = {}
		liquid._vars.grid[k1][k2].count = 0
		liquid._vars.grid[k1].count = liquid._vars.grid[k1].count +1
	end
	local exists
	for a,b in ipairs(liquid._vars.grid[k1][k2]) do --eliminates double positioning
		if b == v then
			exists = true
		end
	end
	if not exists then
		liquid._vars.grid[k1][k2].count = liquid._vars.grid[k1][k2].count +1
		liquid._vars.grid[k1][k2][#liquid._vars.grid[k1][k2]+1] = v
		--print('created '.. k1,k2,v,#liquid._vars.grid[k1][k2]+1)
	end
end
liquid._vars.grid.remove = function(k1,k2,v) --x,y,i,v or {x,y,i},v
	if type(k1) == 'table' then
		v=k2
		k2 = k1[2]
		i = k1[3]
		k1 = k1[1]
	end
	--print('going to remove ',k1,k2,v)
	if liquid._vars.grid[k1] then
		if k2 then
			if liquid._vars.grid[k1][k2] then
				if v then
					--print('looking for '..v)
					local exists
					for a,b in ipairs(liquid._vars.grid[k1][k2]) do
						if b == v then
							exists = a
							break
						end
					end
					--print(exists and 'found',exists or 'not found')
					if exists then
						liquid._vars.grid[k1][k2].count = liquid._vars.grid[k1][k2].count -1
						--liquid._vars.grid[k1][k2][exists] = nil
						table.remove(liquid._vars.grid[k1][k2],exists)
						--print('removed '..k1,k2,v,exists)
					end
				else
					liquid._vars.grid[k1].count = liquid._vars.grid[k1].count -1
					liquid._vars.grid[k1][k2] = nil
					--print('removed '..k1,k2)
				end
			end
		else
			--liquid._vars.grid.count = liquid._vars.grid.count -1
			liquid._vars.grid[k1] = nil
			--print('removed '..k1)
		end
	end
end

function liquid.newParticle(position,velocity,alive)
	local particle = {}
	particle.position = position
	particle.velocity = velocity
	particle.pressure = 0
	particle.alive = alive
	particle.distances = {}
	particle.neighbors = {}
	particle.neighborCount = 0
	particle.grid = {liquid._vars.grid.transformCoord(position[1]),liquid._vars.grid.transformCoord(position[2])}
	return particle
end

function liquid.findNeighbors(pindex)
	liquid._vars.liquid[pindex].neighbors = {}
	local particle = liquid._vars.liquid[pindex]
	particle.neighborCount = 0
	for x = -1,1 do
		for y = -1,1 do
			local nx,ny = particle.grid[1] + x,particle.grid[2] + y
			if liquid._vars.grid.getValue(nx,ny) then
				for i,v in ipairs(liquid._vars.grid.getValue(nx,ny)) do
					if v ~= pindex then
						particle.neighbors[#particle.neighbors+1] = v
					end
					particle.neighborCount = particle.neighborCount +1
					if particle.neighborCount == 75 then
						return
					end
				end
			end
		end
	end
	liquid._vars.liquid[pindex] = particle
end

function liquid.init()
	for i=1,liquid._vars.maxParticles do
		liquid._vars.liquid[i] = liquid.newParticle({0,0},{0,0},false)
		liquid._vars.liquid[i].index = i

		liquid._vars.delta[i] = {0,0} --vec2
		liquid._vars.scaledPositions[i] = {} --vec2
		liquid._vars.scaledVelocity[i] = {} --vec2
	end
end

function liquid.settings(...) --mp,r,v,nc or {mp=mp,r=r,v=v,nc=nc} or {mp,r,v,nc}
	args = {...}
	if #args == 1 then
		args = args[1]
	end
	liquid._vars.maxParticles = args.maxParticles or args[1] or liquid._vars.maxParticles
	--liquid._vars.radius = args.radius and (args.radius*love.graphics.getHeight())/600 or args[2] and (args[2]*love.graphics.getHeight())/600 or (liquid._vars.radius*love.graphics.getHeight())/600
	liquid._vars.radius = args.radius or args[2] or liquid._vars.radius
	liquid._vars.viscosity = args.viscosity and args.viscosity or args[3] and args[3] or liquid._vars.viscosity
	--liquid._vars.viscosity = args.viscosity and (args.viscosity*love.graphics.getHeight())/600 or args[3] and (args[3]*love.graphics.getHeight())/600 or (liquid._vars.viscosity*love.graphics.getHeight())/600
	liquid._vars.maxNeighbors = args.maxNeighbors or args[4] or liquid._vars.maxNeighbors
	liquid._vars.postUpdate = args.postUpdate or args[5] or nil

	--liquid._vars.scale = (32*love.graphics.getHeight())/600
	liquid._vars.scale = ((liquid._vars.radius*32)/(0.6))
	liquid._vars.idealRadius = ((liquid._vars.radius*50)/(0.6))
	liquid._vars.idealRadiusSQ = liquid._vars.idealRadius*liquid._vars.idealRadius
	liquid._vars.multiplier = liquid._vars.idealRadius/liquid._vars.radius
	liquid._vars.grid.cellSize = ((liquid._vars.radius*0.5)/(0.6))

	liquid._vars.multiplier = liquid._vars.idealRadius/liquid._vars.radius
	liquid._vars.numActiveParticles = 0
	liquid._vars.liquid = {}
	liquid._vars.activeParticles = {}

	liquid.init()
end

function liquid.applyLiquidConstraints(dt)
	liquid._vars.debug = {}
	liquid._vars.debug[1] = {name = 'First loop',os.clock()}
	for i = 1,liquid._vars.numActiveParticles do
		local index = liquid._vars.activeParticles[i]
		local particle = liquid._vars.liquid[index]

		liquid._vars.scaledPositions[i] = {particle.position[1]*liquid._vars.multiplier,particle.position[2]*liquid._vars.multiplier}
		liquid._vars.scaledVelocity[i] = {particle.velocity[1]*liquid._vars.multiplier,particle.velocity[2]*liquid._vars.multiplier}

		liquid._vars.delta[index] = {0,0}

		--updates neighbors
		liquid._vars.debug[2] = {name = 'Neighbor search',os.clock()}
		liquid.findNeighbors(index)
		liquid._vars.debug[2][2] = os.clock()
	end
	for i = 1,liquid._vars.numActiveParticles do
		local index = liquid._vars.activeParticles[i]
		local particle = liquid._vars.liquid[index]
		--Calculate Pressure
		local p = 0
		local pnear = 0

		liquid._vars.debug[3] = {name = 'Pressure calculation',os.clock()}
		for i,v in ipairs(particle.neighbors) do
			local relativePosition = {liquid._vars.scaledPositions[v][1] - liquid._vars.scaledPositions[index][1],liquid._vars.scaledPositions[v][2] - liquid._vars.scaledPositions[index][2]}
			local distanceSQ = dist(relativePosition[1],relativePosition[2])^2

			--within idealRadius check
			if distanceSQ < liquid._vars.idealRadiusSQ then
				particle.distances[i] = math.sqrt(distanceSQ)

				local oneminusq = 1 - (particle.distances[i]/liquid._vars.idealRadius)
				p = (p + oneminusq * oneminusq)
				liquid._vars.liquid[index].pressure = p
				pnear = (pnear + oneminusq*oneminusq*oneminusq)
			else
				particle.distances[i] = 1/0 -- float.MaxValue ?
			end
		end
		liquid._vars.debug[3][2] = os.clock()

		--Apply force
		local pressure = (p-5)/2 -- normal pressure term
		local presnear = pnear /2 -- near particles term
		local change = {0,0}
		
		liquid._vars.debug[4] = {name = 'Apply force',os.clock()}
		for i,v in ipairs(particle.neighbors) do
			local relativePosition = {liquid._vars.scaledPositions[v][1] - liquid._vars.scaledPositions[index][1],liquid._vars.scaledPositions[v][2] - liquid._vars.scaledPositions[index][2]}
			if particle.distances[i] < liquid._vars.idealRadius then
				local q = particle.distances[i] / liquid._vars.idealRadius
				local oneminusq = 1 - q
				local factor = oneminusq * (pressure+presnear*oneminusq)/(2*particle.distances[i])
				local d = {relativePosition[1]*factor,relativePosition[2]*factor}
				local relativeVelocity = {liquid._vars.scaledVelocity[v][1] - liquid._vars.scaledVelocity[index][1],liquid._vars.scaledVelocity[v][2] - liquid._vars.scaledVelocity[index][2]}

				factor = liquid._vars.viscosity * oneminusq*dt
				d = {d[1] - (relativeVelocity[1]*factor),d[2] - (relativeVelocity[2]*factor)}
				liquid._vars.delta[v] = {liquid._vars.delta[v][1] + d[1],liquid._vars.delta[v][2] + d[2]}
				change = {change[1]-d[1],change[2]-d[2]}
			end
		end
		liquid._vars.debug[4][2] = os.clock()
		liquid._vars.delta[index] = {liquid._vars.delta[index][1] + change[1],liquid._vars.delta[index][2] + change[2]}
		liquid._vars.liquid[index].velocity = {liquid._vars.liquid[index].velocity[1],liquid._vars.liquid[index].velocity[2]+.0}
	end
	liquid._vars.debug[1][2] = os.clock()

	liquid._vars.debug[5] = {name = 'Position update',os.clock()}
	for i = 1,liquid._vars.numActiveParticles do
		local index = liquid._vars.activeParticles[i]
		particle = liquid._vars.liquid[index]

		particle.position = {particle.position[1] + (liquid._vars.delta[index][1]/liquid._vars.multiplier),particle.position[2] + (liquid._vars.delta[index][2]/liquid._vars.multiplier)}
		particle.velocity = {particle.velocity[1] + (liquid._vars.delta[index][1]/(liquid._vars.multiplier*dt)),particle.velocity[2] + (liquid._vars.delta[index][2]/(liquid._vars.multiplier*dt))}
		particle.position = {particle.position[1] + (liquid._vars.liquid[index].velocity[1]/liquid._vars.multiplier),particle.position[2] + (liquid._vars.liquid[index].velocity[2]/liquid._vars.multiplier)}

		local x,y = liquid._vars.grid.transformCoord(particle.position[1]),liquid._vars.grid.transformCoord(particle.position[2])
		if x ~= particle.grid[1] or y ~= particle.grid[2] then
			--print('count on '..particle.grid[2],liquid._vars.grid[particle.grid[1]][particle.grid[2]].count)
			--print('sending '..particle.grid[1],particle.grid[2],index)
			liquid._vars.grid.remove(particle.grid[1],particle.grid[2],index)
			if liquid._vars.grid[particle.grid[1]][particle.grid[2]].count == 0 then
				liquid._vars.grid.remove(particle.grid[1],particle.grid[2])
				if liquid._vars.grid[particle.grid[1]].count == 0 then
					liquid._vars.grid.remove(particle.grid[1])
				end
			end
			--print('sending to add '..x,y,index)
			liquid._vars.grid.add(x,y,index)
			particle.grid = {x,y}
		end
	end
	liquid._vars.debug[5][2] = os.clock()
	if liquid._vars.postUpdate then
		for i,v in ipairs(liquid._vars.liquid) do
			if v.alive then
				liquid._vars.postUpdate(i)
			end
		end
	end
end

function liquid.createParticle(x,y,n)
	local inactiveParticlei = {}

	for i,v in ipairs(liquid._vars.liquid) do
		if not v.alive then
			table.insert(inactiveParticlei,i)
		end
		if #inactiveParticlei == n then
			break
		end
	end

	for i,v in ipairs(inactiveParticlei) do
		jitter = {love.math.random()*2 -1, love.math.random() -0.5}

		liquid._vars.liquid[v] = liquid.newParticle({x+jitter[1],y+jitter[2]},{0,0},true)
		liquid._vars.scaledPositions[v] = {(x+jitter[1])*liquid._vars.multiplier,(y+jitter[2])*liquid._vars.multiplier}
		liquid._vars.scaledVelocity[v] = {0,0}
		liquid._vars.grid.add(liquid._vars.liquid[v].grid[1],liquid._vars.liquid[v].grid[2],v)
		local exists
		for a,b in ipairs(liquid._vars.activeParticles) do
			if b == v then
				exists = true
			end
		end
		if not exists then
			table.insert(liquid._vars.activeParticles,v)
			liquid._vars.numActiveParticles = liquid._vars.numActiveParticles +1
		end
	end
end

function liquid.postUpdate(func)
	liquid._vars.postUpdate = func
end

function liquid.getParticlePosition(i)
	if liquid._vars.liquid[i] then
		return liquid._vars.liquid[i].position[1] * liquid._vars.scale,liquid._vars.liquid[i].position[2] * liquid._vars.scale
	end
end

function liquid.moveParticle(i,x,y)
	if liquid._vars.liquid[i] then
		if liquid._vars.liquid[i].alive then
			x,y = x and x/liquid._vars.scale or liquid._vars.liquid[i].position[1], y and y/liquid._vars.scale or liquid._vars.liquid[i].position[2]
			liquid._vars.liquid[i].position = {x,y}
		end
	end
end





function liquid.draw()
	local width = love.graphics.getLineWidth()
	love.graphics.setLineWidth(love.graphics.getHeight()/600)
	for i,v in ipairs(liquid._vars.activeParticles) do
		local particle = liquid._vars.liquid[v]
		local x,y = particle.position[1] * liquid._vars.scale,particle.position[2] * liquid._vars.scale
		--love.graphics.point(x, y)
		love.graphics.setColor(255*(particle.pressure/5), 255*((particle.pressure/5)/1.1), 255, 255)
		love.graphics.line(x, y, x+particle.velocity[1], y+particle.velocity[2])
	end
	love.graphics.setLineWidth(width)
	love.graphics.setColor(255, 255, 255, 255)
end

if love.system.getOS() == 'Android' or love.system.getOS() == 'iOS' then
	function liquid.update(dt)
		local x,y = love.mouse.getPosition()
		x,y = (x+math.random(1,10)*math.random(-1,1))/liquid._vars.scale,(y+math.random(1,10)*math.random(-1,1))/liquid._vars.scale
		for i,v in ipairs( liquid._vars.touch) do
			liquid.createParticle(v[1]/liquid._vars.scale,v[2]/liquid._vars.scale,math.ceil((120*v[3])*dt))
		end
		liquid.applyLiquidConstraints(dt)
	end
	
	function liquid.touchpressed(id,x,y,p)
		thing = {x*love.graphics.getWidth(),y*love.graphics.getHeight(),p,true}
		liquid._vars.touch[#liquid._vars.touch+1] = {x*love.graphics.getWidth(),y*love.graphics.getHeight(),p,true,id}
	end
	
	function liquid.touchreleased(id,x,y,p)
		for i,v in ipairs(liquid._vars.touch) do
			if v[5] == id then
			 table.remove(liquid._vars.touch,i)
			 return
			end
		end
	end
	
	function liquid.touchmoved(id,x,y,p)
		for i,v in ipairs(liquid._vars.touch) do
			if v[5] == id then
			 liquid._vars.touch[i] = {x*love.graphics.getWidth(),y*love.graphics.getHeight(),p,true,id}
			end
		end
	end
else
	function liquid.update(dt)
		local x,y = love.mouse.getPosition()
		x,y = x/liquid._vars.scale,y/liquid._vars.scale
	
		if love.mouse.isDown('l') then
			liquid.createParticle(x,y,4)
		end
	
		liquid.applyLiquidConstraints(1/60)
	end
end



return liquid
