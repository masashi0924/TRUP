use strict;
use Getopt::Long;
#this program is used for getting reads for denovo assembly


my $arp_file;
my $unmap_file;
my $AB;
my $SM;
my $RA;
my $nc = 3;
my $read_file_1 = '';
my $read_file_2 = '';
my $outputDir = "SRP";

GetOptions (
              "arpfile|m=s"      => \$arp_file,
              "unmap|u=s"        => \$unmap_file,
	      "readfile1|r1=s"   => \$read_file_1,
              "readfile2|r2=s"   => \$read_file_2,
              "nc|n=i"           => \$nc,
              "output|o=s"       => \$outputDir,
              "AB"               => \$AB,
              "SM"               => \$SM,
              "RA"               => \$RA,
	      "help|h" => sub{
	                     print "usage: $0 [options]\n\nOptions:\n";
                             print "\t--arpfile\tthe arp file generated by Rseq_bam_stats, or reads_in_region in which case --RA should be set.\n";
                             print "\t--unmap\t\tunmapped reads file in fq\n";
			     print "\t--readfile1\tthe 5' end reads\n";
			     print "\t--readfile2\tthe 3' end reads\n";
                             print "\t--nc\t\tnumber of undecided nucleotide allowed\n";
                             print "\t--AB\t\twhether AB\n";
                             print "\t--SM\t\twhether for second mapping\n";
                             print "\t--RA\t\twhether for regional assembly\n";
                             print "\t--output\twhere to output.\n";
			     print "\t--help\t\tprint this help message\n\n";
                             exit 0;
			    }
	   );


#split read files
my @read_files_mate1 = split(",", $read_file_1);
my @read_files_mate2 = split(",", $read_file_2) if ($read_file_2 ne '');
my $read_files_mate1 = join(" ", @read_files_mate1);
my $read_files_mate2 = join(" ", @read_files_mate2) if ($read_file_2 ne '');


my ($decompress, $zipSuffix);
if ($read_files_mate1[0] =~ /\.gz$/){
  $decompress = "gzip -d -c";
  $zipSuffix = "gz";
} elsif ($read_files_mate1[0] =~ /\.bz2$/) {
  $decompress = "bzip2 -d -c";
  $zipSuffix = "bz2";
} else {
  print STDERR "the read file $read_file_1 does not seem to be gziped or bziped!!!\n";
  exit 22;
}


my %ARP;  #hash to remember the anomalous read pairs

unless ($SM or $RA) {
  open UM, "gzip -d -c $unmap_file |";
  while ( <UM> ) {
    chomp;
    my $frag_name;
    if ($_ =~ /^@(.+?)\s+/) {
      $frag_name = $1;
    } elsif ($_ =~ /^@(\S+)$/) {
      $frag_name = $1;
    }
    $frag_name =~ s/\/[12].*?$//; #replace the end

    if ($AB) {
      $frag_name =~ s/^(.+)[AB]$/\1/;
    }
    $ARP{$frag_name} = '';

    $_ = <UM>;
    $_ = <UM>;
    $_ = <UM>;
  }
  close UM;
  print STDERR "unmapped file loaded\n";
}

open ARP, "$arp_file";
my $breakpoints = '';         #for regional assembly
my $flag_ra = 0;              #for regional assembly
while ( <ARP> ) {

   chomp;

   if ($AB) {
     $_ =~ s/^(.+)[AB]$/\1/;
   }

   #for regional assembly started here#############
   if ($RA) {
     if ($_ =~ /^\d+\t(chr)?\w+/) {
       if ($flag_ra == 1) {
          $breakpoints = '';
          $flag_ra = 0;
       }
       $breakpoints .= "$_\n";
     }
     else {
        $_ =~ s/\/[123](\w)?$//;
        push (@{$ARP{$_}}, $breakpoints);
        $flag_ra = 1 if ($flag_ra == 0);   #old breakpoints
     }
     next;
   }
   #for regional assembly

   $ARP{$_} = '';
}
close ARP;
print STDERR "ARP file loaded\n";


