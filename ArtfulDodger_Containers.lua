local _, ns = ...
if select(3, UnitClass("player")) ~= 4 then return end

local containerItemIDs = {}
for _, itemID in ipairs({
    264475, 220376, 190954, 179311, 186161, 180522, 180533, 180532,
    169475, 121331, 116920, 119000, 118193, 88567, 68729, 45986,
    43624, 43622, 31952, 5760, 5759, 5758, 4638, 4637, 4636, 4634,
    4633, 204307, 4632, 234453, 168091, 262432, 187278, 19425, 191296,
    16882, 16883, 16884, 16885, 63349, 43575, 29569, 88165, 106895,
}) do
    containerItemIDs[itemID] = true
end

ns.ContainerItemIDs = containerItemIDs