--!strict
-- Config: the one way code reads tunable data (plan section 4.9, ADR 0017).
--
-- Loads every data file through `Sources`, checks it against `Schema` and deep-freezes it. A bad value stops the game
-- at startup with a message naming the file, field and allowed range. The check runs the same rules first, so in
-- practice a bad value never reaches Studio.
--
-- State owned: none. The returned tables are frozen.
--
-- Usage:
--     local Config = require(ReplicatedStorage.Shared.Config)  -- or require("../Config") from shared code
--     local rate = Config.Tuning.Timing.simRate

local Freeze = require("./Util/Freeze")
local Schema = require("@self/Schema")
local Sources = require("@self/Sources")
local Types = require("./Types/Config")

local problems = Schema.validate(Sources)
if #problems > 0 then
	error(Schema.report(problems), 0)
end

local Config: Types.Config = Freeze.deep(Sources)

return Config
