#! /usr/bin/perl -w -s
use List::MoreUtils 'first_index';
use List::MoreUtils qw(indexes);

#############################################################
#
# Removes identical sequences and sorts by longest ORF 
#
#############################################################

my %seqs=();

my $header="";
my $seq="";
$seqs{$seq}=1000000000; # adds empty string to hash with arbitary large number (to ensure first in $output)
my $h1="";
my @idx;
my $output;

while (<>) {
	if ($_=~/\>/) {
		$seqs{$seq}=(sprintf "%.0f",main()) if !exists $seqs{$seq};
		$seq="";		
	} else{
		chomp;
		$seq.=$_;
	}
}


$seqs{$seq}=(sprintf "%.0f",main()) if !exists $seqs{$seq} & $seq ne "";

my $counter=0;
foreach my $key (sort {$seqs{$b} <=> $seqs{$a}} keys %seqs) {
	$output.=">uniq.$counter;maxorf=$seqs{$key};\n$key\n";
	$counter++;
}

syswrite STDOUT, $output,length($output),28;

sub main {
	my $rcseq = reverse_compliment($seq);
	$idx[0] = get_idx($seq);
	$idx[1] = get_idx($rcseq);
	$seq =~ s/^.//s;
	$rcseq =~ s/^.//s;
	$idx[2] = get_idx($seq);
	$idx[3] = get_idx($rcseq);
	$seq =~ s/^.//s;
	$rcseq =~ s/^.//s;
	$idx[4] = get_idx($seq);
	$idx[5] =get_idx($rcseq);

	my $itop = max_numarray_idx(@idx);
	my $score=$idx[$itop];
	$score=length($seq)+1 if $score < 0;
	return($score);
}

sub reverse_compliment {
	my ($s)=@_;
	$s=~tr/atcgATCG/tagcTAGC/;
	reverse $s;
}

sub get_idx {
	my ($s)=@_;
	my @ind1 = indexes { /TAG|TAA|TGA/ } ( $s =~ m/.../g ); # this finds all stop codons - which is also a map of potential ORFs
	return(-1) if !$ind1[0];
	push @ind1,length($s)/3+1;	
	my @ind2 = @ind1;
	pop @ind1;
	shift @ind2;
	my @ind3;
	for (my $i=0;$i<scalar @ind1;$i++){
    		$ind3[$i]= $ind2[$i] - $ind1[$i] -1; 
	}
	unshift @ind3,(shift @ind1);
	$ind3[max_numarray_idx(@ind3)];
}


sub max_numarray_idx {
	my $idxMax = 0;
	my @data = @_;
	my $m1 = first_index {/-1/} @data;
	return($m1) if $m1>-1;    
	$data[$idxMax] > $data[$_] or $idxMax = $_ for 1 .. $#data;
	return($idxMax);
}
