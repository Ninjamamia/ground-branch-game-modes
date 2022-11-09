--
-- Bunch of useful functions
--
-- NB: Requiring this file will probably set some globals...
--

local Tables = require('Common.Tables')

function toboolean(value)
	return not not value
end

function printf(...)
	print(sprintf(...))
end

function sprintf(...)
	return string.format(...)
end

function debugTable(tbl, label)
	if label ~= nil then
		print(label .. Tables.debug(tbl))
	else
		print(Tables.debug(tbl))
	end
end
