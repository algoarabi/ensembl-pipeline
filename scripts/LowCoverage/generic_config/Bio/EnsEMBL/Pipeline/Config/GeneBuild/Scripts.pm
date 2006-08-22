# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Pipeline::Config::GeneBuild::Scripts - imports global variables used by EnsEMBL gene building

=head1 SYNOPSIS
    use Bio::EnsEMBL::Pipeline::Config::GeneBuild::Scripts;
    use Bio::EnsEMBL::Pipeline::Config::GeneBuild::Scripts qw(  );

=head1 DESCRIPTION

Scripts is a pure ripoff of humConf written by James Gilbert.

humConf is based upon ideas from the standard perl Env environment
module.

It imports and sets a number of standard global variables into the
calling package, which are used in many scripts in the human sequence
analysis system.  The variables are first decalared using "use vars",
so that it can be used when "use strict" is in use in the calling
script.  Without arguments all the standard variables are set, and
with a list, only those variables whose names are provided are set.
The module will die if a variable which doesn\'t appear in its
C<%Scripts> hash is asked to be set.

The variables can also be references to arrays or hashes.

Edit C<%Scripts> to add or alter variables.

All the variables are in capitals, so that they resemble environment
variables.

=head1 CONTACT

=cut


package Bio::EnsEMBL::Pipeline::Config::GeneBuild::Scripts;

use strict;
use LowCoverageGeneBuildConf;
use vars qw( %Scripts );
use Bio::EnsEMBL::Pipeline::Config::GeneBuild::Targetted qw (
							     GB_TARGETTED_GW_GENETYPE
							    );

use Bio::EnsEMBL::Pipeline::Config::GeneBuild::Similarity qw (
							     GB_SIMILARITY_GENETYPE
							    );

use Bio::EnsEMBL::Pipeline::Config::GeneBuild::Combined qw (
							     GB_COMBINED_GENETYPE
							    );

use Bio::EnsEMBL::Pipeline::Config::GeneBuild::GeneBuilder qw (
							     GB_FINAL_GENETYPE
							    );

# Hash containing config info
%Scripts = (
	     # path to swissprot "evidence kill list" file - file of
	     # protein IDs that should not be used for building genes
	     # but have made it into the protein databases eg
	     # transposable elements 
	     # ie /path/to/ensembl-pipeline/scripts/GeneBuild/kill_list.txt
	    
	    GB_KILL_LIST   => $LC_KILL,

	    # information about the different protein sources used by new_prepare_proteome.pl,
	    # the header regex should be a regex to pull out the desired id from the fasta header

	    GB_PROTEOME_FILES => [
				  {
				   file_path => $LC_PROTEOME, 
				   header_regex => '^>\((\S+)\)',
				  },
				  #{
				  # file_path => 'swall',
				  # header_regex => '^>\S+\s+\((\S+)\)',
				  #},
				  #{
				  # file_path => 'refseq',
				  # header_regex => '^>\w+\|\w+\|\w+\|(\S+)\|',
				  #},
				 ],


	   );

sub import {
  my ($callpack) = caller(0); # Name of the calling package
  my $pack = shift; # Need to move package off @_
  
  # Get list of variables supplied, or else
  # all of Scripts:
  my @vars = @_ ? @_ : keys( %Scripts );
  return unless @vars;
  
  # Predeclare global variables in calling package
  eval "package $callpack; use vars qw("
    . join(' ', map { '$'.$_ } @vars) . ")";
    die $@ if $@;


    foreach (@vars) {
	if ( defined $Scripts{ $_ } ) {
            no strict 'refs';
	    # Exporter does a similar job to the following
	    # statement, but for function names, not
	    # scalar variables:
	    *{"${callpack}::$_"} = \$Scripts{ $_ };
	} else {
	    die "Error: Scripts: $_ not known\n";
	}
    }
}

1;