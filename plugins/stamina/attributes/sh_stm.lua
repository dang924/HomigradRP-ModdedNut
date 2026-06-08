ATTRIBUTE.name = "Stamina"
ATTRIBUTE.desc = "Affects how fast you can run."

function ATTRIBUTE:onSetup(client, value)
	if (HGRP and HGRP.ApplyOrganismAttributes) then
		HGRP.ApplyOrganismAttributes(client)
	end
end