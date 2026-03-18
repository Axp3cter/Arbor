--!strict
--!optimize 2
-- Server entry point for running tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage:WaitForChild("Arbor"):WaitForChild("test"))
