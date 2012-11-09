#SpectrumAnnotator 
SpectrumAnnotator is an effort to make a capable spectral annotation suite which results in clean and clear svg outputs. 

# Work
##Thus far
* SVG output
* y-scaling by ranges
* y log scale

##Todo: 
* Match object generator
* Bracket annotation for scaled regions
* peak labeling


#Usage examples: 
```ruby 
ruby lib/spectrum_annotator.rb -s m6803 -g --svg --scale 600,1000,5 591.73-68.03.txt
```

Or, you can scale multiple regions: 
```ruby 
ruby lib/spectrum_annotator.rb -s m6803 -g --svg --scale 200,400,10,600,1000,5 591.73-68.03.txt
```
