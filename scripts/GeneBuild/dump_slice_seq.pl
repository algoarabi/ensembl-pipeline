#!/usr/local/bin/perl -w

=head1 NAME

  dump_vc_seq.pl

=head1 SYNOPSIS
 
  chr_genedump.pl

=head1 DESCRIPTION

  Dumps the sequence of a virtual contig to file, masked or unmasked.
  db and dnadb can be the same or different databases - just make sure all the relevant arguments are passed in.
  The user for each db can (and probably should) be read-only.
  Specify chrname, start and end.

=head1 OPTIONS

  -dbname
  -dbhost
  -dnadbname
  -dnadbhost
  -path
  -start
  -end
  -chrname
  -out
  -path
  -masked

=cut

use strict;
use Getopt::Long;
use Bio::SeqIO;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

my $dbname     = 'briggsae_intermediate_newschema';
my $dbuser     = 'ensro'; # always use read only
my $dbhost     = 'ecs1c';
my $dnadbname  = 'briggsae_intermediate_newschema';
my $dnadbuser  = 'ensro'; # always use ensro
my $dnadbhost  = 'ecs1c';
my $path       = 'briggsae_170602';
my $start;
my $end;
my $outfile    = 'out.fa';
my $chrname    = '';
my $masked     = 0;

&GetOptions( 
	    'dbname:s'     => \$dbname,
	    'dbhost:s'     => \$dbhost,
	    'dnadbname:s'  => \$dnadbname,
	    'dnadbhost:s'  => \$dnadbhost,
	    'outfile:s'    => \$outfile,
	    'chrname:s'    => \$chrname,
	    'path:s'       => \$path,
	    'start:i'      => \$start,
	    'end:i'        => \$end,
	    'masked'       => \$masked,
	   );

# usage
if(!defined $dbname    ||
   !defined $dnadbname ||
   !defined $dbhost    ||
   !defined $dnadbhost ||
   !defined $chrname   ||
   !defined $start     ||
   !defined $end       ||
   !defined $path    
  ){
  print  "USAGE: dump_vc_seq.pl -dbname dbname -host host -chrname chr -start start_pos -end end_pos -path path\n optional:\n -masked, for repmasked sequence;\n -outfile to specify a filename other than out.fa\n";
  exit(1);
}

# global stuff
my $dnadb =  new Bio::EnsEMBL::DBSQL::DBAdaptor(
						-host   => $dnadbhost,
						-dbname => $dnadbname,
						-user   => $dnadbuser,
					       );

my $db =  new Bio::EnsEMBL::DBSQL::DBAdaptor(
					     -host   => $dbhost,
					     -dbname => $dbname,
					     -user   => $dbuser,
					     -dnadb  =>$dnadb
					    );

$db->static_golden_path_type($path);

my $sgpa = $db->get_StaticGoldenPathAdaptor;

print STDERR "about to fetch $chrname $start $end\n";

print "fetching virtual contig for ".$chrname." ".$start." ".$end."\n";
my $vc = $sgpa->fetch_VirtualContig_by_chr_start_end($chrname,$start,$end);


my $seqout = Bio::SeqIO->new( '-format' => 'fasta',
                              '-file'   => ">>$outfile");
my $did = $chrname . "." . $start . "-" . $end;
if($masked){
  print STDERR "about to get repeatmasked sequence\n";
  my $rmseq = $vc->get_repeatmasked_seq;
  $rmseq->display_id($did);
  print STDERR "about to write sequence to $outfile\n";

  $seqout->write_seq($rmseq);	       
}

else {
#  my $did = $chrname . "." . $start . "-" . $end;
  $vc->display_id($did);
  print STDERR "about to write sequence to $outfile\n";
  $seqout->write_seq($vc);
}
