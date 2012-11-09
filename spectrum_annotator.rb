require 'gnuplot'
# Debugging
require 'pry'
require 'optparse'
options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: input files of the txt variety, containing a single spectra.  The spectra should be referenced internally in the source code for now"
  opts.on('-s', '--svg', "Make an output svg file.  The name of this file will be the input file with an '_output.svg' appended.") do |s|
    options[:svg] = s 
  end
  opts.on('-g', '--group', "Group by pattern types in the colorations rather than the individual ion matches") do |g|
    options[:group_by_pattern] = g
  end
  opts.on('--[no-]color', "Output only a single color") do |c|
    options[:single_color] = c
  end
  opts.on('-y', '--y_log', 'Change the y axis to a logscale') do |y|
    options[:y_log] = y
  end
  opts.on('--scale start_mz,stop_mz,scale_factor',  String, "Takes a string which will be split on comma to make lists of three attributes: a start m/z, a stop m/z value, and the scaling factor (e.g. 5x)") do |string|
    list = string.split(',')
    if list.size % 3 != 0
      puts "Incorrect scale input, Exiting..."
      puts opts
      break
    end
    options[:scale_ranges] = list.map(&:to_i).each_slice(3).map(&:to_a)
  end
  opts.on('-s string', '--string', String, "pattern string, pick from m6803, m7194, m7790") do |s|
    options[:string] = s
  end
end



sequence = "FCGLCVCPCNK"
parser.parse!
SpectrumAnnotation = Struct.new(:mass, :pattern_symbol, :class_symbol, :sequence_string, :annotation_string)

m6803 = [[774.60,:cross_over, :triple_backbone, "hL3V%hh+P4NKoh", "LC2V-PC4NK"],
  [831.60, :cross_over, :triple_backbone, "hGL3V%hh+P4NKoh", "GLC2V-PC4NK"]].map {|a| SpectrumAnnotation.new(*a)}
m7194 = [[375.00, :open, :double_backbone, '"h1GL2+"", "', 'C1GLC2'], 
  [522.00, :open, :single_backbone, "hF1%hGL2+", "FC1GLC2"], 
  [562.20, :open,   :single_backbone, "h3+hP4NKoh", "C3PC4NK"],
  [621.0, :open, :single_backbone, "hF1%hGL2V", "FC1GLC2V"], 
  [661.20, :open, :single_backbone, "hV3+hP4NKoh", "VC3PC4NK"]].map {|a| SpectrumAnnotation.new(*a)}
m7790 = [[661.20, :open, :single_backbone, "hV3+nP4NKoh", "VC3PC4NK"], 
  [304.20, :parallel, :double_backbone, "h3V4+", "C2VC3"], 
  [766.20, :parallel, :double_backbone, "hF1G+hP2NKoh", "FC1G-PC4NK"], 
  [879.60, :parallel, :double_backbone, "hF1GL+hP2NKoh", "FC1GL-PC4NK"]].map {|a| SpectrumAnnotation.new(*a)}
Annotations = { 'm6803' => m6803, 'm7194' => m7194, 'm7790' => m7790 }
# retrieve raw spectra from tsv file
def spectrum_from_tsv_file(file)
  spectrum = File.readlines(file).map do |line|
    line.chomp.split("\t").map(&:to_f).flatten
  end
  spectrum#.transpose
end

# Pre-processing(sorting matches out into the colored arrays)
Tolerance = 0.3
Color_choices = [1,3,8,10,12,16,20,28,29,30,27,36,37,43,31]
# Prepare data
if options[:string]
  input_arr = Annotations[options[:string]]
else
  puts "Abort: no string given"
  exit
end

input_file = ARGV.shift

test_data = spectrum_from_tsv_file(input_file)
masses = input_arr.map(&:mass)
patterns = Hash.new
input_arr.map(&:pattern_symbol).uniq.map{|pattern| patterns[pattern] = Color_choices.shift }
matches = []
p test_data.size

tmp = test_data.dup
if options[:scale_ranges]
  puts "I'm scaling the following ranges for you.  You may have to draw an indicator onto the plot yourself, and at the very least, you probably have to indicate the scaling factor"
  options[:scale_ranges].each do |scaler|
    range = scaler[0]..scaler[1]
    scale = scaler[2]
    test_data.map! do |arr|
      #range.include?(arr.first) ? [arr.first, arr.second * scale] : arr
      if range.include?(arr.first) 
        puts "range includes"
        [arr[0], arr[1] * scale] 
      else 
        arr
      end
    end
  end
end
# Make the matches
p test_data.size
masses.each do |mass| 
  test_data.delete_if {|a| matches << a if (a.first.to_f-Tolerance..a.first.to_f+Tolerance).include? mass }
end
p tmp - test_data


if options[:group_by_pattern]
  puts "patterns look like this: #{patterns}"
end
outfile_additions = []
outfile_additions << "y-log" if options[:y_log]
if options[:scale_ranges]
  txt = options[:scale_ranges].map {|a| a.join('-')}.join("_")
  p txt
  outfile_additions << "y-scaled_#{txt}" 
end

# Open the graph
Gnuplot.open do |gp|
  Gnuplot::Plot.new(gp) do |plot|
    if options[:svg] 
      outfile = File.basename(input_file).sub('.txt', '_') + outfile_additions.join("_") + "_graphed.svg"
      puts "SVG output file is: #{outfile}"
      plot.output outfile
      plot.terminal 'svg'
    end 
    if options[:y_log]
      plot.logscale 'y'
      plot.yrange "[10:10000]"
    end

    plot.xrange "[200:1200]"
    plot.data << Gnuplot::DataSet.new(test_data.transpose) do |ds|
      ds.with = 'impulse lt 9'
      ds.title = 'raw'
      ds.linewidth = 1
    end
    input_arr.each_with_index do |match, i|
      unless matches.empty? or matches[i].nil?
	if matches[i].first.class == Array
	  input = matches[i].transpose
	else
	  input = matches[i]
	  input = [[input[0]], [input[1]]]
	end
  
	plot.data << Gnuplot::DataSet.new(input) do |ds|
	  if options[:group_by_pattern]
	    ds.with = "impulse lt #{patterns[match.pattern_symbol]}"
	  else 
	    ds.with = "impulse lt #{Color_choices[i]}"
	  end
	  ds.linewidth = 2
	  ds.title = match.annotation_string
	end
      end
    end
  end
end
