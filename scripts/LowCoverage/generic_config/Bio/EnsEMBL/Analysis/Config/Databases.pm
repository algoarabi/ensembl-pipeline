# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Pipeline::Config::GeneBuild::Databases - imports global variables used by EnsEMBL gene building

=head1 SYNOPSIS

    use Bio::EnsEMBL::Analysis::Config::Databases qw(  );

=head1 DESCRIPTION

Databases is a pure ripoff of humConf written by James Gilbert.

humConf is based upon ideas from the standard perl Env environment
module.

It imports and sets a number of standard global variables into the
calling package, which are used in many scripts in the human sequence
analysis system.  The variables are first decalared using "use vars",
so that it can be used when "use strict" is in use in the calling
script.  Without arguments all the standard variables are set, and
with a list, only those variables whose names are provided are set.
The module will die if a variable which doesn\'t appear in its
C<%Databases> hash is asked to be set.

The variables can also be references to arrays or hashes.

Edit C<%Databases> to add or alter variables.

All the variables are in capitals, so that they resemble environment
variables.

=head1 CONTACT

=cut


package Bio::EnsEMBL::Analysis::Config::Databases;

use strict;
use LowCoverageGeneBuildConf;
use vars qw( %Databases );

# Hash containing config info
%Databases = (
	      # We use several databases to avoid the number of connections to go over the maximum number
	      # of threads allowed by mysql. If your genome is small, you can probably use the same db 
	      # for some of these entries. However, reading and writing in the same db is not recommended.
	      
	      # database containing sequence plus features from raw computes
	      GB_DBHOST                  => $LC_DBHOST,
	      GB_DBNAME                  => $LC_DBNAME,
	      GB_DBUSER                  => $LC_DBro,
	      GB_DBPASS                  => '',
	      GB_DBPORT 		 => $LC_DBPORT,
	      # database containing the genewise genes (TGE_gw,similarity_genewise)
              GB_GW_DBHOST  => '',
              GB_GW_DBNAME  => '',
              GB_GW_DBUSER  => '',
              GB_GW_DBPASS  => '',
              GB_GW_DBPORT     => '',
	      # database containing the blessed genes if there are any
	      GB_BLESSED_DBHOST              => '',
	      GB_BLESSED_DBNAME              => '',
	      GB_BLESSED_DBUSER              => '',
	      GB_BLESSED_DBPASS              => '',
	      GB_BLESSED_DBPORT              => '',
	      # database where the combined_gw_e2g genes will be stored
	      # IMPORTANT: we should have copied the genewise genes to this db before hand:
	      GB_COMB_DBHOST                  => '',
	      GB_COMB_DBNAME                  => '',
	      GB_COMB_DBUSER                  => '',
	      GB_COMB_DBPASS                  => '',
	      GB_COMB_DBPORT     	      => '',
	      # database containing the cdnas mapped, to be combined with the genewises
	      # by putting this info here, we free up ESTConf.pm so that two analysis can
	      # be run at the same time
	      GB_cDNA_DBHOST                  => '',
	      GB_cDNA_DBNAME                  => '',
	      GB_cDNA_DBUSER                  => '',
	      GB_cDNA_DBPASS                  => '',
              GB_cDNA_DBPORT     	      => '',
	      # this db needs to have clone & contig & static_golden_path tables populated
	      GB_FINALDBHOST                  => $LC_DBHOST,
	      GB_FINALDBNAME                  => $LC_DBprefix."genebuild",
	      GB_FINALDBUSER                  => $LC_DBro,
	      GB_FINALDBPASS                  => '',
              GB_FINALDBPORT     	      => $LC_DBPORT,

	      # db to put pseudogenes in
	      PSEUDO_DBHOST                  => $LC_DBHOST,
	      PSEUDO_DBNAME                  => $LC_DBprefix."pseudo",
	      PSEUDO_DBUSER                  => $LC_DBUSER,
	      PSEUDO_DBPASS                  => $LC_DBPASS,
              PSEUDO_DBPORT     	     => $LC_DBPORT,
	     );

sub import {
  my ($callpack) = caller(0); # Name of the calling package
  my $pack = shift; # Need to move package off @_
  
  # Get list of variables supplied, or else
  # all of Databases:
  my @vars = @_ ? @_ : keys( %Databases );
  return unless @vars;
  
  # Predeclare global variables in calling package
  eval "package $callpack; use vars qw("
    . join(' ', map { '$'.$_ } @vars) . ")";
    die $@ if $@;


    foreach (@vars) {
	if ( defined $Databases{ $_ } ) {
            no strict 'refs';
	    # Exporter does a similar job to the following
	    # statement, but for function names, not
	    # scalar variables:
	    *{"${callpack}::$_"} = \$Databases{ $_ };
	} else {
	    die "Error: Databases: $_ not known\n";
	}
    }
}

1;