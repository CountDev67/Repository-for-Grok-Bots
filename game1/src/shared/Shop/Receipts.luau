--!strict
-- Idempotent dev-product handler.
-- Grant at most once per PurchaseId. Return PurchaseGranted only after save()
-- succeeds. A failed save leaves the grant in memory and returns NotProcessedYet
-- so the next call saves it without granting again.

local Receipts = {}

export type Receipt = {
	PurchaseId: string,
	ProductId: number,
}

export type Callbacks = {
	grant: () -> boolean,
	save: () -> boolean,
	now: () -> number,
}

function Receipts.Process(
	receipts: { [string]: any },
	receipt: Receipt,
	callbacks: Callbacks
): string
	if
		type(receipt) ~= "table"
		or type(receipt.PurchaseId) ~= "string"
		or receipt.PurchaseId == ""
	then
		return "NotProcessedYet"
	end
	if type(receipt.ProductId) ~= "number" then
		return "NotProcessedYet"
	end

	if receipts[receipt.PurchaseId] ~= nil then
		if callbacks.save() == true then
			return "PurchaseGranted"
		end
		return "NotProcessedYet"
	end

	local granted = false
	local ok, result = pcall(callbacks.grant)
	if ok and result == true then
		granted = true
	end
	if not granted then
		return "NotProcessedYet"
	end

	receipts[receipt.PurchaseId] = {
		productId = receipt.ProductId,
		at = callbacks.now(),
	}
	if callbacks.save() == true then
		return "PurchaseGranted"
	end
	return "NotProcessedYet"
end

return Receipts
