# Loader Mod

## for [Foundation](https://www.polymorph.games/foundation/)

```lua
    require 'mods/loader/loader'

    local loader = create({
        Id = 'loader', -- the folder Name
        Name = 'Loader',
        Author = 'lperlaki',
        Description = 'A loader to define your assets in JSON',
    })

    loader:log('Custom Logger')

    local mod = loader.Mod -- accese to the mod userdata

    mod:msgBox('Hey There!')

    loader:registerAsset('assets/fauntain.json') -- load Building defined in those Json files
    loader:registerAsset('assets/fauntain-part.json') 
```



### References

- [Foundation - Modding Documentation](https://www.polymorph.games/foundation/modding/start)