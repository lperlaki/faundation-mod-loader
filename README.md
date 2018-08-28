# Loader Mod

## for [Foundation](https://www.polymorph.games/foundation/)

### Example

mod.lua
```lua
require 'mods/loader/loader' -- load the Loader

initalise your mod With this Wrapper function
local loader = create({
    Id = 'NAMESPACE', -- the folder Name
    Name = 'MY-MOD',
    Author = 'ATUHOR',
    Description = 'A Mod that adds Stuff',
})

loader:log('Custom Logger')

local mod = loader.Mod -- accese to the mod userdata

mod:msgBox('Hey There!')

-- load your Json defined Assets
loader:registerAsset('assets/fauntain.json')
loader:registerAsset('assets/fauntain-part.json') 
```
assets/fauntain.json
```json
{
    "DataType": "BUILDING",
    "Id": "JSON_FOUNTAIN",
    "Name": "JSON_MOD_FOUNTAIN",
    "Description": "JSON_MOD_FOUNTAIN",
    "BuildingType": "DECORATION",
    "BuildingPartList": [ "JSON_FOUNTAIN_PART" ],
    "VillagerRequired": { "Status": "NEWCOMER", "Quantity": 1 }
}
```

assets/fauntain-part.json
```json
{
    "DataType": "BUILDING_PART",
    "Id": "JSON_FOUNTAIN_PART",
    "Description": "",
    "ConstructorData": {
        "DataType": "DEFAULT_BUILDING_CONSTRUCTOR",
        "CoreObjectPrefab": "JSON_PREFAB_FOUNTAIN"
    },
    "BuildingZone": [ 5, 5 ],
    "ConstructionVisual": "JSON_PREFAB_FOUNTAIN_CONSTRUCTION",
    "Cost": {
        "UpkeepCost": [
            { "Resource": "GOLD", "Quantity": 5 }
        ],
        "RessourcesNeeded": [
            { "Resource": "WOOD", "Quantity": 5 },
            { "Resource": "STONE", "Quantity": 10 }
        ]
    },
    "Models": {
        "JSON_PREFAB_FOUNTAIN": "assets/models/fountain.fbx/Prefab/Fountain",
        "JSON_PREFAB_FOUNTAIN_CONSTRUCTION": "assets/models/fountain.fbx/Prefab/Fountain_Construction_Steps"
    }
}
```

### References

- [Foundation - Modding Documentation](https://www.polymorph.games/foundation/modding/start)
