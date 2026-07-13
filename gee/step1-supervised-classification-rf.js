//Preliminary supervised classification using RF

//Add your ROI into imports

//Getting the images
var roi = yourRiverROI.geometry();
Map.centerObject(roi, 10);

var bands = ['B2', 'B3', 'B4', 'B8', 'B11', 'B12'];
var landcoverPalette = [ 
"8ecae6", //watershlw (0)
"023047", //waterdeep (1)
"ffc800", //freshalluv (2)
"d08c60", //oldalluv (3)
"99ca3c", //agriveg (4)
"18392b" //genvegtn (5)
// "821415" //builtup (6)
];  

// Function to mask clouds using SCL
function maskS2clouds(image) {
  var scl = image.select('SCL');
  var mask = scl.neq(3)  // cloud shadow
    .and(scl.neq(8))     // cloud medium prob
    .and(scl.neq(9))     // cloud high prob
    .and(scl.neq(10));    // cirrus
  return image.updateMask(mask);
}

//Calling Sentinel S2 dataset
var S2 = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED');


//Function to get S2 images for year(s) and month(s) of choice
function S2_Collection(year, month){
  month = ee.Number(month);                 // 1..12

  var start = ee.Date.fromYMD(year, month, 1);
  var end   = start.advance(1, 'month');    // next month start

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
  var mndwi = col.normalizedDifference(['B3',  'B12']).rename('MNDWI');

  return col.addBands([ndvi, ndwi, ndbi, mndwi, sndvi]).set({
    'year': year,
    'month': month,
    'start': start.format('YYYY-MM-dd'),
    'end': end.format('YYYY-MM-dd')
  });
}

//Example: calling one of the images for March 2023:
var March2023 = S2_Collection(2023, 3);


//Visualisations to display on map
var vis = {bands: ['B4', 'B3', 'B2'], min: 0, max: 0.3}; //True colour
var vis1 = {bands: ['B8', 'B4', 'B3'], min: 0, max: 0.3}; //NRG
var vis2 = {bands: ['B12', 'B8', 'B4'], min: 0, max: 0.3}; //SNR

//Display Maps (different visualizations to help sample collection)

Map.addLayer(March2023, vis, "S2 2023 March", false);
Map.addLayer(March2023, vis1, "S2 2023 March", false);
Map.addLayer(March2023, vis2, "S2 2023 March", false);

//Create training data (create samples by creating feature collections in geometry imports)
//Label the feature with 'classID', change names of geometries below as per your convenience

var marchTrainingPoints = watershlw.merge(waterdeep).merge(agriveg).merge(freshalluv).merge(oldalluv).merge(genveg); //merge training data

//Train samples on the image and create classifier
var trainingSamples = March2023.select(bands).sampleRegions({
  collection: marchTrainingPoints,
  properties: ['classID'],
  scale: 10,
  geometries: true
});

var classifier = ee.Classifier.smileRandomForest(100).train({
  features: trainingSamples,
  classProperty: 'classID',
  inputProperties: bands
});

//Classify image(s)
var cMarch23 = March2023.select(bands).classify(classifier);

//View result
Map.addLayer(cMarch23, {min: 1, max: 6, palette: landcoverPalette}, "Mar 23 Classified");

//Export the Images to asset

Export.image.toAsset({
  image: cMarch23,
  description: "supervised-March23",
  scale: 10,
  maxPixels: 1e13
  })
