#
# bio/util/restrction_enzyme/double_stranded/aligned_strands.rb - 
#
# Author::    Trevor Wennblom  <mailto:trevor@corevx.com>
# Copyright:: Copyright (c) 2005-2007 Midwinter Laboratories, LLC (http://midwinterlabs.com)
# License::   Distributes under the same terms as Ruby
#
#  $Id: aligned_strands.rb,v 1.2 2006/12/31 21:50:31 trevor Exp $
#
require 'pathname'
libpath = Pathname.new(File.join(File.dirname(__FILE__), ['..'] * 5, 'lib')).cleanpath.to_s
$:.unshift(libpath) unless $:.include?(libpath)

require 'bio/util/restriction_enzyme/single_strand'
require 'bio/util/restriction_enzyme/cut_symbol'
require 'bio/util/restriction_enzyme/string_formatting'

module Bio; end
class Bio::RestrictionEnzyme
class DoubleStranded

#
# bio/util/restrction_enzyme/double_stranded/aligned_strands.rb - 
#
# Author::    Trevor Wennblom  <mailto:trevor@corevx.com>
# Copyright:: Copyright (c) 2005-2007 Midwinter Laboratories, LLC (http://midwinterlabs.com)
# License::   Distributes under the same terms as Ruby
#
# Align two SingleStrand::Pattern objects and return a Result
# object with +primary+ and +complement+ accessors.
#
class AlignedStrands
  extend CutSymbol
  extend StringFormatting

  # The object returned for alignments
  Result = Struct.new(:primary, :complement)

  # Pad and align two String objects.
  #
  # +a+:: First String
  # +b+:: Second String
  #
  # Example invocation:
  #   AlignedStrands.align('nngattacannnnn', 'nnnnnctaatgtnn')
  #
  # Example return value:
  #   #<struct Bio::RestrictionEnzyme::DoubleStranded::AlignedStrands::Result
  #    primary="nnnnngattacannnnn",
  #    complement="nnnnnctaatgtnnnnn">
  #
  def self.align(a, b)
    a = a.to_s
    b = b.to_s
    validate_input( strip_padding(a), strip_padding(b) )
    left = [left_padding(a), left_padding(b)].sort.last
    right = [right_padding(a), right_padding(b)].sort.last

    p = left + strip_padding(a) + right
    c = left + strip_padding(b) + right
    Result.new(p,c)
  end

  # Pad and align two String objects with cut symbols.
  #
  # +a+:: First String
  # +b+:: Second String
  # +a_cuts+:: First strand cut locations in 0-based index notation
  # +b_cuts+:: Second strand cut locations in 0-based index notation
  #
  # Example invocation:
  #   AlignedStrands.with_cuts('nngattacannnnn', 'nnnnnctaatgtnn', [0, 10, 12], [0, 2, 12])
  #
  # Example return value:
  #   #<struct Bio::RestrictionEnzyme::DoubleStranded::AlignedStrands::Result
  #    primary="n n n n^n g a t t a c a n n^n n^n",
  #    complement="n^n n^n n c t a a t g t n^n n n n">
  #
  # Notes:
  # * To make room for the cut symbols each nucleotide is spaced out.
  # * This is meant to be able to handle multiple cuts and completely
  #   unrelated cutsites on the two strands, therefore no biological
  #   shortcuts are made.
  #
  def self.align_with_cuts(a,b,a_cuts,b_cuts)
    a = a.to_s
    b = b.to_s
    validate_input( strip_padding(a), strip_padding(b) )

    a_left, a_right = left_padding(a), right_padding(a)
    b_left, b_right = left_padding(b), right_padding(b)

    left_diff = a_left.length - b_left.length
    right_diff = a_right.length - b_right.length

    (right_diff > 0) ? (b_right += 'n' * right_diff) : (a_right += 'n' * right_diff.abs)

    a_adjust = b_adjust = 0

    if left_diff > 0
      b_left += 'n' * left_diff
      b_adjust = left_diff
    else
      a_left += 'n' * left_diff.abs
      a_adjust = left_diff.abs
    end

    a = a_left + strip_padding(a) + a_right
    b = b_left + strip_padding(b) + b_right

    a_cuts.sort.reverse.each { |c| a.insert(c+1+a_adjust, cut_symbol) }
    b_cuts.sort.reverse.each { |c| b.insert(c+1+b_adjust, cut_symbol) }

    Result.new( add_spacing(a), add_spacing(b) )
  end

  #########
  protected
  #########

  def self.validate_input(a,b)
    unless a.size == b.size
      err = "Result sequences are not the same size.  Does not align sequences with differing lengths after strip_padding.\n"
      err += "#{a.size}, #{a.inspect}\n"
      err += "#{b.size}, #{b.inspect}"
      raise ArgumentError, err
    end
  end
end # AlignedStrands
end # DoubleStranded
end # Bio::RestrictionEnzyme
