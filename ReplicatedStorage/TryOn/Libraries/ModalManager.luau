--!strict

--[[
	ModalManager - A simple library to handle displaying a single modal window at once.
--]]

local modalChangedBindable = Instance.new("BindableEvent")

local modals: { GuiObject } = {}

local function updateVisibility()
	for index, modal in modals do
		modal.Visible = index == #modals
	end
end

local ModalManager = {
	modalChanged = modalChangedBindable.Event,
}

function ModalManager.push(modal: GuiObject)
	local index = table.find(modals, modal)
	if index then
		table.remove(modals, index)
	end

	table.insert(modals, modal)
	modalChangedBindable:Fire(modals[#modals])

	updateVisibility()
end

function ModalManager.pop(modal: GuiObject)
	local index = table.find(modals, modal)
	if index then
		table.remove(modals, index)
	end

	modalChangedBindable:Fire(modals[#modals])

	modal.Visible = false
	updateVisibility()
end

function ModalManager.getModal(): GuiObject?
	return modals[#modals]
end

return ModalManager
