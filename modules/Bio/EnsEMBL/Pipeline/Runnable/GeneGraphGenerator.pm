#
# Cared for by Eduardo Eyras  <eae@sanger.ac.uk>
#
# Copyright GRL & EBI
#
# You may distribute this module under the same terms as perl itself
#
# POD documenta

=pod 

=head1 NAME

  Bio::EnsEMBL::Pipeline::Runnable::GeneGraphGenerator

=head1 SYNOPSIS

    my $graph = Bio::EnsEMBL::Pipeline::Runnable::GeneGraph->new();
    my @transcripts_in_graph = $graph->_find_connected_graphs(@transcripts);
    
=head1 DESCRIPTION

It creates a graph where the nodes are the transcripts and the vertices is a relation between the
transcripts. In general this relation is 'having one exon in common'. This will most likely be modified 
in the future. For instance, to include the realtion 'having one intron in common'.

The method  _find_connected_graphs will retrieve from the graph the connected components
with more than one element, and returns all the transcripts that are in these connected components.
This will be soon modified to be able to retrieve either the components separately or the total list of
transcripts.

=head1 CONTACT

eae@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

# Let the code begin...
package Bio::EnsEMBL::Pipeline::Runnable::GeneGraphGenerator;

use diagnostics;
use vars qw(@ISA);
use strict;

use Bio::Range;
use Bio::EnsEMBL::Pipeline::GeneComparison::GeneCluster;
use Bio::EnsEMBL::Pipeline::GeneComparison::TranscriptCluster;
use Bio::EnsEMBL::Pipeline::GeneComparison::TranscriptComparator;
use Bio::EnsEMBL::Pipeline::Tools::TranscriptUtils;
use Bio::EnsEMBL::Pipeline::Tools::GeneUtils;
use Bio::EnsEMBL::Pipeline::Tools::ExonUtils;
use Bio::EnsEMBL::Pipeline::GeneCombinerConf;

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableI);

############################################################

sub new{
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  
  return $self;
  
}


############################################################
# this function takes est_transcripts that have been clustered together
# but not with any ensembl transcript and tries to figure out whether they
# make an acceptable set of alt-forms

sub _check_est_Cluster{
  my ($self,@est_transcripts) = @_;
  my %color;

  #if ( scalar(@est_transcripts) == 1 ){
  print STDERR "cluster with ".scalar(@est_transcripts)." transcripts\n";
  #}

  # adjacency lists:
  my %adj;
  my %seen;
  my @linked;

  for(my $i=0;$i<scalar(@est_transcripts);$i++){
    for(my $j=0;$j<scalar(@est_transcripts);$j++){
      
      next if $j==$i;
      print STDERR "Comparing transcripts:\n";
      Bio::EnsEMBL::Pipeline::Tools::TranscriptUtils->_print_Transcript($est_transcripts[$i]);
      Bio::EnsEMBL::Pipeline::Tools::TranscriptUtils->_print_Transcript($est_transcripts[$j]);
      
      # we only check on coincident exon:
      if ( $self->_check_exact_exon_Match( $est_transcripts[$i], $est_transcripts[$j]) 
	   #&&	   $self->_check_protein_Match(    $est_transcripts[$i], $est_transcripts[$j])
	 ){
	print STDERR "they are linked\n";
	push ( @{ $adj{$est_transcripts[$i]} } , $est_transcripts[$j] );
	unless ( defined $seen{ $est_transcripts[$i] } &&  $seen{ $est_transcripts[$i] } ){
	  push ( @linked, $est_transcripts[$i] );
	  $seen{ $est_transcripts[$i] } =1 ;
	}
	unless ( defined $seen{ $est_transcripts[$j] } &&  $seen{ $est_transcripts[$j] } ){
	  push ( @linked, $est_transcripts[$j] );
	  $seen{ $est_transcripts[$j] } = 1;
	}
      }
    }
  }
  
  print STDERR scalar(@linked). " linked transcripts\n";
  
  print STDERR "adjacency lists:\n";
  foreach my $tran (@linked){
    print STDERR $tran->dbID." -> ";
    foreach my $link ( @{ $adj{ $tran } } ){
      print STDERR $link->dbID.",";
    }
    print STDERR "\n";
  }
  
  foreach my $tran ( @linked ){
    $color{$tran} = "white";
  }
  
  my @potential_genes;
  
  # find the connected components doing a depth-first search
  foreach my $tran ( @linked ){
    if ( $color{$tran} eq 'white' ){
      my @potential_gene;
      $self->_visit( $tran, \%color, \%adj, \@potential_gene);
      push ( @potential_genes, \@potential_gene );
    }
  }
  print STDERR scalar(@potential_genes)." potential genes created\n";
  my @accepted_transcripts;
  foreach my $gene (@potential_genes){
    push ( @accepted_transcripts, @$gene );
  }
  print STDERR "returning ".scalar( @accepted_transcripts)." transcripts\n";
  return @accepted_transcripts;
}

#########################################################################

sub _visit{
  my ($self, $node, $color, $adj, $potential_gene) = @_;
  
  # node is a transcript object;
  $color->{ $node } = 'gray';

  foreach my $trans ( @{ $adj->{$node} } ){
    if ( $color->{ $trans } eq 'white' ){
      $self->_visit( $trans, $color, $adj, $potential_gene );
    }
  }
  unless ( $color->{$node} eq 'black'){
    push( @{ $potential_gene }, $node);
  }
  $color->{ $node } = 'black';    
  return;
}

#########################################################################

1;