#check for number of un-decided nucleotides
unless ($SM or $nc == 0) {
  open R1P, "$decompress $read_files_mate1 |";
  while ( <R1P> ) {
    chomp;
    if ($_ =~ /^@(\S+)/) {
      my $frag_name = $1;
      $frag_name =~ s/\/[A-Za-z0-9]+$//;
      if (exists $ARP{$frag_name}) {

        $_ = <R1P>;             #sequence
        chomp;
        my $n = 0;
        while ($_ =~ /N/g) {
          $n++;
        }
        if ($n >= $nc) {
          delete ($ARP{$frag_name}); #delete this frag
        }

        $_ = <R1P>;
        $_ = <R1P>;             #quality
      } else {
        $_ = <R1P>;
        $_ = <R1P>;
        $_ = <R1P>;
      }
    }
  }
  close R1P;

  if ($read_file_2 ne '') {
    open R2P, "$decompress $read_files_mate2 |";
    while ( <R2P> ) {
      chomp;
      if ($_ =~ /^@(\S+)/) {
        my $frag_name = $1;
        $frag_name =~ s/\/[A-Za-z0-9]+$//;
        if (exists $ARP{$frag_name}) {

          $_ = <R2P>;             #sequence
          chomp;
          my $n = 0;
          while ($_ =~ /N/g) {
            $n++;
          }
          if ($n >= $nc) {
            delete ($ARP{$frag_name}); #delete this frag
          }

          $_ = <R2P>;
          $_ = <R2P>;             #quality
        } else {
          $_ = <R2P>;
          $_ = <R2P>;
          $_ = <R2P>;
        }
      }
    }
    close R2P;
  } #when it is paired-end experiment
} ##############check for undecided nucleiotide


my $a_R1 = $read_files_mate1[0];
$a_R1 =~ /^(.+)\/(.+?)$/;
$outputDir = $1 if ($outputDir eq "SRP");
$a_R1 = $2;
if($SM) {
 $a_R1 =~ s/fq\.$zipSuffix$/ARP\.secondmapping\.fq/;
 $a_R1 =~ s/fastq\.$zipSuffix$/ARP\.secondmapping\.fq/;
}
elsif($RA) {
 $a_R1 =~ s/fq\.$zipSuffix$/RAssembly\.fq/;
 $a_R1 =~ s/fastq\.$zipSuffix$/RAssembly\.fq/;
}
else {
 $a_R1 =~ s/fq\.$zipSuffix$/ARP\.fq/;
 $a_R1 =~ s/fastq\.$zipSuffix$/ARP\.fq/;
}
$a_R1 = "$outputDir\/".$a_R1;


my $a_R2;
if ($read_file_2 ne '') {
  $a_R2 = $read_files_mate2[0];
  $a_R2 =~ /^(.+)\/(.+?)$/;
  $a_R2 = $2;
  if ($SM) {
    $a_R2 =~ s/fq\.$zipSuffix$/ARP\.secondmapping\.fq/;
    $a_R2 =~ s/fastq\.$zipSuffix$/ARP\.secondmapping\.fq/;
  } elsif ($RA) {
    $a_R2 =~ s/fq\.$zipSuffix$/RAssembly\.fq/;
    $a_R2 =~ s/fastq\.$zipSuffix$/RAssembly\.fq/;
  } else {
    $a_R2 =~ s/fq\.$zipSuffix$/ARP\.fq/;
    $a_R2 =~ s/fastq\.$zipSuffix$/ARP\.fq/;
  }
  $a_R2 = "$outputDir\/".$a_R2;
}

open AR1, ">$a_R1";
if ($read_file_2 ne '') {
  open AR2, ">$a_R2";
}
open R1, "$decompress $read_files_mate1 |";
if ($read_file_2 ne '') {
  open R2, "$decompress $read_files_mate2 |";
}

