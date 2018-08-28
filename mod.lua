require 'mods/loader/loader'

local loader = create({
    Id = 'loader', -- the folder Name
    Name = 'Loader',
    Author = 'lperlaki',
    Description = 'A loader to define your assets in JSON',
})


-- Register You JSON defined Building Here
loader:registerAsset('assets/fauntain.json') 
loader:registerAsset('assets/fauntain-part.json') 
