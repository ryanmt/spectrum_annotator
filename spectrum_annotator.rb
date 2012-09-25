require 'gnuplot'
# Debugging
require 'pry'
require 'optparse'

parser = OptionParser.new do |opts|
	opts.banner = "Usage: input files of the txt variety, containing a single spectra.  The spectra should be referenced internally in the source code for now"
	opts.on('-s', '--svg', "Make an output svg file.  The name of this file will be the input file with an '_output.svg' appended.") do |s|
		options[:svg] = s 
	end
	opts.on('-g', '--group', "Group by pattern types in the colorations rather than the individual ion matches") do |g|
		options[:group_by_pattern] = g
	end
end



sequence = "FCGLCVCPCNK"
options = {svg: true}
SpectrumAnnotation = Struct.new(:mass, :pattern_symbol, :class_symbol, :sequence_string, :annotation_string)

m6803 = [[774.60,:cross_over, :triple_backbone, "hL3V%hh+P4NKoh", "LC2V-PC4NK"],[831.60, :cross_over, :triple_backbone, "hGL3V%hh+P4NKoh", "GLC2V-PC4NK"]].map {|a| SpectrumAnnotation.new(*a)}
m7194 = [[375.00, :open, :double_backbone, '"h1GL2+"", "', 'C1GLC2'], 
  [522.00, :open, :single_backbone, "hF1%hGL2+", "FC1GLC2"], 
  [562.20, :open,   :single_backbone, "h3+hP4NKoh", "C3PC4NK"],
  [621.0, :open, :single_backbone, "hF1%hGL2V", "FC1GLC2V"], 
  [661.20, :open, :single_backbone, "hV3+hP4NKoh", "VC3PC4NK"]].map {|a| SpectrumAnnotation.new(*a)}
m7790 = [[661.20, :open, :single_backbone, "hV3+nP4NKoh", "VC3PC4NK"], 
  [304.20, :parallel, :double_backbone, "h3V4+", "C2VC3"], 
  [766.20, :parallel, :double_backbone, "hF1G+hP2NKoh", "FC1G-PC4NK"], 
  [879.60, :parallel, :double_backbone, "hF1GL+hP2NKoh", "FC1GL-PC4NK"]].map {|a| SpectrumAnnotation.new(*a)}

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
input_arr = m7194
input_file = ARGV.shift

test_data = spectrum_from_tsv_file(input_file)
masses = input_arr.map(&:mass)
patterns = Hash.new
input_arr.map(&:pattern_symbol).uniq.map{|pattern| patterns[pattern] = Color_choices.shift }
matches = []
p test_data.size
masses.each do |mass| 
  test_data.delete_if {|a| matches << a if (a.first.to_f-Tolerance..a.first.to_f+Tolerance).include? mass }
end
p test_data.size
# Open the graph
Gnuplot.open do |gp|
  Gnuplot::Plot.new(gp) do |plot|
    if options[:svg] 
      plot.output File.basename(input_file) + "_graphed.svg"
      plot.terminal 'svg'
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
