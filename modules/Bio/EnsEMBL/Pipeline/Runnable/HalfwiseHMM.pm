#####note this is not a functional module yet drastic changes are being made to the way it is running donnot try and run this file#####



#
#
# Cared for by Laura Clarke  <lec@sanger.ac.uk>
#
# Copyright Laura Clarke
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Pipeline::Runnable::HalfwiseHMM

=head1 SYNOPSIS

 
 
=head1 DESCRIPTION

This package is based on the genscan runnable.
HalfwiseHMM takes a Bio::Seq (or Bio::PrimarySeq) object and runs HalfwiseHMM on it. The
resulting output is parsed to produce a set of Bio::SeqFeatures. 

=head2 Methods:

=over 4

=item new($seq_obj)

=item    HalfwiseHMM($path_to_HalfwiseHMM)

=item    workdir($directory_name)

=item    run()

=item    output()

=back

=head1 CONTACT

ensembl-dev.ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. 


=cut

package Bio::EnsEMBL::Pipeline::Runnable::HalfwiseHMM;


use vars qw(@ISA);
use strict;
# Object preamble - inherits from Bio::Root::RootI;

use Bio::EnsEMBL::Pipeline::RunnableI;
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Pipeline::Runnable::FeatureFilter;
use Bio::PrimarySeq; 
use Bio::Seq;
use Bio::SeqIO;
use Bio::Root::RootI;
use Bio::Tools::BPlite;
use Bio::EnsEMBL::Pipeline::Runnable::Blast;
use Bio::EnsEMBL::Pipeline::Runnable::GenewiseHmm;
use DB_File;
use Fcntl;

BEGIN {
    require "Bio/EnsEMBL/Pipeline/pipeConf.pl";
}

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableI);

=head2 new

    Title   :   new
    Usage   :   my obj =  Bio::EnsEMBL::Pipeline::Runnable::HalfwiseHMM->new (-QUERY => $seq);
    Function:   Initialises HalfwiseHMMobject
    Returns :   a HalfwiseHMMObject
    Args    :   A Bio::Seq object 
                (blastdb, hmmdb location of exes etc  optional)

=cut

sub new {
    my ($class,@args) = @_;

    my $self = $class->SUPER::new(@args);    

    $self->{'_genomic_seq'} = undef;
    $self->{'_input_features'} = [];
    $self->{'_output_features'} = [];
    $self->{'_hmmfetch'} = undef;
    $self->{'_hmmdb'} = undef;
    $self->{'_hmmfilename'} = undef; #file to store protein profile hmms 
    $self->{'_errorfile'} = undef; #file to store any errors hmmfetch throw
    $self->{'_dbm_file'} = undef;
    #print"args = @args\n";
    my ($genomic, $features, $hmmfetch, $hmmdb, $dbmfile) = $self->_rearrange([qw(GENOMIC
										  FEATURES
										  HMMFETCH
										  HMMDB 
										  DBMFILE)], @args);
    $self->throw("No genomic sequence input") unless defined($genomic);
    $self->genomic_sequence($genomic);
    $self->add_input_features($features);
    
    if ($hmmfetch){
	$self->hmmfetch($hmmfetch);
    } else {
	$self->hmmfetch('hmmfetch');
    }
    
    if($hmmdb){
	$self->hmmdb($hmmdb);
    } else {
	$self->hmmdb('/usr/local/ensembl/data/blastdb/Ensemb/Pfam');
	
    }
    if($dbmfile){
      $self->dbm_file($dbmfile);
    } else {
      $self->dbm_file('/usr/local/ensembl/data/swiss2prot_7.0.index');	
    }
    return $self; # success - we hope!
}




#################
#GET/SET METHODS#
#################
=head2 genomic_sequence

    Title   :   genomic_sequence
    Usage   :   $self->genomic_sequence($seq)
    Function:   Get/set method for genomic sequence
    Returns :   Bio::Seq object
    Args    :   Bio::Seq object

=cut

sub genomic_sequence {
    my( $self, $value ) = @_;    
    if ($value) {
        #need to check if passed sequence is Bio::Seq object
        $value->isa("Bio::PrimarySeqI") || $self->throw("Input isn't a Bio::PrimarySeqI");
        $self->{'_genomic_sequence'} = $value;
    }
    return $self->{'_genomic_sequence'};
}


sub add_input_features{
    
    my ($self, $features) = @_;
    
    if (ref($features) eq "ARRAY") {
      push(@{$self->{'_input_features'}},@$features);
    } else {
      $self->throw("[$features] is not an array ref.");
    }
      


}

sub all_input_features{

  my ($self) = @_;

  return @{$self->{'_input_features'}};

}


