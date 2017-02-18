-- title:  Pico Smash
-- author: William F.
-- desc:   ...
-- script: lua
-- input:  gamepad
-- pal:    PICO8
-- version 0.0.1

-- Settings
local FPS=30
local SKIP=4

-- Framework
local _l,_C;local _f=1;local _s=1000/FPS;local _t=time();local _S={}
function TIC()_f=_f and _C.init() or nil;_l=0;while time()>_t and _l<=SKIP do local _c=time();_C.update(_c,_c/1000);_t=_t+_s;_l=_l+1 end;_C.draw() end
function addScene(n,v)_S[n]=v;if _C==nil then _C=v end end
function toScene(n)local c=_S[n];if c==nil then return end;if _C.blur then _C.blur() end;_C=c;_f=1;if _C.focus then _C.focus() end end

-- Globals
local SCR={w=240,h=136}
local CELL=8
local SOLID={
	1,2,3,40,41, -- Dreamland
	48,49,50,    -- Mario
}
local GRAVITY=4

local Cam={x=0,y=0,gx=0,gy=0,w=SCR.w,h=SCR.h}

-- API
PI=math.pi
function abs(n)return math.abs(n) end
function pow(a,b)return math.pow(a,b) end
function cos(n)return math.cos(n) end
function sin(n)return math.sin(n) end
function sqrt(n)return math.sqrt(n) end
function asin(n)return math.asin(n) end
function acos(n)return math.acos(n) end
function flr(n)return math.floor(n) end
function ceil(n)return math.ceil(n) end
function add(t,v)t[#t+1]=v end
function del(t,p)if not p then p=#t end;for i=p,#t do t[i]=t[i+1] end end
function foreach(a,b)for _,i in ipairs(a) do b(i) end end
function isnum(a)return type(a)=="number" end
local _spr=spr;function spr(s,x,y,a,c,f,r,w,h)local a=a==nil and 0 or a;local c=c==nil and 1 or c;local f=f==nil and 0 or f;local r=r==nil and 0 or r;local w=w==nil and 1 or w;local h=h==nil and 1 or h;for j=1,h do for i=1,w do _spr(s,x+(i-1)*8*c,y+(j-1)*8*c,a,c,f,r);s=s+1 end;s=s-w+16 end end
function sget(x,y)local a=0x4000+(x//8+y//8*16)*16;return peek4(a*2+x%8+y%8*8) end

-- Vector
Vec2={};Vec2.__index=Vec2
function Vec2.new(x,y)return setmetatable({x=x or 0,y=y or 0},Vec2) end
function Vec2.__add(a,b)if isnum(a) then return Vec2.new(b.x+a,b.y+a) elseif isnum(b) then return Vec2.new(a.x+b,a.y+b) else return Vec2.new(a.x+b.x,a.y+b.y) end end
function Vec2.__sub(a,b)if isnum(a) then return Vec2.new(a-b.x,a-b.y) elseif isnum(b) then return Vec2.new(a.x-b,a.y-b) else return Vec2.new(a.x-b.x,a.y-b.y) end end
function Vec2.__mul(a,b)if isnum(a) then return Vec2.new(b.x*a,b.y*a) elseif isnum(b) then return Vec2.new(a.x*b,a.y*b) else return Vec2.new(a.x*b.x,a.y*b.y) end end
function Vec2.__div(a,b)if isnum(a) then return Vec2.new(a/b.x,a/b.y) elseif isnum(b) then return Vec2.new(a.x/b,a.y/b) else return Vec2.new(a.x/b.x,a.y/b.y) end end
function Vec2.__eq(a,b)return a.x==b.x and a.y==b.y end
function Vec2.__lt(a,b)return a.x<b.x or (a.x==b.x and a.y<b.y) end
function Vec2.__le(a,b)return a.x<=b.x and a.y<=b.y end
function Vec2.dist(a, b)return (b-a):len() end
function Vec2:copy()return Vec2.new(self.x,self.y) end
function Vec2:unpack()return self.x,self.y end
function Vec2:len()return sqrt(self.x*self.x+self.y*self.y) end
function Vec2:lenSq()return self.x*self.x+self.y*self.y end
function Vec2:norm()local l=self:len();self.x=self.x/l;self.y=self.y/l;return self end
function Vec2:normd()return self/self:len() end
function Vec2:rot(p)local c=cos(p);local s=sin(p);self.x=c*self.x-s*self.y;self.y=s*self.x+c*self.y;return self end
function Vec2:rotd(p)return self:copy():rot(p) end
function Vec2:perp()return Vec2.new(-self.y,self.x) end
function Vec2:proj(other)return (self*o)*o/o:lenSq() end
function Vec2:cross(o)return self.x*o.y-self.y*o.x end
setmetatable(Vec2,{__call=function(_,...)return Vec2.new(...)end})

-- Collision
local Col={}
function Col:edges(x,y,w,h)
	local w=w or CELL-1
	local h=h or CELL-1
	local x=x+(CELL-w)/2
	local y=y+(CELL-h)/2
	local tl=mget(x/CELL,y/CELL)
	local tr=mget((x+w)/CELL,y/CELL)
	local bl=mget(x/CELL,(y+h)/CELL)
	local br=mget((x+w)/CELL,(y+h)/CELL)
	return tl,tr,bl,br
end
function Col:solid(i)for _,v in ipairs(SOLID) do if v==i then return true end end;return false end

-- Animation
function Anim(f,d,l)
	local o={t=0,i=0,frame=0,f=f or {},d=d or {},c=0,loop=l==nil and -1 or l,ended=false}
	function o.update(t)
		if #o.f==0 or o.ended then return end
		o.frame=o.f[o.i+1]
		if t>=o.t+o.d[o.i+1] then if o.i+1==#o.f then o.i=0;o.c=o.c+1 else o.i=o.i+1 end;o.t=t end
		if o.loop>-1 then o.ended=o.c==o.loop+1 end
	end
	function o.rand() o.i=math.random(#o.f) end
	function o.reset() o.i=0;o.ended=false end
	return o
end

-- Locals
local puffs={}
local PUFF={
	jump={{352,353,354,355,356},{60,60,60,60,60},0}
}

-- Player
function Player(x,y)
	local s={
		pos=Vec2(x or 0,y or 0),
		spd=3,
		vel=Vec2(0,0),
		gacc=2,gdcc=1,
		aacc=8,adcc=.5,
		grav=1,
		gnd=true,
		hp=0,
		atk=-1,
		anim=nil,
		anims={},
		alpha=8,
		flip=0
	}

	function s.move(dx)
		if abs(s.vel.x)<s.spd then
			s.vel.x=s.vel.x+s.gacc*dx
		end
		
		-- Flip?
		if dx~=0 then s.flip=dx<0 and 1 or 0 end
		
		if s.atk==-1 then
			s.anim=s.anims.walk
		end
	end

	function s.update(t)
		-- Update animation
		if s.anim~=nil and s.anim.ended then
			s.atk=-1
		end
		
		if s.gnd and s.atk==-1 then
			s.anim=s.anims.idle
		end
		
		-- Gravity
		-- TODO

		-- Movement
		if btn(2) then
			s.move(-1)
		end
		if btn(3) then
			s.move(1)
		end
	
		if s.vel.x~=0 then
			s.pos.x=s.pos.x+s.vel.x
			s.vel.x=s.vel.x+s.gdcc*(s.vel.x>0 and -1 or 1)
		end
		
		-- Update animation
		s.anim.update(t)
	end

	function s.draw()
		--spr(s.anim.frame+5,s.pos.x-3,s.pos.y+8,s.alpha,1,s.flip)
		--spr(s.anim.frame+5,s.pos.x-5,s.pos.y+8,s.alpha,1,s.flip)
		--spr(s.anim.frame+5,s.pos.x-4,s.pos.y+7,s.alpha,1,s.flip)
		--spr(s.anim.frame+5,s.pos.x-4,s.pos.y+9,s.alpha,1,s.flip)
		spr(s.anim.frame,s.pos.x-4,s.pos.y+8,s.alpha,1,s.flip)
	end

	return s
end

-- Puff
function Puff(x,y,a,p)
	local s={
		x=x,
		y=y,
		anim=Anim(a[1],a[2],a[3]),
		alpha=p or 8
	}

	function s.update(t)
		s.anim.update(t)
	end

	function s.draw()
		spr(s.anim.frame,s.x-4,s.y+8,s.alpha)
	end

	return s
end

-- Animations
local S_PIKA={
	idle=Anim({272},{60}),
	walk=Anim({273,274},{120,120}),
	fall=Anim({275,276},{120,120})
}
local S_MARIO={
	spd=2,
	gacc=1,
	gdcc=.25,
	jmph=20,
	anims={
		idle=Anim({288},{60}),
		walk=Anim({289,290},{180,180}),
		fall=Anim({291,292},{120,120})
	}
}
local S_LINK={
	idle=Anim({304},{60}),
	walk=Anim({305,306},{160,160}),
	fall=Anim({305,306},{120,120})
}

-- Scene: game
local game={
	stage=1,
	map=Vec2(30,0)
}

local p1=Player(12*8,9*8)
p1.spd=S_MARIO.spd
p1.gacc=S_MARIO.gacc
p1.gdcc=S_MARIO.gdcc
p1.jmph=S_MARIO.jmph
p1.anims=S_MARIO.anims
p1.anim=p1.anims.idle

function game.init()
end

function game.update(t,dt)
	-- Update puffs
	for i,p in ipairs(puffs) do
		if p.anim.ended then
			del(puffs,i)
		else
		p.update(t)
		end
	end

	-- Update players
	p1.update(t)
end

function game.draw()
	cls(0)
	
	-- Draw map
	map(game.map.x,game.map.y,Cam.w,Cam.h)
	
	if game.stage==0 then
		for i=8,21 do
			spr(301,i*8,56,8)
		end
		
		spr(269,56,80,8,1,0,0,3,1)
		spr(269,160,80,8,1,0,0,3,1)
	end
	
	-- Draw puffs
	for _,p in ipairs(puffs) do
		p.draw()
	end
	
	-- Draw players
	p1.draw()
	
	local t=2*sin(time()*.0015*PI)
	spr(338,p1.pos.x-3,p1.pos.y-2+t,8)
	spr(338,p1.pos.x-5,p1.pos.y-2+t,8)
	spr(338,p1.pos.x-4,p1.pos.y-3+t,8)
	spr(338,p1.pos.x-4,p1.pos.y-1+t,8)
	
	spr(336,p1.pos.x-4,p1.pos.y-2+t,8)
	
	-- Draw HUD
	local pr1="32"
	local pr2="79"
	print(pr1.."%",64,Cam.h-7)
	print(pr2.."%",Cam.w-64-(#pr2*8),Cam.h-7)
	
	-- Debug
	print(p1.gnd and "GND" or "AIR")
	print(btn(4) and "1" or "0",0,7)
	print(""..#puffs,0,14)
end

-- Register scenes
addScene("game",game)
