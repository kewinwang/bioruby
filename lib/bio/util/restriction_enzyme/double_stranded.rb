#
# bio/util/restrction_enzyme/double_stranded.rb - DoubleStranded restriction enzyme sequence
#
# Author::    Trevor Wennblom  <mailto:trevor@corevx.com>
# Copyright:: Copyright (c) 2005-2007 Midwinter Laboratories, LLC (http://midwinterlabs.com)
# License::   Distributes under the same terms as Ruby
#
#  $Id: double_stranded.rb,v 1.2 2006/12/31 21:50:31 trevor Exp $
#
require 'pathname'
libpath = Pathname.new(File.join(File.dirname(__FILE__), ['..'] * 4, 'lib')).cleanpath.to_s
$:.unshift(libpath) unless $:.include?(libpath)

require 'bio/db/rebase'
require 'bio/util/restriction_enzyme'
require 'bio/util/restriction_enzyme/cut_symbol'
require 'bio/util/restriction_enzyme/single_strand'
require 'bio/util/restriction_enzyme/single_strand_complement'
require 'bio/util/restriction_enzyme/double_stranded/aligned_strands'
require 'bio/util/restriction_enzyme/double_stranded/cut_locations'
require 'bio/util/restriction_enzyme/double_stranded/cut_locations_in_enzyme_notation'

module Bio; end
class Bio::RestrictionEnzyme

#
# bio/util/restrction_enzyme/double_stranded.rb - DoubleStranded restriction enzyme sequence
#
# Author::    Trevor Wennblom  <mailto:trevor@corevx.com>
# Copyright:: Copyright (c) 2005-2007 Midwinter Laboratories, LLC (http://midwinterlabs.com)
# License::   Distributes under the same terms as Ruby
#
# A pair of +SingleStrand+ and +SingleStrandComplement+ objects with methods to
# add utility to their relation.
# 
# = Notes
#  * This is created by Bio::RestrictionEnzyme.new for convenience.
#  * The two strands accessible are +primary+ and +complement+.
#  * SingleStrand methods may be used on DoubleStranded and they will be passed to +primary+.
# 
class DoubleStranded
  include CutSymbol
  extend CutSymbol
  include StringFormatting
  extend StringFormatting

  # The primary strand
  attr_reader :primary

  # The complement strand
  attr_reader :complement

  # Cut locations in 0-based index format, DoubleStranded::CutLocations object
  attr_reader :cut_locations

  # Cut locations in enzyme index notation, DoubleStranded::CutLocationsInEnzymeNotation object
  attr_reader :cut_locations_in_enzyme_notation

  # [+erp+] One of three possible parameters:  The name of an enzyme, a REBASE::EnzymeEntry object, or a nucleotide pattern with a cut mark.
  # [+raw_cut_pairs+] The cut locations in enzyme index notation.
  #
  # Enzyme index notation:: 1.._n_, value before 1 is -1
  #
  # Examples of the allowable cut locations for +raw_cut_pairs+ follows.  'p' and
  # 'c' refer to a cut location on the 'p'rimary and 'c'omplement strands.
  #
  #   1, [3,2], [20,22], 57
  #   p, [p,c], [p, c],  p
  #
  # Which is the same as:
  #
  #   1, (3..2), (20..22), 57
  #   p, (p..c), (p..c),   p
  #
  # Examples of partial cuts:
  #   1, [nil,2], [20,nil], 57
  #   p, [p,  c], [p, c],   p
  #
  def initialize(erp, *raw_cut_pairs)
    # 'erp' : 'E'nzyme / 'R'ebase / 'P'attern
    k = erp.class

    if k == Bio::REBASE::EnzymeEntry
      # Passed a Bio::REBASE::EnzymeEntry object

      unless raw_cut_pairs.empty?
        err = "A Bio::REBASE::EnzymeEntry object was passed, however the cut locations contained values.  Ambiguous or redundant.\n"
        err += "inspect = #{raw_cut_pairs.inspect}"
        raise ArgumentError, err
      end
      initialize_with_rebase( erp )

    elsif erp.kind_of? String
      # Passed something that could be an enzyme pattern or an anzyme name

      # Decide if this String is an enzyme name or a pattern
      if Bio::RestrictionEnzyme.enzyme_name?( erp )
        # Check if it's a known name
        known_enzyme = false
        known_enzyme = true if Bio::RestrictionEnzyme.rebase[ erp ]

        # Try harder to find the enzyme
        unless known_enzyme
          re = %r"^#{erp}$"i
          Bio::RestrictionEnzyme.rebase.each { |name, v| (known_enzyme = true; erp = name; break) if name =~ re }
        end

        if known_enzyme
          initialize_with_rebase( Bio::RestrictionEnzyme.rebase[erp] )
        else
          raise IndexError, "No entry found for enzyme named '#{erp}'"
        end

      else
        # Not an enzyme name, so a pattern is assumed
        if erp =~ re_cut_symbol
          initialize_with_pattern_and_cut_symbols( erp )
        else
          initialize_with_pattern_and_cut_locations( erp, raw_cut_pairs )
        end
      end

    elsif k == NilClass
      err = "Passed a nil value.  Perhaps you tried to pass a Bio::REBASE::EnzymeEntry that does not exist?\n"
      err += "inspect = #{erp.inspect}"
      raise ArgumentError, err
    else
      err = "I don't know what to do with class #{k} for erp.\n"
      err += "inspect = #{erp.inspect}"
      raise ArgumentError, err
    end

  end

  # See AlignedStrands.align
  def aligned_strands
    AlignedStrands.align(@primary.pattern, @complement.pattern)
  end

  # See AlignedStrands.align_with_cuts
  def aligned_strands_with_cuts
    AlignedStrands.align_with_cuts(@primary.pattern, @complement.pattern, @primary.cut_locations, @complement.cut_locations)
  end

  # Returns +true+ if the cut pattern creates blunt fragments
  def blunt?
    as = aligned_strands_with_cuts
    ary = [as.primary, as.complement]
    ary.collect! { |seq| seq.split( cut_symbol ) }
    # convert the cut sections to their lengths
    ary.each { |i| i.collect! { |c| c.length } }
    ary[0] == ary[1]
  end

  # Returns +true+ if the cut pattern creates sticky fragments
  def sticky?
    !blunt?
  end

  #########
  protected
  #########

  def initialize_with_pattern_and_cut_symbols( s )
    p_cl = SingleStrand::CutLocationsInEnzymeNotation.new( strip_padding(s) )
    s = Bio::Sequence::NA.new( strip_cuts_and_padding(s) )

    # * Reflect cuts that are in enzyme notation
    # * 0 is not a valid enzyme index, decrement 0 and all negative
