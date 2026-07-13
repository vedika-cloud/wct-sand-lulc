The workflow developed here has two steps in Google Earth Engine:
    Step 1: This step involves doing a preliminary classification of a riverine ecosystem and separating out classes of water, soil and vegetation.
    Step 2: Step 2 takes the classification done in Step 1 and uses it to create a mask for only the categories related to sand. After that, training points are taken for various classes of sand, including fresh sand, sand mining, bedrock, vegetated sand and fallow land. A classification is done using the gradient booster algorithm.

The training data is exported in Step 2 along with the spectral and feature value information across each point. 
This data was imported into R and used to conduct a CART analysis. 

The area of each land cover type is taken along with the accuracy and confusion matrixes for each land cover and error-adjusted area is found using the protocol in Olofsson et al 2014. 
