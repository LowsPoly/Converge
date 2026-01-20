local DEFAULT_PRECISION_THRESHOLD = 0.025
local MOVEMENT_TIME_OFFSET = 10

local Converge = {}
Converge.__index = Converge

Converge.Direction = {
	BEGIN = 0,
	CLOSE = 1;
}

Converge.estimateMoveTime = function(Constraint)
	local distance = 0
	local speed = 0

	if (Constraint:IsA("PrismaticConstraint")) then
		distance = Constraint.UpperLimit
		speed = Constraint.Speed
	end

	if (Constraint:IsA("HingeConstraint")) then
		distance = Constraint.UpperAngle
		speed = Constraint.AngularSpeed
	end

	return (distance / speed) + MOVEMENT_TIME_OFFSET
end

function Converge.new(Constraint, Configuration: {
	Precision: number,
	Timeout: number})

	assert(Constraint:IsA("PrismaticConstraint")or Constraint:IsA("HingeConstraint"),
		tostring(Constraint) .. " IS NOT SUPPORTED")

	Configuration = Configuration or {}
	local self = setmetatable({}, Converge)

	self.Constraint = Constraint
	self.PrecisionThreshold = Configuration.Precision or DEFAULT_PRECISION_THRESHOLD
	self.Timeout = Configuration.Timeout or Converge.estimateMoveTime(self.Constraint)

	self._waiting = false
	self._completed = false
	self._completionTask = nil

	return self
end

function Converge:IsCompleted(Direction): boolean
	local target = self:_CalculateTarget(Direction)

	if (self.Constraint:IsA("PrismaticConstraint")) then
		local distDiff = math.abs(self.Constraint.CurrentPosition - target)
		return distDiff <= self.PrecisionThreshold
	end

	if (self.Constraint:IsA("HingeConstraint")) then
		local distDiff = math.abs(self.Constraint.CurrentAngle - target)
		return distDiff <= self.PrecisionThreshold
	end

	error("UNSUPPORTED CONSTRAINT: " .. tostring(self.Constraint), 2)
end

function Converge:Wait(): boolean
	self._waiting = true
	self._completed = false

	task.delay(self.Timeout, function()
		if (self._completed) then
			return false
		end

		self._waiting = false
		self._completed = true
		warn(tostring(self.Constraint) .. " COMPLETION WAITING CANCELLED: TIMEOUT REACHED")
	end)

	while (not self._completed) do
		if (not self:IsCompleted()) then
			task.wait()
			continue
		end

		self._waiting = false
		self._completed = true
		return true
	end
end

function Converge:Completed(Callback)
	assert(typeof(Callback) == "function", "CALLBACK MUST BE A FUNCTION")

	if (self._completed) then
		task.defer(Callback)
		return
	end

	if (self._completionTask) then
		return
	end

	self._completionTask = task.spawn(function()
		self:Wait()
		Callback()
		self._completionTask = nil
	end)
end

function Converge:Reset()
	self._waiting = false
	self._completed = false
	self._completionTask = nil
end

function Converge:_CalculateTarget(Direction)
	local target

	if (self.Constraint:IsA("PrismaticConstraint")) then
		target = self.Constraint.UpperLimit
	end

	if (self.Constraint:IsA("HingeConstraint")) then
		target = self.Constraint.UpperAngle
	end

	if (Direction == Converge.Direction.CLOSE) then
		target = 0
	end

	return target
end

return Converge