#    c_cl = p_cl.collect { |n| s.length - n }.collect { |n| n <= 0 ? n - 1 : n } #wrong.
    c_cl = p_cl.collect {|n| (n >= s.length or n < 1) ? ((s.length - n) - 1) : (s.length - n)}

    create_cut_locations( p_cl.zip(c_cl) )
    create_primary_and_complement( s, p_cl, c_cl )
  end

  def initialize_with_pattern_and_cut_locations( s, raw_cl )
    create_cut_locations(raw_cl)
    create_primary_and_complement( Bio::Sequence::NA.new(s), @cut_locations_in_enzyme_notation.primary, @cut_locations_in_enzyme_notation.complement )
  end

  def create_primary_and_complement(primary_seq, p_cuts, c_cuts)
    @primary = SingleStrand.new( primary_seq, p_cuts )
    @complement = SingleStrandComplement.new( primary_seq.forward_complement, c_cuts )
  end

  def create_cut_locations(raw_cl)
    @cut_locations_in_enzyme_notation = CutLocationsInEnzymeNotation.new( *raw_cl.collect {|cl| CutLocationPairInEnzymeNotation.new(cl)} )
    @cut_locations = @cut_locations_in_enzyme_notation.to_array_index
  end

  def initialize_with_rebase( e )
    p_cl = [e.primary_strand_cut1, e.primary_strand_cut2]
    c_cl = [e.complementary_strand_cut1, e.complementary_strand_cut2]

    # If there's no cut in REBASE it's represented as a 0.
    # 0 is an invalid index, it just means no cut.
    p_cl.delete(0)
    c_cl.delete(0)
    raise IndexError unless p_cl.size == c_cl.size
    initialize_with_pattern_and_cut_locations( e.pattern, p_cl.zip(c_cl) )
  end

end # DoubleStranded
end # Bio::RestrictionEnzyme
