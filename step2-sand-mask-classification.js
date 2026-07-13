
//---Variables---
var classified = ‘projects/assets/supervised-March23’ //Add your asset path from the image classified in the previous step. 

var roi = yourRiver.geometry();    //Add your river extent shapefile in the imports

var bands = ['B2', 'B3', 'B4', 'B8', 'B11', 'B12'];
var allBands = ['NDVI', 'NDBI', 'MNDWI', 'NDMI', 'BCI', 'B2', 'B3', 'B4', 'NDWI', 'SNDVI', 'B8', 'B11', 'B12', 'homogeneity', 'entropy', 'contrast', 'dissimilarity', 
                'correlation', 'variance', 'asm', 'HAND'];

//---Palettes---

var sandPalette = [ "ffc800", //freshalluv(1)
'#371D10', //sandmining (2) 
'576d80', //wetsand (3)
"ff4d00", //fallow (4)
"99ca3c", //vegsand (5)
"c4c4c4", //bedrock (6) 
]; 

var landcoverPalette = [ 
"8ecae6", //watershlw (0)
"023047", //waterdeep (1)
"ffc800", //freshalluv (2)
"d08c60", //oldalluv (3)
"99ca3c", //agriveg (4)
"18392b", //genvegtn (5)
"grey" //bedrock (6)
];  

var viz = {min:1, max: 6, palette: landcoverPalette};
var viz1 = {bands: ['B4', 'B3', 'B2'], min: 0, max: 0.3};
var viz2 = {bands: ['B8', 'B4', 'B3'], min: 0 , max: 0.3};

var freshalluv = 3;
var oldalluv = 4;
var bedrock = 7;

//---Getting the image---

// Function to mask clouds at the pixel level

function maskS2clouds(image) {
  var scl = image.select('SCL');
  var mask = scl.neq(3)  // cloud shadow
    .and(scl.neq(8))     // cloud medium prob
    .and(scl.neq(9))     // cloud high prob
    .and(scl.neq(10))    // cirrus
  return image.updateMask(mask);
}

// Sentinel set up with feature stack

//Hand
var hand = ee.ImageCollection("users/gena/global-hand/hand-100")
            .mosaic()
            .rename('HAND')
            .clip(roi);

//S2
var S2 = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED');

function S2_Collection(year, month){
  month = ee.Number(month);                 

  var start = ee.Date.fromYMD(year, month, 1);
  var end   = start.advance(1, 'month');    

  var raw = S2.filterBounds(roi)
              .filterDate(start, end)
              .map(maskS2clouds)
              .select(bands)
              .median()
              .clip(roi);

  var col = raw.divide(10000);

  var ndvi  = col.normalizedDifference(['B8',  'B4']).rename('NDVI');
  var sndvi  = col.normalizedDifference(['B11',  'B4']).rename('SNDVI');
  var ndwi  = col.normalizedDifference(['B3',  'B8']).rename('NDWI');
  var ndbi  = col.normalizedDifference(['B11', 'B8']).rename('NDBI');
  var ndmi = col.normalizedDifference(['B8', 'B11']).rename('NDMI');
  var mndwi = col.normalizedDifference(['B3',  'B12']).rename('MNDWI');
  var bci = col.expression(
    '((swir + red) - (nir + blue))/ ((swir + red) + (nir + blue))',{
      swir: col.select('B11'),
      red: col.select('B4'),
      nir: col.select('B8'),
      blue: col.select('B2')
    }).rename('BCI');
  var gray = col.select('B8')
              .multiply(10000)
              .divide(500)
              .toInt32();
  var glcm = gray.glcmTexture({size: 3});
  var homogeneity = glcm.select('B8_idm').rename('homogeneity');
  var entropy = glcm.select('B8_ent').rename('entropy');
  var contrast    = glcm.select('B8_contrast').rename('contrast');
  var dissimilarity = glcm.select('B8_diss').rename('dissimilarity');
  var correlation = glcm.select('B8_corr').rename('correlation');
  var variance    = glcm.select('B8_var').rename('variance');
  var asm         = glcm.select('B8_asm').rename('asm');  

  return col
    .addBands([ndvi, ndbi, mndwi, bci, ndmi, ndwi, sndvi,
               entropy, homogeneity, contrast, dissimilarity,
               correlation, variance, asm, hand])
      
    .set({
      'year':  year,
      'month': month,
      'start': start.format('YYYY-MM-dd'),
      'end':   end.format('YYYY-MM-dd')
    });
}

//Imagery calling (add more years as per your requirement)

var imagery23 = S2_Collection(2023, 3);

//---Image Mask---

var sandMask23 = classified.eq(freshalluv).or(classified.eq(oldalluv)).or(classified.eq(bedrock));

var sandImagery23 = imagery23.select(allBands).updateMask(sandMask23);

//Samples---add your training and accuracy samples in the geometries section

var samples = freshsand.merge(wetsand).merge(sandmine).merge(fallow).merge(rock).merge(vegsand);
var accuracy = freshsand23.merge(wetsand23).merge(sandmine23).merge(fallow23).merge(rock23).merge(vegsand23);

var training = sandImagery23.sampleRegions({
  collection: samples,
  properties: ['class'], 
  scale: 10,
  tileScale: 4
});

//Classification using GB

var GBclassifier = ee.Classifier.smileGradientTreeBoost({
  numberOfTrees: 200,
  shrinkage: 0.05,
  samplingRate: 0.7,
  maxNodes: 32,
  seed: 42
}).train({
  features: training,
  classProperty: 'class',
  inputProperties: allBands
});

var gbMar23 = sandImagery23.select(allBands).classify(GBclassifier)

// Sample the classified image at accuracy assessment points

var GBvalidated = gbMar23.sampleRegions({
  collection: accuracy,
  properties: ['class'],
  scale: 10,
  tileScale: 4
});

// Get the error matrix comparing predicted vs actual classes
var GBerrorMatrix = GBvalidated.errorMatrix('class', 'classification');

// Print results to console

// print('GB Error Matrix:', GBerrorMatrix);
// print('GB Overall Accuracy:', GBerrorMatrix.accuracy());
// print('GB Kappa Coefficient:', GBerrorMatrix.kappa());
// print('GB Producers Accuracy (per class):', GBerrorMatrix.producersAccuracy());
// print('GB Consumers Accuracy (per class):', GBerrorMatrix.consumersAccuracy());

//--------------------Visualization of Layers----------
Map.addLayer(classified, {min: 1, max: 7, palette: landcoverPalette}, "Supervised")
Map.addLayer(sandMask23, {min: 0, max: 1, palette: ["white", "ffc800"]}, "Sand Mask23")
Map.addLayer(imagery23, viz1, "Image23");

//---Sand Only Imagery Layers---
//Map.addLayer(sandImagery23, viz1, "Sand23");

//GB layers
//Map.addLayer(gbMar23, viz, "GB Full 23");

//Exports

// Export.image.toDrive({
//   image: gbMar23,
//   scale: 10,
//   maxPixels: 1e13,
//   region: roi,
//   description: "gb-sand-23”
// });

// Export.table.toDrive({
//   collection: results,
//   description: "c-mining-area-gb-rf",
//   fileFormat: "CSV"
// });

Export.table.toAsset({
  collection: accuracy,
  description: "c-accuracy-mar22",
})


