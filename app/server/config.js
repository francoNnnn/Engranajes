var config = {};

config.levels =  ['1-65d1-11e6-8b77-86f30ca893d3','2-a33a-427b-888f-3dcdc72427f6','3-7598-4330-8515-12015a4c6cd8',
    '4-57dc-44de-861b-c1a85f0ed44c','5-6a4b-4de8-8457-963f3dc0f5b5','6-9b5c-4fa5-94ab-5b54d9e6ba4c',
    '7-8c80-467d-b9a6-1fc45bf607b8','8-5501-4e23-96f9-fb0d5fb8c899','9-cf74-42b1-b9e1-70c0aa8cc81a',
    '10-124f-4e0b-b972-e98d95ab20c3','11-d4f3-47c3-94d1-e88d93a04643','12-ad9c-4df1-a720-3fb75b06255a'];

config.openLevelImagesArray =  ["1.png","2.png","3.png","4.png","5.png","6.png","7.png","8.png","9.png","10.png","11.png","12.png"];

config.doneLevelImagesArray = ["done1.png","done2.png","done3.png","done4.png","done5.png","done6.png","done7.png","done8.png","done9.png","done10.png","done11.png","done12.png"];

config.lockedLevelImagesArray = ["locked1.png","locked2.png","locked3.png","locked4.png","locked5.png","locked6.png","locked7.png","locked8.png","locked9.png","locked10.png","locked11.png","locked12.png"];

config.openLevelImages ={}
config.doneLevelImages ={}
config.lockedLevelImages ={}

config.levels.forEach(function (currentValue,i){
    config.openLevelImages[currentValue]=config.openLevelImagesArray[i]
    config.doneLevelImages[currentValue]=config.doneLevelImagesArray[i]
    config.lockedLevelImages[currentValue]=config.lockedLevelImagesArray[i]
})

config.unlockCode= "ox-unlock-code"
config.statsURL= "stats"

module.exports = config;