#methods that probably won't be needed

#sub sort_input_features{

#  my ($self) = @_;

#  @features = $self->all_input_features();

#  foreach my $f(@features){

#   if($f->strand == 1){
#     $self->forward_features($f);
#   }elsif($f->strand == -1){
#     $self->reverse_features($f);
#   }else{
#     $self->throw("feature has no strand : $!");
#   } 

#  }

#}

#sub forward_features{
  
#  my ($self, $f) = @_;
 
#  if (defined($f))
#    {
#	push(@{$self->{'_forward_features'}}, $f);
#    }

#  return @{$self->{'_forward_features'}};
#}

#sub reverse_features{

#  my ($self, $f) = @_;
 
#  if (defined($f))
#    {
#	push(@{$self->{'_reverse_features'}}, $f);
#    }

#  return @{$self->{'_reverse_features'}};
#}

=head2 hmmfetch 

 Title    : hmmfetch
 Usage    : $self->hmmfetch($location);
 Function : gets and sets the location of the hmmfetch command
 Returns  : the hmmfetch command
 Args     : the hmmfetch comand

=cut

sub hmmfetch {
    my ($self, $args) =@_;

    if (defined($args)){
	$self->{'_hmmfetch'} = $args;
    }
    return $self->{'_hmmfetch'};
}

=head2 hmmdb

 Title    : hmmdb
 Usage    : $self->hmmdb($db);
 Function : gets and sets the location of the hmmdb
 Returns  : the location of the hmmdb
 Args     : the location of the hmmdb

=cut

sub hmmdb {
    my ($self, $args) =@_;

    if (defined($args)){
	$self->{'_hmmdb'} = $args;
    }
    return $self->{'_hmmdb'};
}

sub hmmdb {
    my ($self, $args) =@_;

    if (defined($args)){
	$self->{'_hmmdb'} = $args;
    }
    return $self->{'_hmmdb'};
}

=head2  hmmfilename

 Title    : hmmfilename
 Usage    : $self->hmmfilename($filename);
 Function : gets and sets the name of the hmmdb file
 Returns  : the name of the hmmdb file
 Args     : the name of the hmmdb file

=cut

sub hmmfilename {
    my ($self, $args) = @_;
    if (defined ($args)){
	$self->{'_hmmfilename'} = $args;
    }

    return $self->{'_hmmfilename'};

}



sub dbm_file {
    my ($self, $args) = @_;
    if (defined ($args)){
	$self->{'_dbm_file'} = $args;
    }

    return $self->{'_dbm_file'};

}




##########
#ANALYSIS#
##########


=head2  run
 
 Title    : Run
 Usage    : $self->run
 Function : runs blast and halfwise
 Returns  : nothing
 Args     : workdir

=cut

sub run {

    my ($self, $dir) = @_;
    #print "running halfwise\n";
    my %swissprot_ids = $self->get_swissprot_ids();
    #print "got swiss prot ids \n";
    my @keys = keys(%swissprot_ids);
    
    #foreach my $key (@keys){
    #  print "hid = ".$key." strand = ".$swissprot_ids{$key}."\n";
    #}

    my %pfam_ids = $self->get_pfam_ids(\%swissprot_ids);
    #print "got pfam ids \n";
    $self->create_genewisehmm(\%pfam_ids, $dir);

}


sub get_swissprot_ids{

  my ($self) = @_;

  my @features = $self->all_input_features();
  my %swissprot_ids;
  foreach my $f(@features){
    #print "swissprot id = ".$f->hseqname."\n";
    if(!$swissprot_ids{$f->hseqname}){
     
      $swissprot_ids{$f->hseqname} = $f->strand;
    
    }elsif(defined$swissprot_ids{$f->hseqname}){
      
      if($swissprot_ids{$f->hseqname} != $f->strand){
	$swissprot_ids{$f->hseqname} = 0;
      }else{
	$swissprot_ids{$f->hseqname} = $f->strand;
      }

    }
    
  }

  return %swissprot_ids;
    
}


