#!/usr/local/ensembl/bin/perl -w

=head1 NAME

make_input_ids_for_similarity_build 

=head1 SYNOPSIS

make_input_ids_for_similarity_build.pl

=head1 DESCRIPTION

This script generates input ids for the similarity gene build, allowing
more effective distribition of similarity jobs across a compute farm.

The overall aim is to align a set of proteins (determined by a sequence seeding 
strategy that is performed at raw compute stage, most commonly by BLASTing the
genscan peptides against SWALL) against a chromosome. There are two ways of 
distributing this work:

1. Spiltting the chromosome up into chunks. This is the classical method. The
drawback is that (a) it is difficult to know in advance what the granulatity 
of the split is. Too large and the jobs may take too long to complete; too
small and we increase the chances of a split occurring in the middle of a 
gene. This script attempts to split the chromosomes (by way of input_id construction)
heuristically in the hope of arriving at an effective distribution of work. 

2. Partitioning the chromosomes based on the protein features. In the past, 
this has been difficult to do due to the way that Runnables/RunnableDBs work.
However, I have added functionality to the FPC_BlastMiniGenewise runnable (to
start with) that is able to make use of a more heavily loaded input id. Specifically,
input_ids of the form

chr_name.start-end:10:3

are now supported. A single job receiving this input id will only align the
3rd subset of 10 (in this case) of the proteins hitting the genomic slice. 
The RunnableDB determinisitcally sorts all the protein ids in hitting this 
region, divides the list onto 10 bins, and considers only the 3rd bin. By
construction, for a given genomic slice, there will be X ids of the form 
slice_id.start.end:X:Y, ranging from slice_id.start.end:X:1 to slice_id.start.end:X:X. 
X can be different for each slice, and is chosen heuristically in this script based on 
the number of proteins hitting the slice. 

NOTE: The current version of this script adopts strategy (2); the 
standard raw compute pipeline currently generates sequence seeds that 
are not exhaustive enough at the level of individual alignments for
(1) to be performed with any accuracy.  A comprehensive BLAST search at 
the raw compute stage would allow (1); currently being investigated. 


=head1 OPTIONS

=head1 EXAMPLES

=cut

use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Utils::InputIDFactory;
use Bio::EnsEMBL::Pipeline::DBSQL::StateInfoContainer;

use Bio::EnsEMBL::Pipeline::Config::GeneBuild::Databases qw (
							     GB_DBNAME
							     GB_DBHOST
							     GB_DBUSER
							     GB_DBPASS
							     GB_DBPORT
							    );

use Bio::EnsEMBL::Pipeline::Config::GeneBuild::Similarity qw (
							      GB_SIMILARITY_DATABASES
							    );

use strict;
use Getopt::Long;

my (
    $write,
    $help,
    $verbose,
    $max_slice_size,
    $logic_name);

&GetOptions(
	    'logic_name=s' => \$logic_name,
	    'write'        => \$write,
	    'help'         => \$help,
	    'max_slice=s'  => \$max_slice_size,
	    'verbose'      => \$verbose
);
exec('perldoc', $0) if $help;

die "Could must give a logic name with -logic_name\n" if not $logic_name;


foreach my $arg($GB_DBNAME, $GB_DBHOST, $GB_DBUSER ){
  if ($arg eq '' ){
    print STDERR "You need to set various parameters in GeneBuild config files\n" .  
      "Here are your current values for required settings: \n" .
      "dbname      => $GB_DBNAME\n" .
      "dbhost      => $GB_DBHOST\n" .
      "dbuser      => $GB_DBUSER\n" .
      "dbpass      => $GB_DBPASS\n" . 
      "dbport      => $GB_DBPORT\n";
    
    exit(1);
  }
}

my $db = Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor->new(
	'-dbname' => $GB_DBNAME,
	'-host'   => $GB_DBHOST,
	'-user'   => $GB_DBUSER,
	'-pass'   => $GB_DBPASS,
	'-port'   => $GB_DBPORT

) or die "Could not connect to the pipeline database; check config\n";

my $analysis = $db->get_AnalysisAdaptor->fetch_by_logic_name($logic_name);
if (not $analysis) {
    die "Could not find analysis for $logic_name\n";
}

my ($ana_id, $ana_type) = ($analysis->dbID, $analysis->input_id_type);
if (not $ana_type) {
    die "Could not find dbID/input_id_type for $logic_name\n";
}    

$max_slice_size = 5000000 if not $max_slice_size;

my $sl_adp = $db->get_SliceAdaptor;
my $inputIDFactory = new Bio::EnsEMBL::Pipeline::Utils::InputIDFactory(-db => $db);
my @iids_to_write;

# at the moment, we generate slices according to the input slice size. In a later
# version, slices will be generated according to the most appropriate split point
# (determined by examining the protein/cDNA hits to the genome)

$verbose and print STDERR "Generating Initial input ids...\n";

# foreach my $chr (sort {$a->dbID <=> $b->dbID} @{$db->get_ChromosomeAdaptor->fetch_all}) {
foreach my $slice_id ($inputIDFactory->generate_slice_input_ids($max_slice_size, 0)) {
    my ($chr_name, $chr_start, $chr_end) = $slice_id =~ /^(\S+)\.(\d+)\-(\d+)$/;

    my $chr_slice = $sl_adp->fetch_by_chr_start_end( $chr_name, $chr_start, $chr_end );

    $verbose and print STDERR "Getting hits for $chr_name.$chr_start-$chr_end\n";

    my $seeds = {};
    foreach my $db (@{$GB_SIMILARITY_DATABASES}) {
	foreach my $f (@{$chr_slice->get_all_ProteinAlignFeatures($db->{'type'}, 
								  $db->{'threshold'})}) {
	    push @{$seeds->{$f->hseqname}->{'hits'}}, $f;	    
	}
    }

    # printf "Seqs for chr %s (%d) : %d\n", $chr->chr_name, $chr->length, scalar(keys %$seeds);
    my $num_seeds = scalar(keys %$seeds);

    next if $num_seeds == 0;

    # rule of thumb; split data so that each job constitutes one piece of 
    # genomic DNA against ~20 proteins. 
    my $num_chunks = int($num_seeds / 20) + 1;
    for (my $x=1; $x <= $num_chunks; $x++) {
	# generate input id : $chr_name.1-$chr_length:$num_chunks:$x
	my $new_iid = $slice_id . ":$num_chunks:$x"; 
	if (not $write) {
	    print "INSERT into input_id_analysis values ('$new_iid', '$ana_type', $ana_id, now(), '', '', 0);\n";
	}
	else {
	    push @iids_to_write, $new_iid;
	}
    }
}

if ($write) {
    my $s_inf_cont =$db->get_StateInfoContainer;

    foreach my $iid (@iids_to_write) {
	eval {
	    $s_inf_cont->store_input_id_analysis($iid, $analysis, '');
	};
	if ($@) {
	    print STDERR "Input id $iid already present\n";
	} else {
	    print STDERR "Stored input id $iid\n";
	}
    }

}
