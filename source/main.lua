liquid = require('liquid')

function love.load()
	love.window.setMode(800, 600, {vsync=false})
	if not (love.system.getOS() == 'Android' or love.system.getOS() == 'iOS') then
		--love.window.setFullscreen(true,'desktop')
		--love._openConsole()
	end
	local postupdate = function(i)
		local x,y = liquid.getParticlePosition(i)
		if x < 0 or x > love.graphics.getWidth() then
			liquid.moveParticle(i,love.graphics.getWidth()*math.abs(math.abs(x/love.graphics.getWidth()) - math.abs(math.floor(x/love.graphics.getWidth())) ))
		end
		if y < 0 or y > love.graphics.getHeight() then
			liquid.moveParticle(i,nil,love.graphics.getHeight()*math.abs(math.abs(y/love.graphics.getHeight()) - math.abs(math.floor(y/love.graphics.getHeight())) ))
		end
	end
	liquid.settings({maxParticles=1000,postUpdate = postupdate,radius = (love.graphics.getWidth()*(1.05+(1.05*(800/love.graphics.getWidth()))))/1680})

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
end

function love.keypressed(k)
	if k == 'escape' then
		love.event.quit()
	end
end

if love.system.getOS() == 'Android' then
	function love.touchpressed(id,x,y,p)
		liquid.touchpressed(id,x,y,p)
	end
	
	function love.touchreleased(id,x,y,p)
		liquid.touchreleased(id,x,y,p)
	end
	
	function love.touchmoved(id,x,y,p)
		liquid.touchmoved(id,x,y,p)
	end
end