sub get_pfam_ids{

  my ($self, $swissprot_ids) = @_;

  my %swiss_pfam;
  my %pfams;
  my $permission = O_RDONLY;
  tie(%swiss_pfam, "DB_File", $self->dbm_file, $permission, 0400);
  
  foreach my $swiss_id(keys(%$swissprot_ids)){
    #print "searching for pfam ids for ".$swiss_id."\n";  
    my $strand = $swissprot_ids->{$swiss_id};
    
    my $pfam = $swiss_pfam{$swiss_id};
    #print "found these pfam domains ".$pfam." \n";
    if(!$pfam){
      $self->warn("the swissprot ".$swiss_id ."entry has no pfam domains :!")
    }
    my @pfams = split /,/, $pfam;
    #print "pfams = @pfams\n";
    foreach my $pfam_id(@pfams){
      #print "trying to create a hash entry for pfam".$pfam_id."\n";
      if(!defined $pfams{$pfam_id}){
	#print "defining pfam hash key\n";
	$pfams{$pfam_id} = $strand;
    
     }elsif(defined$pfams{$pfam_id}){
	if($pfams{$pfam_id} != $strand){
	 $pfams{$pfam_id} = 0;
	}else{
	 $pfams{$pfam_id} = $strand;
       }
      }
    }
  }
  return %pfams;
}
 

sub create_genewisehmm{

 my ($self, $pfam_ids, $dir) = @_;
 #print "getting hmms\n";
 $self->workdir('/tmp') unless ($self->workdir($dir)); 
 $self->checkdir();
 my @ids = keys(%$pfam_ids);
 my $genewisehmm;
 my @features;
 my $memory = 400000;
 #print "there are ".scalar(@ids)." pfam ids to run\n";
 foreach my $id (@ids){
   #print "running for pfam ".$id."\n";
   my $strand = $pfam_ids->{$id};

   $self->get_hmm($id);
   #print "got hmm \n";
   if($strand == 1){
    
    $genewisehmm = $self->run_genewisehmm($strand, $memory);
    $genewisehmm->run();
    @features = $genewisehmm->output();

    $self->add_output_features(\@features);
   
   }elsif($strand == -1){
     $genewisehmm = $self->run_genewisehmm($strand, $memory);
    $genewisehmm->run();
    @features = $genewisehmm->output();

    $self->add_output_features(\@features);
   }elsif($strand == 0){
     $genewisehmm = $self->run_genewisehmm(1, $memory);
     $genewisehmm->run();
     @features = $genewisehmm->output();

     $self->add_output_features(\@features);
   
     $genewisehmm = $self->run_genewisehmm(-1, $memory);
     $genewisehmm->run();
     @features = $genewisehmm->output();

     $self->add_output_features(\@features);
   }else{

     $self->throw("strand = ".$strand." something funnies going on : $!\n");

   }

 }


}


sub run_genewisehmm{

  my ($self, $strand, $memory) = @_;
  my $reverse;
  if($strand == -1){
    $reverse = 1;
  }else{
    $reverse = undef;
  }
  print "creating genewisehmm\n";
  my $genewisehmm = Bio::EnsEMBL::Pipeline::Runnable::GenewiseHmm->new('-genomic' => $self->genomic_sequence(),
                                                                    '-memory' => $memory,
                                                                    '-hmmfile' => $self->hmmfilename(),
                                                                    '-reverse' => $reverse);

  return $genewisehmm

}


=head2 

 Title    : get_hmm
 Usage    : $self->get_hmm;
 Function : gets all the hmms for the pfam matchs found by blast
 Returns  : none
 Args     : none

=cut

sub get_hmm{
  
  my ($self, $id) = @_;
  $self->hmmfilename($id.".".$$.".hmm");
  $self->errorfile($self->genomic_sequence->id."err.$$");
  #print "getting hmm for id ".$id."\n";
  my $command =  $self->hmmfetch." ".$self->hmmdb." ".$id." 2> ".$self->errorfile." 1>".$self->hmmfilename;

  print "command = ".$command."\n";
  system ('pwd');
  system($command);
  
  if (-e $self->errorfile){
    open(ERROR, $self->errorfile) or die "couldn't open error file : $!";
    while(<ERROR>){
      if(/no such hmm/i){
	print STDERR "error message : ".$_."\n";
      }
    }
    close(ERROR) or die "couldn't close error file : $!";
  }
  
}








=head2  errorfile

 Title    : errorfile
 Usage    : $self->errorfile($filename);
 Function : gets and sets the name of the hmmdb file
 Returns  : the name of the hmmdb file
 Args     : the name of the hmmdb file

=cut

sub errorfile {
    my ($self, $args) = @_;
    if (defined ($args)){
	$self->{'_errorfile'} = $args;
    }

    return $self->{'_errorfile'};

}


sub add_output_features{
    
    my ($self, $features) = @_;
    
    if (ref($features) eq "ARRAY") {
      push(@{$self->{'_output_features'}},@$features);
    } else {
      $self->throw("[$features] is not an array ref.");
    }
      


}

sub all_output_features{

  my ($self) = @_;

  return @{$self->{'_output_features'}};

}


################
#OUTPUT METHODS#
################


sub output{

  my ($self) = @_;

  my @out = $self->all_output_features();

  return @out;

}
1;
