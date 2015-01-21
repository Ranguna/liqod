liquid = require('liquid')

function love.load()
	love.window.setMode(800, 600, {vsync=false})
	if not (love.system.getOS() == 'Android' or love.system.getOS() == 'iOS') then
		--love.window.setFullscreen(true,'desktop')
		--love._openConsole()
	end
	postUpdates = {}
	postUpdates[1] = function(i)
		local x,y = liquid.getParticlePosition(i)
		if x < 0 or x > love.graphics.getWidth() then
			liquid.moveParticle(i,love.graphics.getWidth()*math.abs(math.abs(x/love.graphics.getWidth()) - math.abs(math.floor(x/love.graphics.getWidth())) ))
		end
		if y < 0 or y > love.graphics.getHeight() then
			liquid.moveParticle(i,nil,love.graphics.getHeight()*math.abs(math.abs(y/love.graphics.getHeight()) - math.abs(math.floor(y/love.graphics.getHeight())) ))
		end
	end
	postUpdates[2] = function(i)
		local x,y = liquid.getParticlePosition(i)
		local ox,oy = liquid.getOldParticlePosition(i)
		local vx,vy = liquid.getParticleVelocity(i)
		if x < 0 or x > love.graphics.getWidth() then
			liquid.moveParticle(i,ox)
			liquid.changeVelocity(i,-vx*0.98)
		end
		if y < 0 or y > love.graphics.getHeight() then
			liquid.moveParticle(i,nil,oy)
			liquid.changeVelocity(i,nil,-vy*0.98)
		end
	end
	postUpdates.using = 1

	liquid.settings({maxParticles=1000,postUpdate = postUpdates[postUpdates.using],radius = (love.graphics.getWidth()*(1.05+(1.05*(800/love.graphics.getWidth()))))/1680})
end

function love.update(dt)
	a = os.clock()
	liquid.update(dt)
	a = os.clock() - a
	love.window.setTitle(love.timer.getFPS())
end

function love.draw()
	--love.graphics.setColor(0, 0, 255, 128)
	--for x=1,#liquid._vars.grid do
	--	for y = 1,#liquid._vars.grid[x] do
	--		if type(liquid._vars.grid[x][y]) == 'table' then
	--			if liquid._vars.grid[x][y][1] then
	--				love.graphics.rectangle('fill', x*liquid._vars.grid.cellSize*liquid._vars.scale+1, y*liquid._vars.grid.cellSize*liquid._vars.scale+1,liquid._vars.grid.cellSize*liquid._vars.scale-1,liquid._vars.grid.cellSize*liquid._vars.scale-1)
	--			end
	--		end
	--	end
	--end
	--love.graphics.setColor(255, 255, 255, 255)
	liquid.draw()
	--love.graphics.line(0, love.graphics.getHeight()/2, love.graphics.getWidth(), love.graphics.getHeight()/2)
	love.graphics.print(liquid._vars.numActiveParticles, 1, 1)
	love.graphics.print(a, 1, 15)
	local b
	for i,v in ipairs(liquid._vars.debug) do
		love.graphics.print(v.name ..': ' .. v[2]-v[1], 1, 15+15*i)
		b=i+1
	end
  
	local c =0
	if love.system.getOS() == 'Android' then
		for i,v in ipairs(liquid._vars.touch) do
			for ii,vv in ipairs(v) do
				c=c+1
				love.graphics.print(i..', '..tostring(vv),1,15*(b+c))
			end
		end
	end
	c=c+1
	love.graphics.print(liquid._vars.radius,1,15*(b+c))
	love.graphics.print(liquid._vars.grid.cellSize,1,15*(b+c+1))
	love.graphics.print('Gravity = '.. liquid._vars.gravity[1] ..', '.. liquid._vars.gravity[2],1,15*(b+c+2))
	love.graphics.print('Using post update: '..postUpdates.using, 1, 15*(b+c+3))
end

function love.keypressed(k)
	if k == 'escape' then
		love.event.quit()
	elseif k == 'g' then
		x,y = liquid.getGravity()
		y = y == 0 and 9.8/300 or 0

		liquid.setGravity(x,y)
	elseif k == 'b' then
		postUpdates.using = postUpdates.using +1 <= #postUpdates and postUpdates.using+1 or 1

		liquid.postUpdate(postUpdates[postUpdates.using])
	elseif k == 'w' then --rough water test
		liquid._vars.roughWaters = not liquid._vars.roughWaters
	end
end

if love.system.getOS() == 'Android' then
	function love.touchpressed(id,x,y,p)
		if (y < 0.1 or y > 0.9) and (x < 0.1 or x > 0.9) then
			if y < 0.1 then
				if x < 0.1 then --bottom left
					postUpdates.using = postUpdates.using +1 <= #postUpdates and postUpdates.using+1 or 1

					liquid.postUpdate(postUpdates[postUpdates.using])
				else --bottom right
					x,y = liquid.getGravity()
					y = y == 0 and 9.8/300 or 0

					liquid.setGravity(x,y)
				end
			else
				if x > 0.9 then --top left
					liquid._vars.roughWaters = not liquid._vars.roughWaters
				end
			end
		else
			liquid.touchpressed(id,x,y,p)
		end
	end
	
	function love.touchreleased(id,x,y,p)
		liquid.touchreleased(id,x,y,p)
	end
	
	function love.touchmoved(id,x,y,p)
		liquid.touchmoved(id,x,y,p)
	end
end
