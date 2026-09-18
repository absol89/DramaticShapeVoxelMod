-- Single-camera visual flight adapted from q57 JuggleComfort/SummonReturn.
-- Units here are map pixels. No input, collision or gameplay ownership.
local B={WORLD_UNITS_PER_METRE=16, GRAVITY=9.81*16, THROW_SECONDS=.72}
function B.launch(origin,target,duration,gravity)
  duration=math.max(.001,duration or B.THROW_SECONDS)
  local g=gravity or B.GRAVITY
  return {origin={origin[1],origin[2],origin[3]},target={target[1],target[2],target[3]},
    duration=duration,gravity=g,velocity={(target[1]-origin[1])/duration,
    (target[2]-origin[2])/duration+.5*g*duration,(target[3]-origin[3])/duration}}
end
function B.sample(f,age)
  local t=math.max(0,math.min(f.duration,age))
  local o,v=f.origin,f.velocity
  return o[1]+v[1]*t,o[2]+v[2]*t-.5*f.gravity*t*t,o[3]+v[3]*t
end
-- Cosmetic contact recoil: back toward the thrower and upward, ending at
-- rest before intake. No gameplay clock or catch result is modified.
B.CONTACT_SECONDS=.28
B.CONTACT_LIFT=8
B.CONTACT_BACK=6
function B.contactPose(target,origin,age,duration)
  local u=math.max(0,math.min(1,age/math.max(.001,duration or B.CONTACT_SECONDS)))
  local q=1-(1-u)^3
  local dx,dz=origin[1]-target[1],origin[3]-target[3]
  local len=math.sqrt(dx*dx+dz*dz)
  if len<.001 then dx,dz,len=0,1,1 end
  return target[1]+dx/len*B.CONTACT_BACK*q,
    target[2]+B.CONTACT_LIFT*q+2*math.sin(math.pi*u),
    target[3]+dz/len*B.CONTACT_BACK*q,2*math.pi*(1-(1-u)^2)
end
-- Shortest-arc orientation: +Z is the button/opening axis.
function B.turnAngle(a,b,t)
  t=math.max(0,math.min(1,t)); t=t*t*(3-2*t)
  local d=(b-a+math.pi)%(2*math.pi)-math.pi
  return a+d*t
end
function B.facePoint(x,y,z,target)
  local dx,dz=target[1]-x,target[3]-z
  local horizontal=math.sqrt(dx*dx+dz*dz)
  return math.atan2(dx,dz),math.atan2(y-target[2],horizontal)
end
return B