my %RA;                         #a hash for RAssembly;
while ( <R1> ) {                #name

  chomp;
  my $MATE2;
  if ($read_file_2 ne '') {
    $MATE2 = <R2>;
    chomp($MATE2);
  }

  if ($_ =~ /^@(\S+)/) {

    my $frag_name = $1;
    $frag_name =~ s/\/[A-Za-z0-9]+$//;

    if (exists $ARP{$frag_name}) {

      my $tag_tmp1;
      my $tag_tmp2;
      $_ =~ s/(\/[123])\w+$/\1/;                              #id mate1
      $MATE2 =~ s/(\/[123])\w+$/\1/ if ($read_file_2 ne '');  #id mate2
      if ($RA) {
        $tag_tmp1 .= "$_\n";
        $tag_tmp2 .= "$MATE2\n" if ($read_file_2 ne '');
      } else {
        print AR1 "$_\n";
        print AR2 "$_\n" if ($read_file_2 ne '');
      }

      $_ = <R1>;                                             #sequence mate1
      $MATE2 = <R2> if ($read_file_2 ne '');                 #sequence mate2
      if ($RA) {
        $tag_tmp1 .= "$_";
        $tag_tmp2 .= "$MATE2" if ($read_file_2 ne '');
      } else {
        print AR1 "$_";
        print AR2 "$_" if ($read_file_2 ne '');
      }

      $_ = <R1>;                                             #third line mate1
      $MATE2 = <R2> if ($read_file_2 ne '');                 #third line mate2
      $_ =~ s/(\/[123])\w+/\1/;
      $MATE2 =~ s/(\/[123])\w+/\1/ if ($read_file_2 ne '');
      if ($RA) {
        $tag_tmp1 .= "$_";
        $tag_tmp2 .= "$MATE2" if ($read_file_2 ne '');
      } else {
        print AR1 "$_";
        print AR2 "$_" if ($read_file_2 ne '');
      }

      $_ = <R1>;                                             #quality mate1
      $MATE2 = <R2> if ($read_file_2 ne '');                 #quality mate2
      if ($RA) {
        $tag_tmp1 .= "$_";
        $tag_tmp2 .= "$MATE2" if ($read_file_2 ne '');
        foreach my $bp (@{$ARP{$frag_name}}) {
          push(@{$RA{$bp}{'mate1'}}, $tag_tmp1);
          push(@{$RA{$bp}{'mate2'}}, $tag_tmp2) if ($read_file_2 ne '');
        }
        delete($ARP{$frag_name});
      } else {
        print AR1 "$_";
        print AR2 "$_" if ($read_file_2 ne '');
      }

    } else {
      $_ = <R1>;
      $MATE2 = <R2> if ($read_file_2 ne '');
      $_ = <R1>;
      $MATE2 = <R2> if ($read_file_2 ne '');
      $_ = <R1>;
      $MATE2 = <R2> if ($read_file_2 ne '');
    }
  }
}
close R1;
close R2;

if ($RA) {   #for regional assembly printing (shuffled)
  foreach my $breakpoint (sort {$a =~ /^(\d+)\t/; my $ida = $1; $b =~ /^(\d+)\t/; my $idb = $1; $ida<=>$idb} keys %RA){
    print AR1 "$breakpoint";
    print AR2 "$breakpoint" if ($read_file_2 ne '');
    foreach my $tag1 (@{$RA{$breakpoint}{'mate1'}}){
      print AR1 "$tag1";
    }
    if ($read_file_2 ne '') {
      foreach my $tag2 (@{$RA{$breakpoint}{'mate2'}}) {
        print AR2 "$tag2";
      }
    }
  } #each breakpoint
}

close AR1;
close AR2 if ($read_file_2 ne '');

%RA = ();

exit;
